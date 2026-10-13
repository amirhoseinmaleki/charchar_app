class AdRewardStatus {
  const AdRewardStatus({
    required this.canWatch,
    required this.viewsRemainingToday,
    required this.maxPerDay,
    required this.cooldownEndsAt,
    required this.coinAmount,
  });

  final bool canWatch;
  final int viewsRemainingToday;
  final int maxPerDay;

  /// null when not currently in cooldown.
  final DateTime? cooldownEndsAt;
  final int coinAmount;

  factory AdRewardStatus.fromJson(Map<String, dynamic> json) {
    final cooldownMs = json['cooldownEndsAt'] as num?;
    return AdRewardStatus(
      canWatch: json['canWatch'] as bool,
      viewsRemainingToday: (json['viewsRemainingToday'] as num).toInt(),
      maxPerDay: (json['maxPerDay'] as num).toInt(),
      cooldownEndsAt: cooldownMs != null ? DateTime.fromMillisecondsSinceEpoch(cooldownMs.toInt()) : null,
      coinAmount: (json['coinAmount'] as num).toInt(),
    );
  }
}

class AdRewardResult {
  const AdRewardResult({required this.coinBalance, required this.status});

  final int coinBalance;
  final AdRewardStatus status;

  factory AdRewardResult.fromJson(Map<String, dynamic> json) {
    return AdRewardResult(
      coinBalance: (json['coinBalance'] as num).toInt(),
      status: AdRewardStatus.fromJson(json),
    );
  }
}

/// Rescue ad status (`GET /ads/rescue-status`).
/// Contains whether the player is eligible by balance, balance threshold,
/// current coin balance, plus view quotas and cooldown timing.
class AdRescueStatus {
  const AdRescueStatus({
    required this.canWatch,
    required this.viewsRemainingToday,
    required this.maxPerDay,
    required this.cooldownEndsAt,
    required this.coinAmount,
    required this.eligibleByBalance,
    required this.balanceThreshold,
    required this.coinBalance,
  });

  final bool canWatch;
  final int viewsRemainingToday;
  final int maxPerDay;
  final DateTime? cooldownEndsAt;
  final int coinAmount;
  final bool eligibleByBalance;
  final int balanceThreshold;
  final int coinBalance;

  factory AdRescueStatus.fromJson(Map<String, dynamic> json) {
    final cooldownMs = json['cooldownEndsAt'] as num?;
    return AdRescueStatus(
      canWatch: json['canWatch'] as bool? ?? false,
      viewsRemainingToday: (json['viewsRemainingToday'] as num?)?.toInt() ?? 0,
      maxPerDay: (json['maxPerDay'] as num?)?.toInt() ?? 0,
      cooldownEndsAt: cooldownMs != null ? DateTime.fromMillisecondsSinceEpoch(cooldownMs.toInt()) : null,
      coinAmount: (json['coinAmount'] as num?)?.toInt() ?? 0,
      eligibleByBalance: json['eligibleByBalance'] as bool? ?? false,
      balanceThreshold: (json['balanceThreshold'] as num?)?.toInt() ?? 100,
      coinBalance: (json['coinBalance'] as num?)?.toInt() ?? 0,
    );
  }
}

class AdRewardException implements Exception {
  const AdRewardException(this.code, this.message, this.status);

  final String code;
  final String message;
  final AdRewardStatus? status;

  @override
  String toString() => 'AdRewardException($code): $message';
}
