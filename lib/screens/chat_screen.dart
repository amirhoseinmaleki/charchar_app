import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../models/chat_message.dart';
import '../models/room_events.dart';
import '../providers/chat_provider.dart';
import '../providers/room_provider.dart';
import '../providers/sound_provider.dart';
import '../theme/app_images.dart';
import '../theme/app_spacing.dart';
import '../theme/app_theme.dart';
import '../utils/persian_numbers.dart';
import '../widgets/app_back_button.dart';
import '../widgets/error_dialog.dart';
import '../widgets/floating_letters_background.dart';
import '../widgets/player_avatar.dart';
import '../widgets/p_text.dart';

/// A 5-char room code the "دعوت در چت" button embeds as "کد اتاق: XXXXX".
final _roomCodeInText = RegExp(r'کد اتاق:\s*([A-HJ-NP-Z2-9]{5})');

/// Reply is client-only (no reply field on the wire) — encoded as a quoted
/// first line of the message text itself and parsed back out for display.
const _replyPrefix = '↩ ';
// The server collapses whitespace (chat.md rule 1), so the "\n" after the
// quote arrives as a plain space — anchor on the snippet's closing "…"
// (always appended by [_quoteSnippet]) instead of the newline.
final _replyQuoteRe = RegExp('^$_replyPrefix(.+?): (.+?…)\\s*([\\s\\S]+)\$');

/// (quotedNickname, quotedSnippet, body), or null if [text] isn't a reply.
(String, String, String)? _parseReply(String text) {
  final m = _replyQuoteRe.firstMatch(text);
  if (m == null) return null;
  return (m.group(1)!, m.group(2)!, m.group(3)!);
}

/// Always ends in an ellipsis — even when [text] fits — so a quote reads
/// unambiguously as "part of another message", not as the whole message.
String _quoteSnippet(String text, {int max = 40}) {
  final chars = text.characters;
  final cut = chars.length <= max ? chars : chars.take(max);
  return '$cut…';
}

