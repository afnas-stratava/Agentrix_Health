import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_shadows.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/screen_back_button.dart';
import '../../../domain/entities/chat/chat_message.dart';
import '../../providers/chat_provider.dart';
import 'main_shell.dart';
import 'voice_screen.dart';

/// Text chat with the in-app health assistant, reached from the tab bar's
/// centre action. Mirrors the other pushed screens' shape — a centred
/// heading row under [ScreenBackButton], content in the middle, a pinned bar
/// at the bottom — but the content is a message list instead of a form.
class AiChatScreen extends ConsumerStatefulWidget {
  const AiChatScreen({super.key});

  @override
  ConsumerState<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends ConsumerState<AiChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();

  /// How long the composer sits untouched before the assistant's avatar
  /// starts its idle breathing animation — a quiet nudge that something is
  /// still listening, rather than a screen that reads as stalled.
  static const _idleDelay = Duration(seconds: 5);

  Timer? _idleTimer;
  bool _idle = false;

  static const _prompts = [
    'How did I sleep?',
    "What's left in my food log today?",
    'Am I drinking enough water?',
    'Anything flagged in my labs?',
  ];

  @override
  void initState() {
    super.initState();
    _controller.addListener(_registerActivity);
    _armIdleTimer();
  }

  @override
  void dispose() {
    _idleTimer?.cancel();
    _controller.removeListener(_registerActivity);
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _registerActivity() {
    if (_idle) setState(() => _idle = false);
    _armIdleTimer();
  }

  void _armIdleTimer() {
    _idleTimer?.cancel();
    _idleTimer = Timer(_idleDelay, () {
      if (mounted) setState(() => _idle = true);
    });
  }

  void _scrollToEnd() {
    if (!_scrollController.hasClients) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  void _send([String? text]) {
    final message = text ?? _controller.text;
    if (message.trim().isEmpty) return;
    HapticFeedback.lightImpact();
    _controller.clear();
    _registerActivity();
    ref.read(chatProvider.notifier).send(message);
    _scrollToEnd();
  }

  @override
  Widget build(BuildContext context) {
    final chat = ref.watch(chatProvider);
    ref.listen(chatProvider, (previous, next) {
      if (next.messages.length != previous?.messages.length) _scrollToEnd();
    });

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.space5),
          child: Row(
            children: [
              const ScreenBackButton(),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  spacing: 8,
                  children: [
                    _AssistantAvatar(idle: _idle),
                    Text(
                      'Health Assistant',
                      style: AppTextStyles.h6.copyWith(
                        fontSize: 15,
                        letterSpacing: 0,
                      ),
                    ),
                  ],
                ),
              ),
              AppButton.icon(
                leading: const Icon(Icons.mic_none_rounded),
                backgroundColor: AppColors.surface,
                onPressed: () => MainShell.push(context, const VoiceScreen()),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.space5,
              AppSpacing.space4,
              AppSpacing.space5,
              AppSpacing.space4,
            ),
            itemCount: chat.messages.length + (chat.isTyping ? 1 : 0),
            itemBuilder: (context, index) {
              if (index == chat.messages.length) {
                return const _TypingBubble();
              }
              return _MessageBubble(message: chat.messages[index]);
            },
          ),
        ),
        if (chat.messages.length <= 1)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.space5,
              0,
              AppSpacing.space5,
              AppSpacing.space3,
            ),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final prompt in _prompts)
                  _PromptChip(label: prompt, onTap: () => _send(prompt)),
              ],
            ),
          ),
        _Composer(controller: _controller, onSend: () => _send()),
      ],
    );
  }
}

/// The header's bot mark. Idle, it breathes with a slow scale pulse — a
/// small tell that the assistant is still there and listening rather than a
/// static icon that reads the same whether the screen just opened or has sat
/// untouched for a minute. [AiChatScreen._registerActivity] drops [idle] the
/// moment the user types or sends, so the pulse only ever plays into silence.
class _AssistantAvatar extends StatefulWidget {
  const _AssistantAvatar({required this.idle});

  final bool idle;

  @override
  State<_AssistantAvatar> createState() => _AssistantAvatarState();
}

