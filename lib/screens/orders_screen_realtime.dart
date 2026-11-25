import 'dart:ui' show FontFeature;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../providers/firebase_admin_service.dart';
import '../providers/firebase_auth_provider.dart';
import '../services/fcm_sender_service.dart';
import '../services/resend_email_service.dart';
import '../widgets/responsive.dart';
import '../utils/printer_helper.dart';

// ─── Design Tokens ────────────────────────────────────────────────────────────

/// Max width of the page content on wide (desktop / web) screens.
const double _kMaxContentWidth = 1120;

class _P {
  // Surfaces
  static const Color canvas     = Color(0xFFF4F6F8);
  static const Color card       = Color(0xFFFFFFFF);
  static const Color surfaceAlt = Color(0xFFF9FAFB);
  static const Color sideBar    = Color(0xFF0B1B2B);

  // Brand
  static const Color navy      = Color(0xFF0B1B2B);
  static const Color navyMid   = Color(0xFF12303A);
  static const Color azure     = Color(0xFF0B7A62);
  static const Color azureDark = Color(0xFF075E4B);
  static const Color azureSoft = Color(0xFFE9F6F1);
  static const Color azureMid  = Color(0xFFB4E1D4);
  static const Color info      = Color(0xFF175CD3);
  static const Color infoBg    = Color(0xFFEFF6FF);

  // Semantic
  static const Color emerald   = Color(0xFF067647);
  static const Color emeraldBg = Color(0xFFECFDF3);
  static const Color amber     = Color(0xFFB54708);
  static const Color amberBg   = Color(0xFFFFFAEB);
  static const Color violet    = Color(0xFF6941C6);
  static const Color violetBg  = Color(0xFFF4F0FF);
  static const Color teal      = Color(0xFF0B7F74);
  static const Color tealBg    = Color(0xFFEDFCF9);
  static const Color rose      = Color(0xFFC01048);
  static const Color roseBg    = Color(0xFFFFF1F3);
  static const Color slate     = Color(0xFF667085);

  // Text
  static const Color textPrimary   = Color(0xFF101828);
  static const Color textSecondary = Color(0xFF475467);
  static const Color textMuted     = Color(0xFF7C8799);
  static const Color border        = Color(0xFFE4E7EC);
  static const Color borderSoft    = Color(0xFFF0F2F5);

  // Elevation
  static List<BoxShadow> get shadowSm => [
        BoxShadow(color: const Color(0xFF101828).withOpacity(0.05), blurRadius: 2, offset: const Offset(0, 1)),
        BoxShadow(color: const Color(0xFF101828).withOpacity(0.045), blurRadius: 18, offset: const Offset(0, 8)),
      ];
}

class _T {
  /// Titles & numbers – Plus Jakarta Sans.
  static TextStyle heading(double sz, {FontWeight w = FontWeight.w700, Color c = _P.textPrimary}) =>
      GoogleFonts.plusJakartaSans(fontSize: sz, fontWeight: w, color: c, letterSpacing: -0.3, height: 1.25);

  /// Reading text – Inter.
  static TextStyle body(double sz, {FontWeight w = FontWeight.w400, Color c = _P.textSecondary}) =>
      GoogleFonts.inter(fontSize: sz, fontWeight: w, color: c, height: 1.4);

  /// Small UI text (chips, buttons, captions) – Inter.
  static TextStyle label(double sz, {FontWeight w = FontWeight.w600, Color c = _P.textSecondary}) =>
      GoogleFonts.inter(fontSize: sz, fontWeight: w, color: c, letterSpacing: 0.05);

  /// Prices – tabular figures so amounts line up.
  static TextStyle money(double sz, {FontWeight w = FontWeight.w700, Color c = _P.textPrimary}) =>
      GoogleFonts.plusJakartaSans(
        fontSize: sz,
        fontWeight: w,
        color: c,
        letterSpacing: -0.4,
        fontFeatures: const [FontFeature.tabularFigures()],
      );
}

// ─── Shared UI helpers ────────────────────────────────────────────────────────

BoxDecoration _cardDeco({Color color = _P.card, double radius = 16, bool shadow = true}) => BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: _P.border),
      boxShadow: shadow ? _P.shadowSm : null,
    );

InputDecoration _inputDeco({
  String? label,
  String? hint,
  String? prefix,
  EdgeInsetsGeometry? padding,
}) {
  OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: c, width: w),
      );
  return InputDecoration(
    labelText: label,
    labelStyle: _T.body(12.5, c: _P.textMuted),
    floatingLabelStyle: _T.label(12, c: _P.azure),
    hintText: hint,
    hintStyle: _T.body(12.5, c: _P.textMuted),
    prefixText: prefix,
    prefixStyle: _T.label(13, c: _P.textSecondary),
    isDense: true,
    filled: true,
    fillColor: Colors.white,
    contentPadding: padding ?? const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
    border: border(_P.border),
    enabledBorder: border(_P.border),
    focusedBorder: border(_P.azure, 1.6),
  );
}

ButtonStyle _primaryBtn({
  EdgeInsetsGeometry? padding,
  Size? minimumSize,
  double radius = 10,
  Color? bg,
  double fontSize = 13,
}) =>
    ElevatedButton.styleFrom(
      backgroundColor: bg ?? _P.azure,
      foregroundColor: Colors.white,
      disabledBackgroundColor: (bg ?? _P.azure).withOpacity(0.5),
      disabledForegroundColor: Colors.white70,
      elevation: 0,
      padding: padding ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      minimumSize: minimumSize,
      textStyle: _T.label(fontSize, w: FontWeight.w700, c: Colors.white),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius)),
    );

ButtonStyle _softBtn({EdgeInsetsGeometry? padding, double radius = 9, double fontSize = 12}) =>
    ElevatedButton.styleFrom(
      backgroundColor: _P.azureSoft,
      foregroundColor: _P.azure,
      elevation: 0,
      padding: padding ?? const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      minimumSize: Size.zero,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      textStyle: _T.label(fontSize, w: FontWeight.w700, c: _P.azure),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius),
        side: BorderSide(color: _P.azure.withOpacity(0.18)),
      ),
    );

String _initialsOf(Map<String, dynamic> bookingData) {
  final f = (bookingData['firstName'] ?? '').toString().trim();
  final l = (bookingData['lastName'] ?? '').toString().trim();
  final s = '${f.isNotEmpty ? f[0] : ''}${l.isNotEmpty ? l[0] : ''}'.toUpperCase();
  return s.isEmpty ? '?' : s;
}

/// Round avatar with initials.
class _Avatar extends StatelessWidget {
  final String initials;
  final double size;
  final bool onDark;
  const _Avatar({required this.initials, this.size = 38, this.onDark = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: onDark
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.white.withOpacity(0.22), Colors.white.withOpacity(0.08)],
              )
            : const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFD7F0E7), Color(0xFFB4E1D4)],
              ),
        border: Border.all(color: onDark ? Colors.white.withOpacity(0.25) : _P.azure.withOpacity(0.18)),
      ),
      child: Text(
        initials,
        style: _T.heading(size * 0.36, w: FontWeight.w800, c: onDark ? Colors.white : _P.azureDark),
      ),
    );
  }
}

/// Small rounded tag with optional icon.
class _Pill extends StatelessWidget {
  final String label;
  final IconData? icon;
  final Color color;
  final Color bg;
  final Color? borderColor;
  const _Pill({required this.label, required this.color, required this.bg, this.icon, this.borderColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor ?? color.withOpacity(0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 5),
          ],
          Flexible(
            child: Text(label, style: _T.label(11.5, w: FontWeight.w600, c: color), overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }
}

/// Section label with an accent bar.
class _SectionTitle extends StatelessWidget {
  final String text;
  final Widget? trailing;
  const _SectionTitle(this.text, {this.trailing});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 12,
          decoration: BoxDecoration(color: _P.azure, borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: _T.label(11, w: FontWeight.w800, c: _P.textSecondary).copyWith(letterSpacing: 0.9),
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

/// Shared dark header used by the dialogs.
class _DialogHeader extends StatelessWidget {
  final Widget leading;
  final String title;
  final String subtitle;
  final VoidCallback? onClose;
  final bool compact;
  const _DialogHeader({
    required this.leading,
    required this.title,
    required this.subtitle,
    required this.onClose,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(compact ? 16 : 22, compact ? 16 : 20, compact ? 6 : 12, compact ? 16 : 20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_P.navy, _P.navyMid],
        ),
      ),
      child: Row(
        children: [
          leading,
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: _T.heading(compact ? 16 : 18, w: FontWeight.w800, c: Colors.white),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: _T.body(12, c: const Color(0xFF9FB3C0)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onClose,
            tooltip: 'Close',
            icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 20),
            splashRadius: 20,
          ),
        ],
      ),
    );
  }
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
    'pending',
    'confirmed',
    'pickup_assigned',
    'pickup_en_route',
    'collected',
    'awaiting_approval',
    'cleaning',
    'ready_for_delivery',
    'delivery_assigned',
    'out_for_delivery',
    'delivered',
    'cancelled',
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
    if (s == 'all') return 'Live Orders';
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
    final isMobile = Responsive.isMobile(context);
    final hPad = isMobile ? 16.0 : 28.0;

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: _P.card,
        border: Border(bottom: BorderSide(color: _P.border)),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _kMaxContentWidth),
          child: Padding(
            padding: EdgeInsets.fromLTRB(hPad, isMobile ? 16 : 22, hPad, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: isMobile ? 42 : 48,
                      height: isMobile ? 42 : 48,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [_P.azure, _P.azureDark],
                        ),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: _P.azure.withOpacity(0.28),
                            blurRadius: 14,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Icon(Icons.receipt_long_rounded, color: Colors.white, size: isMobile ? 21 : 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Orders', style: _T.heading(isMobile ? 21 : 26, w: FontWeight.w800)),
                          const SizedBox(height: 2),
                          Text(
                            'Track, itemize and update every order in real time',
                            style: _T.body(12.5, c: _P.textMuted),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    _LiveBadge(),
                  ],
                ),
                SizedBox(height: isMobile ? 16 : 20),
                _buildFilterTabs(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterTabs() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: _statusOptions.map((status) {
          final isSelected = _selectedStatus == status;
          final cfg = status == 'all' ? null : _Status.of(status);
          final accent = cfg?.color ?? _P.azure;
          final accentBg = cfg?.bg ?? _P.azureSoft;

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                decoration: BoxDecoration(
                  color: isSelected ? accentBg : _P.card,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: isSelected ? accent.withOpacity(0.5) : _P.border),
                ),
                child: Material(
                  type: MaterialType.transparency,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(999),
                    onTap: () => setState(() => _selectedStatus = status),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (status == 'all')
                            Icon(Icons.bolt_rounded, size: 15, color: isSelected ? accent : _P.textMuted)
                          else
                            Container(
                              width: 7,
                              height: 7,
                              decoration: BoxDecoration(
                                color: isSelected ? accent : accent.withOpacity(0.45),
                                shape: BoxShape.circle,
                              ),
                            ),
                          const SizedBox(width: 7),
                          Text(
                            _filterLabel(status),
                            style: _T.label(
                              12.5,
                              w: isSelected ? FontWeight.w700 : FontWeight.w600,
                              c: isSelected ? accent : _P.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── States ────────────────────────────────────────────────────────────────────

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 30,
            height: 30,
            child: CircularProgressIndicator(color: _P.azure, strokeWidth: 2.5),
          ),
          const SizedBox(height: 14),
          Text('Loading orders...', style: _T.body(13, c: _P.textMuted)),
        ],
      ),
    );
  }

  Widget _buildErrorState(Object? error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 420),
          padding: const EdgeInsets.all(24),
          decoration: _cardDeco(radius: 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(color: _P.roseBg, borderRadius: BorderRadius.circular(16)),
                child: const Icon(Icons.error_outline_rounded, color: _P.rose, size: 28),
              ),
              const SizedBox(height: 16),
              Text('Failed to load orders', style: _T.heading(17)),
              const SizedBox(height: 6),
              Text('$error', style: _T.body(13), textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 104,
              height: 104,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _P.azureSoft.withOpacity(0.55),
              ),
              child: Container(
                width: 74,
                height: 74,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _P.azureSoft,
                  border: Border.all(color: _P.azureMid),
                ),
                child: const Icon(Icons.inbox_rounded, color: _P.azure, size: 34),
              ),
            ),
            const SizedBox(height: 20),
            Text('No orders here', style: _T.heading(19)),
            const SizedBox(height: 6),
            Text(
              _selectedStatus == 'all'
                  ? 'Orders will appear once customers place them'
                  : 'No orders with this status yet',
              style: _T.body(13.5, c: _P.textMuted),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListSummary(int count) {
    return Row(
      children: [
        Text(_filterLabel(_selectedStatus), style: _T.heading(16)),
        const SizedBox(width: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
          decoration: BoxDecoration(
            color: _P.card,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: _P.border),
          ),
          child: Text(
            count == 1 ? '1 order' : '$count orders',
            style: _T.label(11.5, c: _P.textSecondary),
          ),
        ),
      ],
    );
  }

  // ── Orders List ───────────────────────────────────────────────────────────────

  Widget _buildOrdersList() {
    final isMobile = Responsive.isMobile(context);
    final hPad = isMobile ? 14.0 : 28.0;

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: context.read<FirebaseAdminService>().getOrdersStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingState();
        }

        if (snapshot.hasError) {
          return _buildErrorState(snapshot.error);
        }

        final orders = snapshot.data ?? [];
        final filtered = _selectedStatus == 'all'
            ? orders.where((o) {
                final st = (o['status'] ?? '').toString().toLowerCase();
                return st != 'cancelled' && st != 'canceled';
              }).toList()
            : orders.where((o) => (_Status.groups[_selectedStatus] ?? {_selectedStatus}).contains(o['status'])).toList();

        if (filtered.isEmpty) {
          return _buildEmptyState();
        }

        return Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _kMaxContentWidth),
            child: Column(
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(hPad, 18, hPad, 2),
                  child: _buildListSummary(filtered.length),
                ),
                Expanded(
                  child: ListView.builder(
                    padding: EdgeInsets.fromLTRB(hPad, 14, hPad, 32),
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

                // Automated Free Resend Email notifications on status change
                if (newStatus == 'delivered') {
                  ResendEmailService.instance.sendDeliveredInvoiceEmail(filtered[i]);
                } else if (newStatus == 'awaiting_approval') {
                  ResendEmailService.instance.sendBillApprovalEmail(filtered[i]);
                }

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
                  ),
                ),
              ],
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
      padding: const EdgeInsets.fromLTRB(10, 6, 13, 6),
      decoration: BoxDecoration(
        color: _P.emeraldBg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _P.emerald.withOpacity(0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: AnimatedBuilder(
              animation: _pulse,
              builder: (_, __) {
                final ring = 8 + 8 * ((_pulse.value - 0.5) * 2);
                return Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: ring,
                      height: ring,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _P.emerald.withOpacity(0.28 * (1.5 - _pulse.value)),
                      ),
                    ),
                    Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(color: _P.emerald, shape: BoxShape.circle),
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(width: 6),
          Text(
            'LIVE',
            style: _T.label(10.5, w: FontWeight.w800, c: _P.emerald).copyWith(letterSpacing: 0.9),
          ),
        ],
      ),
    );
  }
}
// ─── Price Helper ─────────────────────────────────────────────────────────────

