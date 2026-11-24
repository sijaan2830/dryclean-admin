import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';

class FirebaseAdminService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Robust extraction of service name(s) across web and mobile order schemas.
  static String extractServiceName(Map<String, dynamic> data, Map<String, dynamic> bookingData) {
    // 1. Check selectedServices list
    final selectedServices = bookingData['selectedServices'] ?? data['selectedServices'] ?? data['services'] ?? bookingData['services'];
    if (selectedServices is List && selectedServices.isNotEmpty) {
      final names = selectedServices
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty && e != 'All Services')
          .toList();
      if (names.isNotEmpty) return names.join(', ');
    }

    // 2. Check single service field
    final singleSvc = bookingData['service'] ?? bookingData['selectedService'] ?? data['service'] ?? data['selectedService'];
    if (singleSvc != null && singleSvc.toString().trim().isNotEmpty && singleSvc.toString().trim() != 'All Services') {
      return singleSvc.toString().trim();
    }

    // 3. Check prepaid pack name
    final packName = bookingData['prepaidPackName'] ?? data['prepaidPackName'];
    if (packName != null && packName.toString().trim().isNotEmpty) {
      return 'Prepaid Pack: ${packName.toString().trim()}';
    }

    // 4. Check selectedItems
    final selectedItems = bookingData['selectedItems'] ?? data['items'] ?? data['selectedItems'];
    if (selectedItems is Map && selectedItems.isNotEmpty) {
      final items = <String>[];
      for (final val in selectedItems.values) {
        if (val is Map) {
          final t = (val['itemType'] ?? val['name'] ?? val['title'] ?? val['category'] ?? '').toString().trim();
          if (t.isNotEmpty && !items.contains(t)) items.add(t);
        }
      }
      if (items.isNotEmpty) return items.take(3).join(', ');
      return selectedItems.keys.first.toString();
    } else if (selectedItems is List && selectedItems.isNotEmpty) {
      final items = <String>[];
      for (final val in selectedItems) {
        if (val is Map) {
          final t = (val['itemType'] ?? val['name'] ?? val['title'] ?? val['category'] ?? '').toString().trim();
          if (t.isNotEmpty && !items.contains(t)) items.add(t);
        } else if (val != null) {
          final str = val.toString().trim();
          if (str.isNotEmpty && !items.contains(str)) items.add(str);
        }
      }
      if (items.isNotEmpty) return items.take(3).join(', ');
    }

    if (data['type'] == 'prepaid_pack') return 'Prepaid Pack';
    if (data['type'] == 'quick_bag') return 'Standard Service (Bag)';
    return 'Standard Cleaning';
  }

  // Real-time stream for dashboard stats
  Stream<Map<String, dynamic>> getDashboardStatsStream() {
    // Use orders stream as the primary stream and calculate other stats
    return _firestore
        .collection('orders')
        .snapshots()
        .asyncMap((ordersSnapshot) async {
      final orders = ordersSnapshot.docs;
      
      // Get users and services data
      final usersSnapshot = await _firestore.collection('users').get();
      final servicesSnapshot = await _firestore.collection('services').get();
      
      final users = usersSnapshot.docs;
      final services = servicesSnapshot.docs;
      
      // Calculate total revenue from orders
      double totalRevenue = 0.0;
      for (final orderDoc in orders) {
        final data = orderDoc.data();
        final bookingData = data['bookingData'] as Map<String, dynamic>? ?? {};
        final totalPrice = bookingData['totalPrice'] as double? ?? 
                          data['transactionAmount'] as double? ?? 0.0;
        totalRevenue += totalPrice;
      }
      
      return {
        'totalOrders': orders.length,
        'totalRevenue': totalRevenue,
        'totalUsers': users.length,
        'activeServices': services.length,
        'pendingOrders': orders.where((doc) => 
          doc.data()['status'] == 'pending').length,
        'completedOrders': orders.where((doc) => 
          doc.data()['status'] == 'completed').length,
      };
    });
  }

  // Real-time stream for orders
  Stream<List<Map<String, dynamic>>> getOrdersStream() {
    return _firestore
        .collection('orders')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        
        // Extract customer information from bookingData
        final bookingData = data['bookingData'] as Map<String, dynamic>? ?? {};
        final firstName = bookingData['firstName'] as String? ?? '';
        final lastName = bookingData['lastName'] as String? ?? '';
        final customerName = '$firstName $lastName'.trim();
        
        // Extract service information
        final serviceName = extractServiceName(data, bookingData);
        
        // Extract price information
        final totalPrice = bookingData['totalPrice'] as double? ?? 
                          data['transactionAmount'] as double? ?? 0.0;
        
        return {
          'id': doc.id,
          'orderId': data['orderId'] ?? doc.id,
          'customerName': customerName.isNotEmpty ? customerName : 'Unknown',
          'serviceName': serviceName,
          'totalPrice': totalPrice,
          'status': data['status'] ?? 'pending',
          'type': data['type'] ?? 'regular',
          'createdAt': data['createdAt']?.toDate() ?? DateTime.now(),
          'email': bookingData['email'] ?? '',
          'phone': bookingData['phone'] ?? '',
          'bookingData': bookingData,
        };
      }).toList();
    });
  }

  // Debug method to check what collections exist
  Future<void> debugCheckCollections() async {
    try {
      final usersSnapshot = await _firestore.collection('users').get();
      final adminUsersSnapshot = await _firestore.collection('admin_users').get();
      
      debugPrint('FirebaseAdminService: Users collection exists with ${usersSnapshot.docs.length} documents');
      debugPrint('FirebaseAdminService: Admin users collection exists with ${adminUsersSnapshot.docs.length} documents');
      
      debugPrint('FirebaseAdminService: All users in users collection:');
      for (final doc in usersSnapshot.docs) {
        debugPrint('  - User ID: ${doc.id}, Data: ${doc.data()}');
      }
      
      debugPrint('FirebaseAdminService: All users in admin_users collection:');
      for (final doc in adminUsersSnapshot.docs) {
        debugPrint('  - User ID: ${doc.id}, Data: ${doc.data()}');
      }
      
      // Check specifically for Abraham
      final abrahamDoc = await _firestore.collection('users').doc('Imx8Olv6doaYzu8ozsndAFBoNgA3').get();
      debugPrint('FirebaseAdminService: Abraham document exists in users: ${abrahamDoc.exists}');
      
      if (!abrahamDoc.exists) {
        // Check admin_users
        final abrahamAdminDoc = await _firestore.collection('admin_users').doc('Imx8Olv6doaYzu8ozsndAFBoNgA3').get();
        debugPrint('FirebaseAdminService: Abraham document exists in admin_users: ${abrahamAdminDoc.exists}');
      }
      
    } catch (e) {
      debugPrint('FirebaseAdminService: Error checking collections: $e');
    }
  }

  // Real-time stream for users (customers only, excludes admin users)
  Stream<List<Map<String, dynamic>>> getUsersStream() {
    debugPrint('FirebaseAdminService: Setting up users stream from users collection');
    return _firestore
        .collection('users')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .asyncMap((snapshot) async {
      debugPrint('FirebaseAdminService: Users snapshot received with ${snapshot.docs.length} documents');
      
      // Get all users from snapshot
      final users = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        debugPrint('FirebaseAdminService: User document data: ${data}');
        
        // Skip system documents like indexes and documents without proper user data
        final hasValidId = !doc.id.startsWith('--');
        final notIndexes = !data.containsKey('indexes');
        final hasEmail = data['email'] != null && data['email'].toString().isNotEmpty;
        final hasName = data.containsKey('firstName') || data.containsKey('displayName');
        
        debugPrint('FirebaseAdminService: User ${doc.id} - hasValidId: $hasValidId, notIndexes: $notIndexes, hasEmail: $hasEmail, hasName: $hasName');
        
        if (!hasValidId || !notIndexes || !hasEmail || !hasName) {
          debugPrint('FirebaseAdminService: Skipping system/invalid user document: ${doc.id}');
          return null;
        }
        
        final firstName = data['firstName'] as String? ?? '';
        final lastName = data['lastName'] as String? ?? '';
        final customerName = '$firstName $lastName'.trim();
        
        // Use contactUpdatedAt if available, otherwise use createdAt
        DateTime lastActive = data['contactUpdatedAt']?.toDate() ?? 
                             data['lastLogin']?.toDate() ?? 
                             data['createdAt']?.toDate() ?? 
                             DateTime.now();
        
        final userData = {
          'id': doc.id,
          'customerName': customerName.isNotEmpty ? customerName : 'Unknown',
          'email': data['email'] ?? '',
          'phone': data['phone'] ?? '',
          'customerType': data['customerType'] ?? 'individual',
          'companyName': data['companyName'] ?? '',
          'createdAt': data['createdAt']?.toDate() ?? DateTime.now(),
          'lastActive': lastActive, // Add this field
          'isActive': data['isActive'] ?? true,
        };
        
        debugPrint('FirebaseAdminService: Processed user data: $userData');
        return userData;
      }).where((user) => user != null).cast<Map<String, dynamic>>().toList();
      
      // Check if Abraham is missing and add him manually if needed
      final abrahamId = 'Imx8Olv6doaYzu8ozsndAFBoNgA3';
      final hasAbraham = users.any((user) => user['id'] == abrahamId);
      
      if (!hasAbraham) {
        debugPrint('FirebaseAdminService: Abraham missing from stream, adding manually');
        try {
          final abrahamDoc = await _firestore.collection('users').doc(abrahamId).get();
          if (abrahamDoc.exists) {
            final data = abrahamDoc.data() as Map<String, dynamic>;
            final firstName = data['firstName'] as String? ?? '';
            final lastName = data['lastName'] as String? ?? '';
            final customerName = '$firstName $lastName'.trim();
            
            DateTime lastActive = data['contactUpdatedAt']?.toDate() ?? 
                                 data['lastLogin']?.toDate() ?? 
                                 data['createdAt']?.toDate() ?? 
                                 DateTime.now();
            
            final abrahamData = {
              'id': abrahamId,
              'customerName': customerName.isNotEmpty ? customerName : 'Unknown',
              'email': data['email'] ?? '',
              'phone': data['phone'] ?? data['phoneNumber'] ?? '',
              'customerType': data['customerType'] ?? 'individual',
              'companyName': data['companyName'] ?? '',
              'createdAt': data['createdAt']?.toDate() ?? DateTime.now(),
              'lastActive': lastActive,
              'isActive': data['isActive'] ?? true,
            };
            
            users.add(abrahamData);
            debugPrint('FirebaseAdminService: Added Abraham manually: $abrahamData');
          }
        } catch (e) {
          debugPrint('FirebaseAdminService: Error adding Abraham manually: $e');
        }
      }
      
      debugPrint('FirebaseAdminService: Returning ${users.length} processed users');
      return users;
    });
  }

  // Get customer details by ID
  Future<Map<String, dynamic>?> getCustomerDetails(String customerId) async {
    try {
      final doc = await _firestore.collection('users').doc(customerId).get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        final firstName = data['firstName'] as String? ?? '';
        final lastName = data['lastName'] as String? ?? '';
        final customerName = '$firstName $lastName'.trim();
        
        return {
          'id': doc.id,
          'customerName': customerName.isNotEmpty ? customerName : 'Unknown',
          'email': data['email'] ?? '',
          'phone': data['phone'] ?? '',
          'customerType': data['customerType'] ?? 'individual',
          'companyName': data['companyName'] ?? '',
          'createdAt': data['createdAt']?.toDate() ?? DateTime.now(),
          'isActive': data['isActive'] ?? true,
          'contactUpdatedAt': data['contactUpdatedAt']?.toDate(),
          // Include address fields
          'defaultAddress': data['defaultAddress'],
          'selectedAddress': data['selectedAddress'],
          'deliveryAddress': data['deliveryAddress'],
          'addresses': data['addresses'],
          'address': data['address'],
        };
      }
      return null;
    } catch (e) {
      debugPrint('FirebaseAdminService: Error getting customer details: $e');
      return null;
    }
  }

  // Get customer orders
  Future<List<Map<String, dynamic>>> getCustomerOrders(String customerId) async {
    debugPrint('FirebaseAdminService: Getting orders for customer ID: $customerId');
    
    try {
      // First get the customer's email
      final customerDoc = await _firestore.collection('users').doc(customerId).get();
      if (!customerDoc.exists) {
        debugPrint('FirebaseAdminService: Customer document not found');
        return <Map<String, dynamic>>[];
      }
      
      final customerData = customerDoc.data() as Map<String, dynamic>;
      final customerEmail = customerData['email'] as String? ?? '';
      debugPrint('FirebaseAdminService: Customer email: $customerEmail');
      
      if (customerEmail.isEmpty) {
        debugPrint('FirebaseAdminService: Customer email is empty');
        return <Map<String, dynamic>>[];
      }
      
      // Get all orders and filter by email client-side (avoids index requirement)
      final ordersSnapshot = await _firestore
          .collection('orders')
          .orderBy('createdAt', descending: true)
          .limit(100) // Limit to avoid fetching too much data
          .get();
      
      debugPrint('FirebaseAdminService: Found ${ordersSnapshot.docs.length} total orders');
      
      // Filter orders by customer email
      final customerOrders = ordersSnapshot.docs.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final bookingData = data['bookingData'] as Map<String, dynamic>? ?? {};
        final orderEmail = bookingData['email'] as String? ?? '';
        return orderEmail == customerEmail;
      }).toList();
      
      debugPrint('FirebaseAdminService: Found ${customerOrders.length} orders for customer after filtering');
      
      return customerOrders.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final bookingData = data['bookingData'] as Map<String, dynamic>? ?? {};
        final firstName = bookingData['firstName'] as String? ?? '';
        final lastName = bookingData['lastName'] as String? ?? '';
        final customerName = '$firstName $lastName'.trim();
        
        // Extract service information
        final serviceName = extractServiceName(data, bookingData);
        
        // Extract price information
        final totalPrice = bookingData['totalPrice'] as double? ?? 
                          data['transactionAmount'] as double? ?? 0.0;
        
        return {
          'id': doc.id,
          'orderId': data['orderId'] ?? doc.id,
          'customerName': customerName.isNotEmpty ? customerName : 'Unknown',
          'serviceName': serviceName,
          'totalPrice': totalPrice,
          'status': data['status'] ?? 'pending',
          'type': data['type'] ?? 'regular',
          'createdAt': data['createdAt']?.toDate() ?? DateTime.now(),
          'email': bookingData['email'] ?? '',
          'phone': bookingData['phone'] ?? '',
          'bookingData': bookingData, // Include complete bookingData
          'transactionAmount': data['transactionAmount'], // Include order level transactionAmount
        };
      }).toList();
    } catch (e) {
      debugPrint('FirebaseAdminService: Error getting customer orders: $e');
      return <Map<String, dynamic>>[];
    }
  }

  // Toggle customer status
  Future<bool> toggleCustomerStatus(String customerId) async {
    try {
      final doc = await _firestore.collection('users').doc(customerId).get();
      if (doc.exists) {
        final currentStatus = doc.data()?['isActive'] as bool? ?? true;
        await _firestore.collection('users').doc(customerId).update({
          'isActive': !currentStatus,
          'statusUpdatedAt': FieldValue.serverTimestamp(),
        });
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('FirebaseAdminService: Error toggling customer status: $e');
      return false;
    }
  }

  // Real-time stream for timeslots
  Stream<List<Map<String, dynamic>>> getTimeslotsStream() {
    debugPrint('FirebaseAdminService: Starting time slots stream from time_slots collection...');
    
    return _firestore
        .collection('time_slots')
        .orderBy('day')
        .orderBy('startTime')
        .snapshots()
        .map((snapshot) {
          debugPrint('FirebaseAdminService: Received ${snapshot.docs.length} documents from time_slots');
          
          return snapshot.docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            debugPrint('FirebaseAdminService: Processing document - ${doc.id}: ${data.toString()}');
            
            return {
              'id': doc.id,
              'day': data['day'] ?? '',
              'startTime': data['startTime'] ?? '09:00',
              'endTime': data['endTime'] ?? '17:00',
              'maxBookings': data['maxBookings'] ?? 5,
              'currentBookings': data['currentBookings'] ?? 0,
              'isActive': data['isActive'] ?? true,
              'createdAt': data['createdAt']?.toDate() ?? DateTime.now(),
              'updatedAt': data['updatedAt']?.toDate() ?? DateTime.now(),
            };
          }).toList();
        });
  }

  // Real-time stream for collection time slots
  Stream<List<Map<String, dynamic>>> getCollectionTimeslotsStream() {
    debugPrint('FirebaseAdminService: Starting collection time slots stream from time_slots collection...');
    
    return _firestore
        .collection('time_slots')
        .where('type', isEqualTo: 'collection')
        .orderBy('day')
        .orderBy('startTime')
        .snapshots()
        .map((snapshot) {
          debugPrint('FirebaseAdminService: Received ${snapshot.docs.length} collection time slots from time_slots');
          
          return snapshot.docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            debugPrint('FirebaseAdminService: Processing collection document - ${doc.id}: ${data.toString()}');
            
            return {
              'id': doc.id,
              'day': data['day'] ?? '',
              'dayName': data['dayName'] ?? data['day'] ?? _getDayName(data['day']),
              'startTime': data['startTime'] ?? '09:00',
              'endTime': data['endTime'] ?? '17:00',
              'maxBookings': data['maxBookings'] ?? 5,
              'currentBookings': data['currentBookings'] ?? 0,
              'isActive': data['isActive'] ?? true,
              'type': data['type'] ?? 'collection',
              'createdAt': data['createdAt']?.toDate() ?? DateTime.now(),
              'updatedAt': data['updatedAt']?.toDate() ?? DateTime.now(),
            };
          }).toList();
        });
  }

  // Real-time stream for delivery time slots
  Stream<List<Map<String, dynamic>>> getDeliveryTimeslotsStream() {
    debugPrint('FirebaseAdminService: Starting delivery time slots stream from time_slots collection...');
    
    return _firestore
        .collection('time_slots')
        .where('type', isEqualTo: 'delivery')
        .orderBy('day')
        .orderBy('startTime')
        .snapshots()
        .map((snapshot) {
          debugPrint('FirebaseAdminService: Received ${snapshot.docs.length} delivery time slots from time_slots');
          
          return snapshot.docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            debugPrint('FirebaseAdminService: Processing delivery document - ${doc.id}: ${data.toString()}');
            
            return {
              'id': doc.id,
              'day': data['day'] ?? '',
              'dayName': data['dayName'] ?? data['day'] ?? _getDayName(data['day']),
              'startTime': data['startTime'] ?? '09:00',
              'endTime': data['endTime'] ?? '17:00',
              'maxBookings': data['maxBookings'] ?? 5,
              'currentBookings': data['currentBookings'] ?? 0,
              'isActive': data['isActive'] ?? true,
              'type': data['type'] ?? 'delivery',
              'createdAt': data['createdAt']?.toDate() ?? DateTime.now(),
              'updatedAt': data['updatedAt']?.toDate() ?? DateTime.now(),
            };
          }).toList();
        });
  }

  // Helper to get day name from day number or string
  String _getDayName(dynamic dayValue) {
    if (dayValue == null) return 'Unknown';
    
    String dayStr = dayValue.toString();
    
    // If it's already a day name, return it
    final dayNames = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    for (var name in dayNames) {
      if (name.toLowerCase() == dayStr.toLowerCase()) {
        return name;
      }
    }
    
    // If it's a number, convert to day name
    try {
      int dayNum = int.parse(dayStr);
      if (dayNum >= 1 && dayNum <= 7) {
        return dayNames[dayNum - 1];
      }
    } catch (e) {
      // Not a number
    }
    
    return 'Unknown';
  }

  Stream<List<Map<String, dynamic>>> getServicesStream() {
    return _firestore
        .collection('services')
        .orderBy('order')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'id': doc.id,
          ...data,
          'createdAt': data['createdAt']?.toDate() ?? DateTime.now(),
          'items': List<Map<String, dynamic>>.from(data['items'] ?? []),
        };
      }).toList();
    });
  }

  // Real-time stream for prepaid packs
  Stream<List<Map<String, dynamic>>> getPrepaidPacksStream() {
    return _firestore
        .collection('prepaid_packs')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'id': doc.id,
          ...data,
          'createdAt': data['createdAt']?.toDate() ?? DateTime.now(),
          'soldCount': data['soldCount'] ?? 0,
        };
      }).toList();
    });
  }

  // Real-time stream for analytics
  Stream<Map<String, dynamic>> getAnalyticsStream() {
    return _firestore.collection('analytics').doc('dashboard').snapshots().map((snapshot) {
      if (snapshot.exists) {
        return snapshot.data() as Map<String, dynamic>;
      }
      return {
        'totalRevenue': 0.0,
        'monthlyRevenue': {},
        'servicePopularity': {},
        'totalOrders': 0,
        'totalUsers': 0,
      };
    });
  }

  // Create new service
  Future<String> createService(Map<String, dynamic> serviceData) async {
    final docRef = await _firestore.collection('services').add({
      ...serviceData,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return docRef.id;
  }

  // Update service
  Future<void> updateService(String serviceId, Map<String, dynamic> data) async {
    await _firestore.collection('services').doc(serviceId).update(data);
  }

  // Toggle service status
  Future<void> toggleServiceStatus(String serviceId, bool isActive) async {
    await _firestore.collection('services').doc(serviceId).update({
      'isActive': isActive,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // Delete service
  Future<void> deleteService(String serviceId) async {
    try {
      debugPrint('FirebaseAdminService: Deleting service - ID: $serviceId');
      
      // Delete the service document from Firestore
      await _firestore.collection('services').doc(serviceId).delete();
      
      debugPrint('FirebaseAdminService: Service deleted successfully - ID: $serviceId');
    } catch (e) {
      debugPrint('FirebaseAdminService: Error deleting service - $e');
      rethrow;
    }
  }

  // Update order status
  Future<void> updateOrderStatus(String orderId, String status) async {
    await _firestore.collection('orders').doc(orderId).update({
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // Create new order
  Future<String> createOrder(Map<String, dynamic> orderData) async {
    final docRef = await _firestore.collection('orders').add({
      ...orderData,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'status': 'pending',
    });
    return docRef.id;
  }

  // Update order price
  Future<void> updateOrderPrice(String orderId, double newBasePrice) async {
    try {
      debugPrint('FirebaseAdminService: Updating order price - Order ID: $orderId, New Base Price: $newBasePrice');
      
      // Calculate total amount with tax and fees (same as main app)
      const serviceFee = 2.99;
      const deliveryFee = 0.0;
      const taxRate = 0.20; // 20% tax
      
      final tax = (newBasePrice + serviceFee + deliveryFee) * taxRate;
      final totalAmount = newBasePrice + serviceFee + deliveryFee + tax;
      
      debugPrint('FirebaseAdminService: Calculated - Service Fee: $serviceFee, Tax: $tax, Total Amount: $totalAmount');
      
      // Update both base price and total amount in Firestore
      await _firestore.collection('orders').doc(orderId).update({
        'bookingData.calculatedTotalPrice': newBasePrice,
        'totalPrice': newBasePrice,
        'transactionAmount': totalAmount,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      debugPrint('FirebaseAdminService: Order price updated successfully');
    } catch (e) {
      debugPrint('FirebaseAdminService: Error updating order price: $e');
    }
  }

  // Create new user
  Future<String> createUser(Map<String, dynamic> userData) async {
    final docRef = await _firestore.collection('users').add({
      ...userData,
      'createdAt': FieldValue.serverTimestamp(),
      'isActive': true,
    });
    return docRef.id;
  }

  // Update user
  Future<void> updateUser(String userId, Map<String, dynamic> data) async {
    await _firestore.collection('users').doc(userId).update({
      ...data,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // Create prepaid pack
  Future<String> createPrepaidPack(Map<String, dynamic> packData) async {
    final docRef = await _firestore.collection('prepaid_packs').add({
      ...packData,
      'createdAt': FieldValue.serverTimestamp(),
      'soldCount': 0,
      'isActive': true,
    });
    return docRef.id;
  }

  // Update prepaid pack
  Future<void> updatePrepaidPack(String packId, Map<String, dynamic> data) async {
    await _firestore.collection('prepaid_packs').doc(packId).update({
      ...data,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // Delete prepaid pack
  Future<void> deletePrepaidPack(String packId) async {
    await _firestore.collection('prepaid_packs').doc(packId).delete();
  }

  // Update dashboard stats
  Future<void> updateDashboardStats(Map<String, dynamic> stats) async {
    await _firestore.collection('stats').doc('dashboard').set({
      ...stats,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // Update analytics
  Future<void> updateAnalytics(Map<String, dynamic> analytics) async {
    await _firestore.collection('analytics').doc('dashboard').set({
      ...analytics,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // Update time slot
  Future<void> updateTimeSlot(String timeslotId, Map<String, dynamic> data) async {
    await _firestore.collection('time_slots').doc(timeslotId).update({
      ...data,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // Real-time stream for settings
  Stream<Map<String, dynamic>> getSettingsStream() {
    return _firestore.collection('settings').doc('app').snapshots().map((snapshot) {
      if (snapshot.exists) {
        return snapshot.data() as Map<String, dynamic>;
      }
      return {
        'businessName': 'DryClean Plus',
        'businessEmail': 'admin@drycleanplus.com',
        'businessPhone': '+44 20 1234 5678',
        'businessAddress': '123 Main Street, London, UK',
        'defaultCurrency': 'GBP (£)',
        'timeZone': 'Europe/London',
        'dateFormat': 'DD/MM/YYYY',
        'emailNotifications': true,
        'smsNotifications': false,
        'pushNotifications': true,
      };
    });
  }

  // Update settings
  Future<void> updateSettings(Map<String, dynamic> settings) async {
    await _firestore.collection('settings').doc('app').set({
      ...settings,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // Get single document helpers
  Future<DocumentSnapshot> getOrder(String orderId) async {
    return await _firestore.collection('orders').doc(orderId).get();
  }

  Future<DocumentSnapshot> getUser(String userId) async {
    return await _firestore.collection('users').doc(userId).get();
  }

  Future<DocumentSnapshot> getService(String serviceId) async {
    return await _firestore.collection('services').doc(serviceId).get();
  }

  Future<DocumentSnapshot> getPrepaidPack(String packId) async {
    return await _firestore.collection('prepaid_packs').doc(packId).get();
  }
}
