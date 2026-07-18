import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:kazumi/modules/bangumi/bangumi_item.dart';
import 'package:kazumi/modules/bangumi/bangumi_tag.dart';
import 'package:kazumi/modules/history/history_module.dart';
import 'package:kazumi/repositories/history_repository.dart';
import 'package:kazumi/services/storage/history_storage_coordinator.dart';

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
        remoteSyncScheduler: _noopRemoteSync,
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
        remoteSyncScheduler: _noopRemoteSync,
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
        historiesBox: historiesBox,
        privateModeReader: () => privateMode,
        progressSyncAppender: _noopHistorySync,
        deleteSyncAppender: _noopDeleteSync,
        clearSyncAppender: _noopClearSync,
        remoteSyncScheduler: _noopRemoteSync,
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
        historiesBox: historiesBox,
        privateModeReader: () => privateMode,
        progressSyncAppender: _noopHistorySync,
        deleteSyncAppender: _noopDeleteSync,
        clearSyncAppender: _noopClearSync,
        remoteSyncScheduler: _noopRemoteSync,
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

    test('serializes repository writes with snapshot reconciliation', () async {
      final appendStarted = Completer<void>();
      final allowAppendToFinish = Completer<void>();
      final repository = HistoryRepository(
        historiesBox: historiesBox,
        privateModeReader: () => privateMode,
        progressSyncAppender: ({
          required history,
          required episode,
          required road,
          required progressMs,
          required updatedAt,
        }) async {
          appendStarted.complete();
          await allowAppendToFinish.future;
        },
        deleteSyncAppender: _noopDeleteSync,
        clearSyncAppender: _noopClearSync,
        remoteSyncScheduler: _noopRemoteSync,
      );
      final item = _item(4);

      final update = repository.updateHistory(
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
      await appendStarted.future;

      var reconciliationStarted = false;
      final reconciliation = HistoryStorageCoordinator().run(() async {
        reconciliationStarted = true;
      });
      await Future<void>.delayed(Duration.zero);
      expect(reconciliationStarted, isFalse);

      allowAppendToFinish.complete();
      await update;
      await reconciliation;
      expect(reconciliationStarted, isTrue);
    });

    test('schedules remote sync only after a recordable history write',
        () async {
      var scheduledSyncs = 0;
      final repository = HistoryRepository(
        historiesBox: historiesBox,
        privateModeReader: () => privateMode,
        progressSyncAppender: _noopHistorySync,
        deleteSyncAppender: _noopDeleteSync,
        clearSyncAppender: _noopClearSync,
        remoteSyncScheduler: () => scheduledSyncs += 1,
      );
      final identity = PlaybackHistoryIdentity.online(
        bangumiItem: _item(6),
        pluginName: 'plugin',
        episodeNumber: 1,
        episodeTitle: 'EP1',
        road: 0,
        onlineBangumiSrc: 'https://example.com/source',
        episodePageUrl: '/online/1',
      );

      await repository.updateHistory(
        identity: identity,
        progress: const Duration(seconds: 10),
      );
      expect(scheduledSyncs, 1);

      privateMode = true;
      await repository.updateHistory(
        identity: identity,
        progress: const Duration(seconds: 20),
      );
      expect(scheduledSyncs, 1);
    });
  });
}

Future<void> _noopHistorySync({
  required History history,
  required int episode,
  required int road,
  required int progressMs,
  required int updatedAt,
}) async {}

Future<void> _noopDeleteSync(History history) async {}

Future<void> _noopClearSync() async {}

void _noopRemoteSync() {}

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
