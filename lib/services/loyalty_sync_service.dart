import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'push_service.dart';

/// Atomic spend-based loyalty card synchronizer for DryClean Plus.
///
/// Rules:
/// - Qualifying orders: status in ('delivered', 'completed') AND paymentStatus in ('paid', 'paid_on_delivery').
/// - Only the customer's self-paid amount counts (`max(0, finalTotal - loyaltyCreditUsed)`).
/// - After 5 qualifying orders in a round, awards free cleaning credit equal to `roundTotal / 5`,
///   records the completed round in `rewardHistory`, unlocks `lastUnlockedReward`, and resets for the next round.
class LoyaltySyncService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static double _round2(num v) => (v * 100).roundToDouble() / 100.0;

  static String _cardNumberForUid(String uid) {
    int hash = 0;
    for (final code in uid.codeUnits) {
      hash = (hash * 31 + code) & 0x7fffffff;
    }
    return ((hash % 9000) + 1000).toString().padLeft(4, '0');
  }

  static bool isCompletedStatus(String status) {
    final s = status.trim().toLowerCase();
    return s == 'delivered' || s == 'completed';
  }

  static bool isPaidPaymentStatus(String paymentStatus, [String paymentMethod = '']) {
    final p = paymentStatus.trim().toLowerCase();
    final m = paymentMethod.trim().toLowerCase();
    return p == 'paid' || p == 'paid_on_delivery' || m == 'paid';
  }

  /// Evaluates `orders/{orderDocId}` inside an atomic Firestore transaction.
  /// Safe to call repeatedly — uses `loyaltyCounted` to prevent double-counting.
  static Future<void> syncOrderById(String orderDocId) async {
    if (orderDocId.isEmpty) return;
    final orderRef = _db.collection('orders').doc(orderDocId);
    Map<String, dynamic>? pushEvent;

    try {
      await _db.runTransaction((tx) async {
        final orderSnap = await tx.get(orderRef);
        if (!orderSnap.exists) return;
        final o = orderSnap.data() ?? {};

        final userId = (o['userId'] ?? '').toString().trim();
        if (userId.isEmpty || userId == 'website_guest' || userId == 'dummy') return;

        final status = (o['status'] ?? '').toString();
        final b = (o['bookingData'] is Map) ? Map<String, dynamic>.from(o['bookingData']) : <String, dynamic>{};
        final pStatus = (o['paymentStatus'] ?? b['paymentStatus'] ?? '').toString();
        final pMethod = (o['paymentMethod'] ?? b['paymentMethod'] ?? '').toString();

        final bool qualifies = isCompletedStatus(status) && isPaidPaymentStatus(pStatus, pMethod);
        final bool alreadyCounted = o['loyaltyCounted'] == true;

        final double total = (o['transactionAmount'] as num?)?.toDouble() ??
            (o['totalAmount'] as num?)?.toDouble() ??
            (o['finalAmount'] as num?)?.toDouble() ??
            (b['totalPrice'] as num?)?.toDouble() ??
            0.0;
        final double creditUsed = (o['loyaltyCreditUsed'] as num?)?.toDouble() ??
            (b['loyaltyCreditUsed'] as num?)?.toDouble() ??
            0.0;
        final double selfPaid = _round2(math.max(0.0, total - creditUsed));
        final String displayOrderId = (o['orderId'] ?? orderDocId).toString();

        final userRef = _db.collection('users').doc(userId);
        final userSnap = await tx.get(userRef);
        final uData = userSnap.data() ?? {};
        final Map<String, dynamic> loyalty = (uData['loyalty'] is Map)
            ? Map<String, dynamic>.from(uData['loyalty'])
            : <String, dynamic>{};

        final String cardNo = (loyalty['cardNumber'] ?? '').toString().isNotEmpty
            ? loyalty['cardNumber'].toString()
            : _cardNumberForUid(userId);
        int activeRound = (loyalty['activeRound'] as num?)?.toInt() ?? 1;
        double currentTotalPaid = (loyalty['currentTotalPaid'] as num?)?.toDouble() ?? 0.0;
        double availableCredit = (loyalty['availableCredit'] as num?)?.toDouble() ?? 0.0;
        double totalCreditEarned = (loyalty['totalCreditEarned'] as num?)?.toDouble() ?? 0.0;
        int lifetimeOrders = (loyalty['lifetimeQualifyingOrders'] as num?)?.toInt() ?? 0;

        final List<Map<String, dynamic>> roundOrders = ((loyalty['currentRoundOrders'] as List?) ?? const [])
            .whereType<Map>()
            .map((m) => Map<String, dynamic>.from(m))
            .toList();
        final List<Map<String, dynamic>> rewardHistory = ((loyalty['rewardHistory'] as List?) ?? const [])
            .whereType<Map>()
            .map((m) => Map<String, dynamic>.from(m))
            .toList();

        if (qualifies && !alreadyCounted && selfPaid > 0) {
          final existingIdx = roundOrders.indexWhere((e) => e['orderDocId'] == orderDocId);
          if (existingIdx != -1) return;

          final nowIso = DateTime.now().toUtc().toIso8601String();
          roundOrders.add({
            'orderDocId': orderDocId,
            'orderId': displayOrderId,
            'paidAmount': selfPaid,
            'dateIso': nowIso,
          });
          currentTotalPaid = _round2(currentTotalPaid + selfPaid);
          lifetimeOrders += 1;

          if (roundOrders.length >= 5) {
            final unlockedRound = activeRound;
            final rewardCredit = _round2(currentTotalPaid / 5.0);
            final rewardRecord = {
              'round': unlockedRound,
              'unlockedAtIso': nowIso,
              'totalSpent': currentTotalPaid,
              'creditEarned': rewardCredit,
              'status': 'available',
              'orders': List<Map<String, dynamic>>.from(roundOrders),
            };
            rewardHistory.insert(0, rewardRecord);
            availableCredit = _round2(availableCredit + rewardCredit);
            totalCreditEarned = _round2(totalCreditEarned + rewardCredit);

            tx.set(
              userRef,
              {
                'loyalty': {
                  'cardNumber': cardNo,
                  'activeRound': unlockedRound + 1,
                  'currentCount': 0,
                  'currentTotalPaid': 0.0,
                  'availableCredit': availableCredit,
                  'totalCreditEarned': totalCreditEarned,
                  'lifetimeQualifyingOrders': lifetimeOrders,
                  'currentRoundOrders': <Map<String, dynamic>>[],
                  'rewardHistory': rewardHistory,
                  'lastUnlockedReward': rewardRecord,
                  'updatedAt': FieldValue.serverTimestamp(),
                },
              },
              SetOptions(merge: true),
            );
            tx.update(orderRef, {
              'loyaltyCounted': true,
              'loyaltyRound': unlockedRound,
              'loyaltyPaidAmount': selfPaid,
            });
            final notifRef = userRef.collection('notifications').doc();
            tx.set(notifRef, {
              'title': 'Reward unlocked! £${rewardCredit.toStringAsFixed(2)} free credit',
              'body': 'You completed 5 orders (£${currentTotalPaid.toStringAsFixed(2)} total). Use £${rewardCredit.toStringAsFixed(2)} off your next booking!',
              'category': 'loyalty',
              'theme': 'mint',
              'icon': 'card_giftcard',
              'orderId': orderDocId,
              'read': false,
              'createdAt': FieldValue.serverTimestamp(),
            });
            pushEvent = {
              'userId': userId,
              'title': 'Reward unlocked! £${rewardCredit.toStringAsFixed(2)} free credit',
              'body': 'You completed 5 orders — £${rewardCredit.toStringAsFixed(2)} free cleaning credit is ready to use.',
            };
          } else {
            final newCount = roundOrders.length;
            tx.set(
              userRef,
              {
                'loyalty': {
                  'cardNumber': cardNo,
                  'activeRound': activeRound,
                  'currentCount': newCount,
                  'currentTotalPaid': currentTotalPaid,
                  'availableCredit': availableCredit,
                  'totalCreditEarned': totalCreditEarned,
                  'lifetimeQualifyingOrders': lifetimeOrders,
                  'currentRoundOrders': roundOrders,
                  'rewardHistory': rewardHistory,
                  if (loyalty['lastUnlockedReward'] != null) 'lastUnlockedReward': loyalty['lastUnlockedReward'],
                  'updatedAt': FieldValue.serverTimestamp(),
                },
              },
              SetOptions(merge: true),
            );
            tx.update(orderRef, {
              'loyaltyCounted': true,
              'loyaltyRound': activeRound,
              'loyaltyPaidAmount': selfPaid,
            });
            final left = 5 - newCount;
            pushEvent = {
              'userId': userId,
              'title': 'Loyalty stamp $newCount of 5 added',
              'body': '£${selfPaid.toStringAsFixed(2)} counted from #$displayOrderId. Just $left more order${left == 1 ? '' : 's'} to unlock free credit!',
            };
          }
        } else if (!qualifies && alreadyCounted) {
          // Order cancelled or reverted from delivered/paid while in active round
          final idx = roundOrders.indexWhere((e) => e['orderDocId'] == orderDocId);
          if (idx != -1) {
            final removedAmt = (roundOrders[idx]['paidAmount'] as num?)?.toDouble() ?? selfPaid;
            roundOrders.removeAt(idx);
            currentTotalPaid = _round2(math.max(0.0, currentTotalPaid - removedAmt));
            lifetimeOrders = math.max(0, lifetimeOrders - 1);
            tx.set(
              userRef,
              {
                'loyalty': {
                  'cardNumber': cardNo,
                  'activeRound': activeRound,
                  'currentCount': roundOrders.length,
                  'currentTotalPaid': currentTotalPaid,
                  'availableCredit': availableCredit,
                  'totalCreditEarned': totalCreditEarned,
                  'lifetimeQualifyingOrders': lifetimeOrders,
                  'currentRoundOrders': roundOrders,
                  'rewardHistory': rewardHistory,
                  if (loyalty['lastUnlockedReward'] != null) 'lastUnlockedReward': loyalty['lastUnlockedReward'],
                  'updatedAt': FieldValue.serverTimestamp(),
                },
              },
              SetOptions(merge: true),
            );
            tx.update(orderRef, {
              'loyaltyCounted': false,
            });
          }
        }
      });

      if (pushEvent != null) {
        PushService.send(
          userId: pushEvent!['userId'] as String,
          title: pushEvent!['title'] as String,
          body: pushEvent!['body'] as String,
          data: {'type': 'loyalty', 'orderId': orderDocId},
        );
      }
    } catch (e) {
      debugPrint('LoyaltySyncService.syncOrderById($orderDocId) error: $e');
    }
  }

  /// Refunds unused loyalty credit back to customer if an order using credit is cancelled.
  static Future<void> refundCreditIfCancelled(String orderDocId) async {
    if (orderDocId.isEmpty) return;
    final orderRef = _db.collection('orders').doc(orderDocId);
    try {
      await _db.runTransaction((tx) async {
        final snap = await tx.get(orderRef);
        if (!snap.exists) return;
        final o = snap.data() ?? {};
        final userId = (o['userId'] ?? '').toString().trim();
        if (userId.isEmpty || userId == 'website_guest' || userId == 'dummy') return;
        if (o['loyaltyCreditRefunded'] == true) return;
        final double used = (o['loyaltyCreditUsed'] as num?)?.toDouble() ?? 0.0;
        if (used <= 0) return;

        final userRef = _db.collection('users').doc(userId);
        final uSnap = await tx.get(userRef);
        final uData = uSnap.data() ?? {};
        final Map<String, dynamic> loyalty = (uData['loyalty'] is Map)
            ? Map<String, dynamic>.from(uData['loyalty'])
            : <String, dynamic>{};
        final double avail = (loyalty['availableCredit'] as num?)?.toDouble() ?? 0.0;

        tx.set(
          userRef,
          {
            'loyalty': {
              ...loyalty,
              'availableCredit': _round2(avail + used),
              'updatedAt': FieldValue.serverTimestamp(),
            },
          },
          SetOptions(merge: true),
        );
        tx.update(orderRef, {'loyaltyCreditRefunded': true});
      });
    } catch (e) {
      debugPrint('LoyaltySyncService.refundCreditIfCancelled($orderDocId) error: $e');
    }
  }
}
