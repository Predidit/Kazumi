import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:kazumi/modules/bangumi/bangumi_item.dart';
import 'package:kazumi/request/apis/anilist_api.dart';

void main() {
  BangumiItem item({
    required int id,
    required String name,
    required String airDate,
    List<String> alias = const [],
  }) {
    return BangumiItem(
      id: id,
      type: 2,
      name: name,
      nameCn: '',
      summary: '',
      airDate: airDate,
      airWeekday: 1,
      rank: 0,
      images: const {},
      tags: const [],
      alias: alias,
      ratingScore: 0,
      votes: 0,
      votesCount: const [],
      info: '',
    );
  }

  String payload(List<Map<String, dynamic>> media) => jsonEncode(media);

  Map<String, dynamic> media({
    required String status,
    required String nativeTitle,
    required DateTime startDate,
    int? airingAt,
    List<String> synonyms = const [],
  }) {
    return {
      'status': status,
      'startDate': {
        'year': startDate.year,
        'month': startDate.month,
        'day': startDate.day,
      },
      'title': {
        'romaji': nativeTitle,
        'native': nativeTitle,
        'english': '',
      },
      'synonyms': synonyms,
      'nextAiringEpisode': airingAt == null ? null : {'airingAt': airingAt},
    };
  }

  test(
      'matches the native title and converts AniList UTC seconds to local time',
      () {
    final utcTime = DateTime.utc(2026, 7, 5, 14);
    final result = AniListApi.parseAiringTimes(
      payload([
        media(
          status: 'RELEASING',
          nativeTitle: '测试番剧',
          startDate: DateTime(2026, 7, 5),
          airingAt: utcTime.millisecondsSinceEpoch ~/ 1000,
        ),
      ]),
      [item(id: 1, name: '测试番剧', airDate: '2026-07-05')],
    );

    expect(result[1], utcTime.toLocal());
  });

  test('matches an alias only when the original air date confirms it', () {
    final result = AniListApi.parseAiringTimes(
      payload([
        media(
          status: 'RELEASING',
          nativeTitle: 'AniList Native',
          startDate: DateTime(2026, 7, 5),
          airingAt: 1783260000,
        ),
      ]),
      [
        item(
          id: 1,
          name: 'Bangumi Name',
          airDate: '2026-07-05',
          alias: const ['AniList Native'],
        ),
      ],
    );

    expect(result, contains(1));
  });

  test('does not display finished anime or ambiguous title-only matches', () {
    final result = AniListApi.parseAiringTimes(
      payload([
        media(
          status: 'FINISHED',
          nativeTitle: '已完结',
          startDate: DateTime(2026, 7, 5),
          airingAt: 1783260000,
        ),
        media(
          status: 'RELEASING',
          nativeTitle: '仅别名匹配',
          startDate: DateTime(2026, 7, 5),
          airingAt: 1783260000,
        ),
      ]),
      [
        item(id: 1, name: '已完结', airDate: '2026-07-05'),
        item(
          id: 2,
          name: '不同标题',
          airDate: '',
          alias: const ['仅别名匹配'],
        ),
      ],
    );

    expect(result, isEmpty);
  });

  test('uses AniList season names for quarterly cache keys', () {
    expect(AniListApi.buildSeasonCacheKey(DateTime(2026, 1)), '2026-WINTER');
    expect(AniListApi.buildSeasonCacheKey(DateTime(2026, 4)), '2026-SPRING');
    expect(AniListApi.buildSeasonCacheKey(DateTime(2026, 7)), '2026-SUMMER');
    expect(AniListApi.buildSeasonCacheKey(DateTime(2026, 10)), '2026-FALL');
  });
}
