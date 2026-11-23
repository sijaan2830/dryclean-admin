import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/firebase_admin_service.dart';
import '../providers/firebase_auth_provider.dart';
import '../services/fcm_sender_service.dart';
import '../widgets/responsive.dart';

// ─── Design Tokens ────────────────────────────────────────────────────────────

class _P {
  // Surfaces
  static const Color canvas   = Color(0xFFF5F7F5);
  static const Color card     = Color(0xFFFFFFFF);
  static const Color sideBar  = Color(0xFF0F172A);

  // Brand
  static const Color navy     = Color(0xFF0F172A);
  static const Color azure    = Color(0xFF047857);
  static const Color azureSoft= Color(0xFFECFDF5);
  static const Color azureMid = Color(0xFFA7F3D0);
  static const Color info     = Color(0xFF1D4ED8);
  static const Color infoBg   = Color(0xFFEFF6FF);

  // Semantic
  static const Color emerald  = Color(0xFF059669);
  static const Color emeraldBg= Color(0xFFECFDF5);
  static const Color amber    = Color(0xFFD97706);
  static const Color amberBg  = Color(0xFFFFFBEB);
  static const Color violet   = Color(0xFF7C3AED);
  static const Color violetBg = Color(0xFFF5F3FF);
  static const Color teal     = Color(0xFF0D9488);
  static const Color tealBg   = Color(0xFFF0FDFA);
  static const Color rose     = Color(0xFFE11D48);
  static const Color roseBg   = Color(0xFFFFF1F2);
  static const Color slate    = Color(0xFF64748B);

  // Text
  static const Color textPrimary   = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color textMuted     = Color(0xFF94A3B8);
  static const Color border        = Color(0xFFE5E9E7);
  static const Color borderSoft    = Color(0xFFF1F5F9);
}

class _T {
  static TextStyle heading(double sz, {FontWeight w = FontWeight.w700, Color c = _P.textPrimary}) =>
      GoogleFonts.plusJakartaSans(fontSize: sz, fontWeight: w, color: c, letterSpacing: -0.4);

  static TextStyle body(double sz, {FontWeight w = FontWeight.w400, Color c = _P.textSecondary}) =>
      GoogleFonts.plusJakartaSans(fontSize: sz, fontWeight: w, color: c);

  static TextStyle label(double sz, {FontWeight w = FontWeight.w600, Color c = _P.textSecondary}) =>
      GoogleFonts.plusJakartaSans(fontSize: sz, fontWeight: w, color: c, letterSpacing: 0.1);
}

// ─── Status Config ────────────────────────────────────────────────────────────

class _Status {
  final String label;
  final Color color;
  final Color bg;
  final IconData icon;

  const _Status(this.label, this.color, this.bg, this.icon);

  /// The shared status list (website, customer app, driver app, intake app, admin).
  static const Map<String, _Status> map = {
    'pending':            _Status('Order Placed',       _P.amber,   _P.amberBg,   Icons.inbox_rounded),
    'confirmed':          _Status('Confirmed',          _P.amber,   _P.amberBg,   Icons.event_available_rounded),
    'pickup_assigned':    _Status('Driver Assigned',    _P.info,    _P.infoBg, Icons.assignment_ind_rounded),
    'pickup_en_route':    _Status('Driver On The Way',  _P.info,    _P.infoBg, Icons.local_shipping_rounded),
    'pickup_arrived':     _Status('Driver Outside',     _P.info,    _P.infoBg, Icons.where_to_vote_rounded),
    'pickup_failed':      _Status('Collection Failed',  _P.rose,    _P.roseBg,    Icons.event_busy_rounded),
    'collected':          _Status('Collected',          _P.violet,  _P.violetBg,  Icons.inventory_2_rounded),
    'at_facility':        _Status('At Facility',        _P.violet,  _P.violetBg,  Icons.warehouse_rounded),
    'inspecting':         _Status('Inspecting',         _P.violet,  _P.violetBg,  Icons.fact_check_rounded),
    'awaiting_approval':  _Status('Awaiting Approval',  _P.amber,   _P.amberBg,   Icons.pending_actions_rounded),
    'cleaning':           _Status('Cleaning',           _P.violet,  _P.violetBg,  Icons.local_laundry_service_rounded),
    'quality_check':      _Status('Quality Check',      _P.violet,  _P.violetBg,  Icons.verified_rounded),
    'ready_for_delivery': _Status('Ready',              _P.teal,    _P.tealBg,    Icons.checkroom_rounded),
    'delivery_assigned':  _Status('Delivery Assigned',  _P.teal,    _P.tealBg,    Icons.assignment_ind_rounded),
    'out_for_delivery':   _Status('Out for Delivery',   _P.teal,    _P.tealBg,    Icons.local_shipping_rounded),
    'delivery_arrived':   _Status('Driver Outside',     _P.teal,    _P.tealBg,    Icons.where_to_vote_rounded),
    'delivery_failed':    _Status('Delivery Failed',    _P.rose,    _P.roseBg,    Icons.event_busy_rounded),
    'delivered':          _Status('Delivered',          _P.emerald, _P.emeraldBg, Icons.check_circle_rounded),
    'cancelled':          _Status('Cancelled',          _P.rose,    _P.roseBg,    Icons.cancel_rounded),
    // legacy values from older app versions
    'processing':         _Status('Cleaning',           _P.violet,  _P.violetBg,  Icons.local_laundry_service_rounded),
    'in_progress':        _Status('Cleaning',           _P.violet,  _P.violetBg,  Icons.local_laundry_service_rounded),
    'ready':              _Status('Ready',              _P.teal,    _P.tealBg,    Icons.checkroom_rounded),
    'completed':          _Status('Delivered',          _P.emerald, _P.emeraldBg, Icons.check_circle_rounded),
    // filter groups
    'grp_collect':        _Status('To Collect',         _P.amber,   _P.amberBg,   Icons.inbox_rounded),
    'grp_facility':       _Status('In Facility',        _P.violet,  _P.violetBg,  Icons.local_laundry_service_rounded),
    'grp_delivery':       _Status('Delivery',           _P.teal,    _P.tealBg,    Icons.local_shipping_rounded),
  };

