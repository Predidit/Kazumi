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
import 'package:kazumi/pages/video/video_controller.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:hive/hive.dart';
import 'package:kazumi/utils/storage.dart';
import 'package:logger/logger.dart';
import 'package:kazumi/utils/logger.dart';
import 'package:kazumi/utils/utils.dart';
import 'package:kazumi/utils/constants.dart';
import 'package:kazumi/shaders/shaders_controller.dart';
import 'package:kazumi/utils/syncplay.dart';
import 'package:kazumi/utils/external_player.dart';
import 'package:url_launcher/url_launcher_string.dart';

part 'player_controller.g.dart';

class PlayerController = _PlayerController with _$PlayerController;

abstract class _PlayerController with Store {
  final VideoPageController videoPageController =
      Modular.get<VideoPageController>();
  final ShadersController shadersController = Modular.get<ShadersController>();

  // 弹幕控制
  late DanmakuController danmakuController;
  @observable
  Map<int, List<Danmaku>> danDanmakus = {};
  @observable
  bool danmakuOn = false;

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
  /// 2. Anime4K
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

  Future<void> init(String url, {int offset = 0}) async {
    videoUrl = url;
    playing = false;
    loading = true;
    isBuffering = true;
    currentPosition = Duration.zero;
    buffer = Duration.zero;
    duration = Duration.zero;
    completed = false;
    try {
      await dispose(disposeSyncPlayController: false);
    } catch (_) {}
    int episodeFromTitle = 0;
    try {
      episodeFromTitle = Utils.extractEpisodeNumber(videoPageController
          .roadList[videoPageController.currentRoad]
          .identifier[videoPageController.currentEpisode - 1]);
    } catch (e) {
      KazumiLogger().log(Level.error, '从标题解析集数错误 ${e.toString()}');
    }
    if (episodeFromTitle == 0) {
      episodeFromTitle = videoPageController.currentEpisode;
    }
    getDanDanmakuByBgmBangumiID(
        videoPageController.bangumiItem.id, episodeFromTitle);
    mediaPlayer ??= await createVideoController(offset: offset);

    playerSpeed =
        setting.get(SettingBoxKey.defaultPlaySpeed, defaultValue: 1.0);
    aspectRatioType =
        setting.get(SettingBoxKey.defaultAspectRatioType, defaultValue: 1);
        
    buttonSkipTime =
        setting.get(SettingBoxKey.buttonSkipTime, defaultValue: 80);
    arrowKeySkipTime =
        setting.get(SettingBoxKey.arrowKeySkipTime, defaultValue: 10);

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
    KazumiLogger().log(Level.info, 'VideoURL初始化完成');
    loading = false;
    if (syncplayController?.isConnected ?? false) {
      if (syncplayController!.currentFileName !=
          "${videoPageController.bangumiItem.id}[${videoPageController.currentEpisode}]") {
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
        KazumiLogger().simpleLog(event.toString());
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

  Future<Player> createVideoController({int offset = 0}) async {
    String userAgent = '';
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
    if (videoPageController.currentPlugin.userAgent == '') {
      userAgent = Utils.getRandomUA();
    } else {
      userAgent = videoPageController.currentPlugin.userAgent;
    }
    String referer = videoPageController.currentPlugin.referer;
    var httpHeaders = {
      'user-agent': userAgent,
      if (referer.isNotEmpty) 'referer': referer,
    };

    mediaPlayer = Player(
      configuration: PlayerConfiguration(
        bufferSize: lowMemoryMode ? 15 * 1024 * 1024 : 1500 * 1024 * 1024,
        osc: false,
        logLevel: MPVLogLevel.info,
      ),
    );

    // 记录播放器内部日志
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

    await mediaPlayer!.setAudioTrack(
      AudioTrack.auto(),
    );

    videoController ??= VideoController(
      mediaPlayer!,
      configuration: VideoControllerConfiguration(
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
        KazumiDialog.showToast(
            message: '播放器内部错误 ${event.toString()} $videoUrl',
            duration: const Duration(seconds: 5),
            showActionButton: true);
      }
      KazumiLogger().log(
          Level.error, 'Player intent error: ${event.toString()} $videoUrl');
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
      KazumiLogger().log(Level.error, '设置播放速度失败 ${e.toString()}');
    }
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
    if (syncplayController != null) {
      setSyncPlayCurrentPosition();
      if (enableSync) {
        await requestSyncPlaySync();
      }
    }
  }

  Future<void> dispose({bool disposeSyncPlayController = true}) async {
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

  Future<void> getDanDanmakuByBgmBangumiID(
      int bgmBangumiID, int episode) async {
    KazumiLogger().log(Level.info, '尝试获取弹幕 [BgmBangumiID] $bgmBangumiID');
    try {
      danDanmakus.clear();
      bangumiID =
          await DanmakuRequest.getDanDanBangumiIDByBgmBangumiID(bgmBangumiID);
      var res = await DanmakuRequest.getDanDanmaku(bangumiID, episode);
      addDanmakus(res);
    } catch (e) {
      KazumiLogger().log(Level.warning, '获取弹幕错误 ${e.toString()}');
    }
  }

  Future<void> getDanDanmakuByEpisodeID(int episodeID) async {
    KazumiLogger().log(Level.info, '尝试获取弹幕 $episodeID');
    try {
      danDanmakus.clear();
      var res = await DanmakuRequest.getDanDanmakuByEpisodeID(episodeID);
      addDanmakus(res);
    } catch (e) {
      KazumiLogger().log(Level.warning, '获取弹幕错误 ${e.toString()}');
    }
  }

  void addDanmakus(List<Danmaku> danmakus) {
    for (var element in danmakus) {
      var danmakuList =
          danDanmakus[element.time.toInt()] ?? List.empty(growable: true);
      danmakuList.add(element);
      danDanmakus[element.time.toInt()] = danmakuList;
    }
  }

  void lanunchExternalPlayer() async {
    String referer = videoPageController.currentPlugin.referer;
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
      {bool enableTLS = false}) async {
    await syncplayController?.disconnect();
    final String syncPlayEndPoint = setting.get(SettingBoxKey.syncPlayEndPoint,
        defaultValue: defaultSyncPlayEndPoint);
    String syncPlayEndPointHost = '';
    int syncPlayEndPointPort = 0;
    debugPrint('SyncPlay: 连接到服务器 $syncPlayEndPoint');
    try {
      final parts = syncPlayEndPoint.split(':');
      if (parts.length == 2) {
        syncPlayEndPointHost = parts[0];
        syncPlayEndPointPort = int.parse(parts[1]);
      }
    } catch (_) {}
    if (syncPlayEndPointHost == '' || syncPlayEndPointPort == 0) {
      KazumiDialog.showToast(
        message: 'SyncPlay: 服务器地址不合法 $syncPlayEndPoint',
      );
      KazumiLogger().log(Level.error, 'SyncPlay: 服务器地址不合法 $syncPlayEndPoint');
      return;
    }
    syncplayController =
        SyncplayClient(host: syncPlayEndPointHost, port: syncPlayEndPointPort);
    try {
      await syncplayController!.connect(enableTLS: enableTLS);
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
            if (bangumiID != 0 &&
                episode != 0 &&
                episode != videoPageController.currentEpisode) {
              KazumiDialog.showToast(
                  message:
                      'SyncPlay: ${message['setBy'] ?? 'unknown'} 切换到第 $episode 话',
                  duration: const Duration(seconds: 3));
              changeEpisode(episode,
                  currentRoad: videoPageController.currentRoad);
            }
          }
        },
      );
      syncplayController!.onChatMessage.listen(
        (message) {
          if (message['username'] != username) {
            KazumiDialog.showToast(
                message:
                    'SyncPlay: ${message['username']} 说: ${message['message']}',
                duration: const Duration(seconds: 5));
          }
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
    await syncplayController!.setSyncPlayPlaying(
        "${videoPageController.bangumiItem.id}[${videoPageController.currentEpisode}]",
        10800,
        220514438);
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
