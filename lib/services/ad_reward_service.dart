import 'package:dio/dio.dart';
import 'api_error.dart';
import 'dio_client.dart';
import '../models/ad_reward.dart';

/// REST client for `GET /ads/reward-status` and `POST /ads/reward`. The
/// server is the sole authority on the 5-per-24h / 4h-cooldown rate limit —
/// this client only ever displays what the server reports, never computes
/// its own eligibility.
class AdRewardService {
  AdRewardService({Dio? dio, String? baseUrl})
      : _dio = dio ?? buildDio(baseUrl);

  final Dio _dio;

  Future<AdRewardStatus> fetchStatus(String token) async {
    try {
      final response = await _dio.get(
        '/ads/reward-status',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      return AdRewardStatus.fromJson((response.data as Map).cast());
    } on DioException catch (e) {
      throw _toException(e);
    }
  }

  Future<AdRewardResult> claimReward(String token) async {
    try {
      final response = await _dio.post(
        '/ads/reward',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      return AdRewardResult.fromJson((response.data as Map).cast());
    } on DioException catch (e) {
      throw _toException(e);
    }
  }

  /// The "rescue" grant: a SEPARATE flow from the Home gift box, for a
  /// player stuck below the online-game cost. Its own 60s cooldown / 5-per-
  /// day cap (`ad_rescue_views` table) — watching it doesn't touch the gift
  /// box's quota or 4h cooldown. Server gates on `coinBalance <
  /// AD_RESCUE_BALANCE_THRESHOLD` (= 100). Same [AdRewardResult] shape.
  ///
  /// Throws [AdRewardException] with code `AD_RESCUE_NOT_ELIGIBLE` (balance
  /// too high — fall back to gift box / shop) or `AD_REWARD_NOT_AVAILABLE`
  /// (rescue cooldown / daily cap).
  Future<AdRewardResult> claimRescueReward(String token) async {
    try {
      final response = await _dio.post(
        '/ads/reward/rescue',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      return AdRewardResult.fromJson((response.data as Map).cast());
    } on DioException catch (e) {
      throw _toException(e);
    }
  }

  /// Fetches the rescue ad status (`GET /ads/rescue-status`).
  /// Reports whether the user is eligible by balance, remaining views,
  /// and cooldown state.
  Future<AdRescueStatus> fetchRescueStatus(String token) async {
    try {
      final response = await _dio.get(
        '/ads/rescue-status',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      return AdRescueStatus.fromJson((response.data as Map).cast());
    } on DioException catch (e) {
      throw _toException(e);
    }
  }

  AdRewardException _toException(DioException e) {
    final err = ApiError.from(e);
    final data = e.response?.data;
    AdRewardStatus? status;
    if (data is Map) {
      final statusJson = Map<String, dynamic>.from(data)..removeWhere((k, _) => k == 'error' || k == 'message');
      try {
        status = AdRewardStatus.fromJson(statusJson);
      } catch (_) {
        status = null;
      }
    }
    return AdRewardException(err.code, err.message, status);
  }
}
