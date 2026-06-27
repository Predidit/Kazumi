import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:kazumi/modules/bangumi/bangumi_item.dart';
import 'package:kazumi/modules/bangumi/bangumi_tag.dart';
import 'package:kazumi/modules/history/history_module.dart';
import 'package:kazumi/repositories/history_repository.dart';

void main() {
  late Directory tempDir;
  late Box<History> historiesBox;
  late bool privateMode;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('kazumi_history_test_');
    Hive.init(tempDir.path);
    _registerAdapters();
    historiesBox = await Hive.openBox<History>('histories');
  });

  setUp(() async {
    privateMode = false;
    await historiesBox.clear();
  });

  tearDownAll(() async {
    await Hive.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('HistoryRepository source metadata', () {
    test('keeps online source isolated from offline history', () async {
      final repository = HistoryRepository(
        historiesBox: historiesBox,
        privateModeReader: () => privateMode,
        progressSyncAppender: _noopHistorySync,
        deleteSyncAppender: _noopDeleteSync,
        clearSyncAppender: _noopClearSync,
      );
      final item = _item(1);

      await repository.updateHistory(
        identity: PlaybackHistoryIdentity.online(
          bangumiItem: item,
          pluginName: 'plugin',
          episodeNumber: 1,
          episodeTitle: 'EP1',
          road: 0,
          onlineBangumiSrc: 'https://example.com/source',
          episodePageUrl: '/online/1',
        ),
        progress: const Duration(seconds: 10),
      );

      await repository.updateHistory(
        identity: PlaybackHistoryIdentity.offline(
          bangumiItem: item,
          pluginName: 'plugin',
          episodeNumber: 1,
          episodeTitle: 'EP1 local',
          road: 0,
          episodePageUrl: '/offline/1',
        ),
        progress: const Duration(seconds: 20),
      );

      final online = repository.getHistory(
        'plugin',
        item,
        entryKind: HistoryEntryKind.online,
      );
      final offline = repository.getHistory(
        'plugin',
        item,
        entryKind: HistoryEntryKind.offline,
      );

      expect(online, isNotNull);
      expect(offline, isNotNull);
      expect(online!.lastSrc, 'https://example.com/source');
      expect(online.episodePageUrl, '/online/1');
      expect(online.progresses[1]!.progress.inSeconds, 10);
      expect(offline!.lastSrc, isEmpty);
      expect(offline.episodePageUrl, '/offline/1');
      expect(offline.progresses[1]!.progress.inSeconds, 20);
      expect(online.key, History.getKey('plugin', item));
      expect(
        offline.key,
        History.getKey(
          'plugin',
          item,
          entryKind: HistoryEntryKind.offline,
        ),
      );
    });

    test('does not overwrite existing online source with an empty value',
        () async {
      final repository = HistoryRepository(
        historiesBox: historiesBox,
        privateModeReader: () => privateMode,
        progressSyncAppender: _noopHistorySync,
        deleteSyncAppender: _noopDeleteSync,
        clearSyncAppender: _noopClearSync,
      );
      final item = _item(2);

      await repository.updateHistory(
        identity: PlaybackHistoryIdentity.online(
          bangumiItem: item,
          pluginName: 'plugin',
          episodeNumber: 1,
          episodeTitle: 'EP1',
          road: 0,
          onlineBangumiSrc: 'https://example.com/source',
          episodePageUrl: '/online/1',
        ),
        progress: const Duration(seconds: 10),
      );

      await repository.updateHistory(
        identity: PlaybackHistoryIdentity.online(
          bangumiItem: item,
          pluginName: 'plugin',
          episodeNumber: 2,
          episodeTitle: 'EP2',
          road: 1,
          onlineBangumiSrc: '',
          episodePageUrl: '/online/2',
        ),
        progress: const Duration(seconds: 30),
      );

      final history = repository.getHistory(
        'plugin',
        item,
        entryKind: HistoryEntryKind.online,
      );

      expect(history, isNotNull);
      expect(history!.lastSrc, 'https://example.com/source');
      expect(history.lastWatchEpisode, 2);
      expect(history.lastWatchEpisodeName, 'EP2');
      expect(history.episodePageUrl, '/online/2');
      expect(history.progresses[2]!.episodePageUrl, '/online/2');
      expect(history.progresses[2]!.progress.inSeconds, 30);
    });

    test('finds progress by page url before the old episode index', () async {
      final repository = HistoryRepository(
        historiesBox: historiesBox,
        privateModeReader: () => privateMode,
        progressSyncAppender: _noopHistorySync,
        deleteSyncAppender: _noopDeleteSync,
        clearSyncAppender: _noopClearSync,
      );
      final item = _item(4);
      final history = History(
        item,
        2,
        'plugin',
        DateTime.fromMillisecondsSinceEpoch(1000),
        'https://example.com/source',
        'EP2',
        episodePageUrl: '/online/2',
      );
      history.progresses[1] = Progress(
        1,
        0,
        10 * 1000,
        episodePageUrl: '/online/1',
      );
      history.progresses[2] = Progress(
        2,
        0,
        20 * 1000,
        episodePageUrl: '/online/2',
      );
      await historiesBox.put(history.key, history);

      final progress = repository.findProgress(
        item,
        'plugin',
        1,
        episodePageUrl: '/online/2',
      );

      expect(progress, isNotNull);
      expect(progress!.progress.inSeconds, 20);
      expect(progress.episodePageUrl, '/online/2');
    });

    test('falls back to legacy int progress and backfills page url', () async {
      final repository = HistoryRepository(
        historiesBox: historiesBox,
        privateModeReader: () => privateMode,
        progressSyncAppender: _noopHistorySync,
        deleteSyncAppender: _noopDeleteSync,
        clearSyncAppender: _noopClearSync,
      );
      final item = _item(5);
      final history = History(
        item,
        1,
        'plugin',
        DateTime.fromMillisecondsSinceEpoch(1000),
        'https://example.com/source',
        'EP1',
        episodePageUrl: '/online/1',
      );
      history.progresses[1] = Progress(1, 0, 10 * 1000);
      await historiesBox.put(history.key, history);

      final progress = repository.findProgress(
        item,
        'plugin',
        1,
        episodePageUrl: '/online/1',
      );

      expect(progress, isNotNull);
      expect(progress!.progress.inSeconds, 10);
      expect(progress.episodePageUrl, '/online/1');
      expect(historiesBox.get(history.key)!.progresses[1]!.episodePageUrl,
          '/online/1');
    });

    test('does not overwrite an existing different page url bucket', () async {
      final repository = HistoryRepository(
        historiesBox: historiesBox,
        privateModeReader: () => privateMode,
        progressSyncAppender: _noopHistorySync,
        deleteSyncAppender: _noopDeleteSync,
        clearSyncAppender: _noopClearSync,
      );
      final item = _item(6);

      await repository.updateHistory(
        identity: PlaybackHistoryIdentity.online(
          bangumiItem: item,
          pluginName: 'plugin',
          episodeNumber: 1,
          episodeTitle: 'EP1',
          road: 0,
          onlineBangumiSrc: 'https://example.com/source',
          episodePageUrl: '/online/a',
        ),
        progress: const Duration(seconds: 10),
      );
      await repository.updateHistory(
        identity: PlaybackHistoryIdentity.online(
          bangumiItem: item,
          pluginName: 'plugin',
          episodeNumber: 1,
          episodeTitle: 'EP1 new',
          road: 0,
          onlineBangumiSrc: 'https://example.com/source',
          episodePageUrl: '/online/b',
        ),
        progress: const Duration(seconds: 20),
      );

      final history = repository.getHistory('plugin', item)!;
      expect(history.progresses, hasLength(2));
      expect(
        history.progresses.values
            .singleWhere(
              (progress) => progress.episodePageUrl == '/online/a',
            )
            .progress
            .inSeconds,
        10,
      );
      expect(
        history.progresses.values
            .singleWhere(
              (progress) => progress.episodePageUrl == '/online/b',
            )
            .progress
            .inSeconds,
        20,
      );
    });

    test('clears the progress matched by page url', () async {
      final repository = HistoryRepository(
        historiesBox: historiesBox,
        privateModeReader: () => privateMode,
        progressSyncAppender: _noopHistorySync,
        deleteSyncAppender: _noopDeleteSync,
        clearSyncAppender: _noopClearSync,
      );
      final item = _item(7);

      await repository.updateHistory(
        identity: PlaybackHistoryIdentity.online(
          bangumiItem: item,
          pluginName: 'plugin',
          episodeNumber: 1,
          episodeTitle: 'EP1',
          road: 0,
          onlineBangumiSrc: 'https://example.com/source',
          episodePageUrl: '/online/a',
        ),
        progress: const Duration(seconds: 10),
      );
      await repository.updateHistory(
        identity: PlaybackHistoryIdentity.online(
          bangumiItem: item,
          pluginName: 'plugin',
          episodeNumber: 1,
          episodeTitle: 'EP1 new',
          road: 0,
          onlineBangumiSrc: 'https://example.com/source',
          episodePageUrl: '/online/b',
        ),
        progress: const Duration(seconds: 20),
      );

      await repository.clearProgress(
        item,
        'plugin',
        1,
        episodePageUrl: '/online/b',
      );

      final history = repository.getHistory('plugin', item)!;
      expect(
        history.progresses.values
            .singleWhere(
              (progress) => progress.episodePageUrl == '/online/a',
            )
            .progress
            .inSeconds,
        10,
      );
      expect(
        history.progresses.values
            .singleWhere(
              (progress) => progress.episodePageUrl == '/online/b',
            )
            .progress,
        Duration.zero,
      );
    });

    test('empty page url ignores synthetic buckets for other episodes',
        () async {
      final repository = HistoryRepository(
        historiesBox: historiesBox,
        privateModeReader: () => privateMode,
        progressSyncAppender: _noopHistorySync,
        deleteSyncAppender: _noopDeleteSync,
        clearSyncAppender: _noopClearSync,
      );
      final item = _item(8);

      await repository.updateHistory(
        identity: PlaybackHistoryIdentity.online(
          bangumiItem: item,
          pluginName: 'plugin',
          episodeNumber: 1,
          episodeTitle: 'EP1',
          road: 0,
          onlineBangumiSrc: 'https://example.com/source',
          episodePageUrl: '/online/a',
        ),
        progress: const Duration(seconds: 10),
      );
      await repository.updateHistory(
        identity: PlaybackHistoryIdentity.online(
          bangumiItem: item,
          pluginName: 'plugin',
          episodeNumber: 1,
          episodeTitle: 'EP1 alt',
          road: 0,
          onlineBangumiSrc: 'https://example.com/source',
          episodePageUrl: '/online/b',
        ),
        progress: const Duration(seconds: 20),
      );

      expect(repository.findProgress(item, 'plugin', 2), isNull);

      await repository.updateHistory(
        identity: PlaybackHistoryIdentity.online(
          bangumiItem: item,
          pluginName: 'plugin',
          episodeNumber: 2,
          episodeTitle: 'EP2',
          road: 0,
          onlineBangumiSrc: 'https://example.com/source',
          episodePageUrl: '',
        ),
        progress: const Duration(seconds: 30),
      );

      var history = repository.getHistory('plugin', item)!;
      final urlProgress = history.progresses.values.singleWhere(
        (progress) => progress.episodePageUrl == '/online/b',
      );
      final noUrlProgress = repository.findProgress(item, 'plugin', 2);

      expect(urlProgress.episode, 1);
      expect(urlProgress.progress.inSeconds, 20);
      expect(noUrlProgress, isNotNull);
      expect(noUrlProgress!.episode, 2);
      expect(noUrlProgress.episodePageUrl, isEmpty);
      expect(noUrlProgress.progress.inSeconds, 30);

      await repository.clearProgress(item, 'plugin', 2);

      history = repository.getHistory('plugin', item)!;
      expect(
        history.progresses.values
            .singleWhere(
              (progress) => progress.episodePageUrl == '/online/b',
            )
            .progress
            .inSeconds,
        20,
      );
      expect(
          repository.findProgress(item, 'plugin', 2)!.progress, Duration.zero);
    });

    test('backfills synthetic legacy progress when page url appears later',
        () async {
      final repository = HistoryRepository(
        historiesBox: historiesBox,
        privateModeReader: () => privateMode,
        progressSyncAppender: _noopHistorySync,
        deleteSyncAppender: _noopDeleteSync,
        clearSyncAppender: _noopClearSync,
      );
      final item = _item(9);

      await repository.updateHistory(
        identity: PlaybackHistoryIdentity.online(
          bangumiItem: item,
          pluginName: 'plugin',
          episodeNumber: 1,
          episodeTitle: 'EP1',
          road: 0,
          onlineBangumiSrc: 'https://example.com/source',
          episodePageUrl: '/online/a',
        ),
        progress: const Duration(seconds: 10),
      );
      await repository.updateHistory(
        identity: PlaybackHistoryIdentity.online(
          bangumiItem: item,
          pluginName: 'plugin',
          episodeNumber: 1,
          episodeTitle: 'EP1 alt',
          road: 0,
          onlineBangumiSrc: 'https://example.com/source',
          episodePageUrl: '/online/b',
        ),
        progress: const Duration(seconds: 20),
      );
      await repository.updateHistory(
        identity: PlaybackHistoryIdentity.online(
          bangumiItem: item,
          pluginName: 'plugin',
          episodeNumber: 2,
          episodeTitle: 'EP2',
          road: 0,
          onlineBangumiSrc: 'https://example.com/source',
          episodePageUrl: '',
        ),
        progress: const Duration(seconds: 30),
      );

      var history = repository.getHistory('plugin', item)!;
      expect(history.progresses, hasLength(3));
      expect(history.progresses[2]!.episode, 1);
      expect(history.progresses[2]!.episodePageUrl, '/online/b');
      expect(history.progresses[3]!.episode, 2);
      expect(history.progresses[3]!.episodePageUrl, isEmpty);

      final resumed = repository.findProgress(
        item,
        'plugin',
        2,
        episodePageUrl: '/online/2',
      );
      expect(resumed, isNotNull);
      expect(resumed!.episode, 2);
      expect(resumed.progress.inSeconds, 30);
      expect(resumed.episodePageUrl, '/online/2');

      await repository.updateHistory(
        identity: PlaybackHistoryIdentity.online(
          bangumiItem: item,
          pluginName: 'plugin',
          episodeNumber: 2,
          episodeTitle: 'EP2',
          road: 0,
          onlineBangumiSrc: 'https://example.com/source',
          episodePageUrl: '/online/2',
        ),
        progress: const Duration(seconds: 40),
      );

      history = repository.getHistory('plugin', item)!;
      expect(history.progresses, hasLength(3));
      expect(history.progresses[2]!.episode, 1);
      expect(history.progresses[2]!.episodePageUrl, '/online/b');
      expect(history.progresses[3]!.episode, 2);
      expect(history.progresses[3]!.episodePageUrl, '/online/2');
      expect(history.progresses[3]!.progress.inSeconds, 40);
    });

    test(
        'last watching falls back to episode when latest watch has no page url',
        () async {
      final repository = HistoryRepository(
        historiesBox: historiesBox,
        privateModeReader: () => privateMode,
        progressSyncAppender: _noopHistorySync,
        deleteSyncAppender: _noopDeleteSync,
        clearSyncAppender: _noopClearSync,
      );
      final item = _item(10);

      await repository.updateHistory(
        identity: PlaybackHistoryIdentity.online(
          bangumiItem: item,
          pluginName: 'plugin',
          episodeNumber: 1,
          episodeTitle: 'EP1',
          road: 0,
          onlineBangumiSrc: 'https://example.com/source',
          episodePageUrl: '/online/a',
        ),
        progress: const Duration(seconds: 10),
      );
      await repository.updateHistory(
        identity: PlaybackHistoryIdentity.online(
          bangumiItem: item,
          pluginName: 'plugin',
          episodeNumber: 2,
          episodeTitle: 'EP2',
          road: 0,
          onlineBangumiSrc: 'https://example.com/source',
          episodePageUrl: '',
        ),
        progress: const Duration(seconds: 20),
      );

      final history = repository.getHistory('plugin', item)!;
      final progress = repository.getLastWatchingProgress(item, 'plugin');

      expect(history.lastWatchEpisode, 2);
      expect(history.episodePageUrl, isEmpty);
      expect(progress, isNotNull);
      expect(progress!.episode, 2);
      expect(progress.episodePageUrl, isEmpty);
      expect(progress.progress.inSeconds, 20);
    });

    test('does not record history when private mode is enabled', () async {
      privateMode = true;
      final repository = HistoryRepository(
        historiesBox: historiesBox,
        privateModeReader: () => privateMode,
        progressSyncAppender: _noopHistorySync,
        deleteSyncAppender: _noopDeleteSync,
        clearSyncAppender: _noopClearSync,
      );
      final item = _item(3);

      await repository.updateHistory(
        identity: PlaybackHistoryIdentity.online(
          bangumiItem: item,
          pluginName: 'plugin',
          episodeNumber: 1,
          episodeTitle: 'EP1',
          road: 0,
          onlineBangumiSrc: 'https://example.com/source',
          episodePageUrl: '/online/1',
        ),
        progress: const Duration(seconds: 10),
      );

      expect(historiesBox.values, isEmpty);
      expect(repository.getHistory('plugin', item), isNull);
    });
  });

  group('HistoryRepository stableId matching', () {
    HistoryRepository buildRepository() => HistoryRepository(
          historiesBox: historiesBox,
          privateModeReader: () => privateMode,
          progressSyncAppender: _noopHistorySync,
          deleteSyncAppender: _noopDeleteSync,
          clearSyncAppender: _noopClearSync,
        );

    test('reuses the same bucket after a domain change via stableId', () async {
      final repository = buildRepository();
      final item = _item(30);

      await repository.updateHistory(
        identity: PlaybackHistoryIdentity.online(
          bangumiItem: item,
          pluginName: 'plugin',
          episodeNumber: 1,
          episodeTitle: 'EP1',
          road: 0,
          onlineBangumiSrc: 'https://example.com/source',
          episodePageUrl: 'https://old.example.com/play/1',
          stableId: '/play/1',
        ),
        progress: const Duration(seconds: 10),
      );

      // 源站换域名：episodePageUrl 完全不同，但 stableId 不变，应复用同一桶。
      await repository.updateHistory(
        identity: PlaybackHistoryIdentity.online(
          bangumiItem: item,
          pluginName: 'plugin',
          episodeNumber: 1,
          episodeTitle: 'EP1',
          road: 0,
          onlineBangumiSrc: 'https://example.com/source',
          episodePageUrl: 'https://new-mirror.example.org/play/1',
          stableId: '/play/1',
        ),
        progress: const Duration(seconds: 42),
      );

      final history = repository.getHistory('plugin', item)!;
      expect(history.progresses, hasLength(1));
      final progress = history.progresses.values.single;
      expect(progress.progress.inSeconds, 42);
      expect(progress.stableId, '/play/1');
      expect(progress.episodePageUrl, 'https://new-mirror.example.org/play/1');
    });

    test('findProgress matches by stableId ignoring page url drift', () async {
      final repository = buildRepository();
      final item = _item(31);

      await repository.updateHistory(
        identity: PlaybackHistoryIdentity.online(
          bangumiItem: item,
          pluginName: 'plugin',
          episodeNumber: 1,
          episodeTitle: 'EP1',
          road: 0,
          onlineBangumiSrc: 'https://example.com/source',
          episodePageUrl: 'https://old.example.com/play/1',
          stableId: '/play/1',
        ),
        progress: const Duration(seconds: 15),
      );

      final progress = repository.findProgress(
        item,
        'plugin',
        1,
        episodePageUrl: 'https://new.example.com/play/1',
        stableId: '/play/1',
      );

      expect(progress, isNotNull);
      expect(progress!.progress.inSeconds, 15);
    });

    test('backfills stableId onto a legacy progress matched by page url',
        () async {
      final repository = buildRepository();
      final item = _item(32);

      final history = History(
        item,
        1,
        'plugin',
        DateTime.fromMillisecondsSinceEpoch(1000),
        'https://example.com/source',
        'EP1',
        episodePageUrl: 'https://old.example.com/play/1',
      );
      history.progresses[1] = Progress(
        1,
        0,
        10 * 1000,
        episodePageUrl: 'https://old.example.com/play/1',
      );
      await historiesBox.put(history.key, history);

      final progress = repository.findProgress(
        item,
        'plugin',
        1,
        episodePageUrl: 'https://old.example.com/play/1',
        stableId: '/play/1',
      );

      expect(progress, isNotNull);
      expect(progress!.progress.inSeconds, 10);
      expect(
        historiesBox.get(history.key)!.progresses[1]!.stableId,
        '/play/1',
      );
    });
  });

  group('HistoryRepository migrateProgressPageUrls', () {
    HistoryRepository buildRepository() => HistoryRepository(
          historiesBox: historiesBox,
          privateModeReader: () => privateMode,
          progressSyncAppender: _noopHistorySync,
          deleteSyncAppender: _noopDeleteSync,
          clearSyncAppender: _noopClearSync,
        );

    test('rewrites stale page url in place and reuses bucket on next update',
        () async {
      final repository = buildRepository();
      final item = _item(20);

      await repository.updateHistory(
        identity: PlaybackHistoryIdentity.online(
          bangumiItem: item,
          pluginName: 'plugin',
          episodeNumber: 1,
          episodeTitle: 'EP1',
          road: 0,
          onlineBangumiSrc: 'https://example.com/source',
          episodePageUrl: 'https://old.example.com/play/1',
        ),
        progress: const Duration(seconds: 10),
      );

      repository.migrateProgressPageUrls(
        adapterName: 'plugin',
        bangumiItem: item,
        resolveCurrentPageUrl: (road, episode) =>
            road == 0 && episode == 1 ? 'https://new.example.com/play/1' : '',
      );

      var history = repository.getHistory('plugin', item)!;
      expect(history.progresses, hasLength(1));
      expect(
        history.progresses[1]!.episodePageUrl,
        'https://new.example.com/play/1',
      );

      // 后续以新 URL 写入应复用既有桶，而非新建重复条目。
      await repository.updateHistory(
        identity: PlaybackHistoryIdentity.online(
          bangumiItem: item,
          pluginName: 'plugin',
          episodeNumber: 1,
          episodeTitle: 'EP1',
          road: 0,
          onlineBangumiSrc: 'https://example.com/source',
          episodePageUrl: 'https://new.example.com/play/1',
        ),
        progress: const Duration(seconds: 30),
      );

      history = repository.getHistory('plugin', item)!;
      expect(history.progresses, hasLength(1));
      expect(history.progresses[1]!.progress.inSeconds, 30);
      expect(
        history.progresses[1]!.episodePageUrl,
        'https://new.example.com/play/1',
      );
    });

    test(
        'migrates top-level history.episodePageUrl and keeps lastWatching match',
        () async {
      final repository = buildRepository();
      final item = _item(21);

      await repository.updateHistory(
        identity: PlaybackHistoryIdentity.online(
          bangumiItem: item,
          pluginName: 'plugin',
          episodeNumber: 1,
          episodeTitle: 'EP1',
          road: 0,
          onlineBangumiSrc: 'https://example.com/source',
          episodePageUrl: 'https://old.example.com/play/1',
        ),
        progress: const Duration(seconds: 10),
      );

      repository.migrateProgressPageUrls(
        adapterName: 'plugin',
        bangumiItem: item,
        resolveCurrentPageUrl: (road, episode) =>
            'https://new.example.com/play/$episode',
      );

      final history = repository.getHistory('plugin', item)!;
      expect(history.episodePageUrl, 'https://new.example.com/play/1');

      final resumed = repository.getLastWatchingProgress(item, 'plugin');
      expect(resumed, isNotNull);
      expect(resumed!.episode, 1);
      expect(resumed.episodePageUrl, 'https://new.example.com/play/1');
      expect(resumed.progress.inSeconds, 10);
    });

    test('uses progress road/episode not the bucket key for synthetic buckets',
        () async {
      final repository = buildRepository();
      final item = _item(22);

      // 模拟 bucketForNewProgress 递增产生的 synthetic bucket：
      // map key (3) 不等于 Progress.episode (1)。
      final history = History(
        item,
        1,
        'plugin',
        DateTime.now(),
        'https://example.com/source',
        'EP1',
        entryKind: HistoryEntryKind.online,
        episodePageUrl: 'https://old.example.com/play/1',
      );
      history.progresses[3] = Progress(
        1,
        0,
        10000,
        updatedAtMs: DateTime.now().millisecondsSinceEpoch,
        episodePageUrl: 'https://old.example.com/play/1',
      );
      await historiesBox.put(history.key, history);

      final resolverCalls = <String>[];
      repository.migrateProgressPageUrls(
        adapterName: 'plugin',
        bangumiItem: item,
        resolveCurrentPageUrl: (road, episode) {
          resolverCalls.add('$road:$episode');
          if (road == 0 && episode == 1) {
            return 'https://new.example.com/play/1';
          }
          return '';
        },
      );

      final stored = repository.getHistory('plugin', item)!;
      expect(stored.progresses.containsKey(3), isTrue);
      expect(stored.progresses[3]!.episode, 1);
      expect(
        stored.progresses[3]!.episodePageUrl,
        'https://new.example.com/play/1',
      );
      // resolver 必须使用 Progress 值的 road/episode（1），而非 map key（3）。
      expect(resolverCalls, contains('0:1'));
      expect(resolverCalls, isNot(contains('0:3')));
    });

    test('collapses duplicate buckets keeping the newer progress', () async {
      final repository = buildRepository();
      final item = _item(23);

      // 一个旧 URL 桶 + 一个过往升级已生成的新 URL 桶，迁移后应合并为一个。
      final history = History(
        item,
        1,
        'plugin',
        DateTime.now(),
        'https://example.com/source',
        'EP1',
        entryKind: HistoryEntryKind.online,
        episodePageUrl: 'https://new.example.com/play/1',
      );
      history.progresses[1] = Progress(
        1,
        0,
        30000,
        updatedAtMs: 2000,
        episodePageUrl: 'https://old.example.com/play/1',
      );
      history.progresses[2] = Progress(
        1,
        0,
        20000,
        updatedAtMs: 1000,
        episodePageUrl: 'https://new.example.com/play/1',
      );
      await historiesBox.put(history.key, history);

      repository.migrateProgressPageUrls(
        adapterName: 'plugin',
        bangumiItem: item,
        resolveCurrentPageUrl: (road, episode) =>
            'https://new.example.com/play/1',
      );

      final stored = repository.getHistory('plugin', item)!;
      expect(stored.progresses, hasLength(1));
      final survivor = stored.progresses.values.single;
      expect(survivor.episodePageUrl, 'https://new.example.com/play/1');
      expect(survivor.progress.inSeconds, 30);
    });

    test('leaves entries untouched when resolver or stored url is empty',
        () async {
      final repository = buildRepository();
      final item = _item(24);

      await repository.updateHistory(
        identity: PlaybackHistoryIdentity.online(
          bangumiItem: item,
          pluginName: 'plugin',
          episodeNumber: 1,
          episodeTitle: 'EP1',
          road: 0,
          onlineBangumiSrc: 'https://example.com/source',
          episodePageUrl: 'https://old.example.com/play/1',
        ),
        progress: const Duration(seconds: 10),
      );
      await repository.updateHistory(
        identity: PlaybackHistoryIdentity.online(
          bangumiItem: item,
          pluginName: 'plugin',
          episodeNumber: 2,
          episodeTitle: 'EP2',
          road: 0,
          onlineBangumiSrc: 'https://example.com/source',
          episodePageUrl: '',
        ),
        progress: const Duration(seconds: 20),
      );

      repository.migrateProgressPageUrls(
        adapterName: 'plugin',
        bangumiItem: item,
        resolveCurrentPageUrl: (road, episode) => '',
      );

      final history = repository.getHistory('plugin', item)!;
      expect(
        history.progresses[1]!.episodePageUrl,
        'https://old.example.com/play/1',
      );
      expect(history.progresses[2]!.episodePageUrl, isEmpty);
    });
  });
}

Future<void> _noopHistorySync({
  required History history,
  required int episode,
  required int road,
  required int progressMs,
  required int updatedAt,
  required String episodePageUrl,
}) async {}

Future<void> _noopDeleteSync(History history) async {}

Future<void> _noopClearSync() async {}

void _registerAdapters() {
  if (!Hive.isAdapterRegistered(1)) {
    Hive.registerAdapter(HistoryAdapter());
  }
  if (!Hive.isAdapterRegistered(2)) {
    Hive.registerAdapter(ProgressAdapter());
  }
  if (!Hive.isAdapterRegistered(3)) {
    Hive.registerAdapter(BangumiItemAdapter());
  }
  if (!Hive.isAdapterRegistered(6)) {
    Hive.registerAdapter(BangumiTagAdapter());
  }
}

BangumiItem _item(int id) {
  return BangumiItem(
    id: id,
    type: 2,
    name: 'subject $id',
    nameCn: '条目 $id',
    summary: '',
    airDate: '2026-01-01',
    airWeekday: 4,
    rank: 0,
    images: const {
      'large': '',
      'common': '',
      'medium': '',
      'small': '',
      'grid': '',
    },
    tags: const <BangumiTag>[],
    alias: const [],
    ratingScore: 0,
    votes: 0,
    votesCount: const [],
    info: '',
  );
}
