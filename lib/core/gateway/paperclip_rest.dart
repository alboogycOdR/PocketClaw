/// Paperclip REST API client + response models.
///
/// Paperclip is a standalone Node+PostgreSQL service on the VPS at
/// `http://<vps>:3100`. Separate from OpenClaw — independent auth
/// (agent API key in `Authorization: Bearer`), independent URL.
/// See `docs/PocketClaw-Paperclip-Architecture-v2.0.md` for the contract.
library;

import 'dart:convert';

import 'package:http/http.dart' as http;

class PaperclipRestClient {
  final String baseUrl;
  final String apiKey;
  final http.Client _http;

  PaperclipRestClient({
    required String baseUrl,
    required this.apiKey,
    http.Client? httpClient,
  })  : baseUrl = _normaliseBaseUrl(baseUrl),
        _http = httpClient ?? http.Client();

  /// Users often paste the dashboard URL (`http://host:3100`) without the
  /// `/api` prefix. Paperclip answers `/health` on both paths (that's why
  /// Test-connection passes), but the rest of the surface lives under
  /// `/api`. Normalise here so the user doesn't have to think about it.
  static String _normaliseBaseUrl(String raw) {
    var url = raw.trim();
    while (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }
    if (url.isEmpty) return url;
    if (!url.endsWith('/api')) url = '$url/api';
    return url;
  }

  Map<String, String> get _headers => {
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
      };

  // ── Health ────────────────────────────────────────────────────────────

