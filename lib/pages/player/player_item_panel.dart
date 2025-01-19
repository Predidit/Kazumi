import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/utils/utils.dart';
import 'package:kazumi/pages/video/video_controller.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/pages/player/player_controller.dart';
import 'package:saver_gallery/saver_gallery.dart';
import 'package:flutter/services.dart';
import 'package:kazumi/utils/remote.dart';
import 'package:kazumi/bean/appbar/drag_to_move_bar.dart' as dtb;
import 'package:kazumi/pages/settings/danmaku/danmaku_settings_window.dart';
import 'package:kazumi/bean/widget/collect_button.dart';
import 'package:kazumi/pages/info/info_controller.dart';
import 'package:kazumi/utils/constants.dart';
import 'package:hive/hive.dart';
import 'package:kazumi/utils/storage.dart';
import 'package:canvas_danmaku/canvas_danmaku.dart';
import 'package:audio_video_progress_bar/audio_video_progress_bar.dart';

class PlayerItemPanel extends StatefulWidget {
  const PlayerItemPanel({
    super.key,
    required this.onBackPressed,
    required this.setPlaybackSpeed,
    required this.showDanmakuSwitch,
    required this.changeEpisode,
    required this.handleFullscreen,
    required this.handleProgressBarDragStart,
    required this.handleProgressBarDragEnd,
    required this.animationController,
    required this.openMenu,
    required this.keyboardFocus,
    required this.handleHove,
  });

  final void Function(BuildContext) onBackPressed;
  final Future<void> Function(double) setPlaybackSpeed;
  final void Function() showDanmakuSwitch;
  final Future<void> Function(int, {int currentRoad, int offset}) changeEpisode;
  final void Function() openMenu;
  final void Function() handleFullscreen;
  final void Function(ThumbDragDetails details) handleProgressBarDragStart;
  final void Function() handleProgressBarDragEnd;
  final void Function() handleHove;
  final AnimationController animationController;
  final FocusNode keyboardFocus;

  @override
  State<PlayerItemPanel> createState() => _PlayerItemPanelState();
}

class _PlayerItemPanelState extends State<PlayerItemPanel> {
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

  Future<void> _handleScreenshot() async {
    KazumiDialog.showToast(message: '截图中...');
    try {
      Uint8List? screenshot =
          await playerController.screenshot(format: 'image/png');
      final result = await SaverGallery.saveImage(screenshot!,
          fileName: DateTime.timestamp().toString(), skipIfExists: false);
      if (result.isSuccess) {
        KazumiDialog.showToast(message: '截图保存到相簿成功');
      } else {
        KazumiDialog.showToast(message: '截图保存失败：${result.errorMessage}');
      }
    } catch (e) {
      KazumiDialog.showToast(message: '截图失败：$e');
    }
  }

  void _handleDanmaku() {
    if (playerController.danDanmakus.isEmpty) {
      widget.showDanmakuSwitch();
      return;
    }
    playerController.danmakuController.onClear();
    playerController.danmakuOn = !playerController.danmakuOn;
  }

  /// 发送弹幕 由于接口限制, 暂时未提交云端
  void sendDanmaku() async {
    widget.keyboardFocus.requestFocus();
    if (playerController.danDanmakus.isEmpty) {
      KazumiDialog.showToast(
        message: '当前剧集不支持弹幕发送的说',
      );
      return;
    }
    final String msg = textController.text;
    if (msg.isEmpty) {
      KazumiDialog.showToast(message: '弹幕内容为空');
      return;
    } else if (msg.length > 100) {
      KazumiDialog.showToast(message: '弹幕内容过长');
      return;
    }
    // Todo 接口方限制

    KazumiDialog.showToast(message: '发送成功');
    playerController.danmakuController
        .addDanmaku(DanmakuContentItem(msg, selfSend: true));
    textController.clear();
  }

