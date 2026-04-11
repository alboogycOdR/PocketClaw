/// Paperclip organisation state — company data pushed via WebSocket
library;

class PaperclipState {
  final bool isConnected;
  final CompanyOverview? overview;
  final List<OrgMember> orgChart;
  final List<CompanyGoal> goals;
  final BudgetInfo? budget;
  final List<CompanyTicket> tickets;
  final List<GovernanceDraft> governanceDrafts;
  final SecurityDashboard? security;

  const PaperclipState({
    this.isConnected = false,
    this.overview,
    this.orgChart = const [],
    this.goals = const [],
    this.budget,
    this.tickets = const [],
    this.governanceDrafts = const [],
    this.security,
  });

  PaperclipState copyWith({
    bool? isConnected,
    CompanyOverview? overview,
    List<OrgMember>? orgChart,
    List<CompanyGoal>? goals,
    BudgetInfo? budget,
    List<CompanyTicket>? tickets,
    List<GovernanceDraft>? governanceDrafts,
    SecurityDashboard? security,
  }) =>
      PaperclipState(
        isConnected: isConnected ?? this.isConnected,
        overview: overview ?? this.overview,
        orgChart: orgChart ?? this.orgChart,
        goals: goals ?? this.goals,
        budget: budget ?? this.budget,
        tickets: tickets ?? this.tickets,
        governanceDrafts: governanceDrafts ?? this.governanceDrafts,
        security: security ?? this.security,
      );
}

class CompanyOverview {
  final String name;
  final String? description;
  final int employeeCount;
  final int activeProjects;
  final double healthScore;

  const CompanyOverview({
    required this.name,
    this.description,
    this.employeeCount = 0,
    this.activeProjects = 0,
    this.healthScore = 0,
  });

  factory CompanyOverview.fromJson(Map<String, dynamic> json) =>
      CompanyOverview(
        name: json['name'] as String? ?? 'Unknown',
        description: json['description'] as String?,
        employeeCount: json['employeeCount'] as int? ?? 0,
        activeProjects: json['activeProjects'] as int? ?? 0,
        healthScore: (json['healthScore'] as num?)?.toDouble() ?? 0,
      );
}

class OrgMember {
  final String id;
  final String name;
  final String role;
  final String? department;
  final String? reportsTo;
  final String? avatarUrl;
  final bool isAgent;

  const OrgMember({
    required this.id,
    required this.name,
    required this.role,
    this.department,
    this.reportsTo,
    this.avatarUrl,
    this.isAgent = false,
  });

  factory OrgMember.fromJson(Map<String, dynamic> json) => OrgMember(
        id: json['id'] as String,
        name: json['name'] as String,
        role: json['role'] as String? ?? 'Member',
        department: json['department'] as String?,
        reportsTo: json['reportsTo'] as String?,
        avatarUrl: json['avatarUrl'] as String?,
        isAgent: json['isAgent'] as bool? ?? false,
      );
}

class CompanyGoal {
  final String id;
  final String title;
  final String? description;
  final double progress;
  final String? owner;
  final DateTime? dueDate;

  const CompanyGoal({
    required this.id,
    required this.title,
    this.description,
    this.progress = 0,
    this.owner,
    this.dueDate,
  });

  factory CompanyGoal.fromJson(Map<String, dynamic> json) => CompanyGoal(
        id: json['id'] as String,
        title: json['title'] as String,
        description: json['description'] as String?,
        progress: (json['progress'] as num?)?.toDouble() ?? 0,
        owner: json['owner'] as String?,
        dueDate: json['dueDate'] != null
            ? DateTime.tryParse(json['dueDate'] as String)
            : null,
      );
}

class BudgetInfo {
  final double totalBudget;
  final double spent;
  final double remaining;
  final Map<String, double> categoryBreakdown;

  const BudgetInfo({
    this.totalBudget = 0,
    this.spent = 0,
    this.remaining = 0,
    this.categoryBreakdown = const {},
  });