  Future<bool> isReachable() async {
    try {
      final res = await _http
          .get(Uri.parse('$baseUrl/health'))
          .timeout(const Duration(seconds: 5));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // ── Companies ─────────────────────────────────────────────────────────

  Future<List<PaperclipCompany>> getCompanies() async {
    final res = await _get('/companies');
    final list = res is List ? res : (res['companies'] as List? ?? const []);
    return [
      for (final e in list)
        if (e is Map<String, dynamic>) PaperclipCompany.fromJson(e),
    ];
  }

  Future<PaperclipDashboard> getDashboard(String companyId) async {
    final res = await _get('/companies/$companyId/dashboard');
    return PaperclipDashboard.fromJson(res as Map<String, dynamic>);
  }

  // ── Agents / Org Chart ────────────────────────────────────────────────

  Future<List<PaperclipAgent>> getAgents(String companyId) async {
    final res = await _get('/companies/$companyId/agents');
    final list = res is List ? res : (res['agents'] as List? ?? const []);
    return [
      for (final e in list)
        if (e is Map<String, dynamic>) PaperclipAgent.fromJson(e),
    ];
  }

  Future<dynamic> getOrgChart(String companyId) async {
    return await _get('/companies/$companyId/org');
  }

  Future<void> pauseAgent(String agentId) =>
      _post('/agents/$agentId/pause', const {});

  Future<void> resumeAgent(String agentId) =>
      _post('/agents/$agentId/resume', const {});

  Future<void> terminateAgent(String agentId) =>
      _post('/agents/$agentId/terminate', const {});

  // ── Issues (Tickets) ──────────────────────────────────────────────────

  Future<List<PaperclipIssue>> getIssues(
    String companyId, {
    String? status,
    String? assigneeAgentId,
    String? projectId,
  }) async {
    final params = <String, String>{};
    if (status != null) params['status'] = status;
    if (assigneeAgentId != null) params['assigneeAgentId'] = assigneeAgentId;
    if (projectId != null) params['projectId'] = projectId;
    final res = await _get('/companies/$companyId/issues', params: params);
    final list = res is List ? res : (res['issues'] as List? ?? const []);
    return [
      for (final e in list)
        if (e is Map<String, dynamic>) PaperclipIssue.fromJson(e),
    ];
  }

  Future<PaperclipIssue> createIssue(
    String companyId, {
    required String title,
    String? description,
    String status = 'todo',
    String priority = 'medium',
    String? assigneeAgentId,
    String? projectId,
    String? goalId,
  }) async {
    final res = await _post('/companies/$companyId/issues', {
      'title': title,
      if (description != null) 'description': description,
      'status': status,
      'priority': priority,
      if (assigneeAgentId != null) 'assigneeAgentId': assigneeAgentId,
      if (projectId != null) 'projectId': projectId,
      if (goalId != null) 'goalId': goalId,
    });
    return PaperclipIssue.fromJson(res as Map<String, dynamic>);
  }

  Future<void> updateIssue(String issueId, Map<String, dynamic> fields) async {
    await _patch('/issues/$issueId', fields);
  }

  Future<void> addIssueComment(String issueId, String body) async {
    await _post('/issues/$issueId/comments', {'body': body});
  }

  // ── Goals ─────────────────────────────────────────────────────────────

  Future<List<PaperclipGoal>> getGoals(String companyId) async {
    final res = await _get('/companies/$companyId/goals');
    final list = res is List ? res : (res['goals'] as List? ?? const []);
    return [
      for (final e in list)
        if (e is Map<String, dynamic>) PaperclipGoal.fromJson(e),
    ];
  }

  Future<PaperclipGoal> createGoal(
    String companyId, {
    required String title,
    String? description,
    String level = 'company',
    String status = 'active',
  }) async {
    final res = await _post('/companies/$companyId/goals', {
      'title': title,
      if (description != null) 'description': description,
      'level': level,
      'status': status,
    });
    return PaperclipGoal.fromJson(res as Map<String, dynamic>);
  }

  Future<void> updateGoal(String goalId, Map<String, dynamic> fields) async {
    await _patch('/goals/$goalId', fields);
  }

  // ── Costs (Budgets) ───────────────────────────────────────────────────

  Future<PaperclipCostSummary> getCostSummary(String companyId) async {
    final res = await _get('/companies/$companyId/costs/summary');
    return PaperclipCostSummary.fromJson(res as Map<String, dynamic>);
  }

  Future<List<PaperclipAgentCost>> getCostByAgent(String companyId) async {
    final res = await _get('/companies/$companyId/costs/by-agent');
    final list = res is List ? res : (res['agents'] as List? ?? const []);
    return [
      for (final e in list)
        if (e is Map<String, dynamic>) PaperclipAgentCost.fromJson(e),
    ];
  }

  // ── Approvals (Governance) ────────────────────────────────────────────

  Future<List<PaperclipApproval>> getApprovals(
    String companyId, {
    String? status,
  }) async {
    final params = status != null ? {'status': status} : <String, String>{};
    final res =
        await _get('/companies/$companyId/approvals', params: params);
    final list = res is List ? res : (res['approvals'] as List? ?? const []);
    return [
      for (final e in list)
        if (e is Map<String, dynamic>) PaperclipApproval.fromJson(e),
    ];
  }

  Future<void> approveApproval(String approvalId,
      {String? decisionNote}) async {
    await _post('/approvals/$approvalId/approve', {
      if (decisionNote != null) 'decisionNote': decisionNote,
    });
  }

  Future<void> rejectApproval(String approvalId,
      {String? decisionNote}) async {
    await _post('/approvals/$approvalId/reject', {
      if (decisionNote != null) 'decisionNote': decisionNote,
    });
  }

  // ── Activity (Security tab audit section) ─────────────────────────────

  Future<List<PaperclipActivityEntry>> getActivity(
    String companyId, {
    String? entityType,
    String? agentId,
  }) async {
    final params = <String, String>{};
    if (entityType != null) params['entityType'] = entityType;
    if (agentId != null) params['agentId'] = agentId;
    final res = await _get('/companies/$companyId/activity', params: params);
    final list = res is List ? res : (res['activity'] as List? ?? const []);
    return [
      for (final e in list)
        if (e is Map<String, dynamic>) PaperclipActivityEntry.fromJson(e),
    ];
  }

  // ── Private helpers ───────────────────────────────────────────────────

  Future<dynamic> _get(String path, {Map<String, String>? params}) async {
    var uri = Uri.parse('$baseUrl$path');
    if (params != null && params.isNotEmpty) {
      uri = uri.replace(queryParameters: params);
    }
    final res = await _http
        .get(uri, headers: _headers)
        .timeout(const Duration(seconds: 15));
    _checkStatus(res);
    return res.body.isEmpty ? null : jsonDecode(res.body);
  }

  Future<dynamic> _post(String path, Map<String, dynamic> body) async {
    final res = await _http
        .post(
          Uri.parse('$baseUrl$path'),
          headers: _headers,
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 15));
    _checkStatus(res);
    return res.body.isEmpty ? null : jsonDecode(res.body);
  }

  Future<dynamic> _patch(String path, Map<String, dynamic> body) async {
    final res = await _http
        .patch(
          Uri.parse('$baseUrl$path'),
          headers: _headers,
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 15));
    _checkStatus(res);
    return res.body.isEmpty ? null : jsonDecode(res.body);
  }

