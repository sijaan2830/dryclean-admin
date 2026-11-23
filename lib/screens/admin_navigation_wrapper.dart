import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../providers/firebase_auth_provider.dart';
import '../theme/admin_ui.dart';
import 'analytics_screen_realtime.dart';
import 'customers_screen_realtime.dart';
import 'dashboard_screen_realtime.dart';
import 'dispatch_screen_realtime.dart';
import 'login_screen.dart';
import 'notices_screen.dart';
import 'offers_screen_realtime.dart';
import 'orders_screen_realtime.dart';
import 'prepaid_packs_screen_realtime.dart';
import 'services_screen_realtime.dart';
import 'settings_screen_realtime.dart';
import 'timeslots_screen_realtime.dart';
import 'website_settings_screen.dart';

/// One entry in the console navigation.
class NavigationItem {
  final IconData icon, activeIcon;
  final String label, group;
  final String? badgeKey;
  final Widget Function() build;
  const NavigationItem({required this.icon, required this.activeIcon, required this.label, required this.group, required this.build, this.badgeKey});
}

final List<NavigationItem> kAdminNav = [
  NavigationItem(icon: Icons.space_dashboard_outlined, activeIcon: Icons.space_dashboard_rounded, label: 'Dashboard', group: 'Overview', build: () => const DashboardScreenRealtime()),
  NavigationItem(icon: Icons.insights_outlined, activeIcon: Icons.insights_rounded, label: 'Analytics', group: 'Overview', build: () => const AnalyticsScreenRealtime()),
  NavigationItem(icon: Icons.receipt_long_outlined, activeIcon: Icons.receipt_long_rounded, label: 'Orders', group: 'Operations', badgeKey: 'orders', build: () => const OrdersScreenRealtime()),
  NavigationItem(icon: Icons.local_shipping_outlined, activeIcon: Icons.local_shipping_rounded, label: 'Dispatch', group: 'Operations', badgeKey: 'dispatch', build: () => const DispatchScreenRealtime()),
  NavigationItem(icon: Icons.people_outline_rounded, activeIcon: Icons.people_rounded, label: 'Customers', group: 'Operations', build: () => const CustomersScreen()),
  NavigationItem(icon: Icons.sell_outlined, activeIcon: Icons.sell_rounded, label: 'Services & prices', group: 'Catalogue', build: () => const ServicesScreenRealtime()),
  NavigationItem(icon: Icons.inventory_2_outlined, activeIcon: Icons.inventory_2_rounded, label: 'Prepaid packs', group: 'Catalogue', build: () => const PrepaidPacksScreenRealtime()),
  NavigationItem(icon: Icons.local_offer_outlined, activeIcon: Icons.local_offer_rounded, label: 'Offers', group: 'Catalogue', build: () => const OffersScreenRealtime()),
  NavigationItem(icon: Icons.schedule_outlined, activeIcon: Icons.schedule_rounded, label: 'Time slots', group: 'Catalogue', build: () => const TimeslotsScreenRealtime()),
  NavigationItem(icon: Icons.campaign_outlined, activeIcon: Icons.campaign_rounded, label: 'Notices', group: 'Website', badgeKey: 'notices', build: () => const NoticesScreen()),
  NavigationItem(icon: Icons.language_outlined, activeIcon: Icons.language_rounded, label: 'Website settings', group: 'Website', build: () => const WebsiteSettingsScreen()),
  NavigationItem(icon: Icons.settings_outlined, activeIcon: Icons.settings_rounded, label: 'App settings', group: 'System', build: () => const SettingsScreenRealtime()),
];

class AdminNavigationWrapper extends StatefulWidget {
  const AdminNavigationWrapper({super.key});
  @override
  State<AdminNavigationWrapper> createState() => _AdminNavigationWrapperState();
}

