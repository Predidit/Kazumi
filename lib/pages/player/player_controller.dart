import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_volume_controller/flutter_volume_controller.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/modules/bili_dm/dm.pb.dart';
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
import 'package:flutter/services.dart';
import 'package:kazumi/utils/constants.dart';
import 'package:kazumi/shaders/shaders_controller.dart';

part 'player_controller.g.dart';

class PlayerController = _PlayerController with _$PlayerController;

abstract class _PlayerController with Store {
  final VideoPageController videoPageController =
      Modular.get<VideoPageController>();
  final ShadersController shadersController = Modular.get<ShadersController>();
  // 弹幕控制
  late DanmakuController danmakuController;
  @observable
  Map<int, List> danDanmakus = {};
  @observable
  bool danmakuOn = false;
  // 弹幕时间轴偏移量
  int dmOffset = 0;

  // 视频比例类型
  // 1. AUTO
  // 2. COVER
  // 3. FILL
  @observable
  int aspectRatioType = 1;

  // 视频超分
  // 1. OFF
  // 2. Anime4K
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
  late Player mediaPlayer;
  late VideoController videoController;

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
  bool lowMemoryMode = false;
  bool autoPlay = true;
  int forwardTime = 80;

  // 播放器实时状态
  bool get playerPlaying => mediaPlayer.state.playing;
  bool get playerBuffering => mediaPlayer.state.buffering;
  bool get playerCompleted => mediaPlayer.state.completed;
  double get playerVolume => mediaPlayer.state.volume;
  Duration get playerPosition => mediaPlayer.state.position;
  Duration get playerBuffer => mediaPlayer.state.buffer;
  Duration get playerDuration => mediaPlayer.state.duration;

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
      mediaPlayer.dispose();
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
    cid = null;
    isBiliDm = false;
    dmOffset = 0;
    getDanDanmaku(videoPageController.title, episodeFromTitle);
    mediaPlayer = await createVideoController(offset: offset);
    playerSpeed =
        setting.get(SettingBoxKey.defaultPlaySpeed, defaultValue: 1.0);
    if (Utils.isDesktop()) {
      volume = volume != -1 ? volume : 100;
    } else {
      await FlutterVolumeController.getVolume().then((value) {
        volume = (value ?? 0.0) * 100;
      });
    }
    await setVolume(volume);
    if (Platform.isIOS) {
      FlutterVolumeController.updateShowSystemUI(true);
    }
    setPlaybackSpeed(playerSpeed);
    KazumiLogger().log(Level.info, 'VideoURL初始化完成');
    loading = false;
  }

  Future<Player> createVideoController({int offset = 0}) async {
    String userAgent = '';
    superResolutionType =
        setting.get(SettingBoxKey.defaultSuperResolutionType, defaultValue: 1);
    hAenable = setting.get(SettingBoxKey.hAenable, defaultValue: true);
    hardwareDecoder =
        setting.get(SettingBoxKey.hardwareDecoder, defaultValue: 'auto-safe');
    autoPlay = setting.get(SettingBoxKey.autoPlay, defaultValue: true);
    lowMemoryMode =
        setting.get(SettingBoxKey.lowMemoryMode, defaultValue: false);
    KazumiLogger().log(
        Level.info, 'media_kit decoder: 硬件解码: $hAenable 解码器: $hardwareDecoder');
    if (videoPageController.currentPlugin.userAgent == '') {
      userAgent = Utils.getRandomUA();
    } else {
      userAgent = videoPageController.currentPlugin.userAgent;
    }
    KazumiLogger().log(Level.info, 'media_kit UA: $userAgent');
    String referer = videoPageController.currentPlugin.referer;
    KazumiLogger().log(Level.info, 'media_kit Referer: $referer');
    var httpHeaders = {
      'user-agent': userAgent,
      if (referer.isNotEmpty) 'referer': referer,
    };

    mediaPlayer = Player(
      configuration: PlayerConfiguration(
        bufferSize: lowMemoryMode ? 15 * 1024 * 1024 : 1500 * 1024 * 1024,
      ),
    );

    var pp = mediaPlayer.platform as NativePlayer;
    await pp.setProperty("af", "scaletempo2=max-speed=8");
    if (Platform.isAndroid) {
      await pp.setProperty("volume-max", "100");
      await pp.setProperty("ao", "opensles");
    }

    await mediaPlayer.setAudioTrack(
      AudioTrack.auto(),
    );

    videoController = VideoController(
      mediaPlayer,
      configuration: VideoControllerConfiguration(
        enableHardwareAcceleration: hAenable,
        hwdec: hAenable ? hardwareDecoder : 'no',
        androidAttachSurfaceAfterVideoParameters: false,
      ),
    );
    mediaPlayer.setPlaylistMode(PlaylistMode.none);

    // error handle
    bool showPlayerError =
        setting.get(SettingBoxKey.showPlayerError, defaultValue: true);
    mediaPlayer.stream.error.listen((event) {
      if (showPlayerError) {
        KazumiDialog.showToast(
            message: '播放器内部错误 ${event.toString()} $videoUrl',
            duration: const Duration(seconds: 5),
            showUndoButton: true);
      }
      KazumiLogger().log(
          Level.error, 'Player intent error: ${event.toString()} $videoUrl');
    });

    if (superResolutionType != 1) {
      await setShader(superResolutionType);
    }

    await mediaPlayer.open(
      Media(videoUrl,
          start: Duration(seconds: offset), httpHeaders: httpHeaders),
      play: autoPlay,
    );

    return mediaPlayer;
  }

  Future<void> setShader(int type, {bool synchronized = true}) async {
    var pp = mediaPlayer.platform as NativePlayer;
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
      mediaPlayer.setRate(playerSpeed);
    } catch (e) {
      KazumiLogger().log(Level.error, '设置播放速度失败 ${e.toString()}');
    }
  }

  Future<void> setVolume(double value) async {
    value = value.clamp(0.0, 100.0);
    volume = value;
    try {
      if (Utils.isDesktop()) {
        await mediaPlayer.setVolume(value);
      } else {
        await FlutterVolumeController.updateShowSystemUI(false);
        await FlutterVolumeController.setVolume(value / 100);
      }
    } catch (_) {}
  }

  Future<void> playOrPause() async {
    if (mediaPlayer.state.playing) {
      await pause();
    } else {
      await play();
    }
  }

  Future<void> seek(Duration duration) async {
    currentPosition = duration;
    danmakuController.clear();
    await mediaPlayer.seek(duration);
  }

  Future<void> pause() async {
    danmakuController.pause();
    await mediaPlayer.pause();
    playing = false;
  }

  Future<void> play() async {
    danmakuController.resume();
    await mediaPlayer.play();
    playing = true;
  }

  Future<void> dispose() async {
    try {
      await mediaPlayer.dispose();
    } catch (_) {}
  }

  Future<void> stop() async {
    try {
      await mediaPlayer.stop();
      loading = true;
    } catch (_) {}
  }

  Future<Uint8List?> screenshot({String format = 'image/jpeg'}) async {
    return await mediaPlayer.screenshot(format: format);
  }

  void setForwardTime(int time) {
    forwardTime = time;
  }

  Future<void> getDanDanmaku(String title, int episode) async {
    KazumiLogger().log(Level.info, '尝试获取弹幕 $title');
    try {
      danDanmakus.clear();
      if (isBiliDm) {
        requestedSeg.clear();
        getBiliDanmaku();
      } else {
        bangumiID = await DanmakuRequest.getBangumiID(title);
        var res = await DanmakuRequest.getDanDanmaku(bangumiID, episode);
        addDanmakus(res);
      }
    } catch (e) {
      KazumiLogger().log(Level.warning, '获取弹幕错误 ${e.toString()}');
    }
  }

  Future<void> getDanDanmakuByEpisodeID(int episodeID) async {
    KazumiLogger().log(Level.info, '尝试获取弹幕 $episodeID');
    try {
      danDanmakus.clear();
      if (isBiliDm) {
        requestedSeg.clear();
        getBiliDanmaku();
      } else {
        var res = await DanmakuRequest.getDanDanmakuByEpisodeID(episodeID);
        addDanmakus(res);
      }
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

  late bool isBiliDm = false;
  dynamic cid;
  late final int segmentLength = 60 * 6 * 1000;
  late final Map<int, bool> requestedSeg = {};

  int calcSegment(int progress) {
    return progress ~/ segmentLength;
  }

  Future getBiliDanmaku([int? segmentIndex]) async {
    if (cid == null) return;
    segmentIndex ??= calcSegment(currentPosition.inMilliseconds);
    if (requestedSeg[segmentIndex] == true) return;
    requestedSeg[segmentIndex] = true;
    final DmSegMobileReply result =
        await DanmakuRequest.getBiliDanmaku(cid, segmentIndex + 1);
    KazumiLogger().log(Level.info, 'Bili弹幕: ${result.elems.length}');
    if (result.elems.isNotEmpty) {
      for (var element in result.elems) {
        int pos = element.progress ~/ 1000;
        danDanmakus[pos] ??= [];
        danDanmakus[pos]!.add(element);
      }
    }
  }

  List? getCurrentDanmaku(int progress) {
    int segmentIndex = calcSegment(progress * 1000);
    if (requestedSeg[segmentIndex] != true) {
      getBiliDanmaku(segmentIndex);
    }
    return danDanmakus[progress];
  }
}
