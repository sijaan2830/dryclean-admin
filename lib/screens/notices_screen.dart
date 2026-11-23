import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../theme/admin_ui.dart';

/// Website notice board — `notices` collection, read live by the website's
/// NoticeBanner (slim bar under the header + details popup) and the customer app.
class NoticesScreen extends StatefulWidget {
  const NoticesScreen({super.key});
  @override
  State<NoticesScreen> createState() => _NoticesScreenState();
}

class _Look {
  final String label;
  final IconData icon;
  final Color a, bg, bd, tx;
  const _Look(this.label, this.icon, this.a, this.bg, this.bd, this.tx);
}

// identical to the website's .nb / .nb--important / .nb--holiday / .nb--info styles
const _types = <String, _Look>{
  'delay': _Look('Service delay', Icons.warning_amber_rounded, Color(0xFFD97706), Color(0xFFFFFBEB), Color(0xFFFDE68A), Color(0xFF78350F)),
  'important': _Look('Important', Icons.error_outline_rounded, Color(0xFFDC2626), Color(0xFFFEF2F2), Color(0xFFFECACA), Color(0xFF7F1D1D)),
  'holiday': _Look('Holiday hours', Icons.event_rounded, Color(0xFF7C3AED), Color(0xFFF5F3FF), Color(0xFFDDD6FE), Color(0xFF4C1D95)),
  'info': _Look('Service update', Icons.info_outline_rounded, Color(0xFF059669), Color(0xFFECFDF5), Color(0xFFA7F3D0), Color(0xFF064E3B)),
};
_Look _look(String? t) => _types[(t ?? 'delay').toLowerCase()] ?? _types['delay']!;

DateTime? _dt(Object? v) => v is Timestamp ? v.toDate() : null;

/// Live · Scheduled · Ended · Off — what visitors see right now.
(String, Color, Color) _state(Map<String, dynamic> m) {
  if (m['isActive'] != true) return ('Off', AC.mut, AC.subtle);
  final now = DateTime.now(), s = _dt(m['startsAt']), e = _dt(m['endsAt']);
  if (s != null && s.isAfter(now)) return ('Scheduled', AC.info, AC.infoBg);
  if (e != null && e.isBefore(now)) return ('Ended', AC.mut, AC.subtle);
  return ('Live', AC.emerald7, AC.mint);
}

class _NoticesScreenState extends State<NoticesScreen> {
  final _col = FirebaseFirestore.instance.collection('notices');
  late final _stream = _col.snapshots();
  String _filter = 'all';

  Future<void> _edit([QueryDocumentSnapshot<Map<String, dynamic>>? doc, bool duplicate = false]) async {
    final data = await showDialog<Map<String, dynamic>>(context: context, barrierDismissible: false, builder: (_) => _Editor(initial: doc?.data(), duplicate: duplicate));
    if (data == null) return;
    if (doc == null || duplicate) {
      await _col.add({...data, 'createdAt': FieldValue.serverTimestamp(), 'updatedAt': FieldValue.serverTimestamp()});
      if (mounted) adminToast(context, data['isActive'] == true ? 'Notice published — it’s on the website now.' : 'Notice saved as off.');
    } else {
      await doc.reference.update({...data, 'updatedAt': FieldValue.serverTimestamp()});
      if (mounted) adminToast(context, 'Notice updated — visitors see the change instantly.');
    }
  }

