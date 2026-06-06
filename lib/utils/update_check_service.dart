import 'package:hive_ce/hive.dart';
import 'package:kazumi/modules/bangumi/episode_item.dart';
import 'package:kazumi/modules/collect/collect_module.dart';
import 'package:kazumi/modules/history/history_module.dart';
import 'package:kazumi/repositories/collect_crud_repository.dart';
import 'package:kazumi/request/apis/bangumi_api.dart';
import 'package:kazumi/services/logging/logger.dart';
import 'package:kazumi/services/storage/storage.dart';
import 'package:flutter_modular/flutter_modular.dart';

class UpdateCheckService {
  CollectCrudRepository? _crudRepo;

  CollectCrudRepository get _crud =>
      _crudRepo ??= Modular.get<CollectCrudRepository>();

  Future<Set<int>> checkUpdates(
      List<CollectedBangumi> collectibles) async {
    final Set<int> bangumiIdsWithUpdate = {};
    final Box historiesBox = GStorage.histories;

    for (final collectible in collectibles) {
      if (collectible.type != 1) continue;

      final int bangumiId = collectible.bangumiItem.id;

      if (collectible.eps == 0) {
        await _fetchAndStoreEps(collectible);
      }

      if (collectible.eps > 0) {
        final int lastWatched = _getLastWatchedEpisode(
            historiesBox, bangumiId);
        if (lastWatched < collectible.eps) {
          bangumiIdsWithUpdate.add(bangumiId);
        }
      }
    }

    return bangumiIdsWithUpdate;
  }

  Future<void> _fetchAndStoreEps(CollectedBangumi collectible) async {
    try {
      final List<EpisodeInfo> episodes =
          await BangumiApi.getBangumiEpisodesByID(
                  collectible.bangumiItem.id)
              .timeout(const Duration(seconds: 15));
      final int eps = episodes.where((e) => e.type == 0).length;
      if (eps > 0) {
        collectible.eps = eps;
        await _crud.updateCollectibleEps(
            collectible.bangumiItem.id, eps);
      }
    } catch (e) {
      KazumiLogger().w(
        'UpdateCheck: failed to fetch eps for ${collectible.bangumiItem.id}',
        error: e,
      );
    }
  }

  int _getLastWatchedEpisode(Box historiesBox, int bangumiId) {
    int maxEpisode = 0;
    try {
      for (final history in historiesBox.values.cast<History>()) {
        if (history.bangumiItem.id == bangumiId &&
            history.lastWatchEpisode > maxEpisode) {
          maxEpisode = history.lastWatchEpisode;
        }
      }
    } catch (e) {
      KazumiLogger().w(
        'UpdateCheck: failed to get last watched for $bangumiId',
        error: e,
      );
    }
    return maxEpisode;
  }
}
