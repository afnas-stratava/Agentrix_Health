import 'package:google_generative_ai/google_generative_ai.dart';

import '../../domain/entities/chat/chat_message.dart';

/// Thin wrapper over the Gemini SDK for the health assistant chat.
///
/// A fresh [GenerativeModel] is built per call rather than held as a field —
/// the system prompt carries a snapshot of the user's readiness, food log and
/// labs, which can change between one message and the next, and the SDK has
/// no way to update a model's system instruction after construction. Building
/// the model is a local, no-network operation, so this costs nothing extra.
class GeminiChatService {
  // `gemini-2.0-flash` sits on this key's free tier at a hard 0 quota
  // (RESOURCE_EXHAUSTED, limit: 0) — a project-level allowance, not a bug in
  // this call. `gemini-flash-latest` is the alias Google points at whichever
  // current flash model that project *does* have quota for, and is what
  // actually answers today.
  const GeminiChatService({
    required this.apiKey,
    this.model = 'gemini-flash-latest',
  });

  final String apiKey;
  final String model;

  /// False when no key is configured — [ChatNotifier] falls back to the
  /// local rule-based engine rather than attempting a call that can only fail.
  bool get isConfigured => apiKey.trim().isNotEmpty;

  Future<String> reply({
    required String systemPrompt,
    required List<ChatMessage> history,
    required String message,
  }) async {
    final generativeModel = GenerativeModel(
      model: model,
      apiKey: apiKey,
      systemInstruction: Content.system(systemPrompt),
    );

    final contents = [
      for (final entry in history)
        Content(entry.role == ChatRole.user ? 'user' : 'model', [
          TextPart(entry.text),
        ]),
      Content.text(message),
    ];

    final response = await generativeModel.generateContent(contents);
    final text = response.text?.trim();
    if (text == null || text.isEmpty) {
      // A response with no text — usually the prompt or the reply tripped a
      // safety filter. Throwing lets the caller fall back rather than show
      // the user a blank bubble.
      throw StateError('Gemini returned no text in its response');
    }
    return text;
  }
}
