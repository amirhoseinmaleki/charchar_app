class PlayerCosmetics {
  const PlayerCosmetics({this.avatarId, this.nameColorId, this.frameId});

  final String? avatarId;
  final String? nameColorId;
  final String? frameId;

  factory PlayerCosmetics.fromJson(Map<String, dynamic> json) {
    return PlayerCosmetics(
      avatarId: json['avatarId'] as String?,
      nameColorId: json['nameColorId'] as String?,
      frameId: json['frameId'] as String?,
    );
  }
}

class Player {
  const Player({
    required this.id,
    required this.name,
    required this.isHost,
    required this.isNpc,
    required this.connected,
    required this.score,
    required this.cosmetics,
    this.nameColorHex,
    this.avatarUrl,
  });

  final String id;
  final String name;
  final bool isHost;
  final bool isNpc;
  final bool connected;
  final int score;
  final PlayerCosmetics cosmetics;

  /// Server-resolved hex for this player's equipped name-color, or null for
  /// the default. Use with [ColoredName] to tint their name anywhere it's
  /// shown (lobby, in-round scoreboard, results).
  final String? nameColorHex;

  /// Server-relative path for this player's equipped avatar image (custom or
  /// the shared default). Prefix with SERVER_URL to load.
  final String? avatarUrl;

  factory Player.fromJson(Map<String, dynamic> json) {
    return Player(
      id: json['id'] as String,
      name: json['name'] as String,
      isHost: json['isHost'] as bool? ?? false,
      isNpc: json['isNpc'] as bool? ?? false,
      connected: json['connected'] as bool? ?? true,
      score: (json['score'] as num?)?.toInt() ?? 0,
      cosmetics: PlayerCosmetics.fromJson(
        (json['cosmetics'] as Map?)?.cast<String, dynamic>() ?? const {},
      ),
      nameColorHex: json['nameColorHex'] as String?,
      avatarUrl: json['avatarUrl'] as String?,
    );
  }
}
