import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../theme/admin_ui.dart';

/// Command centre: live KPIs, the order pipeline, revenue trend, what needs attention.
class DashboardScreenRealtime extends StatefulWidget {
  const DashboardScreenRealtime({super.key});
  @override
  State<DashboardScreenRealtime> createState() => _DashboardScreenRealtimeState();
}

// pipeline stages (shared status list)
const _stages = <(String, IconData, Color, Set<String>)>[
  ('To collect', Icons.inbox_rounded, AC.warning, {'pending', 'confirmed', 'pickup_assigned', 'pickup_failed'}),
  ('With drivers', Icons.local_shipping_rounded, AC.info, {'pickup_en_route', 'pickup_arrived', 'collected'}),
  ('At facility', Icons.local_laundry_service_rounded, AC.violet, {'at_facility', 'inspecting', 'awaiting_approval', 'cleaning', 'quality_check', 'processing', 'in_progress'}),
  ('Ready', Icons.checkroom_rounded, Color(0xFF0D9488), {'ready_for_delivery', 'delivery_assigned', 'ready'}),
  ('Out for delivery', Icons.route_rounded, AC.emerald, {'out_for_delivery', 'delivery_arrived', 'delivery_failed'}),
];

double _amount(Map<String, dynamic> m) {
  final b = m['bookingData'] is Map ? (m['bookingData'] as Map) : const {};
  final v = (m['pricing'] is Map ? (m['pricing'] as Map)['final'] : null) ?? m['transactionAmount'] ?? b['totalPrice'] ?? 0;
  return v is num ? v.toDouble() : double.tryParse('$v') ?? 0;
}

DateTime? _created(Map<String, dynamic> m) => m['createdAt'] is Timestamp ? (m['createdAt'] as Timestamp).toDate() : null;
String _status(Map<String, dynamic> m) => '${m['status'] ?? 'pending'}';
bool _closed(String s) => const {'delivered', 'completed', 'cancelled'}.contains(s);

class _DashboardScreenRealtimeState extends State<DashboardScreenRealtime> {
  final _db = FirebaseFirestore.instance;
  late final _orders = _db.collection('orders').orderBy('createdAt', descending: true).limit(600).snapshots();
  late final _drivers = _db.collection('driver_locations').where('online', isEqualTo: true).snapshots();
  late final _notices = _db.collection('notices').where('isActive', isEqualTo: true).snapshots();
  late final _users = _db.collection('users').count().get();
  final _money = NumberFormat.currency(locale: 'en_GB', symbol: '£');

