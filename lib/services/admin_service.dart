import 'package:dio/dio.dart';
import 'api_error.dart';
import 'dio_client.dart';

/// Client for admin-guarded endpoints (`/admin-api` anti-cheat and `/notifications` operator actions).
/// Requires `X-Admin-Key: <ADMIN_API_KEY>`.
class AdminService {
  AdminService({Dio? dio, String? baseUrl, String? adminKey})
      : _dio = dio ?? buildDio(baseUrl),
        _adminKey = adminKey;

  final Dio _dio;
  final String? _adminKey;

  Options _adminHeaders([String? key]) {
    final effectiveKey = key ?? _adminKey;
    if (effectiveKey == null || effectiveKey.isEmpty) {
      throw const AdminException('ADMIN_KEY_MISSING', 'کلید مدیریت تنظیم نشده است.');
    }
    return Options(headers: {'X-Admin-Key': effectiveKey});
  }

  /// `GET /admin-api/suspects` — lists suspicious accounts with flags:
  /// `coin_mismatch`, `ad_over_cap`, `high_win_rate`, `fast_earn`, and an anomaly `score`.
  Future<Map<String, dynamic>> fetchSuspects({String? adminKey}) async {
    try {
      final response = await _dio.get('/admin-api/suspects', options: _adminHeaders(adminKey));
      return (response.data as Map).cast<String, dynamic>();
    } on DioException catch (e) {
      throw _toAdminException(e);
    }
  }

  /// `GET /admin-api/player?q=<phone or id>` — detailed player audit:
  /// profile, coin transactions, games, and cosmetic/coin purchases.
  Future<Map<String, dynamic>> fetchPlayerAudit(String query, {String? adminKey}) async {
    try {
      final response = await _dio.get(
        '/admin-api/player',
        queryParameters: {'q': query},
        options: _adminHeaders(adminKey),
      );
      return (response.data as Map).cast<String, dynamic>();
    } on DioException catch (e) {
      throw _toAdminException(e);
    }
  }

  /// `GET /notifications/admin/player?phone=` — checks recipient push device status.
  Future<Map<String, dynamic>> fetchNotificationPlayer(String phone, {String? adminKey}) async {
    try {
      final response = await _dio.get(
        '/notifications/admin/player',
        queryParameters: {'phone': phone},
        options: _adminHeaders(adminKey),
      );
      return (response.data as Map).cast<String, dynamic>();
    } on DioException catch (e) {
      throw _toAdminException(e);
    }
  }

  /// `POST /notifications` — sends broadcast or targeted in-app/push notification (operator).
  Future<Map<String, dynamic>> sendNotification({
    required String title,
    required String body,
    String? phone,
    bool inApp = true,
    bool push = true,
    String? adminKey,
  }) async {
    try {
      final response = await _dio.post(
        '/notifications',
        data: {
          'title': title,
          'body': body,
          if (phone != null && phone.isNotEmpty) 'phone': phone,
          'inApp': inApp,
          'push': push,
        },
        options: _adminHeaders(adminKey),
      );
      return (response.data as Map).cast<String, dynamic>();
    } on DioException catch (e) {
      throw _toAdminException(e);
    }
  }

  AdminException _toAdminException(DioException e) {
    final err = ApiError.from(e);
    return AdminException(err.code, err.message);
  }
}

class AdminException implements Exception {
  const AdminException(this.code, this.message);

  final String code;
  final String message;

  @override
  String toString() => 'AdminException($code): $message';
}
