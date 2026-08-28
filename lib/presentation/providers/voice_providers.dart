import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart' show Level;
import 'package:permission_handler/permission_handler.dart';

import '../../core/config/api_endpoints.dart';
import '../../data/voice/hume_voice_client.dart';
import '../../data/voice/wav_audio.dart';
import '../../domain/entities/voice/voice_message.dart';
import '../voice/agentrix_tool_registry.dart';

/// Why a voice session couldn't start or dropped, kept separate from the
/// human-readable message so the UI can vary phrasing/icon by kind later
/// without re-parsing text.
enum VoiceErrorKind {
  microphonePermissionDenied,
  backendUnavailable,
  tokenFailure,
  connectionFailed,
  disconnected,
  audioFailure,
}

class VoiceSessionException implements Exception {
  const VoiceSessionException(this.kind, this.message);

  final VoiceErrorKind kind;
  final String message;

  @override
  String toString() => message;
}

/// Yellow-highlighted so the audio playback path stands out in logcat while
/// diagnosing "everything logs fine but nothing plays" — remove once
/// playback is confirmed reliable.
void _audioLog(String message) {
  debugPrint('\x1B[33m[AUDIO] $message\x1B[0m');
}

class VoiceUiState {
  const VoiceUiState({
    this.callState = VoiceCallState.idle,
    this.transcript = const [],
    this.errorMessage,
  });

  final VoiceCallState callState;
  final List<VoiceTranscriptEntry> transcript;
  final String? errorMessage;

  VoiceUiState copyWith({
    VoiceCallState? callState,
    List<VoiceTranscriptEntry>? transcript,
  }) => VoiceUiState(
    callState: callState ?? this.callState,
    transcript: transcript ?? this.transcript,
  );
}

/// Owns one voice call end to end: token fetch, the Hume socket, microphone
/// capture and assistant playback. Everything here reacts to
/// [HumeInboundMessage]s from `hume_voice_client.dart` — this file adds the
/// two things that aren't protocol, mic I/O and playback, and derives
/// [VoiceCallState] from what arrives.
///
/// Future Hume tool calls (`get_latest_vitals` and friends — see the
/// integration plan) are a new case in [_handleHumeMessage]'s switch that
/// calls into `agentrix_backend` and sends a `tool_response`; nothing else
/// here needs to change for that.
class VoiceSessionController extends Notifier<VoiceUiState> {
  final HumeVoiceClient _client = HumeVoiceClient();
  // Level.debug is flutter_sound's own default and floods logcat with an
  // FS:---> / FS:<--- trace line (several, each printing a full stack frame)
  // for every recorder/player call — enough to bury the app's own
  // "Hume connection established" / "Hume message: ..." lines that actually
  // matter when diagnosing a dropped call.
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder(
    logLevel: Level.warning,
  );
  final FlutterSoundPlayer _player = FlutterSoundPlayer(
    logLevel: Level.warning,
  );

  StreamController<Uint8List>? _micSink;
  StreamSubscription<Uint8List>? _micSubscription;
  StreamSubscription<HumeInboundMessage>? _humeSubscription;

  bool _recorderOpen = false;
  bool _playerOpen = false;
  bool _playerStreaming = false;

  /// Serializes [_ensurePlayerReady] the same way [_exclusive] serializes
  /// [start]/[stop]. Hume streams several `audio_output` frames back-to-back
  /// per utterance, each handled via `unawaited(_enqueueAudio(...))` — with
  /// no lock, two frames arriving close together could both see
  /// `_playerStreaming == false` before either finished awaiting
  /// `startPlayerFromStream()`, calling it twice concurrently.
  /// `flutter_sound` calls `_stop()` at the start of every
  /// `startPlayerFromStream()`, so the second call silently tore down the
  /// stream the first one had just opened — `_playerStreaming` stayed `true`
  /// throughout, so nothing noticed and all further audio was dropped. This
  /// queue means only one setup can run at a time; anything that arrives
  /// while it's in flight just waits and then sees `_playerStreaming` already
  /// `true`.
  Future<void> _playerSetupQueue = Future.value();