  String get _greeting {
    final h = DateTime.now().hour;
    return h < 12 ? 'Good morning' : h < 18 ? 'Good afternoon' : 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _orders,
      builder: (context, snap) {
        final docs = (snap.data?.docs ?? const <QueryDocumentSnapshot<Map<String, dynamic>>>[]).where((d) => d.id != '--indexes--').toList();
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final yesterday = today.subtract(const Duration(days: 1));
        bool onDay(DateTime? d, DateTime day) => d != null && !d.isBefore(day) && d.isBefore(day.add(const Duration(days: 1)));

        final todayOrders = docs.where((d) => onDay(_created(d.data()), today) && _status(d.data()) != 'cancelled').toList();
        final yOrders = docs.where((d) => onDay(_created(d.data()), yesterday) && _status(d.data()) != 'cancelled').toList();
        final revToday = todayOrders.fold<double>(0, (a, d) => a + _amount(d.data()));
        final revY = yOrders.fold<double>(0, (a, d) => a + _amount(d.data()));
        final active = docs.where((d) => !_closed(_status(d.data()))).toList();
        final last30 = docs.where((d) {
          final c = _created(d.data());
          return c != null && c.isAfter(now.subtract(const Duration(days: 30))) && _status(d.data()) != 'cancelled';
        }).toList();
        final aov = last30.isEmpty ? 0.0 : last30.fold<double>(0, (a, d) => a + _amount(d.data())) / last30.length;

        // 14-day revenue
        final days = List.generate(14, (i) => today.subtract(Duration(days: 13 - i)));
        final series = [for (final d in days) docs.where((o) => onDay(_created(o.data()), d) && _status(o.data()) != 'cancelled').fold<double>(0, (a, o) => a + _amount(o.data()))];

        String? pct(double a, double b) => b == 0 ? (a == 0 ? null : 'new') : '${((a - b) / b * 100).abs().toStringAsFixed(0)}%';
        final wide = MediaQuery.sizeOf(context).width >= 1200;
        final name = (FirebaseAuth.instance.currentUser?.displayName ?? '').split(' ').first;

        return AdminPage(
          title: '$_greeting${name.isEmpty ? '' : ', $name'}',
          subtitle: 'Here’s what’s happening across DryClean Plus today — everything below updates live.',
          actions: [
            OutlinedButton.icon(onPressed: () => openAdminPage('Notices'), icon: const Icon(Icons.campaign_outlined, size: 18), label: const Text('Post a notice')),
            FilledButton.icon(onPressed: () => openAdminPage('Dispatch'), icon: const Icon(Icons.local_shipping_outlined, size: 18), label: const Text('Open dispatch')),
          ],
          child: snap.connectionState == ConnectionState.waiting && docs.isEmpty
              ? const Padding(padding: EdgeInsets.all(60), child: Center(child: CircularProgressIndicator()))
              : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  // ------------------------------------------------ KPIs
                  LayoutBuilder(builder: (context, c) {
                    final cols = c.maxWidth >= 1000 ? 4 : c.maxWidth >= 560 ? 2 : 1;
                    final w = (c.maxWidth - (cols - 1) * 14) / cols;
                    return Wrap(spacing: 14, runSpacing: 14, children: [
                      SizedBox(width: w, child: KpiCard(icon: Icons.payments_outlined, label: 'Revenue today', value: _money.format(revToday), delta: pct(revToday, revY), up: revToday >= revY)),
                      SizedBox(width: w, child: KpiCard(icon: Icons.receipt_long_outlined, label: 'Orders today', value: '${todayOrders.length}', delta: pct(todayOrders.length.toDouble(), yOrders.length.toDouble()), up: todayOrders.length >= yOrders.length, tone: AC.info, toneBg: AC.infoBg)),
                      SizedBox(width: w, child: KpiCard(icon: Icons.autorenew_rounded, label: 'Orders in progress', value: '${active.length}', tone: AC.violet, toneBg: AC.violetBg)),
                      SizedBox(width: w, child: KpiCard(icon: Icons.shopping_basket_outlined, label: 'Average order · 30 days', value: _money.format(aov), tone: AC.warning, toneBg: AC.warningBg)),
                    ]);
                  }),
                  const SizedBox(height: 18),
                  // ------------------------------------------------ pipeline
                  SurfaceCard(
                    title: 'Live order pipeline',
                    subtitle: 'Where every open order is right now',
                    trailing: TextButton(onPressed: () => openAdminPage('Orders'), child: const Text('All orders')),
                    child: _Pipeline(docs: active),
                  ),
                  const SizedBox(height: 18),
                  // ------------------------------------------------ chart + side
                  Flex(
                    direction: wide ? Axis.horizontal : Axis.vertical,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Flexible(
                        flex: wide ? 3 : 0,
                        child: SurfaceCard(
                          title: 'Revenue · last 14 days',
                          subtitle: '${_money.format(series.fold<double>(0, (a, b) => a + b))} total',
                          child: SizedBox(height: 260, child: _RevenueChart(days: days, values: series, money: _money)),
                        ),
                      ),
                      SizedBox(width: wide ? 18 : 0, height: wide ? 0 : 18),
                      Flexible(
                        flex: wide ? 2 : 0,
                        child: Column(children: [
                          _LiveStrip(drivers: _drivers, notices: _notices, users: _users),
                          const SizedBox(height: 18),
                          SurfaceCard(title: 'Needs attention', padding: const EdgeInsets.fromLTRB(12, 8, 12, 12), child: _Attention(docs: active)),
                        ]),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  SurfaceCard(
                    title: 'Recent orders',
                    trailing: TextButton(onPressed: () => openAdminPage('Orders'), child: const Text('View all')),
                    padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
                    child: _Recent(docs: docs.take(8).toList(), money: _money),
                  ),
                ]),
        );
      },
    );
  }
}

