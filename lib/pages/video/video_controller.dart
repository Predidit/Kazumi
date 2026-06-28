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

/// 按订阅规则产出的稳定身份 [EpisodeIdentity.stableId] 定位 `(线路, 列表位次)`。
///
/// 取代原先“用 URL 字符串在 roadList 里 indexOf 反查”的做法：因 stableId 与域名/
/// 协议/列表顺序无关，源站换域名或列表重排后仍能命中同一集。
VideoEpisodeSelection? findEpisodeSelectionByStableId(
  List<Road> roadList,
  String stableId, {
  int? preferredRoad,
}) {
  final id = stableId.trim();
  if (id.isEmpty) {
    return null;
  }
  if (preferredRoad != null &&
      preferredRoad >= 0 &&
      preferredRoad < roadList.length) {
    final episodeIndex = roadList[preferredRoad].indexOfStableId(id);
    if (episodeIndex >= 0) {
      return VideoEpisodeSelection(
        episode: episodeIndex + 1,
        road: preferredRoad,
      );
    }
  }
  for (var roadIndex = 0; roadIndex < roadList.length; roadIndex++) {
    if (roadIndex == preferredRoad) {
      continue;
    }
    final episodeIndex = roadList[roadIndex].indexOfStableId(id);
    if (episodeIndex >= 0) {
      return VideoEpisodeSelection(
        episode: episodeIndex + 1,
        road: roadIndex,
      );
    }
  }
  return null;
}

/// 用历史进度恢复播放选集。
///
/// 新进度必须通过 [stableId] 命中；只有没有 stableId 的存量进度才允许按
/// `(road, episode)` 下标恢复，避免稳定身份失配后误绑到重排后的列表位置。
VideoEpisodeSelection? findEpisodeSelectionForHistoryProgress(
  List<Road> roadList, {
  required String stableId,
  required int episode,
  required int road,
}) {
  final stableSelection = findEpisodeSelectionByStableId(
    roadList,
    stableId,
    preferredRoad: road,
  );
  if (stableId.trim().isNotEmpty) {
    return stableSelection;
  }
  if (road >= 0 &&
      roadList.length > road &&
      episode > 0 &&
      roadList[road].data.length >= episode) {
    return VideoEpisodeSelection(
      episode: episode,
      road: road,
    );
  }
  return null;
}

int? bangumiEpisodeSortNumber(EpisodeInfo episode) {
  final sort = episode.episode;
  if (sort <= 0) {
    return null;
  }
  final rounded = sort.round();
  return sort == rounded ? rounded : null;
}

Map<int, int> bangumiSortByListIndex(List<EpisodeInfo> episodes) {
  final result = <int, int>{};
  for (var index = 0; index < episodes.length; index++) {
    final sortNumber = bangumiEpisodeSortNumber(episodes[index]);
    if (sortNumber != null) {
      result[index + 1] = sortNumber;
    }
  }
  return result;
}

