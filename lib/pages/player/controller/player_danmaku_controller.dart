// ignore_for_file: library_private_types_in_public_api

import 'package:canvas_danmaku/canvas_danmaku.dart' as canvas;
import 'package:flutter_modular/flutter_modular.dart';
import 'package:hive_ce/hive.dart';
import 'package:kazumi/modules/danmaku/danmaku_module.dart';
import 'package:kazumi/pages/player/controller/player_models.dart';
import 'package:kazumi/pages/download/download_controller.dart';
import 'package:kazumi/request/apis/danmaku_api.dart';
import 'package:kazumi/utils/logger.dart';
import 'package:kazumi/utils/storage.dart';
import 'package:kazumi/utils/utils.dart';
import 'package:mobx/mobx.dart';

part 'player_danmaku_controller.g.dart';

class PlayerDanmakuController = _PlayerDanmakuController
    with _$PlayerDanmakuController;

abstract class _PlayerDanmakuController with Store {
  _PlayerDanmakuController({
    required this.setting,
    required this.isLocalPlayback,
  });

  final Box setting;
  final bool Function() isLocalPlayback;

  late canvas.DanmakuController canvasController;

  @observable
  Map<int, List<Danmaku>> danDanmakus = {};
  @observable
  bool danmakuOn = false;
  @observable
  bool danmakuLoading = false;
  DanmakuDestination danmakuDestination = DanmakuDestination.remoteDanmaku;

  // DanDanPlay 弹幕ID
  int bangumiID = 0;

  /// 加载弹幕 (离线模式优先从缓存加载，无缓存时尝试在线获取)
  Future<void> loadDanmaku(
      int bangumiId, String pluginName, int episode) async {
    if (isLocalPlayback()) {
      await _loadCachedDanmaku(bangumiId, pluginName, episode);
    } else {
      await getDanDanmakuByBgmBangumiID(bangumiId, episode);
    }
  }

  Future<void> _loadCachedDanmaku(
      int bangumiId, String pluginName, int episode) async {
    if (danmakuLoading) {
      KazumiLogger()
          .i('PlayerController: danmaku is loading, ignore duplicate request');
      return;
    }

    KazumiLogger().i(
        'PlayerController: attempting to load cached danmaku for episode $episode');
    danmakuLoading = true;
    try {
      danDanmakus.clear();
      final downloadController = Modular.get<DownloadController>();
      final cachedDanmakus = await downloadController.getCachedDanmakus(
        bangumiId,
        pluginName,
        episode,
      );

      if (cachedDanmakus != null && cachedDanmakus.isNotEmpty) {
        addDanmakus(cachedDanmakus);
        KazumiLogger().i(
            'PlayerController: loaded ${cachedDanmakus.length} cached danmakus');
      } else {
        KazumiLogger()
            .i('PlayerController: no cached danmaku, attempting online fetch');
        try {
          bangumiID =
              await DanmakuApi.getDanDanBangumiIDByBgmBangumiID(bangumiId);
          if (bangumiID != 0) {
            var res = await DanmakuApi.getDanDanmaku(bangumiID, episode);
            if (res.isNotEmpty) {
              addDanmakus(res);
              KazumiLogger()
                  .i('PlayerController: fetched ${res.length} danmakus online');
              _saveDanmakuToCache(
                  downloadController, bangumiId, pluginName, episode, res);
            }
          }
        } catch (e) {
          KazumiLogger().w(
              'PlayerController: failed to fetch danmaku online (may be offline)',
              error: e);
        }
      }
    } catch (e) {
      KazumiLogger()
          .w('PlayerController: failed to load cached danmaku', error: e);
    } finally {
      danmakuLoading = false;
    }
  }

  void _saveDanmakuToCache(DownloadController downloadController, int bangumiId,
      String pluginName, int episode, List<Danmaku> danmakus) {
    try {
      downloadController.updateCachedDanmakus(
        bangumiId,
        pluginName,
        episode,
        danmakus,
        bangumiID,
      );
      KazumiLogger()
          .i('PlayerController: saved ${danmakus.length} danmakus to cache');
    } catch (e) {
      KazumiLogger()
          .w('PlayerController: failed to save danmaku to cache', error: e);
    }
  }

  Future<void> getDanDanmakuByBgmBangumiID(
      int bgmBangumiID, int episode) async {
    if (danmakuLoading) {
      KazumiLogger()
          .i('PlayerController: danmaku is loading, ignore duplicate request');
      return;
    }

    KazumiLogger().i(
        'PlayerController: attempting to get danmaku [BgmBangumiID] $bgmBangumiID');
    danmakuLoading = true;
    try {
      danDanmakus.clear();
      bangumiID =
          await DanmakuApi.getDanDanBangumiIDByBgmBangumiID(bgmBangumiID);
      var res = await DanmakuApi.getDanDanmaku(bangumiID, episode);
      addDanmakus(res);
    } catch (e) {
      KazumiLogger().w(
          'PlayerController: failed to get danmaku [BgmBangumiID] $bgmBangumiID',
          error: e);
    } finally {
      danmakuLoading = false;
    }
  }

  Future<void> getDanDanmakuByEpisodeID(int episodeID) async {
    if (danmakuLoading) {
      KazumiLogger()
          .i('PlayerController: danmaku is loading, ignore duplicate request');
      return;
    }

    KazumiLogger().i('PlayerController: attempting to get danmaku $episodeID');
    danmakuLoading = true;
    try {
      danDanmakus.clear();
      var res = await DanmakuApi.getDanDanmakuByEpisodeID(episodeID);
      addDanmakus(res);
    } catch (e) {
      KazumiLogger().w('PlayerController: failed to get danmaku', error: e);
    } finally {
      danmakuLoading = false;
    }
  }

  void addDanmakus(List<Danmaku> danmakus) {
    final bool danmakuDeduplicationEnable =
        setting.get(SettingBoxKey.danmakuDeduplication, defaultValue: false);

    // 如果启用了弹幕去重功能则处理5秒内相邻重复类似的弹幕进行合并
    final List<Danmaku> listToAdd = danmakuDeduplicationEnable
        ? Utils.mergeDuplicateDanmakus(danmakus, timeWindowSeconds: 5)
        : danmakus;

    for (var element in listToAdd) {
      var danmakuList =
          danDanmakus[element.time.toInt()] ?? List.empty(growable: true);
      danmakuList.add(element);
      danDanmakus[element.time.toInt()] = danmakuList;
    }
  }

  void updateDanmakuSpeed(double playerSpeed) {
    final baseDuration =
        setting.get(SettingBoxKey.danmakuDuration, defaultValue: 8.0);
    final followSpeed =
        setting.get(SettingBoxKey.danmakuFollowSpeed, defaultValue: true);

    final duration = followSpeed ? (baseDuration / playerSpeed) : baseDuration;
    canvasController
        .updateOption(canvasController.option.copyWith(duration: duration));
  }
}