  static const List<String> all = [
    'pending', 'confirmed', 'pickup_assigned', 'pickup_en_route', 'pickup_arrived', 'pickup_failed',
    'collected', 'at_facility', 'inspecting', 'awaiting_approval', 'cleaning', 'quality_check',
    'ready_for_delivery', 'delivery_assigned', 'out_for_delivery', 'delivery_arrived', 'delivery_failed',
    'delivered', 'cancelled',
  ];

  static const Map<String, Set<String>> groups = {
    'grp_collect': {'pending', 'confirmed', 'pickup_assigned', 'pickup_en_route', 'pickup_arrived', 'pickup_failed'},
    'grp_facility': {'collected', 'at_facility', 'inspecting', 'awaiting_approval', 'cleaning', 'quality_check', 'processing', 'in_progress'},
    'grp_delivery': {'ready_for_delivery', 'delivery_assigned', 'out_for_delivery', 'delivery_arrived', 'delivery_failed', 'ready'},
    'delivered': {'delivered', 'completed'},
    'cancelled': {'cancelled'},
  };

  static _Status of(String status) =>
      map[status] ?? _Status(status.toUpperCase(), _P.slate, _P.borderSoft, Icons.help_outline_rounded);
}

// ─── Orders Screen ────────────────────────────────────────────────────────────

class OrdersScreenRealtime extends StatefulWidget {
  const OrdersScreenRealtime({super.key});

  @override
  State<OrdersScreenRealtime> createState() => _OrdersScreenRealtimeState();
}

class _OrdersScreenRealtimeState extends State<OrdersScreenRealtime>
    with SingleTickerProviderStateMixin {
  String _selectedStatus = 'all';
  final List<String> _statusOptions = [
    'all', 'grp_collect', 'awaiting_approval', 'grp_facility', 'grp_delivery', 'delivered', 'cancelled',
  ];

  late AnimationController _headerAnim;
  late Animation<double> _headerFade;

  @override
  void initState() {
    super.initState();
    _headerAnim = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _headerFade = CurvedAnimation(parent: _headerAnim, curve: Curves.easeOut);
    _headerAnim.forward();
  }

  @override
  void dispose() {
    _headerAnim.dispose();
    super.dispose();
  }

  String _filterLabel(String s) {
    if (s == 'all') return 'All';
    return _Status.of(s).label;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _P.canvas,
      body: Column(
        children: [
          FadeTransition(opacity: _headerFade, child: _buildHeader()),
          Expanded(child: _buildOrdersList()),
        ],
      ),
    );
  }

  // ── Header ───────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Container(
      decoration: BoxDecoration(
        color: _P.card,
        border: Border(bottom: BorderSide(color: _P.border)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(Responsive.isMobile(context) ? 14 : 24, 16, Responsive.isMobile(context) ? 14 : 24, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: _P.azureSoft,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.receipt_long_rounded, color: _P.azure, size: 20),
                ),
                const SizedBox(width: 14),
                Text('Orders', style: _T.heading(22)),
                const Spacer(),
                _LiveBadge(),
              ],
            ),
            const SizedBox(height: 20),
            _buildFilterTabs(),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterTabs() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _statusOptions.map((status) {
          final isSelected = _selectedStatus == status;
          final cfg = status == 'all' ? null : _Status.of(status);

          return Padding(
            padding: const EdgeInsets.only(right: 6, bottom: 1),
            child: GestureDetector(
              onTap: () => setState(() => _selectedStatus = status),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? (cfg?.color ?? _P.azure)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (cfg != null && isSelected) ...[
                      Icon(cfg.icon, size: 13, color: Colors.white),
                      const SizedBox(width: 5),
                    ],
                    Text(
                      _filterLabel(status),
                      style: _T.label(12,
                          c: isSelected ? Colors.white : _P.textSecondary),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── Orders List ───────────────────────────────────────────────────────────────

  Widget _buildOrdersList() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: context.watch<FirebaseAdminService>().getOrdersStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: _P.azure, strokeWidth: 2),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: _P.roseBg, borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.error_outline_rounded, color: _P.rose, size: 32),
                ),
                const SizedBox(height: 12),
                Text('Failed to load orders', style: _T.heading(16)),
                const SizedBox(height: 4),
                Text('${snapshot.error}', style: _T.body(13)),
              ],
            ),
          );
        }

        final orders = snapshot.data ?? [];
        final filtered = _selectedStatus == 'all'
            ? orders
            : orders.where((o) => (_Status.groups[_selectedStatus] ?? {_selectedStatus}).contains(o['status'])).toList();

        if (filtered.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 72, height: 72,
                  decoration: BoxDecoration(color: _P.azureSoft, borderRadius: BorderRadius.circular(20)),
                  child: const Icon(Icons.inbox_rounded, color: _P.azure, size: 32),
                ),
                const SizedBox(height: 16),
                Text('No orders here', style: _T.heading(18)),
                const SizedBox(height: 6),
                Text(
                  _selectedStatus == 'all'
                      ? 'Orders will appear once customers place them'
                      : 'No orders with this status yet',
                  style: _T.body(13),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          itemCount: filtered.length,
          itemBuilder: (_, i) => _AnimatedCard(
            index: i,
            child: OrderCard(
              order: filtered[i],
              onStatusChanged: (newStatus) async {
                debugPrint('OrdersScreen: Status changing to $newStatus for order ${filtered[i]['id']}');
                final adminService = context.read<FirebaseAdminService>();
                final fcmService = context.read<FCMSenderService>();
                
                // Update status in Firestore
                await adminService.updateOrderStatus(filtered[i]['id'], newStatus);
                debugPrint('OrdersScreen: Status updated in Firestore');

                // Handle Notifications for Delivered or Cancelled
                if (newStatus == 'delivered' || newStatus == 'cancelled') {
                  final userId = filtered[i]['userId'] as String?;
                  final orderIdString = filtered[i]['orderId'] as String? ?? 'Order';
                  
                  debugPrint('OrdersScreen: Attempting notification for user $userId');
                  
                  if (userId != null && userId.isNotEmpty) {
                    final token = await adminService.getUserFCMToken(userId);
                    debugPrint('OrdersScreen: FCM Token found: ${token != null ? 'YES' : 'NO'}');
                    
                    if (token != null) {
                      final title = newStatus == 'delivered' ? 'Order Delivered!' : 'Order Cancelled';
                      final body = newStatus == 'delivered' 
                          ? 'Your order #$orderIdString has been delivered successfully. Thank you!'
                          : 'Your order #$orderIdString has been cancelled. Please contact support for help.';
                      
                      debugPrint('OrdersScreen: Sending FCM Notification now...');
                      final result = await fcmService.sendNotification(
                        title: title,
                        body: body,
                        token: token,
                        data: {
                          'type': 'order',
                          'orderId': filtered[i]['id'], // Pass the Firestore Doc ID for deep linking
                          'displayOrderId': orderIdString, // Human readable ID
                        },
                      );

                      debugPrint('OrdersScreen: Notification result success: ${result['success']}');

                      if (result['unregistered'] == true) {
                        debugPrint('OrdersScreen: FCM token for user $userId is unregistered. Cleaning up.');
                        await adminService.removeUserFCMToken(userId);
                      }
                    } else {
                      debugPrint('OrdersScreen: No FCM token found for user $userId in Firestore');
                    }
                  } else {
                    debugPrint('OrdersScreen: No userId associated with this order');
                  }
                }
              },
            ),
          ),
        );
      },
    );
  }
}

