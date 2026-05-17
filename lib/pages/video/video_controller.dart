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
import 'package:kazumi/providers/video/providers.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:mobx/mobx.dart';
import 'package:kazumi/utils/utils.dart';
import 'package:kazumi/utils/logger.dart';
import 'package:window_manager/window_manager.dart';
import 'package:kazumi/modules/bangumi/episode_item.dart';
import 'package:kazumi/modules/comments/comment_item.dart';
import 'package:kazumi/modules/comments/comment_response.dart';
import 'package:kazumi/request/apis/bangumi_api.dart';
import 'package:dio/dio.dart';
import 'package:hive_ce/hive.dart';
import 'package:kazumi/utils/storage.dart';

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
  final Box setting = GStorage.setting;

  WebViewVideoSourceProvider? _videoSourceProvider;

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
    var selectedRoad = road;
    title =
        bangumiItem.nameCn.isNotEmpty ? bangumiItem.nameCn : bangumiItem.name;
    isOfflineMode = true;
    loading = false;

    _buildOfflineRoadList(downloadedEpisodes);

    if (selectedRoad < 0 || selectedRoad >= roadList.length) {
      selectedRoad = 0;
    }

    // Offline road data stores the real episode number, while selection uses
    // the 1-based position shown in the playlist.
    final index = roadList[selectedRoad].data.indexOf(episodeNumber.toString());
    final selected = VideoEpisodeSelection(
      episode: index >= 0 ? index + 1 : 1,
      road: selectedRoad,
    );
    selectedEpisode = selected;
    playingEpisode = null;
    commentsEpisode = commentEpisodeForSelection(selected);
    KazumiLogger().i(
        'VideoPageController: initialized for offline playback, episode $episodeNumber (position: ${selected.episode})');
  }

  void _buildOfflineRoadList(List<DownloadEpisode> episodes) {
    roadList.clear();
    episodes.sort((a, b) => a.episodeNumber.compareTo(b.episodeNumber));
    roadList.add(Road(
      name: '播放列表1',
      data: episodes.map((e) => e.episodeNumber.toString()).toList(),
      identifier: episodes
          .map((e) =>
              e.episodeName.isNotEmpty ? e.episodeName : '第${e.episodeNumber}集')
          .toList(),
    ));
  }

  void resetOfflineMode() {
    isOfflineMode = false;
    _offlinePluginName = '';
  }

  String get offlinePluginName => _offlinePluginName;

  int get playingActualEpisodeNumber =>
      actualEpisodeNumberForSelection(playbackEpisode);

  int actualEpisodeNumberForSelection(VideoEpisodeSelection selection) {
    if (isOfflineMode && roadList.isNotEmpty) {
      try {
        return int.parse(roadList[selection.road].data[selection.episode - 1]);
      } catch (_) {
        return selection.episode;
      }
    }
    return selection.episode;
  }

  int commentEpisodeForSelection(VideoEpisodeSelection selection) {
    if (roadList.isEmpty ||
        selection.road < 0 ||
        selection.road >= roadList.length) {
      return selection.episode;
    }
    final road = roadList[selection.road];
    final index = selection.episode - 1;
    if (index < 0 || index >= road.identifier.length) {
      return selection.episode;
    }

    final extractedEpisode = Utils.extractEpisodeNumber(road.identifier[index]);
    if (extractedEpisode == 0 ||
        (!isOfflineMode && extractedEpisode > road.identifier.length)) {
      return isOfflineMode
          ? actualEpisodeNumberForSelection(selection)
          : selection.episode;
    }
    return extractedEpisode;
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
    _videoSourceProvider?.cancel();
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

    String chapterName =
        roadList[selection.road].identifier[selection.episode - 1];
    KazumiLogger().i('VideoPageController: changed to $chapterName');
    String urlItem = roadList[selection.road].data[selection.episode - 1];
    if (!urlItem.contains(currentPlugin.baseUrl) &&
        !urlItem.contains(currentPlugin.baseUrl.replaceAll('https', 'http'))) {
      urlItem = currentPlugin.baseUrl + urlItem;
    }

    await _resolveWithProvider(
      urlItem,
      offset,
      selection: selection,
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
    final actualEpisodeNumber =
        int.tryParse(roadList[selection.road].data[selection.episode - 1]);
    if (actualEpisodeNumber == null) {
      KazumiLogger().e(
          'VideoPageController: failed to parse episode number from roadList data: ${roadList[selection.road].data[selection.episode - 1]}');
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
    if (session.isStale) {
      return;
    }
    loading = false;

    KazumiLogger().i(
        'VideoPageController: offline episode changed to $actualEpisodeNumber (index: ${selection.episode}), path: $localPath');

    final params = PlaybackInitParams(
      videoUrl: localPath,
      offset: offset,
      isLocalPlayback: true,
      bangumiId: bangumiItem.id,
      pluginName: _offlinePluginName,
      episode: actualEpisodeNumber,
      httpHeaders: {},
      adBlockerEnabled: false,
      episodeTitle: roadList[selection.road].identifier[selection.episode - 1],
      referer: '',
      currentRoad: selection.road,
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
    try {
      final episodeFromTitle = Utils.extractEpisodeNumber(params.episodeTitle);
      if (episodeFromTitle != 0) {
        return episodeFromTitle;
      }
    } catch (e) {
      KazumiLogger().e(
        'VideoPageController: failed to extract episode number from title',
        error: e,
      );
    }
    return params.episode;
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
        playerController.danmaku.applyDanmakuLoad(result);
      }
    } catch (e) {
      if (session.isActive && danmakuSession.isActive) {
        playerController.danmaku.finishDanmakuLoad();
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

  Future<void> _resolveWithProvider(
    String url,
    int offset, {
    required VideoEpisodeSelection selection,
    required _AsyncSession session,
    required PlayerController playerController,
  }) async {
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

      if (session.isStale) {
        return;
      }
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
        episode: selection.episode,
        httpHeaders: {
          'user-agent': currentPlugin.userAgent.isEmpty
              ? Utils.getRandomUA()
              : currentPlugin.userAgent,
          if (currentPlugin.referer.isNotEmpty)
            'referer': currentPlugin.referer,
        },
        adBlockerEnabled: forceAdBlocker || currentPlugin.adBlocker,
        episodeTitle:
            roadList[selection.road].identifier[selection.episode - 1],
        referer: currentPlugin.referer,
        currentRoad: selection.road,
        coverUrl: bangumiItem.images['large'],
        bangumiName: bangumiItem.nameCn.isNotEmpty
            ? bangumiItem.nameCn
            : bangumiItem.name,
      );

      final initialized = await playerController.init(params);
      if (session.isActive && initialized) {
        playingEpisode = selection;
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
    _videoSourceProvider?.dispose();
    _videoSourceProvider = null;
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
