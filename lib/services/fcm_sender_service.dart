import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Sends admin offer/promo push broadcasts through dc-push-service on Render.
class FCMSenderService {
  static const String _baseUrl = 'https://dc-push-service.onrender.com';
  static const String _apiKey = 'dc_push_2026_drycleanplus';

  Future<Map<String, dynamic>> sendNotification({
    required String title,
    required String body,
    String? topic,
    String? token,
    Map<String, dynamic>? data,
  }) async {
    if (token != null && topic == null) {
      // Single-user order updates are dispatched via PushService.send.
      return {'success': true, 'skipped': true};
    }
    try {
      final res = await http
          .post(
            Uri.parse('$_baseUrl/api/send-broadcast'),
            headers: {
              'Content-Type': 'application/json',
              'x-api-key': _apiKey,
            },
            body: jsonEncode({
              'title': title,
              'body': body,
              'topic': topic ?? 'offers',
              'data': data ?? const {},
            }),
          )
          .timeout(const Duration(seconds: 30));
      final decoded = res.body.isNotEmpty ? jsonDecode(res.body) : {};
      final ok = res.statusCode >= 200 && res.statusCode < 300;
      return {
        'success': ok,
        if (decoded is Map) ...decoded.cast<String, dynamic>(),
        if (!ok) 'error': (decoded is Map ? decoded['error'] : null) ?? res.body,
      };
    } catch (e) {
      debugPrint('sendBroadcast failed: $e');
      return {'success': false, 'error': '$e'};
    }
  }
}
