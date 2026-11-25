import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';

import '../services/push_service.dart';

/// Dispatch — turns orders into driver jobs and shows the fleet live.
///
/// Flow (one Firestore database shared by every app):
///   website / customer app  → orders/{id} status `pending`
///   Dispatch (here)         → jobs/{id} (pickup)   + order `pickup_assigned`
///   driver app              → order `pickup_en_route` … `collected`, live_tracking/{orderId}
///   intake app              → order `at_facility` … `ready_for_delivery`
///   Dispatch (here)         → jobs/{id} (delivery) + order `delivery_assigned`
///   driver app              → order `out_for_delivery` … `delivered`

class _D {
  static const canvas = Color(0xFFF5F7F5);
  static const card = Colors.white;
  static const navy = Color(0xFF0F172A);
  static const azure = Color(0xFF047857);
  static const azureSoft = Color(0xFFECFDF5);
  static const emerald = Color(0xFF059669);
  static const emeraldBg = Color(0xFFECFDF5);
  static const amber = Color(0xFFD97706);
  static const amberBg = Color(0xFFFFFBEB);
  static const rose = Color(0xFFE11D48);
  static const roseBg = Color(0xFFFFF1F2);
  static const violet = Color(0xFF7C3AED);
  static const violetBg = Color(0xFFF5F3FF);
  static const mut = Color(0xFF64748B);
  static const faint = Color(0xFF94A3B8);
  static const border = Color(0xFFE5E9E7);

  static TextStyle h(double s, {Color c = navy}) => GoogleFonts.outfit(fontSize: s, fontWeight: FontWeight.w800, color: c);
  static TextStyle t(double s, {Color c = navy, FontWeight w = FontWeight.w600}) => GoogleFonts.plusJakartaSans(fontSize: s, fontWeight: w, color: c);
}

const _tiles = 'https://{s}.google.com/vt/lyrs=m&x={x}&y={y}&z={z}';
const _defaultCenter = LatLng(52.4862, -1.8904);
const _toCollect = ['pending', 'confirmed', 'pickup_failed'];
const _toDeliver = ['ready_for_delivery', 'delivery_failed'];

String _dayKey(DateTime d) => DateFormat('yyyy-MM-dd').format(d);
Map<String, dynamic> _m(Object? v) => v is Map ? v.cast<String, dynamic>() : <String, dynamic>{};
String _s(Object? v) => v == null ? '' : '$v';
DateTime? _date(Object? v) => v is Timestamp ? v.toDate() : null;

String _ago(DateTime? t) {
  if (t == null) return 'never';
  final s = DateTime.now().difference(t).inSeconds;
  if (s < 60) return 'just now';
  if (s < 3600) return '${s ~/ 60} min ago';
  if (s < 86400) return '${s ~/ 3600} h ago';
  return DateFormat('d MMM').format(t);
}

/// A driver counts as online while their app or driver document reports online.
bool _isOnline(Map<String, dynamic>? loc, [Map<String, dynamic>? driverDoc]) {
  if (loc != null && loc['online'] == true) {
    final at = _date(loc['updatedAt']);
    if (at == null || DateTime.now().difference(at).inMinutes < 60) return true;
  }
  if (driverDoc != null) {
    if (driverDoc['isOnline'] == true || driverDoc['online'] == true) return true;
  }
  return false;
}

DateTime? _created(Object? v) => v is Timestamp ? v.toDate() : v is String ? DateTime.tryParse(v) : null;

/// The day the customer chose, from what the website ("Mon, 16 Nov", "Tomorrow")
/// or the app ("Monday" = the next Monday after booking) saved.
DateTime? _slotDay(String raw, DateTime? bookedAt) {
  final s = raw.trim().toLowerCase();
  final now = DateTime.now(), today = DateTime(now.year, now.month, now.day);
  if (s.isEmpty) return null;
  if (s == 'today') return today;
  if (s == 'tomorrow') return today.add(const Duration(days: 1));
  const days = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'];
  final w = days.indexWhere((d) => s == d || s == d.substring(0, 3));
  if (w >= 0) {
    final b = bookedAt ?? now, base = DateTime(b.year, b.month, b.day);
    var diff = w - (base.weekday - 1);
    if (diff <= 0) diff += 7; // same rule as the app's time slot screen
    return base.add(Duration(days: diff));
  }
  final m = RegExp(r'(\d{1,2})\s+([a-z]{3})').firstMatch(s);
  if (m != null) {
    const mons = ['jan', 'feb', 'mar', 'apr', 'may', 'jun', 'jul', 'aug', 'sep', 'oct', 'nov', 'dec'];
    final mi = mons.indexOf(m.group(2)!);
    if (mi >= 0) {
      var d = DateTime(now.year, mi + 1, int.parse(m.group(1)!));
      if (d.isBefore(today.subtract(const Duration(days: 60)))) d = DateTime(now.year + 1, mi + 1, d.day); // December → January
      return d;
    }
  }
  return null;
}

/// Road route (OSRM, free) from the van to the stop: points + minutes. Null if it can't be found.
Future<(List<LatLng>, int)?> _route(LatLng a, LatLng b) async {
  try {
    final r = await http
        .get(Uri.parse('https://router.project-osrm.org/route/v1/driving/${a.longitude},${a.latitude};${b.longitude},${b.latitude}?overview=full&geometries=geojson'))
        .timeout(const Duration(seconds: 8));
    if (r.statusCode != 200) return null;
    final route = (jsonDecode(r.body)['routes'] as List).first;
    final pts = (route['geometry']['coordinates'] as List).map((c) => LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble())).toList();
    return (pts, ((route['duration'] as num) / 60).ceil());
  } catch (_) {
    return null;
  }
}

/// Postcode → coordinates (postcodes.io, free, UK only). Null if it can't be found.
Future<LatLng?> _geocode(String postcode) async {
  final pc = postcode.replaceAll(' ', '');
  if (pc.isEmpty) return null;
  try {
    final r = await http.get(Uri.parse('https://api.postcodes.io/postcodes/$pc')).timeout(const Duration(milliseconds: 1800));
    if (r.statusCode != 200) return null;
    final j = jsonDecode(r.body)['result'];
    return LatLng((j['latitude'] as num).toDouble(), (j['longitude'] as num).toDouble());
  } catch (_) {
    return null;
  }
}

class DispatchScreenRealtime extends StatefulWidget {
  const DispatchScreenRealtime({super.key});
  @override
  State<DispatchScreenRealtime> createState() => _DispatchScreenRealtimeState();
}

class _DispatchScreenRealtimeState extends State<DispatchScreenRealtime> with SingleTickerProviderStateMixin {
  final _db = FirebaseFirestore.instance;
  late final TabController _tabs = TabController(length: 4, vsync: this);
  DateTime _day = DateTime.now();