  /// Decoded PCM chunks waiting to be fed to the player. Draining this
  /// sequentially — awaiting each `feedUint8FromStream` before the next — is
  /// what keeps playback gapless; see [_drainAudioQueue].
  final Queue<Uint8List> _audioQueue = Queue();
  bool _draining = false;

  /// Set by [HumeAssistantEnd]; only flips the UI back to LISTENING once the
  /// queue it signalled the end of has actually finished playing.
  bool _assistantTurnEnded = false;

  /// Serializes every state-changing operation — [start], [stop], and the
  /// teardown a mid-call [_fail] triggers — onto one queue.
  ///
  /// Without this, tapping "End conversation" while [start] was still
  /// awaiting the token fetch or `openRecorder()` ran [_teardown]
  /// concurrently with [_startMicrophone] on the *same* recorder instance:
  /// `stopRecorder()`/`closeRecorder()` racing `openRecorder()`/
  /// `startRecorder()` corrupts `_recorderOpen`/`_micSink` and can leave a
  /// live `AudioRecord` session neither side thinks is open anymore. Routing
  /// every entry point through here means a [stop] that lands mid-[start]
  /// simply waits for it to finish connecting before tearing down, instead
  /// of touching the recorder while it's still being opened.
  Future<void> _opQueue = Future.value();

  Future<T> _exclusive<T>(Future<T> Function() action) {
    final result = _opQueue.then((_) => action());
    _opQueue = result.then((_) {}, onError: (_) {});
    return result;
  }

  @override
  VoiceUiState build() {
    ref.onDispose(() => unawaited(_exclusive(_teardown)));
    return const VoiceUiState();
  }

  /// Requests the microphone, fetches a Hume token from `agentrix_backend`,
  /// connects the EVI socket, then starts streaming microphone audio.
  /// Connects before recording starts, per Hume's protocol — see
  /// [HumeVoiceClient.connect].
  Future<void> start() => _exclusive(_startImpl);

  Future<void> _startImpl() async {
    if (state.callState != VoiceCallState.idle &&
        state.callState != VoiceCallState.error) {
      return;
    }

    state = const VoiceUiState(callState: VoiceCallState.connecting);
    debugPrint('Voice session started');

    try {
      final micStatus = await Permission.microphone.request();
      if (!micStatus.isGranted) {
        throw const VoiceSessionException(
          VoiceErrorKind.microphonePermissionDenied,
          'Agentrix needs microphone access to talk with you. Enable it in '
              'system settings and try again.',
        );
      }

      final token = await _fetchVoiceToken();

      try {
        await _client.connect(
          accessToken: token.accessToken,
          configId: token.configId,
        );
      } catch (_) {
        throw const VoiceSessionException(
          VoiceErrorKind.connectionFailed,
          'Could not connect to the voice service. Check your connection '
              'and try again.',
        );
      }
      _humeSubscription = _client.messages.listen(
        _handleHumeMessage,
        onError: (Object error) {
          debugPrint('Voice session stream error: ${error.runtimeType}');
          _fail(
            const VoiceSessionException(
              VoiceErrorKind.disconnected,
              'The voice connection dropped. Tap the mic to try again.',
            ),
          );
        },
        onDone: () {
          if (state.callState != VoiceCallState.idle) {
            _fail(
              const VoiceSessionException(
                VoiceErrorKind.disconnected,
                'The voice connection ended. Tap the mic to try again.',
              ),
            );
          }
        },
      );

      await _startMicrophone();

      state = state.copyWith(callState: VoiceCallState.listening);
    } catch (error) {
      await _teardown();
      state = VoiceUiState(
        callState: VoiceCallState.error,
        errorMessage: _describe(error),
      );
    }
  }

  /// User-initiated end of the call — stops the microphone first, then
  /// closes the socket, per the required shutdown order.
  Future<void> stop() => _exclusive(_stopImpl);

  Future<void> _stopImpl() async {
    if (state.callState == VoiceCallState.idle) return;
    await _teardown();
    state = const VoiceUiState();
    debugPrint('Voice session ended');
  }

