/// Morning briefing screen — Hermes summary card + ranked HN story list.
/// Power User Feature Pack §6.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher_string.dart';

import '../../data/providers/core_providers.dart';
import '../../data/providers/hermes_providers.dart';
import 'briefing_service.dart';

final briefingProvider = FutureProvider<BriefingResult>((ref) async {
  final prefs = ref.watch(sharedPrefsProvider);

  final cached = await briefingService.loadCached(prefs);
  if (cached != null) return cached;

  final stories = await briefingService.fetchTopStories();

  String? summary;
  try {
    final client = ref.read(hermesClientProvider);
    if (client != null) {
      final prompt = briefingService.buildHermesPrompt(stories);
      summary = await client.chat(prompt, maxTokens: 400);
    }
  } catch (_) {
    // Briefing remains useful even when Hermes is unreachable — the
    // story list still renders. Summary card hides itself when null.
  }

  await briefingService.cache(
    prefs: prefs,
    stories: stories,
    summary: summary,
  );

  return BriefingResult(
    stories: stories,
    hermesSummary: summary,
    fetchedAt: DateTime.now(),
  );
});

class BriefingScreen extends ConsumerWidget {
  const BriefingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final briefAsync = ref.watch(briefingProvider);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Morning Briefing',
              style: GoogleFonts.jetBrainsMono(fontSize: 15),
            ),
            Text(
              'Top Hacker News · ${DateTime.now().day} ${_month(DateTime.now().month)} ${DateTime.now().year}',
              style: const TextStyle(fontSize: 11, color: Colors.white38),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, size: 18),
            tooltip: 'Refresh briefing',
            onPressed: () async {
              final prefs = ref.read(sharedPrefsProvider);
              await prefs.remove('hn_briefing_date_v1');
              ref.invalidate(briefingProvider);
            },
          ),
        ],
      ),
      body: briefAsync.when(
        loading: () => const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(strokeWidth: 2),
              SizedBox(height: 12),
              Text(
                'Asking Hermes to brief you…',
                style: TextStyle(color: Colors.white54),
              ),
            ],
          ),
        ),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Could not load briefing:\n$e',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.redAccent),
            ),
          ),
        ),
        data: (briefing) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (briefing.hermesSummary != null) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1509),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFFC9A227).withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.auto_awesome,
                          size: 14,
                          color: Color(0xFFC9A227),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Hermes Summary',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFFC9A227),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    SelectableText(
                      briefing.hermesSummary!,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.white70,
                        height: 1.6,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'ALL STORIES',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 10,
                  color: Colors.white38,
                  letterSpacing: 0.8,
                ),
              ),
            ),
            ...briefing.stories.asMap().entries.map(
                  (e) => _StoryCard(rank: e.key + 1, story: e.value),
                ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  String _month(int m) => const [
        '',
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ][m];
}

class _StoryCard extends StatelessWidget {
  final int rank;
  final HnStory story;
  const _StoryCard({required this.rank, required this.story});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: const Color(0xFF161B22),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: Color(0xFF30363D)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: story.url != null ? () => launchUrlString(story.url!) : null,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 24,
                child: Text(
                  '$rank',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 12,
                    color: const Color(0xFF484F58),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      story.title,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFFE6EDF3),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (story.domain != null)
                          Text(
                            story.domain!,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF58A6FF),
                            ),
                          ),
                        if (story.domain != null) const SizedBox(width: 8),
                        Text(
                          '▲ ${story.score}',
                          style: const TextStyle(
                            fontSize: 10,
                            color: Color(0xFF8B949E),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '💬 ${story.comments}',
                          style: const TextStyle(
                            fontSize: 10,
                            color: Color(0xFF8B949E),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
