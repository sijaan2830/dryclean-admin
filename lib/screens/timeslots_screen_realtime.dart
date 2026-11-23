import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/admin_ui.dart';

/// Collection & delivery time slots — read live by the customer app's booking flow.
///
///   collection_slots/{day}             { day_name, isOpen, order }
///   collection_slots/{day}/slots/{id}  { start: '08:00', end: '10:00', max, current, isOpen, isActive }
///   delivery_slots/…                   same shape
class TimeslotsScreenRealtime extends StatefulWidget {
  const TimeslotsScreenRealtime({super.key});
  @override
  State<TimeslotsScreenRealtime> createState() => _TimeslotsScreenRealtimeState();
}

const _days = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'];
String _cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
int _mins(String hhmm) {
  final p = hhmm.split(':');
  return p.length == 2 ? (int.tryParse(p[0]) ?? 0) * 60 + (int.tryParse(p[1]) ?? 0) : 0;
}

class _TimeslotsScreenRealtimeState extends State<TimeslotsScreenRealtime> {
  final _db = FirebaseFirestore.instance;
  String _kind = 'collection_slots';
  late final _allSlots = _db.collectionGroup('slots').snapshots();
  final _dayStreams = <String, Stream<QuerySnapshot<Map<String, dynamic>>>>{};

  Stream<QuerySnapshot<Map<String, dynamic>>> _daysOf(String kind) => _dayStreams.putIfAbsent(kind, () => _db.collection(kind).snapshots());

  Future<void> _ensureDays(List<QueryDocumentSnapshot<Map<String, dynamic>>> existing) async {
    final have = existing.map((d) => d.id).toSet();
    final missing = _days.where((d) => !have.contains(d)).toList();
    if (missing.isEmpty) return;
    final b = _db.batch();
    for (final d in missing) {
      b.set(_db.collection(_kind).doc(d), {'day_name': _cap(d), 'isOpen': true, 'order': _days.indexOf(d) + 1, 'createdAt': FieldValue.serverTimestamp(), 'updatedAt': FieldValue.serverTimestamp()});
    }
    await b.commit();
  }

  Future<void> _slot(String day, [QueryDocumentSnapshot<Map<String, dynamic>>? slot]) async {
    final res = await showDialog<Map<String, dynamic>>(context: context, builder: (_) => _SlotDialog(day: _cap(day), initial: slot?.data()));
    if (res == null) return;
    final data = {
      ...res,
      'startTime': res['start'],
      'endTime': res['end'],
      'maxBookings': res['max'],
      'isActive': true,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (slot == null) {
      await _db.collection(_kind).doc(day).collection('slots').add({...data, 'current': 0, 'isOpen': true, 'createdAt': FieldValue.serverTimestamp()});
    } else {
      await slot.reference.update(data);
    }
    if (mounted) adminToast(context, 'Slot saved — customers see it in the app now.');
  }

  Future<void> _copyToAll(String fromDay, List<QueryDocumentSnapshot<Map<String, dynamic>>> slots) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Copy ${_cap(fromDay)} to every day?'),
        content: Text('The other days’ ${_kind == 'collection_slots' ? 'collection' : 'delivery'} slots are replaced with these ${slots.length}. Bookings already counted are reset.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Copy')),
        ],
      ),
    );
    if (ok != true) return;
    for (final d in _days.where((d) => d != fromDay)) {
      final ref = _db.collection(_kind).doc(d).collection('slots');
      final old = await ref.get();
      final b = _db.batch();
      for (final o in old.docs) {
        b.delete(o.reference);
      }
      for (final s in slots) {
        final m = s.data();
        b.set(ref.doc(), {
          for (final k in ['start', 'end', 'max', 'startTime', 'endTime', 'maxBookings', 'isOpen', 'isActive']) if (m.containsKey(k)) k: m[k],
          'current': 0,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      await b.commit();
    }
    if (mounted) adminToast(context, 'Copied to every day.');
  }

  Future<void> _resetCounts(List<QueryDocumentSnapshot<Map<String, dynamic>>> slots) async {
    final b = _db.batch();
    for (final s in slots) {
      b.update(s.reference, {'current': 0, 'updatedAt': FieldValue.serverTimestamp()});
    }
    await b.commit();
    if (mounted) adminToast(context, 'Booking counts reset.');
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _daysOf(_kind),
      builder: (context, dSnap) {
        final days = [...(dSnap.data?.docs ?? const <QueryDocumentSnapshot<Map<String, dynamic>>>[])]
          ..sort((a, b) => ((a.data()['order'] as num?) ?? _days.indexOf(a.id) + 1).compareTo((b.data()['order'] as num?) ?? _days.indexOf(b.id) + 1));
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _allSlots,
          builder: (context, sSnap) {
            final byDay = <String, List<QueryDocumentSnapshot<Map<String, dynamic>>>>{};
            for (final s in sSnap.data?.docs ?? const <QueryDocumentSnapshot<Map<String, dynamic>>>[]) {
              final day = s.reference.parent.parent;
              if (day == null || day.parent.id != _kind) continue;
              byDay.putIfAbsent(day.id, () => []).add(s);
            }
            for (final l in byDay.values) {
              l.sort((a, b) => _mins('${a.data()['start'] ?? ''}').compareTo(_mins('${b.data()['start'] ?? ''}')));
            }
            final openDays = days.where((d) => d.data()['isOpen'] != false).length;
            final slotsCount = byDay.values.fold<int>(0, (a, l) => a + l.length);
            return AdminPage(
              title: 'Time slots',
              subtitle: '$openDays of 7 days open · $slotsCount ${_kind == 'collection_slots' ? 'collection' : 'delivery'} slots. Customers book from these in the app.',
              actions: [
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'collection_slots', icon: Icon(Icons.north_east_rounded, size: 18), label: Text('Collection')),
                    ButtonSegment(value: 'delivery_slots', icon: Icon(Icons.south_west_rounded, size: 18), label: Text('Delivery')),
                  ],
                  selected: {_kind},
                  onSelectionChanged: (s) => setState(() => _kind = s.first),
                ),
              ],
              child: dSnap.connectionState == ConnectionState.waiting && days.isEmpty
                  ? const Padding(padding: EdgeInsets.all(60), child: Center(child: CircularProgressIndicator()))
                  : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      if (days.length < 7)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: SurfaceCard(child: Row(children: [
                            const Icon(Icons.info_outline_rounded, color: AC.info),
                            const SizedBox(width: 10),
                            Expanded(child: Text('Some days are missing. Add them so every day can be opened or closed.', style: AC.t(13.5))),
                            FilledButton(onPressed: () => _ensureDays(days), child: const Text('Add missing days')),
                          ])),
                        ),
                      LayoutBuilder(builder: (context, c) {
                        final cols = c.maxWidth >= 1300 ? 4 : c.maxWidth >= 900 ? 3 : c.maxWidth >= 600 ? 2 : 1;
                        final w = (c.maxWidth - (cols - 1) * 14) / cols;
                        return Wrap(spacing: 14, runSpacing: 14, children: [
                          for (final d in days)
                            SizedBox(
                              width: w,
                              child: _DayCard(
                                day: d,
                                slots: byDay[d.id] ?? const [],
                                onAdd: () => _slot(d.id),
                                onEdit: (s) => _slot(d.id, s),
                                onCopy: () => _copyToAll(d.id, byDay[d.id] ?? const []),
                                onReset: () => _resetCounts(byDay[d.id] ?? const []),
                              ),
                            ),
                        ]);
                      }),
                    ]),
            );
          },
        );
      },
    );
  }
}

