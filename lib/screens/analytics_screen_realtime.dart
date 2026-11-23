import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/firebase_admin_service.dart';

class AnalyticsScreenRealtime extends StatefulWidget {
  const AnalyticsScreenRealtime({super.key});

  @override
  State<AnalyticsScreenRealtime> createState() => _AnalyticsScreenRealtimeState();
}

class _AnalyticsScreenRealtimeState extends State<AnalyticsScreenRealtime> 
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F5),
      body: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Colors.grey, width: 0.5)),
            ),
            child: Row(
              children: [
                Icon(Icons.analytics, color: Colors.purple[700], size: 28),
                const SizedBox(width: 12),
                Text(
                  'Analytics Dashboard',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.purple[50],
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.purple[200]!),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Colors.purple,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Real-time',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          color: Colors.purple[700],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Tabs
          Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabController,
              labelColor: Colors.purple[700],
              unselectedLabelColor: Colors.grey[600],
              indicatorColor: Colors.purple[700],
              tabs: [
                Tab(
                  child: Text(
                    'Overview',
                    style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
                  ),
                ),
                Tab(
                  child: Text(
                    'Orders',
                    style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
                  ),
                ),
                Tab(
                  child: Text(
                    'Services',
                    style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
          
          // Tab content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                OverviewTab(),
                OrdersAnalyticsTab(),
                ServicesAnalyticsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class OverviewTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Map<String, dynamic>>(
      stream: context.watch<FirebaseAdminService>().getAnalyticsStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error loading analytics: ${snapshot.error}',
              style: GoogleFonts.plusJakartaSans(color: Colors.red),
            ),
          );
        }

        final analytics = snapshot.data ?? {};
        final totalRevenue = (analytics['totalRevenue'] as num?)?.toDouble() ?? 0.0;
        final totalOrders = analytics['totalOrders'] as int? ?? 0;
        final averageOrderValue = (analytics['averageOrderValue'] as num?)?.toDouble() ?? 0.0;
        final statusCounts = analytics['statusCounts'] as Map<String, dynamic>? ?? {};

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Key metrics
              Row(
                children: [
                  Expanded(
                    child: MetricCard(
                      title: 'Total Revenue',
                      value: '£${totalRevenue.toStringAsFixed(2)}',
                      icon: Icons.attach_money,
                      color: Colors.green,
                      change: '+12.5%',
                      isPositive: true,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: MetricCard(
                      title: 'Total Orders',
                      value: totalOrders.toString(),
                      icon: Icons.shopping_bag,
                      color: const Color(0xFF047857),
                      change: '+8.2%',
                      isPositive: true,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: MetricCard(
                      title: 'Average Order Value',
                      value: '£${averageOrderValue.toStringAsFixed(2)}',
                      icon: Icons.trending_up,
                      color: Colors.purple,
                      change: '+3.1%',
                      isPositive: true,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: MetricCard(
                      title: 'Completion Rate',
                      value: '${totalOrders > 0 ? ((statusCounts['completed'] ?? 0) / totalOrders * 100).toStringAsFixed(1) : 0}%',
                      icon: Icons.check_circle,
                      color: Colors.orange,
                      change: '+5.4%',
                      isPositive: true,
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 24),
              
              // Order status chart
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Order Status Distribution',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 16),
                      OrderStatusChart(statusCounts: statusCounts),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class OrdersAnalyticsTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: context.watch<FirebaseAdminService>().getOrdersStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error loading orders: ${snapshot.error}',
              style: GoogleFonts.plusJakartaSans(color: Colors.red),
            ),
          );
        }

        final orders = snapshot.data ?? [];
        
        // Calculate daily orders for the last 7 days
        final now = DateTime.now();
        final last7Days = List.generate(7, (index) {
          final date = now.subtract(Duration(days: 6 - index));
          return {
            'date': date,
            'orders': orders.where((order) {
              final orderDate = (order['createdAt'] as DateTime);
              return orderDate.year == date.year &&
                     orderDate.month == date.month &&
                     orderDate.day == date.day;
            }).length,
          };
        });

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Daily orders chart
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Daily Orders (Last 7 Days)',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 16),
                      DailyOrdersChart(data: last7Days),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Recent orders table
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Recent Orders',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 16),
                      RecentOrdersTable(orders: orders.take(10).toList()),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class ServicesAnalyticsTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Map<String, dynamic>>(
      stream: context.watch<FirebaseAdminService>().getAnalyticsStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error loading analytics: ${snapshot.error}',
              style: GoogleFonts.plusJakartaSans(color: Colors.red),
            ),
          );
        }

        final analytics = snapshot.data ?? {};
        final serviceCounts = analytics['serviceCounts'] as Map<String, dynamic>? ?? {};

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Service popularity chart
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Service Popularity',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ServicePopularityChart(serviceCounts: serviceCounts),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final String change;
  final bool isPositive;

  const MetricCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    required this.change,
    required this.isPositive,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isPositive ? Colors.green[50] : Colors.red[50],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isPositive ? Icons.arrow_upward : Icons.arrow_downward,
                        size: 12,
                        color: isPositive ? Colors.green : Colors.red,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        change,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isPositive ? Colors.green : Colors.red,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class OrderStatusChart extends StatelessWidget {
  final Map<String, dynamic> statusCounts;

  const OrderStatusChart({super.key, required this.statusCounts});

  @override
  Widget build(BuildContext context) {
    final total = statusCounts.values.fold<int>(0, (sum, count) => sum + (count as int));
    
    if (total == 0) {
      return Center(
        child: Text(
          'No orders to display',
          style: GoogleFonts.plusJakartaSans(color: Colors.grey[600]),
        ),
      );
    }

    final statusData = [
      {'status': 'Pending', 'count': statusCounts['pending'] ?? 0, 'color': Colors.orange},
      {'status': 'Confirmed', 'count': statusCounts['confirmed'] ?? 0, 'color': const Color(0xFF047857)},
      {'status': 'Processing', 'count': statusCounts['processing'] ?? 0, 'color': Colors.purple},
      {'status': 'Ready', 'count': statusCounts['ready'] ?? 0, 'color': Colors.teal},
      {'status': 'Completed', 'count': statusCounts['completed'] ?? 0, 'color': Colors.green},
      {'status': 'Cancelled', 'count': statusCounts['cancelled'] ?? 0, 'color': Colors.red},
    ];

    return Column(
      children: statusData.map((data) {
        final count = data['count'] as int;
        final percentage = total > 0 ? (count / total * 100) : 0.0;
        
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    data['status'] as String,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
                    ),
                  ),
                  Text(
                    '$count (${percentage.toStringAsFixed(1)}%)',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              LinearProgressIndicator(
                value: count / total,
                backgroundColor: Colors.grey[200],
                valueColor: AlwaysStoppedAnimation<Color>(data['color'] as Color),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class DailyOrdersChart extends StatelessWidget {
  final List<Map<String, dynamic>> data;

  const DailyOrdersChart({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final maxOrders = data.map((d) => d['orders'] as int).reduce((a, b) => a > b ? a : b);
    
    return Container(
      height: 200,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: data.map((dayData) {
          final orders = dayData['orders'] as int;
          final height = maxOrders > 0 ? (orders / maxOrders * 150) : 0.0;
          final date = dayData['date'] as DateTime;
          
          return Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Container(
                width: 30,
                height: height,
                decoration: BoxDecoration(
                  color: const Color(0xFF059669),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${date.day}/${date.month}',
                style: GoogleFonts.plusJakartaSans(fontSize: 10, color: Colors.grey[600]),
              ),
              Text(
                orders.toString(),
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }
}

class ServicePopularityChart extends StatelessWidget {
  final Map<String, dynamic> serviceCounts;

  const ServicePopularityChart({super.key, required this.serviceCounts});

  @override
  Widget build(BuildContext context) {
    if (serviceCounts.isEmpty) {
      return Center(
        child: Text(
          'No service data to display',
          style: GoogleFonts.plusJakartaSans(color: Colors.grey[600]),
        ),
      );
    }

    final sortedServices = serviceCounts.entries.toList()
      ..sort((a, b) => (b.value as int).compareTo(a.value as int));

    return Column(
      children: sortedServices.take(10).map((entry) {
        final service = entry.key;
        final count = entry.value as int;
        final maxCount = sortedServices.first.value as int;
        final percentage = maxCount > 0 ? (count / maxCount * 100) : 0.0;
        
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      service,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.black87,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    count.toString(),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              LinearProgressIndicator(
                value: percentage / 100,
                backgroundColor: Colors.grey[200],
                valueColor: AlwaysStoppedAnimation<Color>(Colors.purple[600]!),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class RecentOrdersTable extends StatelessWidget {
  final List<Map<String, dynamic>> orders;

  const RecentOrdersTable({super.key, required this.orders});

  @override
  Widget build(BuildContext context) {
    if (orders.isEmpty) {
      return Center(
        child: Text(
          'No orders to display',
          style: GoogleFonts.plusJakartaSans(color: Colors.grey[600]),
        ),
      );
    }

    return Column(
      children: [
        // Table header
        Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
          ),
          child: Row(
            children: [
              Expanded(flex: 2, child: _headerText('Order ID')),
              Expanded(flex: 2, child: _headerText('Customer')),
              Expanded(flex: 1, child: _headerText('Amount')),
              Expanded(flex: 1, child: _headerText('Status')),
              Expanded(flex: 2, child: _headerText('Date')),
            ],
          ),
        ),
        // Table rows
        ...orders.map((order) {
          final bookingData = order['bookingData'] as Map<String, dynamic>? ?? {};
          final customerName = '${bookingData['firstName'] ?? 'Unknown'} ${bookingData['lastName'] ?? ''}';
          final createdAt = order['createdAt'] as DateTime;
          
          return Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.grey[100]!)),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Text(
                    '#${order['orderId']}',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    customerName,
                    style: GoogleFonts.plusJakartaSans(fontSize: 12, color: Colors.black87),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Text(
                    '£${order['transactionAmount']?.toStringAsFixed(2) ?? '0.00'}',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.green[700],
                    ),
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: _getStatusColor(order['status']).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      order['status'].toString().toUpperCase(),
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: _getStatusColor(order['status']),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    '${createdAt.day}/${createdAt.month}/${createdAt.year}',
                    style: GoogleFonts.plusJakartaSans(fontSize: 12, color: Colors.grey[600]),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ],
    );
  }

  Widget _headerText(String text) {
    return Text(
      text,
      style: GoogleFonts.plusJakartaSans(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: Colors.grey[700],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'confirmed':
        return const Color(0xFF047857);
      case 'processing':
        return Colors.purple;
      case 'ready':
        return Colors.teal;
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}
