import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/fcm_sender_service.dart';
import '../theme/admin_ui.dart';

/// Prepaid packs — the `prepaid_packs` collection, read live by the website and app.
///
/// Document: { name, description, order, isActive,
///             discounts: [ {label: 'Shirt', count: '5', old: '14.75', new: '14.00', off: '5%'} ] }
/// (Values are stored as text because that is what the apps already read.)
class PrepaidPacksScreenRealtime extends StatefulWidget {
  const PrepaidPacksScreenRealtime({super.key});
  @override
  State<PrepaidPacksScreenRealtime> createState() => _PrepaidPacksScreenRealtimeState();
}

String _plural(String w, double n) => n == 1 || w.toLowerCase().endsWith('s') ? w : '${w}s';
double _n(Object? v) => double.tryParse('${v ?? ''}'.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0;
List<Map<String, dynamic>> _packOpts(Map<String, dynamic> m) => ((m['discounts'] as List?) ?? const []).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();

class _PrepaidPacksScreenRealtimeState extends State<PrepaidPacksScreenRealtime> {
  final _col = FirebaseFirestore.instance.collection('prepaid_packs');
  late final _stream = _col.snapshots();

  Future<void> _edit([QueryDocumentSnapshot<Map<String, dynamic>>? doc, int nextOrder = 1]) async {
    final res = await showDialog<_PackResult>(context: context, barrierDismissible: false, builder: (_) => _PackDialog(initial: doc?.data()));
    if (res == null) return;
    if (doc == null) {
      final id = res.data['name'].toString().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_').replaceAll(RegExp(r'^_|_$'), '');
      final ref = _col.doc(id.isEmpty ? null : (id.endsWith('pack') ? id : '${id}_pack'));
      await ref.set({...res.data, 'order': nextOrder, 'createdAt': FieldValue.serverTimestamp(), 'updatedAt': FieldValue.serverTimestamp()});
    } else {
      await doc.reference.update({...res.data, 'updatedAt': FieldValue.serverTimestamp()});
    }
    if (!mounted) return;
    adminToast(context, 'Pack saved — live on the website and app.');
    if (res.announce) {
      final r = await FCMSenderService().sendNotification(
        title: doc == null ? 'New prepaid pack' : 'Prepaid pack updated',
        body: '${res.data['name']} — save more when you prepay.',
        topic: 'prepaid_packs',
        data: {'type': 'prepaid_pack'},
      );
      if (mounted) adminToast(context, r['success'] == true ? 'Customers notified.' : 'Pack saved, but the notification wasn’t sent: ${r['error']}');
    }
  }

  Future<void> _move(List<QueryDocumentSnapshot<Map<String, dynamic>>> list, int i, int dir) async {
    final j = i + dir;
    if (j < 0 || j >= list.length) return;
    final b = FirebaseFirestore.instance.batch();
    for (var k = 0; k < list.length; k++) {
      b.update(list[k].reference, {'order': (k == i ? j : k == j ? i : k) + 1});
    }
    await b.commit();
  }

  Future<void> _delete(QueryDocumentSnapshot<Map<String, dynamic>> doc) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Delete “${doc.data()['name']}”?'),
        content: const Text('It disappears from the website and app. Customers who already bought it keep their credits.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(style: FilledButton.styleFrom(backgroundColor: AC.danger), onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok == true) await doc.reference.delete();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _stream,
      builder: (context, snap) {
        final list = [...(snap.data?.docs ?? const <QueryDocumentSnapshot<Map<String, dynamic>>>[])]
          ..sort((a, b) => ((a.data()['order'] as num?) ?? 99).compareTo((b.data()['order'] as num?) ?? 99));
        final live = list.where((d) => d.data()['isActive'] != false).length;
        return AdminPage(
          title: 'Prepaid packs',
          subtitle: 'Bundles customers buy in advance. $live of ${list.length} on sale · changes go live instantly.',
          actions: [FilledButton.icon(onPressed: () => _edit(null, list.length + 1), icon: const Icon(Icons.add_rounded, size: 19), label: const Text('New pack'))],
          child: snap.hasError
              ? SurfaceCard(child: EmptyState(icon: Icons.error_outline_rounded, title: 'Couldn’t load packs', text: '${snap.error}'))
              : snap.connectionState == ConnectionState.waiting && list.isEmpty
                  ? const Padding(padding: EdgeInsets.all(60), child: Center(child: CircularProgressIndicator()))
                  : list.isEmpty
                      ? SurfaceCard(child: EmptyState(icon: Icons.inventory_2_outlined, title: 'No packs yet', text: 'Create a pack like “5 shirts for £14” to reward loyal customers.', action: FilledButton(onPressed: () => _edit(), child: const Text('Create a pack'))))
                      : LayoutBuilder(builder: (context, c) {
                          final cols = c.maxWidth >= 1100 ? 3 : c.maxWidth >= 700 ? 2 : 1;
                          final w = (c.maxWidth - (cols - 1) * 16) / cols;
                          return Wrap(spacing: 16, runSpacing: 16, children: [
                            for (var i = 0; i < list.length; i++)
                              SizedBox(
                                width: w,
                                child: _PackCard(
                                  doc: list[i],
                                  onEdit: () => _edit(list[i]),
                                  onDelete: () => _delete(list[i]),
                                  onLeft: i == 0 ? null : () => _move(list, i, -1),
                                  onRight: i == list.length - 1 ? null : () => _move(list, i, 1),
                                ),
                              ),
                          ]);
                        }),
        );
      },
    );
  }
}

