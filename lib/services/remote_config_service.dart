import 'package:dio/dio.dart';
import 'dio_client.dart';
import '../models/remote_config.dart';

/// Fetches `GET /config/client` — SDK keys + server-authoritative gameplay
/// numbers — once at app startup on the splash screen. Unauthenticated.
///
/// Everything in the response is treated as untrusted: [RemoteConfig] /
/// [ClientConfig] parse defensively and clamp every value, and a body that
/// isn't a JSON object at all is rejected here so the caller falls back to
/// compiled defaults rather than crashing.
class RemoteConfigService {
  RemoteConfigService({Dio? dio, String? baseUrl})
      : _dio = dio ?? buildDio(baseUrl);

  final Dio _dio;

  Future<RemoteConfig> fetch() async {
    final response = await _dio.get(
      '/config/client',
      // A config payload this large is not something the real backend
      // sends — cap it so a hostile/mis-proxied response can't balloon
      // memory before we even parse it.
      options: Options(
        receiveTimeout: const Duration(seconds: 10),
        responseType: ResponseType.json,
      ),
    );

    final data = response.data;
    if (data is! Map) {
      throw const FormatException('config/client: response was not a JSON object');
    }
    return RemoteConfig.fromJson(data.cast<String, dynamic>());
  }

  /// Checks server health via `GET /health` ({ status, uptime, timestamp }).
  Future<ServerHealth> fetchHealth() async {
    final response = await _dio.get(
      '/health',
      options: Options(
        receiveTimeout: const Duration(seconds: 5),
        responseType: ResponseType.json,
      ),
    );
    final data = response.data;
    if (data is! Map) {
      throw const FormatException('health: response was not a JSON object');
    }
    return ServerHealth.fromJson(data.cast<String, dynamic>());
  }
}

class ServerHealth {
  const ServerHealth({
    required this.status,
    required this.uptime,
    required this.timestamp,
  });

  final String status;
  final double uptime;
  final DateTime timestamp;

  factory ServerHealth.fromJson(Map<String, dynamic> json) {
    final rawTs = json['timestamp'];
    final DateTime ts;
    if (rawTs is num) {
      ts = DateTime.fromMillisecondsSinceEpoch(rawTs.toInt());
    } else if (rawTs is String) {
      ts = DateTime.tryParse(rawTs) ?? DateTime.now();
    } else {
      ts = DateTime.now();
    }

    return ServerHealth(
      status: json['status']?.toString() ?? 'ok',
      uptime: (json['uptime'] as num?)?.toDouble() ?? 0.0,
      timestamp: ts,
    );
  }
}
