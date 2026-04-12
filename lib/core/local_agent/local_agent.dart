/// Local Agent - on-device agent loop
library;

import 'dart:async';

import '../../data/models/chat_message.dart';
import '../memory/local_memory.dart';
import '../skills/skill_registry.dart';
import '../session/session_manager.dart';
import 'llm_engine.dart';
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
    // 1. Load relevant skill instructions (kept small — just the body)
    final skill = _skills.matchSkill(message);
    final skillInstructions = skill?.cachedBody ?? '';

    // 2. Retrieve relevant memory context
    final memoryContext = await _memory.search(message, 3);

    // 3. Build a COMPACT prompt. Gemma's chat API wraps messages in its
    //    own turn template (<start_of_turn>user ... <start_of_turn>model)
    //    so we must NOT add our own <system>/<user> XML tags — that
    //    creates a garbled user turn and tiny models (Gemma 3 270M) then
    //    emit EOS immediately, returning an empty response.
    //
    //    Strategy: prepend a minimal context block as plain prose, then
    //    the user question. The model will see it as one user turn.
    final ctxBuffer = StringBuffer();
    if (skillInstructions.isNotEmpty) {
      ctxBuffer.writeln('[Skill context]');
      ctxBuffer.writeln(skillInstructions.substring(
          0, skillInstructions.length.clamp(0, 600)));
      ctxBuffer.writeln();
    }
    if (memoryContext.isNotEmpty) {
      ctxBuffer.writeln('[Relevant notes]');
      for (final note in memoryContext) {
        final snippet = note.content.substring(
            0, note.content.length.clamp(0, 150));
        ctxBuffer.writeln('- ${note.title}: $snippet');
      }
      ctxBuffer.writeln();
    }
    final prompt = ctxBuffer.isEmpty
        ? message
        : '${ctxBuffer.toString()}Question: $message';

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