  late final Stream<QuerySnapshot<Map<String, dynamic>>> _orders =
      _db.collection('orders').where('status', whereIn: [..._toCollect, ..._toDeliver]).snapshots();
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _drivers = _db.collection('drivers').snapshots();
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _staff = _db.collection('staff').snapshots();
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _fleet = _db.collection('driver_locations').snapshots();
  late Stream<QuerySnapshot<Map<String, dynamic>>> _jobs = _jobsFor(_day);

  Stream<QuerySnapshot<Map<String, dynamic>>> _jobsFor(DateTime d) => _db.collection('jobs').where('date', isEqualTo: _dayKey(d)).snapshots();

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  void _setDay(DateTime d) => setState(() {
        _day = d;
        _jobs = _jobsFor(d);
      });

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.of(context).size.width >= 1100;
    return Container(
      color: _D.canvas,
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _drivers,
        builder: (context, dSnap) {
          final drivers = dSnap.data?.docs ?? const [];
          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _fleet,
            builder: (context, fSnap) {
              final fleet = {for (final d in fSnap.data?.docs ?? const <QueryDocumentSnapshot<Map<String, dynamic>>>[]) d.id: d.data()};
              return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _jobs,
                builder: (context, jSnap) {
                  final jobs = jSnap.data?.docs ?? const [];
                  final left = _left(drivers, fleet, jobs);
                  if (!wide) return left;
                  return Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Expanded(flex: 11, child: left),
                    Expanded(
                      flex: 9,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(0, 20, 20, 20),
                        child: _FleetMap(drivers: drivers, fleet: fleet, jobs: jobs),
                      ),
                    ),
                  ]);
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _left(List<QueryDocumentSnapshot<Map<String, dynamic>>> drivers, Map<String, Map<String, dynamic>> fleet, List<QueryDocumentSnapshot<Map<String, dynamic>>> jobs) {
    final wide = MediaQuery.of(context).size.width >= 1100;
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _orders,
      builder: (context, oSnap) {
        final orders = oSnap.data?.docs ?? const [];
        final collect = orders.where((o) => _toCollect.contains(o.data()['status'])).toList();
        final deliver = orders.where((o) => _toDeliver.contains(o.data()['status'])).toList();
        final online = drivers.where((d) => _isOnline(fleet[d.id])).length;
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(
            padding: EdgeInsets.fromLTRB(wide ? 20 : 12, 16, wide ? 20 : 12, 0),
            child: LayoutBuilder(builder: (context, c) {
              final isSmall = c.maxWidth < 460;
              final cols = c.maxWidth >= 620 ? 4 : 2;
              final spacing = isSmall ? 8.0 : 12.0;
              final w = (c.maxWidth - (cols - 1) * spacing) / cols;
              return Wrap(spacing: spacing, runSpacing: spacing, children: [
                SizedBox(width: w, child: _Kpi(Icons.inbox_rounded, '${collect.length}', 'To collect', _D.amber, _D.amberBg)),
                SizedBox(width: w, child: _Kpi(Icons.local_shipping_rounded, '${deliver.length}', 'To deliver', _D.emerald, _D.emeraldBg)),
                SizedBox(width: w, child: _Kpi(Icons.route_rounded, '${jobs.where((j) => j.data()['status'] != 'completed' && j.data()['status'] != 'failed').length}', 'Open jobs', _D.azure, _D.azureSoft)),
                SizedBox(width: w, child: _Kpi(Icons.wifi_tethering_rounded, '$online / ${drivers.length}', 'Drivers online', _D.violet, _D.violetBg)),
              ]);
            }),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Container(
              decoration: BoxDecoration(color: _D.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: _D.border)),
              child: TabBar(
                controller: _tabs,
                isScrollable: !wide,
                labelStyle: _D.t(13.5, w: FontWeight.w800),
                unselectedLabelStyle: _D.t(13.5),
                labelColor: _D.azure,
                unselectedLabelColor: _D.mut,
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                indicator: BoxDecoration(color: _D.azureSoft, borderRadius: BorderRadius.circular(12)),
                tabs: [
                  Tab(text: 'To collect (${collect.length})'),
                  Tab(text: 'To deliver (${deliver.length})'),
                  Tab(text: 'Jobs (${jobs.length})'),
                  Tab(text: 'Team (${drivers.length})'),
                ],
              ),
            ),
          ),
          Expanded(
            child: TabBarView(controller: _tabs, children: [
              _OrderQueue(orders: collect, type: 'pickup', drivers: drivers, fleet: fleet, onAssign: _assign, waiting: oSnap.connectionState == ConnectionState.waiting),
              _OrderQueue(orders: deliver, type: 'delivery', drivers: drivers, fleet: fleet, onAssign: _assign, waiting: oSnap.connectionState == ConnectionState.waiting),
              _JobsList(jobs: jobs, day: _day, onDay: _setDay, onRemove: _unassign, map: wide ? null : _FleetMap(drivers: drivers, fleet: fleet, jobs: jobs)),
              _Team(
                drivers: drivers,
                fleet: fleet,
                staff: _staff,
                onAdd: _addMember,
                onDeleteDriver: (id, name) => _deleteMember('drivers', id, name),
                onDeleteStaff: (id, name) => _deleteMember('staff', id, name),
              ),
            ]),
          ),
        ]);
      },
    );
  }

  // ---------------------------------------------------------------- assign
  Future<void> _assign(QueryDocumentSnapshot<Map<String, dynamic>> order, String type) async {
    final snaps = await Future.wait([
      _db.collection('drivers').get(),
      _db.collection('driver_locations').get(),
    ]);
    final drivers = snaps[0].docs;
    final fleet = {for (final d in snaps[1].docs) d.id: d.data()};
    if (!mounted) return;
    if (drivers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Add a driver in the Team tab first.')));
      _tabs.animateTo(3);
      return;
    }
    final res = await showDialog<_AssignResult>(context: context, builder: (_) => _AssignDialog(order: order.data(), type: type, drivers: drivers, fleet: fleet));
    if (res == null) return;

    final o = order.data();
    final b = _m(o['bookingData']);
    final pickup = type == 'pickup';
    final addr = _m(pickup ? b['selectedAddress'] : (b['deliveryAddress'] ?? b['selectedAddress']));
    final postcode = _s(addr['postalCode'] ?? addr['postcode']);
    LatLng? geo;
    if (addr['latitude'] != null && addr['longitude'] != null) {
      geo = LatLng((addr['latitude'] as num).toDouble(), (addr['longitude'] as num).toDouble());
    } else if (addr['lat'] != null && addr['lng'] != null) {
      geo = LatLng((addr['lat'] as num).toDouble(), (addr['lng'] as num).toDouble());
    } else if (o['geo'] != null && o['geo'] is Map && o['geo']['lat'] != null && o['geo']['lng'] != null) {
      geo = LatLng((o['geo']['lat'] as num).toDouble(), (o['geo']['lng'] as num).toDouble());
    }
    final date = _dayKey(res.date);
    final existingFuture = _db.collection('jobs').where('driverId', isEqualTo: res.driver.id).where('date', isEqualTo: date).get();
    final geoFuture = geo != null ? Future<LatLng?>.value(geo) : _geocode(postcode);
    final existing = await existingFuture;
    geo = await geoFuture;
    final items = _m(b['selectedItems']).values.map(_m).map((i) => {
          'name': _s(i['itemType']).isNotEmpty ? _s(i['itemType']) : (_s(i['description']).isNotEmpty ? _s(i['description']) : _s(i['category'])),
          'qty': (i['quantity'] as num?)?.toInt() ?? 1,
        });
    // services picked in the app's bag booking (Dry Clean, Wash…) — shown to the driver
    final services = ((b['selectedServices'] as List?) ?? const []).map(_s).where((e) => e.isNotEmpty).toList();
    final total = (_m(o['pricing'])['final'] ?? o['transactionAmount'] ?? b['totalPrice'] ?? 0) as num;
    final payment = _s(o['paymentMethod'] ?? b['paymentMethod']);
    final paid = _s(o['paymentStatus'] ?? b['paymentStatus']).toLowerCase() == 'paid';

    final jobRef = _db.collection('jobs').doc();
    final orderRef = order.reference;
    final status = pickup ? 'pickup_assigned' : 'delivery_assigned';
    final dName = _s(res.driver.data()['name']);
    final batch = _db.batch();
    batch.set(jobRef, {
      'orderId': _s(o['orderId']).isEmpty ? order.id : _s(o['orderId']),
      'orderDocId': order.id,
      'type': type,
      'status': 'assigned',
      'driverId': res.driver.id,
      'driverName': dName,
      'date': date,
      'sequence': existing.size + 1,
      'slot': _s(pickup ? b['collectionTime'] : b['deliveryTime']),
      'slotDay': _s(pickup ? b['collectionDate'] : b['deliveryDate']),
      'customerName': '${_s(b['firstName'])} ${_s(b['lastName'])}'.trim(),
      'customerUid': _s(o['userId']),
      'phone': _s(b['phone']).isNotEmpty
          ? _s(b['phone'])
          : (_s(b['phoneNumber']).isNotEmpty ? _s(b['phoneNumber']) : (_s(o['phone']).isNotEmpty ? _s(o['phone']) : _s(o['customerPhone']))),
      'address': {
        'line1': [_s(addr['buildingName']), _s(addr['line1'])].where((e) => e.isNotEmpty).join(', '),
        'line2': _s(addr['line2']),
        'city': _s(addr['city']).isEmpty ? 'London' : _s(addr['city']),
        'postalCode': postcode,
      },
      if (geo != null) 'geo': {'lat': geo.latitude, 'lng': geo.longitude},
      'notes': [res.note, _s(b['specialInstructions'])].where((e) => e.trim().isNotEmpty).join(' · '),
      // website saves collectionHandoff, the customer app saves collectionMethod
      'handoff': pickup
          ? _s(b['collectionHandoff']).ifEmpty(_s(b['collectionMethod']))
          : _s(b['deliveryHandoff']).ifEmpty(_s(b['deliveryMethod'])),
      'items': items.toList(),
      if (services.isNotEmpty) 'services': services,
      if (!pickup) 'bags': (o['bagCount'] as num?)?.toInt() ?? 0,
      if (!pickup) 'bagTags': (o['bagTags'] as List?) ?? const [],
      'amountDue': pickup || paid ? 0 : total,
      'paymentMethod': payment,
      'createdAt': FieldValue.serverTimestamp(),
      'createdBy': FirebaseAuth.instance.currentUser?.uid,
    });
    batch.update(orderRef, {
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
      pickup ? 'pickupJobId' : 'deliveryJobId': jobRef.id,
      pickup ? 'pickupDriver' : 'deliveryDriver': {'uid': res.driver.id, 'name': dName},
    });
    batch.set(orderRef.collection('history').doc(), {
      'status': status,
      'at': FieldValue.serverTimestamp(),
      'byRole': 'dispatch',
      'note': '${dName.split(' ').first} will ${pickup ? 'collect' : 'deliver'} on ${DateFormat('EEE d MMM').format(res.date)}',
    });

    final customerUid = _s(o['userId']);
    final displayId = _s(o['orderId']).isEmpty ? order.id : _s(o['orderId']);
    final notifTitle = pickup ? 'Driver assigned' : 'Delivery booked';
    final notifBody = pickup
        ? 'A driver has been assigned to collect #$displayId.'
        : 'A driver is scheduled to deliver #$displayId.';
    if (customerUid.isNotEmpty && customerUid != 'website_guest' && customerUid != 'dummy') {
      batch.set(_db.collection('users').doc(customerUid).collection('notifications').doc(), {
        'title': notifTitle,
        'body': notifBody,
        'category': 'orders',
        'theme': 'blue',
        'icon': 'person_pin',
        'orderId': order.id,
        'displayOrderId': displayId,
        'status': status,
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
    if (customerUid.isNotEmpty && customerUid != 'website_guest' && customerUid != 'dummy') {
      PushService.send(
        userId: customerUid,
        title: notifTitle,
        body: notifBody,
        data: {'type': 'order', 'orderId': order.id},
      );
    }
    PushService.send(
      collection: 'drivers',
      userId: res.driver.id,
      title: 'New ${pickup ? 'Pickup' : 'Delivery'} Job: #$displayId',
      body: '${_s(b['firstName'])} ${_s(b['lastName'])}'.trim().isNotEmpty
          ? '${_s(b['firstName'])} ${_s(b['lastName'])} ($postcode)'
          : postcode,
      data: {'type': 'job', 'orderId': order.id},
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('${pickup ? 'Pickup' : 'Delivery'} for #${_s(o['orderId'])} sent to $dName${geo == null ? ' (postcode not found — the driver app will look it up)' : ''}.'),
    ));
  }

  Future<void> _unassign(QueryDocumentSnapshot<Map<String, dynamic>> job) async {
    final j = job.data();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Remove this job?'),
        content: Text('The order goes back to the ${j['type'] == 'pickup' ? '“To collect”' : '“To deliver”'} list.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Keep')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Remove')),
        ],
      ),
    );
    if (ok != true) return;
    final b = _db.batch();
    final orderRef = _db.collection('orders').doc(_s(j['orderDocId']));
    final back = j['type'] == 'pickup' ? 'confirmed' : 'ready_for_delivery';
    b.delete(job.reference);
    b.update(orderRef, {'status': back, 'updatedAt': FieldValue.serverTimestamp()});
    b.set(orderRef.collection('history').doc(), {'status': back, 'at': FieldValue.serverTimestamp(), 'byRole': 'dispatch', 'note': 'Driver job removed'});
    await b.commit();
  }

  Future<void> _deleteMember(String collection, String id, String name) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete team member?'),
        content: Text('Remove "$name" permanently from Firebase? They will no longer appear in Dispatch or Team.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _D.rose),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final b = _db.batch();
    b.delete(_db.collection(collection).doc(id));
    if (collection == 'drivers') {
      b.delete(_db.collection('driver_locations').doc(id));
      b.delete(_db.collection('staff').doc(id));
    }
    await b.commit();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Deleted "$name" from Firebase.')));
  }

  // ---------------------------------------------------------------- team
  Future<void> _addMember() async {
    final res = await showDialog<_MemberResult>(context: context, builder: (_) => const _MemberDialog());
    if (res == null) return;
    try {
      // A second Firebase app creates the login without signing the admin out.
      final app = Firebase.apps.any((a) => a.name == 'team-creator')
          ? Firebase.app('team-creator')
          : await Firebase.initializeApp(name: 'team-creator', options: Firebase.app().options);
      final auth = FirebaseAuth.instanceFor(app: app);
      final cred = await auth.createUserWithEmailAndPassword(email: res.email, password: res.password);
      await cred.user?.updateDisplayName(res.name);
      final uid = cred.user!.uid;
      await auth.signOut();
      final b = _db.batch();
      b.set(_db.collection('staff').doc(uid), {
        'role': res.role,
        'name': res.name,
        'email': res.email,
        'phone': res.phone,
        'hubName': 'London Hub',
        'createdAt': FieldValue.serverTimestamp(),
      });
      if (res.role == 'driver') {
        b.set(_db.collection('drivers').doc(uid), {
          'name': res.name,
          'email': res.email,
          'phone': res.phone,
          'vehicle': {'make': res.make, 'colour': res.colour, 'reg': res.reg.toUpperCase()},
          'isOnline': true,
          'status': 'active',
          'createdAt': FieldValue.serverTimestamp(),
        });
        b.set(_db.collection('driver_locations').doc(uid), {
          'name': res.name,
          'online': true,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
      await b.commit();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${res.name} can now sign in to the ${res.role == 'driver' ? 'driver' : 'intake'} app.')));
    } on FirebaseAuthException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message ?? 'Could not create the account.')));
    }
  }
}