  Future<void> _delete(QueryDocumentSnapshot<Map<String, dynamic>> doc) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete this notice?'),
        content: Text('“${doc.data()['title'] ?? 'Notice'}” will be removed from the website and app.'),
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
        final all = [...(snap.data?.docs ?? const <QueryDocumentSnapshot<Map<String, dynamic>>>[])]
          ..sort((a, b) => (_dt(b.data()['createdAt']) ?? DateTime(2000)).compareTo(_dt(a.data()['createdAt']) ?? DateTime(2000)));
        final counts = <String, int>{'all': all.length};
        for (final d in all) {
          final s = _state(d.data()).$1.toLowerCase();
          counts[s] = (counts[s] ?? 0) + 1;
        }
        final list = _filter == 'all' ? all : all.where((d) => _state(d.data()).$1.toLowerCase() == _filter).toList();
        return AdminPage(
          title: 'Notices',
          subtitle: 'Banners and pop-ups on the website and in the customer app. Changes go live instantly.',
          actions: [FilledButton.icon(onPressed: () => _edit(), icon: const Icon(Icons.add_rounded, size: 20), label: const Text('New notice'))],
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final (k, l) in [('all', 'All'), ('live', 'Live'), ('scheduled', 'Scheduled'), ('off', 'Off'), ('ended', 'Ended')])
                ChoiceChip(label: Text('$l  ${counts[k] ?? 0}'), selected: _filter == k, onSelected: (_) => setState(() => _filter = k)),
            ]),
            const SizedBox(height: 16),
            if (snap.connectionState == ConnectionState.waiting)
              const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()))
            else if (list.isEmpty)
              SurfaceCard(
                child: EmptyState(
                  icon: Icons.campaign_rounded,
                  title: _filter == 'all' ? 'No notices yet' : 'Nothing here',
                  text: 'Tell customers about delays, holiday hours or service changes. They appear on the website straight away.',
                  action: _filter == 'all' ? FilledButton.icon(onPressed: () => _edit(), icon: const Icon(Icons.add_rounded), label: const Text('Create the first notice')) : null,
                ),
              )
            else
              for (final d in list) Padding(padding: const EdgeInsets.only(bottom: 12), child: _NoticeCard(doc: d, onEdit: () => _edit(d), onDuplicate: () => _edit(d, true), onDelete: () => _delete(d))),
          ]),
        );
      },
    );
  }
}

class _NoticeCard extends StatelessWidget {
  final QueryDocumentSnapshot<Map<String, dynamic>> doc;
  final VoidCallback onEdit, onDuplicate, onDelete;
  const _NoticeCard({required this.doc, required this.onEdit, required this.onDuplicate, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final m = doc.data();
    final look = _look(m['type'] as String?);
    final st = _state(m);
    final s = _dt(m['startsAt']), e = _dt(m['endsAt']);
    final f = DateFormat('d MMM, HH:mm');
    final mode = '${m['displayMode'] ?? 'both'}';
    final chips = <Widget>[
      StatusPill(look.label, c: look.a, bg: look.bg, icon: look.icon),
      if (m['showOnWebsite'] != false) const StatusPill('Website', c: AC.ink2, bg: AC.subtle, icon: Icons.language_rounded),
      if (m['showInApp'] == true) const StatusPill('App', c: AC.ink2, bg: AC.subtle, icon: Icons.phone_iphone_rounded),
      StatusPill(mode == 'banner_only' ? 'Banner' : mode == 'popup_only' ? 'Pop-up' : 'Banner + pop-up', c: AC.ink2, bg: AC.subtle),
      if ('${m['estimatedDelay'] ?? ''}'.isNotEmpty) StatusPill('${m['estimatedDelay']}', c: AC.ink2, bg: AC.subtle, icon: Icons.schedule_rounded),
      if ('${m['affectedArea'] ?? ''}'.isNotEmpty) StatusPill('${m['affectedArea']}', c: AC.ink2, bg: AC.subtle, icon: Icons.place_outlined),
      if (s != null || e != null) StatusPill([if (s != null) 'from ${f.format(s)}', if (e != null) 'until ${f.format(e)}'].join(' '), c: AC.info, bg: AC.infoBg, icon: Icons.event_rounded),
    ];
    return Container(
      decoration: BoxDecoration(color: AC.surface, borderRadius: BorderRadius.circular(AC.radius), border: Border.all(color: AC.border), boxShadow: AC.shadow(.04)),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Container(width: 5, color: look.a),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 10, 16),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(width: 40, height: 40, decoration: BoxDecoration(color: look.a, borderRadius: BorderRadius.circular(11)), child: Icon(look.icon, color: Colors.white, size: 21)),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Flexible(child: Text('${m['title'] ?? 'Untitled notice'}', style: AC.h(16))),
                      const SizedBox(width: 10),
                      StatusPill(st.$1, c: st.$2, bg: st.$3, icon: st.$1 == 'Live' ? Icons.circle : null),
                    ]),
                    if ('${m['message'] ?? ''}'.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text('${m['message']}', maxLines: 2, overflow: TextOverflow.ellipsis, style: AC.t(13.5, c: AC.ink2))),
                    const SizedBox(height: 10),
                    Wrap(spacing: 6, runSpacing: 6, children: chips),
                  ]),
                ),
                const SizedBox(width: 8),
                Column(children: [
                  Tooltip(
                    message: m['isActive'] == true ? 'Turn off' : 'Publish',
                    child: Switch(value: m['isActive'] == true, onChanged: (v) => doc.reference.update({'isActive': v, 'updatedAt': FieldValue.serverTimestamp()})),
                  ),
                  PopupMenuButton<String>(
                    tooltip: 'More',
                    icon: const Icon(Icons.more_horiz_rounded),
                    onSelected: (v) => v == 'edit' ? onEdit() : v == 'dup' ? onDuplicate() : onDelete(),
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'edit', child: ListTile(dense: true, contentPadding: EdgeInsets.zero, leading: Icon(Icons.edit_outlined), title: Text('Edit'))),
                      PopupMenuItem(value: 'dup', child: ListTile(dense: true, contentPadding: EdgeInsets.zero, leading: Icon(Icons.copy_rounded), title: Text('Duplicate'))),
                      PopupMenuItem(value: 'del', child: ListTile(dense: true, contentPadding: EdgeInsets.zero, leading: Icon(Icons.delete_outline_rounded, color: AC.danger), title: Text('Delete'))),
                    ],
                  ),
                ]),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}

