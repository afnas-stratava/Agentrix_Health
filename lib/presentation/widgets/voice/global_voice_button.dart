import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../navigation/app_navigator.dart';
import '../../providers/app_stage_provider.dart';
import '../../providers/voice_assistant_state_provider.dart';
import '../../providers/voice_providers.dart';

/// Reaches the voice assistant from anywhere in the app, not just the chat
/// screen's mic button — mounted once in `app.dart` via `MaterialApp.builder`,
/// outside the `Navigator`, so it floats above every pushed route and every
/// tab instead of living inside any one screen's tree.
///
/// [voiceSessionProvider] already keeps a call running while the user
/// navigates elsewhere (it's a plain `NotifierProvider`, not scoped to
/// `VoiceScreen`'s widget lifetime) — this button is what makes that
/// reachable: tap to open the voice screen whether starting fresh or
/// rejoining a call already in progress.
class GlobalVoiceButton extends ConsumerWidget {
  const GlobalVoiceButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stage = ref.watch(appStageProvider);
    final onVoiceScreen = ref.watch(voiceScreenVisibleProvider);
    // Onboarding has no signed-in session yet, and the voice screen
    // shouldn't float a duplicate of its own mic button on top of itself.
    if (stage != AppStage.main || onVoiceScreen) {
      return const SizedBox.shrink();
    }

    final errorMessage = ref.watch(
      voiceSessionProvider.select((s) => s.errorMessage),
    );
    final assistantState = ref.watch(voiceAssistantStateProvider);

    return Positioned(
      right: 20,
      bottom: 110,
      child: SafeArea(
        top: false,
        left: false,
        right: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _StateLabel(state: assistantState, errorMessage: errorMessage),
            const SizedBox(height: AppSpacing.space2),
            _Bubble(assistantState: assistantState),
          ],
        ),
      ),
    );
  }
}

/// The plain-language readout of [VoiceAssistantState] — the "single source
/// of truth for what's currently using the mic" made visible, rather than
/// left for the mic bubble's colour/pulse alone to imply.
class _StateLabel extends StatelessWidget {
  const _StateLabel({required this.state, this.errorMessage});

  final VoiceAssistantState state;
  final String? errorMessage;

  String get _text => switch (state) {
    VoiceAssistantState.idleListening => 'Listening for "Hey Agentrix"…',
    VoiceAssistantState.activating => 'Activating…',
    VoiceAssistantState.humeSessionActive => 'Connected to Hume',
    VoiceAssistantState.error => errorMessage ?? 'Voice call failed',
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: AppColors.hairline),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 220),
        child: Text(
          _text,
          style: AppTextStyles.cardMeta.copyWith(fontSize: 11),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}

class _Bubble extends StatefulWidget {
  const _Bubble({required this.assistantState});

  final VoiceAssistantState assistantState;

  @override
  State<_Bubble> createState() => _BubbleState();
}

class _BubbleState extends State<_Bubble> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );

  @override
  void initState() {
    super.initState();
    _syncAnimation();
  }

  @override
  void didUpdateWidget(covariant _Bubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.assistantState != widget.assistantState) _syncAnimation();
  }

  void _syncAnimation() {
    if (_active) {
      if (!_pulse.isAnimating) _pulse.repeat(reverse: true);
    } else {
      _pulse.stop();
      _pulse.value = 0;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  // Driven by the derived state, not raw VoiceCallState directly, so the
  // bubble can never visually disagree with _StateLabel next to it — e.g.
  // pulsing lime the instant a wake-word detection fires, well before
  // Hume's own callState leaves `idle`.
  bool get _active => widget.assistantState != VoiceAssistantState.idleListening;

  @override
  Widget build(BuildContext context) {
    final error = widget.assistantState == VoiceAssistantState.error;

    return Semantics(
      button: true,
      label: _active
          ? 'Voice call in progress — reopen'
          : 'Talk to Agentrix',
      child: GestureDetector(
        onTap: () {
          HapticFeedback.mediumImpact();
          AppNavigator.openVoiceScreen();
        },
        child: AnimatedBuilder(
          animation: _pulse,
          builder: (context, child) {
            final wave = _pulse.value;
            return Container(
              width: 56,
              height: 56,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: (error ? AppColors.critical : AppColors.lime)
                        .withValues(alpha: _active ? 0.35 + 0.25 * wave : 0.25),
                    blurRadius: _active ? 14 + 10 * wave : 10,
                    spreadRadius: _active ? 2 + 3 * wave : 1,
                  ),
                ],
              ),
              child: child,
            );
          },
          child: Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: error
                  ? AppColors.critical.withValues(alpha: 0.12)
                  : AppColors.lime,
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFF7FBF3), width: 3),
            ),
            child: Icon(
              error ? Icons.mic_off_rounded : Icons.mic_rounded,
              size: 22,
              color: error ? AppColors.critical : AppColors.ink,
            ),
          ),
        ),
      ),
    );
  }
}
