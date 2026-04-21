/// Riverpod providers for the server-side Skills surface.
///
/// Wire shape per memory/gateway_control_surface.md:
///   - skills.status  → installed/bundled/workspace skills
///   - skills.search  → Claw Hub catalog
///   - skills.install → install by slug (source:"clawhub")
///   - skills.update  → enable/disable by skillKey, or pull latest
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/skill.dart';
import '../../data/providers/core_providers.dart';

// ── Installed/server skills ─────────────────────────────────────────────

final serverSkillsProvider =
    FutureProvider<List<ServerSkillEntry>>((ref) async {
  final client = ref.watch(gatewayClientProvider);
  if (client == null) return [];
  try {
    final result = await client.request('skills.status', {});
    if (result is! Map) return [];
    final skills = result['skills'];
    if (skills is! List) return [];
    return [
      for (final s in skills)
        if (s is Map<String, dynamic>) ServerSkillEntry.fromJson(s),
    ];
  } catch (_) {
    return [];
  }
});

// ── Claw Hub search (family keyed by query) ──────────────────────────────

final clawHubSearchProvider =
    FutureProvider.family<List<ClawHubSearchHit>, String>((ref, query) async {
  final client = ref.watch(gatewayClientProvider);
  if (client == null) return [];
  try {
    final params = <String, dynamic>{'limit': 50};
    if (query.trim().isNotEmpty) params['query'] = query.trim();
    final result = await client.request('skills.search', params);
    if (result is! Map) return [];
    final results = result['results'];
    if (results is! List) return [];
    return [
      for (final r in results)
        if (r is Map<String, dynamic>) ClawHubSearchHit.fromJson(r),
    ];
  } catch (_) {
    return [];
  }
});

// ── Actions ──────────────────────────────────────────────────────────────

/// Install a Claw Hub skill by slug. Admin scope.
Future<Map<String, dynamic>> installClawHubSkill(
  WidgetRef ref,
  String slug, {
  String? version,
  bool force = false,
}) async {
  final client = ref.read(gatewayClientProvider);
  if (client == null) throw 'Not connected to gateway';
  final result = await client.request(
    'skills.install',
    {
      'source': 'clawhub',
      'slug': slug,
      if (version != null) 'version': version,
      if (force) 'force': true,
    },
    timeout: const Duration(minutes: 2),
  );
  return result is Map<String, dynamic> ? result : {};
}

/// Enable or disable a local skill by `skillKey`. Admin scope.
/// The gateway has no uninstall RPC — disabling is the supported alternative.
Future<void> setServerSkillEnabled(
  WidgetRef ref,
  String skillKey,
  bool enabled,
) async {
  final client = ref.read(gatewayClientProvider);
  if (client == null) return;
  await client.request(
    'skills.update',
    {'skillKey': skillKey, 'enabled': enabled},
  );
}
