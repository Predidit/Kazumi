import 'package:flutter_test/flutter_test.dart';
import 'package:kazumi/modules/download/download_module.dart';
import 'package:kazumi/repositories/download_repository.dart';

void main() {
  group('DownloadEpisodeMatcher', () {
    test('prefers episodePageUrl over episodeNumber', () {
      final record = _record({
        1: _episode(1, '第1话', '/old/1'),
        2: _episode(2, '第2话', '/new/2'),
      });

      final match = DownloadEpisodeMatcher.find(
        record,
        episodeNumber: 1,
        episodePageUrl: '/new/2',
        episodeName: '第1话',
      );

      expect(match?.episodeNumber, 2);
      expect(match?.source, DownloadEpisodeMatchSource.episodePageUrl);
    });

    test('falls back to episodeNumber when url is missing from old records',
        () {
      final record = _record({
        13: _episode(13, '第13话', ''),
      });

      final match = DownloadEpisodeMatcher.find(
        record,
        episodeNumber: 13,
        episodePageUrl: '/episode/13',
        episodeName: '第13话',
      );

      expect(match?.episodeNumber, 13);
      expect(match?.source, DownloadEpisodeMatchSource.episodeNumber);
    });

    test('falls back to unique episodeName when episodeNumber is unreliable',
        () {
      final record = _record({
        1: _episode(13, '第13话', ''),
        2: _episode(14, '第14话', ''),
      });

      final match = DownloadEpisodeMatcher.find(
        record,
        episodeNumber: 13,
        episodePageUrl: '',
        episodeName: '第13话',
      );

      expect(match?.episodeNumber, 1);
      expect(match?.source, DownloadEpisodeMatchSource.episodeName);
    });

    test('does not fall back when episodeName matches multiple episodes', () {
      final record = _record({
        1: _episode(1, 'OVA', ''),
        2: _episode(2, 'OVA', ''),
      });

      final match = DownloadEpisodeMatcher.find(
        record,
        episodeNumber: 99,
        episodePageUrl: '',
        episodeName: 'OVA',
      );

      expect(match, isNull);
    });

    test('fills only empty episodePageUrl values', () {
      final oldRecord = _record({
        1: _episode(1, '第1话', ''),
      });
      final oldMatch = DownloadEpisodeMatcher.find(
        oldRecord,
        episodeNumber: 1,
        episodePageUrl: '/episode/1',
        episodeName: '第1话',
      );

      expect(oldMatch, isNotNull);
      expect(
          DownloadEpisodeMatcher.canFillEpisodePageUrl(
            oldMatch!,
            '/episode/1',
          ),
          isTrue);

      final newRecord = _record({
        1: _episode(1, '第1话', '/existing/1'),
      });
      final newMatch = DownloadEpisodeMatcher.find(
        newRecord,
        episodeNumber: 1,
        episodePageUrl: '/episode/1',
        episodeName: '第1话',
      );

      expect(newMatch, isNotNull);
      expect(
          DownloadEpisodeMatcher.canFillEpisodePageUrl(
            newMatch!,
            '/episode/1',
          ),
          isFalse);
    });
  });
}

DownloadRecord _record(Map<int, DownloadEpisode> episodes) {
  return DownloadRecord(
    1,
    'bangumi',
    '',
    'plugin',
    episodes,
    DateTime(2026),
  );
}

DownloadEpisode _episode(int episodeNumber, String name, String pageUrl) {
  return DownloadEpisode(
    episodeNumber,
    name,
    0,
    DownloadStatus.completed,
    1.0,
    1,
    1,
    '',
    '',
    '',
    null,
    '',
    0,
    pageUrl,
  );
}
