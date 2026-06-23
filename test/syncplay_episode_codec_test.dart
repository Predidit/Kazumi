import 'package:flutter_test/flutter_test.dart';
import 'package:kazumi/pages/player/controller/player_models.dart';

void main() {
  group('SyncPlayEpisodeCodec', () {
    test('encodes and decodes v2 episode identity', () {
      const identity = SyncPlayEpisodeIdentity(
        bangumiId: 123,
        roadIndex: 2,
        listIndex: 1,
        episodeNumber: 13,
      );

      final encoded = SyncPlayEpisodeCodec.encode(identity);
      final decoded = SyncPlayEpisodeCodec.decode(encoded);

      expect(decoded, isNotNull);
      expect(decoded!.bangumiId, 123);
      expect(decoded.roadIndex, 2);
      expect(decoded.listIndex, 1);
      expect(decoded.episodeNumber, 13);
      expect(decoded.isLegacy, isFalse);
    });

    test('decodes legacy file name as list-index identity', () {
      final decoded =
          SyncPlayEpisodeCodec.decode('123[4]', fallbackRoadIndex: 2);

      expect(decoded, isNotNull);
      expect(decoded!.bangumiId, 123);
      expect(decoded.roadIndex, 2);
      expect(decoded.listIndex, 4);
      expect(decoded.episodeNumber, 4);
      expect(decoded.isLegacy, isTrue);
    });

    test('compares legacy target by list index', () {
      final legacy = SyncPlayEpisodeCodec.decode('123[1]');
      const v2 = SyncPlayEpisodeIdentity(
        bangumiId: 123,
        roadIndex: 2,
        listIndex: 1,
        episodeNumber: 13,
      );

      expect(legacy, isNotNull);
      expect(legacy!.isSameSyncPlayTarget(v2), isTrue);
    });

    test('returns null for non kazumi and invalid payloads', () {
      expect(SyncPlayEpisodeCodec.decode('movie.mkv'), isNull);
      expect(SyncPlayEpisodeCodec.decode('kazumi:v2:{bad json'), isNull);
      expect(
        SyncPlayEpisodeCodec.decode(
            'kazumi:v2:{"bangumiId":123,"listIndex":1}'),
        isNull,
      );
    });
  });
}
