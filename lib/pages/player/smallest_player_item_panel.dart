import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/utils/utils.dart';
import 'package:kazumi/pages/video/video_controller.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/pages/player/player_controller.dart';
import 'package:flutter/services.dart';
import 'package:kazumi/utils/remote.dart';
import 'package:kazumi/pages/settings/danmaku/danmaku_settings_window.dart';
import 'package:kazumi/bean/widget/collect_button.dart';
import 'package:kazumi/pages/info/info_controller.dart';
import 'package:kazumi/utils/constants.dart';
import 'package:hive/hive.dart';
import 'package:kazumi/utils/storage.dart';
import 'package:audio_video_progress_bar/audio_video_progress_bar.dart';

class SmallestPlayerItemPanel extends StatefulWidget {
  const SmallestPlayerItemPanel({
    super.key,
    required this.onBackPressed,
    required this.setPlaybackSpeed,
    required this.showDanmakuSwitch,
    required this.handleFullscreen,
    required this.handleProgressBarDragStart,
    required this.handleProgressBarDragEnd,
    required this.animationController,
    required this.keyboardFocus,
    required this.handleHove,
  });

  final void Function(BuildContext) onBackPressed;
  final Future<void> Function(double) setPlaybackSpeed;
  final void Function() showDanmakuSwitch;
  final void Function() handleFullscreen;
  final void Function(ThumbDragDetails details) handleProgressBarDragStart;
  final void Function() handleProgressBarDragEnd;
  final void Function() handleHove;
  final AnimationController animationController;
  final FocusNode keyboardFocus;

  @override
  State<SmallestPlayerItemPanel> createState() =>
      _SmallestPlayerItemPanelState();
}

class _SmallestPlayerItemPanelState extends State<SmallestPlayerItemPanel> {
  Box setting = GStorage.setting;
  late bool haEnable;
  late Animation<Offset> topOffsetAnimation;
  late Animation<Offset> bottomOffsetAnimation;
  late Animation<Offset> leftOffsetAnimation;
  final VideoPageController videoPageController =
      Modular.get<VideoPageController>();
  final InfoController infoController = Modular.get<InfoController>();
  final PlayerController playerController = Modular.get<PlayerController>();
  final TextEditingController textController = TextEditingController();

  void _handleDanmaku() {
    if (playerController.danDanmakus.isEmpty) {
      widget.showDanmakuSwitch();
      return;
    }
    playerController.danmakuController.onClear();
    playerController.danmakuOn = !playerController.danmakuOn;
  }

  void showVideoInfo() async {
    String currentDemux = await Utils.getCurrentDemux();
    KazumiDialog.show(
        // onDismiss: () {
        //   _focusNode.requestFocus();
        // },
        builder: (context) {
      return AlertDialog(
        title: const Text('视频详情'),
        content: SelectableText.rich(
          TextSpan(
            children: [
              TextSpan(text: '规则: ${videoPageController.currentPlugin.name}\n'),
              TextSpan(text: '硬件解码: ${haEnable ? '启用' : '禁用'}\n'),
              TextSpan(text: '解复用器: $currentDemux\n'),
              const TextSpan(text: '资源地址: '),
              TextSpan(
                text: playerController.videoUrl,
              ),
            ],
          ),
          style: Theme.of(context).textTheme.bodyLarge!,
        ),
        actions: const [
          TextButton(onPressed: KazumiDialog.dismiss, child: Text('取消')),
        ],
      );
    });
  }