  void _checkStatus(http.Response res) {
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw PaperclipApiException(
        statusCode: res.statusCode,
        body: res.body,
        path: res.request?.url.path ?? '?',
      );
    }
  }

  void dispose() => _http.close();
}

class PaperclipApiException implements Exception {
  final int statusCode;
  final String body;
  final String path;

  const PaperclipApiException({
    required this.statusCode,
    required this.body,
    required this.path,
  });

  bool get isRetryable => statusCode >= 500;
  bool get isAuthError => statusCode == 401 || statusCode == 403;

  @override
  String toString() =>
      'PaperclipApiException($statusCode) on $path: ${body.isEmpty ? '(no body)' : body}';
}

/// Translate an exception into a short user-facing message.
String friendlyPaperclipError(Object err) {
  if (err is PaperclipApiException) {
    if (err.isAuthError) return 'Paperclip API key rejected.';
    if (err.statusCode == 404) return 'Paperclip resource not found.';
    if (err.statusCode == 409) return 'Conflict — already claimed.';
    if (err.statusCode == 422) return 'Invalid state change.';
    if (err.isRetryable) return 'Paperclip server error. Try again.';
    return 'Paperclip returned HTTP ${err.statusCode}.';
  }
  return 'Paperclip unreachable.';
}

// ═════════════════════════════════════════════════════════════════════════
// Models
// ═════════════════════════════════════════════════════════════════════════

class PaperclipCompany {
  final String id;
  final String name;
  final String? description;
  final String status;
  final int budgetMonthlyCents;
  final String? logoUrl;
  final DateTime? createdAt;

  const PaperclipCompany({
    required this.id,
    required this.name,
    this.description,
    this.status = 'active',
    this.budgetMonthlyCents = 0,
    this.logoUrl,
    this.createdAt,
  });

  factory PaperclipCompany.fromJson(Map<String, dynamic> json) =>
      PaperclipCompany(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '(unnamed)',
        description: json['description'] as String?,
        status: json['status'] as String? ?? 'active',
        budgetMonthlyCents:
            (json['budgetMonthlyCents'] as num?)?.toInt() ?? 0,
        logoUrl: json['logoUrl'] as String?,
        createdAt: _parseDate(json['createdAt']),
      );
}

class PaperclipDashboard {
  final Map<String, int> agentCounts;
  final Map<String, int> issueCounts;
  final int staleTaskCount;
  final PaperclipCostSummary? costs;
  final List<PaperclipActivityEntry> recentActivity;
  final Map<String, dynamic> raw;

  const PaperclipDashboard({
    this.agentCounts = const {},
    this.issueCounts = const {},
    this.staleTaskCount = 0,
    this.costs,
    this.recentActivity = const [],
    this.raw = const {},
  });

  int get totalAgents => agentCounts.values.fold(0, (a, b) => a + b);
  int get activeAgents =>
      (agentCounts['active'] ?? 0) + (agentCounts['running'] ?? 0);
  int get totalIssues => issueCounts.values.fold(0, (a, b) => a + b);
  int get inProgressIssues => issueCounts['in_progress'] ?? 0;

