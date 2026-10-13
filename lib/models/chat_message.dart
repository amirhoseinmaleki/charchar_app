/// One message in the global real-time chat (see chat.md). Only the last
/// hour is retained server-side.
class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.playerId,
    required this.nickname,
    required this.text,
    required this.createdAt,
  });

  final String id;
  final String playerId;

  /// Sender's nickname at send time (a rename shows on new messages only).
  final String nickname;

  /// Sanitized, Persian (+ emoji).
  final String text;

  /// ms epoch.
  final int createdAt;

  DateTime get createdAtLocal => DateTime.fromMillisecondsSinceEpoch(createdAt);

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] as String,
      playerId: json['playerId'] as String,
      nickname: json['nickname'] as String? ?? 'بازیکن',
      text: json['text'] as String? ?? '',
      createdAt: (json['createdAt'] as num).toInt(),
    );
  }
}
