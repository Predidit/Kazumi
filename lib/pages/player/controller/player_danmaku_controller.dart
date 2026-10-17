// ignore_for_file: library_private_types_in_public_api

import 'package:canvas_danmaku/canvas_danmaku.dart' as canvas;
import 'package:kazumi/modules/danmaku/custom_danmaku_server_config.dart';
import 'package:kazumi/modules/danmaku/danmaku_module.dart';
import 'package:kazumi/pages/download/download_controller.dart';
import 'package:kazumi/request/apis/danmaku_api.dart';
import 'package:kazumi/services/logging/logger.dart';
import 'package:kazumi/services/storage/storage.dart';
import 'package:mobx/mobx.dart';
import 'package:kazumi/utils/danmaku.dart';

part 'player_danmaku_controller.g.dart';

/// 弹幕来源服务端名称 (播放信息面板展示)。
/// 自定义服务器未命中回退弹弹play 时, 来源标签按实际提供弹幕的服务端显示。
const String customDanmakuServerName = '自定义弹幕服务器';
const String builtInDanmakuServerName = '弹弹play';

class PlayerDanmakuController = _PlayerDanmakuController
    with _$PlayerDanmakuController;

enum DanmakuLoadStatus {
  success,
  empty,
  failed,
}

class DanmakuLoadResult {
  const DanmakuLoadResult({
    required this.danmakus,
    required this.bangumiID,
    required this.status,
    this.danmakuServer,
    this.danmakuAnimeTitle,
    this.danmakuEpisodeTitle,
  });

  factory DanmakuLoadResult.success({
    required List<DanmakuEntry> danmakus,
    required int bangumiID,
    String? danmakuServer,
    String? danmakuAnimeTitle,
    String? danmakuEpisodeTitle,
  }) {
    return DanmakuLoadResult(
      danmakus: danmakus,
      bangumiID: bangumiID,
      status: danmakus.isEmpty
          ? DanmakuLoadStatus.empty
          : DanmakuLoadStatus.success,
      danmakuServer: danmakuServer,
      danmakuAnimeTitle: danmakuAnimeTitle,
      danmakuEpisodeTitle: danmakuEpisodeTitle,
    );
  }

  factory DanmakuLoadResult.failed({
    required int bangumiID,
    String? danmakuServer,
  }) {
    return DanmakuLoadResult(
      danmakus: const [],
      bangumiID: bangumiID,
      status: DanmakuLoadStatus.failed,
      danmakuServer: danmakuServer,
    );
  }

  final List<DanmakuEntry> danmakus;
  final int bangumiID;
  final DanmakuLoadStatus status;

  /// 实际提供弹幕的服务端名称; 自定义未命中回退弹弹play 等场景用于来源展示。
  final String? danmakuServer;

  /// 自定义弹幕服务器实际匹配到的番剧/分集标题 (含平台来源标记),
  /// 用于来源标签完整展示; 内置弹弹play 路径为 null, 回退到本地标题。
  final String? danmakuAnimeTitle;
  final String? danmakuEpisodeTitle;

  bool get hasDanmakus => status == DanmakuLoadStatus.success;

  bool get isFailed => status == DanmakuLoadStatus.failed;
}

class DanmakuTimeline {
  static int? resolveSourceSecond(
    Duration playbackPosition,
    double timelineOffsetSeconds,
  ) {
    final sourceMilliseconds = playbackPosition.inMilliseconds -
        (timelineOffsetSeconds * 1000).round();
    if (sourceMilliseconds < 0) {
      return null;
    }
    return Duration(milliseconds: sourceMilliseconds).inSeconds;
  }

  static int staggerDelayMilliseconds({
    required int index,
    required int total,
  }) {
    if (total <= 0) {
      return 0;
    }
    return index * 1000 ~/ total;
  }
}

abstract class _PlayerDanmakuController with Store {
  _PlayerDanmakuController({
    required this.isLocalPlayback,
    required this.downloadController,
  });

  final bool Function() isLocalPlayback;
  final DownloadController downloadController;

  late canvas.DanmakuController canvasController;

  final Map<int, List<DanmakuEntry>> danDanmakus = {};
  @observable
  bool danmakuOn = false;
  @observable
  bool danmakuLoading = false;

  /// 当前弹幕来源描述, 用于播放信息面板展示 (动漫名 + 集数 + 服务器)
  @observable
  String danmakuSourceLabel = '';

  /// 当前弹幕来源的动漫名称 (手动选择或标题匹配时已知)
  @observable
  String danmakuSourceAnimeTitle = '';