// ======================================================================= widgets

class _Kpi extends StatelessWidget {
  final IconData icon;
  final String value, label;
  final Color c, bg;
  const _Kpi(this.icon, this.value, this.label, this.c, this.bg);
  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < 460;
    return Container(
      padding: EdgeInsets.all(narrow ? 10 : 14),
      decoration: BoxDecoration(color: _D.card, borderRadius: BorderRadius.circular(16), border: Border.all(color: _D.border)),
      child: Row(children: [
        Container(width: narrow ? 34 : 40, height: narrow ? 34 : 40, decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(narrow ? 10 : 12)), child: Icon(icon, color: c, size: narrow ? 18 : 21)),
        SizedBox(width: narrow ? 8 : 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(value, style: _D.h(narrow ? 17 : 20)),
          Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: _D.t(narrow ? 11 : 12, c: _D.mut)),
        ])),
      ]),
    );
  }
}

class _Empty extends StatelessWidget {
  final IconData icon;
  final String title, text;
  const _Empty(this.icon, this.title, this.text);
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(30),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 64, height: 64, decoration: BoxDecoration(color: _D.azureSoft, borderRadius: BorderRadius.circular(18)), child: Icon(icon, color: _D.azure, size: 30)),
            const SizedBox(height: 14),
            Text(title, style: _D.h(17)),
            const SizedBox(height: 4),
            Text(text, textAlign: TextAlign.center, style: _D.t(13, c: _D.mut)),
          ]),
        ),
      );
}

