/// Kanban board with horizontal tabs for task statuses
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../app/theme.dart';
import '../../data/models/task.dart';
import '../../data/providers/core_providers.dart';
import '../../shared/extensions.dart';
import '../../shared/widgets/empty_state.dart';
import 'mission_control_providers.dart';

class TasksScreen extends ConsumerStatefulWidget {
  const TasksScreen({super.key});

  @override
  ConsumerState<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends ConsumerState<TasksScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  static const _tabs = [
    TaskStatus.inbox,
    TaskStatus.assigned,
    TaskStatus.inProgress,
    TaskStatus.review,
    TaskStatus.done,
  ];

  static const _tabLabels = ['Inbox', 'Assigned', 'Doing', 'Review', 'Done'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _changeTaskStatus(String taskId, TaskStatus newStatus) async {
    final client = ref.read(gatewayRestClientProvider);
    if (client == null) return;
    try {
      await client.updateTaskStatus(taskId, newStatus.name);
      ref.invalidate(mcTasksProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update task: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final restClient = ref.watch(gatewayRestClientProvider);
    final tasksAsync = ref.watch(mcTasksProvider);

    if (restClient == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Tasks')),
        body: const EmptyState(
          icon: Icons.cloud_off,
          message: 'Not connected to Gateway',
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tasks'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, size: 20),
            onPressed: () => ref.invalidate(mcTasksProvider),
          ),
        ],
        bottom: tasksAsync.when(
          data: (tasks) => TabBar(
            controller: _tabController,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: _tabLabels.asMap().entries.map((entry) {
              final count =
                  tasks.where((t) => t.status == _tabs[entry.key]).length;
              return Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(entry.value),
                    if (count > 0) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: PocketClawTheme.lobsterRed.withAlpha(40),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '$count',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              );
            }).toList(),
          ),
          loading: () => TabBar(
            controller: _tabController,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: _tabLabels.map((l) => Tab(text: l)).toList(),
          ),
          error: (_, __) => TabBar(
            controller: _tabController,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: _tabLabels.map((l) => Tab(text: l)).toList(),
          ),
        ),
      ),
      body: tasksAsync.when(
        data: (tasks) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(mcTasksProvider),
          child: TabBarView(
            controller: _tabController,
            children: _tabs.map((status) {
              final filtered = tasks.where((t) => t.status == status).toList();
              if (filtered.isEmpty) {
                return const EmptyState(
                  icon: Icons.inbox_outlined,
                  message: 'No tasks here',
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: filtered.length,
                itemBuilder: (context, index) {
                  return _TaskCard(
                    task: filtered[index],
                    onStatusChange: (newStatus) {
                      _changeTaskStatus(filtered[index].id, newStatus);
                    },
                  );
                },
              );
            }).toList(),
          ),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => EmptyState(
          icon: Icons.error_outline,
          message: 'Failed to load tasks\n$e',
          actionLabel: 'Retry',
          onAction: () => ref.invalidate(mcTasksProvider),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _TaskCard extends StatefulWidget {
  final Task task;
  final ValueChanged<TaskStatus> onStatusChange;

  const _TaskCard({required this.task, required this.onStatusChange});

  @override
  State<_TaskCard> createState() => _TaskCardState();
}

class _TaskCardState extends State<_TaskCard> {
  bool _expanded = false;

  Color get _priorityColor => switch (widget.task.priority) {
        TaskPriority.urgent => const Color(0xFFE53935),
        TaskPriority.high => const Color(0xFFFF9800),
        TaskPriority.medium => const Color(0xFFFFEB3B),
        TaskPriority.low => const Color(0xFF7A7A90),
      };

  String get _priorityLabel => switch (widget.task.priority) {
        TaskPriority.urgent => 'URGENT',
        TaskPriority.high => 'HIGH',
        TaskPriority.medium => 'MED',
        TaskPriority.low => 'LOW',
      };

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => setState(() => _expanded = !_expanded),
      onLongPress: () => _showStatusMenu(context),
      child: Card(
        margin: const EdgeInsets.only(bottom: 10),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Priority indicator
                  Container(
                    width: 4,
                    height: 32,
                    decoration: BoxDecoration(
                      color: _priorityColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 12),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.task.title,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: _priorityColor.withAlpha(25),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                _priorityLabel,
                                style: GoogleFonts.jetBrainsMono(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  color: _priorityColor,
                                ),
                              ),
                            ),
                            if (widget.task.assignedAgent != null) ...[
                              const SizedBox(width: 8),
                              Icon(Icons.smart_toy,
                                  size: 12, color: Colors.white38),
                              const SizedBox(width: 4),
                              Text(
                                widget.task.assignedAgent!,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.white38,
                                ),
                              ),
                            ],
                            const Spacer(),
                            Text(
                              widget.task.createdAt.timeAgo,
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 10,
                                color: Colors.white30,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              // Progress bar
              if (widget.task.progress != null) ...[
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: widget.task.progress!,
                    minHeight: 3,
                    backgroundColor: const Color(0xFF2A2A40),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      PocketClawTheme.electricTeal,
                    ),
                  ),
                ),
              ],

              // Expanded details
              if (_expanded && widget.task.description != null) ...[
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 12),
                Text(
                  widget.task.description!,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.white60,
                    height: 1.5,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showStatusMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: PocketClawTheme.surfaceContainer,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 32,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Move Task',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              ...TaskStatus.values.map((status) {
                final label = switch (status) {
                  TaskStatus.inbox => 'Inbox',
                  TaskStatus.assigned => 'Assigned',
                  TaskStatus.inProgress => 'Doing',
                  TaskStatus.review => 'Review',
                  TaskStatus.done => 'Done',
                };
                return ListTile(
                  leading: Icon(
                    widget.task.status == status
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                    color: widget.task.status == status
                        ? PocketClawTheme.lobsterRed
                        : Colors.white38,
                    size: 20,
                  ),
                  title: Text(label),
                  onTap: () {
                    widget.onStatusChange(status);
                    Navigator.pop(context);
                  },
                );
              }),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }
}
