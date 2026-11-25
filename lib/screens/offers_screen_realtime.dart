import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/firebase_admin_service.dart';
import '../widgets/responsive.dart';
import 'package:intl/intl.dart';
import '../services/fcm_sender_service.dart';
import '../services/resend_email_service.dart';

// ─── Design Tokens ────────────────────────────────────────────────────────────

class _P {
  static const Color surface    = Color(0xFFF5F7F5);
  static const Color card       = Color(0xFFFFFFFF);
  static const Color border     = Color(0xFFE5E9E7);
  static const Color borderSoft = Color(0xFFF1F5F9);

  static const Color azure      = Color(0xFF047857);
  static const Color azureLight = Color(0xFFECFDF5);
  static const Color azureMid   = Color(0xFFA7F3D0);
  static const Color emerald    = Color(0xFF059669);
  static const Color emeraldBg  = Color(0xFFECFDF5);
  static const Color rose       = Color(0xFFE11D48);
  static const Color roseBg     = Color(0xFFFFF1F2);
  static const Color amber      = Color(0xFFD97706);
  static const Color amberBg    = Color(0xFFFFFBEB);
  static const Color amberMid   = Color(0xFFFDE68A);

  static const Color textPrimary   = Color(0xFF111827);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textTertiary  = Color(0xFF9CA3AF);
  static const Color textMuted     = Color(0xFFCBD5E1);
}

class _T {
  static TextStyle display(double sz,
          {FontWeight w = FontWeight.w700,
          Color c = _P.textPrimary}) =>
      GoogleFonts.plusJakartaSans(
          fontSize: sz, fontWeight: w, color: c, letterSpacing: -0.4);

  static TextStyle body(double sz,
          {FontWeight w = FontWeight.w400,
          Color c = _P.textSecondary}) =>
      GoogleFonts.plusJakartaSans(fontSize: sz, fontWeight: w, color: c);

  static TextStyle label(double sz,
          {FontWeight w = FontWeight.w600,
          Color c = _P.textSecondary}) =>
      GoogleFonts.plusJakartaSans(
          fontSize: sz, fontWeight: w, color: c, letterSpacing: 0.2);
}

// ─── Gradient palettes ────────────────────────────────────────────────────────

const List<List<Color>> _kGradients = [
  [Color(0xFF1A1F3A), Color(0xFF2D3561)],
  [Color(0xFF0D2137), Color(0xFF0F4C75)],
  [Color(0xFF0F172A), Color(0xFF0F3460)],
  [Color(0xFF2C1654), Color(0xFF1A1040)],
  [Color(0xFF0B3D2E), Color(0xFF0D5C42)],
];

List<Color> _gradientFor(String id) =>
    _kGradients[id.hashCode.abs() % _kGradients.length];

// ─── Screen ───────────────────────────────────────────────────────────────────

class OffersScreenRealtime extends StatefulWidget {
  const OffersScreenRealtime({super.key});

  @override
  State<OffersScreenRealtime> createState() => _OffersScreenRealtimeState();
}

class _OffersScreenRealtimeState extends State<OffersScreenRealtime> {
  final FirebaseAdminService _adminService = FirebaseAdminService();
  final FCMSenderService _fcmSenderService = FCMSenderService();
  String _filter = 'all'; // 'all' | 'active' | 'inactive' | 'expired'

