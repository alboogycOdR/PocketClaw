/// Builds prompts for the local LLM
library;

import '../../data/models/chat_message.dart';
import '../../data/models/memory_note.dart';

class PromptBuilder {
  PromptBuilder._();

  static String build({
    required String systemPrompt,
    String? skillInstructions,
    List<MemoryNote>? memoryContext,
    List<Map<String, dynamic>>? tools,
    required String userMessage,
    List<ChatMessage>? conversationHistory,
  }) {
    final buffer = StringBuffer();

    // System prompt
    buffer.writeln('<system>');
    buffer.writeln(systemPrompt);

    // Skill instructions (if a skill was matched)
    if (skillInstructions != null && skillInstructions.isNotEmpty) {
      buffer.writeln();
      buffer.writeln('<skill>');
      buffer.writeln(skillInstructions);
      buffer.writeln('</skill>');
    }

    // Memory context
    if (memoryContext != null && memoryContext.isNotEmpty) {
      buffer.writeln();
      buffer.writeln('<memory>');
      for (final note in memoryContext) {
        buffer.writeln('- ${note.title}: ${note.content.substring(0, note.content.length.clamp(0, 200))}');
      }
      buffer.writeln('</memory>');
    }

    // Tool definitions
    if (tools != null && tools.isNotEmpty) {
      buffer.writeln();
      buffer.writeln('<tools>');
      for (final tool in tools) {
        buffer.writeln('- ${tool['name']}: ${tool['description']}');
      }
      buffer.writeln('</tools>');
    }

    buffer.writeln('</system>');

    // Conversation history
    if (conversationHistory != null) {
      for (final msg in conversationHistory) {
        final role = msg.role == MessageRole.user ? 'user' : 'assistant';
        buffer.writeln('<$role>${msg.content}</$role>');
      }
    }

    // Current user message
    buffer.writeln('<user>$userMessage</user>');

    return buffer.toString();
  }

  static String get defaultSystemPrompt => '''
You are Pocket Claw, a personal AI assistant running on the user's phone.
You are helpful, concise, and action-oriented.

CAPABILITIES:
- Create and search notes (local, private)
- Set reminders and alarms
- Query the device calendar
- Perform calculations
- Draft messages (user confirms before sending)
- Capture and process photos (OCR)
- Read files from local storage
- Read text aloud

RULES:
1. Be concise. This is a mobile screen - short responses.
2. When you need to take action, use function calling.
3. For messages/emails: ALWAYS draft first, never claim to send.
4. If a task is beyond your capabilities, say so clearly.
5. Protect user privacy - never suggest sending data externally.
''';
}
