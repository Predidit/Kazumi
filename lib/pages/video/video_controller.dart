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
import 'package:kazumi/services/download/download_manager.dart';
import 'package:kazumi/services/video_source/services.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:mobx/mobx.dart';
import 'package:kazumi/services/logging/logger.dart';
import 'package:window_manager/window_manager.dart';
import 'package:kazumi/modules/bangumi/episode_item.dart';
import 'package:kazumi/modules/comments/comment_item.dart';
import 'package:kazumi/modules/comments/comment_response.dart';
import 'package:kazumi/request/apis/bangumi_api.dart';
import 'package:dio/dio.dart';
import 'package:kazumi/services/storage/storage.dart';
import 'package:kazumi/utils/device.dart';
import 'package:kazumi/utils/episode_url.dart';
import 'package:kazumi/utils/http_headers.dart';
import 'package:kazumi/utils/media.dart';
import 'package:kazumi/services/platform/display_mode_service.dart';

part 'video_controller.g.dart';

class VideoPageController = _VideoPageController with _$VideoPageController;

// Controller-local ownership token for async work. Keep it private so playback
// and comment freshness checks stay inside VideoPageController instead of
// leaking through player, danmaku, or widget APIs.
class _AsyncSessionOwner {
  int _version = 0;

  _AsyncSession begin() {
    return _AsyncSession(this, ++_version);
  }

  void cancel() {
    _version++;
  }

  bool owns(_AsyncSession session) {
    return identical(session.owner, this) && session.version == _version;
  }
}

class _AsyncSession {
  const _AsyncSession(this.owner, this.version);

  final _AsyncSessionOwner owner;
  final int version;

  bool get isActive => owner.owns(this);

  bool get isStale => !isActive;
}

class VideoEpisodeSelection {
  const VideoEpisodeSelection({
    required this.episode,
    required this.road,
  });

  final int episode;
  final int road;

  @override
  bool operator ==(Object other) {
    return other is VideoEpisodeSelection &&
        other.episode == episode &&
        other.road == road;
  }

  @override
  int get hashCode => Object.hash(episode, road);

