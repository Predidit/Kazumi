import 'dart:io';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:flutter/material.dart' show debugPrint;
import 'package:mobx/mobx.dart';

part 'player_controller.g.dart';

class PlayerController = _PlayerController with _$PlayerController;

abstract class _PlayerController with Store {
  @observable
  bool loading = true;

  String videoUrl = '';
  late Player mediaPlayer;
  late VideoController videoController;

  @action
  Future init({int offset = 0}) async {
    loading = true;
    try {
      mediaPlayer.dispose();
      debugPrint('找到逃掉的 player');
    } catch (e) {
      debugPrint('未找到已经存在的 player');
    }
    debugPrint('VideoURL开始初始化');
    mediaPlayer = await createVideoController();
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
    loading = false;
  }

  Future<Player> createVideoController() async {
    mediaPlayer = Player(
      configuration: const PlayerConfiguration(
        // 默认缓存 5M 大小
        bufferSize: 5 * 1024 * 1024, //panic
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
}