// ================================================================ editor
class _Editor extends StatefulWidget {
  final Map<String, dynamic>? initial;
  final bool duplicate;
  const _Editor({this.initial, this.duplicate = false});
  @override
  State<_Editor> createState() => _EditorState();
}

class _EditorState extends State<_Editor> {
  final _form = GlobalKey<FormState>();
  late final Map<String, dynamic> _i = widget.initial ?? const {};
  late final _title = TextEditingController(text: '${_i['title'] ?? ''}${widget.duplicate ? ' (copy)' : ''}');
  late final _message = TextEditingController(text: '${_i['message'] ?? ''}');
  late final _delay = TextEditingController(text: '${_i['estimatedDelay'] ?? ''}');
  late final _area = TextEditingController(text: '${_i['affectedArea'] ?? ''}');
  late String _type = _types.containsKey(_i['type']) ? '${_i['type']}' : 'delay';
  late String _mode = const ['both', 'banner_only', 'popup_only'].contains(_i['displayMode']) ? '${_i['displayMode']}' : 'both';
  late bool _active = widget.duplicate ? false : (_i['isActive'] ?? true) == true;
  late bool _web = _i['showOnWebsite'] != false;
  late bool _app = _i['showInApp'] == true;
  late int _priority = (_i['priority'] as num?)?.toInt() ?? 1;
  late DateTime? _start = _dt(_i['startsAt']);
  late DateTime? _end = _dt(_i['endsAt']);

  @override
  void initState() {
    super.initState();
    for (final c in [_title, _message, _delay, _area]) {
      c.addListener(() => setState(() {}));
    }
  }

