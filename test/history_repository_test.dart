import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:kazumi/modules/bangumi/bangumi_item.dart';
import 'package:kazumi/modules/bangumi/bangumi_tag.dart';
import 'package:kazumi/modules/history/history_module.dart';
import 'package:kazumi/modules/history/history_sync.dart';
import 'package:kazumi/repositories/history_repository.dart';
import 'package:kazumi/services/storage/history_storage.dart';

void main() {
  late Directory tempDir;
  late Box<History> historiesBox;
  late Box<dynamic> journal;
  late HistoryStorage storage;
  late bool privateMode;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('kazumi_history_test_');
    Hive.init(tempDir.path);
    _registerAdapters();
    historiesBox = await Hive.openBox<History>('histories');
    journal = await Hive.openBox<dynamic>('journal');
  });

  setUp(() async {
    privateMode = false;
    await historiesBox.clear();
    await journal.clear();
    storage = HistoryStorage(historiesBox, journal, deviceId: 'test');
    await storage.initialize();
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
        storage: storage,
        privateModeReader: () => privateMode,
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
        storage: storage,
        privateModeReader: () => privateMode,
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
      expect(history.progresses[2]!.progress.inSeconds, 30);
    });

    test('does not record history when private mode is enabled', () async {
      privateMode = true;
      final repository = HistoryRepository(
        storage: storage,
        privateModeReader: () => privateMode,
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

    test('stores zero progress when position is near the end of the video',
        () async {
      final repository = HistoryRepository(
        storage: storage,
        privateModeReader: () => privateMode,
      );
      final item = _item(5);
      final identity = PlaybackHistoryIdentity.online(
        bangumiItem: item,
        pluginName: 'plugin',
        episodeNumber: 1,
        episodeTitle: 'EP1',
        road: 0,
        onlineBangumiSrc: 'https://example.com/source',
        episodePageUrl: '/online/1',
      );

      await repository.updateHistory(
        identity: identity,
        progress: const Duration(minutes: 23, seconds: 57),
        duration: const Duration(minutes: 24),
      );
      var history = repository.getHistory('plugin', item);
      expect(history!.progresses[1]!.progress, Duration.zero);

      await repository.updateHistory(
        identity: identity,
        progress: const Duration(minutes: 20),
        duration: const Duration(minutes: 24),
      );
      history = repository.getHistory('plugin', item);
      expect(history!.progresses[1]!.progress, const Duration(minutes: 20));

      await repository.updateHistory(
        identity: identity,
        progress: const Duration(minutes: 23, seconds: 57),
      );
      history = repository.getHistory('plugin', item);
      expect(
        history!.progresses[1]!.progress,
        const Duration(minutes: 23, seconds: 57),
      );
    });

    test('serializes outbox export with snapshot reconciliation', () async {
      final repository =
          HistoryRepository(storage: storage, privateModeReader: () => false);
      await repository.clearAllHistories();
      final started = Completer<void>();
      final release = Completer<void>();
      final export = repository.flushSyncEvents((events) async {
        started.complete();
        await release.future;
      });
      await started.future;
      var reconciled = false;
      final reconciliation = repository
          .reconcileSyncSnapshot(HistorySyncSnapshot.empty())
          .then((_) => reconciled = true);
      await Future<void>.delayed(Duration.zero);
      expect(reconciled, isFalse);
      release.complete();
      await export;
      await reconciliation;
      expect(reconciled, isTrue);
    });
  });
}

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
