import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../core/config/api_endpoints.dart';
import '../../domain/entities/voice/voice_message.dart';

/// Raw transport for Hume's EVI chat protocol — connect, send
/// `session_settings`/`audio_input`, and surface parsed [HumeInboundMessage]s.
/// Deliberately knows nothing about microphone capture, audio playback, or UI
/// state; `voice_providers.dart` owns wiring this to the recorder/player and
/// deciding what [VoiceCallState] each message implies. Keeping the protocol
/// isolated here is what makes future Hume tool-calling (`tool_call`
/// messages — see [HumeUnknownMessage]) a change to this file and the
/// sealed-class switch, not a rewrite of the screen.
class HumeVoiceClient {
  /// Must match the recorder's actual output format — see
  /// `voice_providers.dart`'s `AudioRecorder`/`FlutterSoundRecorder` config.
  /// Declared once here so the two can never silently drift apart.
  static const int sampleRate = 16000;

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;
  final _messages = StreamController<HumeInboundMessage>.broadcast();

  /// Parsed inbound messages. Closes when the socket closes — a listener's
  /// `onDone` fires exactly when the Hume connection actually ends, whether
  /// that was [disconnect] or the server hanging up.
  Stream<HumeInboundMessage> get messages => _messages.stream;

  bool get isConnected => _channel != null;

  /// Opens the EVI socket and sends the audio `session_settings` handshake.
  /// Per Hume's protocol this must happen before any `audio_input` — callers
  /// must await this before starting microphone capture.
  ///
  /// Throws a plain [Exception] with a fixed message on failure rather than
  /// rethrowing whatever `WebSocketChannel` produced — that exception's
  /// `toString()` can embed the full connection URI, and the URI carries
  /// [accessToken] as a query parameter. Letting it reach a caller that logs
  /// or displays it would leak the token.
  Future<void> connect({
    required String accessToken,
    required String configId,
  }) async {
    final uri = ApiEndpoints.humeEviSocket(
      accessToken: accessToken,
      configId: configId,
    );

    final WebSocketChannel channel;
    try {
      channel = WebSocketChannel.connect(uri);
      await channel.ready;
    } catch (error) {
      debugPrint('Hume connection failed: ${error.runtimeType}');
      throw Exception('Could not connect to the voice service.');
    }
    _channel = channel;

    _subscription = channel.stream.listen(
      _handleRaw,
      onError: (Object error, StackTrace stack) {
        debugPrint('Hume connection error: $error');
        _messages.addError(error, stack);
      },
      onDone: () {
        debugPrint('Hume connection closed');
        _channel = null;
        _messages.close();
      },
    );

    _send({
      'type': 'session_settings',
      'audio': {
        'encoding': 'linear16',
        'sample_rate': sampleRate,
        'channels': 1,
      },
    });
    debugPrint('Hume connection established');
  }

  /// Streams one microphone chunk to Hume as `audio_input`. No-ops once
  /// disconnected rather than throwing — the recorder and the socket close
  /// in a specific order (see `voice_providers.dart`), and a chunk arriving
  /// in the gap between them is expected, not a bug to surface.
  void sendAudioChunk(Uint8List pcm16) {
    _send({'type': 'audio_input', 'data': base64Encode(pcm16)});
  }

  /// Acknowledges a whitelisted tool call's result — see
  /// `agentrix_tool_registry.dart`. [content] must be a UTF-8 string; Hume
  /// speaks it back into the conversation as the tool's result.
  void sendToolResponse({required String toolCallId, required String content}) {
    _send({
      'type': 'tool_response',
      'tool_call_id': toolCallId,
      'content': content,
    });
  }

  /// Reports a tool call this app could not or would not complete — a name
  /// outside the whitelist, or a whitelisted one that failed to run.
  /// [content] is optional text Hume speaks in place of the tool result
  /// instead of treating the failure as fatal to the turn — the exact field
  /// Hume's `ToolErrorMessage` documents; there is no separate
  /// "fallback_content" field in the real protocol.
  void sendToolError({
    required String toolCallId,
    required String error,
    String? content,
  }) {
    _send({
      'type': 'tool_error',
      'tool_call_id': toolCallId,
      'error': error,
      'content': ?content,
    });
  }

  void _send(Map<String, Object?> payload) {
    _channel?.sink.add(jsonEncode(payload));
  }

  void _handleRaw(dynamic raw) {
    if (raw is! String) return;
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final message = HumeInboundMessage.fromJson(json);
      debugPrint(_readableMessageLog(message));
      // The type alone doesn't say *why* — this is the one message type
      // where the content is the diagnosis, not health/personal data, so
      // it's the one exception to logging only the type.
      if (message is HumeError) {
        debugPrint(
          'Hume error: code=${message.code} slug=${message.slug} '
          'message=${message.message}',
        );
      }
      _messages.add(message);
    } catch (error) {
      debugPrint('Could not parse Hume message: $error');
    }
  }

  /// Produces useful development logs without printing base64 audio or user
  /// transcript content, both of which make Logcat noisy and may be private.
  String _readableMessageLog(HumeInboundMessage message) {
    return switch (message) {
      HumeChatMetadata(:final chatId, :final chatGroupId) =>
        'Hume | Session started '
        '(chat: ${chatId ?? 'unknown'}, group: ${chatGroupId ?? 'none'})',
      HumeUserMessage(:final interim) =>
        'Hume | User speech ${interim ? '(interim transcript)' : '(final transcript)'} received',
      HumeAssistantMessage(:final content) =>
        'Hume | Assistant: ${content.isEmpty ? '(empty response)' : content}',
      HumeAudioOutput(:final index, :final data) =>
        'Hume | Assistant audio chunk #$index received '
        '(${data.length} base64 characters)',
      HumeAssistantEnd() => 'Hume | Assistant response complete',
      HumeUserInterruption() => 'Hume | User interrupted the assistant',
      HumeToolCall(:final name, :final responseRequired) =>
        'Hume | Tool call: $name '
        '(response ${responseRequired ? 'required' : 'not required'})',
      HumeError() => 'Hume | Error received',
      HumeUnknownMessage(:final type) when type == 'assistant_prosody' =>
        'Hume | Assistant voice/prosody metadata received',
      HumeUnknownMessage(:final type) =>
        'Hume | Unhandled message type: ${type.isEmpty ? 'unknown' : type}',
    };
  }

  /// Closes the socket. Safe to call more than once.
  Future<void> disconnect() async {
    await _subscription?.cancel();
    _subscription = null;
    await _channel?.sink.close();
    _channel = null;
    if (!_messages.isClosed) await _messages.close();
    debugPrint('Voice session ended');
  }
}
