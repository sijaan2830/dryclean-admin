import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/admin_ui.dart';

/// Services & prices — the `services` collection.
/// The website price list, booking flow and the customer app all read it live,
/// so a saved price appears everywhere within a second.
///
/// Document: { name, description, icon, order, isActive, items: [ {name, price: '£4.90', category, description} ] }
class ServicesScreenRealtime extends StatefulWidget {
  const ServicesScreenRealtime({super.key});
  @override
  State<ServicesScreenRealtime> createState() => _ServicesScreenRealtimeState();
}

/// Icon library, hosted with the admin site (web/service-icons) so the website and app can load it too.
const kIconHost = 'https://dryclean-flutter-app.web.app/service-icons/';
const kServiceIcons = <(String, String)>[
  ('dry-cleaning', 'Dry cleaning'), ('laundry', 'Laundry'), ('ironing', 'Ironing'), ('shirts', 'Shirts'),
  ('suits', 'Suits'), ('wedding-dress', 'Wedding'), ('special-items', 'Leather & special'), ('shoes', 'Shoes'),
  ('duvets-bedding', 'Duvets & bedding'), ('household', 'Household'), ('curtains', 'Curtains'), ('rugs', 'Rugs'),
  ('alterations', 'Alterations'),
];
// bundled in the customer app already, so app versions that read `icon` can still find them
const _appAsset = {
  'dry-cleaning': 'assets/icons/dry cleaning.png',
  'laundry': 'assets/icons/Laundry & Ironing.png',
  'duvets-bedding': 'assets/icons/Duvets & Bedding.png',
  'household': 'assets/icons/Household Items.png',
  'special-items': 'assets/icons/Special Items.png',
};

/// Which library icon a section uses: saved choice, else a guess from its name.
String iconKeyOf(Map<String, dynamic> m) {
  final saved = '${m['iconKey'] ?? ''}';
  if (kServiceIcons.any((i) => i.$1 == saved)) return saved;
  final url = '${m['imageUrl'] ?? ''}';
  for (final i in kServiceIcons) {
    if (url.endsWith('/${i.$1}.png')) return i.$1;
  }
  final n = '${m['name'] ?? ''}'.toLowerCase();
  if (n.contains('special') || n.contains('leather') || n.contains('suede')) return 'special-items';
  if (n.contains('duvet') || n.contains('bed')) return 'duvets-bedding';
  if (n.contains('household') || n.contains('home')) return 'household';
  if (n.contains('curtain')) return 'curtains';
  if (n.contains('rug') || n.contains('carpet')) return 'rugs';
  if (n.contains('shoe') || n.contains('trainer')) return 'shoes';
  if (n.contains('wedding') || n.contains('bridal')) return 'wedding-dress';
  if (n.contains('alter') || n.contains('repair') || n.contains('tailor')) return 'alterations';
  if (n.contains('suit')) return 'suits';
  if (n.contains('shirt')) return 'shirts';
  if (n.contains('iron') || n.contains('laundry') || n.contains('wash')) return 'laundry';
  return 'dry-cleaning';
}

/// Shown inside the console from the same site (no cross-site loading needed).
Widget serviceIcon(String key, {double size = 40, Color bg = AC.mint}) => Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * .14),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(size * .3)),
      child: Image.network('service-icons/$key.png', fit: BoxFit.contain, errorBuilder: (_, _, _) => Icon(Icons.sell_outlined, size: size * .5, color: AC.emerald7)),
    );

/// Fields saved with a section when an icon is picked.
Map<String, dynamic> iconFields(String key) => {
      'iconKey': key,
      'imageUrl': '$kIconHost$key.png',
      if (_appAsset[key] != null) 'icon': _appAsset[key],
    };

// ------------------------------------------------------------ card colours
/// Card colours shared with the website and the customer app (light, strong).
/// Saved on a section as `cardColors: ['#FFA3A8', '#FF7B86']`.
const kCardPalette = <(String, Color, Color)>[
  ('Rose', Color(0xFFFFA3A8), Color(0xFFFF7B86)),
  ('Sunny', Color(0xFFFFE58C), Color(0xFFFFCB4F)),
  ('Sky', Color(0xFFA9E3FF), Color(0xFF7BCBFB)),
  ('Lime', Color(0xFFC9F78E), Color(0xFFA6EB60)),
  ('Lavender', Color(0xFFDCD0FF), Color(0xFFB9A8FF)),
  ('Peach', Color(0xFFFFD9A8), Color(0xFFF5B66B)),
  ('Mint', Color(0xFFA8F0D5), Color(0xFF5EDBB0)),
  ('Coral', Color(0xFFFFC4AD), Color(0xFFFF9E7A)),
  ('Ocean', Color(0xFFAFC8FF), Color(0xFF6C9BFF)),
  ('Orchid', Color(0xFFF5C2FA), Color(0xFFE58BF0)),
];