  @override
  Widget build(BuildContext context) {
    final bool isMobile = Responsive.isMobile(context);

    return Scaffold(
      backgroundColor: _P.surface,
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _adminService.getOffersStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _buildShimmerLoading();
          }

          if (snapshot.hasError) {
            return _buildErrorState('${snapshot.error}');
          }

          final allOffers = snapshot.data ?? [];
          final now       = DateTime.now();

          final offers = allOffers.where((o) {
            final exp     = o['expiryDate'] as DateTime?;
            final active  = o['isActive'] as bool? ?? true;
            final expired = exp != null && exp.isBefore(now);
            switch (_filter) {
              case 'active':   return active && !expired;
              case 'inactive': return !active;
              case 'expired':  return expired;
              default:         return true;
            }
          }).toList();

          final totalActive = allOffers.where((o) {
            final exp = o['expiryDate'] as DateTime?;
            return (o['isActive'] ?? true) && (exp == null || exp.isAfter(now));
          }).length;
          final totalExpired = allOffers.where((o) {
            final exp = o['expiryDate'] as DateTime?;
            return exp != null && exp.isBefore(now);
          }).length;

          return Padding(
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 16 : 32,
              vertical:   isMobile ? 20 : 32,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(isMobile, allOffers.length, allOffers),
                const SizedBox(height: 20),
                _buildStatRow(allOffers.length, totalActive, totalExpired),
                const SizedBox(height: 20),
                _buildFilterBar(),
                const SizedBox(height: 20),
                Expanded(
                  child: offers.isEmpty
                      ? _buildEmptyState()
                      : _buildGrid(isMobile, offers),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────

  Widget _buildHeader(bool isMobile, int total, List<Map<String, dynamic>> offers) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Offers & Promotions', style: _T.display(isMobile ? 22 : 30)),
            const SizedBox(height: 4),
            Text('$total offer${total == 1 ? '' : 's'} total',
                style: _T.body(13)),
          ],
        ),
        Wrap(
          spacing: 10,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: () => _showPromoEmailDialog(offers),
              icon: const Icon(Icons.mark_email_read_outlined, size: 18),
              label: Text(isMobile ? 'Email' : 'Promo Email'),
              style: OutlinedButton.styleFrom(
                foregroundColor: _P.azure,
                side: const BorderSide(color: _P.azure),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                textStyle: _T.label(13, c: _P.azure),
              ),
            ),
            ElevatedButton.icon(
              onPressed: () => _showOfferDialog(),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: Text(isMobile ? 'Add' : 'Add Offer'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _P.azure,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                textStyle: _T.label(13, c: Colors.white),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── Stat row ───────────────────────────────────────────────────────────────

  Widget _buildStatRow(int total, int active, int expired) {
    return Row(
      children: [
        _StatChip(label: 'Total',   value: '$total',   color: _P.azure,   bg: _P.azureLight),
        const SizedBox(width: 10),
        _StatChip(label: 'Active',  value: '$active',  color: _P.emerald, bg: _P.emeraldBg),
        const SizedBox(width: 10),
        _StatChip(label: 'Expired', value: '$expired', color: _P.rose,    bg: _P.roseBg),
      ],
    );
  }

  // ── Filter bar ─────────────────────────────────────────────────────────────

  Widget _buildFilterBar() {
    final filters = [
      ('all',      'All'),
      ('active',   'Active'),
      ('inactive', 'Inactive'),
      ('expired',  'Expired'),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: filters.map((f) {
          final selected = _filter == f.$1;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => setState(() => _filter = f.$1),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: selected ? _P.azure : _P.card,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: selected ? _P.azure : _P.border),
                  boxShadow: selected
                      ? [BoxShadow(
                          color: _P.azure.withOpacity(0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 2))]
                      : [],
                ),
                child: Text(
                  f.$2,
                  style: _T.label(13,
                      c: selected ? Colors.white : _P.textSecondary),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── Grid ───────────────────────────────────────────────────────────────────

  Widget _buildGrid(bool isMobile, List<Map<String, dynamic>> offers) {
    final crossCount = isMobile
        ? 1
        : Responsive.isTablet(context)
            ? 2
            : 3;

    return GridView.builder(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount:   crossCount,
        crossAxisSpacing: 16,
        mainAxisSpacing:  16,
        childAspectRatio: isMobile ? 1.8 : 1.55,
      ),
      itemCount: offers.length,
      itemBuilder: (_, i) => _AdminOfferCard(
        offer:    offers[i],
        onEdit:   () => _showOfferDialog(offer: offers[i]),
        onDelete: () => _confirmDelete(offers[i]),
        onToggle: (val) =>
            _adminService.toggleOfferActive(offers[i]['id'] as String, val),
      ),
    );
  }

  // ── Empty / error / shimmer ─────────────────────────────────────────────────

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration:
                const BoxDecoration(color: _P.azureLight, shape: BoxShape.circle),
            child: const Icon(Icons.local_offer_outlined,
                size: 48, color: _P.azure),
          ),
          const SizedBox(height: 20),
          Text('No offers found', style: _T.display(20)),
          const SizedBox(height: 8),
          Text('Adjust the filter or create a new offer.', style: _T.body(14)),
        ],
      ),
    );
  }

