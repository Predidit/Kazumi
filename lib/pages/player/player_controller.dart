import 'dart:io';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:kazumi/modules/danmaku/danmaku_module.dart';
import 'package:flutter/material.dart' show debugPrint;
import 'package:mobx/mobx.dart';
import 'package:flutter/foundation.dart';
import 'package:canvas_danmaku/canvas_danmaku.dart';
import 'package:kazumi/request/damaku.dart';
import 'package:kazumi/pages/video/video_controller.dart';
import 'package:flutter_modular/flutter_modular.dart';

part 'player_controller.g.dart';

class PlayerController = _PlayerController with _$PlayerController;

abstract class _PlayerController with Store {
  @observable
  bool loading = true;

  String videoUrl = '';
  // 弹幕ID
  int bangumiID = 0;
  late Player mediaPlayer;
  late VideoController videoController;
  late DanmakuController danmakuController;
  final VideoPageController videoPageController =
      Modular.get<VideoPageController>();

  @observable
  Map<int, List<Danmaku>> danDanmakus = {};

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

  // 弹幕开关
  @observable
  bool danmakuOn = false;

  // 界面管理
  @observable
  bool showPositioned = false;
  @observable
  bool showPosition = false;
  @observable
  bool showBrightness = false;
  @observable
  bool showVolume = false;

  // 视频音量/亮度
  @observable
  double volume = 0;
  @observable
  double brightness = 0;

  // 播放器倍速
  @observable
  double playerSpeed = 1.0;

  Future init({int offset = 0}) async {
    playing = false;
    loading = true;
    isBuffering = true;
    currentPosition = Duration.zero;
    buffer = Duration.zero;
    duration = Duration.zero;
    completed = false;
    try {
      mediaPlayer.dispose();
      debugPrint('找到逃掉的 player');
    } catch (e) {
      debugPrint('未找到已经存在的 player');
    }
    debugPrint('VideoItem开始初始化');
    mediaPlayer = await createVideoController();
    playerSpeed = 1.0;
    if (offset != 0) {
      var sub = mediaPlayer.stream.buffer.listen(null);
      sub.onData((event) async {
        if (event.inSeconds > 0) {
          // This is a workaround for unable to await for `mediaPlayer.stream.buffer.first`
          // It seems that when the `buffer.first` is fired, the media is not fully loaded
          // and the player will not seek properlly.
          await sub.cancel();
          await mediaPlayer.seek(Duration(seconds: offset));
        }
      });
    }
    debugPrint('VideoURL初始化完成');
    // 加载弹幕
    getDanDanmaku(
        videoPageController.title, videoPageController.currentEspisode);
    loading = false;
  }

  Future<Player> createVideoController() async {
    mediaPlayer = Player(
      configuration: const PlayerConfiguration(
        // 默认缓存 5M 大小
        bufferSize: 5 * 1024 * 1024,
      ),
    );

    var pp = mediaPlayer.platform as NativePlayer;
    // 解除倍速限制
    await pp.setProperty("af", "scaletempo2=max-speed=8");
    //  音量不一致
    if (Platform.isAndroid) {
      await pp.setProperty("volume-max", "100");
      await pp.setProperty("ao", "audiotrack,opensles");
    }

    await mediaPlayer.setAudioTrack(
      AudioTrack.auto(),
    );

    videoController = VideoController(
      mediaPlayer,
      configuration: const VideoControllerConfiguration(
        enableHardwareAcceleration: true,
        androidAttachSurfaceAfterVideoParameters: false,
      ),
    );
    debugPrint('videoController 配置成功 $videoUrl');

    mediaPlayer.setPlaylistMode(PlaylistMode.none);
    mediaPlayer.open(
      Media(videoUrl),
      // 测试 自动播放待补充
      play: true,
    );
    return mediaPlayer;
  }

  Future setPlaybackSpeed(double playerSpeed) async {
    this.playerSpeed = playerSpeed;
    try {
      mediaPlayer.setRate(playerSpeed);
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  Future playOrPause() async {
    mediaPlayer.state.playing
        ? danmakuController.pause()
        : danmakuController.resume();
    await mediaPlayer.playOrPause();
  }

  Future seek(Duration duration) async {
    danmakuController.clear();
    await mediaPlayer.seek(duration);
  }

  Future pause() async {
    danmakuController.pause();
    await mediaPlayer.pause();
  }

  Future play() async {
    danmakuController.resume();
    await mediaPlayer.play();
  }

  Future getDanDanmaku(String title, int episode) async {
    try {
      danDanmakus.clear();
      bangumiID = await DanmakuRequest.getBangumiID(title);
      var res = await DanmakuRequest.getDanDanmaku(bangumiID, episode);
      addDanmakus(res);
    } catch (e) {
      debugPrint('获取弹幕错误 ${e.toString()}');
    }
  }

  void addDanmakus(List<Danmaku> danmakus) {
    for (var element in danmakus) {
      var danmakuList =
          danDanmakus[element.p.toInt()] ?? List.empty(growable: true);
      danmakuList.add(element);
      danDanmakus[element.p.toInt()] = danmakuList;
    }
  }
}
