import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Fallback base URL when SERVER_URL isn't set in .env.
const _fallbackBaseUrl = 'https://api.woundai.ir';

/// One place that builds every service's [Dio] so they share the same
/// hardened defaults:
///
/// - Short connect/receive/send timeouts so a hung or hostile server can't
///   pin a request open indefinitely.
/// - `validateStatus` accepts only 2xx; every 4xx/5xx becomes a
///   `DioException` the service layer maps to a typed error, so an error
///   body is never mistaken for a success payload.
/// - `receiveDataWhenStatusError: true` so the JSON `{error, message}` body
///   the backend returns on a 4xx is still available to map to the user
///   message (these bodies are tiny — one short sentence).
/// - `followRedirects: false` / `maxRedirects: 0` — the API never
///   legitimately 3xx-redirects; a redirect would only ever be an attempt
///   to bounce an authenticated request (with its Bearer header) to
///   another origin.
Dio buildDio(String? baseUrl) {
  final resolved = baseUrl ?? dotenv.env['SERVER_URL'] ?? _fallbackBaseUrl;
  return Dio(
    BaseOptions(
      baseUrl: resolved,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
      sendTimeout: const Duration(seconds: 15),
      followRedirects: false,
      maxRedirects: 0,
      // Keep the error body — the backend's typed {error, message} JSON is
      // what every service maps to a user-facing message.
      receiveDataWhenStatusError: true,
      // Only 2xx is "success"; anything else throws and the caller's
      // DioException handler turns it into a typed, user-safe error.
      validateStatus: (status) => status != null && status >= 200 && status < 300,
      headers: const {'Accept': 'application/json'},
      responseType: ResponseType.json,
    ),
  );
}