  Widget _buildErrorState(String msg) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline_rounded, color: _P.rose, size: 40),
          const SizedBox(height: 12),
          Text('Failed to load offers', style: _T.display(16, c: _P.rose)),
          const SizedBox(height: 6),
          Text(msg, style: _T.body(12), textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildShimmerLoading() {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _shimmerBox(200, 32),
          const SizedBox(height: 8),
          _shimmerBox(120, 16),
          const SizedBox(height: 24),
          Row(children: [
            _shimmerBox(80, 36),
            const SizedBox(width: 10),
            _shimmerBox(80, 36),
            const SizedBox(width: 10),
            _shimmerBox(80, 36),
          ]),
          const SizedBox(height: 24),
          Expanded(
            child: GridView.count(
              crossAxisCount: 3,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1.55,
              children: List.generate(
                  6, (_) => _shimmerBox(double.infinity, double.infinity)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _shimmerBox(double w, double h) => Container(
        width:  w == double.infinity ? null : w,
        height: h == double.infinity ? null : h,
        decoration: BoxDecoration(
            color: _P.border, borderRadius: BorderRadius.circular(10)),
      );

  // ── Dialog ─────────────────────────────────────────────────────────────────

  void _showOfferDialog({Map<String, dynamic>? offer}) {
    final isEdit = offer != null;

    // FIX: coerce every field to String to avoid null TypeError
    final titleCtrl  = TextEditingController(
        text: isEdit ? (offer['title']        as String? ?? '') : '');
    final descCtrl   = TextEditingController(
        text: isEdit ? (offer['description']  as String? ?? '') : '');
    final codeCtrl   = TextEditingController(
        text: isEdit ? (offer['discountCode'] as String? ?? '') : '');
    final tagCtrl    = TextEditingController(
        text: isEdit ? (offer['tag']           as String? ?? '') : '');
    final imageCtrl  = TextEditingController(
        text: isEdit ? (offer['image']         as String? ?? '') : '');
    final valueCtrl  = TextEditingController(
        text: isEdit ? (offer['discountValue']?.toString() ?? '') : '');

    String discountType = isEdit ? (offer['discountType'] as String? ?? 'percentage') : 'percentage';

    DateTime? selectedDate = isEdit
        ? offer['expiryDate'] as DateTime?
        : DateTime.now().add(const Duration(days: 30));
    bool isActive = isEdit ? (offer['isActive'] as bool? ?? true) : true;
    bool noExpiry = isEdit ? offer['expiryDate'] == null : false;

    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Dialog header ──────────────────────────────────────
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 20),
                  decoration: BoxDecoration(
                    color: isEdit ? _P.amberBg : _P.azureLight,
                    borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(20)),
                    border: const Border(
                        bottom: BorderSide(color: _P.border)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isEdit
                              ? _P.amber.withOpacity(0.15)
                              : _P.azure.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          isEdit
                              ? Icons.edit_rounded
                              : Icons.add_circle_outline_rounded,
                          color: isEdit ? _P.amber : _P.azure,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(isEdit ? 'Edit Offer' : 'Create New Offer',
                                style: _T.display(18)),
                            Text(
                              isEdit
                                  ? 'Update the offer details below'
                                  : 'Fill in the details for the new offer',
                              style: _T.body(12),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded,
                            color: _P.textTertiary),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                ),

                // ── Form body ──────────────────────────────────────────
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Image preview
                        if (imageCtrl.text.isNotEmpty) ...[
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(
                              imageCtrl.text,
                              height: 120,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                height: 120,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: _gradientFor(
                                        offer?['id'] as String? ??
                                            (titleCtrl.text.isNotEmpty
                                                ? titleCtrl.text
                                                : 'preview')),
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Center(
                                  child: Icon(Icons.broken_image_outlined,
                                      color: Colors.white38, size: 32),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                        ] else ...[
                          Container(
                            height: 80,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: _gradientFor(
                                    offer?['id'] as String? ??
                                        (titleCtrl.text.isNotEmpty
                                            ? titleCtrl.text
                                            : 'preview')),
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Center(
                              child: Text(
                                'No image · auto gradient will be used',
                                style: _T.body(11,
                                    c: Colors.white.withOpacity(0.6)),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        _label('Offer Title *'),
                        _field(titleCtrl, 'e.g. Summer Special 25% Off'),
                        const SizedBox(height: 14),

                        _label('Description *'),
                        _field(descCtrl,
                            'Details about what you are offering...',
                            maxLines: 3),
                        const SizedBox(height: 14),

                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _label('Promo Code'),
                                  _field(codeCtrl, 'DRY25'),
                                ],
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _label('Badge / Tag'),
                                  _field(tagCtrl, 'HOT!'),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _label('Discount Value'),
                                  _field(valueCtrl, '10'),
                                ],
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _label('Discount Type'),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12),
                                    decoration: BoxDecoration(
                                      border: Border.all(color: _P.border),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: DropdownButtonHideUnderline(
                                      child: DropdownButton<String>(
                                        value: discountType,
                                        isExpanded: true,
                                        items: const [
                                          DropdownMenuItem(value: 'percentage', child: Text('Percentage (%)')),
                                          DropdownMenuItem(value: 'fixed', child: Text('Fixed Amount (£)')),
                                        ],
                                        onChanged: (v) => setS(() => discountType = v!),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        _label('Image URL (optional)'),
                        _field(imageCtrl, 'https://example.com/image.jpg',
                            onChanged: (_) => setS(() {})),
                        const SizedBox(height: 14),

                        // Expiry
                        _label('Expiry Date'),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Switch(
                              value: noExpiry,
                              onChanged: (v) => setS(() => noExpiry = v),
                              activeColor: _P.azure,
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                            ),
                            Text('No expiry date', style: _T.body(13)),
                          ],
                        ),
                        if (!noExpiry) ...[
                          const SizedBox(height: 8),
                          InkWell(
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: ctx,
                                initialDate: selectedDate ?? DateTime.now(),
                                firstDate: DateTime.now()
                                    .subtract(const Duration(days: 1)),
                                lastDate: DateTime.now()
                                    .add(const Duration(days: 730)),
                              );
                              if (picked != null) {
                                setS(() => selectedDate = picked);
                              }
                            },
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.all(13),
                              decoration: BoxDecoration(
                                border: Border.all(color: _P.border),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.calendar_today_rounded,
                                      size: 16, color: _P.azure),
                                  const SizedBox(width: 10),
                                  Text(
                                    selectedDate != null
                                        ? DateFormat('MMM dd, yyyy')
                                            .format(selectedDate!)
                                        : 'Select a date',
                                    style: _T.body(14, c: _P.textPrimary),
                                  ),
                                  const Spacer(),
                                  const Icon(Icons.chevron_right_rounded,
                                      size: 18, color: _P.textTertiary),
                                ],
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),

                        // Active toggle
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: isActive ? _P.emeraldBg : _P.roseBg,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: isActive
                                    ? _P.emerald.withOpacity(0.3)
                                    : _P.rose.withOpacity(0.3)),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                isActive
                                    ? Icons.visibility_rounded
                                    : Icons.visibility_off_rounded,
                                color: isActive ? _P.emerald : _P.rose,
                                size: 18,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  isActive
                                      ? 'Visible to users'
                                      : 'Hidden from users',
                                  style: _T.label(13,
                                      c: isActive ? _P.emerald : _P.rose),
                                ),
                              ),
                              Switch(
                                value: isActive,
                                onChanged: (v) => setS(() => isActive = v),
                                activeColor: _P.emerald,
                                materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // ── Actions ────────────────────────────────────────────
                Container(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
                  decoration: const BoxDecoration(
                    border: Border(top: BorderSide(color: _P.border)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(ctx),
                          style: OutlinedButton.styleFrom(
                            padding:
                                const EdgeInsets.symmetric(vertical: 14),
                            side: const BorderSide(color: _P.border),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                          child: Text('Cancel', style: _T.label(14)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            if (titleCtrl.text.trim().isEmpty ||
                                descCtrl.text.trim().isEmpty) {
                              ScaffoldMessenger.of(ctx)
                                  .showSnackBar(SnackBar(
                                content: const Text(
                                    'Title and description are required'),
                                backgroundColor: _P.rose,
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(10)),
                              ));
                              return;
                            }

                            final data = {
                              'title':        titleCtrl.text.trim(),
                              'description':  descCtrl.text.trim(),
                              'discountCode': codeCtrl.text.trim().toUpperCase(),
                              'discountValue': double.tryParse(valueCtrl.text.trim()) ?? 0.0,
                              'discountType': discountType,
                              'tag':   tagCtrl.text.trim(),
                              'image': imageCtrl.text.trim(),
                              'expiryDate':
                                  noExpiry ? null : selectedDate,
                              'isActive': isActive,
                            };

                            if (isEdit) {
                              await _adminService.updateOffer(
                                  offer!['id'] as String, data);
                              await _fcmSenderService.sendNotification(
                                title: 'Offer Updated!',
                                body: 'Check out the latest updates for ${data['title']}',
                                data: {'type': 'offer'},
                              );
                            } else {
                              await _adminService.addOffer(data);
                              await _fcmSenderService.sendNotification(
                                title: 'New Offer Available!',
                                body: '${data['title']} is now live. Grab it now!',
                                data: {'type': 'offer'},
                              );
                            }

                            if (ctx.mounted) Navigator.pop(ctx);
                          },
                          icon: Icon(
                              isEdit
                                  ? Icons.check_rounded
                                  : Icons.add_rounded,
                              size: 17),
                          label:
                              Text(isEdit ? 'Save Changes' : 'Create Offer'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _P.azure,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding:
                                const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                            textStyle: _T.label(14, c: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Delete confirm ─────────────────────────────────────────────────────────

  void _confirmDelete(Map<String, dynamic> offer) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: _P.roseBg, borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.delete_outline_rounded,
                  color: _P.rose, size: 20),
            ),
            const SizedBox(width: 12),
            Text('Delete Offer?', style: _T.display(18)),
          ],
        ),
        content: Text(
          'Are you sure you want to delete "${offer['title']}"?\nThis action cannot be undone.',
          style: _T.body(14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: _T.label(14)),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              await _adminService.deleteOffer(offer['id'] as String);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            icon: const Icon(Icons.delete_rounded, size: 16),
            label: const Text('Delete'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _P.rose,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );
  }

  void _showPromoEmailDialog(List<Map<String, dynamic>> offers) {
    final subjectCtrl = TextEditingController(text: '{firstName}, your first DryClean Plus order is 20% off');
    final headlineCtrl = TextEditingController(text: '{firstName}, your first DryClean Plus order is 20% off.');
    final codeCtrl = TextEditingController(text: 'WELCOME20');
    final bodyCtrl = TextEditingController(
        text: 'Pick a time that suits you, we collect from your home or office, and deliver back fresh to your door with free delivery. Add code {code} at checkout to get 20% off your first order.');
    final ctaCtrl = TextEditingController(text: 'GET 20% OFF MY FIRST ORDER');
    final testEmailCtrl = TextEditingController(text: 'drycleanplus2@gmail.com');
    String audience = 'test'; // 'test' | 'first_order' | 'all'
    String? selectedOfferId;
    bool sending = false;

    final activeOffers = offers.where((o) => o['isActive'] != false && (o['discountCode'] ?? '').toString().trim().isNotEmpty).toList();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          backgroundColor: _P.card,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: _P.azureLight, borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.mark_email_read_outlined, color: _P.azure, size: 20),
              ),
              const SizedBox(width: 12),
              Text('Send Promo Email', style: _T.display(18)),
            ],
          ),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (activeOffers.isNotEmpty) ...[
                    _label('AUTO-FILL FROM AN OFFER (OPTIONAL)'),
                    DropdownButtonFormField<String>(
                      value: selectedOfferId,
                      hint: const Text('Pick Black Friday / custom offer…'),
                      decoration: _inputDeco(),
                      items: activeOffers.map((o) {
                        final code = (o['discountCode'] ?? '').toString();
                        final val = (o['discountValue'] ?? '').toString();
                        final isPct = o['discountType'] == 'percentage';
                        final disc = isPct ? '$val% off' : '£$val off';
                        return DropdownMenuItem(
                          value: o['id'] as String,
                          child: Text('$code ($disc) — ${o['title'] ?? ''}'),
                        );
                      }).toList(),
                      onChanged: (id) {
                        if (id == null) return;
                        final o = activeOffers.firstWhere((e) => e['id'] == id);
                        final code = (o['discountCode'] ?? '').toString().trim().toUpperCase();
                        final val = (o['discountValue'] ?? 20).toString().replaceAll(RegExp(r'\.0$'), '');
                        final isPct = o['discountType'] == 'percentage';
                        final disc = isPct ? '$val% off' : '£$val off';
                        final title = (o['title'] ?? 'Special Offer').toString().trim();
                        setS(() {
                          selectedOfferId = id;
                          codeCtrl.text = code;
                          subjectCtrl.text = '{firstName}, enjoy $disc on your DryClean Plus order 🧺';
                          headlineCtrl.text = '{firstName}, $title — $disc!';
                          bodyCtrl.text = 'Pick a time that suits you, we collect from your home or office, and deliver back fresh to your door with free delivery. Add code {code} at checkout to get $disc your order.';
                          ctaCtrl.text = 'CLAIM $disc WITH $code';
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                  ],
                  _label('AUDIENCE'),
                  DropdownButtonFormField<String>(
                    value: audience,
                    decoration: _inputDeco(),
                    items: const [
                      DropdownMenuItem(value: 'test', child: Text('Test Email (Send to 1 address first)')),
                      DropdownMenuItem(value: 'first_order', child: Text('New Customers (0 orders placed)')),
                      DropdownMenuItem(value: 'all', child: Text('All Registered Customers')),
                    ],
                    onChanged: (v) { if (v != null) setS(() => audience = v); },
                  ),
                  if (audience == 'test') ...[
                    const SizedBox(height: 12),
                    _label('TEST EMAIL ADDRESS'),
                    TextField(controller: testEmailCtrl, decoration: _inputDeco(hint: 'drycleanplus2@gmail.com')),
                  ],
                  const SizedBox(height: 12),
                  _label('EMAIL SUBJECT  ({firstName} auto-personalizes)'),
                  TextField(controller: subjectCtrl, decoration: _inputDeco()),
                  const SizedBox(height: 12),
                  _label('BIG HEADLINE'),
                  TextField(controller: headlineCtrl, decoration: _inputDeco()),
                  const SizedBox(height: 12),
                  _label('PROMO CODE'),
                  TextField(controller: codeCtrl, decoration: _inputDeco(hint: 'WELCOME20')),
                  const SizedBox(height: 12),
                  _label('OFFER MESSAGE'),
                  TextField(controller: bodyCtrl, maxLines: 3, decoration: _inputDeco()),
                  const SizedBox(height: 12),
                  _label('BUTTON TEXT'),
                  TextField(controller: ctaCtrl, decoration: _inputDeco()),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: sending ? null : () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton.icon(
              onPressed: sending
                  ? null
                  : () async {
                      setS(() => sending = true);
                      final res = await ResendEmailService.instance.sendPromoEmail(
                        audience: audience,
                        testEmail: testEmailCtrl.text,
                        subject: subjectCtrl.text,
                        headline: headlineCtrl.text,
                        body2: bodyCtrl.text,
                        promoCode: codeCtrl.text,
                        ctaText: ctaCtrl.text,
                      );
                      if (!ctx.mounted) return;
                      Navigator.pop(ctx);
                      final ok = res['success'] == true;
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        backgroundColor: ok ? _P.emerald : _P.rose,
                        content: Text(ok
                            ? 'Sent ${res['sent'] ?? 1} promo email(s)${res['failed'] != null && res['failed'] > 0 ? ' (${res['failed']} failed)' : ''}'
                            : 'Failed: ${res['error'] ?? 'Unknown error'}'),
                      ));
                    },
              icon: sending
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.send_rounded, size: 17),
              label: Text(sending ? 'Sending…' : (audience == 'test' ? 'Send Test Email' : 'Send Broadcast')),
              style: ElevatedButton.styleFrom(backgroundColor: _P.azure, foregroundColor: Colors.white),
            ),
          ],
        ),
      ),
    );
  }

  // ── Form helpers ───────────────────────────────────────────────────────────

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text, style: _T.label(12, c: _P.textSecondary)),
      );

  InputDecoration _inputDeco({String? hint}) => InputDecoration(
        hintText: hint,
        hintStyle: _T.body(14, c: _P.textTertiary),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: _P.border)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: _P.border)),
      );

  Widget _field(
    TextEditingController ctrl,
    String hint, {
    int maxLines = 1,
    void Function(String)? onChanged,
  }) =>
      TextField(
        controller: ctrl,
        maxLines: maxLines,
        onChanged: onChanged,
        style: _T.body(14, c: _P.textPrimary),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: _T.body(14, c: _P.textTertiary),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _P.border)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _P.border)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _P.azure, width: 1.5)),
          filled: true,
          fillColor: _P.card,
        ),
      );
}

