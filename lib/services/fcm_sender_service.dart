import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

/// Sends admin broadcasts through the server (Cloud Function `sendBroadcast`).
///
/// The console no longer holds any Firebase secret: the server checks that the
/// signed-in user is an admin, then sends the push. Order updates (driver on the way,
/// delivered, …) are sent automatically by the server, so token sends are no-ops here.
class FCMSenderService {
  final _fn = FirebaseFunctions.instanceFor(region: 'europe-west2').httpsCallable('sendBroadcast');

  Future<Map<String, dynamic>> sendNotification({
    required String title,
    required String body,
    String? topic,
    String? token,
    Map<String, dynamic>? data,
  }) async {
    if (token != null && topic == null) {
      // The server notifies customers automatically on every status change.
      return {'success': true, 'skipped': true};
    }
    try {
      final res = await _fn.call<Map<String, dynamic>>({
        'title': title,
        'body': body,
        'topic': topic ?? 'offers',
        'data': data ?? const {},
      });
      return {'success': true, ...Map<String, dynamic>.from(res.data)};
    } on FirebaseFunctionsException catch (e) {
      debugPrint('sendBroadcast failed: ${e.code} ${e.message}');
      return {'success': false, 'error': e.message ?? e.code};
    } catch (e) {
      debugPrint('sendBroadcast failed: $e');
      return {'success': false, 'error': '$e'};
    }
  }
}
