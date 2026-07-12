import 'dart:convert';

import 'package:kazumi/modules/bangumi/bangumi_item.dart';
import 'package:kazumi/request/clients/anilist_client.dart';
import 'package:kazumi/services/logging/logger.dart';

/// Resolves the next AniList episode time for Bangumi subjects.
///
/// AniList does not expose Bangumi IDs. Matches therefore require an exact
/// normalized title, with an air-date check for aliases.
class AniListApi {
  static const _cacheTtl = Duration(hours: 1);
  static const _query = r'''
query ($page: Int!, $season: MediaSeason!, $seasonYear: Int!) {
  Page(page: $page, perPage: 50) {
    pageInfo { hasNextPage }
    media(type: ANIME, season: $season, seasonYear: $seasonYear) {
      status
      startDate { year month day }
      title { romaji native english }
      synonyms
      nextAiringEpisode { airingAt }
    }
  }
}
''';

  static final AniListClient _client = AniListClient.instance;
  static final Map<String, _SeasonCache> _cache = {};
  static final Map<String, Future<List<_AniListMedia>>> _requests = {};

  static Future<Map<int, DateTime>> getAiringTimes(
    Iterable<BangumiItem> items, {
    required DateTime selectedDate,
  }) async {
    final itemsBySeason = <String, List<BangumiItem>>{};
    final datesBySeason = <String, DateTime>{};
    for (final item in items) {
      final airDate = DateTime.tryParse(item.airDate) ?? selectedDate;
      final key = buildSeasonCacheKey(airDate);
      (itemsBySeason[key] ??= []).add(item);
      datesBySeason.putIfAbsent(key, () => airDate);
    }

    final matches = await Future.wait(itemsBySeason.entries.map((entry) async {
      final media = await _getSeasonMedia(datesBySeason[entry.key]!);
      return _matchAiringTimes(entry.value, media);
    }));
    return {for (final match in matches) ...match};
  }

  static Future<DateTime?> getAiringTime(BangumiItem item) async {
    final airDate = DateTime.tryParse(item.airDate);
    if (airDate == null) return null;
    return (await getAiringTimes([item], selectedDate: airDate))[item.id];
  }

  static String buildSeasonCacheKey(DateTime date) {
    return '${date.year}-${_seasonName(date)}';
  }

  static Map<int, DateTime> parseAiringTimes(
    String payload,
    Iterable<BangumiItem> items,
  ) {
    final decoded = jsonDecode(payload);
    if (decoded is! List) {
      throw const FormatException('AniList season payload must be a list');
    }
    return _matchAiringTimes(
      items,
      decoded.whereType<Map>().map(_AniListMedia.fromJson),
    );
  }

  static Future<List<_AniListMedia>> _getSeasonMedia(DateTime date) {
    final key = buildSeasonCacheKey(date);
    final cached = _cache[key];
    if (cached != null &&
        DateTime.now().difference(cached.fetchedAt) < _cacheTtl) {
      return Future.value(cached.media);
    }

    return _requests.putIfAbsent(key, () async {
      try {
        final media = await _fetchSeasonMedia(date);
        _cache[key] = _SeasonCache(media, DateTime.now());
        return media;
      } catch (error) {
        KazumiLogger()
            .e('Network: resolve AniList airing schedule failed', error: error);
        return const [];
      } finally {
        _requests.remove(key);
      }
    });
  }

  static Future<List<_AniListMedia>> _fetchSeasonMedia(DateTime date) async {
    final media = <_AniListMedia>[];
    var page = 1;
    var hasNextPage = true;
    while (hasNextPage) {
      final response = await _client.query(
        _query,
        variables: {
          'page': page,
          'season': _seasonName(date),
          'seasonYear': date.year,
        },
      );
      final data = response is Map ? response['data'] : null;
      final pageData = data is Map ? data['Page'] : null;
      if (pageData is! Map) {
        throw const FormatException('AniList response does not contain Page');
      }
      final pageMedia = pageData['media'];
      if (pageMedia is List) {
        media.addAll(pageMedia.whereType<Map>().map(_AniListMedia.fromJson));
      }
      final pageInfo = pageData['pageInfo'];
      hasNextPage = pageInfo is Map && pageInfo['hasNextPage'] == true;
      page++;
    }
    return media;
  }