  Widget danmakuTextField() {
    return Container(
      constraints: const BoxConstraints(maxWidth: 500, maxHeight: 33),
      child: TextField(
        style: const TextStyle(fontSize: 15),
        controller: textController,
        textAlignVertical: TextAlignVertical.center,
        decoration: InputDecoration(
          enabled: playerController.danmakuOn,
          filled: true,
          fillColor: Colors.white30,
          floatingLabelBehavior: FloatingLabelBehavior.never,
          hintText: playerController.danmakuOn ? '发个友善的弹幕见证当下' : '已关闭弹幕',
          hintStyle: const TextStyle(fontSize: 15),
          alignLabelWithHint: true,
          contentPadding:
              const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
          border: const OutlineInputBorder(
            borderSide: BorderSide.none,
            borderRadius: BorderRadius.all(Radius.circular(8)),
          ),
          suffixIcon: TextButton(
            onPressed: () {
              sendDanmaku();
            },
            style: TextButton.styleFrom(
              foregroundColor: playerController.danmakuOn
                  ? Theme.of(context).colorScheme.onPrimaryContainer
                  : Colors.white,
              backgroundColor: playerController.danmakuOn
                  ? Theme.of(context).colorScheme.primaryContainer
                  : Theme.of(context).disabledColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('发送'),
          ),
        ),
        onChanged: (_) {
          widget.handleHove();
        },
        onSubmitted: (_) {
          sendDanmaku();
        },
        onTapOutside: (_) {
          widget.keyboardFocus.requestFocus(FocusNode());
        },
      ),
    );
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

  // 选择倍速
  void showSetSpeedSheet() {
    final double currentSpeed = playerController.playerSpeed;
    KazumiDialog.show(builder: (context) {
      return AlertDialog(
        title: const Text('播放速度'),
        content: StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
          return Wrap(
            spacing: 8,
            runSpacing: Utils.isDesktop() ? 8 : 0,
            children: [
              for (final double i in defaultPlaySpeedList) ...<Widget>[
                if (i == currentSpeed)
                  FilledButton(
                    onPressed: () async {
                      await widget.setPlaybackSpeed(i);
                      KazumiDialog.dismiss();
                    },
                    child: Text(i.toString()),
                  )
                else
                  FilledButton.tonal(
                    onPressed: () async {
                      await widget.setPlaybackSpeed(i);
                      KazumiDialog.dismiss();
                    },
                    child: Text(i.toString()),
                  ),
              ]
            ],
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
              await widget.setPlaybackSpeed(1.0);
              KazumiDialog.dismiss();
            },
            child: const Text('默认速度'),
          ),
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
                  height: 60,
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
                            color: Colors.black.withOpacity(0.5),
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
                            color: Colors.black.withOpacity(0.5),
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
                              color: Colors.black.withOpacity(0.5),
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
                              color: Colors.black.withOpacity(0.5),
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
          // 右侧锁定按钮
          (Utils.isDesktop() || !videoPageController.isFullscreen)
              ? Container()
              : Positioned(
                  right: 0,
                  top: 0,
                  bottom: 0,
                  child: SlideTransition(
                    position: leftOffsetAnimation,
                    child: Column(children: [
                      const Spacer(),
                      (playerController.lockPanel)
                          ? Container()
                          : IconButton(
                              icon: const Icon(
                                Icons.photo_camera_outlined,
                                color: Colors.white,
                              ),
                              onPressed: () {
                                _handleScreenshot();
                              },
                            ),
                      IconButton(
                        icon: Icon(
                          playerController.lockPanel
                              ? Icons.lock_outline
                              : Icons.lock_open,
                          color: Colors.white,
                        ),
                        onPressed: () {
                          playerController.lockPanel =
                              !playerController.lockPanel;
                        },
                      ),
                      const Spacer(),
                    ]),
                  ),
                ),
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
                    (videoPageController.isFullscreen || Utils.isDesktop())
                        ? Text(
                            ' ${videoPageController.title} [${videoPageController.roadList[videoPageController.currentRoad].identifier[videoPageController.currentEpisode - 1]}]',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: Theme.of(context)
                                    .textTheme
                                    .titleMedium!
                                    .fontSize),
                          )
                        : Container(),
                    // 拖动条
                    const Expanded(
                      child: dtb.DragToMoveArea(child: SizedBox(height: 40)),
                    ),
                    forwardIcon(),
                    // 追番
                    CollectButton(bangumiItem: infoController.bangumiItem),
                    MenuAnchor(
                        builder: (BuildContext context,
                            MenuController controller, Widget? child) {
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
                        ]),
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
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
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
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
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
                          // 更换选集
                          (videoPageController.isFullscreen ||
                                  Utils.isTablet() ||
                                  Utils.isDesktop())
                              ? IconButton(
                                  color: Colors.white,
                                  icon: const Icon(Icons.skip_next_rounded),
                                  onPressed: () {
                                    if (videoPageController.loading) {
                                      return;
                                    }
                                    if (videoPageController.currentEpisode ==
                                        videoPageController
                                            .roadList[
                                                videoPageController.currentRoad]
                                            .data
                                            .length) {
                                      KazumiDialog.showToast(
                                        message: '已经是最新一集',
                                      );
                                      return;
                                    }
                                    KazumiDialog.showToast(
                                        message:
                                            '正在加载${videoPageController.roadList[videoPageController.currentRoad].identifier[videoPageController.currentEpisode]}');
                                    widget.changeEpisode(
                                        videoPageController.currentEpisode + 1,
                                        currentRoad:
                                            videoPageController.currentRoad);
                                  },
                                )
                              : Container(),
                          ((Utils.isCompact()) &&
                                  !videoPageController.isFullscreen)
                              ? Container()
                              : Container(
                                  padding: const EdgeInsets.only(left: 10.0),
                                  child: Text(
                                    "${Utils.durationToString(playerController.currentPosition)} / ${Utils.durationToString(playerController.duration)}",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize:
                                          !Utils.isCompact() ? 16.0 : 12.0,
                                      fontFeatures: const [
                                        FontFeature.tabularFigures(),
                                      ],
                                    ),
                                  ),
                                ),
                          Expanded(
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                bool isSpaceEnough = constraints.maxWidth > 600;
                                return Center(
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      IconButton(
                                        color: Colors.white,
                                        icon: Icon(playerController.danmakuOn
                                            ? Icons.subtitles_rounded
                                            : Icons.subtitles_off_rounded),
                                        onPressed: () {
                                          _handleDanmaku();
                                          setState(() {});
                                        },
                                        tooltip: playerController.danmakuOn
                                            ? '关闭弹幕(d)'
                                            : '打开弹幕(d)',
                                      ),
                                      IconButton(
                                        tooltip: '弹幕设置',
                                        onPressed: () {
                                          widget.keyboardFocus.requestFocus();
                                          KazumiDialog.show(builder: (context) {
                                            return DanmakuSettingsWindow(
                                                danmakuController:
                                                    playerController
                                                        .danmakuController);
                                          });
                                        },
                                        color: Colors.white,
                                        icon: const Icon(Icons.tune_rounded),
                                      ),
                                      if (isSpaceEnough) danmakuTextField(),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                          // 超分辨率
                          MenuAnchor(
                            builder: (BuildContext context,
                                MenuController controller, Widget? child) {
                              return TextButton(
                                onPressed: () {
                                  if (controller.isOpen) {
                                    controller.close();
                                  } else {
                                    controller.open();
                                  }
                                },
                                child: const Text(
                                  '超分辨率',
                                  style: TextStyle(color: Colors.white),
                                ),
                              );
                            },
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
                                        ? 'OFF'
                                        : index + 1 == 2
                                            ? 'Efficiency'
                                            : 'Quality',
                                    style: TextStyle(
                                      color: playerController
                                                  .superResolutionType ==
                                              index + 1
                                          ? Theme.of(context)
                                              .colorScheme
                                              .primary
                                          : Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          // 倍速播放
                          MenuAnchor(
                            builder: (BuildContext context,
                                MenuController controller, Widget? child) {
                              return TextButton(
                                onPressed: () {
                                  if (controller.isOpen) {
                                    controller.close();
                                  } else {
                                    controller.open();
                                  }
                                },
                                child: Text(
                                  playerController.playerSpeed == 1.0
                                      ? '倍速'
                                      : '${playerController.playerSpeed}x',
                                  style: const TextStyle(color: Colors.white),
                                ),
                              );
                            },
                            menuChildren: [
                              for (final double i
                                  in defaultPlaySpeedList) ...<MenuItemButton>[
                                MenuItemButton(
                                  onPressed: () async {
                                    await widget.setPlaybackSpeed(i);
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                        0, 10, 10, 10),
                                    child: Text(
                                      '${i}x',
                                      style: TextStyle(
                                          color:
                                              i == playerController.playerSpeed
                                                  ? Theme.of(context)
                                                      .colorScheme
                                                      .primary
                                                  : Colors.white),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          MenuAnchor(
                            builder: (BuildContext context,
                                MenuController controller, Widget? child) {
                              return IconButton(
                                onPressed: () {
                                  if (controller.isOpen) {
                                    controller.close();
                                  } else {
                                    controller.open();
                                  }
                                },
                                icon: const Icon(
                                  Icons.aspect_ratio_rounded,
                                  color: Colors.white,
                                ),
                                tooltip: '视频比例',
                              );
                            },
                            menuChildren: List<MenuItemButton>.generate(
                              3,
                              (int index) => MenuItemButton(
                                onPressed: () => playerController
                                    .aspectRatioType = index + 1,
                                child: Padding(
                                  padding:
                                      const EdgeInsets.fromLTRB(0, 10, 10, 10),
                                  child: Text(
                                    index + 1 == 1
                                        ? 'AUTO'
                                        : index + 1 == 2
                                            ? 'COVER'
                                            : 'FILL',
                                    style: TextStyle(
                                        color: index + 1 ==
                                                playerController.aspectRatioType
                                            ? Theme.of(context)
                                                .colorScheme
                                                .primary
                                            : Colors.white),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          (!videoPageController.isFullscreen &&
                                  !Utils.isTablet() &&
                                  !Utils.isDesktop())
                              ? Container()
                              : IconButton(
                                  color: Colors.white,
                                  icon: const Icon(Icons.menu_open_rounded),
                                  onPressed: () {
                                    videoPageController.showTabBody =
                                        !videoPageController.showTabBody;
                                    widget.openMenu();
                                  },
                                ),
                          (Utils.isTablet() &&
                                  videoPageController.isFullscreen &&
                                  MediaQuery.of(context).size.height <
                                      MediaQuery.of(context).size.width)
                              ? Container()
                              : IconButton(
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
                    const SizedBox(height: 6),
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