  @override
  String toString() {
    return 'VideoEpisodeSelection(episode: $episode, road: $road)';
  }
}

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
  VideoEpisodeSelection selectedEpisode =
      const VideoEpisodeSelection(episode: 1, road: 0);

  @observable
  VideoEpisodeSelection? playingEpisode;

  @observable
  int commentsEpisode = 1;

  void resetEpisodeState({int episode = 1, int road = 0}) {
    final selection = VideoEpisodeSelection(episode: episode, road: road);
    selectedEpisode = selection;
    playingEpisode = null;
    commentsEpisode = commentEpisodeForSelection(selection);
  }

  VideoEpisodeSelection get playbackEpisode =>
      playingEpisode ?? selectedEpisode;

  @observable
  bool isFullscreen = false;

  @observable
  bool isCommentsAscending = false;

  // Playback, automatic danmaku loading, and comment loading have separate
  // owners. Manual danmaku selection can cancel auto danmaku without touching
  // playback; comment refreshes never cancel playback.
  final _AsyncSessionOwner _playbackSessions = _AsyncSessionOwner();
  final _AsyncSessionOwner _danmakuSessions = _AsyncSessionOwner();
  final _AsyncSessionOwner _commentSessions = _AsyncSessionOwner();

  @observable
  bool isPip = false;

  @observable
  bool showTabBody = true;

  @observable
  int historyOffset = 0;

  @observable
  bool isOfflineMode = false;

  PlaybackHistoryIdentity? _playbackHistoryIdentity;
  final Map<int, DownloadEpisode> _offlineEpisodesByNumber = {};
  final Map<int, int> _offlineDisplayRoadToOriginalRoad = {};
  final Map<int, int> _offlineOriginalRoadToDisplayRoad = {};

  /// 和 bangumiItem 中的标题不同，此标题来自于视频源
  String title = '';

  String src = '';

  @observable
  var roadList = ObservableList<Road>();

  late Plugin currentPlugin;

  String _offlinePluginName = '';

  CancelToken? _queryRoadsCancelToken;

  final PluginsController pluginsController = Modular.get<PluginsController>();
  final HistoryController historyController = Modular.get<HistoryController>();
  final IDownloadRepository downloadRepository =
      Modular.get<IDownloadRepository>();
  final IDownloadManager downloadManager = Modular.get<IDownloadManager>();

  WebViewVideoSourceService? _videoSourceService;

  final StreamController<String> _logStreamController =
      StreamController<String>.broadcast();

  Stream<String> get logStream => _logStreamController.stream;

  StreamSubscription<String>? _logSubscription;

  void initForOfflinePlayback({
    required BangumiItem bangumiItem,
    required String pluginName,
    required int episodeNumber,
    required int road,
    required List<DownloadEpisode> downloadedEpisodes,
  }) {
    this.bangumiItem = bangumiItem;
    _offlinePluginName = pluginName;
    title =
        bangumiItem.nameCn.isNotEmpty ? bangumiItem.nameCn : bangumiItem.name;
    isOfflineMode = true;
    loading = false;

    _buildOfflineRoadList(downloadedEpisodes);

    final target = _findOfflineEpisodeByNumber(
      episodeNumber,
      preferredOriginalRoad: road,
    );
    final selected = VideoEpisodeSelection(
      episode: target?.listIndex ?? 1,
      road: target?.roadIndex ?? 0,
    );
    selectedEpisode = selected;
    playingEpisode = null;
    commentsEpisode = commentEpisodeForSelection(selected);
    final resolvedEpisode = _resolveOfflineEpisode(
      selected.episode,
      road: selected.road,
    );
    if (resolvedEpisode != null) {
      _setOfflineHistoryIdentity(resolvedEpisode);
    } else {
      _playbackHistoryIdentity = null;
    }
    KazumiLogger().i(
        'VideoPageController: initialized for offline playback, episode $episodeNumber (position: ${selected.episode})');
  }

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
    _offlinePluginName = '';
    _offlineEpisodesByNumber.clear();
    _offlineDisplayRoadToOriginalRoad.clear();
    _offlineOriginalRoadToDisplayRoad.clear();
    _playbackHistoryIdentity = null;
  }

  String get offlinePluginName => _offlinePluginName;

  PlaybackHistoryIdentity? get currentHistoryIdentity =>
      _playbackHistoryIdentity;

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

  int getHistoryOffsetFor(PlaybackHistoryIdentity identity) {
    final playResume = GStorage.getSetting(SettingsKeys.playResume);
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
    final targetRoad = road ?? selectedEpisode.road;
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
    final targetRoad = road ?? selectedEpisode.road;
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

  int commentEpisodeForSelection(VideoEpisodeSelection selection) {
    final resolvedEpisode = isOfflineMode
        ? _resolveOfflineEpisode(selection.episode, road: selection.road)
        : _resolveOnlineEpisode(selection.episode, road: selection.road);
    return resolvedEpisode?.danmakuEpisodeNumber ?? selection.episode;
  }

  Future<void> changeEpisode(
    int episode, {
    int currentRoad = 0,
    int offset = 0,
    required PlayerController playerController,
  }) async {
    final session = _playbackSessions.begin();
    final selection = VideoEpisodeSelection(
      episode: episode,
      road: currentRoad,
    );
    selectedEpisode = selection;
    playingEpisode = null;
    commentsEpisode = commentEpisodeForSelection(selection);
    resetEpisodeComments();
    _danmakuSessions.cancel();
    playerController.danmaku.finishDanmakuLoad();
    _videoSourceService?.cancel();
    loading = true;
    errorMessage = null;

    await playerController.stop();
    if (session.isStale) {
      return;
    }

    if (isOfflineMode) {
      await _changeOfflineEpisode(
        selection,
        offset,
        session: session,
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

    selectedEpisode = VideoEpisodeSelection(
      episode: resolvedEpisode.listIndex,
      road: resolvedEpisode.roadIndex,
    );
    commentsEpisode = commentEpisodeForSelection(selectedEpisode);
    _setOnlineHistoryIdentity(resolvedEpisode);

    KazumiLogger()
        .i('VideoPageController: changed to ${resolvedEpisode.displayTitle}');
    final urlItem = normalizeEpisodeUrl(
      currentPlugin.baseUrl,
      resolvedEpisode.episodePageUrl,
    );

    await _resolveWithVideoSourceService(
      urlItem,
      offset,
      resolvedEpisode: resolvedEpisode,
      session: session,
      playerController: playerController,
    );
  }

  Future<void> _changeOfflineEpisode(
    VideoEpisodeSelection selection,
    int offset, {
    required _AsyncSession session,
    required PlayerController playerController,
  }) async {
    final resolvedEpisode =
        _resolveOfflineEpisode(selection.episode, road: selection.road);
    if (resolvedEpisode == null) {
      loading = false;
      KazumiLogger().e(
          'VideoPageController: failed to resolve offline episode. road=${selection.road}, episode=${selection.episode}');
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
    selectedEpisode = VideoEpisodeSelection(
      episode: resolvedEpisode.listIndex,
      road: resolvedEpisode.roadIndex,
    );
    commentsEpisode = commentEpisodeForSelection(selectedEpisode);
    _setOfflineHistoryIdentity(resolvedEpisode);
    if (session.isStale) {
      return;
    }
    loading = false;
    final resolvedOffset =
        offset > 0 ? offset : getHistoryOffsetFor(_playbackHistoryIdentity!);

    KazumiLogger().i(
        'VideoPageController: offline episode changed to ${resolvedEpisode.historyEpisodeNumber} (index: ${selection.episode}), path: $localPath');

    final params = PlaybackInitParams(
      videoUrl: localPath,
      offset: resolvedOffset,
      isLocalPlayback: true,
      bangumiId: bangumiItem.id,
      pluginName: _offlinePluginName,
      episode: resolvedEpisode.listIndex,
      danmakuEpisodeNumber: resolvedEpisode.danmakuEpisodeNumber,
      httpHeaders: {},
      adBlockerEnabled: false,
      episodeTitle: resolvedEpisode.displayTitle,
      referer: '',
      currentRoad: resolvedEpisode.roadIndex,
      coverUrl: bangumiItem.images['large'],
      bangumiName:
          bangumiItem.nameCn.isNotEmpty ? bangumiItem.nameCn : bangumiItem.name,
    );

    final initialized = await playerController.init(params);
    if (session.isActive && initialized) {
      playingEpisode = selection;
      unawaited(_loadPlaybackDanmaku(playerController, params, session));
    } else if (session.isActive) {
      _playbackSessions.cancel();
    }
  }

  int _danmakuEpisodeForPlayback(PlaybackInitParams params) {
    return params.danmakuEpisodeNumber;
  }

  Future<void> _loadPlaybackDanmaku(
    PlayerController playerController,
    PlaybackInitParams params,
    _AsyncSession session,
  ) async {
    final danmakuSession = _danmakuSessions.begin();
    playerController.danmaku.beginDanmakuLoad();
    try {
      final result = await playerController.danmaku.fetchDanmaku(
        params.bangumiId,
        params.pluginName,
        _danmakuEpisodeForPlayback(params),
      );
      if (session.isActive && danmakuSession.isActive) {
        if (result.hasDanmakus) {
          final bool enableDanmaku =
              GStorage.getSetting(SettingsKeys.danmakuEnabledByDefault);
          playerController.danmaku.applyDanmakuLoad(
            result,
            enableDanmaku: enableDanmaku,
          );
        } else {
          playerController.danmaku.applyUnavailableDanmakuLoad(result);
          if (result.isFailed) {
            KazumiDialog.showToast(message: '弹幕加载失败，可手动检索');
          }
        }
      }
    } catch (e) {
      if (session.isActive && danmakuSession.isActive) {
        playerController.danmaku.finishDanmakuLoad(disableDanmaku: true);
        KazumiDialog.showToast(message: '弹幕加载失败，可手动检索');
      }
      KazumiLogger().w('VideoPageController: failed to load danmaku', error: e);
    }
  }

  void cancelAutomaticDanmakuLoad() {
    _danmakuSessions.cancel();
  }

  String? _getLocalVideoPath(
      int bangumiId, String pluginName, int episodeNumber) {
    final episode =
        downloadRepository.getEpisode(bangumiId, pluginName, episodeNumber);
    return downloadManager.getLocalVideoPath(episode);
  }

  Future<void> _resolveWithVideoSourceService(
    String url,
    int offset, {
    required ResolvedEpisode resolvedEpisode,
    required _AsyncSession session,
    required PlayerController playerController,
  }) async {
    _videoSourceService ??= WebViewVideoSourceService();

    await _logSubscription?.cancel();
    _logSubscription = _videoSourceService!.onLog.listen((log) {
      if (!_logStreamController.isClosed) {
        _logStreamController.add(log);
      }
    });

    try {
      final source = await _videoSourceService!.resolve(
        url,
        useLegacyParser: currentPlugin.useLegacyParser,
        offset: offset,
      );

      if (session.isStale) {
        return;
      }
      loading = false;
      KazumiLogger()
          .i('VideoPageController: resolved video URL: ${source.url}');

      final bool forceAdBlocker =
          GStorage.getSetting(SettingsKeys.forceAdBlocker);

      final params = PlaybackInitParams(
        videoUrl: source.url,
        offset: source.offset,
        isLocalPlayback: false,
        bangumiId: bangumiItem.id,
        pluginName: currentPlugin.name,
        episode: resolvedEpisode.listIndex,
        danmakuEpisodeNumber: resolvedEpisode.danmakuEpisodeNumber,
        httpHeaders: {
          'user-agent': currentPlugin.userAgent.isEmpty
              ? getRandomUA()
              : currentPlugin.userAgent,
          if (currentPlugin.referer.isNotEmpty)
            'referer': currentPlugin.referer,
        },
        adBlockerEnabled: forceAdBlocker || currentPlugin.adBlocker,
        episodeTitle: resolvedEpisode.displayTitle,
        referer: currentPlugin.referer,
        currentRoad: resolvedEpisode.roadIndex,
        coverUrl: bangumiItem.images['large'],
        bangumiName: bangumiItem.nameCn.isNotEmpty
            ? bangumiItem.nameCn
            : bangumiItem.name,
      );

      final initialized = await playerController.init(params);
      if (session.isActive && initialized) {
        playingEpisode = VideoEpisodeSelection(
          episode: resolvedEpisode.listIndex,
          road: resolvedEpisode.roadIndex,
        );
        unawaited(_loadPlaybackDanmaku(playerController, params, session));
      } else if (session.isActive) {
        _playbackSessions.cancel();
      }
    } on VideoSourceTimeoutException {
      if (session.isStale) {
        return;
      }
      loading = false;
      errorMessage = '视频解析超时，请重试';
    } on VideoSourceCancelledException {
      KazumiLogger().i('VideoPageController: video URL resolution cancelled');
    } catch (e) {
      if (session.isStale) {
        return;
      }
      loading = false;
      errorMessage = '视频解析失败：${e.toString()}';
    }
  }

  void cancelVideoSourceResolution() {
    _playbackSessions.cancel();
    _danmakuSessions.cancel();
    _logSubscription?.cancel();
    _logSubscription = null;
    if (!_logStreamController.isClosed) {
      _logStreamController.close();
    }
    final videoSourceService = _videoSourceService;
    _videoSourceService = null;
    if (videoSourceService != null) {
      unawaited(videoSourceService.dispose());
    }
  }

  void resetEpisodeComments() {
    _commentSessions.cancel();
    episodeInfo.reset();
    episodeCommentsList.clear();
  }

  Future<bool> queryBangumiEpisodeCommentsByID(int id, int episode) async {
    final session = _commentSessions.begin();
    final EpisodeInfo latestEpisodeInfo;
    try {
      latestEpisodeInfo = await BangumiApi.getBangumiEpisodeByID(id, episode);
    } catch (_) {
      if (session.isStale) {
        return false;
      }
      rethrow;
    }
    if (session.isStale) {
      return false;
    }
    final EpisodeCommentResponse value;
    try {
      value =
          await BangumiApi.getBangumiCommentsByEpisodeID(latestEpisodeInfo.id);
    } catch (_) {
      if (session.isStale) {
        return false;
      }
      rethrow;
    }
    if (session.isStale) {
      return false;
    }
    commentsEpisode = episode;
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
    return true;
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
    DisplayModeService.enterFullScreen(lockOrientation: false);
  }

  void exitFullScreen() {
    isFullscreen = false;
    DisplayModeService.exitFullScreen();
  }

  void isDesktopFullscreen() async {
    if (isDesktop()) {
      isFullscreen = await windowManager.isFullScreen();
    }
  }

  void handleOnEnterFullScreen() async {
    isFullscreen = true;
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
    final parsedEpisodeNumber = extractEpisodeNumber(displayTitle);
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
