/// Persistent GROW-session log — appends each completed session to a
/// JSON file in the app's documents directory. Keeps the last 50.
/// Per SPEC-LifeArchitect-v1.0 §8.
library;

import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'grow_state_machine.dart';

class GrowSessionHistory {
  static const _fileName = 'grow_session_history.json';

  Future<void> save(GrowSession session) async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/$_fileName');

    List<dynamic> existing = [];
    if (file.existsSync()) {
      try {
        existing = jsonDecode(await file.readAsString()) as List;
      } catch (_) {
        // Corrupt file — start fresh rather than block the save.
      }
    }

    existing.add({
      'startedAt': session.startedAt.toIso8601String(),
      'completedAt': DateTime.now().toIso8601String(),
      'goal': session.sessionGoal,
      'commitments': session.commitments,
      'phaseCount': session.phaseHistory.length,
    });

    if (existing.length > 50) {
      existing = existing.sublist(existing.length - 50);
    }

    await file.writeAsString(jsonEncode(existing));
  }

  Future<List<Map<String, dynamic>>> load() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/$_fileName');
    if (!file.existsSync()) return const [];
    try {
      final list = jsonDecode(await file.readAsString()) as List;
      return list.cast<Map<String, dynamic>>();
    } catch (_) {
      return const [];
    }
  }
}
