import 'package:video_player/video_player.dart';
import 'package:kazumi/modules/danmaku/danmaku_module.dart';
import 'package:flutter/material.dart' show debugPrint;
import 'package:mobx/mobx.dart';
import 'package:flutter/foundation.dart';
import 'package:canvas_danmaku/canvas_danmaku.dart';
import 'package:kazumi/request/damaku.dart';
import 'package:kazumi/pages/video/video_controller.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:hive/hive.dart';
import 'package:kazumi/utils/storage.dart';

part 'player_controller.g.dart';

class PlayerController = _PlayerController with _$PlayerController;

abstract class _PlayerController with Store {
  @observable
  bool loading = true;

  String videoUrl = '';
  // 弹幕ID
  int bangumiID = 0;
  late VideoPlayerController mediaPlayer;
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

  // 视频音量/亮度
  @observable
  double volume = 0;
  @observable
  double brightness = 0;

  // 播放器倍速
  @observable
  double playerSpeed = 1.0;

  Box setting = GStorage.setting;
  late bool hAenable;

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
    bool aotoPlay = setting.get(SettingBoxKey.autoPlay, defaultValue: true);
    playerSpeed = 1.0;
    if (offset != 0) {
      await mediaPlayer.seekTo(Duration(seconds: offset));
    }
    if (aotoPlay) {
      await mediaPlayer.play();
    }
    debugPrint('VideoURL初始化完成');
    // 加载弹幕
    getDanDanmaku(
        videoPageController.title, videoPageController.currentEspisode);
    loading = false;
  }

  Future<VideoPlayerController> createVideoController() async {
    String userAgent = '';
    if (videoPageController.currentPlugin.userAgent == '') {
      userAgent =
          'Mozilla/5.0 (Macintosh; Intel Mac OS X 13_3_1) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.4 Safari/605.1.15';
    } else {
      debugPrint(
          'media_kit UA: ${videoPageController.currentPlugin.userAgent}');
      userAgent = videoPageController.currentPlugin.userAgent;
    }
    var httpHeaders = {
      'user-agent': userAgent,
    };
    mediaPlayer = VideoPlayerController.networkUrl(Uri.parse(videoUrl),
        httpHeaders: httpHeaders);
    await mediaPlayer.initialize();
    debugPrint('videoController 配置成功 $videoUrl');
    return mediaPlayer;
  }

  Future setPlaybackSpeed(double playerSpeed) async {
    this.playerSpeed = playerSpeed;
    try {
      mediaPlayer.setPlaybackSpeed(playerSpeed);
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  Future playOrPause() async {
    if (mediaPlayer.value.isPlaying) {
      await pause();
    } else {
      await play();
    }
  }

  Future seek(Duration duration) async {
    danmakuController.clear();
    await mediaPlayer.seekTo(duration);
  }

  Future pause() async {
    danmakuController.pause();
    await mediaPlayer.pause();
    playing = false;
  }

  Future play() async {
    danmakuController.resume();
    await mediaPlayer.play();
    playing = true;
  }

  Future getDanDanmaku(String title, int episode) async {
    debugPrint('尝试获取弹幕 $title');
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
          danDanmakus[element.time.toInt()] ?? List.empty(growable: true);
      danmakuList.add(element);
      danDanmakus[element.time.toInt()] = danmakuList;
    }
  }
}
