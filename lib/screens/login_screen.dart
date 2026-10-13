import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../models/auth.dart';
import '../providers/auth_provider.dart';
import '../theme/app_images.dart';
import '../theme/app_spacing.dart';
import '../utils/persian_numbers.dart';
import '../widgets/error_dialog.dart';
import '../widgets/floating_letters_background.dart';
import '../widgets/gradient_button.dart';
import '../widgets/p_text.dart';
import 'otp_screen.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _phoneController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  /// The typed number as ASCII, whatever digit script it was entered in.
  String get _asciiPhone => _phoneController.text.toAsciiDigits();

  bool get _isValidPhone {
    final digits = _asciiPhone.replaceAll(RegExp(r'\D'), '');
    return RegExp(r'^(0?9\d{9}|989\d{9})$').hasMatch(digits);
  }

  Future<void> _submit() async {
    if (!_isValidPhone || _isSubmitting) return;
    setState(() => _isSubmitting = true);

    try {
      await ref.read(authControllerProvider.notifier).requestOtp(_asciiPhone);
      if (!mounted) return;
      context.push('/otp', extra: OtpArgs(phone: _asciiPhone));
    } on AuthException catch (e) {
      if (mounted) ErrorDialog.show(context, e.message);
    } catch (_) {
      if (mounted) ErrorDialog.show(context, 'ارتباط با سرور برقرار نشد.');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LetteredBackdrop(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.screenPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: AppSpacing.xxl),
                Image.asset(
                  AppImages.logo,
                  width: MediaQuery.of(context).size.width * 0.5,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: AppSpacing.lg),
                PText(
                  'برای ورود، شماره موبایل خود را وارد کنید',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: AppSpacing.xxl),
                TextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  textAlign: TextAlign.center,
                  textDirection: TextDirection.ltr,
                  maxLength: 13,
                  buildCounter:
                      (
                        _, {
                        required currentLength,
                        required isFocused,
                        maxLength,
                      }) => null,
                  // Digits (ASCII / Persian / Arabic) and a leading + only —
                  // no letters, spaces, or control chars reach the request —
                  // then shown as Persian digits to match the UI.
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9۰-۹٠-٩+]')),
                    LengthLimitingTextInputFormatter(13),
                    const PersianDigitInputFormatter(),
                  ],
                  style: Theme.of(context).textTheme.titleLarge,
                  decoration: const InputDecoration(
                    hintText: '۰۹xxxxxxxxx',
                    hintTextDirection: TextDirection.ltr,
                  ),
                  onChanged: (_) => setState(() {}),
                  onSubmitted: (_) => _submit(),
                ),
                const SizedBox(height: AppSpacing.lg),
                GradientButton(
                  label: 'دریافت کد',
                  isLoading: _isSubmitting,
                  onTap: _isValidPhone ? _submit : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
