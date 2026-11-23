import 'package:flutter/foundation.dart';

class MockAdminService {
  Future<Map<String, dynamic>> getDashboardStats() async {
    // Mock data for demonstration
    await Future.delayed(const Duration(seconds: 1));
    
    return {
      'totalOrders': 156,
      'totalRevenue': 1245.67,
      'totalUsers': 89,
      'activeServices': 4,
    };
  }

  Future<List<Map<String, dynamic>>> getOrders() async {
    await Future.delayed(const Duration(seconds: 1));
    
    return [
      {
        'id': 'order_1',
        'orderId': 'ORD-2024-001',
        'serviceName': 'Dry Clean',
        'totalPrice': 8.95,
        'status': 'pending',
        'createdAt': DateTime.now().subtract(const Duration(days: 2)),
        'customerName': 'John Doe',
        'customerEmail': 'john@example.com',
        'items': [
          {'name': 'Suit', 'price': '£8.95'},
          {'name': 'Shirt', 'price': '£3.45'},
        ],
      },
      {
        'id': 'order_2',
        'orderId': 'ORD-2024-002',
        'serviceName': 'Laundry & Ironing',
        'totalPrice': 12.45,
        'status': 'processing',
        'createdAt': DateTime.now().subtract(const Duration(days: 1)),
        'customerName': 'Jane Smith',
        'customerEmail': 'jane@example.com',
        'items': [
          {'name': 'T-Shirt', 'price': '£1.95'},
          {'name': 'Trousers', 'price': '£3.45'},
        ],
      },
      {
        'id': 'order_3',
        'orderId': 'ORD-2024-003',
        'serviceName': 'Duvets & Bedding',
        'totalPrice': 15.95,
        'status': 'in_progress',
        'createdAt': DateTime.now().subtract(const Duration(hours: 12)),
        'customerName': 'Mike Johnson',
        'customerEmail': 'mike@example.com',
        'items': [
          {'name': 'Double Duvet', 'price': '£15.95'},
        ],
      },
      {
        'id': 'order_4',
        'orderId': 'ORD-2024-004',
        'serviceName': 'Household Items',
        'totalPrice': 25.95,
        'status': 'out_for_delivery',
        'createdAt': DateTime.now().subtract(const Duration(hours: 6)),
        'customerName': 'Sarah Wilson',
        'customerEmail': 'sarah@example.com',
        'items': [
          {'name': 'Large Rug', 'price': '£25.95'},
        ],
      },
      {
        'id': 'order_5',
        'orderId': 'ORD-2024-005',
        'serviceName': 'Dry Clean',
        'totalPrice': 12.40,
        'status': 'delivered',
        'createdAt': DateTime.now().subtract(const Duration(hours: 2)),
        'customerName': 'Tom Brown',
        'customerEmail': 'tom@example.com',
        'items': [
          {'name': 'Coat', 'price': '£7.95'},
          {'name': 'Dress', 'price': '£5.95'},
        ],
      },
      {
        'id': 'order_6',
        'orderId': 'ORD-2024-006',
        'serviceName': 'Laundry & Ironing',
        'totalPrice': 6.40,
        'status': 'cancelled',
        'createdAt': DateTime.now().subtract(const Duration(hours: 1)),
        'customerName': 'Lisa Davis',
        'customerEmail': 'lisa@example.com',
        'items': [
          {'name': 'Jeans', 'price': '£3.95'},
          {'name': 'Jacket', 'price': '£4.95'},
        ],
      },
    ];
  }

  Future<List<Map<String, dynamic>>> getUsers() async {
    await Future.delayed(const Duration(seconds: 1));
    
    return [
      {
        'id': 'user_1',
        'email': 'admin@example.com',
        'displayName': 'Admin User',
        'createdAt': DateTime.now().subtract(const Duration(days: 30)),
        'isActive': true,
        'lastLogin': DateTime.now().subtract(const Duration(hours: 2)),
      },
      {
        'id': 'user_2',
        'email': 'user@example.com',
        'displayName': 'Regular User',
        'createdAt': DateTime.now().subtract(const Duration(days: 7)),
        'isActive': true,
        'lastLogin': DateTime.now().subtract(const Duration(hours: 24)),
      },
    ];
  }

  Future<List<Map<String, dynamic>>> getServices() async {
    await Future.delayed(const Duration(seconds: 1));
    
    return [
      {
        'id': 'service_1',
        'name': 'Dry Clean',
        'description': 'Expert dry cleaning for delicate fabrics and formal wear.',
        'isActive': true,
        'order': 1,
        'createdAt': DateTime.now().subtract(const Duration(days: 30)),
        'items': [
          {'name': 'Suit', 'price': '£8.95'},
          {'name': 'Coat', 'price': '£7.95'},
          {'name': 'Dress', 'price': '£5.95'},
        ],
      },
      {
        'id': 'service_2',
        'name': 'Laundry & Ironing',
        'description': 'For everyday laundry, bedsheets and towels with professional ironing.',
        'isActive': true,
        'order': 2,
        'createdAt': DateTime.now().subtract(const Duration(days: 30)),
        'items': [
          {'name': 'T-Shirt', 'price': '£1.95'},
          {'name': 'Shirt', 'price': '£2.45'},
          {'name': 'Trousers', 'price': '3.45'},
        ],
      },
      {
        'id': 'service_3',
        'name': 'Duvets & Bedding',
        'description': 'Specialized cleaning for duvets, pillows, and bedding items.',
        'isActive': true,
        'order': 3,
        'createdAt': DateTime.now().subtract(const Duration(days: 30)),
        'items': [
          {'name': 'Single Duvet', 'price': '£11.95'},
          {'name': 'Double Duvet', 'price': '15.95'},
          {'name': 'King Duvet', 'price': '19.95'},
        ],
      },
      {
        'id': 'service_4',
        'name': 'Household Items',
        'description': 'Professional cleaning for curtains, rugs, and household textiles.',
        'isActive': true,
        'order': 4,
        'createdAt': DateTime.now().subtract(const Duration(days: 30)),
        'items': [
          {'name': 'Curtains', 'price': '£15.95'},
          {'name': 'Tablecloth', 'price': '8.95'},
          {'name': 'Napkins', 'price': '2.95'},
        ],
      },
    ];
  }

  Future<void> updateService(String serviceId, Map<String, dynamic> data) async {
    await Future.delayed(const Duration(seconds: 1));
    print('Mock: Updated service $serviceId with data: $data');
  }

  Future<void> toggleServiceStatus(String serviceId, bool isActive) async {
    await Future.delayed(const Duration(seconds: 1));
    print('Mock: Toggled service $serviceId to $isActive');
  }

  Future<void> updateOrderStatus(String orderId, String status) async {
    await Future.delayed(const Duration(seconds: 1));
    print('Mock: Updated order $orderId to status: $status');
  }

  Future<Map<String, dynamic>> getAnalytics() async {
    await Future.delayed(const Duration(seconds: 1));
    
    return {
      'totalRevenue': 1245.67,
      'monthlyRevenue': {
        '1': 890.45,
        '2': 355.22,
      },
      'servicePopularity': {
        'Dry Clean': 45,
        'Laundry & Ironing': 32,
        'Duvets & Bedding': 28,
        'Household Items': 15,
      },
      'totalOrders': 156,
      'totalUsers': 89,
    };
  }
}