  Future<void> _startMicrophone() async {
    try {
      await _recorder.openRecorder();
      _recorderOpen = true;

      final sink = StreamController<Uint8List>();
      _micSink = sink;
      // Hume supports full-duplex barge-in — it'll happily accept audio_input
      // while its own reply is still playing — but that means the phone's
      // speaker output reaching the mic reads to Hume as the user talking
      // over it. `voice_communication` + echo cancellation below cuts down
      // the acoustic echo, but doesn't eliminate it at real playback volume
      // through a loudspeaker (confirmed on-device: the transcript showed
      // the assistant's own words echoed back as "the user's" speech,
      // triggering a `user_interruption` that cut its reply off mid-sentence
      // with no error anywhere, since interruption is a normal protocol
      // message, not a failure). Simplest reliable fix, and what most voice
      // assistants do: don't forward mic audio to Hume while it's speaking,
      // so there's nothing for it to mishear. Trades away true barge-in for
      // playback that never self-interrupts.
      _micSubscription = sink.stream.listen((chunk) {
        if (state.callState == VoiceCallState.speaking) return;
        _client.sendAudioChunk(chunk);
      });

      await _recorder.startRecorder(
        codec: Codec.pcm16,
        toStream: sink.sink,
        sampleRate: HumeVoiceClient.sampleRate,
        numChannels: 1,
        audioSource: AudioSource.voice_communication,
        enableEchoCancellation: true,
      );
    } catch (_) {
      throw const VoiceSessionException(
        VoiceErrorKind.audioFailure,
        'Could not access the microphone. Check that no other app is using '
            'it and try again.',
      );
    }
  }

  void _handleHumeMessage(HumeInboundMessage message) {
    switch (message) {
      case HumeUserMessage(:final content, :final interim):
        if (content.isEmpty) return;
        state = state.copyWith(
          // A non-interim (final) transcript means Hume has what it needs
          // and is generating a reply — Hume has no explicit "thinking"
          // signal, so this transition is inferred from that instead.
          callState: interim
              ? VoiceCallState.listening
              : VoiceCallState.thinking,
          transcript: _withUserLine(content, interim: interim),
        );
      case HumeAssistantMessage(:final content):
        if (content.isEmpty) return;
        state = state.copyWith(
          transcript: [
            ...state.transcript,
            VoiceTranscriptEntry(fromUser: false, text: content),
          ],
        );
      case HumeAudioOutput(:final data):
        state = state.copyWith(callState: VoiceCallState.speaking);
        unawaited(_enqueueAudio(data));
      case HumeAssistantEnd():
        _assistantTurnEnded = true;
        if (_audioQueue.isEmpty && !_draining) {
          state = state.copyWith(callState: VoiceCallState.listening);
        }
      case HumeUserInterruption():
        _audioLog('User interruption received — stopping playback');
        _clearAudioQueue();
        state = state.copyWith(callState: VoiceCallState.listening);
      case HumeToolCall(
        :final toolCallId,
        :final name,
        :final parameters,
      ):
        unawaited(_handleToolCall(toolCallId, name, parameters));
      case HumeError(:final message):
        _fail(VoiceSessionException(VoiceErrorKind.disconnected, message));
      case HumeChatMetadata():
      case HumeUnknownMessage():
        break; // Not acted on yet.
    }
  }

  /// Runs a `tool_call` against [AgentrixToolRegistry] and reports the
  /// result back to Hume. Never lets a bad or unknown tool call take the
  /// call down — every path here ends in a `tool_response`/`tool_error`,
  /// not an exception escaping to [_handleHumeMessage]'s caller.
  ///
  /// Not routed through [_exclusive]: a tool call is independent of the
  /// mic/call lifecycle, and if the user ends the call mid-execution,
  /// [HumeVoiceClient]'s `_send` is already a no-op once disconnected (same
  /// as [sendAudioChunk]) — nothing extra to guard here.
  Future<void> _handleToolCall(
    String toolCallId,
    String name,
    Map<String, dynamic> parameters,
  ) async {
    debugPrint('Hume tool call received: $name');

    if (!AgentrixToolRegistry.isKnown(name)) {
      debugPrint('Hume tool call rejected — not in whitelist: $name');
      _client.sendToolError(
        toolCallId: toolCallId,
        error: 'unknown_tool',
        content: 'Tool "$name" is not available.',
      );
      return;
    }

    debugPrint('Hume tool execution started: $name');
    try {
      final result = await AgentrixToolRegistry.execute(ref, name, parameters);
      debugPrint('Hume tool execution completed: $name');
      _client.sendToolResponse(toolCallId: toolCallId, content: result);
    } catch (error) {
      debugPrint('Hume tool execution failed: $name (${error.runtimeType})');
      _client.sendToolError(
        toolCallId: toolCallId,
        error: 'execution_failed',
        content: 'Could not complete "$name".',
      );
    }
  }

