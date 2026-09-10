import 'dart:async';

import 'package:kazumi/modules/bangumi/bangumi_item.dart';
import 'package:kazumi/modules/history/history_module.dart';
import 'package:kazumi/repositories/history_repository.dart';
import 'package:mobx/mobx.dart';

part 'history_controller.g.dart';

class HistoryController = _HistoryController with _$HistoryController;

abstract class _HistoryController with Store {
  _HistoryController(this._historyRepository) {
    _reload();
    _subscription = _historyRepository.changes.listen((_) => _reload());
  }

  final IHistoryRepository _historyRepository;

  late final StreamSubscription<void> _subscription;

  @readonly
  List<History> _histories = const [];

  void _reload() {
    _histories = List.unmodifiable(_historyRepository.getAllHistories());
  }

  void dispose() => _subscription.cancel();

  Future<void> updateHistory(
    PlaybackHistoryIdentity identity,
    Duration progress, {
    Duration duration = Duration.zero,
  }) async {
    await _historyRepository.updateHistory(
      identity: identity,
      progress: progress,
      duration: duration,
    );
  }

  Progress? lastWatching(
    BangumiItem bangumiItem,
    String adapterName, {
    String entryKind = HistoryEntryKind.online,
  }) {
    return _historyRepository.getLastWatchingProgress(
      bangumiItem,
      adapterName,
      entryKind: entryKind,
    );
  }

  Progress? findProgress(
    BangumiItem bangumiItem,
    String adapterName,
    int episode, {
    String entryKind = HistoryEntryKind.online,
  }) {
    return _historyRepository.findProgress(
      bangumiItem,
      adapterName,
      episode,
      entryKind: entryKind,
    );
  }

  Future<void> deleteHistory(History history) async {
    await _historyRepository.deleteHistory(history);
  }

  Future<void> clearAll() async {
    await _historyRepository.clearAllHistories();
  }
}
