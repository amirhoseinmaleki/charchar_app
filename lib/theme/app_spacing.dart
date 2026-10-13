/// Spacing scale (4/8/12/16/24/32) used throughout the app instead of
/// hardcoded padding/margin numbers.
class AppSpacing {
  AppSpacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;

  /// Standard screen edge padding per the design spec.
  static const double screenPadding = 24;

  /// Minimum touch target size (accessibility).
  static const double minTouchTarget = 44;
}

/// Corner radius scale (12/16/24).
class AppRadius {
  AppRadius._();

  static const double sm = 12;
  static const double md = 16;
  static const double lg = 24;
}
