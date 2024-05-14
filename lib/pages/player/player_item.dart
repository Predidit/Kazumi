import 'dart:io';

import 'package:kazumi/pages/player/player_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/pages/video/video_controller.dart';

class PlayerItem extends StatefulWidget {
  const PlayerItem({super.key});

  @override
  State<PlayerItem> createState() => _PlayerItemState();
}

class _PlayerItemState extends State<PlayerItem> {
  final PlayerController playerController = Modular.get<PlayerController>();
  final VideoPageController videoPageController =
      Modular.get<VideoPageController>();

  @override
  void initState() {
    super.initState();
    // debugPrint('在小部件中初始化');
    // playerController.init;
  }

  @override
  void dispose() {
    //player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // const Text('Video Player Test'),
        Observer(builder: (context) {
          return Expanded(
            child: playerController.loading ? const Center(child: CircularProgressIndicator()) : Video(
              controller: playerController.videoController,
              // 测试 等待引入现代面板
              // controls: NoVideoControls,
              subtitleViewConfiguration: SubtitleViewConfiguration(
                style: TextStyle(
                  color: Colors.pink, // 深粉色字体
                  fontSize: 48.0, // 较大的字号
                  background: Paint()..color = Colors.transparent, // 背景透明
                  decoration: TextDecoration.none, // 无下划线
                  fontWeight: FontWeight.bold, // 字体加粗
                  shadows: const [
                    // 显眼的包边
                    Shadow(
                      offset: Offset(1.0, 1.0),
                      blurRadius: 3.0,
                      color: Color.fromARGB(255, 255, 255, 255),
                    ),
                    Shadow(
                      offset: Offset(-1.0, -1.0),
                      blurRadius: 3.0,
                      color: Color.fromARGB(125, 255, 255, 255),
                    ),
                  ],
                ),
                textAlign: TextAlign.center,
                padding: const EdgeInsets.all(24.0),
              ),
            ),
          );
        }),
      ],
    );
  }
}
