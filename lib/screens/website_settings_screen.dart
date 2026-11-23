import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../theme/admin_ui.dart';

/// Everything the public website reads from `settings/website` in real time:
/// bookings on/off, delivery fee rules, home-page hero, areas, contact details, app links.
class WebsiteSettingsScreen extends StatefulWidget {
  const WebsiteSettingsScreen({super.key});
  @override
  State<WebsiteSettingsScreen> createState() => _WebsiteSettingsScreenState();
}

/// Same defaults the website falls back to, so nothing changes until you save.
const kWebsiteDefaults = <String, dynamic>{
  'bookingsOpen': true,
  'bookingsClosedMessage': 'We’re fully booked right now — please check back soon or call us.',
  'deliveryFee': 4.5,
  'freeDeliveryThreshold': 30,
  'heroBadge': 'Collections available today across West Midlands, Nottinghamshire, Yorkshire & Teesside',
  'heroTitle': 'Clean clothes,',
  'heroHighlight': 'without the chores.',
  'heroSubtitle': 'You get on with your day — we collect, clean and return your clothes in 24 hours, right to your door.',
  'areas': [
    'Birmingham', 'Walsall', 'Wolverhampton', 'Dudley', 'West Bromwich', 'Solihull', 'Sutton Coldfield', 'Coventry',
    'Nottingham', 'Newark-on-Trent', 'Lincoln', 'Mansfield', 'Grantham',
    'Sheffield', 'Leeds', 'Barnsley', 'Wakefield', 'Rotherham', 'Doncaster',
    'Stockton-on-Tees', 'Middlesbrough', 'Darlington', 'Hartlepool', 'Durham'
  ],
  'phone': '+44 7424 866802',
  'email': '',
  'whatsapp': '',
  'address': '',
  'appStoreUrl': 'https://apps.apple.com/pk/app/drycleanplus/id6797293315',
  'playStoreUrl': 'https://play.google.com/store/apps/details?id=com.drycleanplus.service.uk.app',
  'siteUrl': '',
};

class _WebsiteSettingsScreenState extends State<WebsiteSettingsScreen> {
  final _ref = FirebaseFirestore.instance.collection('settings').doc('website');
  final _form = GlobalKey<FormState>();
  final _c = <String, TextEditingController>{};
  bool _bookingsOpen = true;
  List<String> _areas = [];
  final _newArea = TextEditingController();
  bool _loaded = false, _dirty = false, _saving = false;
  DateTime? _savedAt;
  String _savedBy = '';

  static const _textKeys = [
    'bookingsClosedMessage', 'deliveryFee', 'freeDeliveryThreshold', 'heroBadge', 'heroTitle', 'heroHighlight', 'heroSubtitle',
    'phone', 'email', 'whatsapp', 'address', 'appStoreUrl', 'playStoreUrl', 'siteUrl',
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final snap = await _ref.get();
    final m = {...kWebsiteDefaults, ...?snap.data()};
    for (final k in _textKeys) {
      final v = m[k];
      _c[k] = TextEditingController(text: v is num ? (k == 'deliveryFee' ? v.toStringAsFixed(2) : v.toString()) : '${v ?? ''}')..addListener(_touch);
    }
    _bookingsOpen = m['bookingsOpen'] != false;
    _areas = ((m['areas'] as List?) ?? const []).map((e) => '$e').toList();
    _savedAt = (snap.data()?['updatedAt'] as Timestamp?)?.toDate();
    _savedBy = '${snap.data()?['updatedBy'] ?? ''}';
    if (mounted) setState(() => _loaded = true);
  }

  void _touch() {
    if (!_dirty && mounted) setState(() => _dirty = true);
  }

  @override
  void dispose() {
    for (final c in _c.values) {
      c.dispose();
    }
    _newArea.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    String v(String k) => _c[k]!.text.trim();
    try {
      await _ref.set({
        'bookingsOpen': _bookingsOpen,
        'bookingsClosedMessage': v('bookingsClosedMessage'),
        'deliveryFee': double.parse(v('deliveryFee')),
        'freeDeliveryThreshold': double.parse(v('freeDeliveryThreshold')),
        'heroBadge': v('heroBadge'),
        'heroTitle': v('heroTitle'),
        'heroHighlight': v('heroHighlight'),
        'heroSubtitle': v('heroSubtitle'),
        'areas': _areas,
        'phone': v('phone'),
        'email': v('email'),
        'whatsapp': v('whatsapp'),
        'address': v('address'),
        'appStoreUrl': v('appStoreUrl'),
        'playStoreUrl': v('playStoreUrl'),
        'siteUrl': v('siteUrl'),
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': FirebaseAuth.instance.currentUser?.email ?? 'admin',
      }, SetOptions(merge: true));
      setState(() {
        _dirty = false;
        _savedAt = DateTime.now();
        _savedBy = FirebaseAuth.instance.currentUser?.email ?? 'admin';
      });
      if (mounted) adminToast(context, 'Saved — the website has updated.');
    } catch (e) {
      if (mounted) adminToast(context, 'Couldn’t save: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String? _money(String? v) => double.tryParse((v ?? '').trim()) == null ? 'Enter a number, e.g. 4.50' : null;
  String? _url(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return null;
    final u = Uri.tryParse(s);
    return (u == null || !u.hasScheme || !s.startsWith('http')) ? 'Use a full link starting with https://' : null;
  }

  Widget _field(String k, {String? hint, int lines = 1, String? Function(String?)? validator, TextInputType? type, IconData? icon, String? prefix}) => TextFormField(
        controller: _c[k],
        minLines: lines,
        maxLines: lines == 1 ? 1 : lines + 2,
        keyboardType: type,
        validator: validator,
        inputFormatters: type == const TextInputType.numberWithOptions(decimal: true) ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))] : null,
        decoration: InputDecoration(hintText: hint, prefixIcon: icon == null ? null : Icon(icon, size: 19), prefixText: prefix),
      );

