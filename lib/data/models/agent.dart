/// OpenClaw Agent model
library;

enum AgentStatus { active, idle, error, paused }

class Agent {
  final String id;
  final String name;
  final String model;
  final AgentStatus status;
  final String? currentSession;
  final int tokensToday;
  final String? emoji;
  final String? color;

  const Agent({
    required this.id,
    required this.name,
    required this.model,
    required this.status,
    this.currentSession,
    this.tokensToday = 0,
    this.emoji,
    this.color,
  });

  factory Agent.fromJson(Map<String, dynamic> json) => Agent(
        id: json['id'] as String,
        name: json['name'] as String,
        model: json['model'] as String? ?? 'unknown',
        status: AgentStatus.values.firstWhere(
          (s) => s.name == json['status'],
          orElse: () => AgentStatus.idle,
        ),
        currentSession: json['currentSession'] as String?,
        tokensToday: json['tokensToday'] as int? ?? 0,
        emoji: json['emoji'] as String?,
        color: json['color'] as String?,
      );

  /// Builds an Agent from the gateway's `agents.list` response shape:
  /// `{id, workspace, model?:{primary,...}, name?, identity?:{name?,theme?,emoji?,...}}`.
  /// The roster itself has no running-state — status stays idle until we
  /// enrich from `sessions.usage`. Same for tokensToday.
  factory Agent.fromSummary(Map<String, dynamic> json) {
    final identity = json['identity'] as Map<String, dynamic>?;
    final modelBlock = json['model'] as Map<String, dynamic>?;
    return Agent(
      id: json['id'] as String? ?? '',
      name: (identity?['name'] as String?) ??
          (json['name'] as String?) ??
          (json['id'] as String? ?? 'unnamed'),
      model: (modelBlock?['primary'] as String?) ?? 'unknown',
      status: AgentStatus.idle,
      emoji: identity?['emoji'] as String?,
      color: identity?['theme'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'model': model,
        'status': status.name,
        'currentSession': currentSession,
        'tokensToday': tokensToday,
        'emoji': emoji,
        'color': color,
      };

  Agent copyWith({
    AgentStatus? status,
    String? currentSession,
    int? tokensToday,
  }) =>
      Agent(
        id: id,
        name: name,
        model: model,
        status: status ?? this.status,
        currentSession: currentSession ?? this.currentSession,
        tokensToday: tokensToday ?? this.tokensToday,
        emoji: emoji,
        color: color,
      );
}
