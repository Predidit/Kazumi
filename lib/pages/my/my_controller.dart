import 'dart:async';

import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/modules/my/watch_stats.dart';
import 'package:kazumi/repositories/download_repository.dart';
import 'package:kazumi/repositories/history_repository.dart';
import 'package:kazumi/services/logging/logger.dart';
import 'package:kazumi/services/storage/storage.dart';
import 'package:kazumi/services/update/auto_updater.dart';
import 'package:mobx/mobx.dart';

part 'my_controller.g.dart';

class MyController = _MyController with _$MyController;

abstract class _MyController with Store {
  _MyController(
    this._historyRepository,
    this._downloadRepository,
  );

  final IHistoryRepository _historyRepository;
  final IDownloadRepository _downloadRepository;

  @observable
  WatchStats watchStats = const WatchStats();

  static const Duration _refreshDebounce = Duration(milliseconds: 300);

  int _viewerCount = 0;
  final List<StreamSubscription<void>> _subscriptions = [];
  Timer? _refreshDebounceTimer;

  // Route swaps can briefly attach two page instances.
  void attach() {
    _viewerCount++;
    if (_subscriptions.isEmpty) {
      for (final changes in [
        _historyRepository.changes,
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
    // Coalesce frequent playback history writes.
    _refreshDebounceTimer?.cancel();
    _refreshDebounceTimer = Timer(_refreshDebounce, _refresh);
  }

  @action
  void _refresh() {
    watchStats = WatchStats.from(
      histories: _historyRepository.getAllHistories(),
      downloadRecords: _downloadRepository.getAllRecords(),
    );
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
