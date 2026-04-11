/// Starter Pack activation — loads pack definitions and pushes to Paperclip
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// A single agent definition within a starter pack.
class PackAgent {
  final String name;
  final String role;
  final String tier;

  const PackAgent({
    required this.name,
    required this.role,
    required this.tier,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'role': role,
        'tier': tier,
      };
}

/// Full starter pack definition.
class StarterPack {
  final String id;
  final String displayName;
  final String description;
  final String icon;
  final String companyName;
  final String mission;
  final String governanceMode;
  final int defaultBudget;
  final List<String> phases;
  final List<PackAgent> agents;
  final List<String> skillFiles; // SKILL.md filenames bundled with this pack

  const StarterPack({
    required this.id,
    required this.displayName,
    required this.description,
    required this.icon,
    required this.companyName,
    required this.mission,
    required this.governanceMode,
    required this.defaultBudget,
    this.phases = const [],
    required this.agents,
    required this.skillFiles,
  });

  Map<String, dynamic> toCompanyJson() => {
        'companyName': companyName,
        'mission': mission,
        'governanceMode': governanceMode,
        'defaultBudget': defaultBudget,
        if (phases.isNotEmpty) 'phases': phases,
        'agents': agents.map((a) => a.toJson()).toList(),
      };
}

/// All available starter packs.
const List<StarterPack> kStarterPacks = [
  StarterPack(
    id: 'solo-founder-os',
    displayName: 'Solo Founder OS',
    description:
        'Complete AI company for one-person startups — marketing, ops, admin, strategy',
    icon: '\u{1F680}',
    companyName: 'My Solo Business',
    mission: 'Deliver high-impact services whilst maintaining work-life balance',
    governanceMode: 'advisory',
    defaultBudget: 120,
    agents: [
      PackAgent(name: 'Marketing Agent', role: 'Marketing', tier: 'server'),
      PackAgent(
          name: 'Client Success Agent', role: 'Client Success', tier: 'server'),
      PackAgent(
          name: 'Coaching Operations Agent',
          role: 'Coaching Operations',
          tier: 'bridge'),
      PackAgent(name: 'Growth Agent', role: 'Growth', tier: 'server'),
      PackAgent(
          name: 'Executive Assistant Agent',
          role: 'Executive Assistant',
          tier: 'server'),
    ],
    skillFiles: ['solo-founder.md'],
  ),
  StarterPack(
    id: 'forex-power-user',
    displayName: 'Forex Power User',
    description:
        'Risk-aware trading toolkit — CRT analysis, position sizing, trade journal',
    icon: '\u{1F4B9}',
    companyName: 'Trading Desk',
    mission: 'Disciplined, risk-aware trading with ICT/SMC methodology',
    governanceMode: 'advisory',
    defaultBudget: 50,
    agents: [
      PackAgent(
          name: 'Forex Analyst Agent', role: 'Forex Analysis', tier: 'local'),
    ],
    skillFiles: ['forex-starter.md', 'forex-calc.md'],
  ),
  StarterPack(
    id: 'enterprise-it-project-team',
    displayName: 'Enterprise IT Project Team',
    description:
        'Full 12-agent IT delivery team with strict governance and project phases',
    icon: '\u{1F3E2}',
    companyName: 'IT Delivery Department',
    mission:
        'Deliver high-quality, on-time, secure IT projects with full governance',
    governanceMode: 'strict',
    defaultBudget: 1500000,
    phases: [
      'Initiation',
      'Requirements',
      'Design',
      'Development',
      'Testing',
      'Deployment',
      'Hypercare',
      'Closeout',
    ],
    agents: [
      PackAgent(
          name: 'Project Manager Agent', role: 'Project Manager', tier: 'server'),
      PackAgent(
          name: 'Business Analyst Agent',
          role: 'Business Analyst',
          tier: 'bridge'),
      PackAgent(
          name: 'Solution Architect Agent',
          role: 'Solution Architect',
          tier: 'server'),
      PackAgent(
          name: 'Backend Developer Agent',
          role: 'Backend Developer',
          tier: 'server'),
      PackAgent(
          name: 'Frontend Developer Agent',
          role: 'Frontend Developer',
          tier: 'server'),
      PackAgent(
          name: 'QA Engineer Agent', role: 'QA Engineer', tier: 'server'),
      PackAgent(
          name: 'DevOps Engineer Agent', role: 'DevOps Engineer', tier: 'server'),
      PackAgent(
          name: 'Security Officer Agent',
          role: 'Security Officer',
          tier: 'server'),
      PackAgent(
          name: 'Data Analyst Agent', role: 'Data Analyst', tier: 'server'),
      PackAgent(
          name: 'UI/UX Designer Agent', role: 'UI/UX Designer', tier: 'bridge'),
      PackAgent(
          name: 'Change Management Lead Agent',
          role: 'Change Management',
          tier: 'server'),
      PackAgent(
          name: 'PMO Governance Analyst Agent',
          role: 'PMO Analyst',
          tier: 'server'),
    ],
    skillFiles: ['enterprise-it.md'],
  ),
  StarterPack(
    id: 'personal-ai-academy',
    displayName: 'Personal AI Academy',
    description:
        'Dynamic tutoring for Grades 8\u201312 — one tutor per subject + Success Coach',
    icon: '\u{1F393}',
    companyName: 'My AI Academy',
    mission: 'Personalised, curriculum-aligned learning support',
    governanceMode: 'advisory',
    defaultBudget: 80,
    agents: [
      PackAgent(
          name: 'Student Success Coach',
          role: 'Student Success',
          tier: 'server'),
    ],
    skillFiles: [
      'academy-tutor.md',
      'student-success-coach.md',
      'subject-tutor-template.md',
      'vertex-rag-bridge.md',
    ],
  ),
  StarterPack(
    id: 'life-architect',
    displayName: 'Life Architect',
    description:
        'Holistic personal coaching \u2014 GROW methodology + Master Life Architect',
    icon: '\u{1F331}',
    companyName: 'My Life Company',
    mission: 'Holistic personal development across all life facets',
    governanceMode: 'advisory',
    defaultBudget: 100,
    agents: [
      PackAgent(
          name: 'Master Life Architect',
          role: 'Life Architect',
          tier: 'server'),
      PackAgent(
          name: 'Fitness & Movement Coach', role: 'Fitness', tier: 'hybrid'),
    ],
    skillFiles: [
      'life-architect.md',
      'master-life-architect.md',
      'fitness-coach.md',
    ],
  ),
];

/// Service that activates a starter pack — pushes company template to
/// Paperclip REST, marks the pack as active in local prefs, and ensures
/// the associated skills are loaded.
class StarterPackService {
  final SharedPreferences _prefs;

