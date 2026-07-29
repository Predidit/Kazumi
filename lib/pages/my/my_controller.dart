import 'dart:async';

import 'package:flutter/foundation.dart' show listEquals;
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/modules/my/recent_watch_item.dart';
import 'package:kazumi/modules/my/watch_stats.dart';
import 'package:kazumi/repositories/collect_crud_repository.dart';
import 'package:kazumi/repositories/download_repository.dart';
import 'package:kazumi/repositories/history_repository.dart';
import 'package:kazumi/services/logging/logger.dart';
import 'package:mobx/mobx.dart';
import 'package:kazumi/services/storage/storage.dart';
import 'package:kazumi/services/update/auto_updater.dart';

part 'my_controller.g.dart';

class MyController = _MyController with _$MyController;

abstract class _MyController with Store {
  _MyController(
    this._historyRepository,
    this._collectCrudRepository,
    this._downloadRepository,
  );

  final IHistoryRepository _historyRepository;
  final ICollectCrudRepository _collectCrudRepository;
  final IDownloadRepository _downloadRepository;

  @observable
  WatchStats watchStats = const WatchStats();

  final ObservableList<RecentWatchItem> recentWatches =
      ObservableList<RecentWatchItem>();

  static const int _recentWatchLimit = 6;
  static const Duration _refreshDebounce = Duration(milliseconds: 300);

  int _viewerCount = 0;
  final List<StreamSubscription<void>> _subscriptions = [];
  Timer? _refreshDebounceTimer;

  /// Follows every source the stats are derived from while a viewer is on
  /// screen, and derives once more to catch up on what changed while there was
  /// none. The count survives a route swap that attaches the next page before
  /// detaching the last.
  void attach() {
    _viewerCount++;
    if (_subscriptions.isEmpty) {
      for (final changes in [
        _historyRepository.changes,
        _collectCrudRepository.changes,
        _downloadRepository.changes,
      ]) {
        _subscriptions.add(changes.listen((_) => _scheduleRefresh()));
      }
    }
    _refresh();
  }

  void detach() {
    if (--_viewerCount > 0) {
      return;
    }
    _refreshDebounceTimer?.cancel();
    _refreshDebounceTimer = null;
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    _subscriptions.clear();
  }

  void _scheduleRefresh() {
    // Playback rewrites history every second and a sync restore rewrites
    // collectibles one by one; coalesce those into one pass.
    _refreshDebounceTimer?.cancel();
    _refreshDebounceTimer = Timer(_refreshDebounce, _refresh);
  }

  @action
  void _refresh() {
    final histories = _historyRepository.getAllHistories();
    watchStats = WatchStats.from(
      histories: histories,
      collectibles: _collectCrudRepository.getAllCollectibles(),
      downloadRecords: _downloadRepository.getAllRecords(),
    );
    // getAllHistories is already sorted by most recent watch time.
    final recents = histories
        .take(_recentWatchLimit)
        .map(RecentWatchItem.from)
        .toList(growable: false);
    if (!listEquals(recents, recentWatches)) {
      recentWatches
        ..clear()
        ..addAll(recents);
    }
  }

  @observable
  ObservableList<String> shieldList = ObservableList.of([]);

  bool isDanmakuBlocked(String? danmaku) {
    if (danmaku == null || danmaku.isEmpty) return false;
    for (String item in shieldList) {
      if (item.isEmpty) continue;
      if (item.startsWith('/') && item.endsWith('/')) {
        if (item.length <= 2) continue;
        String pattern = item.substring(1, item.length - 1);
        try {
          if (RegExp(pattern).hasMatch(danmaku)) return true;
        } catch (_) {
          KazumiLogger()
              .e('Danmaku: invalid danmaku shield regex pattern: $pattern');
          continue;
        }
      } else {
        if (danmaku.contains(item)) return true;
      }
    }
    return false;
  }

  void loadShieldList() {
    shieldList.clear();
    shieldList.addAll(GStorage.shieldList.values.toList());
  }

  void addShieldList(String item) {
    if (item.isEmpty) {
      KazumiDialog.showToast(message: '请输入关键词');
      return;
    }
    if (item.length > 64) {
      KazumiDialog.showToast(message: '关键词过长');
      return;
    }
    if (shieldList.contains(item)) {
      KazumiDialog.showToast(message: '已存在该关键词');
      return;
    }
    shieldList.add(item);
    GStorage.shieldList.put(item, item);
    GStorage.shieldList.flush();
  }

  void removeShieldList(String item) {
    shieldList.remove(item);
    GStorage.shieldList.delete(item);
    GStorage.shieldList.flush();
  }

  Future<bool> checkUpdate({String type = 'manual'}) async {
    try {
      final autoUpdater = AutoUpdater();

      if (type == 'manual') {
        await autoUpdater.manualCheckForUpdates();
      } else {
        await autoUpdater.autoCheckForUpdates();
      }

      return true;
    } catch (err) {
      KazumiLogger().e('Update: check update failed', error: err);
      if (type == 'manual') {
        KazumiDialog.showToast(message: '检查更新失败，请稍后重试');
      }
      return false;
    }
  }
}