int episodeSortNumberForPlayback({
  required int listIndex,
  int? anchoredSortNumber,
  int? ruleOrdinal,
}) {
  return anchoredSortNumber ?? ruleOrdinal ?? listIndex;
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
  OfflineRoadListSnapshot? _offlineSnapshot;
  final Map<int, DownloadEpisode> _offlineEpisodesByNumber = {};
  final Map<String, List<DownloadEpisode>> _offlineEpisodesByStableId = {};
  final Map<int, int> _offlineDisplayRoadToOriginalRoad = {};
  final Map<int, int> _offlineOriginalRoadToDisplayRoad = {};
  final Map<int, int> _bangumiSortByListIndex = {};

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
    required String stableId,
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

    final target = _findOfflineEpisodeByIdentity(
      stableId: stableId,
      episodeNumber: episodeNumber,
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
        'VideoPageController: initialized for offline playback, stableId=$stableId, episode $episodeNumber (position: ${selected.episode})');
  }

  void _buildOfflineRoadList(List<DownloadEpisode> episodes) {
    final snapshot = buildOfflineRoadListSnapshot(episodes);
    _offlineSnapshot = snapshot;
    roadList.clear();
    roadList.addAll(snapshot.roads);
    _offlineEpisodesByNumber.clear();
    _offlineEpisodesByNumber.addAll(snapshot.episodesByNumber);
    _offlineEpisodesByStableId.clear();
    _offlineEpisodesByStableId.addAll(snapshot.episodesByStableId);
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
    _offlineEpisodesByStableId.clear();
    _offlineSnapshot = null;
    _offlineDisplayRoadToOriginalRoad.clear();
    _offlineOriginalRoadToDisplayRoad.clear();
    _playbackHistoryIdentity = null;
  }

  String get offlinePluginName => _offlinePluginName;

  PlaybackHistoryIdentity? get currentHistoryIdentity =>
      _playbackHistoryIdentity;

  ({int listIndex, int roadIndex})? _findOfflineEpisodeByIdentity({
    required String stableId,
    required int episodeNumber,
    required int preferredOriginalRoad,
  }) {
    if (roadList.isEmpty) {
      return null;
    }
    final preferredDisplayRoad =
        _offlineOriginalRoadToDisplayRoad[preferredOriginalRoad];
    final stableSelection = findEpisodeSelectionByStableId(
      roadList,
      stableId,
      preferredRoad: preferredDisplayRoad,
    );
    if (stableSelection != null) {
      return (
        listIndex: stableSelection.episode,
        roadIndex: stableSelection.road,
      );
    }
    if (episodeNumber <= 0) {
      return null;
    }
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

  DownloadEpisode? _offlineDownloadEpisodeForIdentity(
    EpisodeIdentity identity,
    int displayRoad,
  ) {
    final snapshotMatch = _offlineSnapshot?.episodeForIdentity(
      identity,
      displayRoad,
    );
    if (snapshotMatch != null) {
      return snapshotMatch;
    }
    final preferredOriginalRoad =
        _offlineDisplayRoadToOriginalRoad[displayRoad] ?? displayRoad;
    if (identity.stableId.isNotEmpty) {
      final candidates = _offlineEpisodesByStableId[identity.stableId];
      if (candidates != null && candidates.isNotEmpty) {
        for (final episode in candidates) {
          if (episode.road == preferredOriginalRoad) {
            return episode;
          }
        }
        return candidates.first;
      }
    }
    final episodeNumber = identity.ordinal;
    return episodeNumber == null
        ? null
        : _offlineEpisodesByNumber[episodeNumber];
  }

  ({int listIndex, int roadIndex})? _findOfflineEpisodeInDisplayRoad(
    int episodeNumber,
    int roadIndex,
  ) {
    if (roadIndex < 0 || roadIndex >= roadList.length) {
      return null;
    }
    final index = roadList[roadIndex].indexOfOrdinal(episodeNumber);
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
              episodePageUrl: identity.episodePageUrl,
              stableId: identity.stableId,
            )
            ?.progress
            .inSeconds ??
        0;
  }

  /// 规则身份升级或 baseURL 变更后，历史进度可能缺少 stableId，或仍持有旧
  /// pageURL。在线视频页打开时，依据当前 roadList 把存量历史就地迁移到规则
  /// 抓取阶段产出的身份，后续播放器只消费 [Progress.stableId]。
  void migrateStaleOnlineEpisodeIdentity() {
    if (isOfflineMode || roadList.isEmpty) {
      return;
    }
    historyController.migrateProgressPageUrls(
      adapterName: currentPlugin.name,
      bangumiItem: bangumiItem,
      resolveCurrentPageUrl: (road, episode) {
        if (road < 0 || road >= roadList.length) {
          return '';
        }
        final data = roadList[road].data;
        final idx = episode - 1;
        if (idx < 0 || idx >= data.length) {
          return '';
        }
        return data[idx].pageUrl;
      },
      resolveCurrentStableId: (road, episode) {
        if (road < 0 || road >= roadList.length) {
          return '';
        }
        final data = roadList[road].data;
        final idx = episode - 1;
        if (idx < 0 || idx >= data.length) {
          return '';
        }
        return data[idx].stableId;
      },
    );
  }

  void _setOnlineHistoryIdentity(EpisodeRef episode) {
    _playbackHistoryIdentity = PlaybackHistoryIdentity.online(
      bangumiItem: bangumiItem,
      pluginName: currentPlugin.name,
      episodeNumber: episode.historyEpisodeNumber,
      episodeTitle: episode.displayTitle,
      road: episode.originalRoadIndex,
      onlineBangumiSrc: src,
      episodePageUrl: episode.pageUrl,
      stableId: episode.stableId,
    );
  }

  void _setOfflineHistoryIdentity(EpisodeRef episode) {
    _playbackHistoryIdentity = PlaybackHistoryIdentity.offline(
      bangumiItem: bangumiItem,
      pluginName: _offlinePluginName,
      episodeNumber: episode.historyEpisodeNumber,
      episodeTitle: episode.displayTitle,
      road: episode.originalRoadIndex,
      episodePageUrl: episode.pageUrl,
      stableId: episode.stableId,
    );
  }

  EpisodeRef? _resolveOnlineEpisode(int episode, {int? road}) {
    final targetRoad = road ?? selectedEpisode.road;
    if (roadList.isEmpty || targetRoad < 0 || targetRoad >= roadList.length) {
      return null;
    }
    final roadData = roadList[targetRoad];
    final index = episode - 1;
    if (index < 0 || index >= roadData.data.length) {
      return null;
    }
    return EpisodeRef.online(
      listIndex: episode,
      identity: roadData.data[index],
      anchoredSortNumber: _bangumiSortByListIndex[episode],
    );
  }

  EpisodeRef? _resolveOfflineEpisode(int episode, {int? road}) {
    final targetRoad = road ?? selectedEpisode.road;
    if (roadList.isEmpty || targetRoad < 0 || targetRoad >= roadList.length) {
      return null;
    }
    final roadData = roadList[targetRoad];
    final index = episode - 1;
    if (index < 0 || index >= roadData.data.length) {
      return null;
    }
    final identity = roadData.data[index];
    final episodeNumber = identity.ordinal;
    if (episodeNumber == null) {
      return null;
    }
    final downloadEpisode =
        _offlineDownloadEpisodeForIdentity(identity, targetRoad);
    final resolvedTitle = downloadEpisode?.episodeName.isNotEmpty == true
        ? downloadEpisode!.episodeName
        : (identity.title.isNotEmpty ? identity.title : '第$episodeNumber集');
    final resolvedIdentity = EpisodeIdentity(
      stableId: identity.stableId,
      pageUrl: downloadEpisode?.episodePageUrl.isNotEmpty == true
          ? downloadEpisode!.episodePageUrl
          : identity.pageUrl,
      title: resolvedTitle,
      ordinal: episodeNumber,
      roadIndex: targetRoad,
    );
    return EpisodeRef.offline(
      listIndex: episode,
      identity: resolvedIdentity,
      originalRoadIndex: downloadEpisode?.road ??
          _offlineDisplayRoadToOriginalRoad[targetRoad] ??
          targetRoad,
    );
  }

  EpisodeRef? resolveEpisode(VideoEpisodeSelection selection) {
    return isOfflineMode
        ? _resolveOfflineEpisode(selection.episode, road: selection.road)
        : _resolveOnlineEpisode(selection.episode, road: selection.road);
  }

  int commentEpisodeForSelection(VideoEpisodeSelection selection) {
    final resolvedEpisode = resolveEpisode(selection);
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
      resolvedEpisode.pageUrl,
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

    final localPath = _getLocalVideoPathForEpisode(
      bangumiItem.id,
      _offlinePluginName,
      resolvedEpisode,
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
      pageUrl: resolvedEpisode.pageUrl,
      stableId: resolvedEpisode.stableId,
      sortNumber: resolvedEpisode.sortNumber,
      httpHeaders: {},
      adBlockerEnabled: false,
      episodeTitle: resolvedEpisode.displayTitle,
      referer: '',
      currentRoad: resolvedEpisode.roadIndex,
      downloadRoad: resolvedEpisode.originalRoadIndex,
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
        stableId: params.stableId,
        road: params.downloadRoad ?? params.currentRoad,
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

  String? _getLocalVideoPathForEpisode(
    int bangumiId,
    String pluginName,
    EpisodeRef episodeRef,
  ) {
    DownloadEpisode? episode;
    if (episodeRef.stableId.isNotEmpty) {
      final candidates = _offlineEpisodesByStableId[episodeRef.stableId];
      if (candidates != null) {
        for (final candidate in candidates) {
          if (candidate.road == episodeRef.originalRoadIndex) {
            episode = candidate;
            break;
          }
        }
      }
      episode ??= downloadRepository.getEpisodeByStableId(
        bangumiId,
        pluginName,
        episodeRef.stableId,
        road: episodeRef.originalRoadIndex,
      );
    }
    episode ??= downloadRepository.getEpisode(
      bangumiId,
      pluginName,
      episodeRef.historyEpisodeNumber,
    );
    return downloadManager.getLocalVideoPath(episode);
  }

  Future<void> _resolveWithVideoSourceService(
    String url,
    int offset, {
    required EpisodeRef resolvedEpisode,
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
        pageUrl: resolvedEpisode.pageUrl,
        stableId: resolvedEpisode.stableId,
        sortNumber: resolvedEpisode.sortNumber,
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
    _bangumiSortByListIndex.clear();
    for (Plugin plugin in pluginsController.pluginList) {
      if (plugin.name == pluginName) {
        roadList.addAll(
            await plugin.querychapterRoads(url, cancelToken: cancelToken));
      }
    }
    await _refreshBangumiEpisodeSorts();
    KazumiLogger()
        .i('VideoPageController: road list length ${roadList.length}');
    if (roadList.isNotEmpty) {
      KazumiLogger().i(
          'VideoPageController: first road episode count ${roadList[0].data.length}');
    }
  }

  Future<void> _refreshBangumiEpisodeSorts() async {
    if (roadList.isEmpty || bangumiItem.id <= 0) {
      return;
    }
    final episodes = await BangumiApi.getBangumiEpisodesByID(bangumiItem.id);
    _bangumiSortByListIndex
      ..clear()
      ..addAll(bangumiSortByListIndex(episodes));
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
    required this.episodesByStableId,
    required this.displayRoadToOriginalRoad,
    required this.originalRoadToDisplayRoad,
  });

  final List<Road> roads;
  final Map<int, DownloadEpisode> episodesByNumber;
  final Map<String, List<DownloadEpisode>> episodesByStableId;
  final Map<int, int> displayRoadToOriginalRoad;
  final Map<int, int> originalRoadToDisplayRoad;

  DownloadEpisode? episodeForIdentity(
    EpisodeIdentity identity,
    int displayRoad,
  ) {
    final preferredOriginalRoad =
        displayRoadToOriginalRoad[displayRoad] ?? displayRoad;
    if (identity.stableId.isNotEmpty) {
      final candidates = episodesByStableId[identity.stableId];
      if (candidates != null && candidates.isNotEmpty) {
        for (final episode in candidates) {
          if (episode.road == preferredOriginalRoad) {
            return episode;
          }
        }
        return candidates.first;
      }
    }
    final episodeNumber = identity.ordinal;
    return episodeNumber == null ? null : episodesByNumber[episodeNumber];
  }
}

OfflineRoadListSnapshot buildOfflineRoadListSnapshot(
  List<DownloadEpisode> episodes,
) {
  final groupedEpisodes = <int, List<DownloadEpisode>>{};
  final episodesByNumber = <int, DownloadEpisode>{};
  final episodesByStableId = <String, List<DownloadEpisode>>{};

  for (final episode in episodes) {
    episodesByNumber[episode.episodeNumber] = episode;
    if (episode.stableId.isNotEmpty) {
      episodesByStableId.putIfAbsent(episode.stableId, () => []).add(episode);
    }
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
      data: roadEpisodes
          .map((e) => EpisodeIdentity(
                // 新下载记录直接复用规则产出的 stableId；旧记录缺失时保持空值，
                // 只通过旧集号路径兼容，不再从 URL 反推身份。
                stableId: e.stableId,
                pageUrl: e.episodePageUrl,
                title: e.episodeName.isNotEmpty
                    ? e.episodeName
                    : '第${e.episodeNumber}集',
                ordinal: e.episodeNumber,
                roadIndex: displayRoad,
              ))
          .toList(),
    ));
  }

  return OfflineRoadListSnapshot(
    roads: roads,
    episodesByNumber: episodesByNumber,
    episodesByStableId: episodesByStableId,
    displayRoadToOriginalRoad: displayRoadToOriginalRoad,
    originalRoadToDisplayRoad: originalRoadToDisplayRoad,
  );
}

