import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../data/wakeword/wake_word_engine.dart';
import '../../domain/entities/voice/voice_message.dart';
import '../navigation/app_navigator.dart';
import 'app_stage_provider.dart';
import 'voice_providers.dart';

enum WakeWordStatus {
  idle,
  listening,

  /// The wake word fired and the engine is stopping/handing off to Hume —
  /// between here and [VoiceCallState.connecting] picking up, *neither*
  /// system holds the mic. See [voiceAssistantStateProvider], which is the
  /// reason this exists as its own value rather than collapsing into
  /// [idle]: without it, that provider has no way to tell "genuinely idle"
  /// apart from "mid-handoff" during the gap.
  activating,

  error,
}

/// Decides *when* [WakeWordEngine] should be running and reacts to a
/// detection; the engine itself just knows how to run.
///
/// Listening is on whenever the app is in the signed-in main experience and
/// no call is already active — off during onboarding (no session to wake
/// into), and off for the duration of a Hume call, since that call's own
/// [FlutterSoundRecorder] in `voice_providers.dart` needs the microphone and
/// two recorders cannot open it at once. `_sync` re-evaluates on every
/// relevant change, so a call ending hands the mic straight back to this
/// engine rather than requiring the user to do anything.
///
/// This is foreground-only by design, matching the deferred wake-word scope:
/// no foreground service, no background-mic permission, nothing running once
/// the app itself is backgrounded. "Hey Agentrix" while the app is closed or
/// minimized is the separate native layer planned for later, not this.
class WakeWordController extends Notifier<WakeWordStatus> {
  final WakeWordEngine _engine = WakeWordEngine();
  StreamSubscription<void>? _detectionSubscription;

  @override
  WakeWordStatus build() {
    ref.onDispose(() => unawaited(_engine.dispose()));

    _detectionSubscription = _engine.detections.listen((_) => _onDetected());
    ref.onDispose(() => _detectionSubscription?.cancel());

    ref.listen(appStageProvider, (_, _) => _sync());
    ref.listen(
      voiceSessionProvider.select((s) => s.callState),
      (_, _) => _sync(),
    );
    // Deferred a frame — `build()` returning is what commits the initial
    // state; starting the engine (which itself sets state) belongs after
    // that, not during it.
    Future.microtask(_sync);

    return WakeWordStatus.idle;
  }

  bool get _callActive {
    final callState = ref.read(voiceSessionProvider).callState;
    return callState != VoiceCallState.idle && callState != VoiceCallState.error;
  }

  Future<void> _sync() async {
    final shouldListen =
        ref.read(appStageProvider) == AppStage.main && !_callActive;

    if (shouldListen && !_engine.isListening) {
      await _start();
    } else if (!shouldListen && _engine.isListening) {
      await _engine.stop();
      state = WakeWordStatus.idle;
    }
  }

  Future<void> _start() async {
    // Wake-word listening is now the app's default mic behaviour from
    // launch (not a convenience layered onto an already-mic-permitted
    // flow), so this actively requests access rather than silently skipping
    // when it isn't granted yet.
    final status = await Permission.microphone.request();
    if (!status.isGranted) {
      state = WakeWordStatus.error;
      return;
    }

    try {
      await _engine.start();
      state = WakeWordStatus.listening;
      debugPrint('Wake word listening started');
    } catch (error) {
      debugPrint('Wake word listening failed: ${error.runtimeType}');
      state = WakeWordStatus.error;
    }
  }

  void _onDetected() {
    debugPrint('Wake word detected');
    // Set synchronously, before the await below — the alternative (leaving
    // this at `listening` until the engine actually finishes stopping) means
    // `voiceAssistantStateProvider` would keep reporting "listening for Hey
    // Agentrix" for the whole teardown, which is backwards: the engine is on
    // its way out from the instant this fires, not still listening.
    state = WakeWordStatus.activating;
    // Fired first and synchronously, before any of the async work below —
    // "Hey Agentrix" can be said while looking at any screen, not just one
    // that's mid-transition into the call, so the buzz is the only feedback
    // guaranteed to land the instant the word is heard. The visual
    // confirmation (VoiceScreen's activation ripple) follows a moment later.
    HapticFeedback.mediumImpact();
    unawaited(
      _engine.stop().then((_) {
        AppNavigator.openVoiceScreen();
        ref.read(voiceSessionProvider.notifier).start();
      }),
    );
  }
}

final wakeWordControllerProvider =
    NotifierProvider<WakeWordController, WakeWordStatus>(
      WakeWordController.new,
    );
