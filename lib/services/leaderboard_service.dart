import 'package:dio/dio.dart';
import 'dio_client.dart';
import '../models/leaderboard.dart';

/// REST client for `GET /leaderboard` — read-only, so failures surface as a
/// plain exception message rather than a typed error-code enum like auth.
class LeaderboardService {
  LeaderboardService({Dio? dio, String? baseUrl})
      : _dio = dio ?? buildDio(baseUrl);

  final Dio _dio;

  Future<LeaderboardResult> fetch({required LeaderboardScope scope, String? token}) async {
    try {
      // No limit/offset — the board is always the fixed top 100; `myRank`
      // covers "where am I if I'm outside it" (see leaderboard.md).
      final response = await _dio.get(
        '/leaderboard',
        queryParameters: {'scope': scope.apiValue},
        options: token != null ? Options(headers: {'Authorization': 'Bearer $token'}) : null,
      );
      // ignore: avoid_print
      print('[LB] ${scope.apiValue} tokenSent=${token != null} '
          'tokenLen=${token?.length ?? 0} '
          'myRank=${(response.data as Map)['myRank']} '
          'entries=${((response.data as Map)['entries'] as List?)?.length}');
      return LeaderboardResult.fromJson((response.data as Map).cast());
    } on DioException catch (e) {
      // ignore: avoid_print
      print('[LB] ${scope.apiValue} FAILED ${e.response?.statusCode} ${e.message}');
      throw Exception('ارتباط با سرور برقرار نشد.');
    }
  }
}
