/// One broadcast in-app notification, annotated with THIS player's read
/// state (see notifications.md — there's no per-recipient row server-side).
class AppNotification {
  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.createdAt,
    required this.read,
    this.readAt,
  });

  final String id;
  final String title;
  final String body;

  /// Server epoch ms.
  final int createdAt;
  final bool read;

  /// Server epoch ms when this player marked it read, or null.
  final int? readAt;

  DateTime get createdAtLocal => DateTime.fromMillisecondsSinceEpoch(createdAt);

  AppNotification copyWith({bool? read, int? readAt}) {
    return AppNotification(
      id: id,
      title: title,
      body: body,
      createdAt: createdAt,
      read: read ?? this.read,
      readAt: readAt ?? this.readAt,
    );
  }

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'] as String,
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      createdAt: (json['createdAt'] as num).toInt(),
      read: json['read'] as bool? ?? false,
      readAt: (json['readAt'] as num?)?.toInt(),
    );
  }
}

/// One page of `GET /notifications`.
class NotificationPage {
  const NotificationPage({
    required this.items,
    required this.unreadCount,
    required this.total,
    required this.nextBefore,
  });

  final List<AppNotification> items;
  final int unreadCount;
  final int total;

  /// Keyset cursor for the next (older) page, or null when there are no
  /// more pages.
  final int? nextBefore;

  factory NotificationPage.fromJson(Map<String, dynamic> json) {
    return NotificationPage(
      items: (json['items'] as List)
          .map((e) => AppNotification.fromJson((e as Map).cast<String, dynamic>()))
          .toList(),
      unreadCount: (json['unreadCount'] as num?)?.toInt() ?? 0,
      total: (json['total'] as num?)?.toInt() ?? 0,
      nextBefore: (json['nextBefore'] as num?)?.toInt(),
    );
  }
}