// ─── Animated Card Wrapper ────────────────────────────────────────────────────

class _AnimatedCard extends StatefulWidget {
  final int index;
  final Widget child;
  const _AnimatedCard({required this.index, required this.child});

  @override
  State<_AnimatedCard> createState() => _AnimatedCardState();
}

class _AnimatedCardState extends State<_AnimatedCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _fade  = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: const Offset(0, 0.04), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));

    Future.delayed(Duration(milliseconds: 40 * widget.index), () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      FadeTransition(opacity: _fade, child: SlideTransition(position: _slide, child: widget.child));
}

// ─── Live Badge ───────────────────────────────────────────────────────────────

class _LiveBadge extends StatefulWidget {
  @override
  State<_LiveBadge> createState() => _LiveBadgeState();
}

class _LiveBadgeState extends State<_LiveBadge>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 2))
      ..repeat(reverse: true);
    _pulse = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _P.emeraldBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _P.emerald.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _pulse,
            builder: (_, __) => Container(
              width: 7, height: 7,
              decoration: BoxDecoration(
                color: _P.emerald.withOpacity(_pulse.value),
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: _P.emerald.withOpacity(0.4 * _pulse.value), blurRadius: 4)],
              ),
            ),
          ),
          const SizedBox(width: 6),
          Text('Live', style: _T.label(11, c: _P.emerald)),
        ],
      ),
    );
  }
}

// ─── Order Card ───────────────────────────────────────────────────────────────

class OrderCard extends StatefulWidget {
  final Map<String, dynamic> order;
  final Function(String) onStatusChanged;

  const OrderCard({super.key, required this.order, required this.onStatusChanged});

  @override
  State<OrderCard> createState() => _OrderCardState();
}

class _OrderCardState extends State<OrderCard> with SingleTickerProviderStateMixin {
  bool _isExpanded = false;
  late bool _isActive;
  late AnimationController _expandCtrl;
  late Animation<double> _expandAnim;

