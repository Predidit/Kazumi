import 'package:flutter_test/flutter_test.dart';
import 'package:kazumi/modules/danmaku/danmaku_episode_response.dart';

/// A successful `/api/v2/bangumi/bgmtv/{id}` payload.
Map<String, dynamic> _successPayload() => {
      'bangumi': {
        'animeId': 12345,
        'animeTitle': 'テスト',
        'type': 'tvseries',
        'episodes': [
          {'episodeId': 179470001, 'episodeTitle': '第1话', 'episodeNumber': 1},
          {'episodeId': 179470002, 'episodeTitle': '第2话', 'episodeNumber': 2},
        ],
      },
      'errorCode': 0,
      'success': true,
      'errorMessage': '',
    };

/// What the backend answers when the shared credentials are rate limited.
/// There is no `bangumi` key at all -- this is the shape that used to reach
/// `json['bangumi']['episodes']` and blow up with a null error.
Map<String, dynamic> _rateLimitedPayload() => {
      'errorCode': 429,
      'success': false,
      'errorMessage': '请求过于频繁，请稍后再试',
    };

void main() {
  group('DanmakuEpisodeResponse.fromJson', () {
    test('parses a successful payload', () {
      final response = DanmakuEpisodeResponse.fromJson(_successPayload());

      expect(response.success, isTrue);
      expect(response.errorCode, 0);
      expect(response.bangumiId, 12345);
      expect(response.episodes, hasLength(2));
      expect(response.episodes.first.episodeId, 179470001);
      expect(response.episodes.first.episodeTitle, '第1话');
    });

    test('surfaces the backend error instead of a null error', () {
      expect(
        () => DanmakuEpisodeResponse.fromJson(_rateLimitedPayload()),
        throwsA(
          isA<DanmakuApiException>()
              .having((e) => e.errorCode, 'errorCode', 429)
              .having((e) => e.errorMessage, 'errorMessage', '请求过于频繁，请稍后再试'),
        ),
      );
    });

    test('reports the error through toString so it reaches the log', () {
      const exception = DanmakuApiException(
        errorCode: 429,
        errorMessage: '请求过于频繁，请稍后再试',
      );

      expect(exception.toString(), contains('429'));
      expect(exception.toString(), contains('请求过于频繁'));
    });

    test('degrades to an empty episode list when episodes are absent', () {
      final response = DanmakuEpisodeResponse.fromJson({
        'bangumi': {'animeId': 1},
        'errorCode': 0,
        'success': true,
        'errorMessage': '',
      });

      expect(response.episodes, isEmpty);
      expect(response.bangumiId, 1);
    });

    test('skips malformed episode entries rather than failing the whole list',
        () {
      final response = DanmakuEpisodeResponse.fromJson({
        'bangumi': {
          'animeId': 1,
          'episodes': [
            {'episodeId': 2, 'episodeTitle': 'ok'},
            'not-an-object',
            {'episodeTitle': 'missing id'},
          ],
        },
        'errorCode': 0,
        'success': true,
        'errorMessage': '',
      });

      expect(response.episodes, hasLength(2));
      expect(response.episodes.first.episodeId, 2);
      expect(response.episodes.last.episodeId, 0);
      expect(response.episodes.last.episodeTitle, 'missing id');
    });
  });

  group('DanmakuEpisodeResponse.toJson', () {
    test('round-trips through fromJson', () {
      final original = DanmakuEpisodeResponse.fromJson(_successPayload());
      final restored = DanmakuEpisodeResponse.fromJson(original.toJson());

      expect(restored.bangumiId, original.bangumiId);
      expect(restored.errorCode, original.errorCode);
      expect(restored.success, original.success);
      expect(restored.episodes, hasLength(original.episodes.length));
      expect(restored.episodes.first.episodeId, original.episodes.first.episodeId);
      expect(
        restored.episodes.first.episodeTitle,
        original.episodes.first.episodeTitle,
      );
    });
  });
}