String _hex(Color c) => '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';
Color? _parseHex(Object? v) {
  final h = '${v ?? ''}'.replaceAll('#', '').trim();
  final n = int.tryParse(h, radix: 16);
  return h.length == 6 && n != null ? Color(0xFF000000 | n) : null;
}

/// Colour a section gets when none is picked — same rule as the app and website.
(Color, Color) autoCardColors(String name) {
  final n = name.toLowerCase().trim();
  (Color, Color) at(int i) => (kCardPalette[i].$2, kCardPalette[i].$3);
  if (n.contains('special') || n.contains('leather') || n.contains('suede')) return at(5);
  if (n.contains('dry clean')) return at(0);
  if (n.contains('duvet') || n.contains('bedding')) return at(1);
  if (n.contains('laundry') || n.contains('ironing')) return at(2);
  if (n.contains('household')) return at(3);
  if (n.contains('wash')) return at(4);
  var h = 0;
  for (final c in n.codeUnits) {
    h = (h * 31 + c) & 0x7fffffff;
  }
  return at(h % kCardPalette.length);
}

/// The colours a section shows with: picked in the console, else automatic.
(Color, Color) cardColorsOf(Map<String, dynamic> m) {
  final l = (m['cardColors'] as List?) ?? const [];
  final a = l.isNotEmpty ? _parseHex(l[0]) : null, b = l.length > 1 ? _parseHex(l[1]) : null;
  return a != null && b != null ? (a, b) : autoCardColors('${m['name'] ?? ''}');
}