  @override
  Widget build(BuildContext context) {
    if (!_loaded) return const Center(child: CircularProgressIndicator());
    final fee = double.tryParse(_c['deliveryFee']!.text) ?? 0, free = double.tryParse(_c['freeDeliveryThreshold']!.text) ?? 0;
    final money = NumberFormat.currency(locale: 'en_GB', symbol: '£');
    return Form(
      key: _form,
      child: AdminPage(
        title: 'Website settings',
        subtitle: 'What visitors see on the website. Saved changes appear for everyone within a second — no redeploy needed.',
        actions: [
          if (_savedAt != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(_dirty ? 'Unsaved changes' : 'Saved ${DateFormat('d MMM, HH:mm').format(_savedAt!)}${_savedBy.isEmpty ? '' : ' · $_savedBy'}',
                  style: AC.t(12.5, c: _dirty ? AC.warning : AC.mut, w: FontWeight.w700)),
            ),
          FilledButton.icon(
            onPressed: _saving || !_dirty ? null : _save,
            icon: _saving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.cloud_upload_outlined, size: 19),
            label: const Text('Save & publish'),
          ),
        ],
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          // ---------------------------------------------------------- bookings
          SurfaceCard(
            title: 'Bookings',
            subtitle: 'Pause new orders on the website during holidays or when you’re at capacity.',
            child: Column(children: [
              Container(
                padding: const EdgeInsets.fromLTRB(16, 10, 10, 10),
                decoration: BoxDecoration(color: _bookingsOpen ? AC.mint : AC.dangerBg, borderRadius: BorderRadius.circular(14), border: Border.all(color: _bookingsOpen ? AC.mint2 : const Color(0xFFFECACA))),
                child: Row(children: [
                  Icon(_bookingsOpen ? Icons.check_circle_rounded : Icons.pause_circle_rounded, color: _bookingsOpen ? AC.emerald7 : AC.danger),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(_bookingsOpen ? 'Taking bookings' : 'Bookings paused', style: AC.t(15, w: FontWeight.w800, c: _bookingsOpen ? AC.emerald7 : AC.danger)),
                      Text(_bookingsOpen ? 'Customers can schedule pickups on the website.' : 'The “Schedule pickup” buttons show your message instead.', style: AC.t(13, c: AC.ink2)),
                    ]),
                  ),
                  Switch(value: _bookingsOpen, onChanged: (v) => setState(() {
                        _bookingsOpen = v;
                        _dirty = true;
                      })),
                ]),
              ),
              FieldRow(label: 'Message when paused', help: 'Shown to customers who try to book.', child: _field('bookingsClosedMessage', lines: 2)),
            ]),
          ),
          const SizedBox(height: 16),
          // ---------------------------------------------------------- delivery
          SurfaceCard(
            title: 'Delivery & pricing',
            subtitle: 'Used in the basket, checkout and the prices page.',
            child: Column(children: [
              FieldRow(label: 'Collection & delivery fee', help: 'Charged on orders below the free-delivery amount.', child: _field('deliveryFee', prefix: '£ ', type: const TextInputType.numberWithOptions(decimal: true), validator: _money)),
              FieldRow(label: 'Free delivery from', help: 'Basket total that removes the fee.', child: _field('freeDeliveryThreshold', prefix: '£ ', type: const TextInputType.numberWithOptions(decimal: true), validator: _money)),
              Container(
                margin: const EdgeInsets.only(top: 6),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: AC.subtle, borderRadius: BorderRadius.circular(12)),
                child: Row(children: [
                  const Icon(Icons.visibility_outlined, size: 18, color: AC.mut),
                  const SizedBox(width: 10),
                  Expanded(child: Text('Customers see: “Free delivery over ${free % 1 == 0 ? '£${free.toInt()}' : money.format(free)} · otherwise ${money.format(fee)}. Always free for DrycleanPlus+ members.”', style: AC.t(13, c: AC.ink2))),
                ]),
              ),
            ]),
          ),
          const SizedBox(height: 16),
          // ---------------------------------------------------------- hero
          SurfaceCard(
            title: 'Home page',
            subtitle: 'The first thing visitors read.',
            child: Column(children: [
              FieldRow(label: 'Live badge', help: 'Small line above the headline.', child: _field('heroBadge')),
              FieldRow(label: 'Headline', help: 'First line, then the highlighted (green) line.', child: Row(children: [Expanded(child: _field('heroTitle')), const SizedBox(width: 10), Expanded(child: _field('heroHighlight'))])),
              FieldRow(label: 'Intro text', child: _field('heroSubtitle', lines: 2)),
              const SizedBox(height: 8),
              _HeroPreview(badge: _c['heroBadge']!.text, title: _c['heroTitle']!.text, highlight: _c['heroHighlight']!.text, sub: _c['heroSubtitle']!.text),
            ]),
          ),
          const SizedBox(height: 16),
          // ---------------------------------------------------------- areas
          SurfaceCard(
            title: 'Areas we cover',
            subtitle: 'Scrolling list on the home page. Drag isn’t needed — add, remove, done.',
            trailing: Text('${_areas.length} areas', style: AC.t(13, c: AC.mut, w: FontWeight.w700)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final a in _areas)
                  InputChip(
                    label: Text(a),
                    onDeleted: () => setState(() {
                      _areas.remove(a);
                      _dirty = true;
                    }),
                  ),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: TextField(
                    controller: _newArea,
                    decoration: const InputDecoration(hintText: 'Add an area, e.g. Stratford', prefixIcon: Icon(Icons.add_location_alt_outlined, size: 19)),
                    onSubmitted: (_) => _addArea(),
                  ),
                ),
                const SizedBox(width: 10),
                OutlinedButton(onPressed: _addArea, child: const Text('Add')),
              ]),
            ]),
          ),
          const SizedBox(height: 16),
          // ---------------------------------------------------------- contact
          SurfaceCard(
            title: 'Contact details',
            subtitle: 'One phone number everywhere — header, footer, booking confirmation and live tracking.',
            child: Column(children: [
              FieldRow(label: 'Phone', child: _field('phone', icon: Icons.call_outlined, type: TextInputType.phone, validator: (v) => (v ?? '').trim().isEmpty ? 'A phone number is required' : null)),
              FieldRow(label: 'Email', child: _field('email', icon: Icons.mail_outline_rounded, type: TextInputType.emailAddress, hint: 'hello@yourdomain.co.uk')),
              FieldRow(label: 'WhatsApp', help: 'Optional — number with country code.', child: _field('whatsapp', icon: Icons.chat_outlined, type: TextInputType.phone, hint: '+44 7…')),
              FieldRow(label: 'Address', help: 'Optional — shown in the footer.', child: _field('address', icon: Icons.storefront_outlined, lines: 2)),
            ]),
          ),
          const SizedBox(height: 16),
          // ---------------------------------------------------------- links
          SurfaceCard(
            title: 'Links',
            child: Column(children: [
              FieldRow(label: 'App Store', child: _field('appStoreUrl', icon: Icons.apple, validator: _url)),
              FieldRow(label: 'Google Play', child: _field('playStoreUrl', icon: Icons.shop_outlined, validator: _url)),
              FieldRow(label: 'Website address', help: 'Used by “View website” in this console.', child: _field('siteUrl', icon: Icons.language_rounded, hint: 'https://www.yourdomain.co.uk', validator: _url)),
            ]),
          ),
          const SizedBox(height: 16),
          Text('Stored in Firestore · settings/website', textAlign: TextAlign.center, style: AC.t(12, c: AC.faint)),
        ]),
      ),
    );
  }

  void _addArea() {
    final v = _newArea.text.trim();
    if (v.isEmpty || _areas.any((a) => a.toLowerCase() == v.toLowerCase())) return;
    setState(() {
      _areas.add(v);
      _dirty = true;
      _newArea.clear();
    });
  }
}

class _HeroPreview extends StatelessWidget {
  final String badge, title, highlight, sub;
  const _HeroPreview({required this.badge, required this.title, required this.highlight, required this.sub});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFF5F8F6), Color(0xFFE9F7EF)]),
          border: Border.all(color: AC.border),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [Text('PREVIEW', style: AC.label()), const Spacer()]),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(99)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 7, height: 7, decoration: const BoxDecoration(color: Color(0xFF22C55E), shape: BoxShape.circle)),
              const SizedBox(width: 6),
              Text(badge, style: AC.t(12, c: AC.forest, w: FontWeight.w700)),
            ]),
          ),
          const SizedBox(height: 10),
          Text(title, style: AC.h(26, c: AC.ink)),
          Text(highlight, style: AC.h(26, c: AC.emerald)),
          const SizedBox(height: 8),
          Text(sub, style: AC.t(14, c: AC.ink2, height: 1.5)),
        ]),
      );
}
