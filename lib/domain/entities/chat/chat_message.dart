/// A single turn in the health assistant conversation.
enum ChatRole { user, assistant }

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.role,
    required this.text,
    required this.sentAt,
  });

  final String id;
  final ChatRole role;
  final String text;
  final DateTime sentAt;
}