double _num(Object? p) => double.tryParse('${p ?? ''}'.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0;
String _gbp(double v) => '£${v.toStringAsFixed(2)}';
List<Map<String, dynamic>> _items(Map<String, dynamic> m) => ((m['items'] as List?) ?? const []).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();

class _ServicesScreenRealtimeState extends State<ServicesScreenRealtime> {
  final _col = FirebaseFirestore.instance.collection('services');
  late final _stream = _col.snapshots();
  String? _selected;
  String _q = '';

  Future<void> _saveItems(DocumentReference<Map<String, dynamic>> ref, List<Map<String, dynamic>> items, String msg) async {
    await ref.update({'items': items, 'updatedAt': FieldValue.serverTimestamp()});
    if (mounted) adminToast(context, msg);
  }

  Future<void> _editItem(QueryDocumentSnapshot<Map<String, dynamic>> svc, [int? index]) async {
    final items = _items(svc.data());
    final cats = {for (final i in items) '${i['category'] ?? ''}'}..removeWhere((c) => c.isEmpty);
    final res = await showDialog<Map<String, dynamic>>(context: context, builder: (_) => _ItemDialog(initial: index == null ? null : items[index], categories: cats.toList()));
    if (res == null) return;
    // re-read so we never overwrite someone else's change made meanwhile
    final fresh = _items((await svc.reference.get()).data() ?? const {});
    if (index == null) {
      fresh.add(res);
    } else {
      final at = fresh.indexWhere((i) => i['name'] == items[index]['name'] && i['category'] == items[index]['category']);
      if (at >= 0) fresh[at] = {...fresh[at], ...res};
      else fresh.add(res);
    }
    await _saveItems(svc.reference, fresh, index == null ? '“${res['name']}” added — live on the website and app.' : 'Price updated — live on the website and app.');
  }

  Future<void> _deleteItem(QueryDocumentSnapshot<Map<String, dynamic>> svc, Map<String, dynamic> item) async {
    final ok = await _confirm('Remove “${item['name']}”?', 'Customers will no longer be able to choose it.');
    if (!ok) return;
    final fresh = _items((await svc.reference.get()).data() ?? const {})..removeWhere((i) => i['name'] == item['name'] && i['category'] == item['category']);
    await _saveItems(svc.reference, fresh, 'Item removed.');
  }

  Future<void> _editSection([QueryDocumentSnapshot<Map<String, dynamic>>? svc, int nextOrder = 1]) async {
    final res = await showDialog<Map<String, dynamic>>(context: context, builder: (_) => _SectionDialog(initial: svc?.data()));
    if (res == null) return;
    if (svc == null) {
      final id = '${res['name']}'.toLowerCase().trim().replaceAll(RegExp(r'[^a-z0-9]+'), '_').replaceAll(RegExp(r'^_|_$'), '');
      final ref = _col.doc(id.isEmpty ? null : id);
      await ref.set({...res..removeWhere((k, v) => k == 'cardColors' && v == null), 'order': nextOrder, 'isActive': true, 'items': <Map<String, dynamic>>[], 'createdAt': FieldValue.serverTimestamp(), 'updatedAt': FieldValue.serverTimestamp()});
      setState(() => _selected = ref.id);
      if (mounted) adminToast(context, 'Section created — add its items next.');
    } else {
      await svc.reference.update({...res, if (res['cardColors'] == null) 'cardColors': FieldValue.delete(), 'updatedAt': FieldValue.serverTimestamp()});
      if (mounted) adminToast(context, 'Section updated.');
    }
  }

  Future<void> _move(List<QueryDocumentSnapshot<Map<String, dynamic>>> list, int i, int dir) async {
    final j = i + dir;
    if (j < 0 || j >= list.length) return;
    final b = FirebaseFirestore.instance.batch();
    for (var k = 0; k < list.length; k++) {
      final pos = k == i ? j : k == j ? i : k;
      b.update(list[k].reference, {'order': pos + 1});
    }
    await b.commit();
  }

  Future<bool> _confirm(String title, String text) async =>
      await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: Text(title),
          content: Text(text),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            FilledButton(style: FilledButton.styleFrom(backgroundColor: AC.danger), onPressed: () => Navigator.pop(context, true), child: const Text('Remove')),
          ],
        ),
      ) ??
      false;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _stream,
      builder: (context, snap) {
        final list = [...(snap.data?.docs ?? const <QueryDocumentSnapshot<Map<String, dynamic>>>[])]
          ..sort((a, b) => ((a.data()['order'] as num?) ?? 99).compareTo((b.data()['order'] as num?) ?? 99));
        final sel = list.where((d) => d.id == _selected).firstOrNull ?? (list.isEmpty ? null : list.first);
        final wide = MediaQuery.sizeOf(context).width >= 1180;
        final totalItems = list.fold<int>(0, (a, d) => a + _items(d.data()).length);

        final sections = SurfaceCard(
          title: 'Sections',
          subtitle: '${list.length} sections · $totalItems items',
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
          child: Column(children: [
            for (var i = 0; i < list.length; i++)
              _SectionTile(
                doc: list[i],
                selected: list[i].id == sel?.id,
                onTap: () => setState(() => _selected = list[i].id),
                onUp: i == 0 ? null : () => _move(list, i, -1),
                onDown: i == list.length - 1 ? null : () => _move(list, i, 1),
              ),
            const SizedBox(height: 6),
            OutlinedButton.icon(onPressed: () => _editSection(null, list.length + 1), icon: const Icon(Icons.add_rounded, size: 18), label: const Text('New section')),
          ]),
        );

        final detail = sel == null
            ? const SurfaceCard(child: EmptyState(icon: Icons.sell_outlined, title: 'No services yet', text: 'Create a section such as “Dry Clean”, then add its items and prices.'))
            : _SectionDetail(
                doc: sel,
                query: _q,
                onQuery: (v) => setState(() => _q = v),
                onAdd: () => _editItem(sel),
                onEdit: (i) => _editItem(sel, i),
                onDelete: (item) => _deleteItem(sel, item),
                onEditSection: () => _editSection(sel),
                onDeleteSection: () async {
                  if (await _confirm('Delete “${sel.data()['name']}”?', 'The whole section and its ${_items(sel.data()).length} items disappear from the website and app.')) {
                    await sel.reference.delete();
                    setState(() => _selected = null);
                  }
                },
              );

        return AdminPage(
          title: 'Services & prices',
          subtitle: 'Your live price list. Every change appears on the website and in the customer app instantly.',
          actions: [
            const StatusPill('Live', icon: Icons.circle, c: AC.emerald7, bg: AC.mint),
            FilledButton.icon(onPressed: sel == null ? null : () => _editItem(sel), icon: const Icon(Icons.add_rounded, size: 19), label: const Text('Add item')),
          ],
          child: snap.connectionState == ConnectionState.waiting && list.isEmpty
              ? const Padding(padding: EdgeInsets.all(60), child: Center(child: CircularProgressIndicator()))
              : wide
                  ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [SizedBox(width: 330, child: sections), const SizedBox(width: 18), Expanded(child: detail)])
                  : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [sections, const SizedBox(height: 16), detail]),
        );
      },
    );
  }
}

