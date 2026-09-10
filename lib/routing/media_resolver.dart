import 'package:kazumi/modules/bangumi/bangumi_item.dart';
import 'package:kazumi/pages/download/download_controller.dart';
import 'package:kazumi/pages/video/video_playback_args.dart';
import 'package:kazumi/plugins/plugins_controller.dart';
import 'package:kazumi/repositories/collect_repository.dart';
import 'package:kazumi/repositories/history_repository.dart';
import 'package:kazumi/request/apis/bangumi_api.dart';
import 'package:kazumi/services/plugin/rule_engine_models.dart'
    show RuleCancelToken;

import 'media_location.dart';

class MediaResolver {
  MediaResolver(this._collect, this._history, this._plugins, this._downloads,
      {Future<BangumiItem?> Function(int)? loadBangumi})
      : _loadBangumi = loadBangumi ?? BangumiApi.getBangumiInfoByID;

  final ICollectRepository _collect;
  final IHistoryRepository _history;
  final PluginsController _plugins;
  final DownloadController _downloads;
  final Future<BangumiItem?> Function(int) _loadBangumi;

  Future<BangumiItem> info(int id) async {
    if (id <= 0) throw const FormatException('番组编号无效。');
    final collected = _collect.getCollectible(id)?.bangumiItem;
    if (collected != null) return collected;
    for (final history in _history.getAllHistories()) {
      if (history.bangumiItem.id == id) return history.bangumiItem;
    }
    final item = await _loadBangumi(id);
    if (item == null || item.id != id) {
      throw const FormatException('未能加载番组信息，请稍后重试。');
    }
    return item;
  }

  Future<VideoPlaybackArgs> video(
      VideoLocation target, RuleCancelToken token) async {
    if (target.offline) {
      final record = _downloads.getRecord(target.id, target.plugin);
      final episodes =
          _downloads.getCompletedEpisodes(target.id, target.plugin);
      final episode = episodes
          .where((episode) =>
              episode.episodeNumber == target.episode &&
              episode.road == target.road)
          .firstOrNull;
      if (record == null ||
          episode == null ||
          _downloads.getLocalVideoPath(
                  target.id, target.plugin, target.episode!) ==
              null) {
        throw const FormatException('未找到对应的本地缓存，请重新选择下载内容。');
      }
      return OfflineVideoPlaybackArgs.fromRecord(
        record: record,
        episode: episode,
        downloadedEpisodes: episodes,
      );
    }
    final plugin = _plugins.pluginList
        .where((plugin) => plugin.name == target.plugin)
        .firstOrNull;
    if (plugin == null) {
      throw const FormatException('播放规则尚未安装，请先在规则管理中添加。');
    }
    final item = await info(target.id);
    if (token.isCancelled) throw token.cancelError!;
    final roads =
        await plugin.queryChapterRoads(target.src!, cancelToken: token);
    if (token.isCancelled) throw token.cancelError!;
    if (roads.isEmpty ||
        (target.road == null && roads.first.data.isEmpty) ||
        (target.road != null &&
            (target.road! >= roads.length ||
                target.episode! > roads[target.road!].data.length))) {
      throw const FormatException('对应的线路或集数已不可用，请重新选择播放源。');
    }
    return OnlineVideoPlaybackArgs(
      bangumiItem: item,
      plugin: plugin,
      title: item.nameCn.isEmpty ? item.name : item.nameCn,
      src: target.src!,
      roads: roads,
      episode: target.episode,
      road: target.road,
    );
  }
}