class _Pill extends StatelessWidget {
  final String text;
  final Color c, bg;
  const _Pill(this.text, this.c, this.bg);
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(7)),
        child: Text(text, style: _D.t(11, c: c, w: FontWeight.w800)),
      );
}

class _OrderQueue extends StatelessWidget {
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> orders;
  final String type;
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> drivers;
  final Map<String, Map<String, dynamic>> fleet;
  final Future<void> Function(QueryDocumentSnapshot<Map<String, dynamic>>, String) onAssign;
  final bool waiting;
  const _OrderQueue({required this.orders, required this.type, required this.drivers, required this.fleet, required this.onAssign, required this.waiting});

  @override
  Widget build(BuildContext context) {
    if (waiting) return const Center(child: CircularProgressIndicator());
    final pickup = type == 'pickup';
    if (orders.isEmpty) {
      return _Empty(pickup ? Icons.inbox_rounded : Icons.local_shipping_rounded, pickup ? 'Nothing to collect' : 'Nothing to deliver',
          pickup ? 'New bookings from the website and app appear here instantly.' : 'Orders marked “Ready” in the intake app appear here.');
    }
    final list = [...orders]..sort((a, b) => (_date(a.data()['createdAt']) ?? DateTime(2000)).compareTo(_date(b.data()['createdAt']) ?? DateTime(2000)));
    final isMobile = MediaQuery.sizeOf(context).width < 540;
    return ListView.separated(
      padding: EdgeInsets.fromLTRB(isMobile ? 12 : 20, 16, isMobile ? 12 : 20, 24),
      itemCount: list.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final o = list[i].data();
        final b = _m(o['bookingData']);
        final addr = _m(pickup ? b['selectedAddress'] : (b['deliveryAddress'] ?? b['selectedAddress']));
        final failed = _s(o['status']).endsWith('_failed');
        final day = _s(pickup ? b['collectionDate'] : b['deliveryDate']);
        final time = _s(pickup ? b['collectionTime'] : b['deliveryTime']);
        final assignBtn = FilledButton.icon(
          onPressed: () => onAssign(list[i], type),
          icon: const Icon(Icons.person_add_alt_1_rounded, size: 16),
          label: const Text('Assign'),
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF073B1B),
            padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 16, vertical: isMobile ? 10 : 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );

        if (isMobile) {
          return Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: _D.card, borderRadius: BorderRadius.circular(16), border: Border.all(color: failed ? const Color(0xFFFECDD3) : _D.border)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(color: pickup ? _D.amberBg : _D.emeraldBg, borderRadius: BorderRadius.circular(10)),
                  child: Icon(pickup ? Icons.north_east_rounded : Icons.south_west_rounded, color: pickup ? _D.amber : _D.emerald, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Wrap(spacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
                    Text('#${_s(o['orderId'])}', style: _D.t(12, c: _D.mut, w: FontWeight.w700)),
                    if (failed) _Pill(pickup ? 'Collection failed' : 'Delivery failed', _D.rose, _D.roseBg),
                    if (_s(o['source']) == 'website') _Pill('Website', _D.azure, _D.azureSoft),
                  ]),
                ),
                assignBtn,
              ]),
              const SizedBox(height: 8),
              Text('${_s(b['firstName'])} ${_s(b['lastName'])}'.trim().isEmpty ? 'Customer' : '${_s(b['firstName'])} ${_s(b['lastName'])}'.trim(), style: _D.t(14.5, w: FontWeight.w800)),
              Text([_s(addr['line1']), _s(addr['postalCode'])].where((e) => e.isNotEmpty).join(' · '), maxLines: 1, overflow: TextOverflow.ellipsis, style: _D.t(12, c: _D.mut)),
              const SizedBox(height: 5),
              Row(children: [
                const Icon(Icons.schedule_rounded, size: 14, color: _D.faint),
                const SizedBox(width: 5),
                Flexible(child: Text([day, time].where((e) => e.isNotEmpty).join(' · ').ifEmpty('Any time'), style: _D.t(12, w: FontWeight.w700))),
              ]),
            ]),
          );
        }

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: _D.card, borderRadius: BorderRadius.circular(16), border: Border.all(color: failed ? const Color(0xFFFECDD3) : _D.border)),
          child: Row(children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(color: pickup ? _D.amberBg : _D.emeraldBg, borderRadius: BorderRadius.circular(13)),
              child: Icon(pickup ? Icons.north_east_rounded : Icons.south_west_rounded, color: pickup ? _D.amber : _D.emerald),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Wrap(spacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
                  Text('#${_s(o['orderId'])}', style: _D.t(12, c: _D.mut, w: FontWeight.w700)),
                  if (failed) _Pill(pickup ? 'Collection failed' : 'Delivery failed', _D.rose, _D.roseBg),
                  if (_s(o['source']) == 'website') _Pill('Website', _D.azure, _D.azureSoft),
                ]),
                const SizedBox(height: 2),
                Text('${_s(b['firstName'])} ${_s(b['lastName'])}'.trim().isEmpty ? 'Customer' : '${_s(b['firstName'])} ${_s(b['lastName'])}'.trim(), style: _D.t(15, w: FontWeight.w800)),
                Text([_s(addr['line1']), _s(addr['postalCode'])].where((e) => e.isNotEmpty).join(' · '), maxLines: 1, overflow: TextOverflow.ellipsis, style: _D.t(12.5, c: _D.mut)),
                const SizedBox(height: 6),
                Row(children: [
                  const Icon(Icons.schedule_rounded, size: 15, color: _D.faint),
                  const SizedBox(width: 5),
                  Flexible(child: Text([day, time].where((e) => e.isNotEmpty).join(' · ').ifEmpty('Any time'), style: _D.t(12.5, w: FontWeight.w700))),
                ]),
              ]),
            ),
            const SizedBox(width: 10),
            assignBtn,
          ]),
        );
      },
    );
  }
}