  /// 当前弹幕来源的集数描述
  @observable
  String danmakuSourceEpisodeTitle = '';

  int bangumiID = 0;
  int _scheduledDanmakuGeneration = 0;

  int get scheduledDanmakuGeneration => _scheduledDanmakuGeneration;

  double get timelineOffsetSeconds {
    final offset = GStorage.getSetting(SettingsKeys.danmakuTimeOffset);
    return offset;
  }

  int? resolveDanmakuSecond(Duration playbackPosition) {
    return DanmakuTimeline.resolveSourceSecond(
      playbackPosition,
      timelineOffsetSeconds,
    );
  }

  List<DanmakuEntry> danmakusForPlaybackPosition(Duration playbackPosition) {
    final danmakuSecond = resolveDanmakuSecond(playbackPosition);
    if (danmakuSecond == null) {
      return const [];
    }
    return danDanmakus[danmakuSecond] ?? const [];
  }

  @action
  void setDanmakuEnabled(bool value) {
    danmakuOn = value;
  }

  String get _danmakuServerName => CustomDanmakuServerConfig.isEnabled
      ? customDanmakuServerName
      : builtInDanmakuServerName;

  /// 记录当前弹幕来源 (播放信息面板展示)。
  @action
  void setDanmakuSource({
    required String animeTitle,
    required String episodeTitle,
    String? serverName,
  }) {
    danmakuSourceAnimeTitle = animeTitle;
    danmakuSourceEpisodeTitle = episodeTitle;
    final server = serverName ?? _danmakuServerName;
    final animePart = animeTitle.isEmpty ? '' : '《$animeTitle》';
    final episodePart = episodeTitle.isEmpty ? '' : ' $episodeTitle';
    danmakuSourceLabel = '$animePart$episodePart · $server';
  }

  /// 直接设置来源标签 (本地缓存/获取失败等场景)。
  @action
  void updateDanmakuSourceLabel(String label) {
    danmakuSourceLabel = label;
  }

  @action
  void clearDanmakuSource() {
    danmakuSourceLabel = '';
    danmakuSourceAnimeTitle = '';
    danmakuSourceEpisodeTitle = '';
  }

  void clearAndInvalidateScheduledDanmakus() {
    _scheduledDanmakuGeneration++;
    canvasController.clear();
  }

  // Apply fetched data only after VideoPageController validates the session.
  Future<DanmakuLoadResult> fetchDanmaku(
    int bangumiId,
    String pluginName,
    int episode, {
    String? bangumiName,
  }) async {
    final title = bangumiName?.trim() ?? '';
    final DanmakuLoadResult result;
    if (isLocalPlayback()) {
      result = await _fetchCachedDanmaku(
        bangumiId,
        pluginName,
        episode,
        bangumiName,
      );
    } else {
      result = await _fetchDanDanmakuByBgmBangumiID(
        bangumiId,
        episode,
        bangumiName,
      );
    }
    _applyDanmakuSourceLabel(result, title: title, episode: episode);
    return result;
  }

  /// 根据加载结果更新弹幕来源标签 (播放信息面板展示)。
  /// 自定义服务器会带回其实际匹配的番剧/分集标题 (含平台来源标记),
  /// 优先用于展示, 与手动选择弹幕源时的显示保持一致。
  void _applyDanmakuSourceLabel(
    DanmakuLoadResult result, {
    required String title,
    required int episode,
  }) {
    if (result.isFailed) {
      updateDanmakuSourceLabel('弹幕获取失败');
      return;
    }
    final server = result.danmakuServer ?? _danmakuServerName;
    if (result.danmakus.isEmpty) {
      updateDanmakuSourceLabel('未匹配到《$title》第${episode}集弹幕 · $server');
      return;
    }
    setDanmakuSource(
      animeTitle: result.danmakuAnimeTitle ?? title,
      episodeTitle: result.danmakuEpisodeTitle ?? '第${episode}集',
      serverName: server,
    );
  }

  @action
  void beginDanmakuLoad() {
    danDanmakus.clear();
    danmakuLoading = true;
  }

  @action
  void applyDanmakuLoad(
    DanmakuLoadResult result, {
    required bool enableDanmaku,
  }) {
    bangumiID = result.bangumiID;
    addDanmakus(result.danmakus);
    danmakuOn = enableDanmaku;
    danmakuLoading = false;
  }

  @action
  void applyUnavailableDanmakuLoad(DanmakuLoadResult result) {
    bangumiID = result.bangumiID;
    danDanmakus.clear();
    danmakuOn = false;
    danmakuLoading = false;
  }