  @override
  void initState() {
    super.initState();
    _isActive = widget.order['isActive'] as bool? ?? true;
    _expandCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 260));
    _expandAnim = CurvedAnimation(parent: _expandCtrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _expandCtrl.dispose();
    super.dispose();
  }

  void _toggleExpand() {
    setState(() => _isExpanded = !_isExpanded);
    _isExpanded ? _expandCtrl.forward() : _expandCtrl.reverse();
  }

  // ── Kept all original helpers ─────────────────────────────────────────────

  String _mapOldStatusToNew(String status) {
    switch (status) {
      case 'processing':
      case 'in_progress': return 'cleaning';
      case 'ready':       return 'ready_for_delivery';
      case 'in_transit':  return 'out_for_delivery';
      case 'completed':   return 'delivered';
      default:            return _Status.all.contains(status) ? status : 'pending';
    }
  }

  String _getTotalAmount() {
    final total = widget.order['transactionAmount'] as num? ??
                  widget.order['totalPrice'] as num? ?? 0.0;
    return total.toStringAsFixed(2);
  }

  String _getOrderPrice() {
    debugPrint('Order card price debug - Available keys: ${widget.order.keys}');
    final bookingData = widget.order['bookingData'] as Map<String, dynamic>? ?? {};

    final totalPrice        = widget.order['totalPrice'] as num?;
    final transactionAmount = widget.order['transactionAmount'] as num?;
    final price             = widget.order['price'] as num?;
    final amount            = widget.order['amount'] as num?;
    final bookingTotalPrice = bookingData['totalPrice'] as num?;
    final bookingPrice      = bookingData['price'] as num?;
    final bookingAmount     = bookingData['amount'] as num?;

    if (totalPrice        != null && totalPrice > 0)        return totalPrice.toStringAsFixed(2);
    if (transactionAmount != null && transactionAmount > 0) return transactionAmount.toStringAsFixed(2);
    if (price             != null && price > 0)             return price.toStringAsFixed(2);
    if (amount            != null && amount > 0)            return amount.toStringAsFixed(2);
    if (bookingTotalPrice != null && bookingTotalPrice > 0) return bookingTotalPrice.toStringAsFixed(2);
    if (bookingPrice      != null && bookingPrice > 0)      return bookingPrice.toStringAsFixed(2);
    if (bookingAmount     != null && bookingAmount > 0)     return bookingAmount.toStringAsFixed(2);
    return '0.00';
  }

  String _getAddressString(Map<String, dynamic> bookingData) {
    debugPrint('Getting address string from booking data...');

    if (widget.order['type'] == 'prepaid_pack') {
      if (bookingData['address']           != null) return bookingData['address'].toString();
      if (bookingData['deliveryAddress']   != null) return bookingData['deliveryAddress'].toString();
      if (bookingData['collectionAddress'] != null) return bookingData['collectionAddress'].toString();
      if (bookingData['prepaidPackData'] is Map) {
        final packData = bookingData['prepaidPackData'] as Map<String, dynamic>;
        if (packData['address']         != null) return packData['address'].toString();
        if (packData['deliveryAddress'] != null) return packData['deliveryAddress'].toString();
      }
    }

    Map<String, dynamic>? addr;
    if      (bookingData['defaultAddress']  != null) addr = bookingData['defaultAddress']  as Map<String, dynamic>;
    else if (bookingData['selectedAddress'] != null) addr = bookingData['selectedAddress'] as Map<String, dynamic>;
    else if (bookingData['addresses'] is List && (bookingData['addresses'] as List).isNotEmpty)
      addr = (bookingData['addresses'] as List)[0] as Map<String, dynamic>;

    if (addr != null) {
      return [
        addr['line1'],
        if (addr['line2'] != null && addr['line2'].toString().isNotEmpty) addr['line2'],
        addr['city'],
        addr['postalCode'],
      ].where((e) => e != null).join(', ');
    }
    return 'No address available';
  }

  List<String> _extractServices(Map<String, dynamic> order, Map<String, dynamic> bookingData) {
    final list = <String>[];

    // 1. Check selectedServices list
    final bServices = bookingData['selectedServices'] ?? order['selectedServices'] ?? order['services'] ?? bookingData['services'];
    if (bServices is List) {
      for (final s in bServices) {
        final str = s?.toString().trim() ?? '';
        if (str.isNotEmpty && str != 'All Services' && !list.contains(str)) {
          list.add(str);
        }
      }
    }

    // 2. Check single service field
    final single = bookingData['service'] ?? bookingData['selectedService'] ?? order['service'] ?? order['selectedService'];
    if (single != null) {
      final str = single.toString().trim();
      if (str.isNotEmpty && str != 'All Services' && !list.contains(str)) {
        list.add(str);
      }
    }

    // 3. Check prepaid pack name
    final pack = bookingData['prepaidPackName'] ?? order['prepaidPackName'];
    if (pack != null && pack.toString().trim().isNotEmpty) {
      final str = 'Prepaid: ${pack.toString().trim()}';
      if (!list.contains(str)) list.add(str);
    }

    // 4. If still empty, infer from items' categories
    if (list.isEmpty) {
      final items = _extractItems(order, bookingData);
      for (final itm in items) {
        final cat = (itm['category'] ?? '').toString().trim();
        if (cat.isNotEmpty && !list.contains(cat)) {
          list.add(cat);
        }
      }
    }

    return list;
  }

  List<Map<String, dynamic>> _extractItems(Map<String, dynamic> order, Map<String, dynamic> bookingData) {
    final result = <Map<String, dynamic>>[];
    final raw = bookingData['selectedItems'] ?? order['selectedItems'] ?? order['items'] ?? bookingData['items'];
    if (raw == null) return result;

    if (raw is Map) {
      for (final entry in raw.entries) {
        final val = entry.value;
        if (val is Map) {
          final cat = (val['category'] ?? '').toString().trim();
          final type = (val['itemType'] ?? val['name'] ?? val['title'] ?? entry.key).toString().trim();
          final p = val['price'];
          final desc = (val['description'] ?? '').toString().trim();
          final qty = (val['quantity'] as num?)?.toInt() ?? 1;

          if (cat.isNotEmpty || type.isNotEmpty || p != null) {
            result.add({
              'category': cat,
              'itemType': type.isNotEmpty ? type : (cat.isNotEmpty ? cat : 'Item'),
              'price': p,
              'quantity': qty,
              'description': desc,
            });
          }
        } else if (val != null) {
          result.add({
            'category': '',
            'itemType': entry.key.toString(),
            'price': val,
            'quantity': 1,
            'description': '',
          });
        }
      }
    } else if (raw is List) {
      for (final itm in raw) {
        if (itm is Map) {
          final cat = (itm['category'] ?? '').toString().trim();
          final type = (itm['itemType'] ?? itm['name'] ?? itm['title'] ?? '').toString().trim();
          final p = itm['price'];
          final desc = (itm['description'] ?? '').toString().trim();
          final qty = (itm['quantity'] as num?)?.toInt() ?? 1;

          if (cat.isNotEmpty || type.isNotEmpty || p != null) {
            result.add({
              'category': cat,
              'itemType': type.isNotEmpty ? type : (cat.isNotEmpty ? cat : 'Item'),
              'price': p,
              'quantity': qty,
              'description': desc,
            });
          }
        } else if (itm != null && itm.toString().trim().isNotEmpty) {
          result.add({
            'category': '',
            'itemType': itm.toString().trim(),
            'price': '0.00',
            'quantity': 1,
            'description': '',
          });
        }
      }
    }

    return result;
  }

  String _getOrderTypeLabel(Map<String, dynamic> order, Map<String, dynamic> bookingData, List<String> services, List<Map<String, dynamic>> items) {
    if (order['type'] == 'prepaid_pack' || bookingData['prepaidPackName'] != null) {
      final name = bookingData['prepaidPackName'] ?? order['prepaidPackName'];
      return name != null ? 'Prepaid Pack ($name)' : 'Prepaid Pack';
    }

    if (items.isNotEmpty) {
      if (services.isNotEmpty) {
        return 'Itemized Order (${services.join(', ')})';
      }
      return 'Itemized Order';
    }

    if (services.isNotEmpty) {
      return 'Bag Service (${services.join(', ')})';
    }

    if (order['type'] == 'quick_bag') {
      return 'Bag Service (Count at facility)';
    }

    return 'Regular Order (Count at facility)';
  }

  String _getOrderItemsString(Map<String, dynamic> bookingData) {
    final items = _extractItems(widget.order, bookingData);
    final services = _extractServices(widget.order, bookingData);
    if (items.isNotEmpty) {
      return items.map((i) {
        final cat = (i['category'] ?? '').toString().trim();
        final type = (i['itemType'] ?? i['name'] ?? '').toString().trim();
        final title = cat.isNotEmpty && type.isNotEmpty && cat != type ? '$cat – $type' : (type.isNotEmpty ? type : 'Item');
        final p = i['price']?.toString() ?? '0.00';
        return '$title: £$p';
      }).join('\n');
    }
    if (services.isNotEmpty) {
      return 'Services: ${services.join(', ')} (Count at facility)';
    }
    return 'Items to be counted at facility';
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isMobile    = Responsive.isMobile(context);
    final bookingData = Map<String, dynamic>.from(widget.order['bookingData'] ?? {});
    final services    = _extractServices(widget.order, bookingData);
    final items       = _extractItems(widget.order, bookingData);
    final orderTypeLabel = _getOrderTypeLabel(widget.order, bookingData, services, items);

    final status = _Status.of(widget.order['status'] ?? '');
    final isPrepaid = widget.order['type'] == 'prepaid_pack';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: _P.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _P.border),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 3)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          children: [
            // ── Status accent bar ──
            Container(
              height: 3,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [status.color, status.color.withOpacity(0.3)]),
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Top row: ID + status + price ──
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text('#${widget.order['orderId']}',
                                    style: _T.heading(15)),
                                if (isPrepaid)
                                  _Chip(label: 'PREPAID', color: _P.violet, bg: _P.violetBg),
                                _StatusBadge(status: status),
                              ],
                            ),
                            const SizedBox(height: 8),
                            // ── Prominent Service Badges ──
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: [
                                if (services.isNotEmpty)
                                  ...services.map((s) => Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: _P.azureSoft,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: _P.azure.withOpacity(0.3)),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.checkroom_rounded, size: 12, color: _P.azure),
                                        const SizedBox(width: 4),
                                        Text(s, style: _T.label(11, c: _P.azure)),
                                      ],
                                    ),
                                  )),
                                if (items.isEmpty)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: _P.emeraldBg,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: _P.emerald.withOpacity(0.3)),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.inventory_2_outlined, size: 12, color: _P.emerald),
                                        const SizedBox(width: 4),
                                        Text('Count at facility', style: _T.label(11, c: _P.emerald)),
                                      ],
                                    ),
                                  ),
                                if (items.isNotEmpty)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: _P.canvas,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: _P.border),
                                    ),
                                    child: Text('${items.length} item${items.length == 1 ? '' : 's'}', style: _T.label(11, c: _P.textSecondary)),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('£${_getTotalAmount()}',
                              style: _T.heading(20, w: FontWeight.w800, c: _P.textPrimary)),
                          Text('Total', style: _T.body(11, c: _P.textMuted)),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),
                  Divider(color: _P.borderSoft, height: 1),
                  const SizedBox(height: 16),

                  // ── Customer / Collection / Delivery ──
                  if (isMobile)
                    Column(
                      children: [
                        _buildCustomerTile(bookingData),
                        const SizedBox(height: 10),
                        Row(children: [
                          Expanded(child: _buildDateTile('Collection', bookingData['collectionDate'], bookingData['collectionTime'], Icons.upload_rounded, _P.azure, _P.azureSoft)),
                          const SizedBox(width: 10),
                          Expanded(child: _buildDateTile('Delivery', bookingData['deliveryDate'], bookingData['deliveryTime'], Icons.download_rounded, _P.emerald, _P.emeraldBg)),
                        ]),
                      ],
                    )
                  else
                    Row(children: [
                      Expanded(child: _buildCustomerTile(bookingData)),
                      const SizedBox(width: 10),
                      _buildDateTile('Collection', bookingData['collectionDate'], bookingData['collectionTime'], Icons.upload_rounded, _P.azure, _P.azureSoft),
                      const SizedBox(width: 10),
                      _buildDateTile('Delivery', bookingData['deliveryDate'], bookingData['deliveryTime'], Icons.download_rounded, _P.emerald, _P.emeraldBg),
                    ]),
                ],
              ),
            ),

            // ── Action bar ──
            Container(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Row(
                children: [
                  _TextAction(
                    label: _isExpanded ? 'Show Less' : 'Show More',
                    icon: _isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                    onTap: _toggleExpand,
                  ),
                  const Spacer(),
                  _OutlineAction(
                    label: 'Print',
                    icon: Icons.print_outlined,
                    onTap: () => _printOrderDetails(),
                  ),
                ],
              ),
            ),

            // ── Expanded panel ──
            SizeTransition(
              sizeFactor: _expandAnim,
              child: _buildExpandedPanel(bookingData, items, services, orderTypeLabel),
            ),
          ],
        ),
      ),
    );
  }

  // ── Customer tile ─────────────────────────────────────────────────────────

  Widget _buildCustomerTile(Map<String, dynamic> bookingData) {
    return InkWell(
      onTap: () => _showCustomerDetailsModal(context, bookingData),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: _P.canvas,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _P.border),
        ),
        child: Row(
          children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(color: _P.azureSoft, borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.person_rounded, size: 18, color: _P.azure),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${bookingData['firstName'] ?? 'Unknown'} ${bookingData['lastName'] ?? ''}',
                    style: _T.label(13, c: _P.textPrimary),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(bookingData['phone'] ?? 'No phone',
                      style: _T.body(11)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, size: 16, color: _P.textMuted),
          ],
        ),
      ),
    );
  }

  Widget _buildDateTile(String title, dynamic date, dynamic time, IconData icon, Color color, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 12, color: color),
              const SizedBox(width: 4),
              Text(title, style: _T.label(10, c: color)),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            date != null ? '$date ${time ?? ''}' : 'N/A',
            style: _T.label(11, c: color.withOpacity(0.9)),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // ── Expanded panel ────────────────────────────────────────────────────────

  Widget _buildExpandedPanel(
    Map<String, dynamic> bookingData,
    List<Map<String, dynamic>> items,
    List<String> services,
    String orderTypeLabel,
  ) {
    return Container(
      margin: const EdgeInsets.fromLTRB(18, 0, 18, 18),
      decoration: BoxDecoration(
        color: _P.canvas,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _P.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Items Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text('ORDER ITEMS & SERVICES', style: _T.label(12, c: _P.textMuted).copyWith(letterSpacing: 0.8)),
                Text(orderTypeLabel, style: _T.label(11, c: _P.azure)),
              ],
            ),
          ),
          const SizedBox(height: 8),

          if (items.isNotEmpty) ...[
            ...items.map((item) => _ItemRow(item: item)),
          ] else ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _P.azureSoft.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _P.azure.withOpacity(0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.inventory_2_outlined, size: 16, color: _P.azure),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            services.isNotEmpty ? 'Selected Services: ${services.join(', ')}' : 'Standard Service Order',
                            style: _T.heading(13, c: _P.azure),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'Items will be counted, inspected & priced at the facility upon collection.',
                      style: _T.body(12, c: _P.textMuted),
                    ),
                  ],
                ),
              ),
            ),
          ],

          // Special instructions or customer note
          if ((bookingData['specialInstructions'] != null && bookingData['specialInstructions'].toString().trim().isNotEmpty) ||
              (bookingData['instructions'] != null && bookingData['instructions'].toString().trim().isNotEmpty)) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _P.amberBg.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _P.amber.withOpacity(0.3)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.note_outlined, size: 15, color: _P.amber),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Customer Note: ${(bookingData['specialInstructions'] ?? bookingData['instructions'] ?? '').toString().trim()}',
                        style: _T.body(12, c: _P.textPrimary),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],

          if (bookingData['address'] != null) ...[
            Divider(color: _P.border, height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  const Icon(Icons.location_on_rounded, size: 14, color: _P.textMuted),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(bookingData['address'].toString(),
                        style: _T.body(12)),
                  ),
                ],
              ),
            ),
          ],

          Divider(color: _P.border, height: 24),

          // Status dropdown
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: DropdownButtonFormField<String>(
              value: _mapOldStatusToNew(widget.order['status'] ?? 'pending'),
              decoration: InputDecoration(
                labelText: 'Update Status',
                labelStyle: _T.body(13),
                filled: true,
                fillColor: _P.card,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: _P.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: _P.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: _P.azure, width: 1.5),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                isDense: true,
              ),
              style: _T.body(13, c: _P.textPrimary),
              dropdownColor: _P.card,
              borderRadius: BorderRadius.circular(12),
              items: _Status.all
                  .map((s) {
                    final cfg = _Status.of(s);
                    return DropdownMenuItem(
                      value: s,
                      child: Row(
                        children: [
                          Container(
                            width: 8, height: 8,
                            decoration: BoxDecoration(color: cfg.color, shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 8),
                          Text(cfg.label, style: _T.body(13, c: _P.textPrimary)),
                        ],
                      ),
                    );
                  }).toList(),
              onChanged: (v) { if (v != null) widget.onStatusChanged(v); },
            ),
          ),
        ],
      ),
    );
  }

  // ── Customer Details Modal ────────────────────────────────────────────────

  void _showCustomerDetailsModal(BuildContext context, Map<String, dynamic> bookingData) {
    final isMobile = Responsive.isMobile(context);
    final services = _extractServices(widget.order, bookingData);
    final items = _extractItems(widget.order, bookingData);
    final orderTypeLabel = _getOrderTypeLabel(widget.order, bookingData, services, items);

    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: isMobile
            ? const EdgeInsets.all(12)
            : const EdgeInsets.symmetric(horizontal: 60, vertical: 40),
        child: Container(
          width: isMobile ? double.infinity : 560,
          clipBehavior: Clip.antiAlias,
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.88),
          decoration: BoxDecoration(
            color: _P.card,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.14), blurRadius: 40, offset: const Offset(0, 16))],
          ),
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.fromLTRB(22, 20, 16, 20),
                decoration: const BoxDecoration(
                  color: _P.navy,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                      child: const Icon(Icons.person_rounded, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Customer Details',
                              style: _T.heading(17, c: Colors.white)),
                          Text('${bookingData['firstName'] ?? ''} ${bookingData['lastName'] ?? ''}',
                              style: _T.body(12, c: Colors.white60)),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded, color: Colors.white60, size: 20),
                    ),
                  ],
                ),
              ),

              // Body
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _DetailSection(title: 'Personal', rows: [
                        _DetailRow('Full Name',      '${bookingData['firstName'] ?? 'Unknown'} ${bookingData['lastName'] ?? ''}', Icons.person_outline_rounded),
                        _DetailRow('Email',          bookingData['email'] ?? 'No email',  Icons.email_outlined),
                        _DetailRow('Phone',          bookingData['phone'] ?? 'No phone',  Icons.phone_outlined),
                        _DetailRow('Customer Type',  bookingData['customerType'] ?? 'individual', Icons.badge_outlined),
                        if (bookingData['companyName'] != null && bookingData['companyName'].toString().isNotEmpty)
                          _DetailRow('Company', bookingData['companyName'], Icons.business_outlined),
                      ]),
                      const SizedBox(height: 20),
                      _DetailSection(title: 'Order Information', rows: [
                        _DetailRow('Order ID',     '#${widget.order['orderId']}', Icons.receipt_outlined),
                        _DetailRow('Order Type',   orderTypeLabel, Icons.shopping_bag_outlined),
                        if (services.isNotEmpty)
                          _DetailRow('Selected Services', services.join(', '), Icons.checkroom_outlined),
                        if (bookingData['prepaidPackName'] != null)
                          _DetailRow('Prepaid Pack', bookingData['prepaidPackName'].toString(), Icons.card_membership_outlined),
                        _DetailRow('Status',       _Status.of(widget.order['status'] ?? '').label, Icons.info_outline_rounded),
                        _DetailRow('Payment Method', (widget.order['paymentMethod'] ?? bookingData['paymentMethod'] ?? 'Pay on delivery').toString().toUpperCase(), Icons.payment_outlined),
                        _DetailRow('Total Amount', '£${_getTotalAmount()}', Icons.payments_outlined),
                      ]),
                      const SizedBox(height: 20),
                      _DetailSection(title: 'Items & Services', rows: [
                        if (items.isNotEmpty)
                          ...items.map((i) {
                            final cat = (i['category'] ?? '').toString().trim();
                            final type = (i['itemType'] ?? i['name'] ?? '').toString().trim();
                            final title = cat.isNotEmpty && type.isNotEmpty && cat.toLowerCase() != type.toLowerCase()
                                ? '$cat – $type'
                                : (type.isNotEmpty ? type : 'Item');
                            final p = i['price']?.toString() ?? '0.00';
                            final qty = (i['quantity'] as num?)?.toInt() ?? 1;
                            return _DetailRow(qty > 1 ? '$title (x$qty)' : title, '£$p', Icons.check_circle_outline);
                          })
                        else
                          _DetailRow('Items Status', services.isNotEmpty ? '${services.join(', ')} — Count at facility' : 'Count at facility', Icons.inventory_2_outlined),
                      ]),
                      const SizedBox(height: 20),
                      _DetailSection(title: 'Address', rows: [
                        ..._buildAddressRows(bookingData),
                      ]),
                      const SizedBox(height: 20),
                      _DetailSection(title: 'Collection & Delivery', rows: [
                        _DetailRow('Collection Date', bookingData['collectionDate']?.toString() ?? 'N/A', Icons.calendar_today_outlined),
                        _DetailRow('Collection Time', bookingData['collectionTime']?.toString() ?? 'N/A', Icons.schedule_outlined),
                        _DetailRow('Delivery Date',   bookingData['deliveryDate']?.toString()   ?? 'N/A', Icons.calendar_today_outlined),
                        _DetailRow('Delivery Time',   bookingData['deliveryTime']?.toString()   ?? 'N/A', Icons.schedule_outlined),
                        if (bookingData['instructions'] != null && bookingData['instructions'].toString().isNotEmpty)
                          _DetailRow('Instructions', bookingData['instructions'].toString(), Icons.note_outlined),
                        if (bookingData['specialInstructions'] != null && bookingData['specialInstructions'].toString().isNotEmpty)
                          _DetailRow('Special Instructions', bookingData['specialInstructions'].toString(), Icons.note_alt_outlined),
                      ]),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<_DetailRow> _buildAddressRows(Map<String, dynamic> bookingData) {
    Map<String, dynamic>? addr;
    if      (bookingData['selectedAddress'] != null) addr = bookingData['selectedAddress'] as Map<String, dynamic>;
    else if (bookingData['defaultAddress']  != null) addr = bookingData['defaultAddress']  as Map<String, dynamic>;
    else if (bookingData['addresses'] is List && (bookingData['addresses'] as List).isNotEmpty)
      addr = (bookingData['addresses'] as List)[0] as Map<String, dynamic>;

    if (addr != null) {
      return [
        _DetailRow('Line 1',      addr['line1']?.toString()      ?? 'N/A', Icons.location_on_outlined),
        if (addr['line2'] != null && addr['line2'].toString().isNotEmpty)
          _DetailRow('Line 2',    addr['line2'].toString(),                Icons.location_on_outlined),
        _DetailRow('City',        addr['city']?.toString()       ?? 'N/A', Icons.location_city_outlined),
        _DetailRow('Postal Code', addr['postalCode']?.toString() ?? 'N/A', Icons.local_post_office_outlined),
      ];
    }
    return [_DetailRow('Address', 'No address available', Icons.location_off_outlined)];
  }

  // ── Print Dialog ──────────────────────────────────────────────────────────

  void _printOrderDetails() {
    final bookingData = widget.order['bookingData'] as Map<String, dynamic>? ?? {};
    final services = _extractServices(widget.order, bookingData);
    final items = _extractItems(widget.order, bookingData);
    final orderTypeLabel = _getOrderTypeLabel(widget.order, bookingData, services, items);

    final itemsBlock = items.isNotEmpty
        ? items.map((i) {
            final cat = (i['category'] ?? '').toString().trim();
            final type = (i['itemType'] ?? i['name'] ?? '').toString().trim();
            final title = cat.isNotEmpty && type.isNotEmpty && cat.toLowerCase() != type.toLowerCase()
                ? '$cat – $type'
                : (type.isNotEmpty ? type : 'Item');
            final p = i['price']?.toString() ?? '0.00';
            final qty = (i['quantity'] as num?)?.toInt() ?? 1;
            return '• $title ${qty > 1 ? '(x$qty)' : ''}: £$p';
          }).join('\n')
        : 'Services: ${services.isNotEmpty ? services.join(', ') : 'Standard Cleaning'}\n(Items to be counted and priced at facility)';

    final orderDetails = '''
ORDER DETAILS
=============
Order ID: #${widget.order['orderId']}
Order Type: $orderTypeLabel
Selected Services: ${services.isNotEmpty ? services.join(', ') : 'Standard Cleaning'}
Status: ${widget.order['status']?.toString().toUpperCase() ?? 'PENDING'}
Payment: ${(widget.order['paymentMethod'] ?? bookingData['paymentMethod'] ?? 'COD').toString().toUpperCase()}
Total Price: £${_getTotalAmount()}

CUSTOMER INFORMATION
====================
Name: ${bookingData['firstName'] ?? 'Unknown'} ${bookingData['lastName'] ?? ''}
Email: ${bookingData['email'] ?? 'No email'}
Phone: ${bookingData['phone'] ?? 'No phone'}
Customer Type: ${bookingData['customerType'] ?? 'individual'}
${bookingData['companyName'] != null ? 'Company: ${bookingData['companyName']}' : ''}

ADDRESS INFORMATION
===================
${_getAddressString(bookingData)}

COLLECTION & DELIVERY
=====================
Collection: ${bookingData['collectionDate'] ?? 'N/A'} ${bookingData['collectionTime'] ?? ''}
Delivery: ${bookingData['deliveryDate'] ?? 'N/A'} ${bookingData['deliveryTime'] ?? ''}
${bookingData['instructions'] != null && bookingData['instructions'].toString().isNotEmpty ? 'Instructions: ${bookingData['instructions']}' : ''}
${bookingData['specialInstructions'] != null && bookingData['specialInstructions'].toString().isNotEmpty ? 'Special Note: ${bookingData['specialInstructions']}' : ''}

ITEMS / SERVICES
================
$itemsBlock

Generated on: ${DateTime.now().toString()}
    ''';

    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          width: 600,
          height: 680,
          decoration: BoxDecoration(
            color: _P.card,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 32, offset: const Offset(0, 12))],
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(22, 18, 14, 18),
                decoration: BoxDecoration(
                  color: _P.navy,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.print_rounded, color: Colors.white, size: 20),
                    const SizedBox(width: 12),
                    Expanded(child: Text('Order Preview', style: _T.heading(16, c: Colors.white))),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded, color: Colors.white60, size: 20),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: _P.canvas,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _P.border),
                    ),
                    child: Text(orderDetails, style: _T.body(12).copyWith(height: 1.6, fontFamily: 'monospace')),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(18),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Order details ready for printing', style: _T.body(13, c: Colors.white)),
                            backgroundColor: _P.emerald,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        );
                      },
                      icon: const Icon(Icons.print_rounded, size: 17),
                      label: const Text('Print'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _P.azure,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── buildInfoCard (kept for backwards compat) ─────────────────────────────

  Widget _buildInfoCard(String title, String date, String time, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 5),
            Text(title, style: _T.label(11, c: color)),
          ]),
          const SizedBox(height: 4),
          Text(date, style: _T.label(12, c: _P.textPrimary)),
          Text(time, style: _T.body(11)),
        ],
      ),
    );
  }
}