double _parsePrice(dynamic v) {
  if (v is num) return v.toDouble();
  if (v == null) return 0.0;
  final cleaned = v.toString().replaceAll('£', '').replaceAll(',', '').trim();
  return double.tryParse(cleaned) ?? 0.0;
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

    final status    = _Status.of(widget.order['status'] ?? '');
    final isPrepaid = widget.order['type'] == 'prepaid_pack';
    final rawSrc    = (widget.order['source'] ?? '').toString().toLowerCase();
    final isWebOrder = rawSrc.contains('web') || (widget.order['type'] == 'website');
    final pad = isMobile ? 16.0 : 22.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: _P.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _P.border),
        boxShadow: _P.shadowSm,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(17),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(pad + 4, pad, pad, pad - 2),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Top row: status icon + ID + badges + total ──
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: isMobile ? 40 : 46,
                            height: isMobile ? 40 : 46,
                            decoration: BoxDecoration(
                              color: status.bg,
                              borderRadius: BorderRadius.circular(13),
                              border: Border.all(color: status.color.withOpacity(0.2)),
                            ),
                            child: Icon(status.icon, size: isMobile ? 20 : 22, color: status.color),
                          ),
                          SizedBox(width: isMobile ? 12 : 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Wrap(
                                  spacing: 10,
                                  runSpacing: 6,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    Text('#${widget.order['orderId']}', style: _T.heading(isMobile ? 15.5 : 17, w: FontWeight.w800)),
                                    _StatusBadge(status: status),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: [
                                    if (isPrepaid)
                                      const _Chip(label: 'PREPAID', color: _P.violet, bg: _P.violetBg, icon: Icons.card_membership_rounded),
                                    isWebOrder
                                        ? const _Chip(label: 'WEB ORDER', color: _P.teal, bg: _P.tealBg, icon: Icons.language_rounded)
                                        : const _Chip(label: 'APP ORDER', color: Color(0xFF4F46E5), bg: Color(0xFFEEF2FF), icon: Icons.smartphone_rounded),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text('£${_getTotalAmount()}', style: _T.money(isMobile ? 20 : 25, w: FontWeight.w800)),
                              const SizedBox(height: 2),
                              Text(
                                'ORDER TOTAL',
                                style: _T.label(9.5, w: FontWeight.w700, c: _P.textMuted).copyWith(letterSpacing: 0.9),
                              ),
                            ],
                          ),
                        ],
                      ),

                      const SizedBox(height: 14),

                      // ── Service / item tags ──
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          if (services.isNotEmpty)
                            ...services.map((s) => _Pill(
                                  label: s,
                                  icon: Icons.checkroom_rounded,
                                  color: _P.azure,
                                  bg: _P.azureSoft,
                                )),
                          if (items.isEmpty)
                            const _Pill(
                              label: 'Count at facility',
                              icon: Icons.inventory_2_outlined,
                              color: _P.emerald,
                              bg: _P.emeraldBg,
                            ),
                          if (items.isNotEmpty)
                            _Pill(
                              label: '${items.length} item${items.length == 1 ? '' : 's'}',
                              icon: Icons.layers_outlined,
                              color: _P.textSecondary,
                              bg: _P.surfaceAlt,
                              borderColor: _P.border,
                            ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // ── Customer / Collection / Delivery / Address ──
                      _buildInfoStrip(bookingData, isMobile),
                    ],
                  ),
                ),

                // ── Action bar ──
                Container(
                  decoration: const BoxDecoration(
                    border: Border(top: BorderSide(color: _P.borderSoft)),
                  ),
                  padding: EdgeInsets.fromLTRB(isMobile ? 8 : 16, 8, isMobile ? 12 : 16, 8),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _TextAction(
                        label: _isExpanded ? 'Show Less' : 'Details & Actions',
                        icon: _isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                        onTap: _toggleExpand,
                      ),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _OutlineAction(
                            label: 'Invoice',
                            icon: Icons.receipt_long_rounded,
                            onTap: _printOrderDetails,
                          ),
                          _OutlineAction(
                            label: 'Send Email',
                            icon: Icons.send_rounded,
                            onTap: () async {
                              final email = (bookingData['email'] ?? widget.order['email'] ?? '').toString();
                              if (email.isEmpty || !email.contains('@')) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('No valid customer email on this order.'),
                                    backgroundColor: Color(0xFFDC2626),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                                return;
                              }
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Sending invoice & PDF to $email...'),
                                  backgroundColor: const Color(0xFF1E5FD8),
                                  behavior: SnackBarBehavior.floating,
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                              final statusStr = (widget.order['status'] ?? '').toString().toLowerCase();
                              final res = statusStr == 'awaiting_approval'
                                  ? await ResendEmailService.instance.sendBillApprovalEmail(widget.order)
                                  : await ResendEmailService.instance.sendDeliveredInvoiceEmail(widget.order);
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(res['success'] == true
                                      ? '✓ Invoice & PDF emailed to $email'
                                      : 'Could not send email: ${res['error'] ?? 'Check connection'}'),
                                  backgroundColor: res['success'] == true ? const Color(0xFF059669) : const Color(0xFFDC2626),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            },
                          ),
                          ElevatedButton.icon(
                            onPressed: () => _openItemizeModal(context, widget.order, bookingData),
                            icon: const Icon(Icons.edit_note_rounded, size: 17),
                            label: Text(items.isEmpty ? 'Itemize Bag' : 'Edit Bill (${items.length})'),
                            style: _primaryBtn(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              minimumSize: Size.zero,
                              fontSize: 12.5,
                            ),
                          ),
                        ],
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

            // ── Status accent bar ──
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              child: Container(width: 4, color: status.color),
            ),
          ],
        ),
      ),
    );
  }

  // ── Info strip (customer + dates + address) ───────────────────────────────

  Widget _buildInfoStrip(Map<String, dynamic> bookingData, bool isMobile) {
    final collection = _buildDateTile('Collection', bookingData['collectionDate'], bookingData['collectionTime'], Icons.upload_rounded, _P.azure, _P.azureSoft);
    final delivery   = _buildDateTile('Delivery', bookingData['deliveryDate'], bookingData['deliveryTime'], Icons.download_rounded, _P.emerald, _P.emeraldBg);
    const vDivider = VerticalDivider(width: 1, thickness: 1, color: _P.border);
    const hDivider = Divider(height: 1, thickness: 1, color: _P.border);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _P.border),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(13),
        child: Material(
          color: _P.surfaceAlt,
          child: Column(
            children: [
              if (isMobile) ...[
                _buildCustomerTile(bookingData),
                hDivider,
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(child: collection),
                      vDivider,
                      Expanded(child: delivery),
                    ],
                  ),
                ),
              ] else
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(flex: 5, child: _buildCustomerTile(bookingData)),
                      vDivider,
                      Expanded(flex: 3, child: collection),
                      vDivider,
                      Expanded(flex: 3, child: delivery),
                    ],
                  ),
                ),
              hDivider,
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                child: Row(
                  children: [
                    const Icon(Icons.location_on_outlined, size: 16, color: _P.azure),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _getAddressString(bookingData),
                        style: _T.body(12.5, c: _P.textSecondary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
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

  // ── Customer tile ─────────────────────────────────────────────────────────

  Widget _buildCustomerTile(Map<String, dynamic> bookingData) {
    final name = '${bookingData['firstName'] ?? 'Unknown'} ${bookingData['lastName'] ?? ''}'.trim();
    return InkWell(
      onTap: () => _showCustomerDetailsModal(context, bookingData),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            _Avatar(initials: _initialsOf(bookingData), size: 40),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    name,
                    style: _T.heading(14, w: FontWeight.w700),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      const Icon(Icons.phone_outlined, size: 12, color: _P.textMuted),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          '${bookingData['phone'] ?? 'No phone'}',
                          style: _T.body(12),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, size: 20, color: _P.textMuted),
          ],
        ),
      ),
    );
  }

  Widget _buildDateTile(String title, dynamic date, dynamic time, IconData icon, Color color, Color bg) {
    final hasTime = time != null && time.toString().trim().isNotEmpty;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
                child: Icon(icon, size: 12, color: color),
              ),
              const SizedBox(width: 7),
              Text(
                title.toUpperCase(),
                style: _T.label(10, w: FontWeight.w700, c: _P.textMuted).copyWith(letterSpacing: 0.8),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            date != null ? '$date' : 'N/A',
            style: _T.label(13, w: FontWeight.w700, c: _P.textPrimary),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (date != null && hasTime) ...[
            const SizedBox(height: 2),
            Text('$time', style: _T.body(11.5), maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
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
    final isMobile = Responsive.isMobile(context);

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: _P.surfaceAlt,
        border: Border(top: BorderSide(color: _P.border)),
      ),
      padding: EdgeInsets.fromLTRB(isMobile ? 14 : 22, 18, isMobile ? 14 : 22, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Items header
          const _SectionTitle('ORDER ITEMS & SERVICES'),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(left: 11),
                  child: Text(orderTypeLabel, style: _T.label(12, c: _P.azure)),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: () => _openItemizeModal(context, widget.order, bookingData),
                icon: const Icon(Icons.edit_note_rounded, size: 15),
                label: Text(items.isEmpty ? 'Count & Set Price' : 'Edit Items'),
                style: _softBtn(),
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (items.isNotEmpty) ...[
            Container(
              decoration: _cardDeco(radius: 12, shadow: false),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(11),
                child: Column(
                  children: [
                    for (int i = 0; i < items.length; i++) ...[
                      if (i > 0) const Divider(height: 1, color: _P.borderSoft),
                      _ItemRow(item: items[i]),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: () => _openItemizeModal(context, widget.order, bookingData),
                icon: const Icon(Icons.edit_note_rounded, size: 16, color: _P.azure),
                label: const Text('Add / Modify Items & Price'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _P.azure,
                  backgroundColor: _P.card,
                  side: BorderSide(color: _P.azure.withOpacity(0.45)),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  textStyle: _T.label(12, w: FontWeight.w700, c: _P.azure),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ] else ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _P.azureSoft.withOpacity(0.6),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _P.azure.withOpacity(0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: _P.card,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: _P.azureMid),
                        ),
                        child: const Icon(Icons.inventory_2_outlined, size: 18, color: _P.azure),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              services.isNotEmpty ? 'Selected Services: ${services.join(', ')}' : 'Standard Service Order',
                              style: _T.heading(13.5, c: _P.azureDark),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Items will be counted, inspected & priced at the facility upon collection.',
                              style: _T.body(12.5, c: _P.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  ElevatedButton.icon(
                    onPressed: () => _openItemizeModal(context, widget.order, bookingData),
                    icon: const Icon(Icons.add_shopping_cart_rounded, size: 16),
                    label: const Text('Count / Itemize Bag & Set Price'),
                    style: _primaryBtn(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                      fontSize: 12.5,
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Special instructions or customer note
          if ((bookingData['specialInstructions'] != null && bookingData['specialInstructions'].toString().trim().isNotEmpty) ||
              (bookingData['instructions'] != null && bookingData['instructions'].toString().trim().isNotEmpty)) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _P.amberBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _P.amber.withOpacity(0.25)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.note_outlined, size: 17, color: _P.amber),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Customer Note: ${(bookingData['specialInstructions'] ?? bookingData['instructions'] ?? '').toString().trim()}',
                      style: _T.body(12.5, c: _P.textPrimary),
                    ),
                  ),
                ],
              ),
            ),
          ],

          if (bookingData['address'] != null) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: _cardDeco(radius: 12, shadow: false),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.location_on_outlined, size: 16, color: _P.textMuted),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(bookingData['address'].toString(), style: _T.body(12.5)),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 20),
          const _SectionTitle('CHANGE STATUS'),
          const SizedBox(height: 10),

          // Status dropdown
          Builder(
            builder: (context) {
              final current = _mapOldStatusToNew(widget.order['status'] ?? 'pending');
              final options = _Status.all.contains(current) ? _Status.all : [..._Status.all, current];
              return DropdownButtonFormField<String>(
                value: current,
                decoration: _inputDeco(label: 'Update Status'),
                style: _T.body(13.5, c: _P.textPrimary),
                dropdownColor: _P.card,
                borderRadius: BorderRadius.circular(12),
                icon: const Icon(Icons.expand_more_rounded, color: _P.textMuted),
                items: options
                    .map((s) {
                      final cfg = _Status.of(s);
                      return DropdownMenuItem(
                        value: s,
                        child: Row(
                          children: [
                            Container(
                              width: 9,
                              height: 9,
                              decoration: BoxDecoration(color: cfg.color, shape: BoxShape.circle),
                            ),
                            const SizedBox(width: 10),
                            Text(cfg.label, style: _T.body(13.5, c: _P.textPrimary)),
                          ],
                        ),
                      );
                    }).toList(),
                onChanged: (v) { if (v != null) widget.onStatusChanged(v); },
              );
            },
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
          width: isMobile ? double.infinity : 580,
          clipBehavior: Clip.antiAlias,
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.88),
          decoration: BoxDecoration(
            color: _P.canvas,
            borderRadius: BorderRadius.circular(22),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 48, offset: const Offset(0, 20))],
          ),
          child: Column(
            children: [
              // Header
              _DialogHeader(
                leading: _Avatar(initials: _initialsOf(bookingData), size: 44, onDark: true),
                title: 'Customer Details',
                subtitle: '${bookingData['firstName'] ?? ''} ${bookingData['lastName'] ?? ''}',
                compact: isMobile,
                onClose: () => Navigator.of(context).pop(),
              ),

              // Body
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(isMobile ? 14 : 22),
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

    final orderId     = widget.order['orderId'] ?? widget.order['id'] ?? 'DCP-0000';
    final totalAmount = _getTotalAmount();
    final status      = _Status.of(widget.order['status'] ?? '');
    final addressStr  = _getAddressString(bookingData);
    final customerName = '${bookingData['firstName'] ?? 'Valued'} ${bookingData['lastName'] ?? 'Customer'}'.trim();
    final phone       = (bookingData['phone'] ?? 'N/A').toString();
    final email       = (bookingData['email'] ?? 'N/A').toString();
    final colDate     = '${bookingData['collectionDate'] ?? 'N/A'} ${bookingData['collectionTime'] ?? ''}'.trim();
    final delDate     = '${bookingData['deliveryDate'] ?? 'N/A'} ${bookingData['deliveryTime'] ?? ''}'.trim();
    final paymentMethod = (widget.order['paymentMethod'] ?? bookingData['paymentMethod'] ?? 'SumUp / Card / COD').toString().toUpperCase();

    showDialog(
      context: context,
      builder: (dialogCtx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Container(
          width: 680,
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(dialogCtx).height * 0.92),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.18), blurRadius: 36, offset: const Offset(0, 12)),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              // Top Bar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                color: const Color(0xFF0F172A),
                child: Row(
                  children: [
                    const Icon(Icons.receipt_long_rounded, color: Color(0xFF38BDF8), size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Tax Invoice & Order Receipt · #$orderId',
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.white70),
                      onPressed: () => Navigator.of(dialogCtx).pop(),
                    ),
                  ],
                ),
              ),

              // Printable Invoice Sheet
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 1. Signature Brand Header (Signature Logo Only, No Icon Box)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Text(
                                      'Dryclean ',
                                      style: GoogleFonts.satisfy(
                                        fontSize: 30,
                                        fontWeight: FontWeight.w700,
                                        color: const Color(0xFF1B5E20),
                                      ),
                                    ),
                                    Text(
                                      'Plus',
                                      style: GoogleFonts.satisfy(
                                        fontSize: 30,
                                        fontWeight: FontWeight.w700,
                                        color: const Color(0xFFEF4444),
                                      ),
                                    ),
                                    Text(
                                      '+',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 24,
                                        fontWeight: FontWeight.w900,
                                        color: const Color(0xFFEF4444),
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    const Icon(Icons.auto_awesome, size: 15, color: Color(0xFFFACC15)),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text('DryClean Plus Ltd · 2c Bar Gate, Newark NG24 1ES, United Kingdom\ndilee@drycleanplus.co.uk · +44 7424 866802',
                                    style: GoogleFonts.plusJakartaSans(fontSize: 11, color: const Color(0xFF64748B), height: 1.45)),
                              ],
                            ),
                            const Spacer(),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF0E3AA8).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text('OFFICIAL INVOICE', style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w800, color: const Color(0xFF0E3AA8))),
                                ),
                                const SizedBox(height: 6),
                                Text('Invoice #: INV-$orderId', style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A))),
                                Text('Date: ${DateFormat('dd MMM yyyy, HH:mm').format(DateTime.now())}', style: GoogleFonts.plusJakartaSans(fontSize: 11, color: const Color(0xFF64748B))),
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: status.color.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(status.label, style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w700, color: status.color)),
                                ),
                              ],
                            ),
                          ],
                        ),

                        const SizedBox(height: 20),
                        const Divider(color: Color(0xFFCBD5E1), thickness: 1.2),
                        const SizedBox(height: 16),

                        // 2. Customer & Route Metadata Box
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('CUSTOMER DETAILS', style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.w800, color: const Color(0xFF64748B), letterSpacing: 0.8)),
                                    const SizedBox(height: 4),
                                    Text(customerName, style: GoogleFonts.plusJakartaSans(fontSize: 13.5, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A))),
                                    const SizedBox(height: 2),
                                    Text('Phone: $phone', style: GoogleFonts.plusJakartaSans(fontSize: 12, color: const Color(0xFF334155))),
                                    Text('Email: $email', style: GoogleFonts.plusJakartaSans(fontSize: 12, color: const Color(0xFF334155))),
                                    const SizedBox(height: 4),
                                    Text('Address: $addressStr', style: GoogleFonts.plusJakartaSans(fontSize: 12, color: const Color(0xFF334155), height: 1.3)),
                                  ],
                                ),
                              ),
                              Container(width: 1, height: 90, color: const Color(0xFFCBD5E1)),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('SCHEDULE & SERVICE', style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.w800, color: const Color(0xFF64748B), letterSpacing: 0.8)),
                                    const SizedBox(height: 4),
                                    Text('Collection Slot:', style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF0E3AA8))),
                                    Text(colDate, style: GoogleFonts.plusJakartaSans(fontSize: 12, color: const Color(0xFF0F172A))),
                                    const SizedBox(height: 6),
                                    Text('Delivery Slot:', style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF10B981))),
                                    Text(delDate, style: GoogleFonts.plusJakartaSans(fontSize: 12, color: const Color(0xFF0F172A))),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 20),

                        // 3. Itemized Table
                        Text('INVOICED GARMENTS & SERVICES', style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A), letterSpacing: 0.6)),
                        const SizedBox(height: 10),

                        Table(
                          border: TableBorder(
                            horizontalInside: const BorderSide(color: Color(0xFFE2E8F0), width: 1),
                            bottom: const BorderSide(color: Color(0xFFCBD5E1), width: 1.5),
                          ),
                          columnWidths: const {
                            0: FlexColumnWidth(4),
                            1: FlexColumnWidth(2.5),
                            2: FlexColumnWidth(1.2),
                            3: FlexColumnWidth(1.8),
                            4: FlexColumnWidth(1.8),
                          },
                          children: [
                            // Table Header
                            TableRow(
                              decoration: const BoxDecoration(color: Color(0xFFF1F5F9)),
                              children: [
                                Padding(padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8), child: Text('ITEM / GARMENT', style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w800, color: const Color(0xFF334155)))),
                                Padding(padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6), child: Text('CATEGORY', style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w800, color: const Color(0xFF334155)))),
                                Padding(padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6), child: Text('QTY', textAlign: TextAlign.center, style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w800, color: const Color(0xFF334155)))),
                                Padding(padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6), child: Text('RATE', textAlign: TextAlign.right, style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w800, color: const Color(0xFF334155)))),
                                Padding(padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8), child: Text('TOTAL', textAlign: TextAlign.right, style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w800, color: const Color(0xFF334155)))),
                              ],
                            ),
                            // Table Rows
                            if (items.isNotEmpty)
                              ...items.map((itm) {
                                final name = (itm['itemType'] ?? itm['name'] ?? 'Garment').toString();
                                final cat = (itm['category'] ?? 'General').toString();
                                final qty = (itm['quantity'] as num?)?.toInt() ?? (itm['qty'] as num?)?.toInt() ?? 1;
                                final p = (itm['unitPrice'] as num?)?.toDouble() ?? _parsePrice(itm['price']);
                                final lineTot = p * qty;
                                return TableRow(
                                  children: [
                                    Padding(padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8), child: Text(name, style: GoogleFonts.plusJakartaSans(fontSize: 12.5, fontWeight: FontWeight.w600, color: const Color(0xFF0F172A)))),
                                    Padding(padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6), child: Text(cat, style: GoogleFonts.plusJakartaSans(fontSize: 11.5, color: const Color(0xFF64748B)))),
                                    Padding(padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6), child: Text('$qty', textAlign: TextAlign.center, style: GoogleFonts.plusJakartaSans(fontSize: 12.5, color: const Color(0xFF0F172A)))),
                                    Padding(padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6), child: Text('£${p.toStringAsFixed(2)}', textAlign: TextAlign.right, style: GoogleFonts.plusJakartaSans(fontSize: 12.5, color: const Color(0xFF334155)))),
                                    Padding(padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8), child: Text('£${lineTot.toStringAsFixed(2)}', textAlign: TextAlign.right, style: GoogleFonts.plusJakartaSans(fontSize: 12.5, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A)))),
                                  ],
                                );
                              })
                            else
                              TableRow(
                                children: [
                                  Padding(padding: const EdgeInsets.all(12), child: Text('Standard Service Bag (Priced upon facility inspection)', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontStyle: FontStyle.italic, color: const Color(0xFF64748B)))),
                                  Padding(padding: const EdgeInsets.all(12), child: Text(services.isNotEmpty ? services.join(', ') : 'Dry Cleaning', style: GoogleFonts.plusJakartaSans(fontSize: 11.5))),
                                  const Padding(padding: EdgeInsets.all(12), child: Text('1', textAlign: TextAlign.center)),
                                  Padding(padding: const EdgeInsets.all(12), child: Text('£$totalAmount', textAlign: TextAlign.right)),
                                  Padding(padding: const EdgeInsets.all(12), child: Text('£$totalAmount', textAlign: TextAlign.right, style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold))),
                                ],
                              ),
                          ],
                        ),

                        const SizedBox(height: 18),

                        // 4. Financial Totals
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 5,
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('PAYMENT & TERMS', style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.w800, color: const Color(0xFF475569))),
                                    const SizedBox(height: 4),
                                    Text('Payment Mode: $paymentMethod', style: GoogleFonts.plusJakartaSans(fontSize: 11.5, fontWeight: FontWeight.w600, color: const Color(0xFF0E3AA8))),
                                    const SizedBox(height: 2),
                                    Text('SumUp Secure Payment Link:\nhttps://pay.sumup.com/b2c/Q3MO3NEP', style: GoogleFonts.plusJakartaSans(fontSize: 11, color: const Color(0xFF64748B))),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              flex: 4,
                              child: Column(
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text('Subtotal:', style: GoogleFonts.plusJakartaSans(fontSize: 12.5, color: const Color(0xFF64748B))),
                                      Text('£$totalAmount', style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF0F172A))),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text('Collection & Delivery:', style: GoogleFonts.plusJakartaSans(fontSize: 12.5, color: const Color(0xFF64748B))),
                                      Text('FREE', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF10B981))),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  const Divider(color: Color(0xFFCBD5E1)),
                                  const SizedBox(height: 6),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text('Total Due:', style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A))),
                                      Text('£$totalAmount', style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w900, color: const Color(0xFF0E3AA8))),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 24),
                        Center(
                          child: Text(
                            'Thank you for trusting DryClean Plus! · London\'s Premier Laundry Partner',
                            style: GoogleFonts.satisfy(fontSize: 15, color: const Color(0xFF64748B)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Bottom Actions: 3 Print Formats (A4, 80mm Thermal, 58mm Thermal)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: const BoxDecoration(
                  color: Color(0xFFF8FAFC),
                  border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
                ),
                child: Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  alignment: WrapAlignment.end,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(dialogCtx).pop(),
                      child: const Text('Close'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () {
                        final html = _buildThermalReceipt58mmHtml(
                          orderId: orderId,
                          customerName: customerName,
                          phone: phone,
                          addressStr: addressStr,
                          colDate: colDate,
                          delDate: delDate,
                          statusLabel: status.label,
                          items: items,
                          totalAmount: totalAmount,
                          paymentMethod: paymentMethod,
                        );
                        printInvoiceHtml(html);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Printing 58mm Thermal Receipt (2")...'),
                            backgroundColor: Color(0xFF334155),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                      icon: const Icon(Icons.receipt_rounded, size: 16),
                      label: const Text('58mm Receipt (2")'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF334155),
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () {
                        final html = _buildThermalReceipt80mmHtml(
                          orderId: orderId,
                          customerName: customerName,
                          phone: phone,
                          addressStr: addressStr,
                          colDate: colDate,
                          delDate: delDate,
                          statusLabel: status.label,
                          items: items,
                          totalAmount: totalAmount,
                          paymentMethod: paymentMethod,
                        );
                        printInvoiceHtml(html);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Printing 80mm POS Thermal Receipt (3")...'),
                            backgroundColor: Color(0xFF0D9488),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                      icon: const Icon(Icons.print_rounded, size: 16),
                      label: const Text('80mm POS Roll (3")'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0D9488),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () {
                        final html = _buildInvoiceHtml(
                          orderId: orderId,
                          customerName: customerName,
                          phone: phone,
                          email: email,
                          addressStr: addressStr,
                          colDate: colDate,
                          delDate: delDate,
                          statusLabel: status.label,
                          items: items,
                          totalAmount: totalAmount,
                          paymentMethod: paymentMethod,
                        );
                        printInvoiceHtml(html);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Opening printable A4 Tax Invoice...'),
                            backgroundColor: Color(0xFF0E3AA8),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                      icon: const Icon(Icons.picture_as_pdf_rounded, size: 16),
                      label: const Text('A4 Tax Invoice'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0E3AA8),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () async {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Sending invoice email via Resend...'),
                            backgroundColor: Color(0xFF1E5FD8),
                            behavior: SnackBarBehavior.floating,
                            duration: Duration(seconds: 2),
                          ),
                        );
                        final res = await ResendEmailService.instance.sendDeliveredInvoiceEmail(widget.order);
                        if (!context.mounted) return;
                        if (res['success'] == true) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('✓ Official invoice sent to $email via Resend'),
                              backgroundColor: const Color(0xFF059669),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Could not send email: ${res['error']}'),
                              backgroundColor: const Color(0xFFDC2626),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.send_rounded, size: 16),
                      label: const Text('Email Invoice to Customer'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E5FD8),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
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

  String _buildInvoiceHtml({
    required String orderId,
    required String customerName,
    required String phone,
    required String email,
    required String addressStr,
    required String colDate,
    required String delDate,
    required String statusLabel,
    required List<Map<String, dynamic>> items,
    required String totalAmount,
    required String paymentMethod,
  }) {
    final dateStr = DateFormat('dd MMM yyyy').format(DateTime.now());
    final StringBuffer rows = StringBuffer();
    double itemsSum = 0.0;
    if (items.isEmpty) {
      rows.write('''
        <tr>
          <td>1</td>
          <td>Dry Cleaning &amp; Laundry Service</td>
          <td>Standard Bag</td>
          <td>1</td>
          <td>£$totalAmount</td>
          <td style="font-weight: bold;">£$totalAmount</td>
        </tr>
      ''');
    } else {
      for (int i = 0; i < items.length; i++) {
        final itm = items[i];
        final name = itm['itemType'] ?? itm['name'] ?? 'Garment';
        final cat = itm['category'] ?? 'General';
        final qty = (itm['quantity'] as num?)?.toInt() ?? (itm['qty'] as num?)?.toInt() ?? 1;
        final p = (itm['unitPrice'] as num?)?.toDouble() ?? _parsePrice(itm['price']);
        final lineVal = p * qty;
        itemsSum += lineVal;
        final rowTotal = lineVal.toStringAsFixed(2);
        rows.write('''
          <tr>
            <td>\${i + 1}</td>
            <td style="font-weight: 600;">\$name</td>
            <td>\$cat</td>
            <td>\$qty</td>
            <td>£\${p.toStringAsFixed(2)}</td>
            <td style="font-weight: bold;">£\$rowTotal</td>
          </tr>
        ''');
      }
    }

    final totalDouble = double.tryParse(totalAmount.replaceAll(RegExp(r'[^0-9.]'), '')) ?? itemsSum;
    final subtotalStr = itemsSum > 0 ? itemsSum.toStringAsFixed(2) : totalDouble.toStringAsFixed(2);
    final totalStr = totalDouble.toStringAsFixed(2);

    return '''<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=860">
  <title>Invoice INV-\$orderId, DryClean Plus</title>
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
  <link href="https://fonts.googleapis.com/css2?family=Satisfy&display=swap" rel="stylesheet">
  <style>
    @page { size: A4 portrait; margin: 14mm 16mm; }
    * { box-sizing: border-box; }

    /* Screen: crisp white A4 sheet */
    body {
      margin: 0;
      padding: 36px 0 48px;
      background: #F4F6F9;
      color: #374151;
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif;
      font-size: 13px;
      line-height: 1.5;
      -webkit-print-color-adjust: exact;
      print-color-adjust: exact;
    }

    .page {
      width: 210mm;
      margin: 0 auto;
      background: #FFFFFF;
      box-shadow:
        0 0 0 1px rgba(15, 23, 42, 0.06),
        0 2px 4px rgba(15, 23, 42, 0.08),
        0 18px 40px rgba(15, 23, 42, 0.14);
    }

    .frame { width: 100%; height: 297mm; border-collapse: separate; border-spacing: 0; }
    .frame td { padding: 0; vertical-align: top; }
    .frame .band td { height: 4px; border-top: 4px solid #0B2A6B; font-size: 0; line-height: 0; }
    .frame tr.fill td { height: 100%; }
    .frame td.r-head { padding: 10mm 17mm 0; }
    .frame td.r-meta { padding: 9mm 17mm 0; }
    .frame td.r-items { padding: 8mm 17mm 0; }
    .frame td.r-summary { padding: 7mm 17mm 0; }
    .frame td.r-foot { padding: 0 17mm 13mm; vertical-align: bottom; }

    table { border-collapse: collapse; }
    .layout { width: 100%; }
    .layout td { padding: 0; vertical-align: top; }

    .label { font-size: 11.5px; color: #6B7280; margin-bottom: 3px; }
    .strong { font-weight: bold; color: #111827; }
    .ink { color: #111827; }
    .muted { color: #6B7280; }

    /* Signature Wordmark Only (matching website DrycleanPlusLogo) */
    .wordmark {
      font-family: 'Satisfy', 'Brush Script MT', 'Segoe Script', cursive, Georgia, serif;
      font-size: 30px;
      font-weight: bold;
      font-style: italic;
      line-height: 1.15;
      margin-bottom: 8px;
      white-space: nowrap;
    }
    .wordmark .g { color: #1B5E20; }
    .wordmark .r { color: #EF4444; margin-left: 3px; }
    .wordmark .p { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Arial, sans-serif; font-size: 22px; font-weight: 900; font-style: normal; color: #EF4444; margin-left: 2px; }
    .wordmark .s { color: #FACC15; font-size: 15px; font-style: normal; margin-left: 4px; vertical-align: middle; }

    .company { font-size: 12px; line-height: 1.6; color: #6B7280; }
    .doc-title { font-family: Georgia, 'Times New Roman', serif; font-size: 30px; line-height: 1.1; color: #111827; text-align: right; margin-bottom: 10px; }
    .kv { margin-left: auto; }
    .kv td { padding: 2px 0 2px 18px; font-size: 12.5px; line-height: 1.5; vertical-align: top; }
    .kv td.k { color: #6B7280; text-align: right; }
    .kv td.v { color: #111827; font-weight: bold; text-align: right; }

    /* Customer and schedule */
    .meta { border-top: 1px solid #E3E6EB; border-bottom: 1px solid #E3E6EB; }
    .meta td.left { width: 54%; padding: 16px 20px 18px 0; }
    .meta td.right { width: 46%; padding: 16px 0 18px 22px; border-left: 1px solid #E3E6EB; }
    .meta .line { font-size: 13px; line-height: 1.55; color: #374151; }
    .meta .when { margin-bottom: 10px; }

    /* Items */
    .items { width: 100%; }
    .items thead { display: table-header-group; }
    .items tr { page-break-inside: avoid; break-inside: avoid; }
    .items th {
      padding: 0 8px 9px;
      border-bottom: 1px solid #0B2A6B;
      font-size: 12px;
      font-weight: bold;
      color: #0B2A6B;
      text-align: left;
    }
    .items tbody td {
      padding: 10px 8px;
      border-bottom: 1px solid #E3E6EB;
      font-size: 13px;
      line-height: 1.5;
      color: #111827;
      vertical-align: top;
    }
    .items th:nth-child(1), .items td:nth-child(1) { width: 34px; padding-left: 0; text-align: left; }
    .items th:nth-child(4), .items td:nth-child(4) { width: 52px; text-align: center; }
    .items th:nth-child(5), .items td:nth-child(5) { width: 96px; text-align: right; }
    .items th:nth-child(6), .items td:nth-child(6) { width: 96px; padding-right: 0; text-align: right; }
    .items td:nth-child(3) { color: #6B7280; }

    /* Payment and totals */
    .summary { page-break-inside: avoid; break-inside: avoid; }
    .summary td.pay { width: 52%; padding-right: 28px; }
    .summary td.sum { width: 48%; }
    .pay .line { font-size: 13px; line-height: 1.55; color: #374151; }
    .pay a { color: #0B2A6B; word-break: break-all; }
    .totals { width: 100%; }
    .totals td { padding: 4px 0; font-size: 13px; color: #6B7280; }
    .totals td.n { text-align: right; color: #111827; }
    .totals tr.grand td { padding-top: 14px; border-top: 2px solid #0B2A6B; }
    .totals tr.grand td.k { font-size: 14px; font-weight: bold; color: #111827; vertical-align: middle; }
    .totals tr.grand td.n { font-family: Georgia, 'Times New Roman', serif; font-size: 26px; line-height: 1.2; color: #0B2A6B; }
    .spacer td { padding-bottom: 10px !important; }

    /* Footer */
    .footer { padding-top: 16px; border-top: 1px solid #E3E6EB; page-break-inside: avoid; break-inside: avoid; }
    .footer p { margin: 0 0 6px; font-size: 12px; line-height: 1.6; color: #6B7280; }
    .footer p.thanks { font-size: 13px; color: #111827; }

    @media print {
      body { padding: 0; background: #FFFFFF; }
      .page { width: auto; margin: 0; box-shadow: none; }
      .frame { height: 267mm; }
      .frame td.r-head, .frame td.r-meta, .frame td.r-items, .frame td.r-summary, .frame td.r-foot { padding-left: 0; padding-right: 0; }
      .frame td.r-foot { padding-bottom: 0; }
    }
  </style>
</head>
<body>
  <div class="page">
    <table class="frame" role="presentation">

      <tr class="band"><td></td></tr>

      <!-- Header -->
      <tr>
        <td class="r-head">
          <table class="layout">
            <tr>
              <td>
                <div class="wordmark">
                  <span class="g">Dryclean</span><span class="r">Plus</span><span class="p">+</span><span class="s">&#10022;</span>
                </div>
                <div class="company">
                  DryClean Plus Ltd<br>
                  2c Bar Gate, Newark NG24 1ES, United Kingdom<br>
                  dilee@drycleanplus.co.uk · www.drycleanplus.co.uk
                </div>
              </td>
              <td style="text-align: right;">
                <div class="doc-title">Invoice</div>
                <table class="kv">
                  <tr><td class="k">Invoice number</td><td class="v">INV-\$orderId</td></tr>
                  <tr><td class="k">Date</td><td class="v">\$dateStr</td></tr>
                  <tr><td class="k">Status</td><td class="v">\$statusLabel</td></tr>
                </table>
              </td>
            </tr>
          </table>
        </td>
      </tr>

      <!-- Customer and schedule -->
      <tr>
        <td class="r-meta">
          <table class="layout meta">
            <tr>
              <td class="left">
                <div class="label">Billed to</div>
                <div class="line strong">\$customerName</div>
                <div class="line">\$phone</div>
                <div class="line">\$email</div>
                <div class="line">\$addressStr</div>
              </td>
              <td class="right">
                <div class="when">
                  <div class="label">Collection</div>
                  <div class="line ink">\$colDate</div>
                </div>
                <div>
                  <div class="label">Delivery</div>
                  <div class="line ink">\$delDate</div>
                </div>
              </td>
            </tr>
          </table>
        </td>
      </tr>

      <!-- Items -->
      <tr>
        <td class="r-items">
          <table class="items">
            <thead>
              <tr>
                <th>#</th>
                <th>Item</th>
                <th>Category</th>
                <th>Qty</th>
                <th>Unit price</th>
                <th>Total</th>
              </tr>
            </thead>
            <tbody>
              \$rows
            </tbody>
          </table>
        </td>
      </tr>

      <!-- Payment and totals -->
      <tr>
        <td class="r-summary">
          <table class="layout summary">
            <tr>
              <td class="pay">
                <div class="label">Payment</div>
                <div class="line ink">\$paymentMethod</div>
                <div class="line" style="margin-top: 8px;">
                  Pay online with SumUp:<br>
                  <a href="https://pay.sumup.com/b2c/Q3MO3NEP">https://pay.sumup.com/b2c/Q3MO3NEP</a>
                </div>
              </td>
              <td class="sum">
                <table class="totals">
                  <tr><td>Subtotal</td><td class="n">£\$subtotalStr</td></tr>
                  <tr class="spacer"><td>Collection and delivery</td><td class="n">Free</td></tr>
                  <tr class="grand"><td class="k">Total</td><td class="n">£\$totalStr</td></tr>
                </table>
              </td>
            </tr>
          </table>
        </td>
      </tr>

      <!-- Filler -->
      <tr class="fill"><td></td></tr>

      <!-- Footer -->
      <tr>
        <td class="r-foot">
          <div class="footer">
            <p class="thanks">Thank you for choosing DryClean Plus.</p>
            <p>Questions about this invoice? Email dilee@drycleanplus.co.uk or call +44 7424 866802.</p>
            <p>DryClean Plus Ltd · 2c Bar Gate, Newark NG24 1ES, United Kingdom</p>
          </div>
        </td>
      </tr>

    </table>
  </div>
</body>
</html>''';
  }

  // ── 80mm (3-inch) POS Thermal Receipt Format ────────────────────────────────
  String _buildThermalReceipt80mmHtml({
    required String orderId,
    required String customerName,
    required String phone,
    required String addressStr,
    required String colDate,
    required String delDate,
    required String statusLabel,
    required List<Map<String, dynamic>> items,
    required String totalAmount,
    required String paymentMethod,
  }) {
    final dateStr = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());
    final StringBuffer rows = StringBuffer();
    int totalCount = 0;

    if (items.isEmpty) {
      rows.write('''
        <tr>
          <td colspan="3" style="text-align: center; padding: 6px 0; font-style: italic; font-size: 11px;">
            Standard Bag Service (Itemized at facility)
          </td>
        </tr>
      ''');
    } else {
      for (final itm in items) {
        final name = itm['itemType'] ?? itm['name'] ?? 'Garment';
        final qty = (itm['quantity'] as num?)?.toInt() ?? (itm['qty'] as num?)?.toInt() ?? 1;
        final p = (itm['unitPrice'] as num?)?.toDouble() ?? _parsePrice(itm['price']);
        totalCount += qty;
        final rowTotal = (p * qty).toStringAsFixed(2);
        rows.write('''
          <tr>
            <td style="padding: 3px 0; font-weight: 700;">\$name <span style="font-weight: 400; font-size: 10px;">(x\$qty)</span></td>
            <td style="padding: 3px 0; text-align: right; font-weight: 700;">£\$rowTotal</td>
          </tr>
        ''');
      }
    }

    return '''<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <title>Receipt #\$orderId (80mm)</title>
  <style>
    @page { size: 80mm auto; margin: 3mm; }
    * { box-sizing: border-box; }
    body {
      font-family: -apple-system, BlinkMacSystemFont, "Courier New", Courier, monospace, sans-serif;
      color: #000;
      background: #FFF;
      margin: 0;
      padding: 4px;
      width: 74mm;
      font-size: 12px;
      line-height: 1.3;
    }
    .center { text-align: center; }
    .bold { font-weight: 800; }
    .cut-line { border-bottom: 1px dashed #000; margin: 6px 0; }
    .double-line { border-bottom: 2px solid #000; margin: 6px 0; }
    table { width: 100%; border-collapse: collapse; }
    .row { display: flex; justify-content: space-between; margin-bottom: 2px; }
  </style>
</head>
<body>
  <div class="center">
    <div style="font-size: 18px; font-weight: 900; letter-spacing: 1px;">DRYCLEAN PLUS</div>
    <div style="font-size: 10px; font-weight: 700; margin-top: 1px;">2c Bar Gate, Newark NG24 1ES, UK</div>
    <div style="font-size: 9px; margin-top: 2px;">www.drycleanplus.co.uk · +44 7424 866802</div>
    <div class="cut-line"></div>
    <div style="font-size: 15px; font-weight: 900; margin: 4px 0;">ORDER #\$orderId</div>
    <div style="font-size: 10px;">\$dateStr · Status: \$statusLabel</div>
  </div>

  <div class="cut-line"></div>

  <div style="font-size: 11px;">
    <div class="row"><span class="bold">Customer:</span><span>\$customerName</span></div>
    <div class="row"><span class="bold">Phone:</span><span>\$phone</span></div>
    <div style="font-size: 10px; margin-top: 2px; word-break: break-word;"><span class="bold">Address:</span> \$addressStr</div>
  </div>

  <div class="cut-line"></div>

  <div style="font-size: 11px;">
    <div class="row"><span>Collection:</span><span class="bold">\$colDate</span></div>
    <div class="row"><span>Delivery:</span><span class="bold">\$delDate</span></div>
  </div>

  <div class="double-line"></div>

  <div style="font-size: 10px; font-weight: 800; margin-bottom: 4px;">ITEMIZED GARMENTS</div>
  <table>
    <tbody>
      \$rows
    </tbody>
  </table>

  <div class="double-line"></div>

  <div class="row" style="font-size: 12px;"><span>Total Garments:</span><span class="bold">\$totalCount items</span></div>
  <div class="row" style="font-size: 12px;"><span>Delivery & Collection:</span><span class="bold">FREE</span></div>
  <div class="cut-line"></div>
  <div class="row" style="font-size: 16px; font-weight: 900;">
    <span>TOTAL DUE:</span>
    <span>£\$totalAmount</span>
  </div>
  <div class="row" style="font-size: 10px; margin-top: 4px;"><span>Payment:</span><span>\$paymentMethod</span></div>

  <div class="cut-line"></div>

  <div class="center" style="font-size: 10px; margin-top: 6px;">
    <div class="bold">Thank you for choosing DryClean Plus!</div>
    <div style="font-size: 9px; margin-top: 2px;">Pay online: pay.sumup.com/b2c/Q3MO3NEP</div>
    <div style="margin-top: 6px; font-family: monospace; font-size: 11px; letter-spacing: 2px;">* \$orderId *</div>
  </div>
</body>
</html>''';
  }

  // ── 58mm (2-inch) Compact Mobile Thermal Format ─────────────────────────────
  String _buildThermalReceipt58mmHtml({
    required String orderId,
    required String customerName,
    required String phone,
    required String addressStr,
    required String colDate,
    required String delDate,
    required String statusLabel,
    required List<Map<String, dynamic>> items,
    required String totalAmount,
    required String paymentMethod,
  }) {
    final dateStr = DateFormat('dd/MM HH:mm').format(DateTime.now());
    final StringBuffer rows = StringBuffer();
    int totalCount = 0;

    for (final itm in items) {
      final name = itm['itemType'] ?? itm['name'] ?? 'Garment';
      final qty = (itm['quantity'] as num?)?.toInt() ?? (itm['qty'] as num?)?.toInt() ?? 1;
      final p = (itm['unitPrice'] as num?)?.toDouble() ?? _parsePrice(itm['price']);
      totalCount += qty;
      final rowTotal = (p * qty).toStringAsFixed(2);
      rows.write('''
        <div style="display: flex; justify-content: space-between; font-size: 10px; margin-bottom: 2px;">
          <span style="font-weight: 700; max-width: 70%; overflow: hidden; text-overflow: ellipsis; white-space: nowrap;">\$name (x\$qty)</span>
          <span style="font-weight: 700;">£\$rowTotal</span>
        </div>
      ''');
    }

    return '''<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <title>Receipt #\$orderId (58mm)</title>
  <style>
    @page { size: 58mm auto; margin: 2mm; }
    * { box-sizing: border-box; }
    body {
      font-family: -apple-system, monospace, sans-serif;
      color: #000;
      background: #FFF;
      margin: 0;
      padding: 2px;
      width: 48mm;
      font-size: 10px;
      line-height: 1.25;
    }
    .center { text-align: center; }
    .bold { font-weight: 800; }
    .cut-line { border-bottom: 1px dashed #000; margin: 4px 0; }
  </style>
</head>
<body>
  <div class="center">
    <div style="font-size: 14px; font-weight: 900;">DRYCLEAN PLUS</div>
    <div style="font-size: 8px;">01636918181</div>
    <div class="cut-line"></div>
    <div style="font-size: 13px; font-weight: 900;">#\$orderId</div>
    <div style="font-size: 8.5px;">\$dateStr</div>
  </div>

  <div class="cut-line"></div>

  <div style="font-size: 9.5px;">
    <div><b>Cust:</b> \$customerName</div>
    <div><b>Tel:</b> \$phone</div>
    <div style="font-size: 8.5px; word-break: break-word;"><b>Addr:</b> \$addressStr</div>
  </div>

  <div class="cut-line"></div>

  <div style="font-size: 9px;">
    <div><b>Col:</b> \$colDate</div>
    <div><b>Del:</b> \$delDate</div>
  </div>

  <div class="cut-line"></div>

  <div style="font-size: 9px; font-weight: 800; margin-bottom: 2px;">ITEMS (\$totalCount)</div>
  \$rows

  <div class="cut-line"></div>

  <div style="display: flex; justify-content: space-between; font-size: 13px; font-weight: 900;">
    <span>TOTAL:</span>
    <span>£\$totalAmount</span>
  </div>
  <div style="font-size: 8px; margin-top: 2px;">Payment: \$paymentMethod</div>

  <div class="cut-line"></div>
  <div class="center" style="font-size: 8px; font-weight: 700;">THANK YOU! · DRYCLEAN PLUS</div>
</body>
</html>''';
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

  void _openItemizeModal(BuildContext context, Map<String, dynamic> order, Map<String, dynamic> bookingData) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ItemizeOrderDialog(
        order: order,
        bookingData: bookingData,
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
      padding: const EdgeInsets.fromLTRB(8, 4, 11, 4),
      decoration: BoxDecoration(
        color: status.bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: status.color.withOpacity(0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(status.icon, size: 13, color: status.color),
          const SizedBox(width: 5),
          Text(status.label, style: _T.label(11.5, w: FontWeight.w700, c: status.color)),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final Color color;
  final Color bg;
  final IconData? icon;
  const _Chip({required this.label, required this.color, required this.bg, this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: color.withOpacity(0.15)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 11, color: color),
            const SizedBox(width: 4),
          ],
          Text(label, style: _T.label(9.5, w: FontWeight.w800, c: color).copyWith(letterSpacing: 0.6)),
        ],
      ),
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      child: Row(
        children: [
          Container(
            constraints: const BoxConstraints(minWidth: 36),
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _P.azureSoft,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text('${qty}x', style: _T.heading(12, w: FontWeight.w800, c: _P.azure)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: _T.label(13, c: _P.textPrimary),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 10),
          Text('£$priceStr', style: _T.money(13.5)),
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
      icon: Icon(icon, size: 19, color: _P.azure),
      label: Text(label, style: _T.label(13, w: FontWeight.w700, c: _P.azure)),
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
      icon: Icon(icon, size: 16),
      label: Text(label, style: _T.label(12.5, w: FontWeight.w700)),
      style: OutlinedButton.styleFrom(
        foregroundColor: _P.textSecondary,
        backgroundColor: _P.card,
        side: const BorderSide(color: _P.border),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        minimumSize: Size.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
          child: _SectionTitle(title.toUpperCase()),
        ),
        Container(
          decoration: _cardDeco(radius: 14, shadow: false),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(13),
            child: Column(
              children: rows.asMap().entries.map((e) {
                final isLast = e.key == rows.length - 1;
                return Column(
                  children: [
                    e.value,
                    if (!isLast) const Divider(height: 1, color: _P.borderSoft, indent: 60),
                  ],
                );
              }).toList(),
            ),
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: _P.azureSoft,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 16, color: _P.azure),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: _T.body(11.5, c: _P.textMuted)),
                const SizedBox(height: 2),
                Text(value, style: _T.label(13.5, c: _P.textPrimary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
// ─── Itemize Order & Live Price Modal ────────────────────────────────────────

class _ItemizeOrderDialog extends StatefulWidget {
  final Map<String, dynamic> order;
  final Map<String, dynamic> bookingData;

  const _ItemizeOrderDialog({
    required this.order,
    required this.bookingData,
  });

  @override
  State<_ItemizeOrderDialog> createState() => _ItemizeOrderDialogState();
}

class _EditableLine {
  String id;
  String category;
  String name;
  double unitPrice;
  int qty;

  _EditableLine({
    required this.id,
    required this.category,
    required this.name,
    required this.unitPrice,
    this.qty = 1,
  });

  double get total => unitPrice * qty;
}

class _ItemizeOrderDialogState extends State<_ItemizeOrderDialog> {
  final List<_EditableLine> _lines = [];
  List<Map<String, dynamic>> _catalog = [];
  bool _loadingCatalog = true;
  bool _saving = false;
  bool _serviceFeeEnabled = true;
  double _serviceFee = 2.99;
  bool _deliveryFeeEnabled = false;
  double _deliveryFee = 0.0;

  String? _selectedCategory;
  Map<String, dynamic>? _selectedCatalogItem;

  String _customCategory = 'Dry Clean';
  final _customNameCtrl = TextEditingController();
  final _customPriceCtrl = TextEditingController();
  final _customCatCtrl = TextEditingController(text: 'General');
  final _notesCtrl = TextEditingController();

  late String _targetStatus;

  @override
  void initState() {
    super.initState();
    final currentStatus = widget.order['status'] ?? 'pending';
    _targetStatus = (currentStatus == 'at_facility' || currentStatus == 'inspecting' || currentStatus == 'collected')
        ? 'awaiting_approval'
        : currentStatus;

    _initExistingItems();
    _loadCatalog();
    _loadAppSettings();
  }

  Future<void> _loadAppSettings() async {
    try {
      final snap = await FirebaseFirestore.instance.collection('settings').doc('app').get();
      if (snap.exists && snap.data() != null) {
        final d = snap.data()!;
        if (mounted) {
          setState(() {
            _serviceFeeEnabled = d['serviceFeeEnabled'] == true || '${d['serviceFeeEnabled']}' == 'true';
            _serviceFee = _parsePrice(d['serviceFee'] ?? 2.99);
            _deliveryFeeEnabled = d['deliveryFeeEnabled'] == true || '${d['deliveryFeeEnabled']}' == 'true';
            _deliveryFee = _parsePrice(d['deliveryFee'] ?? 0.0);
          });
        }
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _customNameCtrl.dispose();
    _customPriceCtrl.dispose();
    _customCatCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  void _initExistingItems() {
    final raw = widget.bookingData['selectedItems'] ?? widget.order['selectedItems'] ?? widget.order['items'] ?? widget.bookingData['items'];
    if (raw is Map) {
      raw.forEach((key, val) {
        if (val is Map) {
          final cat = (val['category'] ?? 'General').toString().trim();
          final name = (val['itemType'] ?? val['name'] ?? val['title'] ?? 'Item').toString().trim();
          final p = _parsePrice(val['price'] ?? val['unitPrice']);
          final int qty = (val['quantity'] as num?)?.toInt() ?? (val['qty'] as num?)?.toInt() ?? 1;

          final match = _lines.where((l) => l.name.toLowerCase() == name.toLowerCase() && l.category.toLowerCase() == cat.toLowerCase());
          if (match.isNotEmpty) {
            match.first.qty += qty;
          } else {
            _lines.add(_EditableLine(
              id: UniqueKey().toString(),
              category: cat.isEmpty ? 'General' : cat,
              name: name.isEmpty ? 'Item' : name,
              unitPrice: p,
              qty: qty,
            ));
          }
        }
      });
    } else if (raw is List) {
      for (final val in raw) {
        if (val is Map) {
          final cat = (val['category'] ?? 'General').toString().trim();
          final name = (val['itemType'] ?? val['name'] ?? val['title'] ?? 'Item').toString().trim();
          final p = _parsePrice(val['price'] ?? val['unitPrice']);
          final int qty = (val['qty'] as num?)?.toInt() ?? (val['quantity'] as num?)?.toInt() ?? 1;
          _lines.add(_EditableLine(
            id: UniqueKey().toString(),
            category: cat.isEmpty ? 'General' : cat,
            name: name.isEmpty ? 'Item' : name,
            unitPrice: p,
            qty: qty,
          ));
        }
      }
    }
  }

  double _parsePrice(dynamic v) {
    if (v is num) return v.toDouble();
    if (v == null) return 0.0;
    final cleaned = v.toString().replaceAll('£', '').replaceAll(',', '').trim();
    return double.tryParse(cleaned) ?? 0.0;
  }

  Future<void> _loadCatalog() async {
    try {
      final snap = await FirebaseFirestore.instance.collection('services').orderBy('order').get();
      if (!mounted) return;
      final docs = snap.docs.map((d) {
        final m = Map<String, dynamic>.from(d.data());
        m['id'] = d.id;
        return m;
      }).where((m) => m['isActive'] != false).toList();

      setState(() {
        _catalog = docs;
        _loadingCatalog = false;
        if (docs.isNotEmpty) {
          _selectedCategory = docs.first['name'] ?? docs.first['title'] ?? '';
          final items = (docs.first['items'] as List?)?.cast<Map>() ?? [];
          if (items.isNotEmpty) {
            _selectedCatalogItem = Map<String, dynamic>.from(items.first);
          }
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingCatalog = false);
    }
  }

  void _addFromCatalog() {
    if (_selectedCatalogItem == null) return;
    final name = '${_selectedCatalogItem!['name'] ?? 'Item'}'.trim();
    final cat = '${_selectedCategory ?? 'General'}'.trim();
    final price = _parsePrice(_selectedCatalogItem!['price']);

    final existing = _lines.where((l) => l.name.toLowerCase() == name.toLowerCase() && l.category.toLowerCase() == cat.toLowerCase());
    setState(() {
      if (existing.isNotEmpty) {
        existing.first.qty++;
      } else {
        _lines.add(_EditableLine(
          id: UniqueKey().toString(),
          category: cat,
          name: name,
          unitPrice: price,
          qty: 1,
        ));
      }
    });
  }

  void _addCustomItem() {
    final name = _customNameCtrl.text.trim();
    final price = _parsePrice(_customPriceCtrl.text);
    final cat = _customCategory.trim().isEmpty ? 'Custom' : _customCategory.trim();

    if (name.isEmpty) return;

    setState(() {
      _lines.add(_EditableLine(
        id: UniqueKey().toString(),
        category: cat,
        name: name,
        unitPrice: price,
        qty: 1,
      ));
      _customNameCtrl.clear();
      _customPriceCtrl.clear();
    });
  }

  double get _subtotal => _lines.fold(0.0, (sum, l) => sum + l.total);
  double get _totalPrice => _subtotal;
  int get _totalCount => _lines.fold(0, (sum, l) => sum + l.qty);
  double get _appliedServiceFee => _serviceFeeEnabled ? _serviceFee : 0.0;
  double get _appliedDeliveryFee => _deliveryFeeEnabled ? _deliveryFee : 0.0;
  double get _finalTotal => _subtotal + _appliedServiceFee + _appliedDeliveryFee;

  Future<void> _saveAndSync() async {
    if (_saving) return;
    setState(() => _saving = true);

    try {
      final docId = (widget.order['id'] ?? widget.order['docId'] ?? '').toString();
      if (docId.isEmpty) throw StateError('Missing order document ID');

      final orderRef = FirebaseFirestore.instance.collection('orders').doc(docId);
      final batch = FirebaseFirestore.instance.batch();

      final Map<String, dynamic> selectedItemsMap = {};
      final List<Map<String, dynamic>> itemsList = [];
      int counter = 0;

      for (final itm in _lines) {
        for (int q = 0; q < itm.qty; q++) {
          selectedItemsMap['item_$counter'] = {
            'category': itm.category,
            'itemType': itm.name,
            'name': itm.name,
            'price': itm.unitPrice.toStringAsFixed(2),
            'description': itm.category,
          };
          counter++;
        }
        itemsList.add({
          'category': itm.category,
          'itemType': itm.name,
          'name': itm.name,
          'unitPrice': itm.unitPrice,
          'price': itm.unitPrice,
          'quantity': itm.qty,
          'qty': itm.qty,
          'total': itm.total,
          'priceFormatted': itm.unitPrice.toStringAsFixed(2),
          'totalFormatted': itm.total.toStringAsFixed(2),
        });
      }

      final double subtotal = _subtotal;
      final double sFee = _appliedServiceFee;
      final double dFee = _appliedDeliveryFee;
      final double newTotal = _finalTotal;
      final double oldTotal = (widget.order['transactionAmount'] as num?)?.toDouble() ??
          (widget.order['totalAmount'] as num?)?.toDouble() ??
          0.0;
      final double delta = (newTotal - oldTotal);

      final newStatus = _targetStatus;
      final bool needsApproval = (newStatus == 'awaiting_approval');

      batch.update(orderRef, {
        'bookingData.selectedItems': selectedItemsMap,
        'selectedItems': selectedItemsMap,
        'items': itemsList,
        'subtotal': subtotal,
        'serviceFee': sFee,
        'deliveryFee': dFee,
        'serviceFeeEnabled': _serviceFeeEnabled,
        'deliveryFeeEnabled': _deliveryFeeEnabled,
        'transactionAmount': newTotal,
        'totalAmount': newTotal,
        'finalAmount': newTotal,
        'pricing': {
          'subtotal': subtotal,
          'serviceFee': sFee,
          'deliveryFee': dFee,
          'estimated': oldTotal,
          'final': newTotal,
          'total': newTotal,
          'adjustment': delta,
        },
        'status': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
        if (needsApproval)
          'approval': {
            'status': 'pending',
            'amount': newTotal,
            'previousAmount': oldTotal,
            'requestedAt': FieldValue.serverTimestamp(),
            'notes': _notesCtrl.text.trim(),
          },
      });

      batch.set(orderRef.collection('intake').doc('main'), {
        'lines': itemsList,
        'totalItems': _totalCount,
        'totalPrice': newTotal,
        'notes': _notesCtrl.text.trim(),
        'updatedBy': 'admin',
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      final String historyNote = needsApproval
          ? 'Items counted at facility ($_totalCount item${_totalCount == 1 ? '' : 's'}) — New total £${newTotal.toStringAsFixed(2)}, waiting for your approval'
          : 'Items inspected & priced ($_totalCount item${_totalCount == 1 ? '' : 's'}) — Total £${newTotal.toStringAsFixed(2)}';

      batch.set(orderRef.collection('history').doc(), {
        'status': newStatus,
        'at': FieldValue.serverTimestamp(),
        'byRole': 'admin',
        'note': historyNote,
      });

      final String customerUid = (widget.order['userId'] ?? '').toString();
      if (customerUid.isNotEmpty && customerUid != 'website_guest' && customerUid != 'dummy') {
        final String displayId = (widget.order['orderId'] ?? '').toString();
        final String idTag = displayId.isNotEmpty ? '#$displayId' : 'your order';
        final notifRef = FirebaseFirestore.instance.collection('users').doc(customerUid).collection('notifications').doc();
        batch.set(notifRef, {
          'title': needsApproval ? 'Please approve your order' : 'Items inspected & priced',
          'body': needsApproval
              ? 'We counted $_totalCount item${_totalCount == 1 ? '' : 's'} for $idTag — new total £${newTotal.toStringAsFixed(2)}. Tap to review.'
              : '$_totalCount item${_totalCount == 1 ? '' : 's'} updated for $idTag — total £${newTotal.toStringAsFixed(2)}.',
          'category': 'orders',
          'theme': needsApproval ? 'amber' : 'violet',
          'icon': needsApproval ? 'pending_actions' : 'warehouse',
          'orderId': widget.order['id'],
          'displayOrderId': displayId,
          'status': newStatus,
          'read': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();

      // Automated Free Resend Email for bill update approval
      if (needsApproval || newStatus == 'awaiting_approval') {
        final updatedOrder = Map<String, dynamic>.from(widget.order);
        updatedOrder['countedItems'] = itemsList;
        updatedOrder['subtotal'] = subtotal;
        updatedOrder['totalAmount'] = newTotal;
        ResendEmailService.instance.sendBillApprovalEmail(updatedOrder);
      }

      if (!mounted) return;
      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Order #${widget.order['orderId']} updated: $_totalCount items, £${newTotal.toStringAsFixed(2)}'),
          backgroundColor: _P.azure,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving items: $e'),
          backgroundColor: _P.rose,
        ),
      );
    }
  }

  // ── UI helpers (design only) ────────────────────────────────────────────────

  Widget _buildCatalogPicker(bool isMobile, List<Map<String, dynamic>> categoryItems) {
    final categoryField = DropdownButtonFormField<String>(
      value: _selectedCategory,
      decoration: _inputDeco(label: 'Service Category'),
      style: _T.body(13, c: _P.textPrimary),
      isExpanded: true,
      dropdownColor: _P.card,
      borderRadius: BorderRadius.circular(12),
      items: _catalog.map((c) {
        final name = '${c['name'] ?? c['title'] ?? 'Category'}';
        return DropdownMenuItem(value: name, child: Text(name));
      }).toList(),
      onChanged: (cat) {
        if (cat == null) return;
        setState(() {
          _selectedCategory = cat;
          final catDoc = _catalog.firstWhere((c) => (c['name'] ?? c['title']) == cat);
          final itms = (catDoc['items'] as List?)?.cast<Map>() ?? [];
          _selectedCatalogItem = itms.isNotEmpty ? Map<String, dynamic>.from(itms.first) : null;
        });
      },
    );

    final itemField = DropdownButtonFormField<Map<String, dynamic>>(
      value: _selectedCatalogItem,
      decoration: _inputDeco(label: 'Item / Garment'),
      style: _T.body(13, c: _P.textPrimary),
      isExpanded: true,
      dropdownColor: _P.card,
      borderRadius: BorderRadius.circular(12),
      items: categoryItems.map((itm) {
        final name = '${itm['name'] ?? 'Item'}';
        final p = itm['price'] != null ? ' - £${itm['price']}' : '';
        return DropdownMenuItem(value: itm, child: Text('$name$p', overflow: TextOverflow.ellipsis));
      }).toList(),
      onChanged: (itm) => setState(() => _selectedCatalogItem = itm),
    );

    final addBtn = ElevatedButton.icon(
      onPressed: _addFromCatalog,
      icon: const Icon(Icons.add_rounded, size: 18),
      label: const Text('Add'),
      style: _primaryBtn(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        minimumSize: const Size(0, 46),
      ),
    );

    return Container(
      padding: EdgeInsets.all(isMobile ? 12 : 14),
      decoration: _cardDeco(radius: 14, shadow: false),
      child: isMobile
          ? Column(
              children: [
                categoryField,
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: itemField),
                    const SizedBox(width: 8),
                    addBtn,
                  ],
                ),
              ],
            )
          : Row(
              children: [
                Expanded(flex: 2, child: categoryField),
                const SizedBox(width: 10),
                Expanded(flex: 3, child: itemField),
                const SizedBox(width: 10),
                addBtn,
              ],
            ),
    );
  }

  Widget _buildCustomItemCard(bool isMobile) {
    final categoryField = DropdownButtonFormField<String>(
      value: _customCategory,
      decoration: _inputDeco(label: 'Category'),
      style: _T.body(13, c: _P.textPrimary),
      isExpanded: true,
      dropdownColor: _P.card,
      borderRadius: BorderRadius.circular(12),
      items: const [
        DropdownMenuItem(value: 'Dry Clean', child: Text('Dry Clean')),
        DropdownMenuItem(value: 'Wash & Fold', child: Text('Wash & Fold')),
        DropdownMenuItem(value: 'Ironing', child: Text('Ironing')),
        DropdownMenuItem(value: 'Bedding', child: Text('Bedding')),
        DropdownMenuItem(value: 'Repairs & Alterations', child: Text('Repairs & Alterations')),
        DropdownMenuItem(value: 'Leather & Suede', child: Text('Leather & Suede')),
        DropdownMenuItem(value: 'Custom Item', child: Text('Custom Item')),
      ],
      onChanged: (v) => setState(() => _customCategory = v ?? 'Dry Clean'),
    );

    final nameField = TextField(
      controller: _customNameCtrl,
      decoration: _inputDeco(hint: 'Garment name (e.g. Silk Cushion, Leather Jacket)'),
      style: _T.body(13, c: _P.textPrimary),
    );

    final priceField = TextField(
      controller: _customPriceCtrl,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: _inputDeco(prefix: '£ ', hint: isMobile ? 'Price (e.g. 15.00)' : 'Price'),
      style: _T.body(13, c: _P.textPrimary),
    );

    final addBtn = ElevatedButton.icon(
      onPressed: _addCustomItem,
      icon: const Icon(Icons.add_rounded, size: 17),
      label: const Text('Add Item'),
      style: _primaryBtn(
        bg: _P.navy,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        minimumSize: const Size(0, 46),
      ),
    );

    return Container(
      padding: EdgeInsets.all(isMobile ? 12 : 14),
      decoration: BoxDecoration(
        color: _P.surfaceAlt,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _P.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(color: _P.azureSoft, borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.playlist_add_rounded, size: 16, color: _P.azure),
              ),
              const SizedBox(width: 8),
              Text(
                'ADD CUSTOM / UNLISTED ITEM',
                style: _T.label(11, w: FontWeight.w800, c: _P.azure).copyWith(letterSpacing: 0.8),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (isMobile) ...[
            categoryField,
            const SizedBox(height: 10),
            nameField,
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: priceField),
                const SizedBox(width: 8),
                addBtn,
              ],
            ),
          ] else
            Row(
              children: [
                SizedBox(width: 180, child: categoryField),
                const SizedBox(width: 8),
                Expanded(flex: 3, child: nameField),
                const SizedBox(width: 8),
                Expanded(flex: 2, child: priceField),
                const SizedBox(width: 8),
                addBtn,
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildLineCard(int index, bool isMobile) {
    final line = _lines[index];

    final rateField = TextFormField(
      initialValue: line.unitPrice.toStringAsFixed(2),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: _inputDeco(
        prefix: '£',
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      ),
      style: _T.label(13, c: _P.textPrimary),
      onChanged: (val) {
        final parsed = _parsePrice(val);
        setState(() => line.unitPrice = parsed);
      },
    );

    final stepper = Container(
      decoration: BoxDecoration(
        color: _P.surfaceAlt,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _P.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.remove_rounded, size: 17),
            constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
            padding: EdgeInsets.zero,
            splashRadius: 18,
            onPressed: () {
              setState(() {
                if (line.qty > 1) {
                  line.qty--;
                } else {
                  _lines.removeAt(index);
                }
              });
            },
          ),
          Container(
            constraints: const BoxConstraints(minWidth: 28),
            alignment: Alignment.center,
            child: Text('${line.qty}', style: _T.money(14)),
          ),
          IconButton(
            icon: const Icon(Icons.add_rounded, size: 17),
            constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
            padding: EdgeInsets.zero,
            splashRadius: 18,
            onPressed: () => setState(() => line.qty++),
          ),
        ],
      ),
    );

    final deleteBtn = IconButton(
      onPressed: () => setState(() => _lines.removeAt(index)),
      tooltip: 'Remove item',
      splashRadius: 18,
      icon: const Icon(Icons.delete_outline_rounded, size: 20, color: _P.rose),
    );

    final nameBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          line.name,
          style: _T.heading(14),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 6),
        _Pill(label: line.category, color: _P.azure, bg: _P.azureSoft),
      ],
    );

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _cardDeco(radius: 14, shadow: false),
      child: isMobile
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: nameBlock),
                    const SizedBox(width: 8),
                    Text('£${line.total.toStringAsFixed(2)}', style: _T.money(16, w: FontWeight.w800, c: _P.emerald)),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(height: 1, color: _P.borderSoft),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Text('Rate', style: _T.body(11.5, c: _P.textMuted)),
                    const SizedBox(width: 8),
                    SizedBox(width: 84, child: rateField),
                    const SizedBox(width: 6),
                    Text('each', style: _T.body(11.5, c: _P.textMuted)),
                    const Spacer(),
                    stepper,
                    const SizedBox(width: 2),
                    deleteBtn,
                  ],
                ),
              ],
            )
          : Row(
              children: [
                Expanded(flex: 3, child: nameBlock),
                const SizedBox(width: 12),
                SizedBox(width: 96, child: rateField),
                const SizedBox(width: 12),
                stepper,
                const SizedBox(width: 14),
                SizedBox(
                  width: 76,
                  child: Text(
                    '£${line.total.toStringAsFixed(2)}',
                    textAlign: TextAlign.right,
                    style: _T.money(14.5, w: FontWeight.w800, c: _P.emerald),
                  ),
                ),
                deleteBtn,
              ],
            ),
    );
  }

  Widget _buildStatusOption({
    required String value,
    required String title,
    required String subtitle,
  }) {
    final selected = _targetStatus == value;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      decoration: BoxDecoration(
        color: selected ? _P.azureSoft.withOpacity(0.7) : _P.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: selected ? _P.azure : _P.border, width: selected ? 1.5 : 1),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: RadioListTile<String>(
          value: value,
          groupValue: _targetStatus,
          activeColor: _P.azure,
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          title: Text(title, style: _T.heading(13.5)),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(subtitle, style: _T.body(12, c: _P.textMuted)),
          ),
          onChanged: (v) => setState(() => _targetStatus = v!),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);
    final width = MediaQuery.sizeOf(context).width;
    final dialogWidth = isMobile ? width : (width > 800 ? 760.0 : width * 0.92);

    final oldTotal = (widget.order['transactionAmount'] as num?)?.toDouble() ??
        (widget.order['totalAmount'] as num?)?.toDouble() ??
        0.0;
    final delta = _finalTotal - oldTotal;

    List<Map<String, dynamic>> categoryItems = [];
    if (_catalog.isNotEmpty && _selectedCategory != null) {
      final catDoc = _catalog.firstWhere(
        (c) => (c['name'] ?? c['title']) == _selectedCategory,
        orElse: () => _catalog.first,
      );
      final rawList = catDoc['items'] as List?;
      if (rawList != null) {
        categoryItems = rawList.whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList();
      }
    }

    const diffUp = Color(0xFFFDB022);
    const diffDown = Color(0xFF47CD89);
    final diffColor = delta > 0 ? diffUp : diffDown;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: isMobile
          ? const EdgeInsets.symmetric(horizontal: 8, vertical: 12)
          : const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        width: dialogWidth,
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * (isMobile ? 0.96 : 0.90)),
        decoration: BoxDecoration(
          color: _P.canvas,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 48, offset: const Offset(0, 20)),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            // ── Header ──────────────────────────────────────────────────────────
            _DialogHeader(
              leading: Container(
                width: isMobile ? 40 : 46,
                height: isMobile ? 40 : 46,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF12A583), _P.azureDark],
                  ),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(Icons.inventory_2_rounded, color: Colors.white, size: isMobile ? 20 : 22),
              ),
              title: 'Itemize Order & Update Bill',
              subtitle:
                  'Order #${widget.order['orderId'] ?? widget.order['id']} · ${widget.bookingData['firstName'] ?? ''} ${widget.bookingData['lastName'] ?? ''}',
              compact: isMobile,
              onClose: _saving ? null : () => Navigator.of(context).pop(),
            ),

            // ── Body Scroll ──────────────────────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(isMobile ? 12 : 22, 18, isMobile ? 12 : 22, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Context strip
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: _cardDeco(radius: 14, shadow: false),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Original / Estimated Bill', style: _T.body(11.5, c: _P.textMuted)),
                                const SizedBox(height: 4),
                                Text('£${oldTotal.toStringAsFixed(2)}', style: _T.money(19)),
                              ],
                            ),
                          ),
                          Container(width: 1, height: 36, color: _P.border),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Current Status', style: _T.body(11.5, c: _P.textMuted)),
                                const SizedBox(height: 6),
                                _StatusBadge(status: _Status.of(widget.order['status'] ?? 'pending')),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Section: Add Items from Catalog
                    const _SectionTitle('ADD CLOTHES & SERVICES'),
                    const SizedBox(height: 10),

                    if (_loadingCatalog)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: CircularProgressIndicator(strokeWidth: 2.5, color: _P.azure),
                        ),
                      )
                    else if (_catalog.isNotEmpty)
                      _buildCatalogPicker(isMobile, categoryItems),

                    const SizedBox(height: 12),

                    // Quick Custom Item Row
                    _buildCustomItemCard(isMobile),

                    const SizedBox(height: 26),

                    // Section: Current Counted Clothes
                    _SectionTitle(
                      'BAG CONTENTS & COUNT ($_totalCount ITEMS)',
                      trailing: _lines.isNotEmpty
                          ? TextButton(
                              onPressed: () => setState(() => _lines.clear()),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: Text('Clear all', style: _T.label(12, w: FontWeight.w700, c: _P.rose)),
                            )
                          : null,
                    ),
                    const SizedBox(height: 10),

                    if (_lines.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
                        decoration: _cardDeco(radius: 14, shadow: false),
                        child: Column(
                          children: [
                            Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                color: _P.surfaceAlt,
                                shape: BoxShape.circle,
                                border: Border.all(color: _P.border),
                              ),
                              child: const Icon(Icons.inventory_2_outlined, size: 24, color: _P.textMuted),
                            ),
                            const SizedBox(height: 12),
                            Text('No items added yet', style: _T.heading(14, c: _P.textSecondary)),
                            const SizedBox(height: 4),
                            Text(
                              'Pick clothes from the service catalog above to itemize this bag.',
                              style: _T.body(12.5, c: _P.textMuted),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _lines.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) => _buildLineCard(index, isMobile),
                      ),

                    const SizedBox(height: 20),

                    // Bill Summary Card
                    Container(
                      padding: EdgeInsets.all(isMobile ? 16 : 20),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [_P.navy, _P.navyMid],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(color: _P.navy.withOpacity(0.25), blurRadius: 20, offset: const Offset(0, 8)),
                        ],
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'FINAL TOTAL BILL',
                                      style: _T.label(11, w: FontWeight.w700, c: const Color(0xFF9FB3C0)).copyWith(letterSpacing: 1),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '£${_finalTotal.toStringAsFixed(2)}',
                                      style: _T.money(isMobile ? 26 : 30, w: FontWeight.w800, c: Colors.white),
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: diffColor.withOpacity(0.16),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text(
                                      delta >= 0 ? '+£${delta.toStringAsFixed(2)} diff' : '-£${delta.abs().toStringAsFixed(2)} diff',
                                      style: _T.label(12, w: FontWeight.w700, c: diffColor),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    '$_totalCount total garment(s)',
                                    style: _T.body(11.5, c: const Color(0xFF9FB3C0)),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          const Divider(height: 1, color: Color(0x33FFFFFF)),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Garments Subtotal', style: _T.body(12, c: const Color(0xFFCAD5DE))),
                              Text('£${_subtotal.toStringAsFixed(2)}', style: _T.label(12, w: FontWeight.w700, c: Colors.white)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Service Fee', style: _T.body(12, c: const Color(0xFFCAD5DE))),
                              Text(
                                _serviceFeeEnabled ? '£${_serviceFee.toStringAsFixed(2)}' : 'Free / Disabled',
                                style: _T.label(12, w: FontWeight.w700, c: _serviceFeeEnabled ? Colors.white : const Color(0xFF47CD89)),
                              ),
                            ],
                          ),
                          if (_deliveryFeeEnabled && _deliveryFee > 0) ...[
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Delivery Fee', style: _T.body(12, c: const Color(0xFFCAD5DE))),
                                Text('£${_deliveryFee.toStringAsFixed(2)}', style: _T.label(12, w: FontWeight.w700, c: Colors.white)),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(height: 26),

                    // Target Status Selection
                    const _SectionTitle('ORDER STATUS & CUSTOMER ACTION'),
                    const SizedBox(height: 10),

                    _buildStatusOption(
                      value: 'awaiting_approval',
                      title: 'Require Customer Approval (Recommended)',
                      subtitle: 'Customer sees "Approve Changes" card on website & app to confirm new bill.',
                    ),
                    const SizedBox(height: 8),
                    _buildStatusOption(
                      value: 'cleaning',
                      title: 'Start Cleaning Directly (No Approval Required)',
                      subtitle: 'Moves order directly into cleaning queue at the facility.',
                    ),

                    const SizedBox(height: 16),

                    // Inspector Note
                    TextField(
                      controller: _notesCtrl,
                      decoration: _inputDeco(
                        label: 'Facility Inspector Note (Optional)',
                        hint: 'e.g. 3 shirts washed & ironed, suit dry cleaned. Ready tomorrow.',
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                      ),
                      style: _T.body(13, c: _P.textPrimary),
                    ),
                  ],
                ),
              ),
            ),

            // ── Footer ──────────────────────────────────────────────────────────
            Container(
              padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 22, vertical: isMobile ? 10 : 14),
              decoration: const BoxDecoration(
                color: _P.card,
                border: Border(top: BorderSide(color: _P.border)),
              ),
              child: Row(
                children: [
                  TextButton(
                    onPressed: _saving ? null : () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: Text('Cancel', style: _T.label(13, w: FontWeight.w700, c: _P.textSecondary)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _saving ? null : _saveAndSync,
                      icon: _saving
                          ? const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.check_circle_rounded, size: 17),
                      label: Text(
                        _saving ? 'Saving...' : 'Save & Update Bill (£${_finalTotal.toStringAsFixed(2)})',
                        overflow: TextOverflow.ellipsis,
                      ),
                      style: _primaryBtn(
                        padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 20, vertical: 14),
                        fontSize: isMobile ? 12.5 : 13.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
