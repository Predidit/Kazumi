import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_volume_controller/flutter_volume_controller.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:kazumi/modules/danmaku/danmaku_module.dart';
import 'package:mobx/mobx.dart';
import 'package:canvas_danmaku/canvas_danmaku.dart';
import 'package:kazumi/request/damaku.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:hive_ce/hive.dart';
import 'package:kazumi/utils/storage.dart';
import 'package:kazumi/utils/proxy_utils.dart';
import 'package:kazumi/utils/logger.dart';
import 'package:kazumi/utils/utils.dart';
import 'package:kazumi/utils/constants.dart';
import 'package:kazumi/shaders/shaders_controller.dart';
import 'package:kazumi/utils/syncplay.dart';
import 'package:kazumi/utils/syncplay_endpoint.dart';
import 'package:kazumi/utils/external_player.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:kazumi/pages/download/download_controller.dart';
import 'package:kazumi/utils/discord_rpc_manager.dart';

part 'player_controller.g.dart';

class PlaybackInitParams {
  final String videoUrl;
  final int offset;
  final bool isLocalPlayback;
  final int bangumiId;
  final String pluginName;
  final int episode;
  final Map<String, String> httpHeaders;
  final bool adBlockerEnabled;
  final String episodeTitle;
  final String referer;
  final int currentRoad;

  final String videoName;

  const PlaybackInitParams({
    required this.videoUrl,
    required this.offset,
    required this.isLocalPlayback,
    required this.bangumiId,
    required this.pluginName,
    required this.episode,
    required this.httpHeaders,
    required this.adBlockerEnabled,
    required this.episodeTitle,
    required this.referer,
    required this.currentRoad,
    required this.videoName,
  });
}

enum DanmakuDestination {
  chatRoom,
  remoteDanmaku,
}

class SyncPlayChatMessage {
  final String username;
  final String message;
  final bool fromRemote;
  final DateTime time;

  SyncPlayChatMessage({
    required this.username,
    required this.message,
    this.fromRemote = true,
    DateTime? time,
  }) : time = time ?? DateTime.now();
}

class PlayerController = _PlayerController with _$PlayerController;

abstract class _PlayerController with Store {
  final ShadersController shadersController = Modular.get<ShadersController>();

  late int bangumiId;
  late int currentEpisode;
  late int currentRoad;
  late String referer;

  String _rpcVideoName = "";
  int _rpcEpisode = 0;

  // 弹幕控制
  late DanmakuController danmakuController;
  @observable
  Map<int, List<Danmaku>> danDanmakus = {};
  @observable
  bool danmakuOn = false;
  @observable
  bool danmakuLoading = false;
  DanmakuDestination danmakuDestination = DanmakuDestination.remoteDanmaku;
  final StreamController<SyncPlayChatMessage> syncPlayChatStreamController =
      StreamController<SyncPlayChatMessage>.broadcast();
  Stream<SyncPlayChatMessage> get syncPlayChatStream =>
      syncPlayChatStreamController.stream;

  // 一起看控制器
  SyncplayClient? syncplayController;
  @observable
  String syncplayRoom = '';
  @observable
  int syncplayClientRtt = 0;

  /// 视频比例类型
  /// 1. AUTO
  /// 2. COVER
  /// 3. FILL
  @observable
  int aspectRatioType = 1;

  /// 视频超分
  /// 1. OFF
  /// 2. Anime4K Efficiency
  /// 3. Anime4K Quality
  @observable
  int superResolutionType = 1;

  // 视频音量/亮度
  @observable
  double volume = -1;
  @observable
  double brightness = 0;

  // 播放器界面控制
  @observable
  bool lockPanel = false;
  @observable
  bool showVideoController = true;
  @observable
  bool showSeekTime = false;
  @observable
  bool showBrightness = false;
  @observable
  bool showVolume = false;
  @observable
  bool showPlaySpeed = false;
  @observable
  bool brightnessSeeking = false;
  @observable
  bool volumeSeeking = false;
  @observable
  bool canHidePlayerPanel = true;

  // 视频地址
  String videoUrl = '';

  // DanDanPlay 弹幕ID
  int bangumiID = 0;

  // 播放器实体
  Player? mediaPlayer;
  VideoController? videoController;