  double get usagePercent =>
      totalBudget > 0 ? (spent / totalBudget * 100).clamp(0, 100) : 0;

  factory BudgetInfo.fromJson(Map<String, dynamic> json) => BudgetInfo(
        totalBudget: (json['totalBudget'] as num?)?.toDouble() ?? 0,
        spent: (json['spent'] as num?)?.toDouble() ?? 0,
        remaining: (json['remaining'] as num?)?.toDouble() ?? 0,
        categoryBreakdown:
            (json['categoryBreakdown'] as Map<String, dynamic>?)
                    ?.map((k, v) => MapEntry(k, (v as num).toDouble())) ??
                {},
      );
}

enum TicketStatus { todo, inProgress, done }

class CompanyTicket {
  final String id;
  final String title;
  final String? description;
  final TicketStatus status;
  final String? assignee;
  final DateTime createdAt;

  const CompanyTicket({
    required this.id,
    required this.title,
    this.description,
    this.status = TicketStatus.todo,
    this.assignee,
    required this.createdAt,
  });

  factory CompanyTicket.fromJson(Map<String, dynamic> json) => CompanyTicket(
        id: json['id'] as String,
        title: json['title'] as String,
        description: json['description'] as String?,
        status: TicketStatus.values.firstWhere(
          (s) => s.name == json['status'],
          orElse: () => TicketStatus.todo,
        ),
        assignee: json['assignee'] as String?,
        createdAt: json['createdAt'] != null
            ? DateTime.parse(json['createdAt'] as String)
            : DateTime.now(),
      );
}

class GovernanceDraft {
  final String id;
  final String title;
  final String body;
  final String status; // draft, review, approved, rejected
  final String? author;
  final DateTime createdAt;

  const GovernanceDraft({
    required this.id,
    required this.title,
    required this.body,
    this.status = 'draft',
    this.author,
    required this.createdAt,
  });

  factory GovernanceDraft.fromJson(Map<String, dynamic> json) =>
      GovernanceDraft(
        id: json['id'] as String,
        title: json['title'] as String,
        body: json['body'] as String? ?? '',
        status: json['status'] as String? ?? 'draft',
        author: json['author'] as String?,
        createdAt: json['createdAt'] != null
            ? DateTime.parse(json['createdAt'] as String)
            : DateTime.now(),
      );
}

class SecurityDashboard {
  final int openVulnerabilities;
  final int resolvedThisMonth;
  final double complianceScore;
  final List<SecurityAlert> recentAlerts;

  const SecurityDashboard({
    this.openVulnerabilities = 0,
    this.resolvedThisMonth = 0,
    this.complianceScore = 0,
    this.recentAlerts = const [],
  });

  factory SecurityDashboard.fromJson(Map<String, dynamic> json) =>
      SecurityDashboard(
        openVulnerabilities: json['openVulnerabilities'] as int? ?? 0,
        resolvedThisMonth: json['resolvedThisMonth'] as int? ?? 0,
        complianceScore:
            (json['complianceScore'] as num?)?.toDouble() ?? 0,
        recentAlerts: (json['recentAlerts'] as List<dynamic>?)
                ?.map((a) =>
                    SecurityAlert.fromJson(a as Map<String, dynamic>))
                .toList() ??
            [],
      );
}

class SecurityAlert {
  final String id;
  final String severity; // low, medium, high, critical
  final String message;
  final DateTime timestamp;

  const SecurityAlert({
    required this.id,
    required this.severity,
    required this.message,
    required this.timestamp,
  });

  factory SecurityAlert.fromJson(Map<String, dynamic> json) => SecurityAlert(
        id: json['id'] as String? ?? '',
        severity: json['severity'] as String? ?? 'low',
        message: json['message'] as String? ?? '',
        timestamp: json['timestamp'] != null
            ? DateTime.parse(json['timestamp'] as String)
            : DateTime.now(),
      );
}