  @action
  void finishDanmakuLoad({bool disableDanmaku = false}) {
    if (disableDanmaku) {
      danDanmakus.clear();
      danmakuOn = false;
    }
    danmakuLoading = false;
  }

  Future<DanmakuLoadResult> _fetchCachedDanmaku(
      int bangumiId, String pluginName, int episode, String? bangumiName) async {
    KazumiLogger().i(
        'PlayerController: attempting to load cached danmaku for episode $episode');
    var nextBangumiID = bangumiID;
    try {
      final cachedDanmakus = await downloadController.getCachedDanmakus(
        bangumiId,
        pluginName,
        episode,
      );

      if (cachedDanmakus != null && cachedDanmakus.isNotEmpty) {
        KazumiLogger().i(
            'PlayerController: loaded ${cachedDanmakus.length} cached danmakus');
        return DanmakuLoadResult.success(
          danmakus: cachedDanmakus,
          bangumiID: nextBangumiID,
        );
      } else {
        KazumiLogger()
            .i('PlayerController: no cached danmaku, attempting online fetch');
        // 自定义弹幕服务器优先: 无 bgmtv ID 映射, 本地播放的兜底取弹幕
        // 按标题匹配; 未匹配到弹幕时回退弹弹play, 保证内置弹幕功能可用。
        if (CustomDanmakuServerConfig.isEnabled) {
          final customResult = await _fetchCustomDanmakuByBangumiName(
              bangumiName, episode, nextBangumiID);
          if (customResult.hasDanmakus) {
            return customResult;
          }
          KazumiLogger().i(
              'PlayerController: custom danmaku unavailable, falling back to弹弹play');
        }
        try {
          nextBangumiID =
              await DanmakuApi.getDanDanBangumiIDByBgmBangumiID(bangumiId);
          if (nextBangumiID != 0) {
            var res = await DanmakuApi.getDanDanmaku(nextBangumiID, episode);
            if (res.isNotEmpty) {
              KazumiLogger()
                  .i('PlayerController: fetched ${res.length} danmakus online');
              _saveDanmakuToCache(downloadController, bangumiId, pluginName,
                  episode, res, nextBangumiID);
            }
            return DanmakuLoadResult.success(
              danmakus: res,
              bangumiID: nextBangumiID,
              danmakuServer: builtInDanmakuServerName,
            );
          }
        } catch (e) {
          KazumiLogger().w(
              'PlayerController: failed to fetch danmaku online (may be offline)',
              error: e);
          return DanmakuLoadResult.failed(
            bangumiID: nextBangumiID,
            danmakuServer: builtInDanmakuServerName,
          );
        }
      }
    } catch (e) {
      KazumiLogger()
          .w('PlayerController: failed to load cached danmaku', error: e);
      return DanmakuLoadResult.failed(bangumiID: nextBangumiID);
    }
    return DanmakuLoadResult.success(
      danmakus: const [],
      bangumiID: nextBangumiID,
      danmakuServer: builtInDanmakuServerName,
    );
  }

  void _saveDanmakuToCache(
      DownloadController downloadController,
      int bangumiId,
      String pluginName,
      int episode,
      List<DanmakuEntry> danmakus,
      int danDanID) {
    try {
      downloadController.updateCachedDanmakus(
        bangumiId,
        pluginName,
        episode,
        danmakus,
        danDanID,
      );
      KazumiLogger()
          .i('PlayerController: saved ${danmakus.length} danmakus to cache');
    } catch (e) {
      KazumiLogger()
          .w('PlayerController: failed to save danmaku to cache', error: e);
    }
  }

  Future<DanmakuLoadResult> _fetchDanDanmakuByBgmBangumiID(
      int bgmBangumiID, int episode, String? bangumiName) async {
    // 自定义弹幕服务器 (danmu_api) 不支持 bgmtv ID 映射,
    // 改按番剧标题走 match 接口自动匹配弹幕;
    // 未匹配到弹幕 (或匹配失败) 时回退弹弹play, 保证内置弹幕功能可用。
    if (CustomDanmakuServerConfig.isEnabled) {
      final customResult = await _fetchCustomDanmakuByBangumiName(
          bangumiName, episode, bangumiID);
      if (customResult.hasDanmakus) {
        return customResult;
      }
      KazumiLogger().i(
          'PlayerController: custom danmaku unavailable, falling back to弹弹play');
    }
    return await _fetchBuiltInDanmakuByBgmBangumiID(bgmBangumiID, episode);
  }

