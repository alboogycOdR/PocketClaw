/// Memory Service — manages project brief lifecycle including updates
/// and LLM-based consolidation when a model is available.
library;

import '../local_agent/llm_engine.dart';
import '../../data/repositories/project_memory_repository.dart';

class MemoryService {
  final ProjectMemoryRepository _repository;
  final LlmEngine _llm;

  /// Maximum brief length in characters before truncation is applied.
  static const int maxBriefLength = 8000;

  MemoryService({
    required ProjectMemoryRepository repository,
    required LlmEngine llm,
  })  : _repository = repository,
        _llm = llm;

  /// Update a project's brief by appending [newActivity] to the current brief.
  ///
  /// If the combined text exceeds [maxBriefLength], the oldest content is
  /// truncated from the front.
  Future<void> updateProjectBrief(
    String projectId,
    String newActivity,
  ) async {
    final currentBrief = await _repository.loadProjectBrief(projectId);

    final timestamp = DateTime.now().toIso8601String().substring(0, 16);
    final entry = '\n\n---\n**$timestamp** $newActivity';

    var updated = (currentBrief ?? '# Project Brief') + entry;

    // Simple truncation strategy: drop the oldest entries when too long.
    if (updated.length > maxBriefLength) {
      updated = _truncateBrief(updated);
    }

    await _repository.updateProjectBrief(projectId, updated);
  }

  /// Rewrites the project brief using the on-device model when loaded; otherwise
  /// falls back to [updateProjectBrief] with a truncated activity line.
  Future<void> updateProjectBriefAfterTurn(
    String projectId,
    String userTurnSummary,
  ) async {
    final trimmed = userTurnSummary.trim();
    if (trimmed.isEmpty) return;

    final current = await _repository.loadProjectBrief(projectId) ?? '# Project Brief';

    if (!_llm.isLoaded) {
      await updateProjectBrief(projectId, trimmed);
      return;
    }

    final prompt = '''
You are maintaining a project brief in British English. Output Markdown only.

## Current brief
$current

## New user activity to integrate (one turn)
$trimmed

Produce an updated brief that merges the new information. Keep headings where helpful.
Stay under 6000 characters. Preserve important decisions and dates.
''';

    final updated = await _llm.generateCompleteText(prompt);
    if (updated.isEmpty) {
      await updateProjectBrief(projectId, trimmed);
      return;
    }

    var text = updated;
    if (text.length > maxBriefLength) {
      text =
          '${text.substring(0, maxBriefLength - 50)}\n\n*(truncated)*';
    }
    await _repository.updateProjectBrief(projectId, text);
  }

  /// Truncate by keeping the header and the most recent content up to
  /// [maxBriefLength] characters.
  String _truncateBrief(String brief) {
    // Preserve the first line (header) and take the tail.
    final firstNewline = brief.indexOf('\n');
    if (firstNewline < 0) return brief;

    final header = brief.substring(0, firstNewline);
    final body = brief.substring(firstNewline);

    if (body.length <= maxBriefLength - header.length) {
      return brief;
    }

    final trimmed = body.substring(body.length - (maxBriefLength - header.length - 20));
    // Find the next section boundary to avoid cutting mid-entry.
    final nextBreak = trimmed.indexOf('\n---\n');
    final cleanStart = nextBreak >= 0 ? nextBreak : 0;

    return '$header\n\n*(earlier entries truncated)*${trimmed.substring(cleanStart)}';
  }
}