  // 播放器面板状态
  @observable
  bool loading = true;
  @observable
  bool playing = false;
  @observable
  bool isBuffering = true;
  @observable
  bool completed = false;
  @observable
  Duration currentPosition = Duration.zero;
  @observable
  Duration buffer = Duration.zero;
  @observable
  Duration duration = Duration.zero;
  @observable
  double playerSpeed = 1.0;

  Box setting = GStorage.setting;
  bool hAenable = true;
  late String hardwareDecoder;
  bool androidEnableOpenSLES = true;
  bool lowMemoryMode = false;
  bool autoPlay = true;
  bool playerDebugMode = false;
  int buttonSkipTime = 80;
  int arrowKeySkipTime = 10;

  // 播放器实时状态
  bool get playerPlaying => mediaPlayer!.state.playing;
  bool get playerBuffering => mediaPlayer!.state.buffering;
  bool get playerCompleted => mediaPlayer!.state.completed;
  double get playerVolume => mediaPlayer!.state.volume;
  Duration get playerPosition => mediaPlayer!.state.position;
  Duration get playerBuffer => mediaPlayer!.state.buffer;
  Duration get playerDuration => mediaPlayer!.state.duration;

  // 播放器调试信息
  /// LogLevel 0: 错误 1: 警告 2: 简略 3: 详细
  int playerLogLevel = 2;
  @observable
  ObservableList<String> playerLog = ObservableList.of([]);
  @observable
  int playerWidth = 0;
  @observable
  int playerHeight = 0;
  @observable
  String playerVideoParams = '';
  @observable
  String playerAudioParams = '';
  @observable
  String playerPlaylist = '';
  @observable
  String playerAudioTracks = '';
  @observable
  String playerVideoTracks = '';
  @observable
  String playerAudioBitrate = '';

  /// 播放器调试信息订阅
  StreamSubscription<PlayerLog>? playerLogSubscription;
  StreamSubscription<int?>? playerWidthSubscription;
  StreamSubscription<int?>? playerHeightSubscription;
  StreamSubscription<VideoParams>? playerVideoParamsSubscription;
  StreamSubscription<AudioParams>? playerAudioParamsSubscription;
  StreamSubscription<Playlist>? playerPlaylistSubscription;
  StreamSubscription<Track>? playerTracksSubscription;
  StreamSubscription<double?>? playerAudioBitrateSubscription;

  bool isLocalPlayback = false;

