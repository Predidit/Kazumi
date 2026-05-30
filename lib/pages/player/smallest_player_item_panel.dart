import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:kazumi/pages/player/player_adjustment_hud.dart';
import 'package:kazumi/pages/player/player_panel_hold.dart';
import 'package:kazumi/services/player/pip_utils.dart';
import 'package:kazumi/pages/video/video_controller.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/pages/player/player_controller.dart';
import 'package:flutter/services.dart';
import 'package:kazumi/services/player/remote.dart';
import 'package:kazumi/pages/settings/danmaku/danmaku_settings_sheet.dart';
import 'package:kazumi/utils/constants.dart';
import 'package:hive_ce/hive.dart';
import 'package:kazumi/services/storage/storage.dart';
import 'package:kazumi/bean/appbar/drag_to_move_bar.dart' as dtb;
import 'package:audio_video_progress_bar/audio_video_progress_bar.dart';
import 'package:kazumi/bean/widget/embedded_native_control_area.dart';
import 'package:kazumi/services/player/timed_shutdown_service.dart';
import 'package:kazumi/utils/device.dart';
import 'package:kazumi/utils/format.dart';

class SmallestPlayerItemPanel extends StatefulWidget {
  const SmallestPlayerItemPanel({
    super.key,
    required this.playerController,
    required this.onBackPressed,
    required this.setPlaybackSpeed,
    required this.showDanmakuSwitch,
    required this.handleFullscreen,
    required this.handleProgressBarDragStart,
    required this.handleProgressBarDragEnd,
    required this.handleSuperResolutionChange,
    required this.panelVisibilityController,
    required this.keyboardFocus,
    required this.acquirePlayerPanelHold,
    required this.handleDanmaku,
    required this.skipOP,
    required this.showVideoInfo,
    required this.showSyncPlayRoomCreateDialog,
    required this.showSyncPlayEndPointSwitchDialog,
    required this.pauseForTimedShutdown,
    this.disableAnimations = false,
  });

  final PlayerController playerController;
  final void Function(BuildContext) onBackPressed;
  final Future<void> Function(double) setPlaybackSpeed;
  final void Function() showDanmakuSwitch;
  final void Function() handleDanmaku;
  final void Function() skipOP;
  final void Function() handleFullscreen;
  final void Function(ThumbDragDetails details) handleProgressBarDragStart;
  final void Function() handleProgressBarDragEnd;
  final Future<void> Function(int shaderIndex) handleSuperResolutionChange;
  final AnimationController panelVisibilityController;
  final FocusNode keyboardFocus;
  final PlayerPanelHold Function() acquirePlayerPanelHold;
  final void Function() showVideoInfo;
  final void Function() showSyncPlayRoomCreateDialog;
  final void Function() showSyncPlayEndPointSwitchDialog;
  final VoidCallback pauseForTimedShutdown;
  final bool disableAnimations;

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
  late final PlayerController playerController;
  final TextEditingController textController = TextEditingController();

  // SVG Caches
  String? cachedSvgString;
  Widget? cachedDanmakuOnIcon;
  Widget? cachedDanmakuOffIcon;

  static const double _danmakuIconSize = 24.0;
  static const double _loadingIndicatorStrokeWidth = 2.0;

  @override
  void dispose() {
    textController.dispose();
    super.dispose();
  }