  void showForwardChange() {
    KazumiDialog.show(builder: (context) {
      String input = "";
      return AlertDialog(
        title: const Text('跳过秒数'),
        content: StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
          return TextField(
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly, // 只允许输入数字
            ],
            decoration: InputDecoration(
              floatingLabelBehavior:
                  FloatingLabelBehavior.never, // 控制label的显示方式
              labelText: playerController.forwardTime.toString(),
            ),
            onChanged: (value) {
              input = value;
            },
          );
        }),
        actions: <Widget>[
          TextButton(
            onPressed: () => KazumiDialog.dismiss(),
            child: Text(
              '取消',
              style: TextStyle(color: Theme.of(context).colorScheme.outline),
            ),
          ),
          TextButton(
            onPressed: () async {
              if (input != "") {
                playerController.setForwardTime(int.parse(input));
                KazumiDialog.dismiss();
              } else {
                KazumiDialog.dismiss();
              }
            },
            child: const Text('确定'),
          ),
        ],
      );
    });
  }

  @override
  void initState() {
    super.initState();
    topOffsetAnimation = Tween<Offset>(
      begin: const Offset(0.0, -1.0),
      end: const Offset(0.0, 0.0),
    ).animate(CurvedAnimation(
      parent: widget.animationController,
      curve: Curves.easeInOut,
    ));
    bottomOffsetAnimation = Tween<Offset>(
      begin: const Offset(0.0, 1.0),
      end: const Offset(0.0, 0.0),
    ).animate(CurvedAnimation(
      parent: widget.animationController,
      curve: Curves.easeInOut,
    ));
    leftOffsetAnimation = Tween<Offset>(
      begin: const Offset(1.0, 0.0),
      end: const Offset(0.0, 0.0),
    ).animate(CurvedAnimation(
      parent: widget.animationController,
      curve: Curves.easeInOut,
    ));
    haEnable = setting.get(SettingBoxKey.hAenable, defaultValue: true);
  }

  Widget forwardIcon() {
    return Tooltip(
      message: '长按修改时间',
      child: GestureDetector(
        onLongPress: () => showForwardChange(),
        child: IconButton(
          icon: Image.asset(
            'assets/images/forward_80.png',
            color: Colors.white,
            height: 24,
          ),
          onPressed: () {
            playerController.seek(playerController.currentPosition +
                Duration(seconds: playerController.forwardTime));
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Observer(builder: (context) {
      return Stack(
        alignment: Alignment.center,
        children: [
          //顶部渐变区域
          AnimatedPositioned(
            duration: const Duration(seconds: 1),
            top: 0,
            left: 0,
            right: 0,
            child: Visibility(
              visible: !playerController.lockPanel,
              child: SlideTransition(
                position: topOffsetAnimation,
                child: Container(
                  height: 50,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withOpacity(0.9),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          //底部渐变区域
          AnimatedPositioned(
            duration: const Duration(seconds: 1),
            bottom: 0,
            left: 0,
            right: 0,
            child: Visibility(
              visible: !playerController.lockPanel,
              child: SlideTransition(
                position: bottomOffsetAnimation,
                child: Container(
                  height: 50,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(0.9),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          // 顶部进度条
          Positioned(
              top: 25,
              child: playerController.showSeekTime
                  ? Wrap(
                      alignment: WrapAlignment.center,
                      children: <Widget>[
                        Container(
                          padding: const EdgeInsets.all(8.0),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(8.0), // 圆角
                          ),
                          child: Text(
                            playerController.currentPosition.compareTo(
                                        playerController.playerPosition) >
                                    0
                                ? '快进 ${playerController.currentPosition.inSeconds - playerController.playerPosition.inSeconds} 秒'
                                : '快退 ${playerController.playerPosition.inSeconds - playerController.currentPosition.inSeconds} 秒',
                            style: const TextStyle(
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    )
                  : Container()),
          // 顶部播放速度条
          Positioned(
              top: 25,
              child: playerController.showPlaySpeed
                  ? Wrap(
                      alignment: WrapAlignment.center,
                      children: <Widget>[
                        Container(
                          padding: const EdgeInsets.all(8.0),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(8.0), // 圆角
                          ),
                          child: const Row(
                            children: <Widget>[
                              Icon(Icons.fast_forward, color: Colors.white),
                              Text(
                                ' 倍速播放',
                                style: TextStyle(
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    )
                  : Container()),
          // 亮度条
          Positioned(
              top: 25,
              child: playerController.showBrightness
                  ? Wrap(
                      alignment: WrapAlignment.center,
                      children: <Widget>[
                        Container(
                            padding: const EdgeInsets.all(8.0),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(8.0), // 圆角
                            ),
                            child: Row(
                              children: <Widget>[
                                const Icon(Icons.brightness_7,
                                    color: Colors.white),
                                Text(
                                  ' ${(playerController.brightness * 100).toInt()} %',
                                  style: const TextStyle(
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            )),
                      ],
                    )
                  : Container()),
          // 音量条
          Positioned(
              top: 25,
              child: playerController.showVolume
                  ? Wrap(
                      alignment: WrapAlignment.center,
                      children: <Widget>[
                        Container(
                            padding: const EdgeInsets.all(8.0),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(8.0), // 圆角
                            ),
                            child: Row(
                              children: <Widget>[
                                const Icon(Icons.volume_down,
                                    color: Colors.white),
                                Text(
                                  ' ${playerController.volume.toInt()}%',
                                  style: const TextStyle(
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            )),
                      ],
                    )
                  : Container()),
          // 自定义顶部组件
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Visibility(
              visible: !playerController.lockPanel,
              child: SlideTransition(
                position: topOffsetAnimation,
                child: Row(
                  children: [
                    IconButton(
                      color: Colors.white,
                      icon: const Icon(Icons.arrow_back_rounded),
                      onPressed: () {
                        widget.onBackPressed(context);
                      },
                    ),
                    const Spacer(),
                    // 跳过
                    forwardIcon(),
                    // 弹幕开关
                    IconButton(
                      color: Colors.white,
                      icon: Icon(playerController.danmakuOn
                          ? Icons.subtitles_rounded
                          : Icons.subtitles_off_rounded),
                      onPressed: () {
                        _handleDanmaku();
                        setState(() {});
                      },
                      tooltip: playerController.danmakuOn ? '关闭弹幕' : '打开弹幕',
                    ),
                    // 追番
                    CollectButton(bangumiItem: infoController.bangumiItem),
                    MenuAnchor(
                      consumeOutsideTap: true,
                      builder: (BuildContext context, MenuController controller,
                          Widget? child) {
                        return IconButton(
                          onPressed: () {
                            if (controller.isOpen) {
                              controller.close();
                            } else {
                              controller.open();
                            }
                          },
                          icon: const Icon(
                            Icons.more_vert,
                            color: Colors.white,
                          ),
                        );
                      },
                      menuChildren: [
                        SubmenuButton(
                          menuChildren: List<MenuItemButton>.generate(
                            3,
                            (int index) => MenuItemButton(
                              onPressed: () =>
                                  playerController.aspectRatioType = index + 1,
                              child: Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(0, 10, 10, 10),
                                child: Text(
                                  index + 1 == 1
                                      ? '自动'
                                      : index + 1 == 2
                                          ? '裁切填充'
                                          : '拉伸填充',
                                  style: TextStyle(
                                      color: index + 1 ==
                                              playerController.aspectRatioType
                                          ? Theme.of(context)
                                              .colorScheme
                                              .primary
                                          : null),
                                ),
                              ),
                            ),
                          ),
                          child: const Padding(
                            padding: EdgeInsets.fromLTRB(0, 10, 10, 10),
                            child: Text("视频比例"),
                          ),
                        ),
                        SubmenuButton(
                          menuChildren: [
                            for (final double i
                                in defaultPlaySpeedList) ...<MenuItemButton>[
                              MenuItemButton(
                                onPressed: () async {
                                  await widget.setPlaybackSpeed(i);
                                },
                                child: Padding(
                                  padding:
                                      const EdgeInsets.fromLTRB(0, 10, 10, 10),
                                  child: Text(
                                    '${i}x',
                                    style: TextStyle(
                                        color: i == playerController.playerSpeed
                                            ? Theme.of(context)
                                                .colorScheme
                                                .primary
                                            : null),
                                  ),
                                ),
                              ),
                            ],
                          ],
                          child: const Padding(
                            padding: EdgeInsets.fromLTRB(0, 10, 10, 10),
                            child: Text("倍速"),
                          ),
                        ),
                        SubmenuButton(
                          menuChildren: List<MenuItemButton>.generate(
                            3,
                            (int index) => MenuItemButton(
                              onPressed: () =>
                                  playerController.setShader(index + 1),
                              child: Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(0, 10, 10, 10),
                                child: Text(
                                  index + 1 == 1
                                      ? '关闭'
                                      : index + 1 == 2
                                          ? '效率档'
                                          : '质量档',
                                  style: TextStyle(
                                    color: playerController
                                                .superResolutionType ==
                                            index + 1
                                        ? Theme.of(context).colorScheme.primary
                                        : null,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          child: const Padding(
                            padding: EdgeInsets.fromLTRB(0, 10, 10, 10),
                            child: Text("超分辨率"),
                          ),
                        ),
                        MenuItemButton(
                          onPressed: () {
                            widget.showDanmakuSwitch();
                          },
                          child: const Padding(
                            padding: EdgeInsets.fromLTRB(0, 10, 10, 10),
                            child: Text("弹幕切换"),
                          ),
                        ),
                        MenuItemButton(
                          onPressed: () {
                            KazumiDialog.show(builder: (context) {
                              return DanmakuSettingsWindow(
                                  danmakuController:
                                      playerController.danmakuController);
                            });
                          },
                          child: const Padding(
                            padding: EdgeInsets.fromLTRB(0, 10, 10, 10),
                            child: Text("弹幕设置"),
                          ),
                        ),
                        MenuItemButton(
                          onPressed: () {
                            showVideoInfo();
                          },
                          child: const Padding(
                            padding: EdgeInsets.fromLTRB(0, 10, 10, 10),
                            child: Text("视频详情"),
                          ),
                        ),
                        MenuItemButton(
                          onPressed: () {
                            bool needRestart = playerController.playing;
                            playerController.pause();
                            RemotePlay()
                                .castVideo(context,
                                    videoPageController.currentPlugin.referer)
                                .whenComplete(() {
                              if (needRestart) {
                                playerController.play();
                              }
                            });
                          },
                          child: const Padding(
                            padding: EdgeInsets.fromLTRB(0, 10, 10, 10),
                            child: Text("远程播放"),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          // 自定义播放器底部组件
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Visibility(
              visible: !playerController.lockPanel,
              child: SlideTransition(
                position: bottomOffsetAnimation,
                child: Row(
                  children: [
                    IconButton(
                      color: Colors.white,
                      icon: Icon(playerController.playing
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded),
                      onPressed: () {
                        playerController.playOrPause();
                      },
                    ),
                    Expanded(
                      child: ProgressBar(
                        thumbRadius: 8,
                        thumbGlowRadius: 18,
                        timeLabelLocation: TimeLabelLocation.none,
                        progress: playerController.currentPosition,
                        buffered: playerController.buffer,
                        total: playerController.duration,
                        onSeek: (duration) {
                          playerController.seek(duration);
                        },
                        onDragStart: (details) {
                          widget.handleProgressBarDragStart(details);
                        },
                        onDragUpdate: (details) => {
                          playerController.currentPosition = details.timeStamp
                        },
                        onDragEnd: () {
                          widget.handleProgressBarDragEnd();
                        },
                      ),
                    ),
                    Text(
                      "    ${Utils.durationToString(playerController.currentPosition)} / ${Utils.durationToString(playerController.duration)}",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12.0,
                        fontFeatures: [
                          FontFeature.tabularFigures(),
                        ],
                      ),
                    ),
                    IconButton(
                      color: Colors.white,
                      icon: Icon(videoPageController.isFullscreen
                          ? Icons.fullscreen_exit_rounded
                          : Icons.fullscreen_rounded),
                      onPressed: () {
                        widget.handleFullscreen();
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    });
  }
}