  /// Replaces the trailing interim user line as Hume refines it, rather than
  /// appending a new one per fragment — otherwise "how" / "how did" / "how
  /// did I" would each show as separate transcript lines.
  List<VoiceTranscriptEntry> _withUserLine(
    String content, {
    required bool interim,
  }) {
    final trailingInterim =
        state.transcript.isNotEmpty && state.transcript.last.fromUser;
    final base = trailingInterim
        ? state.transcript.sublist(0, state.transcript.length - 1)
        : state.transcript;
    return [...base, VoiceTranscriptEntry(fromUser: true, text: content)];
  }

  Future<void> _enqueueAudio(String base64Wav) async {
    final WavAudio? wav;
    try {
      wav = parseWav(base64Decode(base64Wav));
    } catch (error) {
      debugPrint('Could not decode audio_output: ${error.runtimeType}');
      return;
    }
    if (wav == null) return;

    try {
      await _ensurePlayerReady(wav);
    } catch (error) {
      debugPrint('Could not start voice playback: ${error.runtimeType}');
      return;
    }

    _audioQueue.add(wav.pcm);
    unawaited(_drainAudioQueue());
  }

  Future<void> _ensurePlayerReady(WavAudio wav) {
    final result = _playerSetupQueue.then((_) async {
      _audioLog(
        'Player open=$_playerOpen, '
        'streaming=$_playerStreaming, '
        'channels=${wav.channels}, '
        'sampleRate=${wav.sampleRate}',
      );

      if (!_playerOpen) {
        _audioLog('Opening player...');
        await _player.openPlayer();
        _playerOpen = true;
        _audioLog('Player opened');
      }
      if (!_playerStreaming) {
        _audioLog(
          'Starting PCM stream '
          '(channels=${wav.channels}, sampleRate=${wav.sampleRate})...',
        );
        await _player.startPlayerFromStream(
          codec: Codec.pcm16,
          interleaved: true,
          numChannels: wav.channels,
          sampleRate: wav.sampleRate,
          bufferSize: 8192,
        );
        _playerStreaming = true;
        _audioLog('PCM stream started');
      }
    });
    _playerSetupQueue = result.then((_) {}, onError: (_) {});
    return result;
  }

  /// Feeds queued chunks to the player one at a time, awaiting each before
  /// the next — `flutter_sound` documents this as required for gapless
  /// playback, and it's what turns [_audioQueue] into real backpressure
  /// instead of a pile of concurrent, out-of-order feed calls.
  Future<void> _drainAudioQueue() async {
    if (_draining) {
      _audioLog('Drain already running — skipping');
      return;
    }
    _draining = true;
    try {
      _audioLog('Drain started, queue=${_audioQueue.length}');
      while (_audioQueue.isNotEmpty) {
        final chunk = _audioQueue.removeFirst();
        _audioLog(
          'Feeding ${chunk.length} bytes (remaining=${_audioQueue.length})',
        );
        await _player.feedUint8FromStream(chunk);
      }
      _audioLog('Drain finished');
    } catch (error, stackTrace) {
      _audioLog('PLAYBACK ERROR: $error');
      debugPrint('$stackTrace');
    } finally {
      _draining = false;
      if (_assistantTurnEnded &&
          _audioQueue.isEmpty &&
          state.callState == VoiceCallState.speaking) {
        _assistantTurnEnded = false;
        state = state.copyWith(callState: VoiceCallState.listening);
        _audioLog('Assistant turn ended → listening');
      }
    }
  }

  /// Drops queued and in-flight assistant audio on [HumeUserInterruption] —
  /// playing a stale reply over the user's own voice is exactly the bug this
  /// exists to prevent.
  void _clearAudioQueue() {
    _audioLog(
      'Clearing audio queue '
      '(queue=${_audioQueue.length}, streaming=$_playerStreaming)',
    );
    _audioQueue.clear();
    _assistantTurnEnded = false;
    if (_playerStreaming) {
      _audioLog('Stopping player...');
      unawaited(_player.stopPlayer());
      _playerStreaming = false;
      _audioLog('Player stopped');
    }
  }