extension on String {
  String ifEmpty(String other) => isEmpty ? other : this;
}

class _JobsList extends StatelessWidget {
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> jobs;
  final DateTime day;
  final ValueChanged<DateTime> onDay;
  final Future<void> Function(QueryDocumentSnapshot<Map<String, dynamic>>) onRemove;
  final Widget? map;
  const _JobsList({required this.jobs, required this.day, required this.onDay, required this.onRemove, this.map});

  static const _status = {
    'assigned': ('Assigned', _D.azure, _D.azureSoft),
    'en_route': ('On the way', _D.violet, _D.violetBg),
    'arrived': ('Arrived', _D.amber, _D.amberBg),
    'completed': ('Done', _D.emerald, _D.emeraldBg),
    'failed': ('Failed', _D.rose, _D.roseBg),
  };

  @override
  Widget build(BuildContext context) {
    final byDriver = <String, List<QueryDocumentSnapshot<Map<String, dynamic>>>>{};
    for (final j in jobs) {
      byDriver.putIfAbsent(_s(j.data()['driverName']).ifEmpty('Driver'), () => []).add(j);
    }
    for (final l in byDriver.values) {
      l.sort((a, b) => ((a.data()['sequence'] as num?) ?? 0).compareTo((b.data()['sequence'] as num?) ?? 0));
    }
    final today = DateTime.now();
    return ListView(padding: const EdgeInsets.fromLTRB(20, 16, 20, 24), children: [
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final (label, d) in [('Today', today), ('Tomorrow', today.add(const Duration(days: 1)))])
          ChoiceChip(label: Text(label), selected: _dayKey(d) == _dayKey(day), onSelected: (_) => onDay(d)),
        ActionChip(
          avatar: const Icon(Icons.calendar_month_rounded, size: 17),
          label: Text(DateFormat('EEE d MMM').format(day)),
          onPressed: () async {
            final d = await showDatePicker(context: context, initialDate: day, firstDate: today.subtract(const Duration(days: 30)), lastDate: today.add(const Duration(days: 60)));
            if (d != null) onDay(d);
          },
        ),
      ]),
      if (map != null) ...[const SizedBox(height: 14), SizedBox(height: 320, child: map)],
      const SizedBox(height: 14),
      if (jobs.isEmpty) const SizedBox(height: 260, child: _Empty(Icons.route_rounded, 'No jobs for this day', 'Assign orders from “To collect” or “To deliver”.')),
      for (final e in byDriver.entries) ...[
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
          child: Row(children: [
            const Icon(Icons.local_shipping_rounded, size: 18, color: _D.mut),
            const SizedBox(width: 8),
            Text(e.key, style: _D.h(16)),
            const Spacer(),
            Text('${e.value.where((j) => j.data()['status'] == 'completed').length}/${e.value.length} done', style: _D.t(12.5, c: _D.mut)),
          ]),
        ),
        for (final j in e.value)
          Builder(builder: (context) {
            final m = j.data();
            final st = _status[_s(m['status'])] ?? ('Assigned', _D.azure, _D.azureSoft);
            final pickup = m['type'] == 'pickup';
            final a = _m(m['address']);
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
              decoration: BoxDecoration(color: _D.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: _D.border)),
              child: Row(children: [
                CircleAvatar(radius: 15, backgroundColor: pickup ? _D.amberBg : _D.emeraldBg, child: Text('${m['sequence'] ?? ''}', style: _D.t(12, c: pickup ? _D.amber : _D.emerald, w: FontWeight.w800))),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Wrap(spacing: 6, children: [_Pill(pickup ? 'Pickup' : 'Delivery', pickup ? _D.amber : _D.emerald, pickup ? _D.amberBg : _D.emeraldBg), _Pill(st.$1, st.$2, st.$3)]),
                    const SizedBox(height: 4),
                    Text('${_s(m['customerName']).ifEmpty('Customer')} · #${_s(m['orderId'])}', style: _D.t(14, w: FontWeight.w800)),
                    Text([_s(a['line1']), _s(a['postalCode']), _s(m['slot'])].where((e) => e.isNotEmpty).join(' · '), style: _D.t(12.5, c: _D.mut)),
                  ]),
                ),
                if (m['status'] == 'assigned')
                  IconButton(tooltip: 'Remove job', onPressed: () => onRemove(j), icon: const Icon(Icons.close_rounded, color: _D.faint)),
              ]),
            );
          }),
      ],
    ]);
  }
}