  void _updateDiscordRpc(bool isPlaying) {
    int? startTimestamp;
    String stateText = "第 $_rpcEpisode 集"; // 默认显示的文字

    if (mediaPlayer != null) {
      final currentPosition = mediaPlayer!.state.position;
      final currentPositionMs = currentPosition.inMilliseconds;

      if (isPlaying) {
        // 🔥 情况A：正在播放
        // 计算“开始时间”，让 Discord 显示 "05:23 elapsed" 并自动走秒
        if (currentPositionMs >= 0) {
          startTimestamp = DateTime.now().millisecondsSinceEpoch - currentPositionMs;
        }
      } else {
        // 🔥 情况B：暂停
        // 不传 startTimestamp (让计时器消失)
        // 改为在文字后面加上 "(暂停于 05:23)"
        if (currentPositionMs > 0) {
          stateText += " (暂停于 ${_formatDuration(currentPosition)})";
        } else {
           stateText += " (已暂停)";
        }
      }
    }

    DiscordRpcManager.updatePresence(
      title: _rpcVideoName,
      subTitle: stateText, // 这里传入带暂停时间的文字
      isPlaying: isPlaying,
      startTimeEpoch: startTimestamp, // 暂停时这里是 null，计时器会自动隐藏
    );
  }
  
  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    
    // 如果超过1小时，显示 HH:MM:SS，否则显示 MM:SS
    if (duration.inHours > 0) {
      return "${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds";
    } else {
      return "$twoDigitMinutes:$twoDigitSeconds";
    }
  }

  Future<void> init(PlaybackInitParams params) async {
    videoUrl = params.videoUrl;
    isLocalPlayback = params.isLocalPlayback;
    bangumiId = params.bangumiId;
    currentEpisode = params.episode;
    currentRoad = params.currentRoad;
    referer = params.referer;

    _rpcVideoName = params.videoName; 
    _rpcEpisode = params.episode;
    
    DiscordRpcManager.init();
    _updateDiscordRpc(true);

    KazumiLogger().i(
        'PlayerController: ${params.isLocalPlayback ? "local" : "online"} playback, url: ${params.videoUrl}');

    playing = false;
    loading = true;
    isBuffering = true;
    currentPosition = Duration.zero;
    buffer = Duration.zero;
    duration = Duration.zero;
    completed = false;
    playerLogLevel = setting.get(SettingBoxKey.playerLogLevel, defaultValue: 2);
    playerSpeed =
        setting.get(SettingBoxKey.defaultPlaySpeed, defaultValue: 1.0);
    aspectRatioType =
        setting.get(SettingBoxKey.defaultAspectRatioType, defaultValue: 1);

    buttonSkipTime =
        setting.get(SettingBoxKey.buttonSkipTime, defaultValue: 80);
    arrowKeySkipTime =
        setting.get(SettingBoxKey.arrowKeySkipTime, defaultValue: 10);
    try {
      await dispose(disposeSyncPlayController: false);
    } catch (_) {}
    int episodeFromTitle = 0;
    try {
      episodeFromTitle = Utils.extractEpisodeNumber(params.episodeTitle);
    } catch (e) {
      KazumiLogger().e(
          'PlayerController: failed to extract episode number from title',
          error: e);
    }
    if (episodeFromTitle == 0) {
      episodeFromTitle = params.episode;
    }
    _loadDanmaku(params.bangumiId, params.pluginName, episodeFromTitle);
    mediaPlayer ??= await createVideoController(
      params.httpHeaders,
      params.adBlockerEnabled,
      offset: params.offset,
    );

    if (Utils.isDesktop()) {
      volume = volume != -1 ? volume : 100;
      await setVolume(volume);
    } else {
      // mobile is using system volume, don't setVolume here,
      // or iOS will mute if system volume is too low (#732)
      await FlutterVolumeController.getVolume().then((value) {
        volume = (value ?? 0.0) * 100;
      });
    }
    setPlaybackSpeed(playerSpeed);
    if (mediaPlayer != null) {
      // 1. 监听播放状态：只要自动播放了，就立马通知 Discord
      mediaPlayer!.stream.playing.listen((bool isPlaying) {
        _updateDiscordRpc(isPlaying);
      });

      // 2. 监听缓冲结束：缓冲完后，重新校准时间，防止时间显示错误
      mediaPlayer!.stream.buffering.listen((bool isBuffering) {
        if (!isBuffering && mediaPlayer!.state.playing) {
          _updateDiscordRpc(true);
        }
      });
    }
    KazumiLogger().i('PlayerController: video initialized');
    loading = false;
    if (syncplayController?.isConnected ?? false) {
      if (syncplayController!.currentFileName !=
          "$bangumiId[$currentEpisode]") {
        setSyncPlayPlayingBangumi(
            forceSyncPlaying: true, forceSyncPosition: 0.0);
      }
    }
  }

  Future<void> setupPlayerDebugInfoSubscription() async {
    await playerLogSubscription?.cancel();
    playerLogSubscription = mediaPlayer!.stream.log.listen((event) {
      playerLog.add(event.toString());
      if (playerDebugMode) {
        KazumiLogger().i("MPV: ${event.toString()}", forceLog: true);
      }
    });
    await playerWidthSubscription?.cancel();
    playerWidthSubscription = mediaPlayer!.stream.width.listen((event) {
      playerWidth = event ?? 0;
    });
    await playerHeightSubscription?.cancel();
    playerHeightSubscription = mediaPlayer!.stream.height.listen((event) {
      playerHeight = event ?? 0;
    });
    await playerVideoParamsSubscription?.cancel();
    playerVideoParamsSubscription =
        mediaPlayer!.stream.videoParams.listen((event) {
      playerVideoParams = event.toString();
    });
    await playerAudioParamsSubscription?.cancel();
    playerAudioParamsSubscription =
        mediaPlayer!.stream.audioParams.listen((event) {
      playerAudioParams = event.toString();
    });
    await playerPlaylistSubscription?.cancel();
    playerPlaylistSubscription = mediaPlayer!.stream.playlist.listen((event) {
      playerPlaylist = event.toString();
    });
    await playerTracksSubscription?.cancel();
    playerTracksSubscription = mediaPlayer!.stream.track.listen((event) {
      playerAudioTracks = event.audio.toString();
      playerVideoTracks = event.video.toString();
    });
    await playerAudioBitrateSubscription?.cancel();
    playerAudioBitrateSubscription =
        mediaPlayer!.stream.audioBitrate.listen((event) {
      playerAudioBitrate = event.toString();
    });
  }

  Future<void> cancelPlayerDebugInfoSubscription() async {
    await playerLogSubscription?.cancel();
    await playerWidthSubscription?.cancel();
    await playerHeightSubscription?.cancel();
    await playerVideoParamsSubscription?.cancel();
    await playerAudioParamsSubscription?.cancel();
    await playerPlaylistSubscription?.cancel();
    await playerTracksSubscription?.cancel();
    await playerAudioBitrateSubscription?.cancel();
  }

  Future<Player> createVideoController(
      Map<String, String> httpHeaders, bool adBlockerEnabled,
      {int offset = 0}) async {
    superResolutionType =
        setting.get(SettingBoxKey.defaultSuperResolutionType, defaultValue: 1);
    hAenable = setting.get(SettingBoxKey.hAenable, defaultValue: true);
    androidEnableOpenSLES =
        setting.get(SettingBoxKey.androidEnableOpenSLES, defaultValue: true);
    hardwareDecoder =
        setting.get(SettingBoxKey.hardwareDecoder, defaultValue: 'auto-safe');
    autoPlay = setting.get(SettingBoxKey.autoPlay, defaultValue: true);
    lowMemoryMode =
        setting.get(SettingBoxKey.lowMemoryMode, defaultValue: false);
    playerDebugMode =
        setting.get(SettingBoxKey.playerDebugMode, defaultValue: false);

    mediaPlayer = Player(
      configuration: PlayerConfiguration(
        bufferSize: lowMemoryMode ? 15 * 1024 * 1024 : 1500 * 1024 * 1024,
        osc: false,
        logLevel: MPVLogLevel.values[playerLogLevel],
        adBlocker: adBlockerEnabled,
      ),
    );

    playerLog.clear();
    setupPlayerDebugInfoSubscription();

    var pp = mediaPlayer!.platform as NativePlayer;
    // media-kit 默认启用硬盘作为双重缓存，这可以维持大缓存的前提下减轻内存压力
    // media-kit 内部硬盘缓存目录按照 Linux 配置，这导致该功能在其他平台上被损坏
    // 该设置可以在所有平台上正确启用双重缓存
    await pp.setProperty("demuxer-cache-dir", await Utils.getPlayerTempPath());
    await pp.setProperty("af", "scaletempo2=max-speed=8");
    if (Platform.isAndroid) {
      await pp.setProperty("volume-max", "100");
      if (androidEnableOpenSLES) {
        await pp.setProperty("ao", "opensles");
      } else {
        await pp.setProperty("ao", "audiotrack");
      }
    }

    // 设置 HTTP 代理
    final bool proxyEnable =
        setting.get(SettingBoxKey.proxyEnable, defaultValue: false);
    if (proxyEnable) {
      final String proxyUrl =
          setting.get(SettingBoxKey.proxyUrl, defaultValue: '');
      final formattedProxy = ProxyUtils.getFormattedProxyUrl(proxyUrl);
      if (formattedProxy != null) {
        await pp.setProperty("http-proxy", formattedProxy);
        KazumiLogger().i('Player: HTTP 代理设置成功 $formattedProxy');
      }
    }

    await mediaPlayer!.setAudioTrack(
      AudioTrack.auto(),
    );

    String? videoRenderer;
    if (Platform.isAndroid) {
      final String androidVideoRenderer =
          setting.get(SettingBoxKey.androidVideoRenderer, defaultValue: 'auto');

      if (androidVideoRenderer == 'auto') {
        // Android 14 及以上使用基于 Vulkan 的 MPV GPU-NEXT 视频输出，着色器性能更好
        // GPU-NEXT 需要 Vulkan 1.2 支持
        // 避免 Android 14 及以下设备上部分机型 Vulkan 支持不佳导致的黑屏问题
        final int androidSdkVersion = await Utils.getAndroidSdkVersion();
        if (androidSdkVersion >= 34) {
          videoRenderer = 'gpu-next';
        } else {
          videoRenderer = 'gpu';
        }
      } else {
        videoRenderer = androidVideoRenderer;
      }
    }

    if (videoRenderer == 'mediacodec_embed') {
      hAenable = true;
      hardwareDecoder = 'mediacodec';
      superResolutionType = 1;
    }

    videoController ??= VideoController(
      mediaPlayer!,
      configuration: VideoControllerConfiguration(
        vo: videoRenderer,
        enableHardwareAcceleration: hAenable,
        hwdec: hAenable ? hardwareDecoder : 'no',
        androidAttachSurfaceAfterVideoParameters: false,
      ),
    );
    mediaPlayer!.setPlaylistMode(PlaylistMode.none);

    // error handle
    bool showPlayerError =
        setting.get(SettingBoxKey.showPlayerError, defaultValue: true);
    mediaPlayer!.stream.error.listen((event) {
      if (showPlayerError) {
        if (event.toString().contains('Failed to open') && playerBuffering) {
          KazumiDialog.showToast(
              message: '加载失败, 请尝试更换其他视频来源',
              showActionButton: true);
        } else {
          KazumiDialog.showToast(
              message: '播放器内部错误 ${event.toString()} $videoUrl',
              duration: const Duration(seconds: 5),
              showActionButton: true);
        }
      }
      KazumiLogger()
          .e('PlayerController: Player intent error $videoUrl', error: event);
    });

    if (superResolutionType != 1) {
      await setShader(superResolutionType);
    }

    await mediaPlayer!.open(
      Media(videoUrl,
          start: Duration(seconds: offset), httpHeaders: httpHeaders),
      play: autoPlay,
    );

    return mediaPlayer!;
  }

  Future<void> setShader(int type, {bool synchronized = true}) async {
    var pp = mediaPlayer!.platform as NativePlayer;
    await pp.waitForPlayerInitialization;
    await pp.waitForVideoControllerInitializationIfAttached;
    if (type == 2) {
      await pp.command([
        'change-list',
        'glsl-shaders',
        'set',
        Utils.buildShadersAbsolutePath(
            shadersController.shadersDirectory.path, mpvAnime4KShadersLite),
      ]);
      superResolutionType = 2;
      return;
    }
    if (type == 3) {
      await pp.command([
        'change-list',
        'glsl-shaders',
        'set',
        Utils.buildShadersAbsolutePath(
            shadersController.shadersDirectory.path, mpvAnime4KShaders),
      ]);
      superResolutionType = 3;
      return;
    }
    await pp.command(['change-list', 'glsl-shaders', 'clr', '']);
    superResolutionType = 1;
  }

  Future<void> setPlaybackSpeed(double playerSpeed) async {
    this.playerSpeed = playerSpeed;
    try {
      mediaPlayer!.setRate(playerSpeed);
    } catch (e) {
      KazumiLogger()
          .e('PlayerController: failed to set playback speed', error: e);
    }
    try {
      updateDanmakuSpeed();
    } catch (_) {}
  }

  void updateDanmakuSpeed() {
    final baseDuration =
        setting.get(SettingBoxKey.danmakuDuration, defaultValue: 8.0);
    final followSpeed =
        setting.get(SettingBoxKey.danmakuFollowSpeed, defaultValue: true);

    final duration = followSpeed ? (baseDuration / playerSpeed) : baseDuration;
    danmakuController
        .updateOption(danmakuController.option.copyWith(duration: duration));
  }

  Future<void> setVolume(double value) async {
    value = value.clamp(0.0, 100.0);
    volume = value;
    try {
      if (Utils.isDesktop()) {
        await mediaPlayer!.setVolume(value);
      } else {
        await FlutterVolumeController.updateShowSystemUI(false);
        await FlutterVolumeController.setVolume(value / 100);
      }
    } catch (_) {}
  }

  Future<void> playOrPause() async {
    if (mediaPlayer!.state.playing) {
      await pause();
    } else {
      await play();
    }
  }

  Future<void> seek(Duration duration, {bool enableSync = true}) async {
    currentPosition = duration;
    danmakuController.clear();
    await mediaPlayer!.seek(duration);
    if (playing) {
      _updateDiscordRpc(true);
    }
    if (syncplayController != null) {
      setSyncPlayCurrentPosition();
      if (enableSync) {
        await requestSyncPlaySync(doSeek: true);
      }
    }
  }

  Future<void> pause({bool enableSync = true}) async {
    danmakuController.pause();
    await mediaPlayer!.pause();
    playing = false;
    _updateDiscordRpc(false);
    if (syncplayController != null) {
      setSyncPlayCurrentPosition();
      if (enableSync) {
        await requestSyncPlaySync();
      }
    }
  }

  Future<void> play({bool enableSync = true}) async {
    danmakuController.resume();
    await mediaPlayer!.play();
    playing = true;
    _updateDiscordRpc(true);
    if (syncplayController != null) {
      setSyncPlayCurrentPosition();
      if (enableSync) {
        await requestSyncPlaySync();
      }
    }
  }

  Future<void> dispose({bool disposeSyncPlayController = true}) async {
    DiscordRpcManager.clear();
    if (disposeSyncPlayController) {
      try {
        syncplayRoom = '';
        syncplayClientRtt = 0;
        await syncplayController?.disconnect();
        syncplayController = null;
      } catch (_) {}
    }
    try {
      await cancelPlayerDebugInfoSubscription();
    } catch (_) {}
    await mediaPlayer?.dispose();
    mediaPlayer = null;
    videoController = null;
  }

  Future<void> stop() async {
    try {
      await mediaPlayer?.stop();
      loading = true;
    } catch (_) {}
  }

  Future<Uint8List?> screenshot({String format = 'image/jpeg'}) async {
    return await mediaPlayer!.screenshot(format: format);
  }

  void setButtonForwardTime(int time) {
    buttonSkipTime = time;
    setting.put(SettingBoxKey.buttonSkipTime, time);
  }

  void setArrowKeyForwardTime(int time) {
    arrowKeySkipTime = time;
    setting.put(SettingBoxKey.arrowKeySkipTime, time);
  }

  /// 加载弹幕 (离线模式优先从缓存加载，无缓存时尝试在线获取)
  Future<void> _loadDanmaku(
      int bangumiId, String pluginName, int episode) async {
    if (isLocalPlayback) {
      await _loadCachedDanmaku(bangumiId, pluginName, episode);
    } else {
      getDanDanmakuByBgmBangumiID(bangumiId, episode);
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
              await DanmakuRequest.getDanDanBangumiIDByBgmBangumiID(bangumiId);
          if (bangumiID != 0) {
            var res = await DanmakuRequest.getDanDanmaku(bangumiID, episode);
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
          await DanmakuRequest.getDanDanBangumiIDByBgmBangumiID(bgmBangumiID);
      var res = await DanmakuRequest.getDanDanmaku(bangumiID, episode);
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
      var res = await DanmakuRequest.getDanDanmakuByEpisodeID(episodeID);
      addDanmakus(res);
    } catch (e) {
      KazumiLogger().w('PlayerController: failed to get danmaku', error: e);
    } finally {
      danmakuLoading = false;
    }
  }

  void addDanmakus(List<Danmaku> danmakus) {
    final bool danmakuDeduplicationEnable = setting.get(SettingBoxKey.danmakuDeduplication, defaultValue: false);

    // 如果启用了弹幕去重功能则处理5秒内相邻重复类似的弹幕进行合并
    final List<Danmaku> listToAdd  = danmakuDeduplicationEnable ? Utils.mergeDuplicateDanmakus(danmakus, timeWindowSeconds: 5) : danmakus;

    for (var element in listToAdd) {
      var danmakuList =
          danDanmakus[element.time.toInt()] ?? List.empty(growable: true);
      danmakuList.add(element);
      danDanmakus[element.time.toInt()] = danmakuList;
    }
  }

  void lanunchExternalPlayer() async {
    if ((Platform.isAndroid || Platform.isWindows) && referer.isEmpty) {
      if (await ExternalPlayer.launchURLWithMIME(videoUrl, 'video/mp4')) {
        KazumiDialog.dismiss();
        KazumiDialog.showToast(
          message: '尝试唤起外部播放器',
        );
      } else {
        KazumiDialog.showToast(
          message: '唤起外部播放器失败',
        );
      }
    } else if (Platform.isMacOS || Platform.isIOS) {
      if (await ExternalPlayer.launchURLWithReferer(videoUrl, referer)) {
        KazumiDialog.dismiss();
        KazumiDialog.showToast(
          message: '尝试唤起外部播放器',
        );
      } else {
        KazumiDialog.showToast(
          message: '唤起外部播放器失败',
        );
      }
    } else if (Platform.isLinux && referer.isEmpty) {
      KazumiDialog.dismiss();
      if (await canLaunchUrlString(videoUrl)) {
        launchUrlString(videoUrl);
        KazumiDialog.showToast(
          message: '尝试唤起外部播放器',
        );
      } else {
        KazumiDialog.showToast(
          message: '无法使用外部播放器',
        );
      }
    } else {
      if (referer.isEmpty) {
        KazumiDialog.showToast(
          message: '暂不支持该设备',
        );
      } else {
        KazumiDialog.showToast(
          message: '暂不支持该规则',
        );
      }
    }
  }

  Future<void> createSyncPlayRoom(
      String room,
      String username,
      Future<void> Function(int episode, {int currentRoad, int offset})
          changeEpisode,
      {bool enableTLS = true}) async {
    await syncplayController?.disconnect();
    final String syncPlayEndPoint = setting.get(SettingBoxKey.syncPlayEndPoint,
        defaultValue: defaultSyncPlayEndPoint);
    String syncPlayEndPointHost = '';
    int syncPlayEndPointPort = 0;
    KazumiLogger().i('SyncPlay: connecting to $syncPlayEndPoint');
    try {
      final parsed = parseSyncPlayEndPoint(syncPlayEndPoint);
      if (parsed != null) {
        syncPlayEndPointHost = parsed.host;
        syncPlayEndPointPort = parsed.port;
      }
    } catch (_) {}
    if (syncPlayEndPointHost == '' || syncPlayEndPointPort == 0) {
      KazumiDialog.showToast(
        message: 'SyncPlay: 服务器地址不合法 $syncPlayEndPoint',
      );
      KazumiLogger().e('SyncPlay: invalid server address $syncPlayEndPoint');
      return;
    }
    syncplayController =
        SyncplayClient(host: syncPlayEndPointHost, port: syncPlayEndPointPort);
    try {
      await syncplayController!.connect(enableTLS: enableTLS);
      KazumiLogger().i(
          'SyncPlay: connected to $syncPlayEndPointHost:$syncPlayEndPointPort');
      syncplayController!.onGeneralMessage.listen(
        (message) {
          // print('SyncPlay: general message: ${message.toString()}');
        },
        onError: (error) {
          print('SyncPlay: error: ${error.message}');
          if (error is SyncplayConnectionException) {
            exitSyncPlayRoom();
            KazumiDialog.showToast(
              message: 'SyncPlay: 同步中断 ${error.message}',
              duration: const Duration(seconds: 5),
              showActionButton: true,
              actionLabel: '重新连接',
              onActionPressed: () =>
                  createSyncPlayRoom(room, username, changeEpisode),
            );
          }
        },
      );
      syncplayController!.onRoomMessage.listen(
        (message) {
          if (message['type'] == 'init') {
            if (message['username'] == '') {
              KazumiDialog.showToast(
                  message: 'SyncPlay: 您是当前房间中的唯一用户',
                  duration: const Duration(seconds: 5));
              setSyncPlayPlayingBangumi();
            } else {
              KazumiDialog.showToast(
                  message:
                      'SyncPlay: 您不是当前房间中的唯一用户, 当前以用户 ${message['username']} 进度为准');
            }
          }
          if (message['type'] == 'left') {
            KazumiDialog.showToast(
                message: 'SyncPlay: ${message['username']} 离开了房间',
                duration: const Duration(seconds: 5));
          }
          if (message['type'] == 'joined') {
            KazumiDialog.showToast(
                message: 'SyncPlay: ${message['username']} 加入了房间',
                duration: const Duration(seconds: 5));
          }
        },
      );
      syncplayController!.onFileChangedMessage.listen(
        (message) {
          print(
              'SyncPlay: file changed by ${message['setBy']}: ${message['name']}');
          RegExp regExp = RegExp(r'(\d+)\[(\d+)\]');
          Match? match = regExp.firstMatch(message['name']);
          if (match != null) {
            int bangumiID = int.tryParse(match.group(1) ?? '0') ?? 0;
            int episode = int.tryParse(match.group(2) ?? '0') ?? 0;
            if (bangumiID != 0 && episode != 0 && episode != currentEpisode) {
              KazumiDialog.showToast(
                  message:
                      'SyncPlay: ${message['setBy'] ?? 'unknown'} 切换到第 $episode 话',
                  duration: const Duration(seconds: 3));
              changeEpisode(episode, currentRoad: currentRoad);
            }
          }
        },
      );
      syncplayController!.onChatMessage.listen(
        (message) {
          final String sender = (message['username'] ?? '').toString();
          final String text = (message['message'] ?? '').toString();
          final bool fromRemote = message['username'] != username;

          // 将消息转发到流
          if (!syncPlayChatStreamController.isClosed) {
            syncPlayChatStreamController.add(SyncPlayChatMessage(
              username: sender,
              message: text,
              fromRemote: fromRemote,
            ));
          }
        },
        onError: (error) {
          print('SyncPlay: error: ${error.message}');
        },
      );
      syncplayController!.onPositionChangedMessage.listen(
        (message) {
          syncplayClientRtt = (message['clientRtt'].toDouble() * 1000).toInt();
          print(
              'SyncPlay: position changed by ${message['setBy']}: [${DateTime.now().millisecondsSinceEpoch / 1000.0}] calculatedPosition ${message['calculatedPositon']} position: ${message['position']} doSeek: ${message['doSeek']} paused: ${message['paused']} clientRtt: ${message['clientRtt']} serverRtt: ${message['serverRtt']} fd: ${message['fd']}');
          if (message['paused'] != !playing) {
            if (message['paused']) {
              if (message['position'] != 0) {
                KazumiDialog.showToast(
                    message: 'SyncPlay: ${message['setBy'] ?? 'unknown'} 暂停了播放',
                    duration: const Duration(seconds: 3));
                pause(enableSync: false);
              }
            } else {
              if (message['position'] != 0) {
                KazumiDialog.showToast(
                    message: 'SyncPlay: ${message['setBy'] ?? 'unknown'} 开始了播放',
                    duration: const Duration(seconds: 3));
                play(enableSync: false);
              }
            }
          }
          if ((((playerPosition.inMilliseconds -
                              (message['calculatedPositon'].toDouble() * 1000)
                                  .toInt())
                          .abs() >
                      1000) ||
                  message['doSeek']) &&
              duration.inMilliseconds > 0) {
            seek(
                Duration(
                    milliseconds:
                        (message['calculatedPositon'].toDouble() * 1000)
                            .toInt()),
                enableSync: false);
          }
        },
      );
      await syncplayController!.joinRoom(room, username);
      syncplayRoom = room;
    } catch (e) {
      print('SyncPlay: error: $e');
    }
  }

  void setSyncPlayCurrentPosition(
      {bool? forceSyncPlaying, double? forceSyncPosition}) {
    if (syncplayController == null) {
      return;
    }
    forceSyncPlaying ??= playing;
    syncplayController!.setPaused(!forceSyncPlaying);
    syncplayController!.setPosition((forceSyncPosition ??
        (((currentPosition.inMilliseconds - playerPosition.inMilliseconds)
                    .abs() >
                2000)
            ? currentPosition.inMilliseconds.toDouble() / 1000
            : playerPosition.inMilliseconds.toDouble() / 1000)));
  }

  Future<void> setSyncPlayPlayingBangumi(
      {bool? forceSyncPlaying, double? forceSyncPosition}) async {
    await syncplayController!
        .setSyncPlayPlaying("$bangumiId[$currentEpisode]", 10800, 220514438);
    setSyncPlayCurrentPosition(
        forceSyncPlaying: forceSyncPlaying,
        forceSyncPosition: forceSyncPosition);
    await requestSyncPlaySync();
  }

  Future<void> requestSyncPlaySync({bool? doSeek}) async {
    await syncplayController!.sendSyncPlaySyncRequest(doSeek: doSeek);
  }

  Future<void> sendSyncPlayChatMessage(String message) async {
    if (syncplayController == null) {
      return;
    }
    await syncplayController!.sendChatMessage(message);
  }

  Future<void> exitSyncPlayRoom() async {
    if (syncplayController == null) {
      return;
    }
    await syncplayController!.disconnect();
    syncplayController = null;
    syncplayRoom = '';
    syncplayClientRtt = 0;
  }
}
