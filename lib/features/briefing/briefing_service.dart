/// Daily AI briefing — fetches HN top stories, summarises via Hermes,
/// caches once per UTC day. Power User Feature Pack §6.
library;

import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

const _hnTopUrl = 'https://hacker-news.firebaseio.com/v0/topstories.json';
String _hnItemUrl(int id) =>
    'https://hacker-news.firebaseio.com/v0/item/$id.json';
const _cacheKey = 'hn_briefing_cache_v1';
const _cacheDateKey = 'hn_briefing_date_v1';

class HnStory {
  final int id;
  final String title;
  final String? url;
  final String? domain;
  final int score;
  final int comments;
  final int time;

  const HnStory({
    required this.id,
    required this.title,
    this.url,
    this.domain,
    required this.score,
    required this.comments,
    required this.time,
  });

  factory HnStory.fromJson(Map<String, dynamic> j) {
    final url = j['url'] as String?;
    String? domain;
    if (url != null) {
      try {
        domain = Uri.parse(url).host.replaceFirst('www.', '');
      } catch (_) {}
    }
    return HnStory(
      id: j['id'] as int,
      title: j['title'] as String? ?? '',
      url: url,
      domain: domain,
      score: j['score'] as int? ?? 0,
      comments: j['descendants'] as int? ?? 0,
      time: j['time'] as int? ?? 0,
    );
  }
}

class BriefingResult {
  final List<HnStory> stories;
  final String? hermesSummary;
  final DateTime fetchedAt;

  const BriefingResult({
    required this.stories,
    this.hermesSummary,
    required this.fetchedAt,
  });
}

class BriefingService {
  Future<BriefingResult?> loadCached(SharedPreferences prefs) async {
    final date = prefs.getString(_cacheDateKey);
    if (date == null) return null;
    final today = DateTime.now().toIso8601String().substring(0, 10);
    if (date != today) return null;
    final raw = prefs.getString(_cacheKey);
    if (raw == null) return null;
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final stories = (json['stories'] as List)
          .cast<Map<String, dynamic>>()
          .map(
            (s) => HnStory(
              id: s['id'] as int,
              title: s['title'] as String,
              url: s['url'] as String?,
              domain: s['domain'] as String?,
              score: s['score'] as int,
              comments: s['comments'] as int,
              time: s['time'] as int,
            ),
          )
          .toList();
      return BriefingResult(
        stories: stories,
        hermesSummary: json['summary'] as String?,
        fetchedAt: DateTime.parse(json['fetchedAt'] as String),
      );
    } catch (_) {
      return null;
    }
  }

  Future<List<HnStory>> fetchTopStories({int count = 20}) async {
    final idsResponse = await http
        .get(Uri.parse(_hnTopUrl))
        .timeout(const Duration(seconds: 10));
    final ids =
        (jsonDecode(idsResponse.body) as List).cast<int>().take(30).toList();

    final stories = await Future.wait(
      ids.map((id) async {
        try {
          final r = await http
              .get(Uri.parse(_hnItemUrl(id)))
              .timeout(const Duration(seconds: 5));
          if (r.statusCode == 200) {
            final j = jsonDecode(r.body) as Map<String, dynamic>;
            if (j['type'] == 'story' && j['title'] != null) {
              return HnStory.fromJson(j);
            }
          }
        } catch (_) {}
        return null;
      }),
    );

    return stories.whereType<HnStory>().take(count).toList();
  }

  String buildHermesPrompt(List<HnStory> stories) {
    final titles = stories
        .take(20)
        .map(
          (s) => '- ${s.title}${s.domain != null ? " (${s.domain})" : ""}',
        )
        .join('\n');

    return '''You are giving a morning tech briefing.

Here are today's top Hacker News stories:

$titles

Task: Select the 5 most relevant stories for someone who:
- Builds AI agents and mobile apps (Flutter, MQL5, Python)
- Trades XAUUSD using algorithmic and discretionary strategies
- Follows AI/ML developments closely
- Runs a software consulting firm in South Africa

For each selected story, write exactly 2 sentences: what it is, and why it matters.
Keep the entire briefing under 250 words. Start directly with "1." — no preamble.''';
  }

  Future<void> cache({
    required SharedPreferences prefs,
    required List<HnStory> stories,
    required String? summary,
  }) async {
    final data = {
      'stories': stories
          .map(
            (s) => {
              'id': s.id,
              'title': s.title,
              'url': s.url,
              'domain': s.domain,
              'score': s.score,
              'comments': s.comments,
              'time': s.time,
            },
          )
          .toList(),
      'summary': summary,
      'fetchedAt': DateTime.now().toIso8601String(),
    };
    await prefs.setString(_cacheKey, jsonEncode(data));
    await prefs.setString(
      _cacheDateKey,
      DateTime.now().toIso8601String().substring(0, 10),
    );
  }
}

final briefingService = BriefingService();
