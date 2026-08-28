import 'dart:convert';

/// Hume EVI's WebSocket message vocabulary — the subset this app currently
/// handles. Ported from the EVI AsyncAPI spec (`dev.hume.ai/asyncapi.json`)
/// and the tool-use guide (`dev.hume.ai/docs/speech-to-speech-evi/features/
/// tool-use`), not invented: field names and the `type` discriminator match
/// the wire protocol exactly, so a payload logged from a real session can be
/// pasted straight into [HumeInboundMessage.fromJson] to debug it.
sealed class HumeInboundMessage {
  const HumeInboundMessage();

  /// Unrecognised `type` values fall through to [HumeUnknownMessage] rather
  /// than throwing, so a protocol addition on Hume's side degrades to
  /// "ignored" instead of killing the session.
  factory HumeInboundMessage.fromJson(Map<String, dynamic> json) {
    final type = json['type'] as String? ?? '';
    return switch (type) {
      'chat_metadata' => HumeChatMetadata(
        chatId: json['chat_id'] as String?,
        chatGroupId: json['chat_group_id'] as String?,
      ),
      'user_message' => HumeUserMessage(
        content: _messageContent(json),
        interim: json['interim'] as bool? ?? false,
      ),
      'assistant_message' => HumeAssistantMessage(
        content: _messageContent(json),
      ),
      'audio_output' => HumeAudioOutput(
        data: json['data'] as String? ?? '',
        index: json['index'] as int? ?? 0,
      ),
      'assistant_end' => const HumeAssistantEnd(),
      'user_interruption' => const HumeUserInterruption(),
      'tool_call' => HumeToolCall(
        toolCallId: json['tool_call_id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        parameters: _toolParameters(json['parameters']),
        responseRequired: json['response_required'] as bool? ?? true,
      ),
      'error' => HumeError(
        code: json['code'] as String? ?? 'unknown',
        message: json['message'] as String? ?? 'Unknown Hume error',
        slug: json['slug'] as String?,
      ),
      _ => HumeUnknownMessage(type: type),
    };
  }

  static String _messageContent(Map<String, dynamic> json) {
    final message = json['message'];
    if (message is Map) return message['content'] as String? ?? '';
    return '';
  }

  /// EVI sends `parameters` as a JSON-*encoded string*, not an object — this
  /// decodes it once here so every caller downstream works with a plain map.
  /// Malformed or absent parameters degrade to `{}` rather than throwing:
  /// the 3 whitelisted tools in Phase 1 take none anyway, and a tool that
  /// does need one checks for it explicitly rather than relying on this to
  /// have failed loudly.
  static Map<String, dynamic> _toolParameters(Object? raw) {
    if (raw is! String || raw.isEmpty) return const {};
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map<String, dynamic> ? decoded : const {};
    } catch (_) {
      return const {};
    }
  }
}

/// First message on a new session — carries the chat/chat-group ids a future
/// "store voice session metadata" feature would key on (see the database note
/// in the integration plan). Not persisted yet.
class HumeChatMetadata extends HumeInboundMessage {
  const HumeChatMetadata({this.chatId, this.chatGroupId});

  final String? chatId;
  final String? chatGroupId;
}

/// A transcribed fragment of what the user said. [interim] fragments are
/// still being refined by Hume and are replaced by the next message with the
/// same content prefix — the transcript UI only keeps the latest one showing.
class HumeUserMessage extends HumeInboundMessage {
  const HumeUserMessage({required this.content, required this.interim});

  final String content;
  final bool interim;
}

/// The assistant's spoken line, as text — arrives alongside the
/// [HumeAudioOutput] chunks that speak it, not instead of them.
class HumeAssistantMessage extends HumeInboundMessage {
  const HumeAssistantMessage({required this.content});

  final String content;
}

/// One chunk of the assistant's speech: base64-encoded WAV. [index] orders
/// chunks within a single spoken turn — Hume does not guarantee WebSocket
/// frames arrive in order under retry, so playback sequences on this rather
/// than arrival order.
class HumeAudioOutput extends HumeInboundMessage {
  const HumeAudioOutput({required this.data, required this.index});

  final String data;
  final int index;
}

/// The assistant finished speaking its current turn — the cue to drop back
/// from SPEAKING to LISTENING once the queued audio finishes playing.
class HumeAssistantEnd extends HumeInboundMessage {
  const HumeAssistantEnd();
}

/// The user started talking while the assistant was still speaking. Queued
/// and in-flight assistant audio must be dropped immediately — playing a
/// stale reply over the user's own voice is the interruption bug this
/// message exists to prevent.
class HumeUserInterruption extends HumeInboundMessage {
  const HumeUserInterruption();
}

class HumeError extends HumeInboundMessage {
  const HumeError({required this.code, required this.message, this.slug});

  final String code;
  final String message;
  final String? slug;
}

/// EVI wants to invoke one of the app's whitelisted tools — see
/// `agentrix_tool_registry.dart`. [toolCallId] must be echoed back on the
/// `tool_response`/`tool_error` that follows, so Hume can match the result to
/// this specific invocation.
class HumeToolCall extends HumeInboundMessage {
  const HumeToolCall({
    required this.toolCallId,
    required this.name,
    required this.parameters,
    required this.responseRequired,
  });

  final String toolCallId;
  final String name;
  final Map<String, dynamic> parameters;
  final bool responseRequired;
}

/// A message type this build doesn't act on yet (`tool_response`/`tool_error`
/// echoes, etc.). Kept distinct from silently dropping the frame so a future
/// need has a single switch arm to extend.
class HumeUnknownMessage extends HumeInboundMessage {
  const HumeUnknownMessage({required this.type});

  final String type;
}

/// One line of the on-screen transcript — collapsed from whichever
/// [HumeUserMessage]/[HumeAssistantMessage] produced it.
class VoiceTranscriptEntry {
  const VoiceTranscriptEntry({required this.fromUser, required this.text});

  final bool fromUser;
  final String text;
}

/// What the voice screen shows. Mirrors the six states the UI was asked for
/// — IDLE/CONNECTING/LISTENING/THINKING/SPEAKING/ERROR — one field short of
/// [HumeAssistantMessage] arriving marking the THINKING→SPEAKING switch,
/// which the controller derives rather than Hume stating outright.
enum VoiceCallState { idle, connecting, listening, thinking, speaking, error }
