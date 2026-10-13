import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../config/coin_costs.dart';
import '../models/room_events.dart';
import '../providers/room_provider.dart';
import '../theme/app_spacing.dart';
import '../theme/app_theme.dart';
import '../widgets/app_back_button.dart';
import '../widgets/coin_pill.dart';
import '../widgets/error_dialog.dart';
import '../widgets/floating_letters_background.dart';
import '../widgets/insufficient_coins_dialog.dart';
import '../widgets/gradient_button.dart';
import '../widgets/pill_tab_switcher.dart';
import '../widgets/p_text.dart';
import '../widgets/tapsell_banner_ad.dart';

/// Room-code alphabet: A–Z minus I and O, digits 2–9 (no 0/1). Ambiguous
/// glyphs are excluded so a code read aloud or off a screen can't be
/// mistyped. Matches the server's format exactly.
final _roomCodeCharset = RegExp('[^A-HJ-NP-Z2-9]');
final _roomCodeFull = RegExp(r'^[A-HJ-NP-Z2-9]{5}$');

bool isValidRoomCode(String code) => _roomCodeFull.hasMatch(code);

class CreateJoinRoomScreen extends ConsumerStatefulWidget {
  const CreateJoinRoomScreen({super.key});

  @override
  ConsumerState<CreateJoinRoomScreen> createState() => _CreateJoinRoomScreenState();
}

class _CreateJoinRoomScreenState extends ConsumerState<CreateJoinRoomScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _codeController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _handleCreate() async {
    setState(() => _isSubmitting = true);
    try {
      final code = await ref.read(roomControllerProvider.notifier).createRoom();
      if (!mounted) return;
      context.push('/lobby', extra: code);
    } on RoomException catch (e) {
      if (!mounted) return;
      if (e.code == 'INSUFFICIENT_COINS') {
        await InsufficientCoinsDialog.show(context, e.message);
      } else {
        ErrorDialog.show(context, e.message);
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _handleJoin() async {
    final code = _codeController.text.trim().toUpperCase();
    if (!isValidRoomCode(code) || _isSubmitting) return;
    setState(() => _isSubmitting = true);
    try {
      final joinedCode = await ref.read(roomControllerProvider.notifier).joinRoom(code);
      if (!mounted) return;
      context.push('/lobby', extra: joinedCode);
    } on RoomException catch (e) {
      if (!mounted) return;
      if (e.code == 'INSUFFICIENT_COINS') {
        await InsufficientCoinsDialog.show(context, e.message);
      } else {
        ErrorDialog.show(context, e.message);
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const PText('بازی با دوستان'), leading: const AppBackButton()),
      body: Stack(
        children: [
          // Same decorative drifting Persian letters as the Home screen.
          Positioned.fill(
            child: FloatingLettersBackground(
              color: context.gameTheme.heroGradient.colors.first,
            ),
          ),
            SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.screenPadding,
                    AppSpacing.sm,
                    AppSpacing.screenPadding,
                    AppSpacing.xs,
                  ),
                  child: PillTabSwitcher(
                    controller: _tabController,
                    tabs: const [
                      PillTab(label: 'ساخت اتاق'),
                      PillTab(label: 'ورود به اتاق'),
                    ],
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _CreateTab(
                        isSubmitting: _isSubmitting,
                        onCreate: _handleCreate,
                      ),
                      _JoinTab(
                        codeController: _codeController,
                        isSubmitting: _isSubmitting,
                        onJoin: _handleJoin,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: TapsellBannerAd(),
            ),
          ),
        ],
      ),
    );
  }
}

class _CreateTab extends ConsumerWidget {
  const _CreateTab({required this.isSubmitting, required this.onCreate});

  final bool isSubmitting;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final createRoomCost = ref.watch(createRoomCostProvider);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenPadding,
        AppSpacing.xs,
        AppSpacing.screenPadding,
        AppSpacing.screenPadding,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PText(
            'یک اتاق جدید بسازید و کد آن را برای دوستانتان بفرستید',
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .bodyLarge
                ?.copyWith(fontSize: (Theme.of(context).textTheme.bodyLarge?.fontSize ?? 16) + 2),
          ),
          const SizedBox(height: AppSpacing.lg),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
            decoration: BoxDecoration(
              color: Theme.of(context).cardTheme.color,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                PText('هزینه ساخت اتاق', style: Theme.of(context).textTheme.bodyMedium),
                CoinPill(balance: createRoomCost),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          GradientButton(
            isLoading: isSubmitting,
            label: 'ساخت اتاق',
            onTap: onCreate,
          ),
        ],
      ),
    );
  }
}

class _JoinTab extends ConsumerStatefulWidget {
  const _JoinTab({
    required this.codeController,
    required this.isSubmitting,
    required this.onJoin,
  });

  final TextEditingController codeController;
  final bool isSubmitting;
  final VoidCallback onJoin;

  @override
  ConsumerState<_JoinTab> createState() => _JoinTabState();
}

class _JoinTabState extends ConsumerState<_JoinTab> {
  @override
  void initState() {
    super.initState();
    // Rebuild on every keystroke so the "ورود به اتاق" button enables the
    // moment a full, valid 5-char code is present and disables otherwise.
    widget.codeController.addListener(_onCodeChanged);
  }

  @override
  void dispose() {
    widget.codeController.removeListener(_onCodeChanged);
    super.dispose();
  }

  void _onCodeChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final code = widget.codeController.text;
    final isComplete = isValidRoomCode(code);
    final joinRoomCost = ref.watch(joinRoomCostProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenPadding,
        AppSpacing.xs,
        AppSpacing.screenPadding,
        AppSpacing.screenPadding,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PText(
            'کد اتاق را از دوستتان بگیرید و اینجا وارد کنید',
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .bodyLarge
                ?.copyWith(fontSize: (Theme.of(context).textTheme.bodyLarge?.fontSize ?? 16) + 2),
          ),
          const SizedBox(height: AppSpacing.lg),
          TextField(
            controller: widget.codeController,
            textAlign: TextAlign.center,
            textCapitalization: TextCapitalization.characters,
            textDirection: TextDirection.ltr,
            maxLength: 5,
            // Room-code format (server-matched): exactly 5 chars from
            // A–Z (minus I, O) and 2–9. Uppercase as the user types and
            // drop anything outside that set — I/O/0/1, lowercase,
            // spaces, dashes — so a malformed code never leaves the
            // device and the field only ever holds valid characters.
            inputFormatters: [
              LengthLimitingTextInputFormatter(5),
              TextInputFormatter.withFunction(
                (oldValue, newValue) => newValue.copyWith(
                  text: newValue.text.toUpperCase().replaceAll(_roomCodeCharset, ''),
                ),
              ),
            ],
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(letterSpacing: 4),
            decoration: const InputDecoration(hintText: 'XXXXX', hintTextDirection: TextDirection.ltr),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
            decoration: BoxDecoration(
              color: Theme.of(context).cardTheme.color,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                PText('هزینه ورود', style: Theme.of(context).textTheme.bodyMedium),
                CoinPill(balance: joinRoomCost),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          GradientButton(
            isLoading: widget.isSubmitting,
            label: 'ورود به اتاق',
            onTap: isComplete ? widget.onJoin : null,
          ),
        ],
      ),
    );
  }
}
