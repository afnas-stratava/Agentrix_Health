import 'package:agentrix_health/core/config/secrets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/chat/gemini_chat_service.dart';
import '../../domain/entities/chat/chat_message.dart';
import '../../features/chat/health_assistant.dart';
import 'health_providers.dart';
import 'labs_providers.dart';
import 'nutrition_providers.dart';
import 'user_profile_provider.dart';

/// Held behind a provider so tests (and a future settings screen) can
/// override the key without touching [ChatNotifier].
final geminiChatServiceProvider = Provider<GeminiChatService>(
  (ref) => const GeminiChatService(apiKey: geminiApiKey),
);

class ChatState {
  const ChatState({required this.messages, this.isTyping = false});

  final List<ChatMessage> messages;

  /// True while the assistant's reply is "being written" — a brief, honest
  /// beat rather than an instant reply, since the reply reads as looked-up
  /// rather than typed if it lands the same frame as the question.
  final bool isTyping;

  ChatState copyWith({List<ChatMessage>? messages, bool? isTyping}) =>
      ChatState(
        messages: messages ?? this.messages,
        isTyping: isTyping ?? this.isTyping,
      );
}

/// Backs the health assistant chat screen reached from the tab bar's centre
/// action. Kept in memory only — like a real conversation, it starts fresh
/// each time the app opens rather than pretending to be a saved thread.
class ChatNotifier extends Notifier<ChatState> {
  @override
  ChatState build() {
    return ChatState(messages: [_welcome()]);
  }

  ChatMessage _welcome() {
    final name = ref.read(userProfileProvider).name.trim();
    final greeting = name.isEmpty ? 'Hi!' : 'Hi, ${name.split(' ').first}!';
    return ChatMessage(
      id: 'welcome',
      role: ChatRole.assistant,
      text: '$greeting I can talk through your readiness, food log, '
          "hydration or labs — what's on your mind?",
      sentAt: DateTime.now(),
    );
  }

  Future<void> send(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    // Captured before the user's own message joins [state.messages] — this
    // is the turn history Gemini gets, with the new message passed separately.
    final priorMessages = List<ChatMessage>.of(state.messages);

    final now = DateTime.now();
    final userMessage = ChatMessage(
      id: 'msg-${now.microsecondsSinceEpoch}',
      role: ChatRole.user,
      text: trimmed,
      sentAt: now,
    );
    state = state.copyWith(
      messages: [...state.messages, userMessage],
      isTyping: true,
    );

    final context = HealthAssistantContext(
      profile: ref.read(userProfileProvider),
      readiness: ref.read(readinessProvider),
      consumedToday: ref.read(consumedTodayProvider),
      targets: ref.read(nutritionTargetsProvider),
      hydrationCupsToday: ref.read(hydrationTodayProvider),
      latestLabReport: ref.read(latestLabReportProvider),
    );
    final reply = await _reply(trimmed, priorMessages, context);

    final replyMessage = ChatMessage(
      id: 'msg-${DateTime.now().microsecondsSinceEpoch}',
      role: ChatRole.assistant,
      text: reply,
      sentAt: DateTime.now(),
    );
    state = state.copyWith(
      messages: [...state.messages, replyMessage],
      isTyping: false,
    );
  }

  /// Gemini is the primary voice; the local rule-based engine is what keeps
  /// the assistant answering when there is no key configured, the network is
  /// down, or the call errors or comes back empty — the same "never let one
  /// dependency freeze the screen" rule the health telemetry providers follow.
  Future<String> _reply(
    String message,
    List<ChatMessage> history,
    HealthAssistantContext context,
  ) async {
    final gemini = ref.read(geminiChatServiceProvider);
    if (gemini.isConfigured) {
      try {
        return await gemini
            .reply(
              systemPrompt: buildHealthAssistantSystemPrompt(context),
              history: history,
              message: message,
            )
            .timeout(const Duration(seconds: 15));
      } catch (_) {
        // Fall through to the local engine below.
      }
    }
    return answerHealthQuestion(message, context);
  }
}

final chatProvider = NotifierProvider<ChatNotifier, ChatState>(
  ChatNotifier.new,
);