class _AdminNavigationWrapperState extends State<AdminNavigationWrapper> {
  int _index = 0;
  bool _collapsed = false;
  final _scaffold = GlobalKey<ScaffoldState>();
  final _db = FirebaseFirestore.instance;
  late final List<Widget> _pages;

  // live counters for the sidebar badges
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _attention = _db
      .collection('orders')
      .where('status', whereIn: ['pending', 'confirmed', 'awaiting_approval', 'pickup_failed', 'delivery_failed', 'ready_for_delivery'])
      .snapshots();
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _notices = _db.collection('notices').where('isActive', isEqualTo: true).snapshots();
  late final Stream<DocumentSnapshot<Map<String, dynamic>>> _site = _db.collection('settings').doc('website').snapshots();

  @override
  void initState() {
    super.initState();
    _pages = kAdminNav.map((item) => item.build()).toList();
    adminNavRequest.addListener(_onNavRequest);
  }

  @override
  void dispose() {
    adminNavRequest.removeListener(_onNavRequest);
    super.dispose();
  }

  void _onNavRequest() {
    final label = adminNavRequest.value;
    if (label == null) return;
    final i = kAdminNav.indexWhere((e) => e.label == label);
    if (i >= 0 && mounted) setState(() => _index = i);
  }

  void _go(int i) {
    setState(() => _index = i);
    if (_scaffold.currentState?.isDrawerOpen ?? false) Navigator.of(context).pop();
  }

  Future<void> _signOut() async {
    await context.read<FirebaseAuthProvider>().signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const LoginScreen()), (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    final desktop = w >= 1100;
    final item = kAdminNav[_index];
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _attention,
      builder: (context, a) {
        final docs = a.data?.docs ?? const [];
        int count(Set<String> s) => docs.where((d) => s.contains(d.data()['status'])).length;
        final badges = <String, int>{
          'orders': count({'pending', 'confirmed', 'awaiting_approval'}),
          'dispatch': count({'pending', 'confirmed', 'pickup_failed', 'delivery_failed', 'ready_for_delivery'}),
        };
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _notices,
          builder: (context, n) {
            badges['notices'] = n.data?.size ?? 0;
            final sidebar = _Sidebar(
              index: _index,
              collapsed: desktop && _collapsed,
              badges: badges,
              email: context.watch<FirebaseAuthProvider>().user?.email ?? 'Admin',
              onTap: _go,
              onToggle: desktop ? () => setState(() => _collapsed = !_collapsed) : null,
              onSignOut: _signOut,
            );
            return Scaffold(
              key: _scaffold,
              backgroundColor: AC.canvas,
              drawer: desktop ? null : Drawer(width: 284, backgroundColor: AC.deep, shape: const RoundedRectangleBorder(), child: sidebar),
              body: Row(children: [
                if (desktop) sidebar,
                Expanded(
                  child: Column(children: [
                    StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                      stream: _site,
                      builder: (context, s) => _TopBar(
                        item: item,
                        desktop: desktop,
                        attention: badges['orders'] ?? 0,
                        siteUrl: '${s.data?.data()?['siteUrl'] ?? ''}',
                        bookingsOpen: s.data?.data()?['bookingsOpen'] != false,
                        email: context.watch<FirebaseAuthProvider>().user?.email ?? 'Admin',
                        onMenu: () => _scaffold.currentState?.openDrawer(),
                        onAttention: () => _go(kAdminNav.indexWhere((e) => e.label == 'Orders')),
                        onWebsite: () => _go(kAdminNav.indexWhere((e) => e.label == 'Website settings')),
                        onSignOut: _signOut,
                      ),
                    ),
                    Expanded(
                      child: IndexedStack(
                        index: _index,
                        children: _pages,
                      ),
                    ),
                  ]),
                ),
              ]),
            );
          },
        );
      },
    );
  }
}

