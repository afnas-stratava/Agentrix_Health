import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/screen_back_button.dart';
import '../../../domain/entities/voice/voice_message.dart';
import '../../providers/voice_providers.dart';

/// Voice conversation with Agentrix, over Hume EVI. Reached from the mic
/// button in `ai_chat_screen.dart`'s header — the same assistant, a spoken
/// channel to it instead of typed.
///
/// The mic button *is* the interface; the transcript underneath is a
/// secondary confirmation of what was heard; a call itself needs no chrome
/// beyond that and a way to end it, which is why this reads closer to a
/// phone call than to the chat screen it's reached from.
class VoiceScreen extends ConsumerStatefulWidget {
  const VoiceScreen({super.key});

  @override
  ConsumerState<VoiceScreen> createState() => _VoiceScreenState();
}

class _VoiceScreenState extends ConsumerState<VoiceScreen> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // Deferred a frame — flipping provider state during another widget's
    // build (this screen's own first build, triggered by the push that got
    // us here) is exactly what Riverpod's "modifying state while building"
    // assertion exists to catch.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(voiceScreenVisibleProvider.notifier).state = true;
    });
  }

  @override
  void dispose() {
    // Best-effort: during a mass widget-tree teardown (a hot restart tearing
    // down the whole app in one pass, not a normal screen-to-screen
    // navigation) Riverpod's ProviderScope can already be gone by the time
    // this runs, and `ref.read` throws rather than silently no-op. Nothing
    // persists across that kind of teardown anyway, so there's nothing this
    // recovers by rethrowing.
    try {
      ref.read(voiceScreenVisibleProvider.notifier).state = false;
    } catch (_) {}
    _scrollController.dispose();
    super.dispose();
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

  @override
  Widget build(BuildContext context) {
    final voice = ref.watch(voiceSessionProvider);
    ref.listen(voiceSessionProvider, (previous, next) {
      if (next.transcript.length != previous?.transcript.length) {
        _scrollToEnd();
      }
    });

    final connected = switch (voice.callState) {
      VoiceCallState.connecting ||
      VoiceCallState.listening ||
      VoiceCallState.thinking ||
      VoiceCallState.speaking => true,
      VoiceCallState.idle || VoiceCallState.error => false,
    };

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.space5),
          child: Row(
            children: [
              const ScreenBackButton(),
              Expanded(
                child: Text(
                  'Agentrix',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.h6.copyWith(fontSize: 15),
                ),
              ),
              const SizedBox(width: 36),
            ],
          ),
        ),
        Expanded(
          child: voice.transcript.isEmpty
              ? const SizedBox.shrink()
              : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.space5,
                    vertical: AppSpacing.space4,
                  ),
                  itemCount: voice.transcript.length,
                  itemBuilder: (context, index) =>
                      _TranscriptLine(entry: voice.transcript[index]),
                ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.space5,
            AppSpacing.space4,
            AppSpacing.space5,
            AppSpacing.space8,
          ),
          child: Column(
            children: [
              Text(
                _prompt(voice.callState),
                textAlign: TextAlign.center,
                style: AppTextStyles.h4.copyWith(fontSize: 18),
              ),
              const SizedBox(height: AppSpacing.space2),
              Text(
                _status(voice.callState),
                style: AppTextStyles.muted,
              ),
              if (voice.callState == VoiceCallState.error &&
                  voice.errorMessage != null) ...[
                const SizedBox(height: AppSpacing.space2),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.space4,
                  ),
                  child: Text(
                    voice.errorMessage!,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.cardBody.copyWith(
                      color: AppColors.critical,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.space8),
              _MicButton(state: voice.callState),
              const SizedBox(height: AppSpacing.space6),
              if (connected)
                AppButton(
                  label: 'End conversation',
                  variant: AppButtonVariant.danger,
                  onPressed: () =>
                      ref.read(voiceSessionProvider.notifier).stop(),
                ),
            ],
          ),
        ),
      ],
    );
  }

  String _prompt(VoiceCallState state) => switch (state) {
    VoiceCallState.idle => 'How can I help you?',
    VoiceCallState.error => "Let's try that again",
    VoiceCallState.connecting ||
    VoiceCallState.listening ||
    VoiceCallState.thinking ||
    VoiceCallState.speaking => 'How can I help you?',
  };

  String _status(VoiceCallState state) => switch (state) {
    VoiceCallState.idle => 'Tap the mic to start talking',
    VoiceCallState.connecting => 'Connecting…',
    VoiceCallState.listening => 'Listening…',
    VoiceCallState.thinking => 'Thinking…',
    VoiceCallState.speaking => 'Speaking…',
    VoiceCallState.error => 'Tap the mic to try again',
  };
}

class _TranscriptLine extends StatelessWidget {
  const _TranscriptLine({required this.entry});

