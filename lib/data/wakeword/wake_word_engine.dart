import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:porcupine_flutter/porcupine_error.dart';
import 'package:porcupine_flutter/porcupine_manager.dart';

/// Detects "Hey Agentrix" with Picovoice Porcupine, using a custom-trained
/// keyword model (see assets/wake_words/) — on-device, no network call.
///
/// `PorcupineManager` owns mic capture itself (via its own voice processor),
/// so unlike the earlier flutter_sound-based attempts, nothing here streams
/// audio manually. Exposes the same shape `wake_word_provider.dart` already
/// expects (`start`/`stop`/`isListening`/`detections`).
class WakeWordEngine {
  // Picovoice access keys are meant to ship in the client app — they're a
  // usage-metering key tied to the console.picovoice.ai account, not a
  // backend secret like the Hume API key.
  static const _accessKey =
      '+pHmWgDxzwp//ODjmhMurh9LUg0GGHhjBgDYZwWhtp5Me2WR31e0UA==';

  static String get _keywordPath => Platform.isAndroid
      ? 'assets/wake_words/Hey-Agentrix_en_android_v4_0_0.ppn'
      : 'assets/wake_words/Hey-Agentrix_en_ios_v4_0_0.ppn';

  PorcupineManager? _manager;
  bool _listening = false;

  final _detections = StreamController<void>.broadcast();

  /// Fires once per wake-word detection. Broadcast, so it's safe whether or
  /// not a listener is attached yet when detection starts.
  Stream<void> get detections => _detections.stream;

  bool get isListening => _listening;

  /// Starts (or restarts) listening. No-ops if already listening. The
  /// manager is created once and reused across stop/start cycles — creating
  /// it loads the keyword model, which only needs to happen once per app run.
  Future<void> start() async {
    if (_listening) return;

    _manager ??= await PorcupineManager.fromKeywordPaths(
      _accessKey,
      [_keywordPath],
      _onDetected,
      errorCallback: _onError,
    );

    await _manager!.start();
    _listening = true;
  }

  void _onDetected(int keywordIndex) {
    // The native side keeps feeding frames to Porcupine until `stop()`
    // actually completes, so this callback can fire more than once for the
    // same utterance — this guard is what makes it idempotent, matching
    // [stop] being the single place that actually calls `_manager.stop()`.
    if (!_listening) return;
    debugPrint('Wake word detected');
    _listening = false;
    _detections.add(null);
  }

  void _onError(PorcupineException error) {
    debugPrint('Wake word engine error: ${error.message}');
  }

  Future<void> stop() async {
    _listening = false;
    await _manager?.stop();
  }

  Future<void> dispose() async {
    await stop();
    await _manager?.delete();
    _manager = null;
    await _detections.close();
  }
}