class _SectionTile extends StatelessWidget {
  final QueryDocumentSnapshot<Map<String, dynamic>> doc;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onUp, onDown;
  const _SectionTile({required this.doc, required this.selected, required this.onTap, this.onUp, this.onDown});

  @override
  Widget build(BuildContext context) {
    final m = doc.data();
    final items = _items(m);
    final prices = items.map((i) => _num(i['price'])).where((v) => v > 0);
    final from = prices.isEmpty ? null : prices.reduce((a, b) => a < b ? a : b);
    final active = m['isActive'] != false;
    return Material(
      color: selected ? AC.mint : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
          child: Row(children: [
            Stack(clipBehavior: Clip.none, children: [
              Opacity(opacity: active ? 1 : .45, child: serviceIcon(iconKeyOf(m), size: 40, bg: selected ? Colors.white : AC.subtle)),
              Positioned(right: -2, bottom: -2, child: Container(width: 11, height: 11, decoration: BoxDecoration(color: active ? AC.emerald : AC.faint, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)))),
            ]),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${m['name'] ?? doc.id}', style: AC.t(14, w: FontWeight.w800, c: selected ? AC.forest : AC.ink)),
                Text('${items.length} items${from == null ? '' : ' · from ${_gbp(from)}'}${active ? '' : ' · hidden'}', style: AC.t(12, c: AC.mut)),
              ]),
            ),
            if (selected) ...[
              IconButton(tooltip: 'Move up', visualDensity: VisualDensity.compact, onPressed: onUp, icon: const Icon(Icons.keyboard_arrow_up_rounded)),
              IconButton(tooltip: 'Move down', visualDensity: VisualDensity.compact, onPressed: onDown, icon: const Icon(Icons.keyboard_arrow_down_rounded)),
            ],
          ]),
        ),
      ),
    );
  }
}

class _SectionDetail extends StatelessWidget {
  final QueryDocumentSnapshot<Map<String, dynamic>> doc;
  final String query;
  final ValueChanged<String> onQuery;
  final VoidCallback onAdd, onEditSection, onDeleteSection;
  final void Function(int) onEdit;
  final void Function(Map<String, dynamic>) onDelete;
  const _SectionDetail({required this.doc, required this.query, required this.onQuery, required this.onAdd, required this.onEdit, required this.onDelete, required this.onEditSection, required this.onDeleteSection});

