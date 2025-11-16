import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:kazumi/bean/widget/embedded_native_control_area.dart';
import 'package:kazumi/utils/utils.dart';
import 'package:kazumi/pages/video/video_controller.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/pages/player/player_controller.dart';
import 'package:saver_gallery/saver_gallery.dart';
import 'package:flutter/services.dart';
import 'package:kazumi/utils/remote.dart';
import 'package:kazumi/bean/appbar/drag_to_move_bar.dart' as dtb;
import 'package:kazumi/pages/settings/danmaku/danmaku_settings_sheet.dart';
import 'package:kazumi/bean/widget/collect_button.dart';
import 'package:kazumi/utils/constants.dart';
import 'package:hive/hive.dart';
import 'package:kazumi/utils/storage.dart';
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
    required this.handleSuperResolutionChange,
    required this.animationController,
    required this.openMenu,
    required this.keyboardFocus,
    required this.sendDanmaku,
    required this.startHideTimer,
    required this.cancelHideTimer,
    required this.handleDanmaku,
    required this.showVideoInfo,
    required this.showSyncPlayRoomCreateDialog,
    required this.showSyncPlayEndPointSwitchDialog,
    this.disableAnimations = false,
  });

  final void Function(BuildContext) onBackPressed;
  final Future<void> Function(double) setPlaybackSpeed;
  final void Function() showDanmakuSwitch;
  final Future<void> Function(int, {int currentRoad, int offset}) changeEpisode;
  final void Function() openMenu;
  final void Function() handleFullscreen;
  final void Function(ThumbDragDetails details) handleProgressBarDragStart;
  final void Function() handleProgressBarDragEnd;
  final Future<void> Function(int shaderIndex) handleSuperResolutionChange;
  final AnimationController animationController;
  final FocusNode keyboardFocus;
  final void Function() startHideTimer;
  final void Function() cancelHideTimer;
  final void Function() handleDanmaku;
  final void Function(String) sendDanmaku;
  final void Function() showVideoInfo;
  final void Function() showSyncPlayRoomCreateDialog;
  final void Function() showSyncPlayEndPointSwitchDialog;
  final bool disableAnimations;

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
  final PlayerController playerController = Modular.get<PlayerController>();
  final TextEditingController textController = TextEditingController();
  final FocusNode textFieldFocus = FocusNode();

  Future<void> _handleScreenshot() async {
    KazumiDialog.showToast(message: '截图中...');
    try {
      Uint8List? screenshot =
          await playerController.screenshot(format: 'image/png');
      final result = await SaverGallery.saveImage(
        screenshot!,
        fileName: DateTime.timestamp().millisecondsSinceEpoch.toString(),
        skipIfExists: false,
      );
      if (result.isSuccess) {
        KazumiDialog.showToast(message: '截图保存到相簿成功');
      } else {
        KazumiDialog.showToast(message: '截图保存失败：${result.errorMessage}');
      }
    } catch (e) {
      KazumiDialog.showToast(message: '截图失败：$e');
    }
  }

  Widget get danmakuTextField {
    return Container(
      constraints: Utils.isDesktop()
          ? const BoxConstraints(maxWidth: 500, maxHeight: 33)
          : const BoxConstraints(maxHeight: 33),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: TextField(
        focusNode: textFieldFocus,
        style: TextStyle(
            fontSize: Utils.isDesktop() ? 15 : 13, color: Colors.white),
        controller: textController,
        textAlignVertical: TextAlignVertical.center,
        decoration: InputDecoration(
          enabled: playerController.danmakuOn,
          filled: true,
          fillColor: Colors.white38,
          floatingLabelBehavior: FloatingLabelBehavior.never,
          hintText: playerController.danmakuOn ? '发个友善的弹幕见证当下' : '已关闭弹幕',
          hintStyle: TextStyle(
              fontSize: Utils.isDesktop() ? 15 : 13, color: Colors.white60),
          alignLabelWithHint: true,
          contentPadding: EdgeInsets.symmetric(
              vertical: 8, horizontal: Utils.isDesktop() ? 8 : 12),
          border: OutlineInputBorder(
            borderSide: BorderSide.none,
            borderRadius:
                BorderRadius.all(Radius.circular(Utils.isDesktop() ? 8 : 20)),
          ),
          suffixIcon: TextButton(
            onPressed: () {
              textFieldFocus.unfocus();
              widget.sendDanmaku(textController.text);
              textController.clear();
            },
            style: TextButton.styleFrom(
              foregroundColor: playerController.danmakuOn
                  ? Theme.of(context).colorScheme.onPrimaryContainer
                  : Colors.white60,
              backgroundColor: playerController.danmakuOn
                  ? Theme.of(context).colorScheme.primaryContainer
                  : Theme.of(context).disabledColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(Utils.isDesktop() ? 8 : 20),
              ),
            ),
            child: const Text('发送'),
          ),
        ),
        onTapAlwaysCalled: true,
        onTap: () {
          widget.cancelHideTimer();
          playerController.canHidePlayerPanel = false;
        },
        onSubmitted: (msg) {
          textFieldFocus.unfocus();
          widget.sendDanmaku(msg);
          widget.cancelHideTimer();
          widget.startHideTimer();
          playerController.canHidePlayerPanel = true;
          textController.clear();
        },
        onTapOutside: (_) {
          widget.cancelHideTimer();
          widget.startHideTimer();
          playerController.canHidePlayerPanel = true;
          textFieldFocus.unfocus();
          widget.keyboardFocus.requestFocus();
        },
      ),
    );
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
              labelText: playerController.buttonSkipTime.toString(),
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
                playerController.setButtonForwardTime(int.parse(input));
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
                Duration(seconds: playerController.buttonSkipTime));
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
              visible: !playerController.lockPanel &&
                  (widget.disableAnimations
                      ? playerController.showVideoController
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
            ),
          ),

          //底部渐变区域
          AnimatedPositioned(
            duration: const Duration(seconds: 1),
            bottom: 0,
            left: 0,
            right: 0,
            child: Visibility(
              visible: !playerController.lockPanel &&
                  (widget.disableAnimations
                      ? playerController.showVideoController
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
          // 右侧锁定按钮
          (Utils.isDesktop() || !videoPageController.isFullscreen)
              ? Container()
              : Positioned(
                  right: 0,
                  top: 0,
                  bottom: 0,
                  child: Visibility(
                    visible: widget.disableAnimations
                        ? playerController.showVideoController
                        : true,
                    child: widget.disableAnimations
                        ? leftControlWidget
                        : SlideTransition(
                            position: leftOffsetAnimation,
                            child: leftControlWidget),
                  ),
                ),
          // 自定义顶部组件
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Visibility(
              visible: !playerController.lockPanel &&
                  (widget.disableAnimations
                      ? playerController.showVideoController
                      : true),
              child: widget.disableAnimations
                  ? topControlWidget
                  : SlideTransition(
                      position: topOffsetAnimation, child: topControlWidget),
            ),
          ),
          // 自定义播放器底部组件
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Visibility(
              visible: !playerController.lockPanel &&
                  (widget.disableAnimations
                      ? playerController.showVideoController
                      : true),
              child: widget.disableAnimations
                  ? bottomControlWidget
                  : SlideTransition(
                      position: bottomOffsetAnimation,
                      child: bottomControlWidget),
            ),
          ),
        ],
      );
    });
  }

  Widget get bottomControlWidget {
    final svgString = danmakuOnSvg.replaceFirst(
        '00AEEC',
        Theme.of(context)
            .colorScheme
            .primary
            .toARGB32()
            .toRadixString(16)
            .substring(2));
    return Observer(
      builder: (context) {
        return SafeArea(
          top: false,
          bottom: videoPageController.isFullscreen,
          left: videoPageController.isFullscreen,
          right: videoPageController.isFullscreen,
          child: MouseRegion(
            cursor: (videoPageController.isFullscreen &&
                    !playerController.showVideoController)
                ? SystemMouseCursors.none
                : SystemMouseCursors.basic,
            onEnter: (_) {
              widget.cancelHideTimer();
            },
            onExit: (_) {
              widget.cancelHideTimer();
              widget.startHideTimer();
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!Utils.isDesktop() && !Utils.isTablet())
                  Container(
                    padding: const EdgeInsets.only(left: 10.0, bottom: 10),
                    child: Text(
                      "${Utils.durationToString(playerController.currentPosition)} / ${Utils.durationToString(playerController.duration)}",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12.0,
                        fontFeatures: [
                          FontFeature.tabularFigures(),
                        ],
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: ProgressBar(
                    thumbRadius: 8,
                    thumbGlowRadius: 18,
                    timeLabelLocation: Utils.isTablet()
                        ? TimeLabelLocation.sides
                        : TimeLabelLocation.none,
                    timeLabelTextStyle: const TextStyle(
                      color: Colors.white,
                      fontSize: 12.0,
                      fontFeatures: [
                        FontFeature.tabularFigures(),
                      ],
                    ),
                    progress: playerController.currentPosition,
                    buffered: playerController.buffer,
                    total: playerController.duration,
                    onSeek: (duration) {
                      playerController.seek(duration);
                    },
                    onDragStart: (details) {
                      widget.handleProgressBarDragStart(details);
                    },
                    onDragUpdate: (details) =>
                        {playerController.currentPosition = details.timeStamp},
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
                      if (videoPageController.isFullscreen ||
                          Utils.isTablet() ||
                          Utils.isDesktop())
                        IconButton(
                          color: Colors.white,
                          icon: const Icon(Icons.skip_next_rounded),
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
                        ),
                      if (Utils.isDesktop())
                        Container(
                          padding: const EdgeInsets.only(left: 10.0),
                          child: Text(
                            "${Utils.durationToString(playerController.currentPosition)} / ${Utils.durationToString(playerController.duration)}",
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16.0,
                              fontFeatures: [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                        ),
                      if (Utils.isDesktop())
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
                                      icon: playerController.danmakuOn
                                          ? SvgPicture.string(
                                              svgString,
                                              height: 24,
                                            )
                                          : SvgPicture.asset(
                                              'assets/images/danmaku_off.svg',
                                              height: 24,
                                            ),
                                      onPressed: () {
                                        widget.handleDanmaku();
                                      },
                                      tooltip: playerController.danmakuOn
                                          ? '关闭弹幕(d)'
                                          : '打开弹幕(d)',
                                    ),
                                    IconButton(
                                      onPressed: () {
                                        widget.keyboardFocus.requestFocus();
                                        showModalBottomSheet(
                                            isScrollControlled: true,
                                            constraints: BoxConstraints(
                                                maxHeight: MediaQuery.of(context)
                                                        .size
                                                        .height *
                                                    3 /
                                                    4,
                                                maxWidth: (Utils.isDesktop() ||
                                                        Utils.isTablet())
                                                    ? MediaQuery.of(context)
                                                            .size
                                                            .width *
                                                        9 /
                                                        16
                                                    : MediaQuery.of(context)
                                                        .size
                                                        .width),
                                            clipBehavior: Clip.antiAlias,
                                            context: context,
                                            builder: (context) {
                                              return DanmakuSettingsSheet(
                                                danmakuController:
                                                    playerController
                                                        .danmakuController,
                                                onUpdateDanmakuSpeed:
                                                    playerController.updateDanmakuSpeed,
                                              );
                                            });
                                      },
                                      color: Colors.white,
                                      icon: SvgPicture.asset(
                                        'assets/images/danmaku_setting.svg',
                                        height: 24,
                                      ),
                                    ),
                                    if (isSpaceEnough) danmakuTextField,
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      if (!Utils.isDesktop()) ...[
                        IconButton(
                          color: Colors.white,
                          icon: playerController.danmakuOn
                              ? SvgPicture.string(
                                  svgString,
                                  height: 24,
                                )
                              : SvgPicture.asset(
                                  'assets/images/danmaku_off.svg',
                                  height: 24,
                                ),
                          onPressed: () {
                            widget.handleDanmaku();
                          },
                          tooltip:
                              playerController.danmakuOn ? '关闭弹幕(d)' : '打开弹幕(d)',
                        ),
                        if (playerController.danmakuOn) ...[
                          IconButton(
                            onPressed: () {
                              showModalBottomSheet(
                                  isScrollControlled: true,
                                  constraints: BoxConstraints(
                                      maxHeight:
                                          MediaQuery.of(context).size.height *
                                              3 /
                                              4,
                                      maxWidth:
                                          (Utils.isDesktop() || Utils.isTablet())
                                              ? MediaQuery.of(context).size.width *
                                                  9 /
                                                  16
                                              : MediaQuery.of(context).size.width),
                                  clipBehavior: Clip.antiAlias,
                                  context: context,
                                  builder: (context) {
                                    return DanmakuSettingsSheet(
                                      danmakuController:
                                          playerController.danmakuController,
                                      onUpdateDanmakuSpeed:
                                          playerController.updateDanmakuSpeed,
                                    );
                                  });
                            },
                            color: Colors.white,
                            icon: SvgPicture.asset(
                              'assets/images/danmaku_setting.svg',
                              height: 24,
                            ),
                          ),
                          Expanded(child: danmakuTextField),
                        ],
                        if (!playerController.danmakuOn) const Spacer(),
                      ],
                      // 超分辨率
                      MenuAnchor(
                        consumeOutsideTap: true,
                        onOpen: () {
                          widget.cancelHideTimer();
                          playerController.canHidePlayerPanel = false;
                        },
                        onClose: () {
                          widget.cancelHideTimer();
                          widget.startHideTimer();
                          playerController.canHidePlayerPanel = true;
                        },
                        builder: (BuildContext context, MenuController controller,
                            Widget? child) {
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
                                widget.handleSuperResolutionChange(index + 1),
                            child: Container(
                              height: 48,
                              constraints: BoxConstraints(minWidth: 112),
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  index + 1 == 1
                                      ? '关闭'
                                      : index + 1 == 2
                                          ? '效率档'
                                          : '质量档',
                                  style: TextStyle(
                                    color: playerController.superResolutionType ==
                                            index + 1
                                        ? Theme.of(context).colorScheme.primary
                                        : null,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      // 倍速播放
                      MenuAnchor(
                        consumeOutsideTap: true,
                        onOpen: () {
                          widget.cancelHideTimer();
                          playerController.canHidePlayerPanel = false;
                        },
                        onClose: () {
                          widget.cancelHideTimer();
                          widget.startHideTimer();
                          playerController.canHidePlayerPanel = true;
                        },
                        builder: (BuildContext context, MenuController controller,
                            Widget? child) {
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
                              child: Container(
                                height: 48,
                                constraints: BoxConstraints(minWidth: 112),
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    '${i}x',
                                    style: TextStyle(
                                      color: i == playerController.playerSpeed
                                          ? Theme.of(context).colorScheme.primary
                                          : null,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      MenuAnchor(
                        consumeOutsideTap: true,
                        onOpen: () {
                          widget.cancelHideTimer();
                          playerController.canHidePlayerPanel = false;
                        },
                        onClose: () {
                          widget.cancelHideTimer();
                          widget.startHideTimer();
                          playerController.canHidePlayerPanel = true;
                        },
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
                              Icons.aspect_ratio_rounded,
                              color: Colors.white,
                            ),
                            tooltip: '视频比例',
                          );
                        },
                        menuChildren: [
                          for (final entry in aspectRatioTypeMap.entries)
                            MenuItemButton(
                              onPressed: () =>
                                  playerController.aspectRatioType = entry.key,
                              child: Container(
                                height: 48,
                                constraints: BoxConstraints(minWidth: 112),
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    entry.value,
                                    style: TextStyle(
                                      color: entry.key ==
                                              playerController.aspectRatioType
                                          ? Theme.of(context).colorScheme.primary
                                          : null,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
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
                if (Utils.isTablet() || Utils.isDesktop())
                  const SizedBox(height: 6),
              ],
            ),
          ),
        );
      }
    );
  }

  Widget get topControlWidget {
    return Observer(
      builder: (context) {
        return EmbeddedNativeControlArea(
          requireOffset: !videoPageController.isFullscreen,
          child: SafeArea(
            top: false,
            bottom: false,
            left: videoPageController.isFullscreen,
            right: videoPageController.isFullscreen,
            child: MouseRegion(
              cursor: (videoPageController.isFullscreen &&
                      !playerController.showVideoController)
                  ? SystemMouseCursors.none
                  : SystemMouseCursors.basic,
              onEnter: (_) {
                widget.cancelHideTimer();
              },
              onExit: (_) {
                widget.cancelHideTimer();
                widget.startHideTimer();
              },
              child: Row(
                children: [
                  IconButton(
                    color: Colors.white,
                    icon: const Icon(Icons.arrow_back_rounded),
                    onPressed: () {
                      widget.onBackPressed(context);
                    },
                  ),
                  // 拖动条
                  Expanded(
                    child: dtb.DragToMoveArea(
                      child: Text(
                        ' ${videoPageController.title} [${videoPageController.roadList[videoPageController.currentRoad].identifier[videoPageController.currentEpisode - 1]}]',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize:
                              Theme.of(context).textTheme.titleMedium!.fontSize,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ),
                  // 跳过
                  forwardIcon(),
                  if (Utils.isDesktop() && !videoPageController.isFullscreen)
                    IconButton(
                      onPressed: () {
                        if (videoPageController.isPip) {
                          Utils.exitDesktopPIPWindow();
                        } else {
                          Utils.enterDesktopPIPWindow();
                        }
                        videoPageController.isPip = !videoPageController.isPip;
                      },
                      icon: const Icon(
                        Icons.picture_in_picture,
                        color: Colors.white,
                      ),
                    ),
                  // 追番
                  CollectButton(
                    bangumiItem: videoPageController.bangumiItem,
                    onOpen: () {
                      widget.cancelHideTimer();
                      playerController.canHidePlayerPanel = false;
                    },
                    onClose: () {
                      widget.cancelHideTimer();
                      widget.startHideTimer();
                      playerController.canHidePlayerPanel = true;
                    },
                  ),
                  MenuAnchor(
                    consumeOutsideTap: true,
                    onOpen: () {
                      widget.cancelHideTimer();
                      playerController.canHidePlayerPanel = false;
                    },
                    onClose: () {
                      widget.cancelHideTimer();
                      widget.startHideTimer();
                      playerController.canHidePlayerPanel = true;
                    },
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
                      MenuItemButton(
                        onPressed: () {
                          widget.showDanmakuSwitch();
                        },
                        child: Container(
                          height: 48,
                          constraints: BoxConstraints(minWidth: 112),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text("弹幕切换"),
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
                            child: Text("视频详情"),
                          ),
                        ),
                      ),
                      MenuItemButton(
                        onPressed: () {
                          bool needRestart = playerController.playing;
                          playerController.pause();
                          RemotePlay()
                              .castVideo(playerController.videoUrl,
                                  videoPageController.currentPlugin.referer)
                              .whenComplete(() {
                            if (needRestart) {
                              playerController.play();
                            }
                          });
                        },
                        child: Container(
                          height: 48,
                          constraints: BoxConstraints(minWidth: 112),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text("远程投屏"),
                          ),
                        ),
                      ),
                      MenuItemButton(
                        onPressed: () {
                          playerController.lanunchExternalPlayer();
                        },
                        child: Container(
                          height: 48,
                          constraints: BoxConstraints(minWidth: 112),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text("外部播放"),
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
                                    "当前房间: ${playerController.syncplayRoom == '' ? '未加入' : playerController.syncplayRoom}"),
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
                                    "网络延时: ${playerController.syncplayClientRtt}ms"),
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
                                child: Text("加入房间"),
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
                                child: Text("切换服务器"),
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
                                child: Text("断开连接"),
                              ),
                            ),
                          ),
                        ],
                        child: Container(
                          height: 48,
                          constraints: BoxConstraints(minWidth: 112),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text("一起看"),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      }
    );
  }

  Widget get leftControlWidget {
    return Observer(
      builder: (context) {
        return SafeArea(
          top: false,
          bottom: false,
          left: videoPageController.isFullscreen,
          right: videoPageController.isFullscreen,
          child: Column(
            children: [
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
                  playerController.lockPanel ? Icons.lock_outline : Icons.lock_open,
                  color: Colors.white,
                ),
                onPressed: () {
                  playerController.lockPanel = !playerController.lockPanel;
                },
              ),
              const Spacer(),
            ],
          ),
        );
      }
    );
  }
}
