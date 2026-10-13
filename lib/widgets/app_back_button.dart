import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/sound_provider.dart';
import '../theme/app_images.dart';

/// The app's single back-navigation icon, used as every [AppBar]'s
/// `leading` instead of Flutter's default arrow — replaces it everywhere
/// with the game's own back.png artwork, plus the shared click sound and
/// a quick shrink-and-return scale bounce on tap (matching the Home
/// screen's round icon buttons).
class AppBackButton extends ConsumerStatefulWidget {
  const AppBackButton({super.key, this.onPressed});

  /// Defaults to popping the current route when omitted.
  final VoidCallback? onPressed;

  @override
  ConsumerState<AppBackButton> createState() => _AppBackButtonState();
}

class _AppBackButtonState extends ConsumerState<AppBackButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 90),
      reverseDuration: const Duration(milliseconds: 140),
    );
    _scale = Tween<double>(begin: 1, end: 0.82).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOut,
        reverseCurve: Curves.easeOutBack,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleTap() async {
    ref.read(soundServiceProvider).playButtonClick();
    await _controller.forward();
    await _controller.reverse();
    if (!mounted) return;
    if (widget.onPressed != null) {
      widget.onPressed!();
    } else {
      Navigator.of(context).maybePop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      child: IconButton(
        icon: Image.asset(AppImages.back, width: 32, height: 32),
        iconSize: 32,
        tooltip: 'بازگشت',
        onPressed: _handleTap,
      ),
    );
  }
}
