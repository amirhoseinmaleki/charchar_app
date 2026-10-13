/// Thrown for a known backend room/gameplay error (room not found, room
/// full, not host, etc). `code` matches the server's error codes so the UI
/// can show a tailored Farsi message.
class RoomException implements Exception {
  const RoomException(this.code, this.message);

  final String code;
  final String message;

  @override
  String toString() => 'RoomException($code): $message';
}

class InsufficientCoinsInfo {
  const InsufficientCoinsInfo({required this.required, required this.balance});

  final int required;
  final int balance;

  factory InsufficientCoinsInfo.fromJson(Map<String, dynamic> json) {
    return InsufficientCoinsInfo(
      required: (json['required'] as num).toInt(),
      balance: (json['balance'] as num).toInt(),
    );
  }
}
