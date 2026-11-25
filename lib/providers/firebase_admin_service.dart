import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:rxdart/rxdart.dart';

import '../services/push_service.dart';

class FirebaseAdminService extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  Stream<List<Map<String, dynamic>>>? _cachedOrdersStream;

  // Real-time stream for all orders (cached broadcast so UI filters don't reset listener)
  Stream<List<Map<String, dynamic>>> getOrdersStream() {
    if (_cachedOrdersStream != null) return _cachedOrdersStream!;
    debugPrint('FirebaseAdminService: Starting orders stream...');

    _cachedOrdersStream = _firestore
        .collection('orders')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      debugPrint(
          'FirebaseAdminService: Received ${snapshot.docs.length} orders');

      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;

        if (doc.id.startsWith('--') || data.containsKey('indexes')) {
          return null;
        }

        double transactionAmount = 0.0;
        if (data['transactionAmount'] != null) {
          if (data['transactionAmount'] is num) {
            transactionAmount =
                (data['transactionAmount'] as num).toDouble();
          } else if (data['transactionAmount'] is String) {
            transactionAmount =
                double.tryParse(data['transactionAmount'].toString()) ??
                    0.0;
          }
        } else {
          final bookingData =
              data['bookingData'] as Map<String, dynamic>?;
          if (bookingData != null && bookingData['totalPrice'] != null) {
            if (bookingData['totalPrice'] is num) {
              transactionAmount =
                  (bookingData['totalPrice'] as num).toDouble();
            } else if (bookingData['totalPrice'] is String) {
              final priceStr = bookingData['totalPrice']
                  .toString()
                  .replaceAll('£', '')
                  .replaceAll(',', '');
              transactionAmount = double.tryParse(priceStr) ?? 0.0;
            }

            if (transactionAmount == 0.0 &&
                bookingData['selectedItems'] != null) {
              final selectedItems = bookingData['selectedItems'];
              double calculatedPrice = 0.0;

              if (selectedItems is Map) {
                for (final item in selectedItems.values) {
                  if (item is Map && item['price'] != null) {
                    final itemPrice = item['price']
                        .toString()
                        .replaceAll('£', '')
                        .replaceAll(',', '');
                    calculatedPrice +=
                        double.tryParse(itemPrice) ?? 0.0;
                  }
                }
              }

              if (calculatedPrice > 0) {
                transactionAmount = calculatedPrice;
              }
            }
          }
        }

        return {
          ...data,
          'id': doc.id,
          'orderId': data['orderId'] ?? '',
          'userId': data['userId'] ?? '',
          'status': data['status'] ?? 'pending',
          'type': data['type'] ?? 'regular',
          'createdAt': data['createdAt'] is Timestamp
              ? (data['createdAt'] as Timestamp).toDate()
              : DateTime.now(),
          'updatedAt': data['updatedAt'] is Timestamp
              ? (data['updatedAt'] as Timestamp).toDate()
              : null,
          'deliveredAt': data['deliveredAt'] is Timestamp
              ? (data['deliveredAt'] as Timestamp).toDate()
              : data['deliveredAt'],
          'transactionAmount': transactionAmount,
          'transactionId': data['transactionId'] ?? '',
          'paymentMethod': data['paymentMethod'] ?? '',
          'bookingData':
              Map<String, dynamic>.from(data['bookingData'] ?? {}),
        };
      }).where((order) => order != null).cast<Map<String, dynamic>>().toList();
    }).asBroadcastStream();
    return _cachedOrdersStream!;
  }

  // Real-time stream for users/customers
  Stream<List<Map<String, dynamic>>> getUsersStream() {
    return _firestore
        .collection('users')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;

        if (doc.id.startsWith('--') ||
            data.containsKey('indexes') ||
            data['email'] == null ||
            data['email'].toString().isEmpty ||
            (!data.containsKey('firstName') &&
                !data.containsKey('displayName'))) {
          return null;
        }

        return {
          'id': doc.id,
          'firstName': data['firstName'] ??
              data['displayName']?.split(' ').first ??
              'Unknown',
          'lastName':
              data['lastName'] ?? data['displayName']?.split(' ').last ?? '',
          'email': data['email'] ?? '',
          'phone': data['phone'] ?? data['phoneNumber'] ?? '',
          'createdAt': data['createdAt']?.toDate() ?? DateTime.now(),
          'orderCount': data['orderCount'] ?? 0,
          'totalSpent': data['totalSpent']?.toDouble() ?? 0.0,
        };
      }).where((user) => user != null).cast<Map<String, dynamic>>().toList();
    });
  }

  // Real-time stream for services
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
          'name': data['name'] ?? '',
          'description': data['description'] ?? '',
          'price': data['price']?.toDouble() ?? 0.0,
          'category': data['category'] ?? '',
          'image': data['image'] ?? '',
          'order': data['order'] ?? 0,
          'isActive': data['isActive'] ?? true,
        };
      }).toList();
    });
  }

  // Real-time stream for prepaid packs
  Stream<List<Map<String, dynamic>>> getPrepaidPacksStream() {
    return _firestore
        .collection('prepaid_packs')
        .orderBy('order')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'id': doc.id,
          'name': data['name'] ?? '',
          'description': data['description'] ?? '',
          'price': data['price']?.toDouble() ?? 0.0,
          'originalPrice': data['originalPrice']?.toDouble() ?? 0.0,
          'services': data['services'] ?? [],
          'order': data['order'] ?? 0,
          'isActive': data['isActive'] ?? true,
        };
      }).toList();
    });
  }

  // ─── FIXED: Real-time stream for collection time slots ───────────────────
  // Uses nested snapshots() instead of asyncMap + .get() so slot-level
  // edits from the admin panel are reflected immediately in the main app.
  Stream<List<Map<String, dynamic>>> getCollectionTimeslotsStream() {
    debugPrint(
        'FirebaseAdminService: Starting collection time slots stream...');

    return _firestore
        .collection('collection_slots')
        .orderBy('order')
        .snapshots()
        .switchMap((daysSnapshot) {
      debugPrint(
          'FirebaseAdminService: Received ${daysSnapshot.docs.length} collection days');

      if (daysSnapshot.docs.isEmpty) {
        return Stream.value(<Map<String, dynamic>>[]);
      }

      // One live slots-stream per day document
      final dayStreams =
          daysSnapshot.docs.map((dayDoc) {
        final dayData = dayDoc.data() as Map<String, dynamic>;
        final dayId   = dayDoc.id;
        final dayName = dayData['day_name'] as String? ?? dayId;

        return _firestore
            .collection('collection_slots')
            .doc(dayId)
            .collection('slots')
            .orderBy('start')
            .snapshots()
            .map((slotSnap) {
          debugPrint(
              'FirebaseAdminService: Collection $dayName — ${slotSnap.docs.length} slots updated');

          return slotSnap.docs.map((slotDoc) {
            final s = slotDoc.data() as Map<String, dynamic>;
            return <String, dynamic>{
              'id':              slotDoc.id,
              'dayId':           dayId,
              'dayName':         dayName,
              'day':             dayName,
              'startTime':       s['start']   ?? '',
              'endTime':         s['end']     ?? '',
              'maxBookings':     s['max']     ?? 5,
              'currentBookings': s['current'] ?? 0,
              'isAvailable':
                  (s['current'] ?? 0) < (s['max'] ?? 5) &&
                  (s['isOpen'] as bool? ?? true),
              'isActive': s['isOpen'] as bool? ?? true,
              'start':    s['start']  ?? '',
              'end':      s['end']    ?? '',
              'max':      s['max']    ?? 5,
              'current':  s['current'] ?? 0,
              'isOpen':   s['isOpen'] as bool? ?? true,
              'type':     'collection',
            };
          }).toList();
        });
      }).toList();

      // Combine all per-day streams into one flat list
      return Rx.combineLatest<List<Map<String, dynamic>>,
          List<Map<String, dynamic>>>(
        dayStreams,
        (lists) => lists.expand((l) => l).toList(),
      );
    }).handleError((error) {
      debugPrint(
          'FirebaseAdminService: Error in collection timeslots stream: $error');
      return <Map<String, dynamic>>[];
    });
  }

  // ─── FIXED: Real-time stream for delivery time slots ─────────────────────
  Stream<List<Map<String, dynamic>>> getDeliveryTimeslotsStream() {
    debugPrint(
        'FirebaseAdminService: Starting delivery time slots stream...');

    return _firestore
        .collection('delivery_slots')
        .orderBy('order')
        .snapshots()
        .switchMap((daysSnapshot) {
      debugPrint(
          'FirebaseAdminService: Received ${daysSnapshot.docs.length} delivery days');

      if (daysSnapshot.docs.isEmpty) {
        return Stream.value(<Map<String, dynamic>>[]);
      }

      final dayStreams =
          daysSnapshot.docs.map((dayDoc) {
        final dayData = dayDoc.data() as Map<String, dynamic>;
        final dayId   = dayDoc.id;
        final dayName = dayData['day_name'] as String? ?? dayId;

        return _firestore
            .collection('delivery_slots')
            .doc(dayId)
            .collection('slots')
            .orderBy('start')
            .snapshots()
            .map((slotSnap) {
          debugPrint(
              'FirebaseAdminService: Delivery $dayName — ${slotSnap.docs.length} slots updated');

          return slotSnap.docs.map((slotDoc) {
            final s = slotDoc.data() as Map<String, dynamic>;
            return <String, dynamic>{
              'id':              slotDoc.id,
              'dayId':           dayId,
              'dayName':         dayName,
              'day':             dayName,
              'startTime':       s['start']   ?? '',
              'endTime':         s['end']     ?? '',
              'maxBookings':     s['max']     ?? 5,
              'currentBookings': s['current'] ?? 0,
              'isAvailable':
                  (s['current'] ?? 0) < (s['max'] ?? 5) &&
                  (s['isOpen'] as bool? ?? true),
              'isActive': s['isOpen'] as bool? ?? true,
              'start':    s['start']  ?? '',
              'end':      s['end']    ?? '',
              'max':      s['max']    ?? 5,
              'current':  s['current'] ?? 0,
              'isOpen':   s['isOpen'] as bool? ?? true,
              'type':     'delivery',
            };
          }).toList();
        });
      }).toList();

      return Rx.combineLatest<List<Map<String, dynamic>>,
          List<Map<String, dynamic>>>(
        dayStreams,
        (lists) => lists.expand((l) => l).toList(),
      );
    }).handleError((error) {
      debugPrint(
          'FirebaseAdminService: Error in delivery timeslots stream: $error');
      return <Map<String, dynamic>>[];
    });
  }

  // Analytics data stream
  Stream<Map<String, dynamic>> getAnalyticsStream() {
    return _firestore.collection('orders').snapshots().map((snapshot) {
      final orders = snapshot.docs;

      double totalRevenue = 0.0;
      int totalOrders = orders.length;
      Map<String, int> statusCounts = {};
      Map<String, int> serviceCounts = {};

      for (final order in orders) {
        final data = order.data() as Map<String, dynamic>;
        final status = data['status'] ?? 'pending';
        final amount = data['transactionAmount']?.toDouble() ?? 0.0;

        totalRevenue += amount;
        statusCounts[status] = (statusCounts[status] ?? 0) + 1;

        final bookingData =
            Map<String, dynamic>.from(data['bookingData'] ?? {});
        final selectedItems = bookingData['selectedItems'];
        List<dynamic> itemsList = [];

        if (selectedItems is List) {
          itemsList = selectedItems;
        } else if (selectedItems is Map) {
          itemsList = selectedItems.values.whereType<Map>().toList();
        }

        if (itemsList.isNotEmpty) {
          for (final item in itemsList) {
            final serviceName = item['itemType'] ?? item['name'] ?? item['category'] ?? 'Service';
            serviceCounts[serviceName] =
                (serviceCounts[serviceName] ?? 0) + 1;
          }
        } else {
          // Bag / Service order without itemized items
          final services = bookingData['selectedServices'] ?? data['selectedServices'] ?? data['services'] ?? bookingData['services'];
          if (services is List && services.isNotEmpty) {
            for (final s in services) {
              final str = s?.toString().trim() ?? '';
              if (str.isNotEmpty) serviceCounts[str] = (serviceCounts[str] ?? 0) + 1;
            }
          } else if (bookingData['prepaidPackName'] != null) {
            final name = 'Prepaid: ${bookingData['prepaidPackName']}';
            serviceCounts[name] = (serviceCounts[name] ?? 0) + 1;
          } else {
            serviceCounts['Standard Cleaning'] = (serviceCounts['Standard Cleaning'] ?? 0) + 1;
          }
        }
      }

      return {
        'totalRevenue': totalRevenue,
        'totalOrders': totalOrders,
        'statusCounts': statusCounts,
        'serviceCounts': serviceCounts,
        'averageOrderValue':
            totalOrders > 0 ? totalRevenue / totalOrders : 0.0,
      };
    });
  }

  // ─── Write methods ────────────────────────────────────────────────────────

  static Map<String, String>? _notificationForStatus(String status, String displayOrderId) {
    final id = displayOrderId.isNotEmpty ? '#$displayOrderId' : 'your order';
    switch (status.toLowerCase()) {
      case 'confirmed':
        return {'title': 'Booking confirmed', 'body': 'Your collection slot for $id is confirmed.', 'theme': 'blue', 'icon': 'event_available'};
      case 'pickup_assigned':
        return {'title': 'Driver assigned', 'body': 'A driver has been assigned to collect $id.', 'theme': 'blue', 'icon': 'person_pin'};
      case 'pickup_en_route':
        return {'title': 'Driver is on the way', 'body': 'Tap to follow your driver live on the map.', 'theme': 'blue', 'icon': 'local_shipping'};
      case 'pickup_arrived':
        return {'title': 'Your driver is outside', 'body': 'Please hand over your bags at the door.', 'theme': 'mint', 'icon': 'where_to_vote'};
      case 'collected':
        return {'title': 'Bags collected', 'body': '$id has been collected and is heading to our facility.', 'theme': 'mint', 'icon': 'inventory'};
      case 'at_facility':
        return {'title': 'Arrived at our facility', 'body': 'We are checking every item in $id.', 'theme': 'violet', 'icon': 'warehouse'};
      case 'awaiting_approval':
        return {'title': 'Please approve your order', 'body': 'Items counted for $id — tap to review & approve before cleaning.', 'theme': 'amber', 'icon': 'pending_actions'};
      case 'cleaning':
        return {'title': 'Cleaning started', 'body': '$id is now being eco-cleaned.', 'theme': 'violet', 'icon': 'laundry'};
      case 'ready_for_delivery':
        return {'title': 'Ready for delivery', 'body': '$id is cleaned, pressed and packed.', 'theme': 'mint', 'icon': 'checkroom'};
      case 'delivery_assigned':
        return {'title': 'Delivery booked', 'body': 'A driver is scheduled to deliver $id.', 'theme': 'blue', 'icon': 'person_pin'};
      case 'out_for_delivery':
        return {'title': 'Driver is bringing your order', 'body': 'Tap to follow your driver live on the map.', 'theme': 'blue', 'icon': 'local_shipping'};
      case 'delivery_arrived':
        return {'title': 'Your driver is outside', 'body': 'Your clean clothes for $id are at your door.', 'theme': 'mint', 'icon': 'where_to_vote'};
      case 'delivered':
        return {'title': 'Delivered — thank you!', 'body': '$id has been delivered. Your receipt is ready.', 'theme': 'mint', 'icon': 'check_circle'};
      case 'cancelled':
        return {'title': 'Order cancelled', 'body': '$id has been cancelled. Call us if you need help.', 'theme': 'amber', 'icon': 'cancel'};
      default:
        return null;
    }
  }

  Future<void> updateOrderStatus(String orderId, String newStatus) async {
    try {
      final ref = _firestore.collection('orders').doc(orderId);
      final snap = await ref.get();
      final data = snap.data() ?? {};
      final userId = (data['userId'] ?? '').toString();
      final displayId = (data['orderId'] ?? '').toString();

      final b = _firestore.batch();
      b.update(ref, {
        'status': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
        if (newStatus == 'delivered') 'deliveredAt': FieldValue.serverTimestamp(),
      });
      // Same timeline the driver and intake apps write, so the customer sees every step.
      b.set(ref.collection('history').doc(), {'status': newStatus, 'at': FieldValue.serverTimestamp(), 'byRole': 'admin', 'note': 'Updated in the admin panel'});

      // Also write in-app customer notification directly so it arrives instantaneously without Blaze Cloud Functions
      final notif = _notificationForStatus(newStatus, displayId);
      if (notif != null && userId.isNotEmpty && userId != 'website_guest' && userId != 'dummy') {
        final notifRef = _firestore.collection('users').doc(userId).collection('notifications').doc();
        b.set(notifRef, {
          'title': notif['title'],
          'body': notif['body'],
          'category': 'orders',
          'theme': notif['theme'],
          'icon': notif['icon'],
          'orderId': orderId,
          'displayOrderId': displayId,
          'status': newStatus,
          'read': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      await b.commit();

      // Fire-and-forget FCM push so the user gets an OS-level notification
      // even when the app is completely closed / killed.
      if (notif != null && userId.isNotEmpty && userId != 'website_guest' && userId != 'dummy') {
        PushService.send(
          userId: userId,
          title: notif['title']!,
          body: notif['body']!,
          data: {'type': 'order', 'orderId': orderId},
        );
      }
    } catch (e) {
      debugPrint('FirebaseAdminService: Error updating order status: $e');
      rethrow;
    }
  }

  Future<void> updateOrderPrice(String orderId, double newPrice) async {
    try {
      await _firestore.collection('orders').doc(orderId).update({
        'transactionAmount': newPrice,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('FirebaseAdminService: Error updating order price: $e');
      rethrow;
    }
  }

  Future<void> updatePaymentStatus(String orderId, String paymentStatus) async {
    try {
      final ref = _firestore.collection('orders').doc(orderId);
      final snap = await ref.get();
      final data = snap.data() ?? {};
      final userId = (data['userId'] ?? '').toString();
      final displayId = (data['orderId'] ?? orderId).toString();
      final isPaid = paymentStatus == 'paid';

      final b = _firestore.batch();
      b.update(ref, {
        'paymentStatus': paymentStatus,
        if (isPaid) 'paidAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      b.set(ref.collection('history').doc(), {
        'status': isPaid ? 'payment_paid' : 'payment_pending',
        'at': FieldValue.serverTimestamp(),
        'byRole': 'admin',
        'note': isPaid ? 'Marked as Paid in Admin Panel' : 'Marked as Unpaid in Admin Panel',
      });

      if (isPaid && userId.isNotEmpty && userId != 'website_guest' && userId != 'dummy') {
        b.set(_firestore.collection('users').doc(userId).collection('notifications').doc(), {
          'title': 'Payment received — thank you!',
          'body': 'Payment for #$displayId has been confirmed.',
          'category': 'orders',
          'theme': 'mint',
          'icon': 'check_circle',
          'orderId': orderId,
          'displayOrderId': displayId,
          'status': (data['status'] ?? '').toString(),
          'read': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      await b.commit();

      if (isPaid && userId.isNotEmpty && userId != 'website_guest' && userId != 'dummy') {
        PushService.send(
          userId: userId,
          title: 'Payment received — thank you!',
          body: 'Payment for #$displayId has been confirmed.',
          data: {'type': 'order', 'orderId': orderId},
        );
      }
    } catch (e) {
      debugPrint('FirebaseAdminService: Error updating payment status: $e');
      rethrow;
    }
  }

  Future<void> updateService(
      String serviceId, Map<String, dynamic> updates) async {
    try {
      await _firestore.collection('services').doc(serviceId).update({
        ...updates,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('FirebaseAdminService: Error updating service: $e');
      rethrow;
    }
  }

  Future<void> addService(Map<String, dynamic> serviceData) async {
    try {
      await _firestore.collection('services').add({
        ...serviceData,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('FirebaseAdminService: Error adding service: $e');
      rethrow;
    }
  }

  Future<void> updatePrepaidPack(
      String packId, Map<String, dynamic> updates) async {
    try {
      await _firestore.collection('prepaid_packs').doc(packId).update({
        ...updates,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('FirebaseAdminService: Error updating prepaid pack: $e');
      rethrow;
    }
  }

  Future<void> updateTimeSlot(
      String type, String day, String slotId, Map<String, dynamic> updates) async {
    try {
      final collection =
          type == 'collection' ? 'collection_slots' : 'delivery_slots';
      final slotRef = _firestore
          .collection(collection)
          .doc(day)
          .collection('slots')
          .doc(slotId);

      await slotRef.update({
        'isOpen':  updates['isOpen']      ?? true,
        'start':   updates['startTime']   ?? updates['start'],
        'end':     updates['endTime']     ?? updates['end'],
        'max':     updates['maxBookings'] ?? updates['max'],
        'updatedAt': FieldValue.serverTimestamp(),
      });
      debugPrint(
          'FirebaseAdminService: Updated $type time slot $slotId for $day');
    } catch (e) {
      debugPrint('FirebaseAdminService: Error updating time slot: $e');
      rethrow;
    }
  }

  Future<void> updateDayOpenStatus(
      String type, String day, bool isOpen) async {
    try {
      final collection =
          type == 'collection' ? 'collection_slots' : 'delivery_slots';
      await _firestore.collection(collection).doc(day).update({
        'isOpen':    isOpen,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      debugPrint(
          'FirebaseAdminService: Updated $type day $day isOpen to $isOpen');
    } catch (e) {
      debugPrint('FirebaseAdminService: Error updating day status: $e');
      rethrow;
    }
  }

  Future<void> addTimeSlot(
      String type, String day, Map<String, dynamic> slotData) async {
    try {
      final collection =
          type == 'collection' ? 'collection_slots' : 'delivery_slots';
      final newSlotRef = _firestore
          .collection(collection)
          .doc(day)
          .collection('slots')
          .doc();

      await newSlotRef.set({
        ...slotData,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      debugPrint(
          'FirebaseAdminService: Added $type time slot for $day');
    } catch (e) {
      debugPrint('FirebaseAdminService: Error adding time slot: $e');
      rethrow;
    }
  }

  Future<void> removeTimeSlot(
      String type, String day, String slotId) async {
    try {
      final collection =
          type == 'collection' ? 'collection_slots' : 'delivery_slots';
      await _firestore
          .collection(collection)
          .doc(day)
          .collection('slots')
          .doc(slotId)
          .delete();
      debugPrint(
          'FirebaseAdminService: Removed $type time slot $slotId for $day');
    } catch (e) {
      debugPrint('FirebaseAdminService: Error removing time slot: $e');
      rethrow;
    }
  }

  Future<void> toggleTimeSlotAvailability(
      String type, String day, String slotId) async {
    try {
      final collection =
          type == 'collection' ? 'collection_slots' : 'delivery_slots';
      final slotRef = _firestore
          .collection(collection)
          .doc(day)
          .collection('slots')
          .doc(slotId);

      final docSnapshot = await slotRef.get();
      if (docSnapshot.exists) {
        final data = docSnapshot.data() as Map<String, dynamic>;
        final currentIsOpen = data['isOpen'] as bool? ?? true;
        await slotRef.update({
          'isOpen':    !currentIsOpen,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      debugPrint(
          'FirebaseAdminService: Error toggling time slot availability: $e');
      rethrow;
    }
  }

  // ─── Offers ───────────────────────────────────────────────────────────────

  // Real-time stream for offers
  Stream<List<Map<String, dynamic>>> getOffersStream() {
    debugPrint('FirebaseAdminService: Starting offers stream...');
    return _firestore
        .collection('offers')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      debugPrint(
          'FirebaseAdminService: Received ${snapshot.docs.length} offers');
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'id':           doc.id,
          'title':        data['title']        ?? '',
          'description':  data['description']  ?? '',
          'discountCode': data['discountCode']  ?? '',
          'discountValue': data['discountValue'] ?? 0.0,
          'discountType':  data['discountType']  ?? 'percentage',
          'tag':          data['tag']           ?? '',
          'image':        data['image']         ?? '',
          'isActive':     data['isActive']      ?? true,
          'expiryDate':   (data['expiryDate'] as Timestamp?)?.toDate(),
          'createdAt':    (data['createdAt'] as Timestamp?)?.toDate() ??
              DateTime.now(),
        };
      }).toList();
    });
  }

  Future<void> addOffer(Map<String, dynamic> offerData) async {
    try {
      await _firestore.collection('offers').add({
        'title':         offerData['title']         ?? '',
        'description':   offerData['description']   ?? '',
        'discountCode':  offerData['discountCode']  ?? '',
        'discountValue': offerData['discountValue'] ?? 0.0,
        'discountType':  offerData['discountType']  ?? 'percentage',
        'tag':           offerData['tag']           ?? '',
        'image':         offerData['image']         ?? '',
        'isActive':      offerData['isActive']      ?? true,
        'expiryDate':   offerData['expiryDate'] != null
            ? Timestamp.fromDate(offerData['expiryDate'] as DateTime)
            : null,
        'createdAt':    FieldValue.serverTimestamp(),
        'updatedAt':    FieldValue.serverTimestamp(),
      });
      debugPrint('FirebaseAdminService: Added new offer');
    } catch (e) {
      debugPrint('FirebaseAdminService: Error adding offer: $e');
      rethrow;
    }
  }

  Future<void> updateOffer(
      String offerId, Map<String, dynamic> updates) async {
    try {
      await _firestore.collection('offers').doc(offerId).update({
        'title':         updates['title']         ?? '',
        'description':   updates['description']   ?? '',
        'discountCode':  updates['discountCode']  ?? '',
        'discountValue': updates['discountValue'] ?? 0.0,
        'discountType':  updates['discountType']  ?? 'percentage',
        'tag':           updates['tag']           ?? '',
        'image':         updates['image']         ?? '',
        'isActive':      updates['isActive']      ?? true,
        'expiryDate':   updates['expiryDate'] != null
            ? Timestamp.fromDate(updates['expiryDate'] as DateTime)
            : null,
        'updatedAt':    FieldValue.serverTimestamp(),
      });
      debugPrint('FirebaseAdminService: Updated offer $offerId');
    } catch (e) {
      debugPrint('FirebaseAdminService: Error updating offer: $e');
      rethrow;
    }
  }

  Future<void> deleteOffer(String offerId) async {
    try {
      await _firestore.collection('offers').doc(offerId).delete();
      debugPrint('FirebaseAdminService: Deleted offer $offerId');
    } catch (e) {
      debugPrint('FirebaseAdminService: Error deleting offer: $e');
      rethrow;
    }
  }

  Future<void> toggleOfferActive(String offerId, bool isActive) async {
    try {
      await _firestore.collection('offers').doc(offerId).update({
        'isActive':  isActive,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      debugPrint(
          'FirebaseAdminService: Toggled offer $offerId isActive=$isActive');
    } catch (e) {
      debugPrint('FirebaseAdminService: Error toggling offer: $e');
      rethrow;
    }
  }

  Future<String?> getUserFCMToken(String userId) async {
    try {
      if (userId.isEmpty) return null;
      final doc = await _firestore.collection('users').doc(userId).get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        return data['fcmToken'] as String?;
      }
      return null;
    } catch (e) {
      debugPrint('FirebaseAdminService: Error getting user FCM token: $e');
      return null;
    }
  }

  Future<void> removeUserFCMToken(String userId) async {
    try {
      if (userId.isEmpty) return;
      await _firestore.collection('users').doc(userId).update({
        'fcmToken': FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      debugPrint('FirebaseAdminService: Removed invalid FCM token for user: $userId');
    } catch (e) {
      debugPrint('FirebaseAdminService: Error removing user FCM token: $e');
    }
  }
}