  @override
  Widget build(BuildContext context) {
    final m = doc.data();
    final items = _items(m);
    final q = query.trim().toLowerCase();
    final groups = <String, List<int>>{};
    for (var i = 0; i < items.length; i++) {
      final it = items[i];
      if (q.isNotEmpty && !'${it['name']} ${it['category']} ${it['description'] ?? ''}'.toLowerCase().contains(q)) continue;
      groups.putIfAbsent('${it['category'] ?? ''}'.isEmpty ? 'Other' : '${it['category']}', () => []).add(i);
    }
    final active = m['isActive'] != false;
    final narrow = MediaQuery.sizeOf(context).width < 600;
    return SurfaceCard(
      padding: EdgeInsets.fromLTRB(narrow ? 14 : 20, 16, narrow ? 14 : 20, 18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (narrow) ...[
          Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
            Tooltip(message: 'Change icon & colour', child: InkWell(onTap: onEditSection, borderRadius: BorderRadius.circular(14), child: serviceIcon(iconKeyOf(m), size: 44, bg: cardColorsOf(m).$1))),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${m['name'] ?? doc.id}', style: AC.h(18)),
                if ('${m['description'] ?? ''}'.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 2), child: Text('${m['description']}', maxLines: 2, overflow: TextOverflow.ellipsis, style: AC.t(12.5, c: AC.mut))),
              ]),
            ),
            PopupMenuButton<String>(
              onSelected: (v) => v == 'edit' ? onEditSection() : onDeleteSection(),
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'edit', child: ListTile(dense: true, contentPadding: EdgeInsets.zero, leading: Icon(Icons.edit_outlined), title: Text('Edit section'))),
                PopupMenuItem(value: 'del', child: ListTile(dense: true, contentPadding: EdgeInsets.zero, leading: Icon(Icons.delete_outline_rounded, color: AC.danger), title: Text('Delete section'))),
              ],
            ),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            const Spacer(),
            Text(active ? 'Visible' : 'Hidden', style: AC.t(12.5, c: active ? AC.emerald7 : AC.mut, w: FontWeight.w700)),
            const SizedBox(width: 6),
            Switch(value: active, onChanged: (v) => doc.reference.update({'isActive': v, 'updatedAt': FieldValue.serverTimestamp()})),
          ]),
        ] else ...[
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Tooltip(message: 'Change icon & colour', child: InkWell(onTap: onEditSection, borderRadius: BorderRadius.circular(18), child: serviceIcon(iconKeyOf(m), size: 58, bg: cardColorsOf(m).$1))),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${m['name'] ?? doc.id}', style: AC.h(20)),
                if ('${m['description'] ?? ''}'.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text('${m['description']}', style: AC.t(13.5, c: AC.mut))),
              ]),
            ),
            Tooltip(
              message: active ? 'Shown to customers' : 'Hidden from customers',
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(active ? 'Visible' : 'Hidden', style: AC.t(13, c: active ? AC.emerald7 : AC.mut, w: FontWeight.w700)),
                Switch(value: active, onChanged: (v) => doc.reference.update({'isActive': v, 'updatedAt': FieldValue.serverTimestamp()})),
              ]),
            ),
            PopupMenuButton<String>(
              onSelected: (v) => v == 'edit' ? onEditSection() : onDeleteSection(),
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'edit', child: ListTile(dense: true, contentPadding: EdgeInsets.zero, leading: Icon(Icons.edit_outlined), title: Text('Edit section'))),
                PopupMenuItem(value: 'del', child: ListTile(dense: true, contentPadding: EdgeInsets.zero, leading: Icon(Icons.delete_outline_rounded, color: AC.danger), title: Text('Delete section'))),
              ],
            ),
          ]),
        ],
        const SizedBox(height: 14),
        if (narrow)
          Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            TextField(onChanged: onQuery, decoration: const InputDecoration(hintText: 'Search items', prefixIcon: Icon(Icons.search_rounded, size: 20))),
            const SizedBox(height: 10),
            FilledButton.icon(onPressed: onAdd, icon: const Icon(Icons.add_rounded, size: 19), label: const Text('Add item')),
          ])
        else
          Row(children: [
            Expanded(child: TextField(onChanged: onQuery, decoration: const InputDecoration(hintText: 'Search items', prefixIcon: Icon(Icons.search_rounded, size: 20)))),
            const SizedBox(width: 10),
            FilledButton.icon(onPressed: onAdd, icon: const Icon(Icons.add_rounded, size: 19), label: const Text('Add item')),
          ]),
        const SizedBox(height: 14),
        if (items.isEmpty)
          EmptyState(icon: Icons.playlist_add_rounded, title: 'No items yet', text: 'Add the first item and price for this section.', action: FilledButton(onPressed: onAdd, child: const Text('Add item')))
        else if (groups.isEmpty)
          const EmptyState(icon: Icons.search_off_rounded, title: 'No matches', text: 'Try another word.')
        else
          for (final g in groups.entries) ...[
            Padding(padding: const EdgeInsets.fromLTRB(4, 12, 4, 6), child: Text(g.key.toUpperCase(), style: AC.label())),
            Container(
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: AC.border)),
              child: Column(children: [
                for (var k = 0; k < g.value.length; k++)
                  _ItemRow(item: items[g.value[k]], first: k == 0, onEdit: () => onEdit(g.value[k]), onDelete: () => onDelete(items[g.value[k]])),
              ]),
            ),
          ],
      ]),
    );
  }
}