  final VoiceTranscriptEntry entry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.space3),
      child: Row(
        mainAxisAlignment: entry.fromUser
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
                color: entry.fromUser ? AppColors.brand600 : AppColors.surface,
                border: entry.fromUser
                    ? null
                    : Border.all(color: AppColors.hairline),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Text(
                entry.text,
                style: AppTextStyles.cardBody.copyWith(
                  fontSize: 14,
                  height: 1.4,
                  color: entry.fromUser ? AppColors.onBrand : AppColors.ink,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The call's one control. Idle/error is a plain tap target; every connected
/// state adds a ring animation so the button itself communicates which state
/// it's in without relying only on the caption below it — listening breathes
/// slowly, thinking pulses at a neutral pace, speaking pulses faster and
/// brighter.
class _MicButton extends StatefulWidget {
  const _MicButton({required this.state});

  final VoiceCallState state;

  @override
  State<_MicButton> createState() => _MicButtonState();
}

class _MicButtonState extends State<_MicButton> with TickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  );

  /// A one-shot expanding, fading ring — separate from [_pulse]'s continuous
  /// breathing loop — played exactly once on the idle/error → active
  /// transition. [_pulse] communicates *which* state a call is already in;
  /// this communicates the moment activation happened, which matters most
  /// when that transition was triggered by "Hey Agentrix" from a screen the
  /// user wasn't looking at this one from — they need an unmistakable "yes,
  /// it heard you" the instant this screen appears, not just a state-colored
  /// pulse that looks the same whether it started a second ago or an hour ago.
  late final AnimationController _activation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  );

  @override
  void initState() {
    super.initState();
    _syncAnimation();
    if (_active) _activation.forward(from: 0);
  }

  @override
  void didUpdateWidget(covariant _MicButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state != widget.state) {
      _syncAnimation();
      final wasActive =
          oldWidget.state != VoiceCallState.idle &&
          oldWidget.state != VoiceCallState.error;
      if (!wasActive && _active) _activation.forward(from: 0);
    }
  }

  void _syncAnimation() {
    final duration = switch (widget.state) {
      VoiceCallState.speaking => const Duration(milliseconds: 500),
      VoiceCallState.thinking => const Duration(milliseconds: 900),
      VoiceCallState.listening => const Duration(milliseconds: 1600),
      VoiceCallState.connecting => const Duration(milliseconds: 700),
      VoiceCallState.idle || VoiceCallState.error => Duration.zero,
    };
    if (duration == Duration.zero) {
      _pulse.stop();
      _pulse.value = 0;
      return;
    }
    _pulse.duration = duration;
    if (!_pulse.isAnimating) _pulse.repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    _activation.dispose();
    super.dispose();
  }

  bool get _active =>
      widget.state != VoiceCallState.idle &&
      widget.state != VoiceCallState.error;

  Color get _ringColor => switch (widget.state) {
    VoiceCallState.error => AppColors.critical,
    _ => AppColors.lime,
  };

  IconData get _icon => switch (widget.state) {
    VoiceCallState.error => Icons.mic_off_rounded,
    _ => Icons.mic_rounded,
  };

  void _onTap() {
    HapticFeedback.mediumImpact();
    final notifier = ProviderScope.containerOf(
      context,
    ).read(voiceSessionProvider.notifier);
    if (_active) return; // Ending the call is the dedicated button below.
    notifier.start();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: _active ? 'Voice call in progress' : 'Start talking to Agentrix',
      child: GestureDetector(
        onTap: _onTap,
        child: SizedBox(
          width: 168,
          height: 168,
          child: Stack(
            alignment: Alignment.center,
            children: [
              AnimatedBuilder(
                animation: _activation,
                builder: (context, _) {
                  // Curved rather than linear so the ring snaps outward
                  // quickly, the way a real activation chime does, instead
                  // of drifting — a slow expansion reads as ambient, not as
                  // "something just happened".
                  final t = Curves.easeOut.transform(_activation.value);
                  if (t >= 1) return const SizedBox.shrink();
                  return Container(
                    width: 96 + 72 * t,
                    height: 96 + 72 * t,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _ringColor.withValues(alpha: 0.6 * (1 - t)),
                        width: 3,
                      ),
                    ),
                  );
                },
              ),
              AnimatedBuilder(
                animation: _pulse,
                builder: (context, child) {
                  final wave = _pulse.value;
                  return Container(
                    width: 120,
                    height: 120,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: _active
                          ? [
                              BoxShadow(
                                color: _ringColor.withValues(
                                  alpha: 0.35 + 0.25 * wave,
                                ),
                                blurRadius: 20 + 20 * wave,
                                spreadRadius: 4 + 6 * wave,
                              ),
                            ]
                          : null,
                    ),
                    child: child,
                  );
                },
                child: Container(
                  width: 96,
                  height: 96,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: widget.state == VoiceCallState.error
                        ? AppColors.critical.withValues(alpha: 0.12)
                        : AppColors.lime,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _icon,
                    size: 36,
                    color: widget.state == VoiceCallState.error
                        ? AppColors.critical
                        : AppColors.ink,
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