// ─── Small Widgets ────────────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  final _Status status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: status.bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(status.icon, size: 11, color: status.color),
          const SizedBox(width: 5),
          Text(status.label, style: _T.label(11, c: status.color)),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final Color color;
  final Color bg;
  const _Chip({required this.label, required this.color, required this.bg});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Text(label, style: _T.label(9, c: color)),
    );
  }
}

class _ItemRow extends StatelessWidget {
  final dynamic item;
  const _ItemRow({required this.item});

  @override
  Widget build(BuildContext context) {
    if (item == null) return const SizedBox.shrink();

    String title = '';
    String priceStr = '0.00';
    int qty = 1;

    if (item is Map) {
      final cat = (item['category'] ?? '').toString().trim();
      final type = (item['itemType'] ?? item['name'] ?? item['title'] ?? '').toString().trim();
      if (cat.isNotEmpty && type.isNotEmpty && cat.toLowerCase() != type.toLowerCase()) {
        title = '$cat – $type';
      } else if (type.isNotEmpty) {
        title = type;
      } else if (cat.isNotEmpty) {
        title = cat;
      } else {
        title = 'Item';
      }

      final p = item['price'];
      if (p is num) {
        priceStr = p.toStringAsFixed(2);
      } else if (p != null) {
        priceStr = p.toString().replaceAll('£', '').replaceAll(',', '').trim();
      }

      qty = (item['quantity'] as num?)?.toInt() ?? 1;
    } else {
      title = item.toString();
    }

    if (title.isEmpty) title = 'Item';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Row(
        children: [
          Container(width: 6, height: 6, decoration: const BoxDecoration(color: _P.azure, shape: BoxShape.circle)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              qty > 1 ? '$title (x$qty)' : title,
              style: _T.body(13, c: _P.textPrimary),
            ),
          ),
          Text('£$priceStr', style: _T.label(13, c: _P.emerald)),
        ],
      ),
    );
  }
}

