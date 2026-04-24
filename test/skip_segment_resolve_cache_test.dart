import 'package:flutter_test/flutter_test.dart';
import 'package:kazumi/modules/skip/skip_segment.dart';
import 'package:kazumi/utils/skip_segment_resolve_cache.dart';

void main() {
  group('SkipSegmentResolveCache', () {
    test('stores and clears resolved segments by episode', () {
      final cache = SkipSegmentResolveCache();
      final openingKey = const SkipSegmentResolveCacheKey(
        bangumiId: 1,
        pluginName: 'test',
        episode: 2,
        type: SkipSegmentType.opening,
      );
      final endingKey = const SkipSegmentResolveCacheKey(
        bangumiId: 1,
        pluginName: 'test',
        episode: 2,
        type: SkipSegmentType.ending,
      );
      const segment = ResolvedSkipSegment(
        type: SkipSegmentType.opening,
        start: Duration(seconds: 30),
        end: Duration(seconds: 120),
        score: 0.9,
        confidence: 0.95,
        sourceEpisode: 1,
      );

      cache.put(openingKey, segment);
      cache.put(
        endingKey,
        const ResolvedSkipSegment(
          type: SkipSegmentType.ending,
          start: Duration(minutes: 21),
          end: Duration(minutes: 22, seconds: 30),
          score: 0.9,
          confidence: 0.95,
          sourceEpisode: 1,
        ),
      );

      expect(cache.get(openingKey), segment);
      expect(cache.get(endingKey), isNotNull);

      cache.clearEpisode(
        bangumiId: 1,
        pluginName: 'test',
        episode: 2,
      );

      expect(cache.get(openingKey), isNull);
      expect(cache.get(endingKey), isNull);
    });
  });
}