// ─── Admin Offer Card ─────────────────────────────────────────────────────────

class _AdminOfferCard extends StatelessWidget {
  final Map<String, dynamic> offer;
  final VoidCallback          onEdit;
  final VoidCallback          onDelete;
  final Function(bool)        onToggle;

  const _AdminOfferCard({
    required this.offer,
    required this.onEdit,
    required this.onDelete,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final expiryDate = offer['expiryDate'] as DateTime?;
    final bool isExpired =
        expiryDate != null && expiryDate.isBefore(DateTime.now());
    final bool isActive  = offer['isActive'] as bool? ?? true;
    final String image   = offer['image']        as String? ?? '';
    final String code    = offer['discountCode'] as String? ?? '';
    final String tag     = offer['tag']          as String? ?? '';
    // FIX: guarantee a non-null String for _gradientFor
    final String id      = offer['id']           as String? ??
                           offer['title']         as String? ??
                           'x';

    int? daysLeft;
    if (expiryDate != null && !isExpired) {
      daysLeft = expiryDate.difference(DateTime.now()).inDays;
    }

    return Container(
      decoration: BoxDecoration(
        color: _P.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: isActive && !isExpired ? _P.border : _P.roseBg,
            width: 1.2),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 12,
              offset: const Offset(0, 3)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Image / gradient strip ────────────────────────────────
          SizedBox(
            height: 72,
            width: double.infinity,
            child: Stack(
              fit: StackFit.expand,
              children: [
                image.isNotEmpty
                    ? Image.network(image,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _gradientStrip(id))
                    : _gradientStrip(id),
                if (!isActive || isExpired)
                  Container(color: Colors.black.withOpacity(0.45)),
                Positioned(
                  top: 8,
                  left: 10,
                  child: _statusBadge(isActive, isExpired),
                ),
                if (tag.isNotEmpty)
                  Positioned(
                    top: 8,
                    right: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: _P.amber,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        tag.toUpperCase(),
                        style: GoogleFonts.plusJakartaSans(
                            fontSize: 8,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: 0.5),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // ── Content ───────────────────────────────────────────────
          // FIX: replaced inner Expanded (caused overflow) with
          //      Flexible so the column shrinks/clips gracefully.
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    offer['title'] as String? ?? '',
                    style: _T.display(13, w: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  // FIX: Flexible instead of Expanded — lets the text
                  //      shrink when the card is vertically tight.
                  Flexible(
                    child: Text(
                      offer['description'] as String? ?? '',
                      style: _T.body(11),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(height: 4),

                  // Code + expiry row
                  Row(
                    children: [
                      if (code.isNotEmpty) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color: _P.azureLight,
                            borderRadius: BorderRadius.circular(5),
                            border: Border.all(color: _P.azureMid),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.confirmation_num_outlined,
                                  size: 10, color: _P.azure),
                              const SizedBox(width: 4),
                              Text(code,
                                  style: _T.label(10, c: _P.azure)),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                      ],
                      const Spacer(),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.access_time_rounded,
                            size: 11,
                            color: isExpired
                                ? _P.rose
                                : daysLeft != null && daysLeft <= 7
                                    ? _P.amber
                                    : _P.textTertiary,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            expiryDate != null
                                ? (isExpired
                                    ? 'Expired'
                                    : daysLeft == 0
                                        ? 'Today'
                                        : '$daysLeft days left')
                                : 'No expiry',
                            style: _T.body(10,
                                c: isExpired
                                    ? _P.rose
                                    : daysLeft != null && daysLeft <= 7
                                        ? _P.amber
                                        : _P.textTertiary),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // ── Action bar ────────────────────────────────────────────
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: _P.borderSoft)),
            ),
            child: Row(
              children: [
                Transform.scale(
                  scale: 0.8,
                  alignment: Alignment.centerLeft,
                  child: Switch(
                    value: isActive,
                    onChanged: onToggle,
                    activeColor: _P.emerald,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
                Text(
                  isActive ? 'Live' : 'Off',
                  style: _T.label(11,
                      c: isActive ? _P.emerald : _P.textTertiary),
                ),
                const Spacer(),
                _ActionBtn(
                  icon:  Icons.edit_outlined,
                  color: _P.azure,
                  bg:    _P.azureLight,
                  onTap: onEdit,
                ),
                const SizedBox(width: 6),
                _ActionBtn(
                  icon:  Icons.delete_outline_rounded,
                  color: _P.rose,
                  bg:    _P.roseBg,
                  onTap: onDelete,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _gradientStrip(String id) => Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: _gradientFor(id)),
        ),
        child: const Center(
          child: Icon(Icons.local_offer_rounded,
              color: Colors.white24, size: 28),
        ),
      );

  Widget _statusBadge(bool isActive, bool isExpired) {
    final Color color = isExpired
        ? _P.rose
        : isActive
            ? _P.emerald
            : _P.textSecondary;
    final String label = isExpired
        ? 'Expired'
        : isActive
            ? 'Active'
            : 'Inactive';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.55),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration:
                BoxDecoration(shape: BoxShape.circle, color: color),
          ),
          const SizedBox(width: 4),
          Text(label,
              style: GoogleFonts.plusJakartaSans(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: 0.3)),
        ],
      ),
    );
  }
}

// ─── Small helpers ────────────────────────────────────────────────────────────

class _ActionBtn extends StatelessWidget {
  final IconData     icon;
  final Color        color;
  final Color        bg;
  final VoidCallback onTap;

  const _ActionBtn({
    required this.icon,
    required this.color,
    required this.bg,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
              color: bg, borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, size: 15, color: color),
        ),
      );
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final Color  color;
  final Color  bg;

  const _StatChip({
    required this.label,
    required this.value,
    required this.color,
    required this.bg,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(value,
                style: _T.display(18, w: FontWeight.w800, c: color)),
            const SizedBox(width: 6),
            Text(label, style: _T.body(12, c: color)),
          ],
        ),
      );
}