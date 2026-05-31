/// Browse and install skills from the Claw Hub registry via the gateway's
/// `skills.search` + `skills.install` WS RPCs. Previously called REST paths
/// that return the SPA index — replaced 2026-04-21.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../app/theme.dart';
import '../../data/models/skill.dart';
import '../../data/providers/core_providers.dart';
import '../../shared/widgets/empty_state.dart';
import 'skills_providers.dart';

final _clawHubQueryProvider = StateProvider<String>((_) => '');

class ClawHubBrowser extends ConsumerWidget {
  const ClawHubBrowser({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final client = ref.watch(gatewayClientProvider);
    final query = ref.watch(_clawHubQueryProvider);
    final resultsAsync = ref.watch(clawHubSearchProvider(query));

    if (client == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('ClawHub')),
        body: const EmptyState(
          icon: Icons.cloud_off,
          message: 'Connect to a Gateway to browse skills',
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('ClawHub'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, size: 20),
            onPressed: () => ref.invalidate(clawHubSearchProvider(query)),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search Claw Hub…',
                prefixIcon: const Icon(Icons.search, size: 20),
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onChanged: (v) =>
                  ref.read(_clawHubQueryProvider.notifier).state = v,
              textInputAction: TextInputAction.search,
            ),
          ),
          Expanded(
            child: resultsAsync.when(
              data: (hits) {
                if (hits.isEmpty) {
                  return const EmptyState(
                    icon: Icons.extension_off_outlined,
                    message: 'No skills found',
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: hits.length,
                  itemBuilder: (_, i) => _HubHitCard(hit: hits[i]),
                );
              },
              loading: () => const Center(
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              error: (e, _) => EmptyState(
                icon: Icons.error_outline,
                message: 'Failed to load skills\n$e',
                actionLabel: 'Retry',
                onAction: () =>
                    ref.invalidate(clawHubSearchProvider(query)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HubHitCard extends ConsumerStatefulWidget {
  final ClawHubSearchHit hit;

  const _HubHitCard({required this.hit});

  @override
  ConsumerState<_HubHitCard> createState() => _HubHitCardState();
}

class _HubHitCardState extends ConsumerState<_HubHitCard> {
  bool _installing = false;
  bool _installed = false;
  String? _error;

  Future<void> _install() async {
    setState(() {
      _installing = true;
      _error = null;
    });
    try {
      final result = await installClawHubSkill(ref, widget.hit.slug);
      final ok = result['ok'] == true;
      if (mounted) {
        setState(() {
          _installing = false;
          _installed = ok;
          if (!ok) {
            _error = result['message'] as String? ?? 'Install failed';
          }
        });
        if (ok) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${widget.hit.displayName} installed')),
          );
          ref.invalidate(serverSkillsProvider);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Install failed: $_error')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _installing = false;
          _error = '$e';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Install failed: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final h = widget.hit;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: PocketClawTheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Center(
                child: Text('🧩', style: TextStyle(fontSize: 20)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    h.displayName,
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    h.slug,
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 10,
                      color: Colors.white38,
                    ),
                  ),
                  if (h.summary != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      h.summary!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white54,
                        height: 1.4,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  if (h.version != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      'v${h.version}',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 10,
                        color: PocketClawTheme.electricTeal,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (_installed)
              Icon(Icons.check_circle,
                  size: 20, color: PocketClawTheme.success)
            else if (_installing)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              OutlinedButton(
                onPressed: _install,
                style: OutlinedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  textStyle: const TextStyle(fontSize: 12),
                ),
                child: const Text('Install'),
              ),
          ],
        ),
      ),
    );
  }
}