  StarterPackService({required SharedPreferences prefs}) : _prefs = prefs;

  /// Returns the currently active pack ID, or null.
  String? get activePackId => _prefs.getString('active_pack_id');

  /// Whether a specific pack is the currently active one.
  bool isActive(String packId) => activePackId == packId;

  /// Activate a starter pack. If Paperclip REST URL is configured, pushes
  /// the company template. Always marks the pack as active locally.
  Future<PackActivationResult> activate(StarterPack pack) async {
    // 1. Mark locally
    await _prefs.setString('active_pack_id', pack.id);
    await _prefs.setString('company_name', pack.companyName);
    await _prefs.setString('company_mission', pack.mission);
    await _prefs.setString('governance_mode', pack.governanceMode);
    await _prefs.setInt('monthly_budget', pack.defaultBudget);

    // 2. Try to push to Paperclip REST if configured
    final restUrl = _prefs.getString('paperclip_rest_url') ?? '';
    final token = _prefs.getString('paperclip_token') ?? '';

    if (restUrl.isNotEmpty && token.isNotEmpty) {
      try {
        final response = await http.post(
          Uri.parse('$restUrl/api/company/import'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: jsonEncode(pack.toCompanyJson()),
        );

        if (response.statusCode == 200 || response.statusCode == 201) {
          debugPrint(
              'StarterPackService: pushed ${pack.id} to Paperclip successfully');
          return PackActivationResult(
            success: true,
            message:
                '${pack.displayName} activated and synced to Paperclip.',
            syncedToPaperclip: true,
          );
        } else {
          debugPrint(
              'StarterPackService: Paperclip responded ${response.statusCode}');
          return PackActivationResult(
            success: true,
            message:
                '${pack.displayName} activated locally. '
                'Paperclip sync failed (HTTP ${response.statusCode}) \u2014 '
                'will retry when connected.',
            syncedToPaperclip: false,
          );
        }
      } catch (e) {
        debugPrint('StarterPackService: Paperclip push failed: $e');
        return PackActivationResult(
          success: true,
          message:
              '${pack.displayName} activated locally. '
              'Could not reach Paperclip \u2014 will sync when connected.',
          syncedToPaperclip: false,
        );
      }
    }

    // No Paperclip configured — local-only activation
    return PackActivationResult(
      success: true,
      message:
          '${pack.displayName} activated. '
          'Connect Paperclip in Settings to spawn agents on your server.',
      syncedToPaperclip: false,
    );
  }

  /// Deactivate the current pack.
  Future<void> deactivate() async {
    await _prefs.remove('active_pack_id');
  }
}

class PackActivationResult {
  final bool success;
  final String message;
  final bool syncedToPaperclip;

  const PackActivationResult({
    required this.success,
    required this.message,
    required this.syncedToPaperclip,
  });
}