class _PackCard extends StatelessWidget {
  final QueryDocumentSnapshot<Map<String, dynamic>> doc;
  final VoidCallback onEdit, onDelete;
  final VoidCallback? onLeft, onRight;
  const _PackCard({required this.doc, required this.onEdit, required this.onDelete, this.onLeft, this.onRight});

  @override
  Widget build(BuildContext context) {
    final m = doc.data();
    final opts = _packOpts(m)..sort((a, b) => _n(a['count']).compareTo(_n(b['count'])));
    final active = m['isActive'] != false;
    final best = opts.isEmpty ? null : opts.map((o) => _n(o['off'])).reduce((a, b) => a > b ? a : b);
    return Container(
      decoration: BoxDecoration(color: AC.surface, borderRadius: BorderRadius.circular(AC.radius), border: Border.all(color: AC.border), boxShadow: AC.shadow(.04)),
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          padding: const EdgeInsets.fromLTRB(18, 16, 8, 16),
          decoration: BoxDecoration(gradient: LinearGradient(colors: active ? [AC.forest, AC.forest2] : [const Color(0xFF475569), const Color(0xFF64748B)])),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(width: 40, height: 40, decoration: BoxDecoration(color: AC.gold, borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.inventory_2_rounded, color: AC.forest, size: 21)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${m['name'] ?? doc.id}', style: AC.h(16, c: Colors.white)),
                const SizedBox(height: 2),
                Text('${m['description'] ?? ''}', maxLines: 2, overflow: TextOverflow.ellipsis, style: AC.t(12.5, c: Colors.white.withValues(alpha: .75))),
              ]),
            ),
            if (best != null && best > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: AC.gold, borderRadius: BorderRadius.circular(99)),
                child: Text('Up to ${best.toStringAsFixed(0)}% off', style: AC.t(11.5, c: AC.forest, w: FontWeight.w800)),
              ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
          child: opts.isEmpty
              ? Padding(padding: const EdgeInsets.symmetric(vertical: 14), child: Text('No options yet — edit to add “5 for £14”.', style: AC.t(13, c: AC.mut)))
              : Column(children: [
                  for (final o in opts)
                    Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(color: AC.subtle, borderRadius: BorderRadius.circular(12)),
                      child: Row(children: [
                        Text('${o['count'] ?? ''} × ${_plural('${o['label'] ?? 'item'}', _n(o['count']))}', style: AC.t(14, w: FontWeight.w700)),
                        const Spacer(),
                        if (_n(o['old']) > _n(o['new'])) Text('£${_n(o['old']).toStringAsFixed(2)}  ', style: AC.t(12.5, c: AC.faint).copyWith(decoration: TextDecoration.lineThrough)),
                        Text('£${_n(o['new']).toStringAsFixed(2)}', style: AC.num(15)),
                        if ('${o['off'] ?? ''}'.isNotEmpty) ...[const SizedBox(width: 8), StatusPill('${o['off']}', c: AC.emerald7, bg: AC.mint)],
                      ]),
                    ),
                ]),
        ),
        const Divider(),
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 4, 8, 6),
          child: Row(children: [
            Switch(value: active, onChanged: (v) => doc.reference.update({'isActive': v, 'updatedAt': FieldValue.serverTimestamp()})),
            Text(active ? 'On sale' : 'Hidden', style: AC.t(13, c: active ? AC.emerald7 : AC.mut, w: FontWeight.w700)),
            const Spacer(),
            IconButton(tooltip: 'Move earlier', onPressed: onLeft, icon: const Icon(Icons.chevron_left_rounded)),
            IconButton(tooltip: 'Move later', onPressed: onRight, icon: const Icon(Icons.chevron_right_rounded)),
            IconButton(tooltip: 'Edit', onPressed: onEdit, icon: const Icon(Icons.edit_outlined, size: 20)),
            IconButton(tooltip: 'Delete', onPressed: onDelete, icon: const Icon(Icons.delete_outline_rounded, size: 20, color: AC.faint)),
          ]),
        ),
      ]),
    );
  }
}

class _PackResult {
  final Map<String, dynamic> data;
  final bool announce;
  _PackResult(this.data, this.announce);
}

class _Opt {
  final count = TextEditingController(), label = TextEditingController(), old = TextEditingController(), price = TextEditingController();
  _Opt([Map<String, dynamic>? m]) {
    count.text = '${m?['count'] ?? ''}';
    label.text = '${m?['label'] ?? ''}';
    old.text = m == null ? '' : _n(m['old']).toStringAsFixed(2);
    price.text = m == null ? '' : _n(m['new']).toStringAsFixed(2);
  }
  String get off {
    final o = _n(old.text), p = _n(price.text);
    return o > 0 && p > 0 && p < o ? '${((o - p) / o * 100).round()}%' : '';
  }
}

