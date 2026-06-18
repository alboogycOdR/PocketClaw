library;

import '../../features/ambient/models/tv_channel.dart';
import '../../features/ambient/models/tv_epg.dart';
import 'tv_database.dart';

class TvStreamService {
  Future<List<TvChannel>> findAlternatives({
    required TvChannel channel,
    required List<TvChannel> allChannels,
  }) async {
    final currentMapping = await tvDatabase.getEpgMapping(channel.id);
    final Map<String, TvEpgMapping> mappings = currentMapping == null
        ? const <String, TvEpgMapping>{}
        : await tvDatabase.getEpgMappings();
    final currentCallSign = _extractCallSign(channel.displayName);
    final currentName = _normalizeName(channel.displayName);
    final currentTvg = channel.tvgId?.trim().toLowerCase();

    final candidates = <_AlternativeScore>[];
    for (final candidate in allChannels) {
      if (candidate.id == channel.id ||
          candidate.streamUrl.trim() == channel.streamUrl.trim()) {
        continue;
      }

      var score = 0.0;
      final reasons = <String>[];
      final candidateTvg = candidate.tvgId?.trim().toLowerCase();
      if (currentTvg != null &&
          currentTvg.isNotEmpty &&
          candidateTvg == currentTvg) {
        score += 10;
        reasons.add('tvg-id');
      }

      if (currentMapping != null) {
        final candidateMapping = mappings[candidate.id];
        if (candidateMapping?.epgChannelId == currentMapping.epgChannelId) {
          score += 8;
          reasons.add('epg');
        }
      }

      final candidateCallSign = _extractCallSign(candidate.displayName);
      if (currentCallSign != null && candidateCallSign == currentCallSign) {
        score += 7;
        reasons.add('call-sign');
      }

      final candidateName = _normalizeName(candidate.displayName);
      if (currentName.isNotEmpty && candidateName == currentName) {
        score += 6;
        reasons.add('name');
      } else if (_tokenOverlap(currentName, candidateName) >= 0.82) {
        score += 4;
        reasons.add('tokens');
      }

      if (candidate.groupTitle == channel.groupTitle) score += 0.5;
      if (score < 4) continue;
      candidates.add(_AlternativeScore(channel: candidate, score: score));
    }

    final healthScores = await tvDatabase.getStreamHealthScores(
      candidates.map((candidate) => candidate.channel.streamUrl).toList(),
    );
    candidates.sort((a, b) {
      final aScore = a.score + (healthScores[a.channel.streamUrl] ?? 0.5);
      final bScore = b.score + (healthScores[b.channel.streamUrl] ?? 0.5);
      return bScore.compareTo(aScore);
    });
    return candidates.map((candidate) => candidate.channel).take(8).toList();
  }

  String _normalizeName(String name) => name
      .toLowerCase()
      .replaceAll(
        RegExp(r'\b(hd|fhd|uhd|4k|sd|hevc|h\.?265|h\.?264|1080p|720p)\b'),
        '',
      )
      .replaceAll(RegExp(r'\[[^\]]*\]'), '')
      .replaceAll(RegExp(r'\([^)]*\)'), '')
      .replaceAll(RegExp(r'[^\w\s]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  String? _extractCallSign(String value) {
    final parenthesized = RegExp(
      r'\(([WK][A-Z]{2,4})\)',
      caseSensitive: false,
    ).firstMatch(value);
    if (parenthesized != null) return parenthesized.group(1)!.toUpperCase();
    final standalone = RegExp(
      r'\b([WK][A-Z]{2,4})\b',
      caseSensitive: false,
    ).firstMatch(value);
    return standalone?.group(1)?.toUpperCase();
  }

  double _tokenOverlap(String a, String b) {
    final aTokens = a.split(RegExp(r'\s+')).where((t) => t.length > 2).toSet();
    final bTokens = b.split(RegExp(r'\s+')).where((t) => t.length > 2).toSet();
    if (aTokens.isEmpty || bTokens.isEmpty) return 0;
    return aTokens.intersection(bTokens).length / aTokens.union(bTokens).length;
  }
}

class _AlternativeScore {
  final TvChannel channel;
  final double score;

  const _AlternativeScore({required this.channel, required this.score});
}

final tvStreamService = TvStreamService();
