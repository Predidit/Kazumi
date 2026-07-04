import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:kazumi/plugins/api_rule_config.dart';
import 'package:kazumi/services/plugin/api_rule_engine.dart';

void main() {
  const engine = ApiRuleStrategy();

  group('RestrictedJsonPath', () {
    test('allows fields, quoted fields, indexes and wildcards', () {
      for (final path in [
        r'$',
        r'$.data.videos[*]',
        r"$['data']['play-sources'][0]",
      ]) {
        expect(() => RestrictedJsonPath.validate(path), returnsNormally);
      }
    });

    test('rejects filters, recursive descent and expressions', () {
      for (final path in [
        r'$..videos',
        r'$.videos[?(@.enabled)]',
        r'$.videos[0:2]',
        r'$.videos.length()',
      ]) {
        expect(
          () => RestrictedJsonPath.validate(path),
          throwsA(isA<ApiRuleFormatException>()),
        );
      }
    });
  });

  test('prepares typed request placeholders', () {
    final request = engine.prepareRequest(
      ApiRequestConfig(
        method: 'post',
        url: 'https://example.com/videos/@source',
        headers: {'X-Keyword': '@keyword'},
        query: {'q': '@keyword', 'page': 1},
        bodyType: ApiBodyType.json,
        body: {
          'source': '@source',
          'label': 'video-@source',
        },
      ),
      {'source': 'a/b', 'keyword': '测试'},
    );

    expect(request.method, 'POST');
    expect(request.url, 'https://example.com/videos/a%2Fb');
    expect(request.headers['X-Keyword'], '测试');
    expect(request.query, {'q': '测试', 'page': 1});
    expect(request.body, {'source': 'a/b', 'label': 'video-a/b'});
  });

  test('ignores inactive request bodies for GET requests', () {
    final request = engine.prepareRequest(
      ApiRequestConfig(
        method: 'GET',
        url: 'https://example.com/search',
        bodyType: ApiBodyType.json,
        body: {'unused': '@missing'},
      ),
      const <String, Object?>{},
    );

    expect(request.body, isNull);
  });

  test('parses Liangzi search and delimited chapters', () {
    const searchRaw = '''
{
  "code": 1,
  "list": [
    {"vod_id": 22639, "vod_name": "吞噬星空"}
  ]
}
''';
    final searchConfig = ApiSearchConfig(
      listPath: r'$.list[*]',
      namePath: r'$.vod_name',
      sourcePath: r'$.vod_id',
    );
    final search = engine.parseSearch(searchRaw, searchConfig);
    expect(search.items.single.name, '吞噬星空');
    expect(search.items.single.src, '22639');

    const chapterRaw = r'''
{
  "list": [{
    "vod_play_from": "线路A$$$线路B",
    "vod_play_url": "第01集$https://cdn-a.test/1.m3u8#第02集$https://cdn-a.test/2.m3u8$$$正片$https://cdn-b.test/main.m3u8"
  }]
}
''';
    final chapterConfig = ApiChapterConfig(
      format: ApiChapterFormat.delimited,
      roadNamesPath: r'$.list[0].vod_play_from',
      roadEpisodesPath: r'$.list[0].vod_play_url',
    );
    final roads = engine.parseChapters(
      chapterRaw,
      chapterConfig,
      source: '22639',
      baseUrl: 'https://lzizy.net/',
    );
    expect(roads.roads, hasLength(2));
    expect(roads.roads[0].name, '线路A');
    expect(roads.roads[0].identifier, ['第01集', '第02集']);
    expect(roads.roads[0].data[0], 'https://cdn-a.test/1.m3u8');
    expect(roads.roads[1].name, '线路B');
    expect(roads.roads[1].data.single, 'https://cdn-b.test/main.m3u8');
  });

  test('parses TvTFun chapters and constructs playback page URLs', () {
    final raw = jsonEncode({
      'data': {
        'slug': '28431',
        'playSources': [
          {
            'name': '线路C',
            'episodes': [
              {'name': '第01集', 'url': 'protected'},
              {'name': '第02集', 'url': 'protected'},
            ],
          },
          {
            'name': '线路D',
            'episodes': [
              {'name': '第01集', 'url': 'protected'},
            ],
          },
        ],
      },
    });
    final config = ApiChapterConfig(
      roadsPath: r'$.data.playSources[*]',
      roadNamePath: r'$.name',
      episodesPath: r'$.episodes[*]',
      episodeNamePath: r'$.name',
      episodeUrlPath: '',
      variables: {'slug': r'$.data.slug'},
      episodePage: ApiEpisodePageConfig(
        url: 'https://www.tvtfun.net/video/@slug/play',
        query: {
          'source': '@roadIndex',
          'episode': '@episodeIndex',
        },
      ),
    );
    final roads = engine.parseChapters(
      raw,
      config,
      source: 'cmp2x3ot91k1qi9m8zglverqd',
      baseUrl: 'https://www.tvtfun.net/',
    );

    expect(roads.roads, hasLength(2));
    expect(
      roads.roads[0].data[1],
      'https://www.tvtfun.net/video/28431/play?source=0&episode=1',
    );
    expect(
      roads.roads[1].data.single,
      'https://www.tvtfun.net/video/28431/play?source=1&episode=0',
    );
  });

  test('skips malformed delimited episode entries', () {
    const raw = r'''
{"names":"线路","episodes":"损坏条目#第02集$https://cdn.test/2.m3u8"}
''';
    final roads = engine.parseChapters(
      raw,
      ApiChapterConfig(
        format: ApiChapterFormat.delimited,
        roadNamesPath: r'$.names',
        roadEpisodesPath: r'$.episodes',
      ),
      source: 'id',
      baseUrl: 'https://example.com/',
    );
    expect(roads.roads.single.identifier, ['第02集']);
    expect(roads.diagnostics, hasLength(1));
  });

  test('keeps default nested road names gapless without changing source index',
      () {
    final raw = jsonEncode({
      'data': {
        'roads': [
          {'episodes': <Object>[]},
          {
            'episodes': [
              {'name': '第01集'},
            ],
          },
        ],
      },
    });
    final result = engine.parseChapters(
      raw,
      ApiChapterConfig(
        roadNamePath: '',
        episodeUrlPath: '',
        episodePage: ApiEpisodePageConfig(
          url: '/play',
          query: {'source': '@roadIndex'},
        ),
      ),
      source: 'id',
      baseUrl: 'https://example.com/',
    );

    expect(result.roads.single.name, '播放线路1');
    expect(
      result.roads.single.data.single,
      'https://example.com/play?source=1',
    );
  });

  test('keeps default delimited road names gapless', () {
    const raw = r'''
{"names":"$$$","episodes":"损坏条目$$$第01集$https://cdn.test/1.m3u8"}
''';
    final result = engine.parseChapters(
      raw,
      ApiChapterConfig(
        format: ApiChapterFormat.delimited,
        roadNamesPath: r'$.names',
        roadEpisodesPath: r'$.episodes',
      ),
      source: 'id',
      baseUrl: 'https://example.com/',
    );

    expect(result.roads.single.name, '播放线路1');
    expect(result.roads.single.data.single, 'https://cdn.test/1.m3u8');
  });

  test('rejects invalid relative search paths before mapping entries', () {
    expect(
      () => engine.parseSearch(
        '{"data":[{"name":"item","id":"1"}]}',
        ApiSearchConfig(
          listPath: r'$.data[*]',
          namePath: r'$..name',
          sourcePath: r'$.id',
        ),
      ),
      throwsA(isA<ApiRuleFormatException>()),
    );
  });
}