class _PackDialog extends StatefulWidget {
  final Map<String, dynamic>? initial;
  const _PackDialog({this.initial});
  @override
  State<_PackDialog> createState() => _PackDialogState();
}

class _PackDialogState extends State<_PackDialog> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: '${widget.initial?['name'] ?? ''}');
  late final _desc = TextEditingController(text: '${widget.initial?['description'] ?? ''}');
  late bool _active = widget.initial?['isActive'] != false;
  bool _announce = false;
  late final List<_Opt> _opts = [for (final o in _opts0()) _Opt(o)];

  List<Map<String, dynamic>> _opts0() {
    final l = widget.initial == null ? <Map<String, dynamic>>[] : _optsOf(widget.initial!);
    return l.isEmpty ? [<String, dynamic>{}] : l;
  }

  static List<Map<String, dynamic>> _optsOf(Map<String, dynamic> m) => _packOpts(m);

  @override
  Widget build(BuildContext context) {
    final money = [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))];
    InputDecoration d(String l, {String? p}) => InputDecoration(labelText: l, prefixText: p, isDense: true);
    return AlertDialog(
      title: Text(widget.initial == null ? 'New prepaid pack' : 'Edit pack'),
      content: SizedBox(
        width: 640,
        child: Form(
          key: _form,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              TextFormField(controller: _name, decoration: const InputDecoration(labelText: 'Pack name', hintText: 'e.g. Shirts prepaid pack'), validator: (v) => (v ?? '').trim().isEmpty ? 'Required' : null),
              const SizedBox(height: 12),
              TextFormField(controller: _desc, decoration: const InputDecoration(labelText: 'Short description', hintText: 'e.g. For wash & iron or dry cleaning.')),
              const SizedBox(height: 18),
              Row(children: [Text('Options', style: AC.h(15)), const Spacer(), Text('Discount is worked out for you', style: AC.t(12, c: AC.mut))]),
              const SizedBox(height: 8),
              for (var i = 0; i < _opts.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    SizedBox(width: 70, child: TextFormField(controller: _opts[i].count, keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly], decoration: d('Qty'), validator: (v) => (int.tryParse(v ?? '') ?? 0) < 1 ? '!' : null)),
                    const SizedBox(width: 8),
                    Expanded(flex: 3, child: TextFormField(controller: _opts[i].label, decoration: d('Item', p: null), validator: (v) => (v ?? '').trim().isEmpty ? 'Required' : null)),
                    const SizedBox(width: 8),
                    Expanded(flex: 2, child: TextFormField(controller: _opts[i].old, inputFormatters: money, onChanged: (_) => setState(() {}), decoration: d('Usual', p: '£'))),
                    const SizedBox(width: 8),
                    Expanded(flex: 2, child: TextFormField(controller: _opts[i].price, inputFormatters: money, onChanged: (_) => setState(() {}), decoration: d('Pack price', p: '£'), validator: (v) => _n(v) <= 0 ? 'Price' : null)),
                    SizedBox(width: 56, child: Padding(padding: const EdgeInsets.only(top: 12), child: Text(_opts[i].off, textAlign: TextAlign.center, style: AC.t(13, c: AC.emerald7, w: FontWeight.w800)))),
                    IconButton(tooltip: 'Remove option', onPressed: _opts.length == 1 ? null : () => setState(() => _opts.removeAt(i)), icon: const Icon(Icons.close_rounded, size: 19)),
                  ]),
                ),
              Align(alignment: Alignment.centerLeft, child: TextButton.icon(onPressed: () => setState(() => _opts.add(_Opt({'label': _opts.last.label.text}))), icon: const Icon(Icons.add_rounded), label: const Text('Add option'))),
              const SizedBox(height: 8),
              SwitchListTile(contentPadding: EdgeInsets.zero, value: _active, onChanged: (v) => setState(() => _active = v), title: const Text('On sale'), subtitle: const Text('Shown on the website and in the app')),
              CheckboxListTile(contentPadding: EdgeInsets.zero, value: _announce, onChanged: (v) => setState(() => _announce = v ?? false), title: const Text('Notify app customers'), subtitle: const Text('Sends a push to everyone following prepaid packs'), controlAffinity: ListTileControlAffinity.leading),
            ]),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            if (!_form.currentState!.validate()) return;
            Navigator.pop(
              context,
              _PackResult({
                'name': _name.text.trim(),
                'description': _desc.text.trim(),
                'isActive': _active,
                'discounts': [
                  for (final o in _opts)
                    {
                      'count': o.count.text.trim(),
                      'label': o.label.text.trim(),
                      'old': _n(o.old.text) > 0 ? _n(o.old.text).toStringAsFixed(2) : _n(o.price.text).toStringAsFixed(2),
                      'new': _n(o.price.text).toStringAsFixed(2),
                      'off': o.off.isEmpty ? '0%' : o.off,
                    },
                ],
              }, _announce),
            );
          },
          child: const Text('Save pack'),
        ),
      ],
    );
  }
}