class _Pipeline extends StatelessWidget {
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs;
  const _Pipeline({required this.docs});
  @override
  Widget build(BuildContext context) {
    final counts = [for (final s in _stages) docs.where((d) => s.$4.contains(_status(d.data()))).length];
    final total = math.max(1, counts.fold<int>(0, (a, b) => a + b));
    return LayoutBuilder(builder: (context, c) {
      final narrow = c.maxWidth < 760;
      final tiles = [
        for (var i = 0; i < _stages.length; i++)
          InkWell(
            onTap: () => openAdminPage(i == 0 || i == 3 ? 'Dispatch' : 'Orders'),
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: AC.subtle, borderRadius: BorderRadius.circular(14), border: Border.all(color: AC.border)),
              child: Row(children: [
                Container(width: 38, height: 38, decoration: BoxDecoration(color: _stages[i].$3.withValues(alpha: .12), borderRadius: BorderRadius.circular(11)), child: Icon(_stages[i].$2, color: _stages[i].$3, size: 20)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${counts[i]}', style: AC.num(22)),
                    Text(_stages[i].$1, maxLines: 1, overflow: TextOverflow.ellipsis, style: AC.t(12.5, c: AC.mut, w: FontWeight.w600)),
                  ]),
                ),
              ]),
            ),
          ),
      ];
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        // proportional bar
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: SizedBox(
            height: 10,
            child: Row(children: [
              for (var i = 0; i < _stages.length; i++)
                if (counts[i] > 0) Expanded(flex: counts[i], child: Container(color: _stages[i].$3, margin: const EdgeInsets.only(right: 2))),
              if (counts.every((c) => c == 0)) Expanded(child: Container(color: AC.border)),
            ]),
          ),
        ),
        const SizedBox(height: 6),
        Text('$total open order${total == 1 ? '' : 's'}', style: AC.t(12, c: AC.faint, w: FontWeight.w600)),
        const SizedBox(height: 14),
        if (narrow)
          Column(children: [for (final t in tiles) Padding(padding: const EdgeInsets.only(bottom: 10), child: t)])
        else
          Row(children: [for (var i = 0; i < tiles.length; i++) ...[Expanded(child: tiles[i]), if (i < tiles.length - 1) const SizedBox(width: 10)]]),
      ]);
    });
  }
}

class _RevenueChart extends StatelessWidget {
  final List<DateTime> days;
  final List<double> values;
  final NumberFormat money;
  const _RevenueChart({required this.days, required this.values, required this.money});
  @override
  Widget build(BuildContext context) {
    final maxV = values.fold<double>(0, math.max);
    final top = maxV <= 0 ? 100.0 : (maxV * 1.25 / 50).ceil() * 50.0;
    return LineChart(LineChartData(
      minY: 0,
      maxY: top,
      gridData: FlGridData(show: true, drawVerticalLine: false, horizontalInterval: top / 4, getDrawingHorizontalLine: (_) => const FlLine(color: AC.border, strokeWidth: 1, dashArray: [4, 4])),
      borderData: FlBorderData(show: false),
      titlesData: FlTitlesData(
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(showTitles: true, reservedSize: 46, interval: top / 4, getTitlesWidget: (v, _) => Text('£${v.toInt()}', style: AC.t(11, c: AC.faint))),
        ),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            interval: 1,
            reservedSize: 26,
            getTitlesWidget: (v, _) {
              final i = v.toInt();
              if (i < 0 || i >= days.length || (i % 2 == 1 && i != days.length - 1)) return const SizedBox.shrink();
              return Padding(padding: const EdgeInsets.only(top: 6), child: Text(DateFormat('d MMM').format(days[i]), style: AC.t(11, c: AC.faint)));
            },
          ),
        ),
      ),
      lineTouchData: LineTouchData(
        touchTooltipData: LineTouchTooltipData(
          getTooltipColor: (_) => AC.ink,
          getTooltipItems: (spots) => [for (final s in spots) LineTooltipItem('${DateFormat('EEE d MMM').format(days[s.x.toInt()])}\n${money.format(s.y)}', AC.t(12, c: Colors.white, w: FontWeight.w700))],
        ),
      ),
      lineBarsData: [
        LineChartBarData(
          spots: [for (var i = 0; i < values.length; i++) FlSpot(i.toDouble(), values[i])],
          isCurved: true,
          curveSmoothness: .28,
          preventCurveOverShooting: true,
          color: AC.emerald,
          barWidth: 3,
          dotData: FlDotData(show: true, getDotPainter: (s, _, __, i) => FlDotCirclePainter(radius: i == values.length - 1 ? 4.5 : 0, color: AC.emerald, strokeWidth: 3, strokeColor: Colors.white)),
          belowBarData: BarAreaData(show: true, gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [AC.emerald.withValues(alpha: .22), AC.emerald.withValues(alpha: 0)])),
        ),
      ],
    ));
  }
}