class _DayCard extends StatelessWidget {
  final QueryDocumentSnapshot<Map<String, dynamic>> day;
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> slots;
  final VoidCallback onAdd, onCopy, onReset;
  final void Function(QueryDocumentSnapshot<Map<String, dynamic>>) onEdit;
  const _DayCard({required this.day, required this.slots, required this.onAdd, required this.onEdit, required this.onCopy, required this.onReset});

  @override
  Widget build(BuildContext context) {
    final open = day.data()['isOpen'] != false;
    final booked = slots.fold<int>(0, (a, s) => a + ((s.data()['current'] as num?)?.toInt() ?? 0));
    final cap = slots.fold<int>(0, (a, s) => a + ((s.data()['max'] as num?)?.toInt() ?? 0));
    return Container(
      decoration: BoxDecoration(color: AC.surface, borderRadius: BorderRadius.circular(AC.radius), border: Border.all(color: open ? AC.border : AC.borderStrong), boxShadow: AC.shadow(.04)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 6, 8),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${day.data()['day_name'] ?? _cap(day.id)}', style: AC.h(16, c: open ? AC.ink : AC.mut)),
                Text(open ? '${slots.length} slots · $booked/$cap booked' : 'Closed — not bookable', style: AC.t(12, c: open ? AC.mut : AC.danger, w: FontWeight.w600)),
              ]),
            ),
            Switch(value: open, onChanged: (v) => day.reference.update({'isOpen': v, 'updatedAt': FieldValue.serverTimestamp()})),
            PopupMenuButton<String>(
              tooltip: 'More',
              onSelected: (v) => v == 'copy' ? onCopy() : onReset(),
              itemBuilder: (_) => [
                PopupMenuItem(value: 'copy', enabled: slots.isNotEmpty, child: const ListTile(dense: true, contentPadding: EdgeInsets.zero, leading: Icon(Icons.copy_all_rounded), title: Text('Copy to every day'))),
                PopupMenuItem(value: 'reset', enabled: booked > 0, child: const ListTile(dense: true, contentPadding: EdgeInsets.zero, leading: Icon(Icons.restart_alt_rounded), title: Text('Reset booking counts'))),
              ],
            ),
          ]),
        ),
        const Divider(),
        Opacity(
          opacity: open ? 1 : .5,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
            child: Column(children: [
              if (slots.isEmpty) Padding(padding: const EdgeInsets.symmetric(vertical: 10), child: Text('No slots yet', style: AC.t(13, c: AC.mut))),
              for (final s in slots) _SlotRow(slot: s, onEdit: () => onEdit(s)),
            ]),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: OutlinedButton.icon(onPressed: onAdd, icon: const Icon(Icons.add_rounded, size: 18), label: const Text('Add slot'), style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(40))),
        ),
      ]),
    );
  }
}

