import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_images.dart';
import '../theme/app_spacing.dart';
import '../widgets/p_text.dart';

class SecurityService {
  SecurityService._();

  static const _channel = MethodChannel('com.PardisSaz.game/security');
  static bool _isChecking = false;

  /// Checks if the device is rooted.
  /// Note: Emulators are explicitly allowed as requested.
  static Future<bool> isDeviceRooted() async {
    if (!Platform.isAndroid && !Platform.isIOS) return false;
    try {
      final isRooted = await _channel.invokeMethod<bool>('isDeviceRooted');
      return isRooted ?? false;
    } catch (e) {
      if (kDebugMode) debugPrint('[security] root check error: $e');
      return false;
    }
  }

  /// Verifies device integrity and shows blocking dialog if rooted.
  static Future<bool> verifyDeviceIntegrity(BuildContext context) async {
    if (_isChecking) return true;
    _isChecking = true;

    final rooted = await isDeviceRooted();
    _isChecking = false;

    if (rooted && context.mounted) {
      await showGeneralDialog(
        context: context,
        barrierDismissible: false,
        barrierColor: Colors.black87,
        transitionDuration: const Duration(milliseconds: 300),
        pageBuilder: (ctx, a, b) => const _RootWarningDialog(),
      );
      // Terminate the app
      if (Platform.isAndroid || Platform.isIOS) {
        SystemNavigator.pop();
        exit(0);
      }
      return false;
    }
    return true;
  }
}

class _RootWarningDialog extends StatelessWidget {
  const _RootWarningDialog();

  @override
  Widget build(BuildContext context) {

    return PopScope(
      canPop: false,
      child: Dialog(
        backgroundColor: const Color(0xFF231A38),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: const BorderSide(color: Color(0xFFE53935), width: 3),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(AppImages.warning, width: 68, height: 68),
              const SizedBox(height: AppSpacing.md),
              PText(
                'هشدار امنیتی',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: const Color(0xFFE53935),
                      fontWeight: FontWeight.w900,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.sm),
              PText(
                'به دلیل حفظ امنیت داده‌ها و رعایت عدالت در رقابت آنلاین، اجرای این بازی روی دستگاه‌های روت‌شده (Rooted) امکان‌پذیر نمی‌باشد.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.white.withValues(alpha: 0.9),
                      height: 1.5,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xl),
              GestureDetector(
                onTap: () {
                  SystemNavigator.pop();
                  exit(0);
                },
                child: Container(
                  width: double.infinity,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFE53935), Color(0xFFB71C1C)],
                    ),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFE53935).withValues(alpha: 0.4),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: const PText(
                    'خروج از بازی',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