// ================================================================ sidebar
class _Sidebar extends StatelessWidget {
  final int index;
  final bool collapsed;
  final Map<String, int> badges;
  final String email;
  final ValueChanged<int> onTap;
  final VoidCallback? onToggle;
  final VoidCallback onSignOut;
  const _Sidebar({required this.index, required this.collapsed, required this.badges, required this.email, required this.onTap, required this.onToggle, required this.onSignOut});

  @override
  Widget build(BuildContext context) {
    final groups = <String>[];
    for (final n in kAdminNav) {
      if (!groups.contains(n.group)) groups.add(n.group);
    }
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      width: collapsed ? 78 : 264,
      decoration: const BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [AC.forest, AC.deep]),
      ),
      child: SafeArea(
        right: false,
        child: Column(children: [
          // brand
          Padding(
            padding: EdgeInsets.fromLTRB(collapsed ? 17 : 20, 20, collapsed ? 17 : 16, 18),
            child: Row(children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(color: AC.gold, borderRadius: BorderRadius.circular(13)),
                alignment: Alignment.center,
                child: Text('DC+', style: AC.h(14, c: AC.forest)),
              ),
              if (!collapsed) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('DryClean Plus', style: AC.h(15.5, c: Colors.white)),
                    Text('Admin console', style: AC.t(12, c: AC.mint2.withValues(alpha: .75), w: FontWeight.w600)),
                  ]),
                ),
              ],
            ]),
          ),
          Expanded(
            child: ListView(padding: EdgeInsets.symmetric(horizontal: collapsed ? 12 : 14), children: [
              for (final g in groups) ...[
                if (!collapsed)
                  Padding(padding: const EdgeInsets.fromLTRB(10, 16, 10, 8), child: Text(g.toUpperCase(), style: AC.label(c: Colors.white.withValues(alpha: .42))))
                else
                  Padding(padding: const EdgeInsets.symmetric(vertical: 10), child: Divider(color: Colors.white.withValues(alpha: .1), height: 1)),
                for (var i = 0; i < kAdminNav.length; i++)
                  if (kAdminNav[i].group == g) _NavTile(item: kAdminNav[i], selected: i == index, collapsed: collapsed, badge: badges[kAdminNav[i].badgeKey] ?? 0, onTap: () => onTap(i)),
              ],
              const SizedBox(height: 12),
            ]),
          ),
          // account
          Container(
            margin: EdgeInsets.fromLTRB(collapsed ? 12 : 14, 8, collapsed ? 12 : 14, 14),
            padding: EdgeInsets.all(collapsed ? 6 : 10),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: .06), borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.white.withValues(alpha: .08))),
            child: collapsed
                ? Column(children: [
                    IconButton(tooltip: 'Expand', onPressed: onToggle, icon: const Icon(Icons.keyboard_double_arrow_right_rounded, color: Colors.white70)),
                    IconButton(tooltip: 'Sign out', onPressed: onSignOut, icon: const Icon(Icons.logout_rounded, color: Colors.white70)),
                  ])
                : Row(children: [
                    CircleAvatar(radius: 17, backgroundColor: AC.emerald, child: Text(email.isEmpty ? 'A' : email[0].toUpperCase(), style: AC.h(14, c: Colors.white))),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Administrator', style: AC.t(12.5, c: Colors.white, w: FontWeight.w700)),
                        Text(email, maxLines: 1, overflow: TextOverflow.ellipsis, style: AC.t(11.5, c: Colors.white.withValues(alpha: .6))),
                      ]),
                    ),
                    if (onToggle != null) IconButton(tooltip: 'Collapse', visualDensity: VisualDensity.compact, onPressed: onToggle, icon: const Icon(Icons.keyboard_double_arrow_left_rounded, color: Colors.white60, size: 20)),
                    IconButton(tooltip: 'Sign out', visualDensity: VisualDensity.compact, onPressed: onSignOut, icon: const Icon(Icons.logout_rounded, color: Colors.white60, size: 19)),
                  ]),
          ),
        ]),
      ),
    );
  }
}