class _AssistantAvatarState extends State<_AssistantAvatar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );
  late final Animation<double> _scale = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeInOut,
  ).drive(Tween<double>(begin: 1, end: 1.18));

  @override
  void initState() {
    super.initState();
    if (widget.idle) _controller.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant _AssistantAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.idle && !oldWidget.idle) {
      _controller.repeat(reverse: true);
    } else if (!widget.idle && oldWidget.idle) {
      _controller.animateBack(0, curve: Curves.easeOut);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      child: const Icon(
        Icons.auto_awesome,
        size: 16,
        color: AppColors.brand600,
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final fromUser = message.role == ChatRole.user;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.space3),
      child: Row(
        mainAxisAlignment: fromUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.sizeOf(context).width * 0.78,
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.space4,
                vertical: 10,
              ),
              decoration: BoxDecoration(
                color: fromUser ? AppColors.brand600 : AppColors.surface,
                border: fromUser ? null : Border.all(color: AppColors.hairline),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(AppRadius.md),
                  topRight: const Radius.circular(AppRadius.md),
                  bottomLeft: Radius.circular(fromUser ? AppRadius.md : 4),
                  bottomRight: Radius.circular(fromUser ? 4 : AppRadius.md),
                ),
                boxShadow: fromUser ? null : AppShadows.sm,
              ),
              child: Text(
                message.text,
                style: AppTextStyles.cardBody.copyWith(
                  fontSize: 14,
                  height: 1.4,
                  color: fromUser ? AppColors.onBrand : AppColors.ink,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Three dots while the assistant "types" — the same shape as an incoming
/// bubble so it doesn't jump when the real reply lands in its place.
class _TypingBubble extends StatefulWidget {
  const _TypingBubble();

  @override
  State<_TypingBubble> createState() => _TypingBubbleState();
}

class _TypingBubbleState extends State<_TypingBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1000),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.space3),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.space4,
              vertical: 14,
            ),
            decoration: BoxDecoration(
              color: AppColors.surface,
              border: Border.all(color: AppColors.hairline),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(AppRadius.md),
                topRight: Radius.circular(AppRadius.md),
                bottomLeft: Radius.circular(4),
                bottomRight: Radius.circular(AppRadius.md),
              ),
              boxShadow: AppShadows.sm,
            ),
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) => Row(
                mainAxisSize: MainAxisSize.min,
                spacing: 4,
                children: List.generate(3, (i) {
                  final t = (_controller.value - i * 0.2) % 1.0;
                  final opacity = 0.3 + 0.7 * (1 - (t - 0.5).abs() * 2).clamp(0, 1);
                  return Opacity(
                    opacity: opacity.toDouble(),
                    child: const CircleAvatar(
                      radius: 3,
                      backgroundColor: AppColors.faint,
                    ),
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PromptChip extends StatelessWidget {
  const _PromptChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: AppColors.brand50,
            border: Border.all(color: AppColors.brand100),
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          child: Text(
            label,
            style: AppTextStyles.cardMeta.copyWith(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.brand600,
            ),
          ),
        ),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({required this.controller, required this.onSend});

  final TextEditingController controller;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.space5,
        AppSpacing.space3,
        AppSpacing.space5,
        AppSpacing.space3 + MediaQuery.paddingOf(context).bottom,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.hairline)),
      ),
      child: Row(
        spacing: AppSpacing.space2,
        children: [
          Expanded(
            child: Container(
              constraints: const BoxConstraints(minHeight: 44, maxHeight: 120),
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 10,
              ),
              decoration: BoxDecoration(
                color: AppColors.canvas,
                border: Border.all(color: AppColors.hairline),
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
              child: TextField(
                controller: controller,
                minLines: 1,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSend(),
                style: AppTextStyles.input.copyWith(fontSize: 14),
                decoration: InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  hintText: 'Ask about sleep, food, hydration, labs…',
                  hintStyle: AppTextStyles.input.copyWith(
                    fontSize: 14,
                    color: AppColors.faint,
                  ),
                ),
              ),
            ),
          ),
          Semantics(
            button: true,
            label: 'Send',
            child: InkWell(
              onTap: onSend,
              borderRadius: BorderRadius.circular(AppRadius.pill),
              child: Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: AppColors.lime,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.arrow_upward,
                  size: 18,
                  color: AppColors.ink,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