  factory PaperclipDashboard.fromJson(Map<String, dynamic> json) {
    Map<String, int> asIntMap(dynamic v) {
      if (v is! Map) return const {};
      return {
        for (final entry in v.entries)
          entry.key.toString(): (entry.value as num?)?.toInt() ?? 0,
      };
    }

    return PaperclipDashboard(
      agentCounts: asIntMap(json['agentCounts'] ?? json['agents']),
      issueCounts: asIntMap(json['issueCounts'] ?? json['issues']),
      staleTaskCount: (json['staleTaskCount'] as num?)?.toInt() ?? 0,
      costs: json['costs'] is Map<String, dynamic>
          ? PaperclipCostSummary.fromJson(json['costs'] as Map<String, dynamic>)
          : null,
      recentActivity: [
        for (final e in (json['recentActivity'] as List? ?? const []))
          if (e is Map<String, dynamic>) PaperclipActivityEntry.fromJson(e),
      ],
      raw: json,
    );
  }
}

class PaperclipAgent {
  final String id;
  final String name;
  final String? title;
  final String role;
  final String? companyId;
  final String? reportsTo;
  final String? capabilities;
  final String status;
  final int budgetMonthlyCents;
  final int spentMonthlyCents;
  final List<Map<String, dynamic>> chainOfCommand;

  const PaperclipAgent({
    required this.id,
    required this.name,
    required this.role,
    required this.status,
    this.title,
    this.companyId,
    this.reportsTo,
    this.capabilities,
    this.budgetMonthlyCents = 0,
    this.spentMonthlyCents = 0,
    this.chainOfCommand = const [],
  });

  double get budgetUsageRatio => budgetMonthlyCents <= 0
      ? 0
      : (spentMonthlyCents / budgetMonthlyCents).clamp(0, 1);

  factory PaperclipAgent.fromJson(Map<String, dynamic> json) => PaperclipAgent(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '(unnamed)',
        title: json['title'] as String?,
        role: json['role'] as String? ?? 'member',
        companyId: json['companyId'] as String?,
        reportsTo: json['reportsTo'] as String?,
        capabilities: json['capabilities'] as String?,
        status: json['status'] as String? ?? 'idle',
        budgetMonthlyCents:
            (json['budgetMonthlyCents'] as num?)?.toInt() ?? 0,
        spentMonthlyCents:
            (json['spentMonthlyCents'] as num?)?.toInt() ?? 0,
        chainOfCommand: [
          for (final c in (json['chainOfCommand'] as List? ?? const []))
            if (c is Map<String, dynamic>) c,
        ],
      );
}

class PaperclipIssue {
  final String id;
  final String title;
  final String? description;
  final String status;
  final String priority;
  final String? assigneeAgentId;
  final String? projectId;
  final String? goalId;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const PaperclipIssue({
    required this.id,
    required this.title,
    required this.status,
    required this.priority,
    this.description,
    this.assigneeAgentId,
    this.projectId,
    this.goalId,
    this.createdAt,
    this.updatedAt,
  });

  factory PaperclipIssue.fromJson(Map<String, dynamic> json) => PaperclipIssue(
        id: json['id'] as String? ?? '',
        title: json['title'] as String? ?? '(untitled)',
        description: json['description'] as String?,
        status: json['status'] as String? ?? 'todo',
        priority: json['priority'] as String? ?? 'medium',
        assigneeAgentId: json['assigneeAgentId'] as String?,
        projectId: json['projectId'] as String?,
        goalId: json['goalId'] as String?,
        createdAt: _parseDate(json['createdAt']),
        updatedAt: _parseDate(json['updatedAt']),
      );
}

class PaperclipGoal {
  final String id;
  final String title;
  final String? description;
  final String level;
  final String status;
  final DateTime? createdAt;

  const PaperclipGoal({
    required this.id,
    required this.title,
    required this.level,
    required this.status,
    this.description,
    this.createdAt,
  });

  factory PaperclipGoal.fromJson(Map<String, dynamic> json) => PaperclipGoal(
        id: json['id'] as String? ?? '',
        title: json['title'] as String? ?? '(untitled)',
        description: json['description'] as String?,
        level: json['level'] as String? ?? 'company',
        status: json['status'] as String? ?? 'active',
        createdAt: _parseDate(json['createdAt']),
      );
}

