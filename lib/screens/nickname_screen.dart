import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../models/auth.dart';
import '../providers/auth_provider.dart';
import '../theme/app_spacing.dart';
import '../theme/app_theme.dart';
import '../utils/persian_numbers.dart';
import '../widgets/error_dialog.dart';
import '../widgets/gradient_button.dart';
import '../widgets/p_text.dart';

class NicknameScreen extends ConsumerStatefulWidget {
  const NicknameScreen({super.key});

  @override
  ConsumerState<NicknameScreen> createState() => _NicknameScreenState();
}

class _NicknameScreenState extends ConsumerState<NicknameScreen> {
  final _controller = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _isValid {
    final text = _controller.text.trim();
    return text.length >= 2 && text.length <= 20;
  }

  Future<void> _submit() async {
    if (!_isValid || _isSubmitting) return;
    setState(() => _isSubmitting = true);

    try {
      await ref.read(authControllerProvider.notifier).setNickname(_controller.text.trim());
      if (!mounted) return;
      context.go('/');
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
    final gameTheme = context.gameTheme;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.screenPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: AppSpacing.xxl * 2),
              ShaderMask(
                shaderCallback: (bounds) => gameTheme.heroGradient.createShader(bounds),
                child: PText(
                  'یک نام مستعار انتخاب کنید',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: Colors.white),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              PText(
                'این نام برای بازیکنان دیگر نمایش داده می‌شود. باید یکتا باشد و از کلمات نامناسب استفاده نکنید.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.xxl),
              TextField(
                controller: _controller,
                textAlign: TextAlign.center,
                maxLength: 20,
                buildCounter: persianCounter,
                style: Theme.of(context).textTheme.titleLarge,
                decoration: const InputDecoration(hintText: 'نام مستعار'),
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: AppSpacing.lg),
              GradientButton(
                label: 'ادامه',
                isLoading: _isSubmitting,
                onTap: _isValid ? _submit : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