class _ItemRow extends StatelessWidget {
  final Map<String, dynamic> item;
  final bool first;
  final VoidCallback onEdit, onDelete;
  const _ItemRow({required this.item, required this.first, required this.onEdit, required this.onDelete});
  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onEdit,
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 10, 4, 10),
          decoration: BoxDecoration(border: first ? null : const Border(top: BorderSide(color: AC.border))),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${item['name'] ?? 'Item'}', style: AC.t(14, w: FontWeight.w700)),
                if ('${item['description'] ?? ''}'.isNotEmpty) Text('${item['description']}', maxLines: 1, overflow: TextOverflow.ellipsis, style: AC.t(12.5, c: AC.mut)),
              ]),
            ),
            Text(_gbp(_num(item['price'])), style: AC.num(15)),
            const SizedBox(width: 6),
            IconButton(tooltip: 'Edit', onPressed: onEdit, icon: const Icon(Icons.edit_outlined, size: 19)),
            IconButton(tooltip: 'Remove', onPressed: onDelete, icon: const Icon(Icons.delete_outline_rounded, size: 19, color: AC.faint)),
          ]),
        ),
      );
}

class _ItemDialog extends StatefulWidget {
  final Map<String, dynamic>? initial;
  final List<String> categories;
  const _ItemDialog({this.initial, required this.categories});
  @override
  State<_ItemDialog> createState() => _ItemDialogState();
}

class _ItemDialogState extends State<_ItemDialog> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: '${widget.initial?['name'] ?? ''}');
  late final _price = TextEditingController(text: widget.initial == null ? '' : _num(widget.initial!['price']).toStringAsFixed(2));
  late final _cat = TextEditingController(text: '${widget.initial?['category'] ?? (widget.categories.isEmpty ? '' : widget.categories.first)}');
  late final _desc = TextEditingController(text: '${widget.initial?['description'] ?? ''}');

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(widget.initial == null ? 'Add item' : 'Edit item'),
        content: SizedBox(
          width: 440,
          child: Form(
            key: _form,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextFormField(controller: _name, autofocus: true, decoration: const InputDecoration(labelText: 'Item name', hintText: 'e.g. 2 piece suit'), validator: (v) => (v ?? '').trim().isEmpty ? 'Required' : null),
              const SizedBox(height: 12),
              TextFormField(
                controller: _price,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                decoration: const InputDecoration(labelText: 'Price', prefixText: '£ '),
                validator: (v) => (double.tryParse(v ?? '') ?? -1) < 0 ? 'Enter a price, e.g. 4.90' : null,
              ),
              const SizedBox(height: 12),
              Autocomplete<String>(
                initialValue: TextEditingValue(text: _cat.text),
                optionsBuilder: (t) => widget.categories.where((c) => c.toLowerCase().contains(t.text.toLowerCase())),
                onSelected: (v) => _cat.text = v,
                fieldViewBuilder: (context, c, f, _) => TextFormField(
                  controller: c,
                  focusNode: f,
                  onChanged: (v) => _cat.text = v,
                  decoration: const InputDecoration(labelText: 'Group', hintText: 'e.g. Suits'),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(controller: _desc, decoration: const InputDecoration(labelText: 'Short note (optional)', hintText: 'e.g. Silk, linen or designer')),
            ]),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              if (!_form.currentState!.validate()) return;
              Navigator.pop(context, {
                'name': _name.text.trim(),
                'price': _gbp(double.parse(_price.text)),
                'category': _cat.text.trim(),
                if (_desc.text.trim().isNotEmpty) 'description': _desc.text.trim(),
              });
            },
            child: const Text('Save'),
          ),
        ],
      );
}

class _SectionDialog extends StatefulWidget {
  final Map<String, dynamic>? initial;
  const _SectionDialog({this.initial});
  @override
  State<_SectionDialog> createState() => _SectionDialogState();
}

