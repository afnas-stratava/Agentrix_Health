import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/voice/voice_message.dart';
import 'voice_providers.dart';
import 'wake_word_provider.dart';

/// The single source of truth for "what currently owns the microphone" —
/// requested explicitly as its own enum rather than inferred ad hoc from
/// [WakeWordController] and [VoiceSessionController] separately, which is
/// exactly what led to `voice_screen.dart`'s dispose-order bug earlier: two
/// places independently guessing at shared state instead of one place
/// deriving it.
///
/// This is a pure projection, not a third state machine — a plain
/// `Provider`, not a `Notifier`, so there is no second place anything could
/// set it out of sync with the two systems it describes. [WakeWordEngine]
/// and Hume's [VoiceSessionController] remain exactly as owned/independent
/// as they were; this only reads them.
enum VoiceAssistantState {
  /// The wake-word listener owns the mic, waiting for "Hey Agentrix".
  idleListening,

  /// Between the wake word firing and the Hume call actually connecting —
  /// neither system holds the mic for that gap — or Hume's own `connecting`
  /// phase once the handoff has happened.
  activating,

  /// A Hume call is in progress (listening/thinking/speaking); wake-word
  /// listening is paused for the duration.
  humeSessionActive,

  /// The Hume call failed. Shown only until wake-word listening has
  /// actually resumed underneath (see below) — `VoiceCallState.error` itself
  /// stays set until the next `start()`, so gating on it alone would show
  /// "error" forever even once listening is genuinely back.
  error,
}

final voiceAssistantStateProvider = Provider<VoiceAssistantState>((ref) {
  final callState = ref.watch(
    voiceSessionProvider.select((s) => s.callState),
  );
  final wakeWordStatus = ref.watch(wakeWordControllerProvider);

  if (callState == VoiceCallState.listening ||
      callState == VoiceCallState.thinking ||
      callState == VoiceCallState.speaking) {
    return VoiceAssistantState.humeSessionActive;
  }

  if (callState == VoiceCallState.error &&
      wakeWordStatus != WakeWordStatus.listening) {
    return VoiceAssistantState.error;
  }

  if (callState == VoiceCallState.connecting ||
      wakeWordStatus == WakeWordStatus.activating) {
    return VoiceAssistantState.activating;
  }

  return VoiceAssistantState.idleListening;
});