class _Team extends StatelessWidget {
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> drivers;
  final Map<String, Map<String, dynamic>> fleet;
  final Stream<QuerySnapshot<Map<String, dynamic>>> staff;
  final VoidCallback onAdd;
  final void Function(String id, String name) onDeleteDriver;
  final void Function(String id, String name) onDeleteStaff;
  const _Team({
    required this.drivers,
    required this.fleet,
    required this.staff,
    required this.onAdd,
    required this.onDeleteDriver,
    required this.onDeleteStaff,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: staff,
      builder: (context, s) {
        final facility = (s.data?.docs ?? const []).where((d) => d.data()['role'] != 'driver').toList();
        return ListView(padding: const EdgeInsets.fromLTRB(20, 16, 20, 24), children: [
          Row(children: [
            Expanded(child: Text('Drivers and facility staff sign in to their apps with these accounts.', style: _D.t(13, c: _D.mut))),
            const SizedBox(width: 12),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.person_add_rounded, size: 18),
              label: const Text('Add member'),
              style: FilledButton.styleFrom(backgroundColor: _D.azure, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            ),
          ]),
          const SizedBox(height: 16),
          Text('Drivers', style: _D.h(16)),
          const SizedBox(height: 8),
          if (drivers.isEmpty) Text('No drivers yet.', style: _D.t(13, c: _D.mut)),
          for (final d in drivers)
            Builder(builder: (_) {
              final m = d.data(), loc = fleet[d.id];
              final online = _isOnline(loc, m);
              final v = _m(m['vehicle']);
              final name = _s(m['name']).ifEmpty('Driver');
              return _MemberRow(
                name: name,
                sub: [_s(m['phone']), [_s(v['colour']), _s(v['make']), _s(v['reg'])].where((e) => e.isNotEmpty).join(' ')].where((e) => e.isNotEmpty).join(' · '),
                trailing: online ? 'Online · ${_ago(_date(loc?['updatedAt']))}' : 'Offline',
                good: online,
                icon: Icons.local_shipping_rounded,
                onDelete: () => onDeleteDriver(d.id, name),
              );
            }),
          const SizedBox(height: 18),
          Text('Facility & admin', style: _D.h(16)),
          const SizedBox(height: 8),
          if (facility.isEmpty) Text('No facility staff yet.', style: _D.t(13, c: _D.mut)),
          for (final f in facility)
            _MemberRow(
              name: _s(f.data()['name']).ifEmpty('Staff'),
              sub: [_s(f.data()['email']), _s(f.data()['hubName'])].where((e) => e.isNotEmpty).join(' · '),
              trailing: _s(f.data()['role']) == 'inspector' ? 'Intake app' : _s(f.data()['role']),
              good: true,
              icon: Icons.warehouse_rounded,
              onDelete: () => onDeleteStaff(f.id, _s(f.data()['name']).ifEmpty('Staff')),
            ),
        ]);
      },
    );
  }
}

class _MemberRow extends StatelessWidget {
  final String name, sub, trailing;
  final bool good;
  final IconData icon;
  final VoidCallback onDelete;
  const _MemberRow({required this.name, required this.sub, required this.trailing, required this.good, required this.icon, required this.onDelete});
  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: _D.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: _D.border)),
        child: Row(children: [
          CircleAvatar(radius: 19, backgroundColor: _D.azureSoft, child: Icon(icon, color: _D.azure, size: 19)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(name, style: _D.t(14.5, w: FontWeight.w800)), if (sub.isNotEmpty) Text(sub, style: _D.t(12.5, c: _D.mut))])),
          Row(children: [
            Container(width: 8, height: 8, decoration: BoxDecoration(color: good ? const Color(0xFF22C55E) : _D.faint, shape: BoxShape.circle)),
            const SizedBox(width: 6),
            Text(trailing, style: _D.t(12.5, c: good ? _D.emerald : _D.mut, w: FontWeight.w700)),
          ]),
          const SizedBox(width: 4),
          IconButton(
            tooltip: 'Delete member',
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline_rounded, color: _D.rose, size: 20),
          ),
        ]),
      );
}

// ---------------------------------------------------------------- fleet map
/// Live fleet: every van that is reporting, its stops, and — for a van on its way —
/// the road route to the customer with the minutes left (like the customer sees it).
class _FleetMap extends StatefulWidget {
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> drivers;
  final Map<String, Map<String, dynamic>> fleet;
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> jobs;
  const _FleetMap({required this.drivers, required this.fleet, required this.jobs});
  @override
  State<_FleetMap> createState() => _FleetMapState();
}

class _FleetMapState extends State<_FleetMap> {
  final _routes = <String, (List<LatLng>, int)>{}; // jobId → road route + minutes
  final _routedFrom = <String, LatLng>{}; // where the van was when the route was made
  final _loading = <String>{};
  static const _dist = Distance();

