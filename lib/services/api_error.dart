import 'package:dio/dio.dart';

/// Turns a Dio failure into a (code, userMessage) pair that's always safe to
/// show a user:
///
/// - A server `{error, message}` body: the code is passed through (screens
///   switch on it), but the message is only surfaced if it's a short,
///   plain string — never a stack trace, HTML page, or huge blob a
///   misbehaving/hostile server might return.
/// - A timeout / connection error / cancelled request: a fixed generic
///   "couldn't reach the server" line.
/// - Anything else (bad status with no JSON body, parse failure): a fixed
///   generic error line, so an internal detail never reaches the UI.
class ApiError {
  const ApiError(this.code, this.message);

  final String code;
  final String message;

  static const _genericUnreachable = 'ارتباط با سرور برقرار نشد.';
  static const _genericError = 'خطایی رخ داد. لطفاً دوباره تلاش کنید.';

  /// Longest server-supplied message we'll show verbatim. Real messages
  /// here are one short Farsi sentence; anything longer is suspect.
  static const _maxMessageLen = 200;

  factory ApiError.from(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.connectionError:
      case DioExceptionType.cancel:
        return const ApiError('SERVER_UNREACHABLE', _genericUnreachable);
      case DioExceptionType.badCertificate:
        return const ApiError('BAD_CERTIFICATE', _genericUnreachable);
      case DioExceptionType.badResponse:
      default:
        // badResponse and unknown fall through to the body inspection below.
        break;
    }

    final data = e.response?.data;
    if (data is Map) {
      final code = data['error'];
      final rawMessage = data['message'];
      if (code is String && code.isNotEmpty && code.length <= 64) {
        final safeMessage = (rawMessage is String &&
                rawMessage.isNotEmpty &&
                rawMessage.length <= _maxMessageLen &&
                !rawMessage.contains('<'))
            ? rawMessage
            : _genericError;
        return ApiError(code, safeMessage);
      }
    }
    return const ApiError('UNKNOWN', _genericError);
  }
}