class _NavTile extends StatefulWidget {
  final NavigationItem item;
  final bool selected, collapsed;
  final int badge;
  final VoidCallback onTap;
  const _NavTile({required this.item, required this.selected, required this.collapsed, required this.badge, required this.onTap});
  @override
  State<_NavTile> createState() => _NavTileState();
}

class _NavTileState extends State<_NavTile> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    final s = widget.selected;
    final tile = MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          margin: const EdgeInsets.only(bottom: 3),
          height: 42,
          padding: EdgeInsets.symmetric(horizontal: widget.collapsed ? 0 : 10),
          decoration: BoxDecoration(
            color: s ? Colors.white.withValues(alpha: .12) : (_hover ? Colors.white.withValues(alpha: .06) : Colors.transparent),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Row(mainAxisAlignment: widget.collapsed ? MainAxisAlignment.center : MainAxisAlignment.start, children: [
            if (!widget.collapsed)
              AnimatedContainer(duration: const Duration(milliseconds: 160), width: 3, height: s ? 18 : 0, margin: const EdgeInsets.only(right: 9), decoration: BoxDecoration(color: AC.gold, borderRadius: BorderRadius.circular(2))),
            Stack(clipBehavior: Clip.none, children: [
              Icon(s ? widget.item.activeIcon : widget.item.icon, size: 20, color: s ? AC.gold : Colors.white.withValues(alpha: .72)),
              if (widget.collapsed && widget.badge > 0) Positioned(right: -4, top: -3, child: Container(width: 9, height: 9, decoration: BoxDecoration(color: AC.gold, shape: BoxShape.circle, border: Border.all(color: AC.forest, width: 1.5)))),
            ]),
            if (!widget.collapsed) ...[
              const SizedBox(width: 12),
              Expanded(child: Text(widget.item.label, style: AC.t(14, c: s ? Colors.white : Colors.white.withValues(alpha: .78), w: s ? FontWeight.w800 : FontWeight.w600))),
              if (widget.badge > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(color: s ? AC.gold : Colors.white.withValues(alpha: .14), borderRadius: BorderRadius.circular(99)),
                  child: Text('${widget.badge}', style: AC.t(11.5, c: s ? AC.forest : Colors.white, w: FontWeight.w800)),
                ),
            ],
          ]),
        ),
      ),
    );
    return widget.collapsed ? Tooltip(message: widget.item.label, preferBelow: false, child: tile) : tile;
  }
}