  static Map<int, DateTime> _matchAiringTimes(
    Iterable<BangumiItem> items,
    Iterable<_AniListMedia> media,
  ) {
    final result = <int, DateTime>{};
    for (final item in items) {
      final match = _findMatch(item, media);
      if (match?.airingTime case final airingTime?) {
        result[item.id] = airingTime;
      }
    }
    return result;
  }

  static _AniListMedia? _findMatch(
    BangumiItem item,
    Iterable<_AniListMedia> media,
  ) {
    final labels = {
      item.name,
      item.nameCn,
      ...item.alias,
    }.map(_normalizeTitle).where((label) => label.isNotEmpty).toSet();
    if (labels.isEmpty) return null;

    final exactName = _normalizeTitle(item.name);
    final airDate = DateTime.tryParse(item.airDate);
    final matches = media.where((candidate) {
      if (candidate.hasEnded || candidate.airingTime == null) return false;
      if (!labels.any(candidate.labels.contains)) return false;
      if (candidate.labels.contains(exactName)) return true;
      return airDate != null &&
          candidate.startDate != null &&
          _isSameDate(airDate, candidate.startDate!);
    }).toList();
    return matches.length == 1 ? matches.single : null;
  }

  static bool _isSameDate(DateTime left, DateTime right) {
    return left.year == right.year &&
        left.month == right.month &&
        left.day == right.day;
  }

  static String _seasonName(DateTime date) {
    switch ((date.month - 1) ~/ 3) {
      case 0:
        return 'WINTER';
      case 1:
        return 'SPRING';
      case 2:
        return 'SUMMER';
      default:
        return 'FALL';
    }
  }

  static String _normalizeTitle(String value) {
    return value.toLowerCase().replaceAll(
        RegExp(r'''[\s\-_!！?？:：;；,，.。/／·・～~()（）\[\]【】「」『』'\"]'''), '');
  }
}

class _SeasonCache {
  const _SeasonCache(this.media, this.fetchedAt);

  final List<_AniListMedia> media;
  final DateTime fetchedAt;
}

class _AniListMedia {
  const _AniListMedia({
    required this.status,
    required this.startDate,
    required this.labels,
    required this.airingTime,
  });

  factory _AniListMedia.fromJson(Map value) {
    final title = value['title'] is Map ? value['title'] as Map : const {};
    final start = value['startDate'] is Map ? value['startDate'] as Map : null;
    final nextEpisode = value['nextAiringEpisode'] is Map
        ? value['nextAiringEpisode'] as Map
        : null;
    final seconds = nextEpisode?['airingAt'];
    final airingAt = seconds is int ? seconds : int.tryParse('$seconds');
    final titles = [
      title['romaji'],
      title['native'],
      title['english'],
      ...(value['synonyms'] as List? ?? const []),
    ];
    return _AniListMedia(
      status: value['status']?.toString() ?? '',
      startDate: _dateFromParts(start?['year'], start?['month'], start?['day']),
      labels: titles
          .map((value) => AniListApi._normalizeTitle('$value'))
          .where((value) => value.isNotEmpty)
          .toSet(),
      airingTime: airingAt == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(airingAt * 1000, isUtc: true)
              .toLocal(),
    );
  }

  final String status;
  final DateTime? startDate;
  final Set<String> labels;
  final DateTime? airingTime;

  bool get hasEnded => status == 'FINISHED' || status == 'CANCELLED';

  static DateTime? _dateFromParts(dynamic year, dynamic month, dynamic day) {
    if (year is! int || month is! int || day is! int) return null;
    return DateTime(year, month, day);
  }
}