class _TextAction extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const _TextAction({required this.label, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18, color: _P.azure),
      label: Text(label, style: _T.label(13, c: _P.azure)),
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}

class _OutlineAction extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const _OutlineAction({required this.label, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 15),
      label: Text(label, style: _T.label(13)),
      style: OutlinedButton.styleFrom(
        foregroundColor: _P.textSecondary,
        side: const BorderSide(color: _P.border),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}

// ─── Detail Section & Row ─────────────────────────────────────────────────────

class _DetailSection extends StatelessWidget {
  final String title;
  final List<_DetailRow> rows;
  const _DetailSection({required this.title, required this.rows});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            children: [
              Container(width: 3, height: 14, decoration: BoxDecoration(color: _P.azure, borderRadius: BorderRadius.circular(2))),
              const SizedBox(width: 8),
              Text(title, style: _T.heading(14, w: FontWeight.w600)),
            ],
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: _P.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _P.border),
          ),
          child: Column(
            children: rows.asMap().entries.map((e) {
              final isLast = e.key == rows.length - 1;
              return Column(
                children: [
                  e.value,
                  if (!isLast) Divider(height: 1, color: _P.borderSoft, indent: 16, endIndent: 16),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  const _DetailRow(this.label, this.value, this.icon);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34, height: 34,
            decoration: BoxDecoration(color: _P.azureSoft, borderRadius: BorderRadius.circular(9)),
            child: Icon(icon, size: 16, color: _P.azure),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,  style: _T.body(11, c: _P.textMuted)),
                const SizedBox(height: 2),
                Text(value,  style: _T.label(13, c: _P.textPrimary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}