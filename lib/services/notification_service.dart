import 'package:dio/dio.dart';
import '../models/notification.dart';
import 'api_error.dart';
import 'dio_client.dart';

/// REST client for the player-facing in-app notification endpoints
/// (see notifications.md). All calls need `Authorization: Bearer <token>`.
class NotificationService {
  NotificationService({Dio? dio, String? baseUrl}) : _dio = dio ?? buildDio(baseUrl);

  final Dio _dio;

  Options _auth(String token) => Options(headers: {'Authorization': 'Bearer $token'});

  /// `GET /notifications` — one page, newest first. [before] is the keyset
  /// cursor from a previous page's `nextBefore`.
  Future<NotificationPage> fetchPage(String token, {int limit = 30, int? before}) async {
    try {
      final query = <String, dynamic>{'limit': limit};
      if (before != null) query['before'] = before;
      final response = await _dio.get('/notifications', queryParameters: query, options: _auth(token));
      return NotificationPage.fromJson((response.data as Map).cast());
    } on DioException catch (e) {
      throw _toException(e);
    }
  }

  /// `GET /notifications/unread-count` — cheap badge poll.
  Future<int> fetchUnreadCount(String token) async {
    try {
      final response = await _dio.get('/notifications/unread-count', options: _auth(token));
      return ((response.data as Map)['unreadCount'] as num?)?.toInt() ?? 0;
    } on DioException catch (e) {
      throw _toException(e);
    }
  }

  /// `POST /notifications/:id/read` — idempotent. Returns the new unread count.
  Future<int> markRead(String token, String id) async {
    try {
      final response = await _dio.post('/notifications/$id/read', options: _auth(token));
      return ((response.data as Map)['unreadCount'] as num?)?.toInt() ?? 0;
    } on DioException catch (e) {
      throw _toException(e);
    }
  }

  /// `POST /notifications/read-all`. Returns the new unread count (0).
  Future<int> markAllRead(String token) async {
    try {
      final response = await _dio.post('/notifications/read-all', options: _auth(token));
      return ((response.data as Map)['unreadCount'] as num?)?.toInt() ?? 0;
    } on DioException catch (e) {
      throw _toException(e);
    }
  }

  /// `POST /notifications/push-token` — idempotent; re-links the FCM token
  /// to this player (moves it off any previous account on this device).
  Future<void> registerPushToken(String token, String fcmToken, {String platform = 'android'}) async {
    try {
      await _dio.post(
        '/notifications/push-token',
        data: {'token': fcmToken, 'platform': platform},
        options: _auth(token),
      );
    } on DioException catch (e) {
      throw _toException(e);
    }
  }

  /// `DELETE /notifications/push-token` — call on logout (with the session
  /// token that is being logged out).
  Future<void> unregisterPushToken(String token, String fcmToken) async {
    try {
      await _dio.delete(
        '/notifications/push-token',
        data: {'token': fcmToken},
        options: _auth(token),
      );
    } on DioException catch (e) {
      throw _toException(e);
    }
  }

  Exception _toException(DioException e) {
    final err = ApiError.from(e);
    return Exception(err.message);
  }
}