  Future<DateTime?> _pick(DateTime? current) async {
    final now = DateTime.now();
    final d = await showDatePicker(context: context, initialDate: current ?? now, firstDate: now.subtract(const Duration(days: 1)), lastDate: now.add(const Duration(days: 365)));
    if (d == null || !mounted) return null;
    final t = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(current ?? now));
    return DateTime(d.year, d.month, d.day, t?.hour ?? 0, t?.minute ?? 0);
  }

  Map<String, dynamic> _data() => {
        'title': _title.text.trim(),
        'message': _message.text.trim(),
        'type': _type,
        'estimatedDelay': _delay.text.trim(),
        'affectedArea': _area.text.trim(),
        'displayMode': _mode,
        'showAsPopup': _mode != 'banner_only',
        'showOnWebsite': _web,
        'showInApp': _app,
        'isActive': _active,
        'priority': _priority,
        'startsAt': _start == null ? null : Timestamp.fromDate(_start!),
        'endsAt': _end == null ? null : Timestamp.fromDate(_end!),
      };

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final wide = size.width >= 1100;
    final f = DateFormat('EEE d MMM, HH:mm');
    final form = Form(
      key: _form,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('Type', style: AC.t(13, w: FontWeight.w700)),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final e in _types.entries)
            ChoiceChip(
              showCheckmark: false,
              avatar: Icon(e.value.icon, size: 17, color: e.value.a),
              label: Text(e.value.label),
              selected: _type == e.key,
              selectedColor: e.value.bg,
              side: BorderSide(color: _type == e.key ? e.value.bd : AC.border),
              onSelected: (_) => setState(() => _type = e.key),
            ),
        ]),
        const SizedBox(height: 16),
        TextFormField(controller: _title, decoration: const InputDecoration(labelText: 'Headline', hintText: 'e.g. Heavy traffic in West London'), maxLength: 80, validator: (v) => (v ?? '').trim().isEmpty ? 'Add a short headline' : null),
        const SizedBox(height: 6),
        TextFormField(controller: _message, minLines: 2, maxLines: 4, maxLength: 300, decoration: const InputDecoration(labelText: 'Message', hintText: 'What customers need to know, in one or two sentences')),
        const SizedBox(height: 6),
        Row(children: [
          Expanded(child: TextFormField(controller: _delay, decoration: const InputDecoration(labelText: 'Delay (optional)', hintText: '+15 to +25 mins', prefixIcon: Icon(Icons.schedule_rounded)))),
          const SizedBox(width: 10),
          Expanded(child: TextFormField(controller: _area, decoration: const InputDecoration(labelText: 'Area (optional)', hintText: 'West London', prefixIcon: Icon(Icons.place_outlined)))),
        ]),
        const SizedBox(height: 18),
        Text('How it appears', style: AC.t(13, w: FontWeight.w700)),
        const SizedBox(height: 8),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'both', label: Text('Banner + pop-up')),
            ButtonSegment(value: 'banner_only', label: Text('Banner only')),
            ButtonSegment(value: 'popup_only', label: Text('Pop-up only')),
          ],
          selected: {_mode},
          onSelectionChanged: (s) => setState(() => _mode = s.first),
        ),
        const SizedBox(height: 14),
        Wrap(spacing: 8, runSpacing: 8, children: [
          FilterChip(showCheckmark: false, avatar: const Icon(Icons.language_rounded, size: 17), label: const Text('Website'), selected: _web, onSelected: (v) => setState(() => _web = v)),
          FilterChip(showCheckmark: false, avatar: const Icon(Icons.phone_iphone_rounded, size: 17), label: const Text('Customer app'), selected: _app, onSelected: (v) => setState(() => _app = v)),
          FilterChip(showCheckmark: false, avatar: const Icon(Icons.push_pin_outlined, size: 17), label: const Text('Pin to top'), selected: _priority >= 5, onSelected: (v) => setState(() => _priority = v ? 5 : 1)),
        ]),
        const SizedBox(height: 18),
        Text('Schedule (optional)', style: AC.t(13, w: FontWeight.w700)),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          InputChip(
            avatar: const Icon(Icons.play_arrow_rounded, size: 18),
            label: Text(_start == null ? 'Starts now' : 'From ${f.format(_start!)}'),
            onPressed: () async {
              final d = await _pick(_start);
              if (d != null) setState(() => _start = d);
            },
            onDeleted: _start == null ? null : () => setState(() => _start = null),
          ),
          InputChip(
            avatar: const Icon(Icons.stop_rounded, size: 18),
            label: Text(_end == null ? 'No end date' : 'Until ${f.format(_end!)}'),
            onPressed: () async {
              final d = await _pick(_end);
              if (d != null) setState(() => _end = d);
            },
            onDeleted: _end == null ? null : () => setState(() => _end = null),
          ),
        ]),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.fromLTRB(14, 6, 8, 6),
          decoration: BoxDecoration(color: _active ? AC.mint : AC.subtle, borderRadius: BorderRadius.circular(12), border: Border.all(color: _active ? AC.mint2 : AC.border)),
          child: Row(children: [
            Icon(_active ? Icons.public_rounded : Icons.public_off_rounded, color: _active ? AC.emerald7 : AC.mut),
            const SizedBox(width: 10),
            Expanded(child: Text(_active ? 'Published — visible as soon as you save' : 'Off — saved but not shown', style: AC.t(13.5, w: FontWeight.w700, c: _active ? AC.emerald7 : AC.ink2))),
            Switch(value: _active, onChanged: (v) => setState(() => _active = v)),
          ]),
        ),
      ]),
    );

    final preview = _Preview(type: _type, title: _title.text.trim(), message: _message.text.trim(), delay: _delay.text.trim(), area: _area.text.trim(), mode: _mode);

    return Dialog(
      insetPadding: EdgeInsets.symmetric(horizontal: wide ? 40 : 12, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: wide ? 1100 : 640, maxHeight: size.height - 48),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 12, 12),
            child: Row(children: [
              Expanded(child: Text(widget.initial == null || widget.duplicate ? 'New notice' : 'Edit notice', style: AC.h(20))),
              IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded)),
            ]),
          ),
          const Divider(),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: wide
                  ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(flex: 5, child: form), const SizedBox(width: 28), Expanded(flex: 5, child: preview)])
                  : Column(children: [form, const SizedBox(height: 24), preview]),
            ),
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
            child: Row(children: [
              Text('Saved to Firestore · notices', style: AC.t(12.5, c: AC.faint)),
              const Spacer(),
              OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
              const SizedBox(width: 10),
              FilledButton.icon(
                onPressed: () {
                  if (_form.currentState!.validate()) Navigator.pop(context, _data());
                },
                icon: Icon(_active ? Icons.publish_rounded : Icons.save_outlined, size: 19),
                label: Text(_active ? 'Publish' : 'Save'),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

/// Mirrors how the notice looks on the website.
class _Preview extends StatelessWidget {
  final String type, title, message, delay, area, mode;
  const _Preview({required this.type, required this.title, required this.message, required this.delay, required this.area, required this.mode});

  Widget _chip(IconData i, String t, _Look l) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: .7), borderRadius: BorderRadius.circular(99), border: Border.all(color: l.bd)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(i, size: 12, color: l.tx), const SizedBox(width: 4), Text(t, style: AC.t(11.5, c: l.tx, w: FontWeight.w700))]),
      );

  @override
  Widget build(BuildContext context) {
    final l = _look(type);
    final head = title.isEmpty ? 'Your headline appears here' : title;
    final banner = Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(color: l.bg, border: Border(bottom: BorderSide(color: l.bd))),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(width: 28, height: 28, decoration: BoxDecoration(color: l.a, borderRadius: BorderRadius.circular(8)), child: Icon(l.icon, size: 16, color: Colors.white)),
        const SizedBox(width: 10),
        Expanded(
          child: Wrap(spacing: 6, runSpacing: 5, crossAxisAlignment: WrapCrossAlignment.center, children: [
            Text(head, style: AC.t(13, c: l.tx, w: FontWeight.w800)),
            if (delay.isNotEmpty) _chip(Icons.schedule_rounded, delay, l),
            if (area.isNotEmpty) _chip(Icons.place_outlined, area, l),
            if (message.isNotEmpty) Text(message, maxLines: 1, overflow: TextOverflow.ellipsis, style: AC.t(12.5, c: l.tx)),
          ]),
        ),
        const SizedBox(width: 8),
        Text('Details', style: AC.t(12.5, c: l.a, w: FontWeight.w800)),
        const SizedBox(width: 8),
        Icon(Icons.close_rounded, size: 16, color: l.tx.withValues(alpha: .6)),
      ]),
    );
    final popup = Container(
      width: 320,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 30, offset: Offset(0, 14))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          Container(width: 38, height: 38, decoration: BoxDecoration(color: l.a, borderRadius: BorderRadius.circular(11)), child: Icon(l.icon, color: Colors.white, size: 20)),
          const SizedBox(width: 10),
          Text(l.label.toUpperCase(), style: AC.label(c: l.a)),
        ]),
        const SizedBox(height: 12),
        Text(head, style: AC.h(17)),
        if (message.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Text(message, style: AC.t(13.5, c: AC.ink2, height: 1.45))),
        if (delay.isNotEmpty || area.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(spacing: 6, runSpacing: 6, children: [if (delay.isNotEmpty) _chip(Icons.schedule_rounded, delay, l), if (area.isNotEmpty) _chip(Icons.place_outlined, area, l)]),
        ],
        const SizedBox(height: 14),
        Container(height: 40, alignment: Alignment.center, decoration: BoxDecoration(color: AC.forest, borderRadius: BorderRadius.circular(11)), child: Text('Got it', style: AC.t(13.5, c: Colors.white, w: FontWeight.w800))),
      ]),
    );
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [Text('LIVE PREVIEW', style: AC.label()), const SizedBox(width: 8), const StatusPill('Website', c: AC.ink2, bg: AC.subtle, icon: Icons.language_rounded)]),
      const SizedBox(height: 10),
      Container(
        decoration: BoxDecoration(color: const Color(0xFFF1F4F2), borderRadius: BorderRadius.circular(16), border: Border.all(color: AC.border)),
        clipBehavior: Clip.antiAlias,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          // mini browser chrome + site header
          Container(
            height: 30,
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(children: [
              for (final c in const [Color(0xFFFCA5A5), Color(0xFFFDE68A), Color(0xFFA7F3D0)]) Container(width: 9, height: 9, margin: const EdgeInsets.only(right: 5), decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
              const SizedBox(width: 8),
              Expanded(child: Container(height: 16, decoration: BoxDecoration(color: AC.subtle, borderRadius: BorderRadius.circular(6)))),
            ]),
          ),
          Container(
            height: 42,
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(children: [
              Container(width: 26, height: 26, decoration: BoxDecoration(color: AC.forest, borderRadius: BorderRadius.circular(8)), alignment: Alignment.center, child: Text('DC', style: AC.h(10, c: AC.gold))),
              const SizedBox(width: 8),
              Text('DryClean Plus', style: AC.t(12.5, w: FontWeight.w800)),
              const Spacer(),
              Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: AC.gold, borderRadius: BorderRadius.circular(8)), child: Text('SCHEDULE PICKUP', style: AC.t(9.5, c: AC.forest, w: FontWeight.w800))),
            ]),
          ),
          if (mode != 'popup_only') banner,
          SizedBox(
            height: mode == 'banner_only' ? 70 : 290,
            child: Stack(alignment: Alignment.center, children: [
              Positioned.fill(child: Container(color: mode == 'banner_only' ? const Color(0xFFF1F4F2) : Colors.black.withValues(alpha: .35))),
              if (mode != 'banner_only') popup else Text('No pop-up — banner only', style: AC.t(12.5, c: AC.mut)),
            ]),
          ),
        ]),
      ),
    ]);
  }
}
