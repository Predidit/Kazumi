import 'package:kazumi/modules/roads/road_module.dart';
import 'package:kazumi/plugins/plugins_controller.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/plugins/plugins.dart';
import 'package:kazumi/pages/webview/webview_controller.dart';
import 'package:kazumi/pages/history/history_controller.dart';
import 'package:kazumi/modules/bangumi/bangumi_item.dart';
import 'package:mobx/mobx.dart';
import 'package:kazumi/utils/utils.dart';
import 'package:kazumi/utils/logger.dart';
import 'package:window_manager/window_manager.dart';
import 'package:kazumi/modules/bangumi/episode_item.dart';
import 'package:kazumi/modules/comments/comment_item.dart';
import 'package:kazumi/request/bangumi.dart';
import 'package:dio/dio.dart';

part 'video_controller.g.dart';

class VideoPageController = _VideoPageController with _$VideoPageController;

abstract class _VideoPageController with Store {
  late BangumiItem bangumiItem;
  EpisodeInfo episodeInfo = EpisodeInfo.fromTemplate();

  @observable
  var episodeCommentsList = ObservableList<EpisodeCommentItem>();

  @observable
  bool loading = true;

  @observable
  int currentEpisode = 1;

  @observable
  int currentRoad = 0;

  /// 全屏状态
  @observable
  bool isFullscreen = false;

  /// 评论正序或倒序
  @observable
  bool isCommentsAscending = false;

  /// 画中画状态
  @observable
  bool isPip = false;

  /// 播放列表显示状态
  @observable
  bool showTabBody = true;

  /// 上次观看位置
  @observable
  int historyOffset = 0;

  /// 和 bangumiItem 中的标题不同，此标题来自于视频源
  String title = '';

  String src = '';

  @observable
  var roadList = ObservableList<Road>();

  late Plugin currentPlugin;

  /// 用于取消正在进行的 queryRoads 操作
  CancelToken? _queryRoadsCancelToken;

  final PluginsController pluginsController = Modular.get<PluginsController>();
  final HistoryController historyController = Modular.get<HistoryController>();

  Future<void> changeEpisode(int episode,
      {int currentRoad = 0, int offset = 0}) async {
    currentEpisode = episode;
    this.currentRoad = currentRoad;
    String chapterName = roadList[currentRoad].identifier[episode - 1];
    KazumiLogger().i('VideoPageController: changed to $chapterName');
    String urlItem = roadList[currentRoad].data[episode - 1];
    if (urlItem.contains(currentPlugin.baseUrl) ||
        urlItem.contains(currentPlugin.baseUrl.replaceAll('https', 'http'))) {
      urlItem = urlItem;
    } else {
      urlItem = currentPlugin.baseUrl + urlItem;
    }
    final webviewItemController = Modular.get<WebviewItemController>();
    await webviewItemController.loadUrl(
        urlItem, currentPlugin.useNativePlayer, currentPlugin.useLegacyParser,
        offset: offset);
  }

  Future<void> queryBangumiEpisodeCommentsByID(int id, int episode) async {
    episodeCommentsList.clear();
    episodeInfo = await BangumiHTTP.getBangumiEpisodeByID(id, episode);
    await BangumiHTTP.getBangumiCommentsByEpisodeID(episodeInfo.id)
        .then((value) {
      episodeCommentsList.addAll(value.commentList);
    });
    if (!isCommentsAscending) {
      episodeCommentsList
          .sort((a, b) => b.comment.createdAt.compareTo(a.comment.createdAt));
    } else {
      episodeCommentsList
          .sort((a, b) => a.comment.createdAt.compareTo(b.comment.createdAt));
    }
    KazumiLogger().i(
        'VideoPageController: loaded comments list length ${episodeCommentsList.length}');
  }

  Future<void> queryRoads(String url, String pluginName,
      {CancelToken? cancelToken}) async {
    if (cancelToken != null) {
      _queryRoadsCancelToken?.cancel();
      _queryRoadsCancelToken = cancelToken;
    } else {
      _queryRoadsCancelToken?.cancel();
      _queryRoadsCancelToken = CancelToken();
      cancelToken = _queryRoadsCancelToken;
    }

    final PluginsController pluginsController =
        Modular.get<PluginsController>();
    roadList.clear();
    for (Plugin plugin in pluginsController.pluginList) {
      if (plugin.name == pluginName) {
        roadList.addAll(
            await plugin.querychapterRoads(url, cancelToken: cancelToken));
      }
    }
    KazumiLogger()
        .i('VideoPageController: road list length ${roadList.length}');
    KazumiLogger().i(
        'VideoPageController: first road episode count ${roadList[0].data.length}');
  }

  void toggleSortOrder() {
    isCommentsAscending = !isCommentsAscending;
    episodeCommentsList.sort(
      (a, b) => isCommentsAscending
          ? a.comment.createdAt.compareTo(b.comment.createdAt)
          : b.comment.createdAt.compareTo(a.comment.createdAt),
    );
  }

  void cancelQueryRoads() {
    if (_queryRoadsCancelToken != null) {
      if (!_queryRoadsCancelToken!.isCancelled) {
        _queryRoadsCancelToken!.cancel();
      }
    }
  }

  void enterFullScreen() {
    isFullscreen = true;
    showTabBody = false;
    Utils.enterFullScreen(lockOrientation: false);
  }

  void exitFullScreen() {
    isFullscreen = false;
    Utils.exitFullScreen();
  }

  void isDesktopFullscreen() async {
    if (Utils.isDesktop()) {
      isFullscreen = await windowManager.isFullScreen();
    }
  }

  void handleOnEnterFullScreen() async {
    isFullscreen = true;
    showTabBody = false;
  }

  void handleOnExitFullScreen() async {
    isFullscreen = false;
  }
}