/// 播放期使用的“已定位单集”视图。
///
/// 重构后不再从 URL/标题反推身份：[stableId] / [sortNumber] / [displayTitle] 等
/// 直接来自订阅规则产出的 [EpisodeIdentity]，本类只负责把规则身份映射为各消费者
/// 需要的口径（历史集号 / 弹幕集号 / 列表位次）。
class EpisodeRef {
  const EpisodeRef({
    required this.listIndex,
    required this.roadIndex,
    required this.displayTitle,
    required this.pageUrl,
    required this.stableId,
    required this.sortNumber,
    required this.historyEpisodeNumber,
    required this.danmakuEpisodeNumber,
    required this.originalRoadIndex,
  });

  final int listIndex;
  final int roadIndex;
  final String displayTitle;
  final String pageUrl;

  /// 定位 / 持久 key，直接取自 [EpisodeIdentity.stableId]，与域名/顺序无关。
  final String stableId;

  /// 集数排序号，直接取自 [EpisodeIdentity.ordinal]（规则产出，无法判定时为 null）。
  final int? sortNumber;
  final int historyEpisodeNumber;
  final int danmakuEpisodeNumber;
  final int originalRoadIndex;

  /// 在线：历史集号用列表位次（与既有历史口径一致），弹幕集号优先用规则序数。
  factory EpisodeRef.online({
    required int listIndex,
    required EpisodeIdentity identity,
    int? anchoredSortNumber,
  }) {
    final sortNumber = episodeSortNumberForPlayback(
      listIndex: listIndex,
      anchoredSortNumber: anchoredSortNumber,
      ruleOrdinal: identity.ordinal,
    );
    return EpisodeRef(
      listIndex: listIndex,
      roadIndex: identity.roadIndex,
      displayTitle: identity.title,
      pageUrl: identity.pageUrl,
      stableId: identity.stableId,
      sortNumber: sortNumber,
      historyEpisodeNumber: listIndex,
      danmakuEpisodeNumber: sortNumber,
      originalRoadIndex: identity.roadIndex,
    );
  }

  /// 离线：历史 / 弹幕 / 排序均以规则序数（下载集号）为准。
  factory EpisodeRef.offline({
    required int listIndex,
    required EpisodeIdentity identity,
    required int originalRoadIndex,
  }) {
    final number = identity.ordinal ?? listIndex;
    return EpisodeRef(
      listIndex: listIndex,
      roadIndex: identity.roadIndex,
      displayTitle: identity.title,
      pageUrl: identity.pageUrl,
      stableId: identity.stableId,
      sortNumber: number,
      historyEpisodeNumber: number,
      danmakuEpisodeNumber: number,
      originalRoadIndex: originalRoadIndex,
    );
  }
}
