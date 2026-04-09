/// Local Agent - on-device agent loop
library;

import 'dart:async';

import '../../data/models/chat_message.dart';
import '../memory/local_memory.dart';
import '../skills/skill_registry.dart';
import '../session/session_manager.dart';
import 'llm_engine.dart';
import 'prompt_builder.dart';
import 'tool_definitions.dart';
import 'tool_executor.dart';

class AgentResponse {
  final String text;
  final bool isDone;
  final FunctionCallData? functionCall;

  const AgentResponse({
    required this.text,
    this.isDone = false,
    this.functionCall,
  });

  factory AgentResponse.text(String text, {bool isDone = false}) =>
      AgentResponse(text: text, isDone: isDone);

  factory AgentResponse.toolCall(FunctionCallData call) =>
      AgentResponse(text: '', functionCall: call);
}

class LocalAgent {
  final LlmEngine _llm;
  final ToolExecutor _tools;
  final LocalMemory _memory;
  final SkillRegistry _skills;
  final SessionManager _sessionManager;

  LocalAgent({
    required LlmEngine llm,
    required ToolExecutor tools,
    required LocalMemory memory,
    required SkillRegistry skills,
    required SessionManager sessionManager,
  })  : _llm = llm,
        _tools = tools,
        _memory = memory,
        _skills = skills,
        _sessionManager = sessionManager;

  Stream<AgentResponse> process(String message, {String? imageUrl}) async* {
    // 1. Load relevant skill instructions
    final skill = _skills.matchSkill(message);
    final skillInstructions = skill?.cachedBody ?? '';

    // 2. Retrieve relevant memory context
    final memoryContext = await _memory.search(message, 3);

    // 3. Build prompt
    final prompt = PromptBuilder.build(
      systemPrompt: PromptBuilder.defaultSystemPrompt,
      skillInstructions: skillInstructions,
      memoryContext: memoryContext,
      tools: localToolDefinitions,
      userMessage: message,
      conversationHistory:
          await _sessionManager.recentHistory(10),
    );

    // 4. Stream LLM response
    await for (final chunk in _llm.generateStream(prompt)) {
      if (chunk.isFunctionCall) {
        // Notify UI about tool execution
        yield AgentResponse.toolCall(chunk.functionCall!);

        // Execute the tool
        final result = await _tools.execute(chunk.functionCall!);

        // Feed result back to LLM
        await for (final resultChunk
            in _llm.continueWithResult(result.output)) {
          if (resultChunk.isText) {
            yield AgentResponse.text(resultChunk.text!);
          }
        }
      } else if (chunk.isText) {
        yield AgentResponse.text(chunk.text!);
      }
    }

    // 5. Signal completion
    yield AgentResponse.text('', isDone: true);

    // 6. Log to session
    _sessionManager.addMessage(ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      role: MessageRole.user,
      content: message,
      source: MessageSource.local,
      timestamp: DateTime.now(),
    ));
  }

  bool get isModelLoaded => _llm.isLoaded;
  String? get modelName => _llm.config?.displayName;
}
