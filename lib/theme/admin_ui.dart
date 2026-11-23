import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// DryClean Plus — admin console design system.
/// Brand: forest #073B1B · emerald #059669 · mint #ECFDF5 · gold #FDE047.
class AC {
  // brand
  static const forest = Color(0xFF073B1B);
  static const forest2 = Color(0xFF0B5A2B);
  static const deep = Color(0xFF04210F);
  static const emerald = Color(0xFF059669);
  static const emerald7 = Color(0xFF047857);
  static const mint = Color(0xFFECFDF5);
  static const mint2 = Color(0xFFD1FAE5);
  static const gold = Color(0xFFFDE047);
  static const gold2 = Color(0xFFFACC15);

  // surfaces
  static const canvas = Color(0xFFF5F7F5);
  static const surface = Colors.white;
  static const subtle = Color(0xFFF8FAF9);
  static const border = Color(0xFFE5E9E7);
  static const borderStrong = Color(0xFFD4DAD7);

  // text
  static const ink = Color(0xFF0F172A);
  static const ink2 = Color(0xFF334155);
  static const mut = Color(0xFF64748B);
  static const faint = Color(0xFF94A3B8);

  // semantic
  static const success = Color(0xFF059669), successBg = Color(0xFFECFDF5);
  static const warning = Color(0xFFB45309), warningBg = Color(0xFFFFFBEB);
  static const danger = Color(0xFFDC2626), dangerBg = Color(0xFFFEF2F2);
  static const info = Color(0xFF2563EB), infoBg = Color(0xFFEFF6FF);
  static const violet = Color(0xFF7C3AED), violetBg = Color(0xFFF5F3FF);

  static const radius = 16.0;

  static TextStyle h(double s, {Color c = ink, FontWeight w = FontWeight.w800}) =>
      GoogleFonts.plusJakartaSans(fontSize: s, fontWeight: w, color: c, letterSpacing: -.3, height: 1.2);
  static TextStyle t(double s, {Color c = ink, FontWeight w = FontWeight.w500, double? height}) =>
      GoogleFonts.plusJakartaSans(fontSize: s, fontWeight: w, color: c, height: height);
  static TextStyle num(double s, {Color c = ink}) =>
      GoogleFonts.plusJakartaSans(fontSize: s, fontWeight: FontWeight.w800, color: c, letterSpacing: -.6, fontFeatures: const [FontFeature.tabularFigures()]);
  static TextStyle label({Color c = mut}) => GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w800, color: c, letterSpacing: 1.1);

  static List<BoxShadow> shadow([double o = .06]) => [
        BoxShadow(color: forest.withValues(alpha: o), blurRadius: 24, offset: const Offset(0, 10), spreadRadius: -10),
      ];
}