  /// Asks for a new route when a van starts a trip or has moved 150 m since the last one.
  void _refresh(String jobId, LatLng van, LatLng stop) {
    final from = _routedFrom[jobId];
    if (_loading.contains(jobId) || (from != null && _dist(from, van) < 150)) return;
    _loading.add(jobId);
    _route(van, stop).then((r) {
      _loading.remove(jobId);
      if (!mounted) return;
      setState(() {
        _routedFrom[jobId] = van;
        _routes[jobId] = r ?? ([van, stop], 0);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final jobsById = {for (final j in widget.jobs) j.id: j.data()};
    final vans = <Marker>[];
    final lines = <Polyline>[];
    for (final e in widget.fleet.entries) {
      final m = e.value;
      final lat = (m['lat'] as num?)?.toDouble(), lng = (m['lng'] as num?)?.toDouble();
      if (lat == null || lng == null || !_isOnline(m)) continue;
      final here = LatLng(lat, lng);
      final job = jobsById[_s(m['activeJobId'])];
      final g = _m(job?['geo']);
      final onTrip = job != null && job['status'] == 'en_route' && g['lat'] != null;
      int? mins;
      if (onTrip) {
        final stop = LatLng((g['lat'] as num).toDouble(), (g['lng'] as num).toDouble());
        final id = _s(m['activeJobId']);
        WidgetsBinding.instance.addPostFrameCallback((_) => _refresh(id, here, stop));
        final r = _routes[id];
        if (r != null) {
          // keep the line starting at the van even between route refreshes
          final pts = [here, ...r.$1.skipWhile((p) => _dist(p, here) > 60 && r.$1.indexOf(p) < 3)];
          lines.add(Polyline(points: pts, strokeWidth: 9, color: Colors.white));
          lines.add(Polyline(points: pts, strokeWidth: 5, color: const Color(0xFF1D7BF2)));
          mins = r.$2 > 0 ? r.$2 : null;
        }
      }
      final heading = (m['heading'] as num?)?.toDouble() ?? 0;
      final name = _s(m['name']).split(' ').first;
      vans.add(Marker(
        point: here,
        width: 150,
        height: 64,
        alignment: Alignment.topCenter,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: onTrip ? const Color(0xFF1D7BF2) : _D.navy, borderRadius: BorderRadius.circular(8)),
            child: Text(onTrip ? '$name · ${mins != null ? '$mins min' : 'on the way'}' : (m['activeOrderId'] != null ? '$name · on job' : name),
                style: _D.t(11, c: Colors.white, w: FontWeight.w800)),
          ),
          const SizedBox(height: 3),
          Transform.rotate(
            angle: heading * 3.1415926535 / 180,
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(color: onTrip ? const Color(0xFF1D7BF2) : _D.azure, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 3), boxShadow: const [BoxShadow(color: Color(0x44000000), blurRadius: 8)]),
              child: Icon(heading > 0 ? Icons.navigation_rounded : Icons.local_shipping_rounded, color: Colors.white, size: 16),
            ),
          ),
        ]),
      ));
    }
    final stops = <Marker>[];
    for (final j in widget.jobs) {
      final m = j.data();
      final g = _m(m['geo']);
      if (g['lat'] == null || m['status'] == 'completed' || m['status'] == 'failed') continue;
      final pickup = m['type'] == 'pickup';
      stops.add(Marker(
        point: LatLng((g['lat'] as num).toDouble(), (g['lng'] as num).toDouble()),
        width: 30,
        height: 38,
        alignment: Alignment.topCenter,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(color: pickup ? _D.amber : _D.emerald, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2.5), boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 6)]),
            alignment: Alignment.center,
            child: Text('${m['sequence'] ?? ''}', style: _D.t(11, c: Colors.white, w: FontWeight.w800)),
          ),
          Container(width: 3, height: 8, color: pickup ? _D.amber : _D.emerald),
        ]),
      ));
    }
    return Container(
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(18), border: Border.all(color: _D.border)),
      clipBehavior: Clip.antiAlias,
      child: Stack(children: [
        FlutterMap(
          options: const MapOptions(initialCenter: _defaultCenter, initialZoom: 11),
          children: [
            TileLayer(
              urlTemplate: _tiles,
              subdomains: const ['mt0', 'mt1', 'mt2', 'mt3'],
              maxZoom: 20,
              userAgentPackageName: 'com.drycleanplus.admin',
            ),
            PolylineLayer(polylines: lines),
            MarkerLayer(markers: stops),
            MarkerLayer(markers: vans),
            const RichAttributionWidget(attributions: [TextSourceAttribution('Google Maps')]),
          ],
        ),
        Positioned(
          left: 12,
          top: 12,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: const [BoxShadow(color: Color(0x22000000), blurRadius: 12)]),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFF22C55E), shape: BoxShape.circle)),
              const SizedBox(width: 7),
              Text('Live fleet · ${vans.length} van${vans.length == 1 ? '' : 's'}', style: _D.t(12.5, w: FontWeight.w800)),
              const SizedBox(width: 12),
              _legend(_D.amber, 'Pickup'),
              const SizedBox(width: 8),
              _legend(_D.emerald, 'Delivery'),
              const SizedBox(width: 8),
              _legend(const Color(0xFF1D7BF2), 'On the way'),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _legend(Color c, String l) => Row(children: [Container(width: 9, height: 9, decoration: BoxDecoration(color: c, shape: BoxShape.circle)), const SizedBox(width: 4), Text(l, style: _D.t(11.5, c: _D.mut))]);
}

// ---------------------------------------------------------------- dialogs
class _AssignResult {
  final QueryDocumentSnapshot<Map<String, dynamic>> driver;
  final DateTime date;
  final String note;
  _AssignResult(this.driver, this.date, this.note);
}

class _AssignDialog extends StatefulWidget {
  final Map<String, dynamic> order;
  final String type;
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> drivers;
  final Map<String, Map<String, dynamic>> fleet;
  const _AssignDialog({required this.order, required this.type, required this.drivers, required this.fleet});
  @override
  State<_AssignDialog> createState() => _AssignDialogState();
}

class _AssignDialogState extends State<_AssignDialog> {
  late QueryDocumentSnapshot<Map<String, dynamic>> _driver = widget.drivers.firstWhere((d) => _isOnline(widget.fleet[d.id], d.data()), orElse: () => widget.drivers.first);
  /// the customer's chosen day (defaults to 48 hours after collection for delivery)
  late final DateTime? _chosen = () {
    final b = _m(widget.order['bookingData']);
    final pickup = widget.type == 'pickup';
    final d = _slotDay(_s(pickup ? b['collectionDate'] : b['deliveryDate']), _created(widget.order['createdAt']));
    final today = DateTime.now();
    final nowDay = DateTime(today.year, today.month, today.day);

    if (!pickup) {
      // 48-hour delivery rule: Delivery must be at least 48 hours (2 days) after collection
      final pickupDay = _slotDay(_s(b['collectionDate']), _created(widget.order['createdAt'])) ?? _created(widget.order['createdAt']) ?? nowDay;
      final minDelivery = DateTime(pickupDay.year, pickupDay.month, pickupDay.day).add(const Duration(days: 2));
      final earliestValid = minDelivery.isBefore(nowDay) ? nowDay : minDelivery;
      if (d == null || d.isBefore(earliestValid)) {
        return earliestValid;
      }
      return d;
    }

    return d == null || d.isBefore(nowDay) ? null : d;
  }();
  late DateTime _date = _chosen ?? DateTime.now();
  final _note = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final b = _m(widget.order['bookingData']);
    final pickup = widget.type == 'pickup';
    final slot = [_s(pickup ? b['collectionDate'] : b['deliveryDate']), _s(pickup ? b['collectionTime'] : b['deliveryTime'])].where((e) => e.isNotEmpty).join(' · ');
    final now = DateTime.now();
    final nowDay = DateTime(now.year, now.month, now.day);
    final pickupDay = _slotDay(_s(b['collectionDate']), _created(widget.order['createdAt'])) ?? _created(widget.order['createdAt']) ?? nowDay;
    final minDelivery = DateTime(pickupDay.year, pickupDay.month, pickupDay.day).add(const Duration(days: 2));
    final earliestAllowedDay = (!pickup && minDelivery.isAfter(nowDay)) ? minDelivery : nowDay;

