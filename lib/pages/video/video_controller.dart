import 'dart:async';
import 'package:kazumi/modules/roads/road_module.dart';
import 'package:kazumi/plugins/plugins_controller.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/plugins/plugins.dart';
import 'package:kazumi/pages/history/history_controller.dart';
import 'package:kazumi/pages/player/player_controller.dart';
import 'package:kazumi/modules/bangumi/bangumi_item.dart';
import 'package:kazumi/modules/download/download_module.dart';
import 'package:kazumi/repositories/download_repository.dart';
import 'package:kazumi/utils/download_manager.dart';
import 'package:kazumi/providers/providers.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:mobx/mobx.dart';
import 'package:kazumi/utils/utils.dart';
import 'package:kazumi/utils/logger.dart';
import 'package:window_manager/window_manager.dart';
import 'package:kazumi/modules/bangumi/episode_item.dart';
import 'package:kazumi/modules/comments/comment_item.dart';
import 'package:kazumi/request/bangumi.dart';
import 'package:dio/dio.dart';
import 'package:hive_ce/hive.dart';
import 'package:kazumi/utils/storage.dart';

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
  String? errorMessage;

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

  /// 离线播放模式
  @observable
  bool isOfflineMode = false;

  /// 离线视频本地路径
  String? _offlineVideoPath;

  /// 和 bangumiItem 中的标题不同，此标题来自于视频源
  String title = '';

  String src = '';

  @observable
  var roadList = ObservableList<Road>();

  late Plugin currentPlugin;

  /// 离线模式下的虚拟插件名
  String _offlinePluginName = '';

  /// 用于取消正在进行的 queryRoads 操作
  CancelToken? _queryRoadsCancelToken;

  final PluginsController pluginsController = Modular.get<PluginsController>();
  final HistoryController historyController = Modular.get<HistoryController>();
  final IDownloadRepository downloadRepository =
      Modular.get<IDownloadRepository>();
  final IDownloadManager downloadManager = Modular.get<IDownloadManager>();
  final Box setting = GStorage.setting;

  /// 长生命周期的视频源提供者（页面生命周期内复用，WebView 实例在 Provider 内复用）
  WebViewVideoSourceProvider? _videoSourceProvider;

  /// 视频提供者日志流控制器
  final StreamController<String> _logStreamController =
      StreamController<String>.broadcast();

  Stream<String> get logStream => _logStreamController.stream;

  StreamSubscription<String>? _logSubscription;

  /// 初始化离线播放模式
  void initForOfflinePlayback({
    required BangumiItem bangumiItem,
    required String pluginName,
    required int episodeNumber,
    required String episodeName,
    required int road,
    required String videoPath,
    required List<DownloadEpisode> downloadedEpisodes,
  }) {
    this.bangumiItem = bangumiItem;
    _offlinePluginName = pluginName;
    currentRoad = road;
    title =
        bangumiItem.nameCn.isNotEmpty ? bangumiItem.nameCn : bangumiItem.name;
    isOfflineMode = true;
    _offlineVideoPath = videoPath;
    // 离线模式不需要解析视频源，直接设置 loading 为 false
    loading = false;

    // 构建仅包含已下载集数的 roadList
    _buildOfflineRoadList(downloadedEpisodes);

    // 离线模式下 roadList 长度为 1 , currentRoad 可能访问越界，需要校正
    if (currentRoad < 0 || currentRoad >= roadList.length) {
      currentRoad = 0;
    }

    // currentEpisode 是列表中的 1-based 位置，而非实际集数编号
    // 在 roadList.data 中查找 episodeNumber 对应的位置
    final index = roadList[currentRoad].data.indexOf(episodeNumber.toString());
    currentEpisode = index >= 0 ? index + 1 : 1;
    KazumiLogger().i(
        'VideoPageController: initialized for offline playback, episode $episodeNumber (position: $currentEpisode)');
  }

  /// 构建离线模式的 roadList
  void _buildOfflineRoadList(List<DownloadEpisode> episodes) {
    roadList.clear();
    episodes.sort((a, b) => a.episodeNumber.compareTo(b.episodeNumber));
    // 使用 '播放列表1' 作为名称，与 UI 代码兼容
    roadList.add(Road(
      name: '播放列表1',
      // data 存储实际的 episodeNumber（字符串形式），用于离线播放时查找本地文件
      data: episodes.map((e) => e.episodeNumber.toString()).toList(),
      identifier: episodes
          .map((e) =>
              e.episodeName.isNotEmpty ? e.episodeName : '第${e.episodeNumber}集')
          .toList(),
    ));
  }

  void resetOfflineMode() {
    isOfflineMode = false;
    _offlineVideoPath = null;
    _offlinePluginName = '';
  }

  String? get offlineVideoPath => _offlineVideoPath;

  String get offlinePluginName => _offlinePluginName;

  /// 获取当前实际的集数编号
  /// 在线模式下直接返回 currentEpisode
  /// 离线模式下从 roadList.data 中获取实际的 episodeNumber
  int get actualEpisodeNumber {
    if (isOfflineMode && roadList.isNotEmpty) {
      try {
        return int.parse(roadList[currentRoad].data[currentEpisode - 1]);
      } catch (_) {
        return currentEpisode;
      }
    }
    return currentEpisode;
  }

  Future<void> changeEpisode(int episode,
      {int currentRoad = 0, int offset = 0}) async {
    currentEpisode = episode;
    this.currentRoad = currentRoad;
    errorMessage = null;

    if (isOfflineMode) {
      await _changeOfflineEpisode(episode, offset);
      return;
    }

    String chapterName = roadList[currentRoad].identifier[episode - 1];
    KazumiLogger().i('VideoPageController: changed to $chapterName');
    String urlItem = roadList[currentRoad].data[episode - 1];
    if (urlItem.contains(currentPlugin.baseUrl) ||
        urlItem.contains(currentPlugin.baseUrl.replaceAll('https', 'http'))) {
      urlItem = urlItem;
    } else {
      urlItem = currentPlugin.baseUrl + urlItem;
    }

    await _resolveWithProvider(urlItem, offset);
  }

  /// 离线模式下切换集数
  /// [episode] 是列表中的位置（从 1 开始），需要从 roadList.data 中获取实际的 episodeNumber
  Future<void> _changeOfflineEpisode(int episode, int offset) async {
    // 从 roadList.data 中获取实际的 episodeNumber
    final actualEpisodeNumber =
        int.tryParse(roadList[currentRoad].data[episode - 1]);
    if (actualEpisodeNumber == null) {
      KazumiLogger().e(
          'VideoPageController: failed to parse episode number from roadList data: ${roadList[currentRoad].data[episode - 1]}');
      KazumiDialog.showToast(message: '集数解析失败');
      return;
    }

    final localPath = _getLocalVideoPath(
      bangumiItem.id,
      _offlinePluginName,
      actualEpisodeNumber,
    );
    if (localPath == null) {
      KazumiDialog.showToast(message: '该集数未下载');
      return;
    }
    _offlineVideoPath = localPath;
    loading = false;

    KazumiLogger().i(
        'VideoPageController: offline episode changed to $actualEpisodeNumber (index: $episode), path: $localPath');

    final params = PlaybackInitParams(
      videoUrl: localPath,
      offset: offset,
      isLocalPlayback: true,
      bangumiId: bangumiItem.id,
      pluginName: _offlinePluginName,
      episode: actualEpisodeNumber,
      httpHeaders: {},
      adBlockerEnabled: false,
      episodeTitle: roadList[currentRoad].identifier[episode - 1],
      referer: '',
      currentRoad: currentRoad,
    );

    final playerController = Modular.get<PlayerController>();
    await playerController.init(params);
  }

  /// 获取本地视频路径
  String? _getLocalVideoPath(
      int bangumiId, String pluginName, int episodeNumber) {
    final episode =
        downloadRepository.getEpisode(bangumiId, pluginName, episodeNumber);
    return downloadManager.getLocalVideoPath(episode);
  }

  /// 使用 VideoSourceProvider 解析视频源
  Future<void> _resolveWithProvider(String url, int offset) async {
    _videoSourceProvider?.cancel();

    loading = true;
    _videoSourceProvider ??= WebViewVideoSourceProvider();

    await _logSubscription?.cancel();
    _logSubscription = _videoSourceProvider!.onLog.listen((log) {
      if (!_logStreamController.isClosed) {
        _logStreamController.add(log);
      }
    });

    try {
      final source = await _videoSourceProvider!.resolve(
        url,
        useLegacyParser: currentPlugin.useLegacyParser,
        offset: offset,
      );

      loading = false;
      KazumiLogger()
          .i('VideoPageController: resolved video URL: ${source.url}');

      final bool forceAdBlocker =
          setting.get(SettingBoxKey.forceAdBlocker, defaultValue: false);

      final params = PlaybackInitParams(
        videoUrl: source.url,
        offset: source.offset,
        isLocalPlayback: false,
        bangumiId: bangumiItem.id,
        pluginName: currentPlugin.name,
        episode: currentEpisode,
        httpHeaders: {
          'user-agent': currentPlugin.userAgent.isEmpty
              ? Utils.getRandomUA()
              : currentPlugin.userAgent,
          if (currentPlugin.referer.isNotEmpty)
            'referer': currentPlugin.referer,
        },
        adBlockerEnabled: forceAdBlocker || currentPlugin.adBlocker,
        episodeTitle: roadList[currentRoad].identifier[currentEpisode - 1],
        referer: currentPlugin.referer,
        currentRoad: currentRoad,
      );

      final playerController = Modular.get<PlayerController>();
      await playerController.init(params);
    } on VideoSourceTimeoutException {
      loading = false;
      errorMessage = '视频解析超时，请重试';
    } on VideoSourceCancelledException {
      KazumiLogger().i('VideoPageController: video URL resolution cancelled');
      // 不设置 loading = false，因为可能是切换到新的集数
    } catch (e) {
      loading = false;
      errorMessage = '视频解析失败：${e.toString()}';
    }
  }

  /// 取消当前视频源解析并销毁 Provider（页面退出时调用）
  void cancelVideoSourceResolution() {
    _logSubscription?.cancel();
    _logSubscription = null;
    if (!_logStreamController.isClosed) {
      _logStreamController.close();
    }
    _videoSourceProvider?.dispose();
    _videoSourceProvider = null;
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