ThemeData buildAdminTheme() {
  final base = ThemeData(useMaterial3: true, brightness: Brightness.light);
  final text = GoogleFonts.plusJakartaSansTextTheme(base.textTheme).apply(bodyColor: AC.ink, displayColor: AC.ink);
  final scheme = ColorScheme.fromSeed(seedColor: AC.emerald, brightness: Brightness.light).copyWith(
    primary: AC.forest,
    onPrimary: Colors.white,
    secondary: AC.emerald,
    onSecondary: Colors.white,
    tertiary: AC.gold,
    surface: AC.surface,
    onSurface: AC.ink,
    surfaceContainerHighest: AC.subtle,
    outline: AC.border,
    outlineVariant: AC.border,
    error: AC.danger,
  );
  final radius12 = BorderRadius.circular(12);
  OutlineInputBorder ob(Color c, [double w = 1]) => OutlineInputBorder(borderRadius: radius12, borderSide: BorderSide(color: c, width: w));
  const btnSize = Size(0, 46);
  final btnShape = RoundedRectangleBorder(borderRadius: radius12);
  final btnText = GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w700);

  return base.copyWith(
    colorScheme: scheme,
    textTheme: text,
    scaffoldBackgroundColor: AC.canvas,
    canvasColor: AC.surface,
    dividerColor: AC.border,
    splashFactory: InkSparkle.splashFactory,
    visualDensity: VisualDensity.standard,
    dividerTheme: const DividerThemeData(color: AC.border, thickness: 1, space: 1),
    cardTheme: CardThemeData(
      color: AC.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AC.radius), side: const BorderSide(color: AC.border)),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: AC.surface,
      foregroundColor: AC.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: AC.h(18),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AC.surface,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      hintStyle: AC.t(14, c: AC.faint),
      labelStyle: AC.t(14, c: AC.mut),
      floatingLabelStyle: AC.t(13, c: AC.emerald7, w: FontWeight.w700),
      prefixIconColor: AC.faint,
      border: ob(AC.border),
      enabledBorder: ob(AC.border),
      focusedBorder: ob(AC.emerald, 1.6),
      errorBorder: ob(AC.danger),
      focusedErrorBorder: ob(AC.danger, 1.6),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(backgroundColor: AC.forest, foregroundColor: Colors.white, minimumSize: btnSize, padding: const EdgeInsets.symmetric(horizontal: 18), shape: btnShape, textStyle: btnText),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(backgroundColor: AC.forest, foregroundColor: Colors.white, elevation: 0, minimumSize: btnSize, padding: const EdgeInsets.symmetric(horizontal: 18), shape: btnShape, textStyle: btnText),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(foregroundColor: AC.ink, side: const BorderSide(color: AC.borderStrong), minimumSize: btnSize, padding: const EdgeInsets.symmetric(horizontal: 16), shape: btnShape, textStyle: btnText),
    ),
    textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(foregroundColor: AC.emerald7, textStyle: btnText, shape: btnShape)),
    iconButtonTheme: IconButtonThemeData(style: IconButton.styleFrom(foregroundColor: AC.ink2)),
    chipTheme: ChipThemeData(
      backgroundColor: AC.surface,
      selectedColor: AC.mint,
      side: const BorderSide(color: AC.border),
      labelStyle: AC.t(13, w: FontWeight.w600),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      checkmarkColor: AC.emerald7,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: AC.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      titleTextStyle: AC.h(20),
      contentTextStyle: AC.t(14, c: AC.ink2),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AC.ink,
      contentTextStyle: AC.t(14, c: Colors.white, w: FontWeight.w600),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    tooltipTheme: TooltipThemeData(decoration: BoxDecoration(color: AC.ink, borderRadius: BorderRadius.circular(8)), textStyle: AC.t(12, c: Colors.white, w: FontWeight.w600)),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? Colors.white : AC.faint),
      trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? AC.emerald : AC.border),
      trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
    ),
    checkboxTheme: CheckboxThemeData(fillColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? AC.emerald : null), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5))),
    tabBarTheme: TabBarThemeData(
      labelColor: AC.forest,
      unselectedLabelColor: AC.mut,
      labelStyle: AC.t(14, w: FontWeight.w800),
      unselectedLabelStyle: AC.t(14, w: FontWeight.w600),
      indicatorColor: AC.emerald,
      dividerColor: AC.border,
    ),
    popupMenuTheme: PopupMenuThemeData(color: AC.surface, surfaceTintColor: Colors.transparent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: AC.border)), textStyle: AC.t(14)),
    dataTableTheme: DataTableThemeData(
      headingTextStyle: AC.label(),
      dataTextStyle: AC.t(14),
      headingRowColor: WidgetStateProperty.all(AC.subtle),
      dividerThickness: 1,
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: AC.emerald, linearTrackColor: AC.mint),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(backgroundColor: AC.forest, foregroundColor: Colors.white),
    listTileTheme: ListTileThemeData(iconColor: AC.mut, titleTextStyle: AC.t(14, w: FontWeight.w700), subtitleTextStyle: AC.t(13, c: AC.mut)),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? AC.mint : AC.surface),
        foregroundColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? AC.forest : AC.ink2),
        side: WidgetStateProperty.all(const BorderSide(color: AC.border)),
        textStyle: WidgetStateProperty.all(AC.t(13, w: FontWeight.w700)),
      ),
    ),
  );
}

// ============================================================ building blocks

/// Standard page: title row (with optional actions) + scrollable content.
class AdminPage extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget> actions;
  final Widget child;
  final bool scroll;
  final EdgeInsets padding;
  const AdminPage({super.key, required this.title, this.subtitle, this.actions = const [], required this.child, this.scroll = true, this.padding = const EdgeInsets.fromLTRB(28, 24, 28, 32)});

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < 700;
    final pad = narrow ? const EdgeInsets.fromLTRB(16, 16, 16, 24) : padding;
    final head = Wrap(
      spacing: 16,
      runSpacing: 12,
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text(title, style: AC.h(narrow ? 22 : 26)),
            if (subtitle != null) ...[const SizedBox(height: 4), Text(subtitle!, style: AC.t(14, c: AC.mut))],
          ]),
        ),
        if (actions.isNotEmpty) Wrap(spacing: 10, runSpacing: 10, children: actions),
      ],
    );
    if (!scroll) {
      return Padding(padding: pad, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [head, const SizedBox(height: 20), Expanded(child: child)]));
    }
    return ListView(padding: pad, children: [head, const SizedBox(height: 20), child]);
  }
}

class SurfaceCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final String? title;
  final String? subtitle;
  final Widget? trailing;
  const SurfaceCard({super.key, required this.child, this.padding = const EdgeInsets.all(20), this.title, this.subtitle, this.trailing});

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(color: AC.surface, borderRadius: BorderRadius.circular(AC.radius), border: Border.all(color: AC.border), boxShadow: AC.shadow(.04)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
          if (title != null)
            Padding(
              padding: EdgeInsets.fromLTRB(padding.left, 18, padding.right, 0),
              child: Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(title!, style: AC.h(16)),
                    if (subtitle != null) Padding(padding: const EdgeInsets.only(top: 3), child: Text(subtitle!, style: AC.t(13, c: AC.mut))),
                  ]),
                ),
                if (trailing != null) trailing!,
              ]),
            ),
          Padding(padding: padding, child: child),
        ]),
      );
}

class KpiCard extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final String? delta;
  final bool up;
  final Color tone, toneBg;
  const KpiCard({super.key, required this.icon, required this.label, required this.value, this.delta, this.up = true, this.tone = AC.emerald, this.toneBg = AC.mint});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(color: AC.surface, borderRadius: BorderRadius.circular(AC.radius), border: Border.all(color: AC.border), boxShadow: AC.shadow(.04)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(width: 36, height: 36, decoration: BoxDecoration(color: toneBg, borderRadius: BorderRadius.circular(10)), child: Icon(icon, size: 19, color: tone)),
            const SizedBox(width: 10),
            Expanded(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: AC.t(13, c: AC.mut, w: FontWeight.w600))),
          ]),
          const SizedBox(height: 14),
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Flexible(child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(value, style: AC.num(28)))),
            if (delta != null) ...[
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(up ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded, size: 13, color: up ? AC.success : AC.danger),
                  Text(delta!, style: AC.t(12, c: up ? AC.success : AC.danger, w: FontWeight.w800)),
                ]),
              ),
            ],
          ]),
        ]),
      );
}

class StatusPill extends StatelessWidget {
  final String text;
  final Color c, bg;
  final IconData? icon;
  const StatusPill(this.text, {super.key, this.c = AC.emerald7, this.bg = AC.mint, this.icon});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(99)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[Icon(icon, size: 13, color: c), const SizedBox(width: 4)],
          Text(text, style: AC.t(12, c: c, w: FontWeight.w800)),
        ]),
      );
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title, text;
  final Widget? action;
  const EmptyState({super.key, required this.icon, required this.title, required this.text, this.action});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 60, height: 60, decoration: BoxDecoration(color: AC.mint, borderRadius: BorderRadius.circular(18)), child: Icon(icon, color: AC.emerald7, size: 28)),
          const SizedBox(height: 14),
          Text(title, style: AC.h(17)),
          const SizedBox(height: 4),
          Text(text, textAlign: TextAlign.center, style: AC.t(13.5, c: AC.mut)),
          if (action != null) ...[const SizedBox(height: 16), action!],
        ]),
      );
}

/// Labelled form row used on settings-style pages.
class FieldRow extends StatelessWidget {
  final String label;
  final String? help;
  final Widget child;
  const FieldRow({super.key, required this.label, this.help, required this.child});
  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final l = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: AC.t(14, w: FontWeight.w700)),
      if (help != null) Padding(padding: const EdgeInsets.only(top: 3), child: Text(help!, style: AC.t(12.5, c: AC.mut))),
    ]);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: wide
          ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [SizedBox(width: 260, child: l), const SizedBox(width: 24), Expanded(child: child)])
          : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [l, const SizedBox(height: 8), child]),
    );
  }
}

/// Ask the console shell to open a page by its menu label (e.g. 'Orders', 'Dispatch').
final adminNavRequest = ValueNotifier<String?>(null);
void openAdminPage(String label) {
  adminNavRequest.value = null;
  adminNavRequest.value = label;
}

void adminToast(BuildContext context, String msg) => ScaffoldMessenger.of(context)
  ..hideCurrentSnackBar()
  ..showSnackBar(SnackBar(content: Text(msg)));