  /// Mid-call failure (stream error, `error` message, socket closing
  /// unexpectedly) — goes through [_exclusive] too, so it can't tear the
  /// recorder down while [_startImpl] is still setting it up.
  ///
  /// A [HumeError] message and the `onDone` that follows it (Hume closes the
  /// socket right after sending one) both call this in quick succession —
  /// without the `error` branch in the guard below, the generic "connection
  /// ended" from `onDone` always ran second and silently overwrote Hume's
  /// actual diagnosis with a useless one. Once *any* failure has landed,
  /// later ones are dropped rather than allowed to clobber it.
  void _fail(VoiceSessionException error) {
    unawaited(
      _exclusive(() async {
        if (state.callState == VoiceCallState.idle ||
            state.callState == VoiceCallState.error) {
          return;
        }
        final transcript = state.transcript;
        await _teardown();
        state = VoiceUiState(
          callState: VoiceCallState.error,
          errorMessage: error.message,
          transcript: transcript,
        );
      }),
    );
  }

  String _describe(Object error) {
    if (error is VoiceSessionException) return error.message;
    return 'Something went wrong starting the voice session. Please try '
        'again.';
  }

  Future<({String accessToken, String configId})> _fetchVoiceToken() async {
    final http.Response response;
    try {
      response = await http
          .get(ApiEndpoints.voiceToken)
          .timeout(const Duration(seconds: 10));
    } catch (_) {
      throw const VoiceSessionException(
        VoiceErrorKind.backendUnavailable,
        'Could not reach Agentrix. Check your connection and try again.',
      );
    }

    if (response.statusCode != 200) {
      throw const VoiceSessionException(
        VoiceErrorKind.tokenFailure,
        'Could not start a voice session right now. Please try again '
            'shortly.',
      );
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final accessToken = body['access_token'] as String?;
    final configId = body['config_id'] as String?;
    if (accessToken == null || configId == null) {
      throw const VoiceSessionException(
        VoiceErrorKind.tokenFailure,
        'Could not start a voice session right now. Please try again '
            'shortly.',
      );
    }
    return (accessToken: accessToken, configId: configId);
  }

  Future<void> _teardown() async {
    await _humeSubscription?.cancel();
    _humeSubscription = null;

    // Microphone stops before the socket closes.
    if (_recorderOpen) {
      try {
        await _recorder.stopRecorder();
      } catch (error) {
        debugPrint('Error stopping recorder: ${error.runtimeType}');
      }
    }
    await _micSubscription?.cancel();
    _micSubscription = null;
    await _micSink?.close();
    _micSink = null;
    if (_recorderOpen) {
      try {
        await _recorder.closeRecorder();
      } catch (error) {
        debugPrint('Error closing recorder: ${error.runtimeType}');
      }
      _recorderOpen = false;
    }

    await _client.disconnect();

    _audioQueue.clear();
    _assistantTurnEnded = false;
    if (_playerStreaming) {
      try {
        await _player.stopPlayer();
      } catch (error) {
        debugPrint('Error stopping player: ${error.runtimeType}');
      }
      _playerStreaming = false;
    }
    if (_playerOpen) {
      try {
        await _player.closePlayer();
      } catch (error) {
        debugPrint('Error closing player: ${error.runtimeType}');
      }
      _playerOpen = false;
    }
  }
}

final voiceSessionProvider =
    NotifierProvider<VoiceSessionController, VoiceUiState>(
      VoiceSessionController.new,
    );

/// Whether `voice_screen.dart` is the screen currently on top. Set by that
/// screen itself in `initState`/`dispose` — [VoiceSessionController]
/// intentionally has no notion of "which screen is showing" of its own, since
/// the whole point of the global floating control (`global_voice_button.dart`)
/// is that a call keeps running while the user is elsewhere. This just lets
/// that control hide itself rather than floating a redundant duplicate of the
/// screen's own mic button on top of the screen itself.
final voiceScreenVisibleProvider = StateProvider<bool>((ref) => false);