    return AlertDialog(
      title: Text('${pickup ? 'Collection' : 'Delivery'} · #${_s(widget.order['orderId'])}', style: _D.h(19)),
      content: SizedBox(
        width: 440,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (slot.isNotEmpty) Text('Customer chose: $slot', style: _D.t(13, c: _D.mut)),
          if (!pickup) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFBFDBFE)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.schedule_rounded, size: 16, color: Color(0xFF1D4ED8)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '48-Hour Rule: Earliest delivery is ${DateFormat('EEE d MMM').format(earliestAllowedDay)}',
                      style: _D.t(12, c: const Color(0xFF1D4ED8), w: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 14),
          Text('Driver', style: _D.t(13, w: FontWeight.w800)),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            initialValue: _driver.id,
            decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
            items: [
              for (final d in widget.drivers)
                DropdownMenuItem(
                  value: d.id,
                  child: Row(children: [
                    Container(width: 8, height: 8, decoration: BoxDecoration(color: _isOnline(widget.fleet[d.id], d.data()) ? const Color(0xFF22C55E) : _D.faint, shape: BoxShape.circle)),
                    const SizedBox(width: 8),
                    Text(_s(d.data()['name']).ifEmpty('Driver')),
                  ]),
                ),
            ],
            onChanged: (v) => setState(() => _driver = widget.drivers.firstWhere((d) => d.id == v)),
          ),
          const SizedBox(height: 14),
          Text('Day', style: _D.t(13, w: FontWeight.w800)),
          const SizedBox(height: 6),
          Wrap(spacing: 8, runSpacing: 6, children: [
            if (_chosen != null) ChoiceChip(avatar: const Icon(Icons.event_available_rounded, size: 17), label: Text('Scheduled · ${DateFormat('EEE d MMM').format(_chosen)}'), selected: _dayKey(_chosen) == _dayKey(_date), onSelected: (_) => setState(() => _date = _chosen)),
            for (final (l, d) in [('Today', nowDay), ('Tomorrow', nowDay.add(const Duration(days: 1)))])
              if ((pickup || !d.isBefore(earliestAllowedDay)) && (_chosen == null || _dayKey(_chosen) != _dayKey(d)))
                ChoiceChip(label: Text(l), selected: _dayKey(d) == _dayKey(_date), onSelected: (_) => setState(() => _date = d)),
            if (!pickup && _dayKey(_date) != _dayKey(earliestAllowedDay) && (_chosen == null || _dayKey(_chosen) != _dayKey(earliestAllowedDay)))
              ChoiceChip(
                avatar: const Icon(Icons.bolt_rounded, size: 16),
                label: Text('Earliest (48h) · ${DateFormat('EEE d MMM').format(earliestAllowedDay)}'),
                selected: _dayKey(earliestAllowedDay) == _dayKey(_date),
                onSelected: (_) => setState(() => _date = earliestAllowedDay),
              ),
            ActionChip(
              avatar: const Icon(Icons.calendar_month_rounded, size: 17),
              label: Text(DateFormat('EEE d MMM').format(_date)),
              onPressed: () async {
                final d = await showDatePicker(
                  context: context,
                  initialDate: _date.isBefore(earliestAllowedDay) ? earliestAllowedDay : _date,
                  firstDate: earliestAllowedDay,
                  lastDate: nowDay.add(const Duration(days: 60)),
                );
                if (d != null) setState(() => _date = d);
              },
            ),
          ]),
          const SizedBox(height: 14),
          TextField(controller: _note, decoration: const InputDecoration(labelText: 'Note for the driver (optional)', border: OutlineInputBorder(), isDense: true)),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(context, _AssignResult(_driver, _date, _note.text.trim())), child: const Text('Send to driver')),
      ],
    );
  }
}

class _MemberResult {
  final String role, name, email, password, phone, make, colour, reg;
  _MemberResult(this.role, this.name, this.email, this.password, this.phone, this.make, this.colour, this.reg);
}

class _MemberDialog extends StatefulWidget {
  const _MemberDialog();
  @override
  State<_MemberDialog> createState() => _MemberDialogState();
}

class _MemberDialogState extends State<_MemberDialog> {
  final _form = GlobalKey<FormState>();
  String _role = 'driver';
  final _c = {for (final k in ['name', 'email', 'password', 'phone', 'make', 'colour', 'reg']) k: TextEditingController()};

  Widget _f(String k, String label, {bool req = true, bool secret = false, TextInputType? type}) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: TextFormField(
          controller: _c[k],
          obscureText: secret,
          keyboardType: type,
          decoration: InputDecoration(labelText: label, border: const OutlineInputBorder(), isDense: true),
          validator: (v) {
            if (req && (v == null || v.trim().isEmpty)) return 'Required';
            if (k == 'email' && v != null && !v.contains('@')) return 'Enter a valid email';
            if (k == 'password' && v != null && v.length < 8) return 'At least 8 characters';
            return null;
          },
        ),
      );

  @override
  Widget build(BuildContext context) {
    final driver = _role == 'driver';
    return AlertDialog(
      title: Text('Add team member', style: _D.h(19)),
      content: SizedBox(
        width: 440,
        child: Form(
          key: _form,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'driver', label: Text('Driver'), icon: Icon(Icons.local_shipping_rounded)),
                  ButtonSegment(value: 'inspector', label: Text('Facility'), icon: Icon(Icons.warehouse_rounded)),
                ],
                selected: {_role},
                onSelectionChanged: (s) => setState(() => _role = s.first),
              ),
              const SizedBox(height: 14),
              _f('name', 'Full name'),
              _f('email', 'Email (used to sign in)', type: TextInputType.emailAddress),
              _f('password', 'Temporary password', secret: true),
              _f('phone', 'Phone', req: driver, type: TextInputType.phone),
              if (driver) ...[
                Row(children: [Expanded(child: _f('colour', 'Van colour', req: false)), const SizedBox(width: 8), Expanded(child: _f('make', 'Van make / model', req: false))]),
                _f('reg', 'Registration', req: false),
              ],
            ]),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            if (!_form.currentState!.validate()) return;
            String v(String k) => _c[k]!.text.trim();
            Navigator.pop(context, _MemberResult(_role, v('name'), v('email'), _c['password']!.text, v('phone'), v('make'), v('colour'), v('reg')));
          },
          child: const Text('Create account'),
        ),
      ],
    );
  }
}
