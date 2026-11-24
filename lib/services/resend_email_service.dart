import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Direct, 100% Free Email Dispatch Service for DryClean Plus Admin Panel
/// Dispatches via the secure DryClean Plus serverless endpoint (£0.00 cost, zero deposit).
class ResendEmailService {
  ResendEmailService._();
  static final ResendEmailService instance = ResendEmailService._();

  static const String _apiEndpoint = 'https://drycleanplus.co.uk/api/send-email';

  /// Sends email via the secure DryClean Plus serverless mail endpoint
  Future<Map<String, dynamic>> sendEmail({
    required String to,
    required String type,
    required Map<String, dynamic> order,
    String? orderDocId,
  }) async {
    if (to.isEmpty || !to.contains('@')) {
      debugPrint('[ResendEmailService] Invalid recipient email: $to');
      return {'success': false, 'error': 'Invalid recipient email'};
    }

    try {
      final res = await http.post(
        Uri.parse(_apiEndpoint),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'type': type,
          'recipientEmail': to.trim(),
          'order': order,
        }),
      );

      final isSuccess = res.statusCode >= 200 && res.statusCode < 300;
      debugPrint('[ResendEmailService] Dispatch to $to [$type] result: ${res.statusCode}');

      if (isSuccess && orderDocId != null && orderDocId.isNotEmpty) {
        try {
          await FirebaseFirestore.instance
              .collection('orders')
              .doc(orderDocId)
              .collection('history')
              .add({
            'status': 'email_$type',
            'title': type == 'awaiting_approval'
                ? 'Approval bill email sent'
                : type == 'delivered'
                    ? 'Official invoice email sent'
                    : 'Customer notification email sent',
            'description': 'Sent to $to via Resend (Free)',
            'at': FieldValue.serverTimestamp(),
            'byRole': 'admin',
          });
        } catch (e) {
          debugPrint('[ResendEmailService] Could not log history: $e');
        }
      }

      return {
        'success': isSuccess,
        'statusCode': res.statusCode,
        'error': isSuccess ? null : res.body,
      };
    } catch (e) {
      debugPrint('[ResendEmailService] Error calling mail endpoint: $e');
      return {'success': false, 'error': '$e'};
    }
  }

  /// 1. Bill Update & Item Approval Email (when order is set to 'awaiting_approval')
  Future<Map<String, dynamic>> sendBillApprovalEmail(Map<String, dynamic> order) async {
    final b = (order['bookingData'] is Map) ? Map<String, dynamic>.from(order['bookingData']) : <String, dynamic>{};
    final recipient = (b['email'] ?? order['email'] ?? '').toString();
    final docId = (order['id'] ?? '').toString();

    return sendEmail(
      to: recipient,
      type: 'awaiting_approval',
      order: order,
      orderDocId: docId,
    );
  }

  /// 2. Delivered Order Official Invoice & Receipt Email (when order is set to 'delivered')
  Future<Map<String, dynamic>> sendDeliveredInvoiceEmail(Map<String, dynamic> order) async {
    final b = (order['bookingData'] is Map) ? Map<String, dynamic>.from(order['bookingData']) : <String, dynamic>{};
    final recipient = (b['email'] ?? order['email'] ?? '').toString();
    final docId = (order['id'] ?? '').toString();

    return sendEmail(
      to: recipient,
      type: 'delivered',
      order: order,
      orderDocId: docId,
    );
  }
}