/// The global real-time chat (see chat.md): one flat Persian-only room,
/// last hour only. Runs over the same socket as the game.
class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  int _lastCount = 0;
  Timer? _clock;

  static const _maxLength = 400;

  // No reply field on the wire (chat:send only ever carries {text}) — a
  // reply is encoded as a quoted first line of the same text, parsed back
  // out by [_parseReply] when rendering. Purely client-side.
  ChatMessage? _replyTo;

  void _startReply(ChatMessage message) {
    ref.read(soundServiceProvider).playButtonClick();
    setState(() => _replyTo = message);
    FocusScope.of(context).requestFocus(_inputFocus);
  }

  void _cancelReply() => setState(() => _replyTo = null);

  final _inputFocus = FocusNode();

  // One key per rendered message so a tapped reply quote can scroll its
  // original into view; [_highlightId] flashes that message briefly.
  final _messageKeys = <String, GlobalKey>{};
  String? _highlightId;
  Timer? _highlightTimer;

  /// The message a reply quote points at: the latest earlier message from
  /// [nickname] whose text starts with the quoted snippet (sans the "…").
  ChatMessage? _findQuoted(
    List<ChatMessage> messages,
    int replyIndex,
    String nickname,
    String snippet,
  ) {
    final prefix = snippet.endsWith('…')
        ? snippet.substring(0, snippet.length - 1)
        : snippet;
    for (var i = replyIndex - 1; i >= 0; i--) {
      final m = messages[i];
      if (m.nickname == nickname && m.text.startsWith(prefix)) return m;
    }
    return null;
  }

  void _jumpToMessage(ChatMessage target) {
    final ctx = _messageKeys[target.id]?.currentContext;
    if (ctx == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: PText('پیام اصلی دیگر در دسترس نیست.')),
      );
      return;
    }
    ref.read(soundServiceProvider).playButtonClick();
    Scrollable.ensureVisible(
      ctx,
      alignment: 0.3,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
    );
    _highlightTimer?.cancel();
    setState(() => _highlightId = target.id);
    _highlightTimer = Timer(const Duration(milliseconds: 1500), () {
      if (mounted) setState(() => _highlightId = null);
    });
  }

  @override
  void initState() {
    super.initState();
    // Flip the counting gate now (no state mutation, so build-safe) so a
    // message arriving before the first frame isn't miscounted as unread.
    ref.read(chatControllerProvider.notifier).markScreenOpen();
    // Deferred: setScreenOpen also zeroes the count (a state mutation),
    // which can't happen while this widget is still building — the first
    // read also builds the controller.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final chat = ref.read(chatControllerProvider.notifier);
      chat.setScreenOpen(true);
      chat.requestHistory();
    });
    // Age the "N دقیقه پیش" labels even when no new message arrives.
    _clock = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void activate() {
    super.activate();
    // Re-entered the tree (e.g. popped back from a route pushed on top of
    // chat) — the screen is being looked at again.
    ref.read(chatControllerProvider.notifier).setScreenOpen(true);
  }

  @override
  void deactivate() {
    // Mark the chat screen closed here, not only in dispose(): when this
    // route is popped, `ref` is guaranteed usable in deactivate(), whereas
    // by dispose() the element may already be unmounted and the read a
    // silent no-op — which left `_screenOpen` stuck `true` and froze the
    // Home unread badge after the first visit.
    ref.read(chatControllerProvider.notifier).setScreenOpen(false);
    super.deactivate();
  }

  @override
  void dispose() {
    _clock?.cancel();
    _highlightTimer?.cancel();
    // Belt-and-suspenders: also reset on dispose in case deactivate() was
    // skipped (it isn't, for a normal pop, but keep the invariant safe).
    ref.read(chatControllerProvider.notifier).setScreenOpen(false);
    _input.dispose();
    _scroll.dispose();
    _inputFocus.dispose();
    super.dispose();
  }

  void _jumpToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
      }
    });
  }

  void _send() {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    ref.read(soundServiceProvider).playButtonClick();
    final replyTo = _replyTo;
    var outgoing = text;
    if (replyTo != null) {
      final quote =
          '$_replyPrefix${replyTo.nickname}: ${_quoteSnippet(replyTo.text)}\n';
      // The server enforces _maxLength on the combined text (unchanged API,
      // so no separate budget for the quote) — trim the body, not the quote,
      // so the reply reference itself never gets cut off mid-word.
      final bodyBudget = _maxLength - quote.characters.length;
      outgoing = bodyBudget > 0
          ? quote + text.characters.take(bodyBudget).toString()
          : text;
    }
    ref.read(chatControllerProvider.notifier).send(outgoing);
    _input.clear();
    setState(() => _replyTo = null);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(chatControllerProvider);
    final myId = ref.watch(myPlayerIdForChatProvider);

    // Auto-scroll to the newest message when the list grows.
    if (state.messages.length != _lastCount) {
      _lastCount = state.messages.length;
      _jumpToBottom();
    }

    // Surface a rejected send.
    ref.listen(chatControllerProvider.select((s) => s.lastError), (_, err) {
      if (err != null && mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: PText(err)));
        ref.read(chatControllerProvider.notifier).consumeError();
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const PText('گفتگو'),
        leading: const AppBackButton(),
      ),
      body: LetteredBackdrop(
        child: SafeArea(
          child: Column(
            children: [
              Expanded(child: _messageList(state, myId)),
              _composer(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _messageList(ChatState state, String? myId) {
    if (!state.hasLoadedHistory) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.messages.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.screenPadding),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(AppImages.chat, width: 56, height: 56),
              const SizedBox(height: AppSpacing.lg),
              PText(
                'هنوز پیامی نیست. اولین نفر باش!',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: Colors.white),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xs),
              PText(
                'فقط پیام‌های یک ساعت اخیر نشان داده می‌شود.',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: const Color(0xFF9AA0A6)),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }
    // Not a lazy ListView.builder: a reply quote must be able to scroll to
    // any earlier message, which needs every bubble laid out. The server
    // only keeps the last hour, so the list stays small.
    final messages = state.messages;
    final ids = messages.map((m) => m.id).toSet();
    _messageKeys.removeWhere((id, _) => !ids.contains(id));
    return SingleChildScrollView(
      controller: _scroll,
      padding: const EdgeInsets.all(AppSpacing.screenPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < messages.length; i++)
            _buildBubble(messages, i, myId),
        ],
      ),
    );
  }

  Widget _buildBubble(List<ChatMessage> messages, int i, String? myId) {
    final m = messages[i];
    final isMine = m.playerId == myId;
    final quote = _parseReply(m.text);
    final quoted = quote == null
        ? null
        : _findQuoted(messages, i, quote.$1, quote.$2);
    return _MessageBubble(
      key: _messageKeys.putIfAbsent(m.id, GlobalKey.new),
      message: m,
      isMine: isMine,
      highlighted: m.id == _highlightId,
      onReply: isMine ? null : () => _startReply(m),
      onQuoteTap: quoted == null ? null : () => _jumpToMessage(quoted),
    );
  }

  Widget _composer(BuildContext context) {
    final remaining = _maxLength - _input.text.characters.length;
    final overLimit = remaining < 0;
    final replyTo = _replyTo;
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A2138).withValues(alpha: 0.3),
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (replyTo != null) _replyPreview(context, replyTo),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.md,
              AppSpacing.sm,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: TextField(
                    controller: _input,
                    focusNode: _inputFocus,
                    minLines: 1,
                    maxLines: 4,
                    textInputAction: TextInputAction.send,
                    onChanged: (_) => setState(() {}),
                    onSubmitted: (_) => _send(),
                    inputFormatters: [
                      LengthLimitingTextInputFormatter(_maxLength + 40),
                    ],
                    decoration: InputDecoration(
                      hintText: 'پیام فارسی بنویس…',
                      isDense: true,
                      filled: true,
                      fillColor: const Color(
                        0xFF1A2138,
                      ).withValues(alpha: 0.55),
                      suffixText: remaining < 60
                          ? remaining.toPersianString()
                          : null,
                      suffixStyle: TextStyle(
                        color: overLimit
                            ? context.gameTheme.invalidColor
                            : null,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                _SendButton(
                  enabled: _input.text.trim().isNotEmpty && !overLimit,
                  onTap: _send,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _replyPreview(BuildContext context, ChatMessage replyTo) {
    final color = context.gameTheme.heroGradient.colors.first;
    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        0,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2138).withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border(right: BorderSide(color: color, width: 3)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                PText(
                  'پاسخ به ${replyTo.nickname}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                PText(
                  _quoteSnippet(replyTo.text),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF9AA0A6).withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: _cancelReply,
            child: const Padding(
              padding: EdgeInsets.all(AppSpacing.xs),
              child: Icon(
                Icons.close_rounded,
                size: 16,
                color: Color(0xFF9AA0A6),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends ConsumerWidget {
  const _MessageBubble({
    super.key,
    required this.message,
    required this.isMine,
    this.highlighted = false,
    this.onReply,
    this.onQuoteTap,
  });

  final ChatMessage message;
  final bool isMine;

  /// Briefly true after a reply quote jumped here.
  final bool highlighted;

  /// Null when the quoted message isn't in the list (aged out of the hour).
  final VoidCallback? onQuoteTap;

  /// Null on your own messages — you can't reply to yourself.
  final VoidCallback? onReply;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gameTheme = context.gameTheme;
    final bubbleColor = isMine
        ? gameTheme.heroGradient.colors.first.withValues(alpha: 0.28)
        : Theme.of(context).cardTheme.color?.withValues(alpha: 0.8);

    final replyQuote = _parseReply(message.text);
    final bodyText = replyQuote?.$3 ?? message.text;

    // A room-invite message → offer a join button, except on your own
    // message (you're the host — you can't join your own room).
    final inviteCode = _roomCodeInText.firstMatch(bodyText)?.group(1);
    final showJoin = inviteCode != null && !isMine;

    final bubble = AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      foregroundDecoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: highlighted
              ? gameTheme.heroGradient.colors.first
              : Colors.transparent,
          width: 2,
        ),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: bubbleColor,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(AppRadius.md),
          topRight: const Radius.circular(AppRadius.md),
          bottomLeft: Radius.circular(isMine ? AppRadius.md : 4),
          bottomRight: Radius.circular(isMine ? 4 : AppRadius.md),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: PText(
              isMine ? '${message.nickname} (شما)' : message.nickname,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: gameTheme.heroGradient.colors.first,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (replyQuote != null)
            GestureDetector(
              onTap: onQuoteTap,
              child: Container(
                margin: const EdgeInsets.only(bottom: AppSpacing.xs),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  // A tint of the sender's own accent colour, not a generic
                  // black/white overlay — so the quote reads as "this is a
                  // quote of someone" at a glance instead of blending into
                  // the bubble it's quoted inside.
                  color: gameTheme.heroGradient.colors.first.withValues(
                    alpha: 0.22,
                  ),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  border: Border(
                    right: BorderSide(
                      color: gameTheme.heroGradient.colors.first,
                      width: 3,
                    ),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    PText(
                      replyQuote.$1,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: gameTheme.heroGradient.colors.first,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    PText(
                      replyQuote.$2,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.white.withValues(alpha: 0.55),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          PText(
            bodyText,
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(color: Colors.white),
          ),
          const SizedBox(height: 2),
          PText(
            _relativeTime(message.createdAtLocal),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: const Color(0xFF9AA0A6),
              fontSize: 10,
            ),
          ),
          if (showJoin) ...[
            const SizedBox(height: AppSpacing.sm),
            _JoinFromChatButton(code: inviteCode),
          ],
        ],
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        mainAxisAlignment: isMine
            ? MainAxisAlignment.start
            : MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isMine && onReply != null) ...[
            // First child in an RTL Row renders at the visual RIGHT edge —
            // i.e. right next to the text's own start side — not tucked
            // over by the avatar on the far left.
            GestureDetector(
              onTap: onReply,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xs),
                // reply_rounded points the LTR way by default; mirror it so
                // the arrow reads correctly for RTL "reply" placement.
                child: Transform.flip(
                  flipX: true,
                  child: const Icon(
                    Icons.reply_rounded,
                    size: 18,
                    color: Color(0xFF9AA0A6),
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
          ],
          Flexible(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.72,
              ),
              child: bubble,
            ),
          ),
          if (!isMine) ...[
            const SizedBox(width: AppSpacing.xs),
            // In RTL the row's end edge is the visual left — so the avatar
            // ends up top-left of the bubble.
            PlayerAvatar(name: message.nickname, radius: 14),
          ],
        ],
      ),
    );
  }
}

String _relativeTime(DateTime t) {
  final d = DateTime.now().difference(t);
  if (d.inSeconds < 45) return 'همین الان';
  if (d.inMinutes < 60) return '${d.inMinutes.toPersianString()} دقیقه پیش';
  return '${d.inHours.toPersianString()} ساعت پیش';
}

/// Small "ورود به اتاق" button under a room-invite chat message.
class _JoinFromChatButton extends ConsumerStatefulWidget {
  const _JoinFromChatButton({required this.code});

  final String code;

  @override
  ConsumerState<_JoinFromChatButton> createState() =>
      _JoinFromChatButtonState();
}

class _JoinFromChatButtonState extends ConsumerState<_JoinFromChatButton> {
  bool _joining = false;

  Future<void> _join() async {
    if (_joining) return;
    setState(() => _joining = true);
    ref.read(soundServiceProvider).playButtonClick();
    try {
      final code = await ref
          .read(roomControllerProvider.notifier)
          .joinRoom(widget.code);
      if (!mounted) return;
      context.go('/lobby', extra: code);
    } on RoomException catch (e) {
      if (mounted) ErrorDialog.show(context, e.message);
    } catch (_) {
      if (mounted) ErrorDialog.show(context, 'ارتباط با سرور برقرار نشد.');
    } finally {
      if (mounted) setState(() => _joining = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = context.gameTheme.heroGradient.colors.first;
    return GestureDetector(
      onTap: _joining ? null : _join,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_joining)
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            else
              const Icon(Icons.login_rounded, size: 14, color: Colors.white),
            const SizedBox(width: AppSpacing.xs),
            const PText(
              'ورود به اتاق',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SendButton extends StatelessWidget {
  const _SendButton({required this.enabled, required this.onTap});

  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = context.gameTheme.heroGradient.colors.first;
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Opacity(
        opacity: enabled ? 1 : 0.4,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          alignment: Alignment.center,
          child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
        ),
      ),
    );
  }
}
