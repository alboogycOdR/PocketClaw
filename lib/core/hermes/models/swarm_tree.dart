/// Groups Hermes sessions by parent → child relationship so the UI
/// can render the orchestrator + worker tree without re-traversing
/// the whole sessions table on every rebuild.
library;

import 'hermes_session.dart';

class OrchestratorNode {
  final HermesSession orchestrator;
  final List<HermesSession> workers;

  const OrchestratorNode({
    required this.orchestrator,
    required this.workers,
  });

  int get doneCount =>
      workers.where((w) => w.swarmStatus == SwarmStatus.complete).length;
  int get failedCount =>
      workers.where((w) => w.swarmStatus == SwarmStatus.failed).length;
  int get runningCount =>
      workers.where((w) => w.swarmStatus == SwarmStatus.running).length;
  int get totalCount => workers.length;
}

class SwarmTree {
  /// Top-level orchestrators (parentSessionId == null) plus their workers.
  final List<OrchestratorNode> orchestrators;

  /// Workers whose parent isn't in the current window (stale/missing).
  final List<HermesSession> orphans;

  const SwarmTree({
    required this.orchestrators,
    required this.orphans,
  });

  /// Flat list of every worker across every orchestrator.
  List<HermesSession> get workers =>
      orchestrators.expand((o) => o.workers).toList();

  static SwarmTree build(List<HermesSession> sessions) {
    final workers = sessions
        .where((s) => s.parentSessionId != null)
        .toList(growable: false);
    final roots = sessions
        .where((s) => s.parentSessionId == null)
        .toList(growable: false);

    final nodes = roots.map((root) {
      final children =
          workers.where((w) => w.parentSessionId == root.id).toList()
            ..sort((a, b) => (a.startedAt ?? DateTime(2020))
                .compareTo(b.startedAt ?? DateTime(2020)));
      return OrchestratorNode(orchestrator: root, workers: children);
    }).toList()
      ..sort((a, b) => (b.orchestrator.startedAt ?? DateTime(2020))
          .compareTo(a.orchestrator.startedAt ?? DateTime(2020)));

    final assigned =
        nodes.expand((n) => n.workers.map((w) => w.id)).toSet();
    final orphans =
        workers.where((w) => !assigned.contains(w.id)).toList();

    return SwarmTree(orchestrators: nodes, orphans: orphans);
  }
}
