/// Memory Router — assembles contextual memory for each message,
/// pulling project briefs and recent tickets from the project repository.
library;

import '../../data/repositories/project_memory_repository.dart';

// ── Memory context model ──

class MemoryContext {
  final String? projectBrief;
  final List<String> relevantItems;
  final List<String> cacheableSections;
  final int estimatedTokens;

  const MemoryContext({
    this.projectBrief,
    this.relevantItems = const [],
    this.cacheableSections = const [],
    this.estimatedTokens = 0,
  });

  /// Empty context when no project is active.
  static const MemoryContext _empty = MemoryContext();
  factory MemoryContext.empty() => _empty;

  bool get isEmpty => projectBrief == null && relevantItems.isEmpty;
}

// ── Router ──

class MemoryRouter {
  final ProjectMemoryRepository _repository;

  MemoryRouter({required ProjectMemoryRepository repository})
      : _repository = repository;

  /// Build context for a user message within an optional active project.
  ///
  /// [userMessage] is the raw user input (currently unused but reserved for
  /// relevance filtering in Phase 2).
  /// [activeProjectId] identifies the project whose brief and tickets to load.
  /// [forceFullContext] increases the number of recent tickets returned.
  Future<MemoryContext> getContextForMessage(
    String userMessage, {
    String? activeProjectId,
    bool forceFullContext = false,
  }) async {
    if (activeProjectId == null) return MemoryContext.empty();

    final brief = await _repository.loadProjectBrief(activeProjectId);

    final ticketLimit = forceFullContext ? 8 : 3;
    final tickets =
        await _repository.getRecentTickets(activeProjectId, limit: ticketLimit);
    final ticketItems = tickets.map((t) => t.content).toList();

    // Sections that are stable across turns and can be prompt-cached.
    final cacheable = <String>[];
    if (brief != null) cacheable.add(brief);

    // Rough token estimate: ~4 characters per token.
    final totalChars =
        (brief?.length ?? 0) + ticketItems.fold<int>(0, (s, t) => s + t.length);
    final estimatedTokens = totalChars ~/ 4;

    return MemoryContext(
      projectBrief: brief,
      relevantItems: ticketItems,
      cacheableSections: cacheable,
      estimatedTokens: estimatedTokens,
    );
  }
}
