import 'dart:async';
import 'package:kazumi/modules/roads/road_module.dart';
import 'package:kazumi/plugins/plugins_controller.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/plugins/plugins.dart';
import 'package:kazumi/pages/history/history_controller.dart';
import 'package:kazumi/pages/player/player_controller.dart';
import 'package:kazumi/modules/bangumi/bangumi_item.dart';
import 'package:kazumi/modules/download/download_module.dart';
import 'package:kazumi/modules/history/history_module.dart';
import 'package:kazumi/repositories/download_repository.dart';
import 'package:kazumi/utils/download_manager.dart';
import 'package:kazumi/providers/video/providers.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:mobx/mobx.dart';
import 'package:kazumi/utils/utils.dart';
import 'package:kazumi/utils/logger.dart';
import 'package:window_manager/window_manager.dart';
import 'package:kazumi/modules/bangumi/episode_item.dart';
import 'package:kazumi/modules/comments/comment_item.dart';
import 'package:kazumi/request/apis/bangumi_api.dart';
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

  int _episodeCommentsRequestId = 0;

  /// 桌面画中画状态，Android 画中画状态不需要单独维护，进入画中画后会直接切换到系统的全局播放器界面
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

  PlaybackHistoryIdentity? _playbackHistoryIdentity;
  ResolvedEpisode? _currentResolvedEpisode;
  final Map<int, DownloadEpisode> _offlineEpisodesByNumber = {};
  final Map<int, int> _offlineDisplayRoadToOriginalRoad = {};
  final Map<int, int> _offlineOriginalRoadToDisplayRoad = {};

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

    final target = _findOfflineEpisodeByNumber(
      episodeNumber,
      preferredOriginalRoad: road,
    );
    currentRoad = target?.roadIndex ?? 0;
    currentEpisode = target?.listIndex ?? 1;
    final resolvedEpisode = _resolveOfflineEpisode(currentEpisode);
    if (resolvedEpisode != null) {
      _currentResolvedEpisode = resolvedEpisode;
      _setOfflineHistoryIdentity(resolvedEpisode);
    } else {
      _currentResolvedEpisode = null;
      _playbackHistoryIdentity = null;
    }
    KazumiLogger().i(
        'VideoPageController: initialized for offline playback, episode $episodeNumber (position: $currentEpisode)');
  }

  /// 构建离线模式的 roadList
  void _buildOfflineRoadList(List<DownloadEpisode> episodes) {
    final snapshot = buildOfflineRoadListSnapshot(episodes);
    roadList.clear();
    roadList.addAll(snapshot.roads);
    _offlineEpisodesByNumber.clear();
    _offlineEpisodesByNumber.addAll(snapshot.episodesByNumber);
    _offlineDisplayRoadToOriginalRoad.clear();
    _offlineDisplayRoadToOriginalRoad
        .addAll(snapshot.displayRoadToOriginalRoad);
    _offlineOriginalRoadToDisplayRoad.clear();
    _offlineOriginalRoadToDisplayRoad
        .addAll(snapshot.originalRoadToDisplayRoad);
  }

  void resetOfflineMode() {
    isOfflineMode = false;
    _offlineVideoPath = null;
    _offlinePluginName = '';
    _offlineEpisodesByNumber.clear();
    _offlineDisplayRoadToOriginalRoad.clear();
    _offlineOriginalRoadToDisplayRoad.clear();
    _currentResolvedEpisode = null;
    _playbackHistoryIdentity = null;
  }

  String? get offlineVideoPath => _offlineVideoPath;

  String get offlinePluginName => _offlinePluginName;

  PlaybackHistoryIdentity? get currentHistoryIdentity =>
      _playbackHistoryIdentity;

  SyncPlayEpisodeIdentity? get currentSyncPlayEpisodeIdentity {
    final resolvedEpisode = _resolveCurrentEpisode();
    return resolvedEpisode?.toSyncPlayEpisodeIdentity(bangumiItem.id);
  }

  /// 获取当前实际的集数编号
  /// 在线模式下直接返回 currentEpisode
  /// 离线模式下从 roadList.data 中获取实际的 episodeNumber
  int get actualEpisodeNumber {
    final resolvedEpisode = _currentResolvedEpisode;
    if (resolvedEpisode != null &&
        resolvedEpisode.listIndex == currentEpisode &&
        resolvedEpisode.roadIndex == currentRoad) {
      return resolvedEpisode.historyEpisodeNumber;
    }
    return isOfflineMode
        ? _resolveOfflineEpisode(currentEpisode)?.historyEpisodeNumber ??
            currentEpisode
        : _resolveOnlineEpisode(currentEpisode)?.historyEpisodeNumber ??
            currentEpisode;
  }

  ResolvedEpisode? _resolveCurrentEpisode() {
    final resolvedEpisode = _currentResolvedEpisode;
    if (resolvedEpisode != null &&
        resolvedEpisode.listIndex == currentEpisode &&
        resolvedEpisode.roadIndex == currentRoad) {
      return resolvedEpisode;
    }
    return isOfflineMode
        ? _resolveOfflineEpisode(currentEpisode)
        : _resolveOnlineEpisode(currentEpisode);
  }

  ({int listIndex, int roadIndex})? resolveSyncPlayEpisodeIdentity(
    SyncPlayEpisodeIdentity identity,
  ) {
    if (identity.bangumiId != bangumiItem.id) {
      return null;
    }
    if (identity.isLegacy) {
      return _resolveSyncPlayListFallback(identity);
    }

    final matchedByEpisodeNumber = isOfflineMode
        ? _findOfflineEpisodeByNumber(
            identity.episodeNumber,
            preferredOriginalRoad: identity.roadIndex,
          )
        : _findSyncPlayEpisodeByNumber(
            identity.episodeNumber,
            preferredRoadIndex: identity.roadIndex,
          );
    if (matchedByEpisodeNumber != null) {
      return matchedByEpisodeNumber;
    }

    return isOfflineMode
        ? _resolveOfflineSyncPlayListFallback(identity)
        : _resolveSyncPlayListFallback(identity);
  }

  ({int listIndex, int roadIndex})? _findOfflineEpisodeByNumber(
    int episodeNumber, {
    required int preferredOriginalRoad,
  }) {
    if (episodeNumber <= 0 || roadList.isEmpty) {
      return null;
    }
    final preferredDisplayRoad =
        _offlineOriginalRoadToDisplayRoad[preferredOriginalRoad];
    final roadIndices = <int>[
      if (preferredDisplayRoad != null) preferredDisplayRoad,
      for (var i = 0; i < roadList.length; i++)
        if (i != preferredDisplayRoad) i,
    ];
    for (final roadIndex in roadIndices) {
      final match = _findOfflineEpisodeInDisplayRoad(episodeNumber, roadIndex);
      if (match != null) {
        return match;
      }
    }
    return null;
  }

  ({int listIndex, int roadIndex})? _findOfflineEpisodeInDisplayRoad(
    int episodeNumber,
    int roadIndex,
  ) {
    if (roadIndex < 0 || roadIndex >= roadList.length) {
      return null;
    }
    final index = roadList[roadIndex].data.indexOf(episodeNumber.toString());
    if (index < 0) {
      return null;
    }
    return (listIndex: index + 1, roadIndex: roadIndex);
  }

  ({int listIndex, int roadIndex})? _findSyncPlayEpisodeByNumber(
    int episodeNumber, {
    required int preferredRoadIndex,
  }) {
    if (episodeNumber <= 0 || roadList.isEmpty) {
      return null;
    }
    final roadIndices = <int>[
      if (preferredRoadIndex >= 0 && preferredRoadIndex < roadList.length)
        preferredRoadIndex,
      for (var i = 0; i < roadList.length; i++)
        if (i != preferredRoadIndex) i,
    ];

    for (final roadIndex in roadIndices) {
      final roadData = roadList[roadIndex];
      for (var listIndex = 1; listIndex <= roadData.data.length; listIndex++) {
        final resolvedEpisode = isOfflineMode
            ? _resolveOfflineEpisode(listIndex, road: roadIndex)
            : _resolveOnlineEpisode(listIndex, road: roadIndex);
        if (resolvedEpisode?.danmakuEpisodeNumber == episodeNumber) {
          return (listIndex: listIndex, roadIndex: roadIndex);
        }
      }
    }
    return null;
  }

  ({int listIndex, int roadIndex})? _resolveSyncPlayListFallback(
    SyncPlayEpisodeIdentity identity,
  ) {
    if (_isValidSyncPlayListTarget(identity.listIndex, identity.roadIndex)) {
      return (listIndex: identity.listIndex, roadIndex: identity.roadIndex);
    }
    for (var roadIndex = 0; roadIndex < roadList.length; roadIndex++) {
      if (_isValidSyncPlayListTarget(identity.listIndex, roadIndex)) {
        return (listIndex: identity.listIndex, roadIndex: roadIndex);
      }
    }
    return null;
  }

  ({int listIndex, int roadIndex})? _resolveOfflineSyncPlayListFallback(
    SyncPlayEpisodeIdentity identity,
  ) {
    final displayRoad = _offlineOriginalRoadToDisplayRoad[identity.roadIndex];
    if (displayRoad != null &&
        _isValidSyncPlayListTarget(identity.listIndex, displayRoad)) {
      return (listIndex: identity.listIndex, roadIndex: displayRoad);
    }
    return _resolveSyncPlayListFallback(identity);
  }

  bool _isValidSyncPlayListTarget(int listIndex, int roadIndex) {
    return roadIndex >= 0 &&
        roadIndex < roadList.length &&
        listIndex > 0 &&
        listIndex <= roadList[roadIndex].data.length;
  }

  int getHistoryOffsetFor(PlaybackHistoryIdentity identity) {
    final playResume =
        setting.get(SettingBoxKey.playResume, defaultValue: true);
    if (playResume != true) {
      return 0;
    }
    return historyController
            .findProgress(
              identity.bangumiItem,
              identity.pluginName,
              identity.episodeNumber,
              entryKind: identity.entryKind,
            )
            ?.progress
            .inSeconds ??
        0;
  }

  void _setOnlineHistoryIdentity(ResolvedEpisode episode) {
    _playbackHistoryIdentity = PlaybackHistoryIdentity.online(
      bangumiItem: bangumiItem,
      pluginName: currentPlugin.name,
      episodeNumber: episode.historyEpisodeNumber,
      episodeTitle: episode.displayTitle,
      road: episode.originalRoadIndex,
      onlineBangumiSrc: src,
      episodePageUrl: episode.episodePageUrl,
    );
  }

  void _setOfflineHistoryIdentity(ResolvedEpisode episode) {
    _playbackHistoryIdentity = PlaybackHistoryIdentity.offline(
      bangumiItem: bangumiItem,
      pluginName: _offlinePluginName,
      episodeNumber: episode.historyEpisodeNumber,
      episodeTitle: episode.displayTitle,
      road: episode.originalRoadIndex,
      episodePageUrl: episode.episodePageUrl,
    );
  }

  ResolvedEpisode? _resolveOnlineEpisode(int episode, {int? road}) {
    final targetRoad = road ?? currentRoad;
    if (roadList.isEmpty || targetRoad < 0 || targetRoad >= roadList.length) {
      return null;
    }
    final roadData = roadList[targetRoad];
    final index = episode - 1;
    if (index < 0 ||
        index >= roadData.data.length ||
        index >= roadData.identifier.length) {
      return null;
    }
    final displayTitle = roadData.identifier[index];
    return ResolvedEpisode.online(
      listIndex: episode,
      roadIndex: targetRoad,
      displayTitle: displayTitle,
      episodePageUrl: roadData.data[index],
    );
  }

  ResolvedEpisode? _resolveOfflineEpisode(int episode, {int? road}) {
    final targetRoad = road ?? currentRoad;
    if (roadList.isEmpty || targetRoad < 0 || targetRoad >= roadList.length) {
      return null;
    }
    final roadData = roadList[targetRoad];
    final index = episode - 1;
    if (index < 0 || index >= roadData.data.length) {
      return null;
    }
    final episodeNumber = int.tryParse(roadData.data[index]);
    if (episodeNumber == null) {
      return null;
    }
    final downloadEpisode = _offlineEpisodesByNumber[episodeNumber];
    final titleFromRoad =
        index < roadData.identifier.length ? roadData.identifier[index] : '';
    final episodeTitle = downloadEpisode?.episodeName.isNotEmpty == true
        ? downloadEpisode!.episodeName
        : (titleFromRoad.isNotEmpty ? titleFromRoad : '第$episodeNumber集');
    return ResolvedEpisode.offline(
      listIndex: episode,
      roadIndex: targetRoad,
      displayTitle: episodeTitle,
      episodePageUrl: downloadEpisode?.episodePageUrl ?? '',
      episodeNumber: episodeNumber,
      originalRoadIndex: downloadEpisode?.road ??
          _offlineDisplayRoadToOriginalRoad[targetRoad] ??
          targetRoad,
    );
  }

  Future<void> changeEpisode(
    int episode, {
    int currentRoad = 0,
    int offset = 0,
    required PlayerController playerController,
  }) async {
    errorMessage = null;

    if (isOfflineMode) {
      await _changeOfflineEpisode(
        episode,
        offset,
        currentRoad: currentRoad,
        playerController: playerController,
      );
      return;
    }

    final resolvedEpisode = _resolveOnlineEpisode(episode, road: currentRoad);
    if (resolvedEpisode == null) {
      loading = false;
      KazumiLogger().e(
          'VideoPageController: failed to resolve online episode. road=$currentRoad, episode=$episode');
      KazumiDialog.showToast(message: '集数解析失败');
      return;
    }

    currentEpisode = resolvedEpisode.listIndex;
    this.currentRoad = resolvedEpisode.roadIndex;
    _currentResolvedEpisode = resolvedEpisode;
    _setOnlineHistoryIdentity(resolvedEpisode);

    KazumiLogger()
        .i('VideoPageController: changed to ${resolvedEpisode.displayTitle}');
    String urlItem = resolvedEpisode.episodePageUrl;
    if (urlItem.contains(currentPlugin.baseUrl) ||
        urlItem.contains(currentPlugin.baseUrl.replaceAll('https', 'http'))) {
      urlItem = urlItem;
    } else {
      urlItem = currentPlugin.baseUrl + urlItem;
    }

    await _resolveWithProvider(
      urlItem,
      offset,
      resolvedEpisode: resolvedEpisode,
      playerController: playerController,
    );
  }

  /// 离线模式下切换集数
  /// [episode] 是列表中的位置（从 1 开始），需要从 roadList.data 中获取实际的 episodeNumber
  Future<void> _changeOfflineEpisode(
    int episode,
    int offset, {
    required int currentRoad,
    required PlayerController playerController,
  }) async {
    final resolvedEpisode = _resolveOfflineEpisode(episode, road: currentRoad);
    if (resolvedEpisode == null) {
      loading = false;
      KazumiLogger().e(
          'VideoPageController: failed to resolve offline episode. road=$currentRoad, episode=$episode');
      KazumiDialog.showToast(message: '集数解析失败');
      return;
    }

    final localPath = _getLocalVideoPath(
      bangumiItem.id,
      _offlinePluginName,
      resolvedEpisode.historyEpisodeNumber,
    );
    if (localPath == null) {
      loading = false;
      KazumiDialog.showToast(message: '该集数未下载');
      return;
    }
    currentEpisode = resolvedEpisode.listIndex;
    this.currentRoad = resolvedEpisode.roadIndex;
    _currentResolvedEpisode = resolvedEpisode;
    _offlineVideoPath = localPath;
    _setOfflineHistoryIdentity(resolvedEpisode);
    loading = false;
    final resolvedOffset =
        offset > 0 ? offset : getHistoryOffsetFor(_playbackHistoryIdentity!);

    KazumiLogger().i(
        'VideoPageController: offline episode changed to ${resolvedEpisode.historyEpisodeNumber} (index: $episode), path: $localPath');

    final params = PlaybackInitParams(
      videoUrl: localPath,
      offset: resolvedOffset,
      isLocalPlayback: true,
      bangumiId: bangumiItem.id,
      pluginName: _offlinePluginName,
      episode: resolvedEpisode.historyEpisodeNumber,
      danmakuEpisodeNumber: resolvedEpisode.danmakuEpisodeNumber,
      httpHeaders: {},
      adBlockerEnabled: false,
      episodeTitle: resolvedEpisode.displayTitle,
      referer: '',
      currentRoad: resolvedEpisode.roadIndex,
      syncPlayEpisodeIdentity:
          resolvedEpisode.toSyncPlayEpisodeIdentity(bangumiItem.id),
      coverUrl: bangumiItem.images['large'],
      bangumiName:
          bangumiItem.nameCn.isNotEmpty ? bangumiItem.nameCn : bangumiItem.name,
    );

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
  Future<void> _resolveWithProvider(
    String url,
    int offset, {
    required ResolvedEpisode resolvedEpisode,
    required PlayerController playerController,
  }) async {
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
        episode: resolvedEpisode.historyEpisodeNumber,
        danmakuEpisodeNumber: resolvedEpisode.danmakuEpisodeNumber,
        httpHeaders: {
          'user-agent': currentPlugin.userAgent.isEmpty
              ? Utils.getRandomUA()
              : currentPlugin.userAgent,
          if (currentPlugin.referer.isNotEmpty)
            'referer': currentPlugin.referer,
        },
        adBlockerEnabled: forceAdBlocker || currentPlugin.adBlocker,
        episodeTitle: resolvedEpisode.displayTitle,
        referer: currentPlugin.referer,
        currentRoad: resolvedEpisode.roadIndex,
        syncPlayEpisodeIdentity:
            resolvedEpisode.toSyncPlayEpisodeIdentity(bangumiItem.id),
        coverUrl: bangumiItem.images['large'],
        bangumiName: bangumiItem.nameCn.isNotEmpty
            ? bangumiItem.nameCn
            : bangumiItem.name,
      );

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
    final int requestId = ++_episodeCommentsRequestId;
    final EpisodeInfo latestEpisodeInfo =
        await BangumiApi.getBangumiEpisodeByID(id, episode);
    final value =
        await BangumiApi.getBangumiCommentsByEpisodeID(latestEpisodeInfo.id);
    if (requestId != _episodeCommentsRequestId) {
      return;
    }
    episodeInfo = latestEpisodeInfo;
    final commentsList = value.commentList;
    if (!isCommentsAscending) {
      commentsList
          .sort((a, b) => b.comment.createdAt.compareTo(a.comment.createdAt));
    } else {
      commentsList
          .sort((a, b) => a.comment.createdAt.compareTo(b.comment.createdAt));
    }
    episodeCommentsList = ObservableList.of(commentsList);
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

class OfflineRoadListSnapshot {
  const OfflineRoadListSnapshot({
    required this.roads,
    required this.episodesByNumber,
    required this.displayRoadToOriginalRoad,
    required this.originalRoadToDisplayRoad,
  });

  final List<Road> roads;
  final Map<int, DownloadEpisode> episodesByNumber;
  final Map<int, int> displayRoadToOriginalRoad;
  final Map<int, int> originalRoadToDisplayRoad;

  ({int listIndex, int roadIndex})? findEpisodeByNumber(
    int episodeNumber, {
    int? preferredOriginalRoad,
  }) {
    if (episodeNumber <= 0 || roads.isEmpty) {
      return null;
    }
    final preferredDisplayRoad = preferredOriginalRoad == null
        ? null
        : originalRoadToDisplayRoad[preferredOriginalRoad];
    final roadIndices = <int>[
      if (preferredDisplayRoad != null) preferredDisplayRoad,
      for (var i = 0; i < roads.length; i++)
        if (i != preferredDisplayRoad) i,
    ];
    for (final roadIndex in roadIndices) {
      final index = roads[roadIndex].data.indexOf(episodeNumber.toString());
      if (index >= 0) {
        return (listIndex: index + 1, roadIndex: roadIndex);
      }
    }
    return null;
  }
}

OfflineRoadListSnapshot buildOfflineRoadListSnapshot(
  List<DownloadEpisode> episodes,
) {
  final groupedEpisodes = <int, List<DownloadEpisode>>{};
  final episodesByNumber = <int, DownloadEpisode>{};

  for (final episode in episodes) {
    episodesByNumber[episode.episodeNumber] = episode;
    groupedEpisodes.putIfAbsent(episode.road, () => []).add(episode);
  }

  final originalRoads = groupedEpisodes.keys.toList()..sort();
  final roads = <Road>[];
  final displayRoadToOriginalRoad = <int, int>{};
  final originalRoadToDisplayRoad = <int, int>{};

  for (final originalRoad in originalRoads) {
    final roadEpisodes = groupedEpisodes[originalRoad]!
      ..sort((a, b) => a.episodeNumber.compareTo(b.episodeNumber));
    final displayRoad = roads.length;
    displayRoadToOriginalRoad[displayRoad] = originalRoad;
    originalRoadToDisplayRoad[originalRoad] = displayRoad;
    roads.add(Road(
      name: originalRoad >= 0
          ? '播放列表${originalRoad + 1}'
          : '播放列表${displayRoad + 1}',
      data: roadEpisodes.map((e) => e.episodeNumber.toString()).toList(),
      identifier: roadEpisodes
          .map((e) =>
              e.episodeName.isNotEmpty ? e.episodeName : '第${e.episodeNumber}集')
          .toList(),
    ));
  }

  return OfflineRoadListSnapshot(
    roads: roads,
    episodesByNumber: episodesByNumber,
    displayRoadToOriginalRoad: displayRoadToOriginalRoad,
    originalRoadToDisplayRoad: originalRoadToDisplayRoad,
  );
}

class ResolvedEpisode {
  const ResolvedEpisode({
    required this.listIndex,
    required this.roadIndex,
    required this.displayTitle,
    required this.episodePageUrl,
    required this.historyEpisodeNumber,
    required this.danmakuEpisodeNumber,
    required this.originalRoadIndex,
  });

  final int listIndex;
  final int roadIndex;
  final String displayTitle;
  final String episodePageUrl;
  final int historyEpisodeNumber;
  final int danmakuEpisodeNumber;
  final int originalRoadIndex;

  factory ResolvedEpisode.online({
    required int listIndex,
    required int roadIndex,
    required String displayTitle,
    required String episodePageUrl,
  }) {
    final parsedEpisodeNumber = Utils.extractEpisodeNumber(displayTitle);
    return ResolvedEpisode(
      listIndex: listIndex,
      roadIndex: roadIndex,
      displayTitle: displayTitle,
      episodePageUrl: episodePageUrl,
      historyEpisodeNumber: listIndex,
      danmakuEpisodeNumber:
          parsedEpisodeNumber > 0 ? parsedEpisodeNumber : listIndex,
      originalRoadIndex: roadIndex,
    );
  }

  const factory ResolvedEpisode.offline({
    required int listIndex,
    required int roadIndex,
    required String displayTitle,
    required String episodePageUrl,
    required int episodeNumber,
    required int originalRoadIndex,
  }) = _OfflineResolvedEpisode;

  SyncPlayEpisodeIdentity toSyncPlayEpisodeIdentity(int bangumiId) {
    return SyncPlayEpisodeIdentity(
      bangumiId: bangumiId,
      roadIndex: originalRoadIndex,
      listIndex: listIndex,
      episodeNumber: danmakuEpisodeNumber,
    );
  }
}

class _OfflineResolvedEpisode extends ResolvedEpisode {
  const _OfflineResolvedEpisode({
    required super.listIndex,
    required super.roadIndex,
    required super.displayTitle,
    required super.episodePageUrl,
    required int episodeNumber,
    required super.originalRoadIndex,
  }) : super(
          historyEpisodeNumber: episodeNumber,
          danmakuEpisodeNumber: episodeNumber,
        );
}