class _SlotRow extends StatelessWidget {
  final QueryDocumentSnapshot<Map<String, dynamic>> slot;
  final VoidCallback onEdit;
  const _SlotRow({required this.slot, required this.onEdit});
  @override
  Widget build(BuildContext context) {
    final m = slot.data();
    final max = (m['max'] as num?)?.toInt() ?? 0, cur = (m['current'] as num?)?.toInt() ?? 0;
    final open = m['isOpen'] != false && m['isActive'] != false;
    final full = max > 0 && cur >= max;
    final pct = max == 0 ? 0.0 : (cur / max).clamp(0, 1).toDouble();
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 8, 2, 8),
      decoration: BoxDecoration(color: AC.subtle, borderRadius: BorderRadius.circular(12)),
      child: Row(children: [
        Expanded(
          child: InkWell(
            onTap: onEdit,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text('${m['start'] ?? '--:--'} – ${m['end'] ?? '--:--'}', style: AC.t(14, w: FontWeight.w800, c: open ? AC.ink : AC.mut)),
                const SizedBox(width: 8),
                if (!open) const StatusPill('Off', c: AC.mut, bg: AC.border) else if (full) const StatusPill('Full', c: AC.danger, bg: AC.dangerBg),
              ]),
              const SizedBox(height: 6),
              Row(children: [
                Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(9), child: LinearProgressIndicator(value: pct, minHeight: 5, color: full ? AC.danger : AC.emerald, backgroundColor: AC.border))),
                const SizedBox(width: 8),
                Text('$cur/$max', style: AC.t(12, c: AC.mut, w: FontWeight.w700)),
              ]),
            ]),
          ),
        ),
        Switch(value: m['isOpen'] != false, onChanged: (v) => slot.reference.update({'isOpen': v, 'updatedAt': FieldValue.serverTimestamp()})),
        PopupMenuButton<String>(
          tooltip: 'More',
          icon: const Icon(Icons.more_vert_rounded, size: 19),
          onSelected: (v) async {
            if (v == 'edit') onEdit();
            if (v == 'del') await slot.reference.delete();
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'edit', child: ListTile(dense: true, contentPadding: EdgeInsets.zero, leading: Icon(Icons.edit_outlined), title: Text('Edit'))),
            PopupMenuItem(value: 'del', child: ListTile(dense: true, contentPadding: EdgeInsets.zero, leading: Icon(Icons.delete_outline_rounded, color: AC.danger), title: Text('Delete'))),
          ],
        ),
      ]),
    );
  }
}

class _SlotDialog extends StatefulWidget {
  final String day;
  final Map<String, dynamic>? initial;
  const _SlotDialog({required this.day, this.initial});
  @override
  State<_SlotDialog> createState() => _SlotDialogState();
}

class _SlotDialogState extends State<_SlotDialog> {
  late String _start = '${widget.initial?['start'] ?? '09:00'}';
  late String _end = '${widget.initial?['end'] ?? '11:00'}';
  late final _max = TextEditingController(text: '${widget.initial?['max'] ?? 5}');
  String? _err;

  String _fmt(TimeOfDay t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  TimeOfDay _parse(String s) => TimeOfDay(hour: _mins(s) ~/ 60, minute: _mins(s) % 60);

  Widget _timeBtn(String label, String value, ValueChanged<String> set) => Expanded(
        child: OutlinedButton(
          onPressed: () async {
            final t = await showTimePicker(context: context, initialTime: _parse(value), builder: (c, w) => MediaQuery(data: MediaQuery.of(c).copyWith(alwaysUse24HourFormat: true), child: w!));
            if (t != null) setState(() => set(_fmt(t)));
          },
          style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(58)),
          child: Column(mainAxisSize: MainAxisSize.min, children: [Text(label, style: AC.t(11.5, c: AC.mut)), Text(value, style: AC.num(20))]),
        ),
      );

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text('${widget.initial == null ? 'Add' : 'Edit'} slot · ${widget.day}'),
        content: SizedBox(
          width: 380,
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [_timeBtn('From', _start, (v) => _start = v), const SizedBox(width: 10), _timeBtn('Until', _end, (v) => _end = v)]),
            const SizedBox(height: 14),
            TextField(
              controller: _max,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(labelText: 'Bookings allowed in this slot', prefixIcon: Icon(Icons.groups_outlined)),
            ),
            if (_err != null) Padding(padding: const EdgeInsets.only(top: 10), child: Text(_err!, style: AC.t(13, c: AC.danger, w: FontWeight.w700))),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final max = int.tryParse(_max.text) ?? 0;
              if (_mins(_end) <= _mins(_start)) return setState(() => _err = 'The end time must be after the start time.');
              if (max < 1) return setState(() => _err = 'Allow at least 1 booking.');
              Navigator.pop(context, {'start': _start, 'end': _end, 'max': max});
            },
            child: const Text('Save'),
          ),
        ],
      );
}