  void showForwardChange() {
    KazumiDialog.show(builder: (context) {
      String input = "";
      return AlertDialog(
        title: const Text('Skip seconds'),
        content: StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
          return TextField(
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly, // 只允许输入数字
            ],
            decoration: InputDecoration(
              floatingLabelBehavior:
                  FloatingLabelBehavior.never, // 控制label的显示方式
              labelText: playerController.playback.buttonSkipTime.toString(),
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
              'Cancel',
              style: TextStyle(color: Theme.of(context).colorScheme.outline),
            ),
          ),
          TextButton(
            onPressed: () async {
              if (input != "") {
                playerController.setButtonForwardTime(int.parse(input));
                KazumiDialog.dismiss();
              } else {
                KazumiDialog.dismiss();
              }
            },
            child: const Text('OK'),
          ),
        ],
      );
    });
  }

  @override
  void initState() {
    super.initState();
    playerController = widget.playerController;
    topOffsetAnimation = Tween<Offset>(
      begin: const Offset(0.0, -1.0),
      end: const Offset(0.0, 0.0),
    ).animate(CurvedAnimation(
      parent: widget.panelVisibilityController,
      curve: Curves.easeInOut,
    ));
    bottomOffsetAnimation = Tween<Offset>(
      begin: const Offset(0.0, 1.0),
      end: const Offset(0.0, 0.0),
    ).animate(CurvedAnimation(
      parent: widget.panelVisibilityController,
      curve: Curves.easeInOut,
    ));
    leftOffsetAnimation = Tween<Offset>(
      begin: const Offset(1.0, 0.0),
      end: const Offset(0.0, 0.0),
    ).animate(CurvedAnimation(
      parent: widget.panelVisibilityController,
      curve: Curves.easeInOut,
    ));
    haEnable = setting.get(SettingBoxKey.hAenable, defaultValue: true);
    cacheSvgIcons();
  }

  void cacheSvgIcons() {
    cachedDanmakuOffIcon = RepaintBoundary(
      child: SvgPicture.asset(
        'assets/images/danmaku_off.svg',
        height: _danmakuIconSize,
      ),
    );
  }

  Widget danmakuOnIcon(BuildContext context) {
    final colorHex = Theme.of(context)
        .colorScheme
        .primary
        .toARGB32()
        .toRadixString(16)
        .substring(2);

    if (cachedSvgString != colorHex) {
      cachedSvgString = colorHex;
      final svgString = danmakuOnSvg.replaceFirst('00AEEC', colorHex);
      cachedDanmakuOnIcon = RepaintBoundary(
        child: SvgPicture.string(
          svgString,
          height: _danmakuIconSize,
        ),
      );
    }

    return cachedDanmakuOnIcon!;
  }

  Widget _buildDanmakuToggleButton(BuildContext context) {
    return IconButton(
      color: Colors.white,
      icon: playerController.danmaku.danmakuLoading
          ? SizedBox(
              width: _danmakuIconSize,
              height: _danmakuIconSize,
              child: CircularProgressIndicator(
                strokeWidth: _loadingIndicatorStrokeWidth,
              ),
            )
          : (playerController.danmaku.danmakuOn
              ? danmakuOnIcon(context)
              : cachedDanmakuOffIcon!),
      onPressed: playerController.danmaku.danmakuLoading
          ? null
          : () {
              widget.handleDanmaku();
            },
      tooltip: playerController.danmaku.danmakuLoading
          ? 'Loading danmaku...'
          : (playerController.danmaku.danmakuOn ? 'Turn off danmaku' : 'Turn on danmaku'),
    );
  }

  Widget forwardIcon() {
    return Tooltip(
      message: 'Skip forward ${playerController.playback.buttonSkipTime}s, long press to change',
      child: GestureDetector(
        onLongPress: () => showForwardChange(),
        child: IconButton(
          icon: Image.asset(
            'assets/images/forward_80.png',
            color: Colors.white,
            height: 24,
          ),
          onPressed: () {
            widget.skipOP();
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        AnimatedPositioned(
          duration: const Duration(seconds: 1),
          top: 0,
          left: 0,
          right: 0,
          child: Observer(builder: (context) {
            return Visibility(
              visible: !playerController.panel.lockPanel &&
                  (widget.disableAnimations
                      ? playerController.panel.showVideoController
                      : true),
              child: widget.disableAnimations
                  ? Container(
                      height: 50,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black45,
                            Colors.transparent,
                          ],
                        ),
                      ),
                    )
                  : SlideTransition(
                      position: topOffsetAnimation,
                      child: Container(
                        height: 50,
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black45,
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
            );
          }),
        ),
        AnimatedPositioned(
          duration: const Duration(seconds: 1),
          bottom: 0,
          left: 0,
          right: 0,
          child: Observer(builder: (context) {
            return Visibility(
              visible: !playerController.panel.lockPanel &&
                  (widget.disableAnimations
                      ? playerController.panel.showVideoController
                      : true),
              child: widget.disableAnimations
                  ? Container(
                      height: 100,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black45,
                          ],
                        ),
                      ),
                    )
                  : SlideTransition(
                      position: bottomOffsetAnimation,
                      child: Container(
                        height: 100,
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black45,
                            ],
                          ),
                        ),
                      ),
                    ),
            );
          }),
        ),
        Positioned(
          top: 25,
          child: Observer(builder: (context) {
            return PlayerSeekHud(
              visible: playerController.panel.showSeekTime,
              currentPosition: playerController.playback.currentPosition,
              playerPosition: playerController.playback.playerPosition,
              duration: playerController.playback.duration,
              direction: playerController.panel.seekDirection,
              disableAnimations: widget.disableAnimations,
            );
          }),
        ),
        Positioned(
          top: 25,
          child: Observer(builder: (context) {
            return PlayerSpeedHud(
              visible: playerController.panel.showPlaySpeed,
              speed: playerController.playback.playerSpeed,
              disableAnimations: widget.disableAnimations,
            );
          }),
        ),
        Positioned(
          top: 25,
          child: Observer(builder: (context) {
            final showVolume = playerController.panel.showVolume;
            final showBrightness = playerController.panel.showBrightness;
            return PlayerAdjustmentHud(
              visible: showVolume || showBrightness,
              type: showVolume
                  ? PlayerAdjustmentHudType.volume
                  : PlayerAdjustmentHudType.brightness,
              value: showVolume
                  ? playerController.playback.volume
                  : playerController.panel.brightness,
              disableAnimations: widget.disableAnimations,
            );
          }),
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Observer(builder: (context) {
            return Visibility(
              visible: !playerController.panel.lockPanel &&
                  (widget.disableAnimations
                      ? playerController.panel.showVideoController
                      : true),
              child: widget.disableAnimations
                  ? topControlWidget
                  : SlideTransition(
                      position: topOffsetAnimation, child: topControlWidget),
            );
          }),
        ),
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Observer(builder: (context) {
            return Visibility(
              visible: !playerController.panel.lockPanel &&
                  (widget.disableAnimations
                      ? playerController.panel.showVideoController
                      : true),
              child: widget.disableAnimations
                  ? bottomControlWidget
                  : SlideTransition(
                      position: bottomOffsetAnimation,
                      child: bottomControlWidget),
            );
          }),
        ),
      ],
    );
  }

  Widget get bottomControlWidget {
    return Observer(builder: (context) {
      return Row(
        children: [
          IconButton(
            color: Colors.white,
            icon: Icon(playerController.playback.playing
                ? Icons.pause_rounded
                : Icons.play_arrow_rounded),
            tooltip: playerController.playback.playing ? 'Pause' : 'Play',
            onPressed: () {
              playerController.playOrPause();
            },
          ),
          Expanded(
            child: ProgressBar(
              thumbRadius: 8,
              thumbGlowRadius: 18,
              timeLabelLocation: TimeLabelLocation.none,
              progress: playerController.playback.currentPosition,
              buffered: playerController.playback.buffer,
              total: playerController.playback.duration,
              onSeek: (duration) {
                playerController.seek(duration);
              },
              onDragStart: (details) {
                widget.handleProgressBarDragStart(details);
              },
              onDragUpdate: (details) => {
                playerController.playback.currentPosition = details.timeStamp
              },
              onDragEnd: () {
                widget.handleProgressBarDragEnd();
              },
            ),
          ),
          Text(
            "    ${durationToString(playerController.playback.currentPosition)} / ${durationToString(playerController.playback.duration)}",
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12.0,
              fontFeatures: [
                FontFeature.tabularFigures(),
              ],
            ),
          ),
          (!videoPageController.isPip)
              ? IconButton(
                  color: Colors.white,
                  icon: Icon(videoPageController.isFullscreen
                      ? Icons.fullscreen_exit_rounded
                      : Icons.fullscreen_rounded),
                  tooltip: videoPageController.isFullscreen ? 'Exit fullscreen' : 'Fullscreen',
                  onPressed: () {
                    widget.handleFullscreen();
                  },
                )
              : const Text('    '),
        ],
      );
    });
  }

  Widget get topControlWidget {
    return Observer(builder: (context) {
      return EmbeddedNativeControlArea(
        child: Row(
          children: [
            IconButton(
              color: Colors.white,
              icon: const Icon(Icons.arrow_back_rounded),
              tooltip: 'Back',
              onPressed: () {
                widget.onBackPressed(context);
              },
            ),
            // 拖动条
            const Expanded(
              child: dtb.DragToMoveArea(child: SizedBox(height: 40)),
            ),
            // 跳过
            forwardIcon(),
            if (isDesktop() || Platform.isAndroid)
              IconButton(
                  onPressed: () async {
                    if (isDesktop()) {
                      if (videoPageController.isPip) {
                        await PipUtils.exitDesktopPIPWindow();
                      } else {
                        // 进入画中画时使用播放源比例，避免窗口比例与视频比例不一致产生黑边
                        await PipUtils.enterDesktopPIPWindow(
                          width: playerController.debug.playerWidth,
                          height: playerController.debug.playerHeight,
                        );
                      }
                      videoPageController.isPip = !videoPageController.isPip;
                      return;
                    }
                    final bool supported =
                        await PipUtils.isAndroidPIPSupported();
                    if (!supported) {
                      KazumiDialog.showToast(message: 'This device does not support picture-in-picture');
                      return;
                    }
                    await PipUtils.updateAndroidPIPActions(
                      playing: playerController.playback.playing,
                      danmakuEnabled: playerController.danmaku.danmakuOn,
                      width: playerController.debug.playerWidth,
                      height: playerController.debug.playerHeight,
                    );
                    final bool entered = await PipUtils.enterAndroidPIPWindow(
                      width: playerController.debug.playerWidth,
                      height: playerController.debug.playerHeight,
                    );
                    if (!entered) {
                      KazumiDialog.showToast(message: 'Failed to enter picture-in-picture');
                    }
                  },
                  tooltip: 'Picture-in-picture',
                  icon: const Icon(Icons.picture_in_picture,
                      color: Colors.white)),
            // 弹幕开关
            _buildDanmakuToggleButton(context),
            // 追番
            PlayerPanelHoldCollectButton(
              acquirePlayerPanelHold: widget.acquirePlayerPanelHold,
              bangumiItem: videoPageController.bangumiItem,
            ),
            PlayerPanelHoldMenuAnchor(
              acquirePlayerPanelHold: widget.acquirePlayerPanelHold,
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
                  tooltip: 'More options',
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
                          playerController.panel.aspectRatioType = index + 1,
                      child: Container(
                        height: 48,
                        constraints: BoxConstraints(minWidth: 112),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            index + 1 == 1
                                ? 'Auto'
                                : index + 1 == 2
                                    ? 'Crop to fill'
                                    : 'Stretch to fill',
                            style: TextStyle(
                                color: index + 1 ==
                                        playerController.panel.aspectRatioType
                                    ? Theme.of(context).colorScheme.primary
                                    : null),
                          ),
                        ),
                      ),
                    ),
                  ),
                  child: Container(
                    height: 48,
                    constraints: BoxConstraints(minWidth: 112),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text("Aspect ratio"),
                    ),
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
                        child: Container(
                          height: 48,
                          constraints: BoxConstraints(minWidth: 112),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              '${i}x',
                              style: TextStyle(
                                  color: i ==
                                          playerController.playback.playerSpeed
                                      ? Theme.of(context).colorScheme.primary
                                      : null),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                  child: Container(
                    height: 48,
                    constraints: BoxConstraints(minWidth: 112),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text("Speed"),
                    ),
                  ),
                ),
                SubmenuButton(
                  menuChildren: List<MenuItemButton>.generate(
                    3,
                    (int index) => MenuItemButton(
                      onPressed: () =>
                          widget.handleSuperResolutionChange(index + 1),
                      child: Container(
                        height: 48,
                        constraints: BoxConstraints(minWidth: 112),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            index + 1 == 1
                                ? 'Close'
                                : index + 1 == 2
                                    ? 'Performance mode'
                                    : 'Quality mode',
                            style: TextStyle(
                              color: playerController
                                          .playback.superResolutionType ==
                                      index + 1
                                  ? Theme.of(context).colorScheme.primary
                                  : null,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  child: Container(
                    height: 48,
                    constraints: BoxConstraints(minWidth: 112),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text("Super resolution"),
                    ),
                  ),
                ),
                SubmenuButton(
                  menuChildren: [
                    MenuItemButton(
                      child: Container(
                        height: 48,
                        constraints: BoxConstraints(minWidth: 112),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                              "Current room: ${playerController.syncplay.syncplayRoom == '' ? 'Not joined' : playerController.syncplay.syncplayRoom}"),
                        ),
                      ),
                    ),
                    MenuItemButton(
                      child: Container(
                        height: 48,
                        constraints: BoxConstraints(minWidth: 112),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                              "Network latency: ${playerController.syncplay.syncplayClientRtt}ms"),
                        ),
                      ),
                    ),
                    MenuItemButton(
                      onPressed: () {
                        widget.showSyncPlayRoomCreateDialog();
                      },
                      child: Container(
                        height: 48,
                        constraints: BoxConstraints(minWidth: 112),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text("Join room"),
                        ),
                      ),
                    ),
                    MenuItemButton(
                      onPressed: () {
                        widget.showSyncPlayEndPointSwitchDialog();
                      },
                      child: Container(
                        height: 48,
                        constraints: BoxConstraints(minWidth: 112),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text("Switch server"),
                        ),
                      ),
                    ),
                    MenuItemButton(
                      onPressed: () async {
                        await playerController.exitSyncPlayRoom();
                      },
                      child: Container(
                        height: 48,
                        constraints: BoxConstraints(minWidth: 112),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text("Disconnect"),
                        ),
                      ),
                    ),
                  ],
                  child: Container(
                    height: 48,
                    constraints: BoxConstraints(minWidth: 112),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text("Watch together"),
                    ),
                  ),
                ),
                MenuItemButton(
                  onPressed: () {
                    widget.showDanmakuSwitch();
                  },
                  child: Container(
                    height: 48,
                    constraints: BoxConstraints(minWidth: 112),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text("Switch danmaku"),
                    ),
                  ),
                ),
                MenuItemButton(
                  onPressed: () {
                    showModalBottomSheet(
                      isScrollControlled: true,
                      constraints: BoxConstraints(
                          maxHeight: MediaQuery.of(context).size.height * 3 / 4,
                          maxWidth: (isDesktop() || isTablet())
                              ? MediaQuery.of(context).size.width * 9 / 16
                              : MediaQuery.of(context).size.width),
                      clipBehavior: Clip.antiAlias,
                      context: context,
                      builder: (context) {
                        return DanmakuSettingsSheet(
                          danmakuController:
                              playerController.danmaku.canvasController,
                          onUpdateDanmakuSpeed:
                              playerController.updateDanmakuSpeed,
                          onTimelineOffsetChanged: playerController
                              .danmaku.clearAndInvalidateScheduledDanmakus,
                        );
                      },
                    );
                  },
                  child: Container(
                    height: 48,
                    constraints: BoxConstraints(minWidth: 112),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text("Danmaku settings"),
                    ),
                  ),
                ),
                MenuItemButton(
                  onPressed: () {
                    widget.showVideoInfo();
                  },
                  child: Container(
                    height: 48,
                    constraints: BoxConstraints(minWidth: 112),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text("Video details"),
                    ),
                  ),
                ),
                MenuItemButton(
                  onPressed: () {
                    bool needRestart = playerController.playback.playing;
                    playerController.pause();
                    RemotePlay()
                        .castVideo(playerController.videoUrl,
                            videoPageController.currentPlugin.referer)
                        .whenComplete(() {
                      if (mounted && needRestart) {
                        playerController.play();
                      }
                    });
                  },
                  child: Container(
                    height: 48,
                    constraints: BoxConstraints(minWidth: 112),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text("Remote casting"),
                    ),
                  ),
                ),
                MenuItemButton(
                  onPressed: () {
                    playerController.launchExternalPlayer();
                  },
                  child: Container(
                    height: 48,
                    constraints: BoxConstraints(minWidth: 112),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text("External player"),
                    ),
                  ),
                ),
                // 定时关闭
                SubmenuButton(
                  menuChildren: [
                    MenuItemButton(
                      onPressed: () {
                        TimedShutdownService().cancel();
                      },
                      child: Container(
                        height: 48,
                        constraints: BoxConstraints(minWidth: 112),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            "Off",
                            style: TextStyle(
                              color: !TimedShutdownService().isActive
                                  ? Theme.of(context).colorScheme.primary
                                  : null,
                            ),
                          ),
                        ),
                      ),
                    ),
                    for (final int minutes in [15, 30, 60])
                      MenuItemButton(
                        onPressed: () {
                          TimedShutdownService().start(minutes,
                              onExpired: widget.pauseForTimedShutdown);
                          KazumiDialog.showToast(
                              message:
                                  'Sleep timer set for ${TimedShutdownService().formatMinutesToDisplay(minutes)}');
                        },
                        child: Container(
                          height: 48,
                          constraints: BoxConstraints(minWidth: 112),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              "$minutes min",
                              style: TextStyle(
                                color:
                                    TimedShutdownService().setMinutes == minutes
                                        ? Theme.of(context).colorScheme.primary
                                        : null,
                              ),
                            ),
                          ),
                        ),
                      ),
                    MenuItemButton(
                      onPressed: () {
                        TimedShutdownService.showCustomTimerDialog(
                          onExpired: widget.pauseForTimedShutdown,
                        );
                      },
                      child: Container(
                        height: 48,
                        constraints: BoxConstraints(minWidth: 112),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text("Custom"),
                        ),
                      ),
                    ),
                  ],
                  child: Container(
                    height: 48,
                    constraints: BoxConstraints(minWidth: 112),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: ValueListenableBuilder<int>(
                        valueListenable:
                            TimedShutdownService().remainingSecondsNotifier,
                        builder: (context, remainingSeconds, child) {
                          return Text(
                            remainingSeconds > 0
                                ? "Sleep timer (${TimedShutdownService().formatRemainingTime()})"
                                : "Sleep timer",
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    });
  }
}