// ================================================================ top bar
class _TopBar extends StatelessWidget {
  final NavigationItem item;
  final bool desktop, bookingsOpen;
  final int attention;
  final String siteUrl, email;
  final VoidCallback onMenu, onAttention, onWebsite, onSignOut;
  const _TopBar({
    required this.item,
    required this.desktop,
    required this.attention,
    required this.siteUrl,
    required this.bookingsOpen,
    required this.email,
    required this.onMenu,
    required this.onAttention,
    required this.onWebsite,
    required this.onSignOut,
  });

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    final narrow = w < 640;
    final isPhone = w < 480;
    return Container(
      height: 64,
      padding: EdgeInsets.symmetric(horizontal: desktop ? 28 : (isPhone ? 8 : 14)),
      decoration: const BoxDecoration(color: AC.surface, border: Border(bottom: BorderSide(color: AC.border))),
      child: Row(children: [
        if (!desktop)
          IconButton(
            onPressed: onMenu,
            icon: const Icon(Icons.menu_rounded),
            padding: isPhone ? EdgeInsets.zero : const EdgeInsets.all(8),
            constraints: isPhone ? const BoxConstraints(minWidth: 36, minHeight: 36) : null,
          ),
        if (!desktop && isPhone) const SizedBox(width: 4),
        Expanded(
          child: Row(children: [
            if (!narrow) ...[
              Text(item.group, style: AC.t(14, c: AC.mut, w: FontWeight.w600)),
              const Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Icon(Icons.chevron_right_rounded, size: 18, color: AC.faint)),
            ],
            Flexible(child: Text(item.label, overflow: TextOverflow.ellipsis, style: AC.t(isPhone ? 14 : 14.5, w: FontWeight.w800))),
          ]),
        ),
        if (!bookingsOpen)
          Padding(
            padding: EdgeInsets.only(right: isPhone ? 6 : 10),
            child: Tooltip(
              message: 'New bookings are paused on the website',
              child: InkWell(
                onTap: onWebsite,
                borderRadius: BorderRadius.circular(99),
                child: isPhone
                    ? Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(color: AC.dangerBg, shape: BoxShape.circle, border: Border.all(color: const Color(0xFFFECACA))),
                        child: const Icon(Icons.pause_rounded, size: 14, color: AC.danger),
                      )
                    : const StatusPill('Bookings paused', c: AC.danger, bg: AC.dangerBg, icon: Icons.pause_circle_rounded),
              ),
            ),
          ),
        InkWell(
          onTap: onAttention,
          borderRadius: BorderRadius.circular(99),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: isPhone ? 8 : 12, vertical: isPhone ? 5 : 7),
            decoration: BoxDecoration(color: attention > 0 ? AC.warningBg : AC.mint, borderRadius: BorderRadius.circular(99), border: Border.all(color: attention > 0 ? const Color(0xFFFDE68A) : AC.mint2)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Container(width: isPhone ? 6 : 8, height: isPhone ? 6 : 8, decoration: BoxDecoration(color: attention > 0 ? AC.warning : AC.emerald, shape: BoxShape.circle)),
              SizedBox(width: isPhone ? 5 : 7),
              Text(attention > 0 ? (narrow ? '$attention' : '$attention need action') : (narrow ? 'Live' : 'All caught up'), style: AC.t(isPhone ? 11.5 : 12.5, c: attention > 0 ? AC.warning : AC.emerald7, w: FontWeight.w800)),
            ]),
          ),
        ),
        if (desktop) ...[
          const SizedBox(width: 14),
          Text(DateFormat('EEE d MMM').format(DateTime.now()), style: AC.t(13, c: AC.mut, w: FontWeight.w600)),
        ],
        if (siteUrl.isNotEmpty && !narrow) ...[
          const SizedBox(width: 12),
          OutlinedButton.icon(
            onPressed: () => launchUrl(Uri.parse(siteUrl), webOnlyWindowName: '_blank'),
            icon: const Icon(Icons.open_in_new_rounded, size: 17),
            label: const Text('View website'),
            style: OutlinedButton.styleFrom(minimumSize: const Size(0, 38)),
          ),
        ],
        SizedBox(width: isPhone ? 6 : 8),
        PopupMenuButton<String>(
          tooltip: 'Account',
          offset: const Offset(0, 48),
          onSelected: (v) {
            if (v == 'out') onSignOut();
            if (v == 'site') onWebsite();
          },
          itemBuilder: (_) => [
            PopupMenuItem(enabled: false, child: Text(email, style: AC.t(13, c: AC.mut))),
            const PopupMenuDivider(),
            const PopupMenuItem(value: 'site', child: ListTile(dense: true, contentPadding: EdgeInsets.zero, leading: Icon(Icons.language_rounded), title: Text('Website settings'))),
            const PopupMenuItem(value: 'out', child: ListTile(dense: true, contentPadding: EdgeInsets.zero, leading: Icon(Icons.logout_rounded, color: AC.danger), title: Text('Sign out'))),
          ],
          child: CircleAvatar(radius: isPhone ? 15 : 17, backgroundColor: AC.forest, child: Text(email.isEmpty ? 'A' : email[0].toUpperCase(), style: AC.h(isPhone ? 12 : 14, c: AC.gold))),
        ),
      ]),
    );
  }
}
