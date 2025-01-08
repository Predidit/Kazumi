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
    required this.openMenu,
  });

  final void Function(BuildContext) onBackPressed;
  final Future<void> Function(double) setPlaybackSpeed;
  final void Function() showDanmakuSwitch;
  final Future<void> Function(int, {int currentRoad, int offset}) changeEpisode;
  final void Function() openMenu;
  final void Function() handleFullscreen;
  final void Function(ThumbDragDetails details) handleProgressBarDragStart;
  final void Function() handleProgressBarDragEnd;

  @override
  State<PlayerItemPanel> createState() => _PlayerItemPanelState();
}

class _PlayerItemPanelState extends State<PlayerItemPanel> {
  Box setting = GStorage.setting;
  late bool haEnable;
  final VideoPageController videoPageController =
      Modular.get<VideoPageController>();
  final InfoController infoController = Modular.get<InfoController>();
  final PlayerController playerController = Modular.get<PlayerController>();

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
  void showShootDanmakuSheet() {
    final TextEditingController textController = TextEditingController();
    bool isSending = false;
    KazumiDialog.show(builder: (context) {
      return AlertDialog(
        title: const Text('发送弹幕'),
        content: StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
          return TextField(
            controller: textController,
          );
        }),
        actions: [
          TextButton(
            onPressed: () => KazumiDialog.dismiss(),
            child: Text(
              '取消',
              style: TextStyle(color: Theme.of(context).colorScheme.outline),
            ),
          ),
          StatefulBuilder(
              builder: (BuildContext context, StateSetter setState) {
            return TextButton(
              onPressed: isSending
                  ? null
                  : () async {
                      final String msg = textController.text;
                      if (msg.isEmpty) {
                        KazumiDialog.showToast(message: '弹幕内容为空');
                        return;
                      } else if (msg.length > 100) {
                        KazumiDialog.showToast(message: '弹幕内容过长');
                        return;
                      }
                      setState(() {
                        isSending = true; // 开始发送，更新状态
                      });
                      // Todo 接口方限制

                      setState(() {
                        isSending = false; // 发送结束，更新状态
                      });
                      KazumiDialog.showToast(message: '发送成功');
                      playerController.danmakuController
                          .addDanmaku(DanmakuContentItem(msg, selfSend: true));
                      KazumiDialog.dismiss();
                    },
              child: Text(isSending ? '发送中' : '发送'),
            );
          })
        ],
      );
    });
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
                position: playerController.topOffsetAnimation,
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
                position: playerController.bottomOffsetAnimation,
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
                    position: playerController.leftOffsetAnimation,
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
                position: playerController.topOffsetAnimation,
                child: Row(
                  children: [
                    IconButton(
                      color: Colors.white,
                      icon: const Icon(Icons.arrow_back),
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
                    PopupMenuButton(
                      tooltip: '',
                      child: Text(
                          playerController.aspectRatioType == 1
                              ? 'AUTO'
                              : playerController.aspectRatioType == 2
                                  ? 'COVER'
                                  : 'FILL',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold)),
                      itemBuilder: (context) {
                        return const [
                          PopupMenuItem(
                            value: 1,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [Text("AUTO")],
                            ),
                          ),
                          PopupMenuItem(
                            value: 2,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [Text("COVER")],
                            ),
                          ),
                          PopupMenuItem(
                            value: 3,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [Text("FILL")],
                            ),
                          ),
                        ];
                      },
                      onSelected: (value) {
                        playerController.aspectRatioType = value;
                      },
                    ),
                    TextButton(
                      style: ButtonStyle(
                        padding: WidgetStateProperty.all(EdgeInsets.zero),
                      ),
                      onPressed: () {
                        // 倍速播放
                        showSetSpeedSheet();
                      },
                      child: Text(
                        '${playerController.playerSpeed}X',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                    forwardIcon(),
                    // 追番
                    CollectButton(bangumiItem: infoController.bangumiItem),
                    PopupMenuButton(
                      tooltip: '',
                      icon: const Icon(
                        Icons.more_vert,
                        color: Colors.white,
                      ),
                      itemBuilder: (context) {
                        return const [
                          PopupMenuItem(
                            value: 0,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [Text("弹幕设置")],
                            ),
                          ),
                          PopupMenuItem(
                            value: 1,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [Text("弹幕切换")],
                            ),
                          ),
                          PopupMenuItem(
                            value: 2,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [Text("视频详情")],
                            ),
                          ),
                          PopupMenuItem(
                            value: 3,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [Text("远程播放")],
                            ),
                          ),
                        ];
                      },
                      onSelected: (value) {
                        if (value == 0) {
                          KazumiDialog.show(builder: (context) {
                            return DanmakuSettingsWindow(
                                danmakuController:
                                    playerController.danmakuController);
                          });
                        }
                        if (value == 1) {
                          widget.showDanmakuSwitch();
                        }
                        if (value == 2) {
                          showVideoInfo();
                        }
                        if (value == 3) {
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
                        }
                      },
                    )
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
                position: playerController.bottomOffsetAnimation,
                child: Row(
                  children: [
                    IconButton(
                      color: Colors.white,
                      icon: Icon(playerController.playing
                          ? Icons.pause
                          : Icons.play_arrow),
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
                            icon: const Icon(Icons.skip_next),
                            onPressed: () {
                              if (videoPageController.loading) {
                                return;
                              }
                              if (videoPageController.currentEpisode ==
                                  videoPageController
                                      .roadList[videoPageController.currentRoad]
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
                                  currentRoad: videoPageController.currentRoad);
                            },
                          )
                        : Container(),
                    Expanded(
                      child: ProgressBar(
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
                    ((Utils.isCompact()) && !videoPageController.isFullscreen)
                        ? Container()
                        : Container(
                            padding: const EdgeInsets.only(left: 10.0),
                            child: Text(
                              "${Utils.durationToString(playerController.currentPosition)} / ${Utils.durationToString(playerController.duration)}",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: !Utils.isCompact() ? 16.0 : 12.0,
                              ),
                            ),
                          ),
                    // 弹幕相关
                    (playerController.danmakuOn)
                        ? IconButton(
                            color: Colors.white,
                            icon: const Icon(Icons.notes),
                            onPressed: () {
                              if (playerController.danDanmakus.isEmpty) {
                                KazumiDialog.showToast(
                                  message: '当前剧集不支持弹幕发送的说',
                                );
                                return;
                              }
                              showShootDanmakuSheet();
                            },
                          )
                        : Container(),
                    IconButton(
                      color: Colors.white,
                      icon: Icon(playerController.danmakuOn
                          ? Icons.subtitles
                          : Icons.subtitles_off),
                      onPressed: () {
                        _handleDanmaku();
                      },
                    ),
                    (!videoPageController.isFullscreen &&
                            !Utils.isTablet() &&
                            !Utils.isDesktop())
                        ? Container()
                        : IconButton(
                            color: Colors.white,
                            icon: Icon(videoPageController.showTabBody
                                ? Icons.menu_open
                                : Icons.menu_open_outlined),
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
                                ? Icons.fullscreen_exit
                                : Icons.fullscreen),
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
