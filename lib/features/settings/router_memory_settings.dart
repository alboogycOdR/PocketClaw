/// Smart Router and Memory configuration (spec §6.7).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../data/providers/core_providers.dart';
import '../../data/repositories/project_memory_repository.dart';

final projectsListProvider = FutureProvider<List<Project>>((ref) async {
  final repo = ref.watch(projectMemoryRepositoryProvider);
  return repo.getProjects();
});

class RouterMemorySettings extends ConsumerStatefulWidget {
  const RouterMemorySettings({super.key});

  @override
  ConsumerState<RouterMemorySettings> createState() =>
      _RouterMemorySettingsState();
}

/// Default execution path tracker. `auto` means SmartRouter / chat-mode
/// auto-detect chooses; specific values pin behaviour to one endpoint.
final defaultExecutionPathProvider = StateProvider<String>((ref) {
  final prefs = ref.watch(sharedPrefsProvider);
  return prefs.getString('default_execution_path') ?? 'auto';
});

class _RouterMemorySettingsState extends ConsumerState<RouterMemorySettings> {
  late final TextEditingController _budgetController;

  @override
  void initState() {
    super.initState();
    final prefs = ref.read(sharedPrefsProvider);
    final t = prefs.getInt('token_budget_threshold') ?? 4000;
    _budgetController = TextEditingController(text: '$t');
  }

  @override
  void dispose() {
    _budgetController.dispose();
    super.dispose();
  }

  Future<void> _saveBudget() async {
    final v = int.tryParse(_budgetController.text.trim());
    if (v == null || v < 500) return;
    final prefs = ref.read(sharedPrefsProvider);
    await prefs.setInt('token_budget_threshold', v);
    ref.read(tokenBudgetThresholdProvider.notifier).state = v;
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Token budget threshold saved')),
      );
    }
  }

  Future<void> _setProject(String? id) async {
    final prefs = ref.read(sharedPrefsProvider);
    if (id == null) {
      await prefs.remove('active_project_id');
    } else {
      await prefs.setString('active_project_id', id);
    }
    ref.read(activeProjectIdProvider.notifier).state = id;
  }

  Future<void> _setDefaultPath(String? value) async {
    if (value == null) return;
    final prefs = ref.read(sharedPrefsProvider);
    await prefs.setString('default_execution_path', value);
    ref.read(defaultExecutionPathProvider.notifier).state = value;
  }

  @override
  Widget build(BuildContext context) {
    final projectsAsync = ref.watch(projectsListProvider);
    final activeId = ref.watch(activeProjectIdProvider);
    final threshold = ref.watch(tokenBudgetThresholdProvider);
    final defaultPath = ref.watch(defaultExecutionPathProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Smart Router & Memory')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Routing',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Colors.white60,
                ),
          ),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Default execution path',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                RadioListTile<String>(
                  title: const Text('Auto'),
                  subtitle: const Text(
                    'SmartRouter / chat-mode autodetect picks.',
                    style: TextStyle(fontSize: 12),
                  ),
                  value: 'auto',
                  groupValue: defaultPath,
                  onChanged: _setDefaultPath,
                ),
                RadioListTile<String>(
                  title: const Text('Local'),
                  subtitle: const Text(
                    'On-device LLM only.',
                    style: TextStyle(fontSize: 12),
                  ),
                  value: 'local',
                  groupValue: defaultPath,
                  onChanged: _setDefaultPath,
                ),
                RadioListTile<String>(
                  title: const Text('Server (OpenClaw)'),
                  subtitle: const Text(
                    'Full agent team via OpenClaw gateway.',
                    style: TextStyle(fontSize: 12),
                  ),
                  value: 'server',
                  groupValue: defaultPath,
                  onChanged: _setDefaultPath,
                ),
                RadioListTile<String>(
                  title: const Text('Hermes'),
                  subtitle: const Text(
                    'Nous Research agent on your VPS.',
                    style: TextStyle(fontSize: 12),
                  ),
                  value: 'hermes',
                  groupValue: defaultPath,
                  onChanged: _setDefaultPath,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: ListTile(
              title: const Text('Memory token budget'),
              subtitle: Text(
                'Above this estimate, routing prefers SERVER when online '
                '(currently $threshold tokens).',
                style: const TextStyle(fontSize: 12),
              ),
              trailing: SizedBox(
                width: 72,
                child: TextField(
                  controller: _budgetController,
                  keyboardType: TextInputType.number,
                  style: GoogleFonts.jetBrainsMono(fontSize: 13),
                  decoration: const InputDecoration(
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => _saveBudget(),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
              onPressed: _saveBudget,
              child: const Text('Save threshold'),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Active project',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Colors.white60,
                ),
          ),
          const SizedBox(height: 8),
          projectsAsync.when(
            data: (projects) {
              if (projects.isEmpty) {
                return const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'No projects in the database yet. Create one via the '
                      'developer flow or a future Projects screen.',
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
                );
              }
              return Card(
                child: Column(
                  children: [
                    RadioListTile<String?>(
                      title: const Text('None'),
                      value: null,
                      groupValue: activeId,
                      onChanged: _setProject,
                    ),
                    ...projects.map(
                      (p) => RadioListTile<String>(
                        title: Text(p.name),
                        subtitle: Text(
                          p.phase,
                          style: const TextStyle(fontSize: 11),
                        ),
                        value: p.id,
                        groupValue: activeId,
                        onChanged: _setProject,
                      ),
                    ),
                  ],
                ),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('Failed to load projects: $e'),
          ),
          const SizedBox(height: 16),
          Text(
            'Project Brief updates append activity and truncate when very long. '
            'LLM summarisation can be layered on later (spec §7.x).',
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withAlpha(128),
            ),
          ),
        ],
      ),
    );
  }
}