class _SectionDialogState extends State<_SectionDialog> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: '${widget.initial?['name'] ?? ''}');
  late final _desc = TextEditingController(text: '${widget.initial?['description'] ?? ''}');
  late String _icon = widget.initial == null ? 'dry-cleaning' : iconKeyOf(widget.initial!);
  /// picked palette colour, or null = automatic (from the name)
  late int? _color = () {
    final l = (widget.initial?['cardColors'] as List?) ?? const [];
    if (l.length < 2) return null;
    final i = kCardPalette.indexWhere((p) => _hex(p.$3) == '${l[1]}'.toUpperCase());
    return i < 0 ? null : i;
  }();

  (Color, Color) get _colors => _color == null ? autoCardColors(_name.text) : (kCardPalette[_color!].$2, kCardPalette[_color!].$3);

  Widget _swatch(String label, Color a, Color b, bool on, VoidCallback tap, {bool auto = false}) => Tooltip(
        message: label,
        child: InkWell(
          onTap: tap,
          customBorder: const CircleBorder(),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [a, b]),
              border: Border.all(color: on ? AC.forest : Colors.white, width: on ? 3 : 2),
              boxShadow: [BoxShadow(color: b.withValues(alpha: .45), blurRadius: on ? 10 : 4, offset: const Offset(0, 3))],
            ),
            child: auto
                ? Icon(on ? Icons.check_rounded : Icons.auto_awesome_rounded, size: 18, color: Colors.white)
                : on
                    ? const Icon(Icons.check_rounded, size: 20, color: Colors.white)
                    : null,
          ),
        ),
      );

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(widget.initial == null ? 'New section' : 'Edit section'),
        content: SizedBox(
          width: 560,
          child: Form(
            key: _form,
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Row(children: [
                  // live preview: the icon on the card colour customers will see
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(19), gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [_colors.$1, _colors.$2])),
                    child: serviceIcon(_icon, size: 64, bg: Colors.transparent),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: TextFormField(
                      controller: _name,
                      autofocus: widget.initial == null,
                      onChanged: (_) => setState(() {}), // the automatic colour follows the name
                      decoration: const InputDecoration(labelText: 'Section name', hintText: 'e.g. Shoe care'),
                      validator: (v) => (v ?? '').trim().isEmpty ? 'Required' : null,
                    ),
                  ),
                ]),
                const SizedBox(height: 12),
                TextFormField(controller: _desc, maxLines: 2, decoration: const InputDecoration(labelText: 'Description (optional)')),
                const SizedBox(height: 18),
                Row(children: [Text('Card colour', style: AC.h(15)), const Spacer(), Text(_color == null ? 'Automatic — from the name' : kCardPalette[_color!].$1, style: AC.t(12, c: AC.mut))]),
                const SizedBox(height: 10),
                Wrap(spacing: 10, runSpacing: 10, children: [
                  _swatch('Automatic', autoCardColors(_name.text).$1, autoCardColors(_name.text).$2, _color == null, () => setState(() => _color = null), auto: true),
                  for (var i = 0; i < kCardPalette.length; i++) _swatch(kCardPalette[i].$1, kCardPalette[i].$2, kCardPalette[i].$3, _color == i, () => setState(() => _color = i)),
                ]),
                const SizedBox(height: 18),
                Row(children: [Text('Icon', style: AC.h(15)), const Spacer(), Text('Shown on the website and in the app', style: AC.t(12, c: AC.mut))]),
                const SizedBox(height: 10),
                Wrap(spacing: 10, runSpacing: 10, children: [
                  for (final (key, label) in kServiceIcons)
                    Tooltip(
                      message: label,
                      child: InkWell(
                        onTap: () => setState(() => _icon = key),
                        borderRadius: BorderRadius.circular(16),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          width: 96,
                          padding: const EdgeInsets.fromLTRB(6, 10, 6, 8),
                          decoration: BoxDecoration(
                            color: _icon == key ? AC.mint : AC.surface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: _icon == key ? AC.emerald : AC.border, width: _icon == key ? 2 : 1),
                          ),
                          child: Column(children: [
                            serviceIcon(key, size: 52, bg: Colors.transparent),
                            const SizedBox(height: 6),
                            Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: AC.t(11.5, w: _icon == key ? FontWeight.w800 : FontWeight.w600, c: _icon == key ? AC.forest : AC.ink2)),
                          ]),
                        ),
                      ),
                    ),
                ]),
              ]),
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => _form.currentState!.validate()
                ? Navigator.pop(context, <String, dynamic>{
                    'name': _name.text.trim(),
                    'description': _desc.text.trim(),
                    ...iconFields(_icon),
                    // the website and app colour the cards with this; null = automatic
                    'cardColors': _color == null ? null : [_hex(kCardPalette[_color!].$2), _hex(kCardPalette[_color!].$3)],
                  })
                : null,
            child: const Text('Save'),
          ),
        ],
      );
}