class _LiveStrip extends StatelessWidget {
  final Stream<QuerySnapshot<Map<String, dynamic>>> drivers, notices;
  final Future<AggregateQuerySnapshot> users;
  const _LiveStrip({required this.drivers, required this.notices, required this.users});
  @override
  Widget build(BuildContext context) {
    Widget tile(IconData i, String v, String l, Color c, String page) => Expanded(
          child: InkWell(
            onTap: () => openAdminPage(page),
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: AC.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: AC.border)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(i, size: 20, color: c),
                const SizedBox(height: 10),
                Text(v, style: AC.num(20)),
                Text(l, style: AC.t(12, c: AC.mut, w: FontWeight.w600)),
              ]),
            ),
          ),
        );
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: drivers,
      builder: (context, d) => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: notices,
        builder: (context, n) => FutureBuilder<AggregateQuerySnapshot>(
          future: users,
          builder: (context, u) => Row(children: [
            tile(Icons.local_shipping_rounded, '${d.data?.size ?? 0}', 'Drivers online', AC.info, 'Dispatch'),
            const SizedBox(width: 10),
            tile(Icons.campaign_rounded, '${n.data?.size ?? 0}', 'Live notices', AC.warning, 'Notices'),
            const SizedBox(width: 10),
            tile(Icons.people_rounded, '${u.data?.count ?? '—'}', 'Customers', AC.emerald, 'Customers'),
          ]),
        ),
      ),
    );
  }
}

class _Attention extends StatelessWidget {
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs;
  const _Attention({required this.docs});
  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final items = <(IconData, Color, Color, String, String, String)>[];
    final approval = docs.where((d) => _status(d.data()) == 'awaiting_approval').length;
    final failed = docs.where((d) => _status(d.data()).endsWith('_failed')).length;
    final unassigned = docs.where((d) {
      final c = _created(d.data());
      return {'pending', 'confirmed'}.contains(_status(d.data())) && c != null && now.difference(c).inHours >= 2;
    }).length;
    final ready = docs.where((d) => _status(d.data()) == 'ready_for_delivery').length;
    if (unassigned > 0) items.add((Icons.hourglass_bottom_rounded, AC.warning, AC.warningBg, '$unassigned order${unassigned == 1 ? '' : 's'} waiting over 2 h', 'No driver assigned yet', 'Dispatch'));
    if (failed > 0) items.add((Icons.event_busy_rounded, AC.danger, AC.dangerBg, '$failed missed visit${failed == 1 ? '' : 's'}', 'Reschedule with the customer', 'Dispatch'));
    if (approval > 0) items.add((Icons.pending_actions_rounded, AC.violet, AC.violetBg, '$approval awaiting customer approval', 'Extras or damage found at intake', 'Orders'));
    if (ready > 0) items.add((Icons.checkroom_rounded, AC.info, AC.infoBg, '$ready ready to deliver', 'Assign a delivery driver', 'Dispatch'));
    if (items.isEmpty) {
      return const EmptyState(icon: Icons.task_alt_rounded, title: 'All clear', text: 'Nothing needs your attention right now.');
    }
    return Column(children: [
      for (final it in items)
        ListTile(
          onTap: () => openAdminPage(it.$6),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          leading: Container(width: 38, height: 38, decoration: BoxDecoration(color: it.$3, borderRadius: BorderRadius.circular(11)), child: Icon(it.$1, color: it.$2, size: 20)),
          title: Text(it.$4),
          subtitle: Text(it.$5),
          trailing: const Icon(Icons.chevron_right_rounded, color: AC.faint),
        ),
    ]);
  }
}