class PaperclipCostSummary {
  final int spentCents;
  final int budgetCents;
  final double utilisation;
  final String? periodStart;
  final String? periodEnd;

  const PaperclipCostSummary({
    this.spentCents = 0,
    this.budgetCents = 0,
    this.utilisation = 0,
    this.periodStart,
    this.periodEnd,
  });

  double get spentDollars => spentCents / 100.0;
  double get budgetDollars => budgetCents / 100.0;
  double get remainingDollars =>
      (budgetCents > 0 ? (budgetCents - spentCents) : 0) / 100.0;

  factory PaperclipCostSummary.fromJson(Map<String, dynamic> json) =>
      PaperclipCostSummary(
        spentCents: (json['spentCents'] as num?)?.toInt() ??
            ((json['spent'] as num?)?.toInt() ?? 0),
        budgetCents: (json['budgetCents'] as num?)?.toInt() ??
            ((json['budget'] as num?)?.toInt() ?? 0),
        utilisation: (json['utilisation'] as num?)?.toDouble() ??
            (json['utilization'] as num?)?.toDouble() ??
            0,
        periodStart: json['periodStart'] as String?,
        periodEnd: json['periodEnd'] as String?,
      );
}

class PaperclipAgentCost {
  final String agentId;
  final String? agentName;
  final int spentCents;
  final int budgetCents;

  const PaperclipAgentCost({
    required this.agentId,
    this.agentName,
    this.spentCents = 0,
    this.budgetCents = 0,
  });

  double get spentDollars => spentCents / 100.0;
  double get budgetDollars => budgetCents / 100.0;

  factory PaperclipAgentCost.fromJson(Map<String, dynamic> json) =>
      PaperclipAgentCost(
        agentId: json['agentId'] as String? ?? '',
        agentName: json['agentName'] as String?,
        spentCents: (json['spentCents'] as num?)?.toInt() ??
            ((json['spent'] as num?)?.toInt() ?? 0),
        budgetCents: (json['budgetCents'] as num?)?.toInt() ??
            ((json['budget'] as num?)?.toInt() ?? 0),
      );
}

class PaperclipApproval {
  final String id;
  final String title;
  final String? description;
  final String status;
  final String? requestedBy;
  final String? decisionNote;
  final DateTime? createdAt;

  const PaperclipApproval({
    required this.id,
    required this.title,
    required this.status,
    this.description,
    this.requestedBy,
    this.decisionNote,
    this.createdAt,
  });

  factory PaperclipApproval.fromJson(Map<String, dynamic> json) =>
      PaperclipApproval(
        id: json['id'] as String? ?? '',
        title: json['title'] as String? ?? '(untitled approval)',
        description: json['description'] as String?,
        status: json['status'] as String? ?? 'pending',
        requestedBy: json['requestedBy'] as String?,
        decisionNote: json['decisionNote'] as String?,
        createdAt: _parseDate(json['createdAt']),
      );
}

class PaperclipActivityEntry {
  final String? actor;
  final String? action;
  final String? entityType;
  final String? entityId;
  final Map<String, dynamic>? details;
  final DateTime? createdAt;

  const PaperclipActivityEntry({
    this.actor,
    this.action,
    this.entityType,
    this.entityId,
    this.details,
    this.createdAt,
  });

  factory PaperclipActivityEntry.fromJson(Map<String, dynamic> json) =>
      PaperclipActivityEntry(
        actor: json['actor'] as String?,
        action: json['action'] as String?,
        entityType: json['entityType'] as String?,
        entityId: json['entityId'] as String?,
        details: json['details'] is Map<String, dynamic>
            ? json['details'] as Map<String, dynamic>
            : null,
        createdAt: _parseDate(json['createdAt']),
      );
}

DateTime? _parseDate(dynamic v) {
  if (v is String && v.isNotEmpty) return DateTime.tryParse(v);
  if (v is num) return DateTime.fromMillisecondsSinceEpoch(v.toInt());
  return null;
}
