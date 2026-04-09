/// Task model for Mission Control kanban
library;

enum TaskStatus { inbox, assigned, inProgress, review, done }

enum TaskPriority { low, medium, high, urgent }

class Task {
  final String id;
  final String title;
  final String? description;
  final TaskStatus status;
  final TaskPriority priority;
  final String? assignedAgent;
  final DateTime createdAt;
  final DateTime? completedAt;
  final double? progress;

  const Task({
    required this.id,
    required this.title,
    this.description,
    required this.status,
    this.priority = TaskPriority.medium,
    this.assignedAgent,
    required this.createdAt,
    this.completedAt,
    this.progress,
  });

  factory Task.fromJson(Map<String, dynamic> json) => Task(
        id: json['id'] as String,
        title: json['title'] as String,
        description: json['description'] as String?,
        status: TaskStatus.values.firstWhere(
          (s) => s.name == json['status'],
          orElse: () => TaskStatus.inbox,
        ),
        priority: TaskPriority.values.firstWhere(
          (p) => p.name == json['priority'],
          orElse: () => TaskPriority.medium,
        ),
        assignedAgent: json['assignedAgent'] as String?,
        createdAt: DateTime.parse(json['createdAt'] as String),
        completedAt: json['completedAt'] != null
            ? DateTime.parse(json['completedAt'] as String)
            : null,
        progress: (json['progress'] as num?)?.toDouble(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'status': status.name,
        'priority': priority.name,
        'assignedAgent': assignedAgent,
        'createdAt': createdAt.toIso8601String(),
        'completedAt': completedAt?.toIso8601String(),
        'progress': progress,
      };

  Task copyWith({
    TaskStatus? status,
    TaskPriority? priority,
    String? assignedAgent,
    DateTime? completedAt,
    double? progress,
  }) =>
      Task(
        id: id,
        title: title,
        description: description,
        status: status ?? this.status,
        priority: priority ?? this.priority,
        assignedAgent: assignedAgent ?? this.assignedAgent,
        createdAt: createdAt,
        completedAt: completedAt ?? this.completedAt,
        progress: progress ?? this.progress,
      );
}

class TaskCreate {
  final String title;
  final String? description;
  final TaskPriority priority;

  const TaskCreate({
    required this.title,
    this.description,
    this.priority = TaskPriority.medium,
  });

  Map<String, dynamic> toJson() => {
        'title': title,
        'description': description,
        'priority': priority.name,
      };
}
