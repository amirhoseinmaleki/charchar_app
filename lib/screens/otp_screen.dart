import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pinput/pinput.dart';
import '../models/auth.dart';
import '../providers/auth_provider.dart';
import '../providers/sound_provider.dart';
import '../theme/app_spacing.dart';
import '../theme/app_theme.dart';
import '../utils/persian_numbers.dart';
import '../widgets/app_back_button.dart';
import '../widgets/error_dialog.dart';
import '../widgets/p_text.dart';

const _otpLength = 5;
const _resendCooldownSeconds = 60;

/// Navigation payload for `/otp`.
class OtpArgs {
  const OtpArgs({required this.phone});

  final String phone;
}

class OtpScreen extends ConsumerStatefulWidget {
  const OtpScreen({super.key, required this.phone});

  final String phone;

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  final _pinController = TextEditingController();
  Timer? _cooldownTimer;
  int _remainingSeconds = _resendCooldownSeconds;
  bool _isSubmitting = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _startCooldown();
  }

  void _startCooldown() {
    _remainingSeconds = _resendCooldownSeconds;
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        if (_remainingSeconds > 0) {
          _remainingSeconds--;
        } else {
          timer.cancel();
        }
      });
    });
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _verify(String rawCode) async {
    if (_isSubmitting) return;
    final code = rawCode.toAsciiDigits(); // Pinput may hand back Persian digits
    setState(() {
      _isSubmitting = true;
      _hasError = false;
    });

    try {
      final session = await ref.read(authControllerProvider.notifier).verifyOtp(widget.phone, code);
      if (!mounted) return;
      // A user with no nickname yet (first login) goes to the name step;
      // everyone else lands on Home.
      if (session.player.nickname == null) {
        context.go('/nickname');
      } else {
        context.go('/');
      }
    } on AuthException catch (e) {
      setState(() => _hasError = true);
      _pinController.clear();
      if (mounted) ErrorDialog.show(context, e.message);
    } catch (_) {
      setState(() => _hasError = true);
      if (mounted) ErrorDialog.show(context, 'ارتباط با سرور برقرار نشد.');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _resend() async {
    if (_remainingSeconds > 0) return;
    ref.read(soundServiceProvider).playButtonClick();
    try {
      await ref.read(authControllerProvider.notifier).requestOtp(widget.phone);
      _startCooldown();
      _pinController.clear();
    } on AuthException catch (e) {
      if (mounted) ErrorDialog.show(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final gameTheme = context.gameTheme;
    final theme = Theme.of(context);

    final defaultPinTheme = PinTheme(
      width: 52,
      height: 56,
      textStyle: theme.textTheme.titleLarge,
      decoration: BoxDecoration(
        color: theme.inputDecorationTheme.fillColor,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
    );

    final focusedPinTheme = defaultPinTheme.copyDecorationWith(
      border: Border.all(color: theme.colorScheme.primary, width: 2),
    );

    final errorPinTheme = defaultPinTheme.copyDecorationWith(
      border: Border.all(color: gameTheme.invalidColor, width: 2),
    );

    return Scaffold(
      appBar: AppBar(
        leading: AppBackButton(onPressed: () => context.pop()),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.screenPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: AppSpacing.xl),
              PText(
                'کد تایید را وارد کنید',
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.sm),
              PText(
                'کد ۵ رقمی به شماره ${widget.phone} پیامک شد',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium,
                textDirection: TextDirection.ltr,
              ),
              const SizedBox(height: AppSpacing.xxl),
              Directionality(
                textDirection: TextDirection.ltr,
                child: Pinput(
                  controller: _pinController,
                  length: _otpLength,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9۰-۹٠-٩]')),
                    const PersianDigitInputFormatter(),
                  ],
                  defaultPinTheme: defaultPinTheme,
                  focusedPinTheme: focusedPinTheme,
                  errorPinTheme: errorPinTheme,
                  forceErrorState: _hasError,
                  enabled: !_isSubmitting,
                  onCompleted: _verify,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              if (_isSubmitting)
                const Center(child: CircularProgressIndicator())
              else
                TextButton(
                  onPressed: _remainingSeconds > 0 ? null : _resend,
                  child: PText(
                    _remainingSeconds > 0 ? 'ارسال مجدد کد (${_remainingSeconds.toPersianString()} ثانیه)' : 'ارسال مجدد کد',
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