  /// 弹弹play 自动匹配: bgmtv ID 映射 -> 按集数约定拉取弹幕。
  Future<DanmakuLoadResult> _fetchBuiltInDanmakuByBgmBangumiID(
      int bgmBangumiID, int episode) async {
    KazumiLogger().i(
        'PlayerController: attempting to get danmaku [BgmBangumiID] $bgmBangumiID');
    var nextBangumiID = bangumiID;
    try {
      nextBangumiID =
          await DanmakuApi.getDanDanBangumiIDByBgmBangumiID(bgmBangumiID);
      if (nextBangumiID == 0) {
        return DanmakuLoadResult.success(
          danmakus: const [],
          bangumiID: nextBangumiID,
          danmakuServer: builtInDanmakuServerName,
        );
      }
      var res = await DanmakuApi.getDanDanmaku(nextBangumiID, episode);
      return DanmakuLoadResult.success(
        danmakus: res,
        bangumiID: nextBangumiID,
        danmakuServer: builtInDanmakuServerName,
      );
    } catch (e) {
      KazumiLogger().w(
          'PlayerController: failed to get danmaku [BgmBangumiID] $bgmBangumiID',
          error: e);
    }
    return DanmakuLoadResult.failed(
      bangumiID: nextBangumiID,
      danmakuServer: builtInDanmakuServerName,
    );
  }

  /// 自定义弹幕服务器: 按番剧标题自动匹配并拉取弹幕。
  /// 标题缺失或未匹配到时返回空结果, 用户仍可在播放页手动搜索选择弹幕源。
  /// 匹配成功时带回服务端的番剧/分集标题, 供来源标签完整展示。
  Future<DanmakuLoadResult> _fetchCustomDanmakuByBangumiName(
    String? bangumiName,
    int episode,
    int fallbackBangumiID,
  ) async {
    final title = bangumiName?.trim() ?? '';
    if (title.isEmpty) {
      KazumiLogger().i(
          'PlayerController: custom danmaku server enabled but bangumi name unavailable');
      return DanmakuLoadResult.success(
        danmakus: const [],
        bangumiID: fallbackBangumiID,
        danmakuServer: customDanmakuServerName,
      );
    }
    try {
      final res = await DanmakuApi.getCustomDanmakuByBangumiName(
          title, episode);
      return DanmakuLoadResult.success(
        danmakus: res.danmakus,
        bangumiID: fallbackBangumiID,
        danmakuServer: customDanmakuServerName,
        danmakuAnimeTitle: res.animeTitle,
        danmakuEpisodeTitle: res.episodeTitle,
      );
    } catch (e) {
      KazumiLogger()
          .w('PlayerController: failed to get danmaku from custom server',
              error: e);
      return DanmakuLoadResult.failed(
        bangumiID: fallbackBangumiID,
        danmakuServer: customDanmakuServerName,
      );
    }
  }

  @action
  Future<bool> getDanDanmakuByEpisodeID(int episodeID,
      {bool? useCustomServer}) async {
    KazumiLogger().i('PlayerController: attempting to get danmaku $episodeID');
    danmakuLoading = true;
    try {
      danDanmakus.clear();
      var res = await DanmakuApi.getDanDanmakuByEpisodeID(episodeID,
          useCustomServer: useCustomServer);
      addDanmakus(res);
      return res.isNotEmpty;
    } catch (e) {
      KazumiLogger().w('PlayerController: failed to get danmaku', error: e);
      rethrow;
    } finally {
      danmakuLoading = false;
    }
  }

  void addDanmakus(List<DanmakuEntry> danmakus) {
    final bool danmakuDeduplicationEnable =
        GStorage.getSetting(SettingsKeys.danmakuDeduplication);

    final List<DanmakuEntry> listToAdd = danmakuDeduplicationEnable
        ? mergeDuplicateDanmakus(danmakus, timeWindowSeconds: 5)
        : danmakus;

    for (final element in listToAdd) {
      final danmakuSecond = element.time.toInt();
      (danDanmakus[danmakuSecond] ??= <DanmakuEntry>[]).add(element);
    }
  }

  void updateDanmakuSpeed(double playerSpeed) {
    final baseDuration = GStorage.getSetting(SettingsKeys.danmakuDuration);
    final followSpeed = GStorage.getSetting(SettingsKeys.danmakuFollowSpeed);

    final duration = followSpeed ? (baseDuration / playerSpeed) : baseDuration;
    canvasController
        .updateOption(canvasController.option.copyWith(duration: duration));
  }
}