class _Recent extends StatelessWidget {
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs;
  final NumberFormat money;
  const _Recent({required this.docs, required this.money});

  static (String, Color, Color) _pill(String s) {
    for (final st in _stages) {
      if (st.$4.contains(s)) return (st.$1, st.$3, st.$3.withValues(alpha: .1));
    }
    if (s == 'delivered' || s == 'completed') return ('Delivered', AC.emerald7, AC.mint);
    if (s == 'cancelled') return ('Cancelled', AC.danger, AC.dangerBg);
    return (s, AC.mut, AC.subtle);
  }

  @override
  Widget build(BuildContext context) {
    if (docs.isEmpty) return const EmptyState(icon: Icons.receipt_long_rounded, title: 'No orders yet', text: 'New orders from the website and app appear here instantly.');
    final wide = MediaQuery.sizeOf(context).width >= 900;
    return Column(children: [
      if (wide)
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 6, 14, 8),
          child: Row(children: [
            Expanded(flex: 3, child: Text('ORDER', style: AC.label())),
            Expanded(flex: 4, child: Text('CUSTOMER', style: AC.label())),
            Expanded(flex: 3, child: Text('STATUS', style: AC.label())),
            Expanded(flex: 2, child: Text('PLACED', style: AC.label())),
            Expanded(flex: 2, child: Text('TOTAL', textAlign: TextAlign.right, style: AC.label())),
          ]),
        ),
      for (final d in docs)
        Builder(builder: (_) {
          final m = d.data();
          final b = m['bookingData'] is Map ? (m['bookingData'] as Map) : const {};
          final name = '${b['firstName'] ?? ''} ${b['lastName'] ?? ''}'.trim();
          final p = _pill(_status(m));
          final c = _created(m);
          final pill = StatusPill(p.$1, c: p.$2, bg: p.$3);
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: const BoxDecoration(border: Border(top: BorderSide(color: AC.border))),
            child: wide
                ? Row(children: [
                    Expanded(flex: 3, child: Text('#${m['orderId'] ?? d.id.substring(0, 6)}', style: AC.t(13.5, w: FontWeight.w800))),
                    Expanded(flex: 4, child: Text(name.isEmpty ? 'Customer' : name, overflow: TextOverflow.ellipsis, style: AC.t(13.5))),
                    Expanded(flex: 3, child: Align(alignment: Alignment.centerLeft, child: pill)),
                    Expanded(flex: 2, child: Text(c == null ? '—' : DateFormat('d MMM, HH:mm').format(c), style: AC.t(13, c: AC.mut))),
                    Expanded(flex: 2, child: Text(money.format(_amount(m)), textAlign: TextAlign.right, style: AC.t(13.5, w: FontWeight.w800))),
                  ])
                : Row(children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('#${m['orderId'] ?? ''} · ${name.isEmpty ? 'Customer' : name}', overflow: TextOverflow.ellipsis, style: AC.t(13.5, w: FontWeight.w800)),
                        const SizedBox(height: 4),
                        pill,
                      ]),
                    ),
                    Text(money.format(_amount(m)), style: AC.t(13.5, w: FontWeight.w800)),
                  ]),
          );
        }),
    ]);
  }
}
