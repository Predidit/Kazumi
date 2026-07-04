import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kazumi/plugins/anti_crawler_config.dart';
import 'package:kazumi/plugins/api_rule_config.dart';
import 'package:kazumi/request/core/network_exception.dart';
import 'package:kazumi/services/plugin/rule_engine.dart';
import 'package:kazumi/services/plugin/rule_engine_models.dart';
import 'package:kazumi/services/plugin/xpath_rule_strategy.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const xpathResponse = '''
<html>
  <article class="result"><h2><a href="/video/alpha">Alpha</a></h2></article>
  <div class="road"><a href="/play/alpha-1">第1集</a></div>
</html>
''';
  final apiSearchFixture = jsonEncode({
    'data': [
      {'name': 'API result', 'id': 'api-id'},
    ],
  });
  final apiChapterFixture = jsonEncode({
    'data': {
      'roads': [
        {
          'name': 'API road',
          'episodes': [
            {'name': 'Episode 1', 'url': '/api-play/1'},
          ],
        },
      ],
    },
  });

  for (final searchMode in [RuleMode.xpath, RuleMode.api]) {
    for (final chapterMode in [RuleMode.xpath, RuleMode.api]) {
      test('supports $searchMode search with $chapterMode chapters', () async {
        final executor = _FakeExecutor([
          searchMode == RuleMode.api ? apiSearchFixture : xpathResponse,
          chapterMode == RuleMode.api ? apiChapterFixture : xpathResponse,
        ]);
        final engine = RuleEngine(
          requestExecutor: executor,
          logFailures: false,
        );
        final config = _config(
          searchMode: searchMode,
          chapterMode: chapterMode,
        );

        final search = await engine.search(config, 'test keyword');
        final chapters = await engine.queryChapters(
          config,
          search.response.data.first.src,
        );

        expect(search.rawResponse, isNotEmpty);
        expect(search.matchedFragments, isNotEmpty);
        expect(search.diagnostics, isEmpty);
        expect(chapters.rawResponse, isNotEmpty);
        expect(chapters.matchedFragments, isNotEmpty);
        expect(chapters.diagnostics, isEmpty);
        expect(chapters.roads, isNotEmpty);
        expect(executor.requests, hasLength(2));
      });
    }
  }

  test('API search never turns a non-JSON captcha page into captcha flow',
      () async {
    final engine = RuleEngine(
      requestExecutor: _FakeExecutor(['<html>captcha</html>']),
      logFailures: false,
    );

    await expectLater(
      engine.search(
        _config(
          searchMode: RuleMode.api,
          chapterMode: RuleMode.xpath,
          antiCrawler: _antiCrawler(),
        ),
        'keyword',
      ),
      throwsA(
        isA<SearchErrorException>()
            .having((error) => error.kind, 'kind', RuleFailureKind.parse),
      ),
    );
  });

  test('maps an empty relative search XPath to a typed parse error', () async {
    final engine = RuleEngine(
      requestExecutor: _FakeExecutor([xpathResponse]),
      logFailures: false,
    );

    await expectLater(
      engine.search(
        _config(
          searchMode: RuleMode.xpath,
          chapterMode: RuleMode.xpath,
          searchName: '',
        ),
        'keyword',
      ),
      throwsA(
        isA<SearchErrorException>()
            .having((error) => error.kind, 'kind', RuleFailureKind.parse)
            .having(
              (error) => error.cause,
              'cause',
              isA<XPathRuleFormatException>()
                  .having(
                    (error) => error.kind,
                    'kind',
                    XPathRuleFormatKind.invalidSelector,
                  )
                  .having(
                    (error) => error.field,
                    'field',
                    XPathRuleField.searchName,
                  ),
            ),
      ),
    );
  });

  test('maps an empty chapter XPath to a typed parse error', () async {
    final engine = RuleEngine(
      requestExecutor: _FakeExecutor([xpathResponse]),
      logFailures: false,
    );

    await expectLater(
      engine.queryChapters(
        _config(
          searchMode: RuleMode.xpath,
          chapterMode: RuleMode.xpath,
          chapterResult: '',
        ),
        '/video/1',
      ),
      throwsA(
        isA<ChapterErrorException>()
            .having((error) => error.kind, 'kind', RuleFailureKind.parse)
            .having(
              (error) => error.cause,
              'cause',
              isA<XPathRuleFormatException>()
                  .having(
                    (error) => error.kind,
                    'kind',
                    XPathRuleFormatKind.invalidSelector,
                  )
                  .having(
                    (error) => error.field,
                    'field',
                    XPathRuleField.chapterResult,
                  ),
            ),
      ),
    );
  });

  test('chapter parsing never triggers the search captcha flow', () async {
    final engine = RuleEngine(
      requestExecutor: _FakeExecutor(['<html>captcha</html>']),
      logFailures: false,
    );

    await expectLater(
      engine.queryChapters(
        _config(
          searchMode: RuleMode.xpath,
          chapterMode: RuleMode.xpath,
          antiCrawler: _antiCrawler(),
        ),
        '/video/1',
      ),
      throwsA(isA<ChapterErrorException>()),
    );
  });

  test('maps request failures to a typed request reason', () async {
    final engine = RuleEngine(
      requestExecutor: _FakeExecutor(
        const [],
        error: StateError('offline'),
      ),
      logFailures: false,
    );

    await expectLater(
      engine.search(
        _config(searchMode: RuleMode.api, chapterMode: RuleMode.api),
        'keyword',
      ),
      throwsA(
        isA<SearchErrorException>()
            .having((error) => error.kind, 'kind', RuleFailureKind.request),
      ),
    );
  });

  test('propagates cancellation without wrapping it', () async {
    const cancellation = NetworkException(
      type: NetworkExceptionType.cancel,
      message: 'cancelled',
    );
    final engine = RuleEngine(
      requestExecutor: _FakeExecutor(const [], error: cancellation),
      logFailures: false,
    );

    await expectLater(
      engine.search(
        _config(searchMode: RuleMode.api, chapterMode: RuleMode.api),
        'keyword',
        cancelToken: CancelToken(),
      ),
      throwsA(same(cancellation)),
    );
  });
}

class _FakeExecutor implements RuleRequestExecutor {
  _FakeExecutor(List<String> responses, {this.error})
      : _responses = List<String>.of(responses);

  final List<String> _responses;
  final Object? error;
  final List<PreparedRuleRequest> requests = [];

  @override
  Future<String> execute(
    PreparedRuleRequest request,
    RuleExecutionConfig config, {
    CancelToken? cancelToken,
  }) async {
    requests.add(request);
    if (error != null) throw error!;
    return _responses.removeAt(0);
  }
}

RuleExecutionConfig _config({
  required String searchMode,
  required String chapterMode,
  AntiCrawlerConfig? antiCrawler,
  String searchName = '//h2/a',
  String chapterResult = '//a',
}) {
  return RuleExecutionConfig(
    pluginName: 'runtime-test',
    baseUrl: 'https://example.com/',
    usePost: false,
    searchMode: searchMode,
    chapterMode: chapterMode,
    searchUrl: 'https://example.com/search?q=@keyword',
    searchList: '//article[@class="result"]',
    searchName: searchName,
    searchResult: '//h2/a',
    chapterRoads: '//div[@class="road"]',
    chapterResult: chapterResult,
    searchApiConfig: ApiSearchConfig(
      request: ApiRequestConfig(
        url: 'https://example.com/api/search',
        query: {'q': '@keyword'},
      ),
      listPath: r'$.data[*]',
      namePath: r'$.name',
      sourcePath: r'$.id',
    ),
    chapterApiConfig: ApiChapterConfig(
      request: ApiRequestConfig(
        url: 'https://example.com/api/videos/@source',
      ),
      roadsPath: r'$.data.roads[*]',
      roadNamePath: r'$.name',
      episodesPath: r'$.episodes[*]',
      episodeNamePath: r'$.name',
      episodeUrlPath: r'$.url',
    ),
    antiCrawlerConfig: antiCrawler ?? AntiCrawlerConfig.empty(),
  );
}

AntiCrawlerConfig _antiCrawler() {
  return AntiCrawlerConfig(
    enabled: true,
    captchaType: CaptchaType.imageCaptcha,
    captchaImage: '',
    captchaInput: '',
    captchaButton: '',
    captchaDetectType: CaptchaDetectType.text,
    captchaDetectValue: 'captcha',
  );
}
