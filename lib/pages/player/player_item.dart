import 'dart:async';
import 'dart:io';
import 'package:audio_video_progress_bar/audio_video_progress_bar.dart';
import 'package:kazumi/pages/player/player_item_panel.dart';
import 'package:kazumi/pages/player/smallest_player_item_panel.dart';
import 'package:kazumi/utils/constants.dart';
import 'package:kazumi/utils/logger.dart';
import 'package:kazumi/utils/utils.dart';
import 'package:kazumi/utils/webdav.dart';
import 'package:logger/logger.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import 'package:kazumi/pages/player/player_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/pages/video/video_controller.dart';
import 'package:window_manager/window_manager.dart';
import 'package:canvas_danmaku/canvas_danmaku.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:screen_brightness_platform_interface/screen_brightness_platform_interface.dart';
import 'package:flutter_volume_controller/flutter_volume_controller.dart';
import 'package:kazumi/pages/history/history_controller.dart';
import 'package:kazumi/pages/info/info_controller.dart';
import 'package:kazumi/pages/collect/collect_controller.dart';
import 'package:hive/hive.dart';
import 'package:kazumi/utils/storage.dart';
import 'package:kazumi/request/damaku.dart';
import 'package:kazumi/modules/danmaku/danmaku_search_response.dart';
import 'package:kazumi/modules/danmaku/danmaku_episode_response.dart';
import 'package:kazumi/pages/player/player_item_surface.dart';
import 'package:kazumi/bean/widget/text_display.dart';
import 'package:mobx/mobx.dart' as mobx;

class PlayerItem extends StatefulWidget {
  const PlayerItem({
    super.key,
    required this.openMenu,
    required this.locateEpisode,
    required this.changeEpisode,
    required this.onBackPressed,
    required this.keyboardFocus,
    required this.sendDanmaku,
  });

  final VoidCallback openMenu;
  final VoidCallback locateEpisode;
  final Future<void> Function(int episode, {int currentRoad, int offset})
      changeEpisode;
  final void Function(BuildContext) onBackPressed;
  final void Function(String) sendDanmaku;
  final FocusNode keyboardFocus;

  @override
  State<PlayerItem> createState() => _PlayerItemState();
}

class _PlayerItemState extends State<PlayerItem>
    with
        WindowListener,
        WidgetsBindingObserver,
        SingleTickerProviderStateMixin {
  Box setting = GStorage.setting;
  final PlayerController playerController = Modular.get<PlayerController>();
  final VideoPageController videoPageController =
      Modular.get<VideoPageController>();
  final HistoryController historyController = Modular.get<HistoryController>();
  final InfoController infoController = Modular.get<InfoController>();
  final CollectController collectController = Modular.get<CollectController>();

  // 1. 在看
  // 2. 想看
  // 3. 搁置
  // 4. 看过
  // 5. 抛弃
  late int collectType;
  late bool webDavEnable;
  late bool webDavEnableHistory;

  // 弹幕
  final _danmuKey = GlobalKey();
  late bool _border;
  late double _opacity;
  late double _duration;
  late double _fontSize;
  late double danmakuArea;
  late bool _hideTop;
  late bool _hideBottom;
  late bool _hideScroll;
  late bool _massiveMode;
  late bool _danmakuColor;
  late bool _danmakuBiliBiliSource;
  late bool _danmakuGamerSource;
  late bool _danmakuDanDanSource;
  late int _danmakuFontWeight;

  // 硬件解码
  late bool haEnable;

  Timer? hideTimer;
  Timer? playerTimer;
  Timer? mouseScrollerTimer;
  Timer? hideVolumeUITimer;

  // 过渡动画控制器
  AnimationController? animationController;

  double lastPlayerSpeed = 1.0;
  int episodeNum = 0;

  late mobx.ReactionDisposer _fullscreenListener;

  /// 处理 Android/iOS 应用后台或熄屏
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    try {
      if (playerController.playerPlaying) {
        playerController.danmakuController.resume();
      }
    } catch (_) {}
  }

  void _handleTap() {
    if (Utils.isDesktop()) {
      playerController.playOrPause();
    } else {
      if (playerController.showVideoController) {
        hideVideoController();
      } else {
        displayVideoController();
      }
    }
  }

  void _handleDoubleTap() {
    if (Utils.isDesktop() && !videoPageController.isPip) {
      handleFullscreen();
    } else {
      playerController.playOrPause();
    }
  }

  void _handleHove() {
    if (!playerController.showVideoController) {
      displayVideoController();
    }
    hideTimer?.cancel();
    startHideTimer();
  }

  void _handleMouseScroller() {
    playerController.showVolume = true;
    mouseScrollerTimer?.cancel();
    mouseScrollerTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) {
        playerController.showVolume = false;
      }
      mouseScrollerTimer = null;
    });
  }

  void _handleKeyChangingVolume() {
    playerController.showVolume = true;
    hideVolumeUITimer?.cancel();
    hideVolumeUITimer = Timer(const Duration(seconds: 2), () {
      if (mounted) {
        playerController.showVolume = false;
      }
      hideVolumeUITimer = null;
    });
  }

  void handleDanmaku() {
    playerController.danmakuController.clear();
    // if true, turn off danmaku.
    if (playerController.danmakuOn) {
      setState(() {
        playerController.danmakuOn = false;
      });
      return;
    }
    // if false and empty, show dialog.
    if (playerController.danDanmakus.isEmpty) {
      showDanmakuSwitch();
      return;
    }
    // turn on danmaku.
    setState(() {
      playerController.danmakuOn = true;
    });
  }

  void _handleFullscreenChange(BuildContext context) async {
    if (videoPageController.isFullscreen && !Utils.isTablet()) {
      playerController.lockPanel = false;
    }
    playerController.danmakuController.clear();
    if (webDavEnable && webDavEnableHistory) {
      var webDav = WebDav();
      webDav.updateHistory();
    }
  }

  void handleProgressBarDragStart(ThumbDragDetails details) {
    playerTimer?.cancel();
    playerController.pause(enableSync: false);
    hideTimer?.cancel();
    playerController.showVideoController = true;
  }

  void handleProgressBarDragEnd() {
    playerController.play(enableSync: false);
    startHideTimer();
    playerTimer = getPlayerTimer();
  }

  void handleFullscreen() {
    _handleFullscreenChange(context);
    if (videoPageController.isFullscreen) {
      Utils.exitFullScreen();
      if (!Utils.isDesktop()) {
        widget.locateEpisode();
        videoPageController.showTabBody = true;
      }
    } else {
      Utils.enterFullScreen();
      videoPageController.showTabBody = false;
    }
    videoPageController.isFullscreen = !videoPageController.isFullscreen;
  }

  void displayVideoController() {
    animationController?.forward();
    hideTimer?.cancel();
    startHideTimer();
    playerController.showVideoController = true;
  }

  void hideVideoController() {
    animationController?.reverse();
    hideTimer?.cancel();
    playerController.showVideoController = false;
  }

  Future<void> setPlaybackSpeed(double speed) async {
    await playerController.setPlaybackSpeed(speed);
    playerController.danmakuController.updateOption(
      playerController.danmakuController.option
          .copyWith(duration: _duration ~/ speed),
    );
  }

  Future<void> increaseVolume() async {
    await playerController.setVolume(playerController.volume + 10);
  }

  Future<void> decreaseVolume() async {
    await playerController.setVolume(playerController.volume - 10);
  }

  Future<void> setBrightness(double value) async {
    try {
      await ScreenBrightnessPlatform.instance
          .setApplicationScreenBrightness(value);
    } catch (_) {}
  }

  void startHideTimer() {
    hideTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && playerController.canHidePlayerPanel) {
        playerController.showVideoController = false;
        animationController?.reverse();
      }
      hideTimer = null;
    });
  }

  // Used to pass hideTimer operation to panel layer
  void cancelHideTimer() {
    hideTimer?.cancel();
  }

  Timer getPlayerTimer() {
    return Timer.periodic(const Duration(seconds: 1), (timer) {
      playerController.playing = playerController.playerPlaying;
      playerController.isBuffering = playerController.playerBuffering;
      playerController.currentPosition = playerController.playerPosition;
      playerController.buffer = playerController.playerBuffer;
      playerController.duration = playerController.playerDuration;
      playerController.completed = playerController.playerCompleted;
      // 弹幕相关
      if (playerController.currentPosition.inMicroseconds != 0 &&
          playerController.playerPlaying == true &&
          playerController.danmakuOn == true) {
        playerController.danDanmakus[playerController.currentPosition.inSeconds]
            ?.asMap()
            .forEach((idx, danmaku) async {
          if (!_danmakuColor) {
            danmaku.color = Colors.white;
          }
          if (!_danmakuBiliBiliSource && danmaku.source.contains('BiliBili')) {
            return;
          }
          if (!_danmakuGamerSource && danmaku.source.contains('Gamer')) {
            return;
          }
          if (!_danmakuDanDanSource &&
              !(danmaku.source.contains('BiliBili') ||
                  danmaku.source.contains('Gamer'))) {
            return;
          }
          await Future.delayed(
              Duration(
                  milliseconds: idx *
                      1000 ~/
                      playerController
                          .danDanmakus[
                              playerController.currentPosition.inSeconds]!
                          .length),
              () => mounted &&
                      playerController.playerPlaying &&
                      !playerController.playerBuffering &&
                      playerController.danmakuOn
                  ? playerController.danmakuController.addDanmaku(
                      DanmakuContentItem(danmaku.message,
                          color: danmaku.color,
                          type: danmaku.type == 4
                              ? DanmakuItemType.bottom
                              : (danmaku.type == 5
                                  ? DanmakuItemType.top
                                  : DanmakuItemType.scroll)))
                  : null);
        });
      }
      // 音量相关
      if (!playerController.volumeSeeking) {
        if (Utils.isDesktop()) {
          playerController.volume = playerController.playerVolume;
        } else {
          FlutterVolumeController.getVolume().then((value) {
            final volume = value ?? 0.0;
            playerController.volume = volume * 100;
          });
        }
      }
      // 亮度相关
      if (!Platform.isWindows &&
          !Platform.isMacOS &&
          !Platform.isLinux &&
          !playerController.brightnessSeeking) {
        ScreenBrightnessPlatform.instance.application.then((value) {
          playerController.brightness = value;
        });
      }
      // 历史记录相关
      if (playerController.playerPlaying && !videoPageController.loading) {
        historyController.updateHistory(
            videoPageController.currentEpisode,
            videoPageController.currentRoad,
            videoPageController.currentPlugin.name,
            infoController.bangumiItem,
            playerController.playerPosition,
            videoPageController.src,
            videoPageController.roadList[videoPageController.currentRoad]
                .identifier[videoPageController.currentEpisode - 1]);
      }
      // 自动播放下一集
      if (playerController.completed &&
          videoPageController.currentEpisode <
              videoPageController
                  .roadList[videoPageController.currentRoad].data.length &&
          !videoPageController.loading) {
        KazumiDialog.showToast(
            message:
                '正在加载${videoPageController.roadList[videoPageController.currentRoad].identifier[videoPageController.currentEpisode]}');
        try {
          playerTimer!.cancel();
        } catch (_) {}
        widget.changeEpisode(videoPageController.currentEpisode + 1,
            currentRoad: videoPageController.currentRoad);
      }
      // 一起去看相关
      playerController.setSyncPlayCurrentPosition();
    });
  }

  void showDanmakuSearchDialog(String keyword) async {
    KazumiDialog.dismiss();
    KazumiDialog.showLoading(msg: '弹幕检索中');
    DanmakuSearchResponse danmakuSearchResponse;
    DanmakuEpisodeResponse danmakuEpisodeResponse;
    try {
      danmakuSearchResponse =
          await DanmakuRequest.getDanmakuSearchResponse(keyword);
    } catch (e) {
      KazumiDialog.dismiss();
      KazumiDialog.showToast(message: '弹幕检索错误: ${e.toString()}');
      return;
    }
    KazumiDialog.dismiss();
    if (danmakuSearchResponse.animes.isEmpty) {
      KazumiDialog.showToast(message: '未找到匹配结果');
      return;
    }
    await KazumiDialog.show(builder: (context) {
      return Dialog(
        child: ListView(
          shrinkWrap: true,
          children: danmakuSearchResponse.animes.map((danmakuInfo) {
            return ListTile(
              title: Text(danmakuInfo.animeTitle),
              onTap: () async {
                KazumiDialog.dismiss();
                KazumiDialog.showLoading(msg: '弹幕检索中');
                try {
                  danmakuEpisodeResponse =
                      await DanmakuRequest.getDanDanEpisodesByBangumiID(
                          danmakuInfo.animeId);
                } catch (e) {
                  KazumiDialog.dismiss();
                  KazumiDialog.showToast(message: '弹幕检索错误: ${e.toString()}');
                  return;
                }
                KazumiDialog.dismiss();
                if (danmakuEpisodeResponse.episodes.isEmpty) {
                  KazumiDialog.showToast(message: '未找到匹配结果');
                  return;
                }
                KazumiDialog.show(builder: (context) {
                  return Dialog(
                    child: ListView(
                      shrinkWrap: true,
                      children: danmakuEpisodeResponse.episodes.map((episode) {
                        return ListTile(
                          title: Text(episode.episodeTitle),
                          onTap: () {
                            KazumiDialog.dismiss();
                            KazumiDialog.showToast(message: '弹幕切换中');
                            playerController
                                .getDanDanmakuByEpisodeID(episode.episodeId);
                          },
                        );
                      }).toList(),
                    ),
                  );
                });
              },
            );
          }).toList(),
        ),
      );
    });
  }

  // 弹幕查询
  void showDanmakuSwitch() {
    KazumiDialog.show(
      builder: (context) {
        final TextEditingController searchTextController =
            TextEditingController();
        searchTextController.text = videoPageController.title;
        return AlertDialog(
          title: const Text('弹幕检索'),
          content: TextField(
            controller: searchTextController,
            decoration: const InputDecoration(
              hintText: '番剧名',
            ),
            onSubmitted: (keyword) {
              showDanmakuSearchDialog(keyword);
            },
          ),
          actions: [
            TextButton(
              onPressed: () {
                KazumiDialog.dismiss();
                widget.keyboardFocus.requestFocus();
              },
              child: Text(
                '取消',
                style: TextStyle(color: Theme.of(context).colorScheme.outline),
              ),
            ),
            TextButton(
              onPressed: () {
                showDanmakuSearchDialog(searchTextController.text);
              },
              child: const Text(
                '提交',
              ),
            ),
          ],
        );
      },
    );
  }

  void showVideoInfo() async {
    String currentDemux = await Utils.getCurrentDemux();
    KazumiDialog.show(builder: (context) {
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
        actions: [
          TextButton(
              onPressed: () {
                KazumiDialog.dismiss();
                showPlayerLogsDialog();
              },
              child: Text('调试信息')),
          TextButton(onPressed: KazumiDialog.dismiss, child: Text('取消')),
        ],
      );
    });
  }

  void showPlayerLogsDialog() {
    KazumiDialog.show(builder: (context) {
      return AlertDialog(
        title: const Text('调试信息'),
        content: SizedBox(
            height: 400,
            width: 400,
            child: TextDisplayWidget(logLines: playerController.playerLog)),
        actions: [
          TextButton(
              onPressed: () {
                Clipboard.setData(
                    ClipboardData(text: playerController.playerLog.toString()));
                KazumiDialog.showToast(message: '已复制到剪贴板');
              },
              child: const Text('复制到剪贴板')),
          TextButton(
            onPressed: KazumiDialog.dismiss,
            child: const Text('取消'),
          ),
        ],
      );
    });
  }

  void showSyncPlayRoomCreateDialog() {
    final formKey = GlobalKey<FormState>();
    final TextEditingController roomController = TextEditingController();
    final TextEditingController usernameController = TextEditingController();
    KazumiDialog.show(builder: (BuildContext context) {
      return AlertDialog(
        title: const Text('加入房间'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: roomController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: '房间号',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '请输入房间号';
                  }
                  final regex = RegExp(r'^[0-9]{6,10}$');
                  if (!regex.hasMatch(value)) {
                    return '房间号需要6到10位数字';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: usernameController,
                decoration: const InputDecoration(
                  labelText: '用户名',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '请输入用户名';
                  }
                  final regex = RegExp(r'^[a-zA-Z]{4,12}$');
                  if (!regex.hasMatch(value)) {
                    return '用户名必须为4到12位英文字符';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              KazumiDialog.dismiss();
            },
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                KazumiDialog.dismiss();
                playerController.createSyncPlayRoom(roomController.text,
                    usernameController.text, widget.changeEpisode);
              }
            },
            child: const Text('确定'),
          ),
        ],
      );
    });
  }

  /// Used to decide which panel is used.
  /// It's too complicated to write these in conditional sentence.
  /// * true: use [PlayerItemPanel]
  /// * false: use [SmallestPlayerItemPanel]
  bool needFullPanel(BuildContext context) {
    // windows too small, workaround for ohos floating window
    if (MediaQuery.sizeOf(context).width < LayoutBreakpoint.compact['width']!) {
      return false;
    }
    // in desktop pip mode
    if (videoPageController.isPip) {
      return false;
    }
    // does not meet Google's phone landscape height and tablet landscape width requirements.
    if (MediaQuery.sizeOf(context).height >
            LayoutBreakpoint.compact['height']! &&
        MediaQuery.sizeOf(context).width < LayoutBreakpoint.medium['width']!) {
      return false;
    }
    return true;
  }

  @override
  void onWindowRestore() {
    playerController.danmakuController.onClear();
  }

  @override
  void initState() {
    super.initState();
    _fullscreenListener = mobx.reaction<bool>(
      (_) => videoPageController.isFullscreen,
      (_) {
        _handleFullscreenChange(context);
      },
    );
    // workaround for #214
    if (Platform.isIOS) {
      FlutterVolumeController.setIOSAudioSessionCategory(
          category: AudioSessionCategory.playback);
    }
    WidgetsBinding.instance.addObserver(this);
    animationController ??= AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    webDavEnable = setting.get(SettingBoxKey.webDavEnable, defaultValue: false);
    webDavEnableHistory =
        setting.get(SettingBoxKey.webDavEnableHistory, defaultValue: false);
    playerController.danmakuOn =
        setting.get(SettingBoxKey.danmakuEnabledByDefault, defaultValue: false);
    _border = setting.get(SettingBoxKey.danmakuBorder, defaultValue: true);
    _opacity = setting.get(SettingBoxKey.danmakuOpacity, defaultValue: 1.0);
    _duration = 8;
    _fontSize = setting.get(SettingBoxKey.danmakuFontSize,
        defaultValue: (Utils.isCompact()) ? 16.0 : 25.0);
    danmakuArea = setting.get(SettingBoxKey.danmakuArea, defaultValue: 1.0);
    _hideTop = !setting.get(SettingBoxKey.danmakuTop, defaultValue: true);
    _hideBottom =
        !setting.get(SettingBoxKey.danmakuBottom, defaultValue: false);
    _hideScroll = !setting.get(SettingBoxKey.danmakuScroll, defaultValue: true);
    _massiveMode =
        setting.get(SettingBoxKey.danmakuMassive, defaultValue: false);
    _danmakuColor = setting.get(SettingBoxKey.danmakuColor, defaultValue: true);
    _danmakuBiliBiliSource =
        setting.get(SettingBoxKey.danmakuBiliBiliSource, defaultValue: true);
    _danmakuGamerSource =
        setting.get(SettingBoxKey.danmakuGamerSource, defaultValue: true);
    _danmakuDanDanSource =
        setting.get(SettingBoxKey.danmakuDanDanSource, defaultValue: true);
    _danmakuFontWeight =
        setting.get(SettingBoxKey.danmakuFontWeight, defaultValue: 4);
    haEnable = setting.get(SettingBoxKey.hAenable, defaultValue: true);
    playerTimer = getPlayerTimer();
    windowManager.addListener(this);
    displayVideoController();
  }

  @override
  void dispose() {
    // Don't dispose player here
    // We need to reuse the player after episode is changed and player item is disposed
    // We dispose player after video page disposed
    _fullscreenListener();
    WidgetsBinding.instance.removeObserver(this);
    windowManager.removeListener(this);
    playerTimer?.cancel();
    hideTimer?.cancel();
    mouseScrollerTimer?.cancel();
    hideVolumeUITimer?.cancel();
    animationController?.dispose();
    animationController = null;
    // Reset player panel state
    playerController.lockPanel = false;
    playerController.showVideoController = true;
    playerController.showSeekTime = false;
    playerController.showBrightness = false;
    playerController.showVolume = false;
    playerController.showPlaySpeed = false;
    playerController.brightnessSeeking = false;
    playerController.volumeSeeking = false;
    playerController.canHidePlayerPanel = true;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    collectType = collectController.getCollectType(infoController.bangumiItem);
    return Observer(
      builder: (context) {
        return ClipRect(
          child: Container(
            color: Colors.black,
            child: MouseRegion(
              cursor: (videoPageController.isFullscreen &&
                      !playerController.showVideoController)
                  ? SystemMouseCursors.none
                  : SystemMouseCursors.basic,
              onHover: (PointerEvent pointerEvent) {
                // workaround for android.
                // I don't know why, but android tap event will trigger onHover event.
                if (Utils.isDesktop()) {
                  if (pointerEvent.position.dy > 50 &&
                      pointerEvent.position.dy <
                          MediaQuery.of(context).size.height - 70) {
                    _handleHove();
                  } else {
                    if (!playerController.showVideoController) {
                      animationController?.forward();
                      playerController.showVideoController = true;
                    }
                  }
                }
              },
              child: Listener(
                onPointerSignal: (pointerSignal) {
                  if (pointerSignal is PointerScrollEvent) {
                    _handleMouseScroller();
                    final scrollDelta = pointerSignal.scrollDelta;
                    final double volume =
                        playerController.volume - scrollDelta.dy / 60;
                    playerController.setVolume(volume);
                  }
                },
                child: SizedBox(
                  height: videoPageController.isFullscreen
                      ? (MediaQuery.of(context).size.height)
                      : (MediaQuery.of(context).size.width * 9.0 / (16.0)),
                  width: MediaQuery.of(context).size.width,
                  child: Stack(alignment: Alignment.center, children: [
                    Center(
                        child: Focus(
                            // workaround for #461
                            // I don't know why, but the focus node will break popscope.
                            focusNode:
                                Utils.isDesktop() ? widget.keyboardFocus : null,
                            autofocus: Utils.isDesktop(),
                            onKeyEvent: (focusNode, KeyEvent event) {
                              if (event is KeyDownEvent) {
                                // 当空格键被按下时
                                if (event.logicalKey ==
                                    LogicalKeyboardKey.space) {
                                  try {
                                    playerController.playOrPause();
                                  } catch (e) {
                                    KazumiLogger().log(
                                        Level.error, '播放器内部错误 ${e.toString()}');
                                  }
                                }
                                // 右方向键被按下
                                if (event.logicalKey ==
                                    LogicalKeyboardKey.arrowRight) {
                                  lastPlayerSpeed =
                                      playerController.playerSpeed;
                                }
                                // 左方向键被按下
                                if (event.logicalKey ==
                                    LogicalKeyboardKey.arrowLeft) {
                                  int targetPosition = playerController
                                          .currentPosition.inSeconds -
                                      10;
                                  if (targetPosition < 0) {
                                    targetPosition = 0;
                                  }
                                  try {
                                    playerTimer?.cancel();
                                    playerController.seek(
                                        Duration(seconds: targetPosition));
                                    playerTimer = getPlayerTimer();
                                  } catch (e) {
                                    KazumiLogger()
                                        .log(Level.error, e.toString());
                                  }
                                }
                                // 上方向键被按下
                                if (event.logicalKey ==
                                    LogicalKeyboardKey.arrowUp) {
                                  increaseVolume();
                                  _handleKeyChangingVolume();
                                }
                                // 下方向键被按下
                                if (event.logicalKey ==
                                    LogicalKeyboardKey.arrowDown) {
                                  decreaseVolume();
                                  _handleKeyChangingVolume();
                                }
                                // Esc键被按下
                                if (event.logicalKey ==
                                    LogicalKeyboardKey.escape) {
                                  if (videoPageController.isFullscreen &&
                                      !Utils.isTablet()) {
                                    try {
                                      playerController.danmakuController
                                          .onClear();
                                    } catch (_) {}
                                    Utils.exitFullScreen();
                                    videoPageController.isFullscreen =
                                        !videoPageController.isFullscreen;
                                  } else if (!Platform.isMacOS) {
                                    playerController.pause();
                                    windowManager.hide();
                                  }
                                }
                                // F键被按下
                                if (event.logicalKey ==
                                    LogicalKeyboardKey.keyF) {
                                  if (!videoPageController.isPip) {
                                    handleFullscreen();
                                  }
                                }
                                // D键盘被按下
                                if (event.logicalKey ==
                                    LogicalKeyboardKey.keyD) {
                                  handleDanmaku();
                                }
                              } else if (event is KeyRepeatEvent) {
                                // 右方向键长按
                                if (event.logicalKey ==
                                    LogicalKeyboardKey.arrowRight) {
                                  if (playerController.playerSpeed < 2.0) {
                                    playerController.showPlaySpeed = true;
                                    setPlaybackSpeed(2.0);
                                  }
                                }
                              } else if (event is KeyUpEvent) {
                                // 右方向键抬起
                                if (event.logicalKey ==
                                    LogicalKeyboardKey.arrowRight) {
                                  if (playerController.showPlaySpeed) {
                                    playerController.showPlaySpeed = false;
                                    setPlaybackSpeed(lastPlayerSpeed);
                                  } else {
                                    try {
                                      playerTimer?.cancel();
                                      playerController.seek(Duration(
                                          seconds: playerController
                                                  .currentPosition.inSeconds +
                                              10));
                                      playerTimer = getPlayerTimer();
                                    } catch (e) {
                                      KazumiLogger().log(Level.error,
                                          '播放器内部错误 ${e.toString()}');
                                    }
                                  }
                                }
                              }
                              return KeyEventResult.handled;
                            },
                            child: const PlayerItemSurface())),
                    (playerController.isBuffering ||
                            videoPageController.loading)
                        ? const Positioned.fill(
                            child: Center(
                              child: CircularProgressIndicator(),
                            ),
                          )
                        : Container(),
                    GestureDetector(
                      onTap: () {
                        _handleTap();
                      },
                      onDoubleTap: (playerController.lockPanel)
                          ? null
                          : () {
                              _handleDoubleTap();
                            },
                      onLongPressStart: (_) {
                        if (playerController.lockPanel) {
                          return;
                        }
                        setState(() {
                          playerController.showPlaySpeed = true;
                        });
                        lastPlayerSpeed = playerController.playerSpeed;
                        setPlaybackSpeed(2.0);
                      },
                      onLongPressEnd: (_) {
                        if (playerController.lockPanel) {
                          return;
                        }
                        setState(() {
                          playerController.showPlaySpeed = false;
                        });
                        setPlaybackSpeed(lastPlayerSpeed);
                      },
                      child: Container(
                        color: Colors.transparent,
                        width: double.infinity,
                        height: double.infinity,
                      ),
                    ),
                    // 弹幕面板
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      height: videoPageController.isFullscreen
                          ? MediaQuery.sizeOf(context).height
                          : (MediaQuery.sizeOf(context).width * 9 / 16),
                      child: DanmakuScreen(
                        key: _danmuKey,
                        createdController: (DanmakuController e) {
                          playerController.danmakuController = e;
                        },
                        option: DanmakuOption(
                          hideTop: _hideTop,
                          hideScroll: _hideScroll,
                          hideBottom: _hideBottom,
                          area: danmakuArea,
                          opacity: _opacity,
                          fontSize: _fontSize,
                          duration: _duration ~/ playerController.playerSpeed,
                          showStroke: _border,
                          fontWeight: _danmakuFontWeight,
                          massiveMode: _massiveMode,
                        ),
                      ),
                    ),
                    // 播放器控制面板
                    (needFullPanel(context))
                        ? PlayerItemPanel(
                            onBackPressed: widget.onBackPressed,
                            setPlaybackSpeed: setPlaybackSpeed,
                            showDanmakuSwitch: showDanmakuSwitch,
                            changeEpisode: widget.changeEpisode,
                            openMenu: widget.openMenu,
                            handleFullscreen: handleFullscreen,
                            handleProgressBarDragStart:
                                handleProgressBarDragStart,
                            handleProgressBarDragEnd: handleProgressBarDragEnd,
                            animationController: animationController!,
                            keyboardFocus: widget.keyboardFocus,
                            sendDanmaku: widget.sendDanmaku,
                            startHideTimer: startHideTimer,
                            cancelHideTimer: cancelHideTimer,
                            handleDanmaku: handleDanmaku,
                            showVideoInfo: showVideoInfo,
                            showSyncPlayRoomCreateDialog:
                                showSyncPlayRoomCreateDialog,
                          )
                        : SmallestPlayerItemPanel(
                            onBackPressed: widget.onBackPressed,
                            setPlaybackSpeed: setPlaybackSpeed,
                            showDanmakuSwitch: showDanmakuSwitch,
                            handleFullscreen: handleFullscreen,
                            handleProgressBarDragStart:
                                handleProgressBarDragStart,
                            handleProgressBarDragEnd: handleProgressBarDragEnd,
                            animationController: animationController!,
                            keyboardFocus: widget.keyboardFocus,
                            handleHove: _handleHove,
                            startHideTimer: startHideTimer,
                            cancelHideTimer: cancelHideTimer,
                            handleDanmaku: handleDanmaku,
                            showVideoInfo: showVideoInfo,
                            showSyncPlayRoomCreateDialog:
                                showSyncPlayRoomCreateDialog,
                          ),
                    // 播放器手势控制
                    Positioned.fill(
                      left: 16,
                      top: 25,
                      right: 15,
                      bottom: 15,
                      child: (Utils.isDesktop() || playerController.lockPanel)
                          ? Container()
                          : GestureDetector(
                              onHorizontalDragStart: (_) {
                                if (!playerController.showVideoController) {
                                  animationController?.forward();
                                }
                                playerController.canHidePlayerPanel = false;
                              },
                              onHorizontalDragUpdate:
                                  (DragUpdateDetails details) {
                                playerController.showSeekTime = true;
                                playerTimer?.cancel();
                                playerController.pause(enableSync: false);
                                final double scale =
                                    180000 / MediaQuery.sizeOf(context).width;
                                int ms = (playerController
                                            .currentPosition.inMilliseconds +
                                        (details.delta.dx * scale).round())
                                    .clamp(
                                        0,
                                        playerController
                                            .duration.inMilliseconds);
                                playerController.currentPosition =
                                    Duration(milliseconds: ms);
                              },
                              onHorizontalDragEnd: (_) {
                                playerController.play(enableSync: false);
                                playerController
                                    .seek(playerController.currentPosition);
                                playerController.canHidePlayerPanel = true;
                                if (!playerController.showVideoController) {
                                  animationController?.reverse();
                                } else {
                                  hideTimer?.cancel();
                                  startHideTimer();
                                }
                                playerTimer = getPlayerTimer();
                                playerController.showSeekTime = false;
                              },
                              onVerticalDragUpdate:
                                  (DragUpdateDetails details) async {
                                final double totalWidth =
                                    MediaQuery.sizeOf(context).width;
                                final double totalHeight =
                                    MediaQuery.sizeOf(context).height;
                                final double tapPosition =
                                    details.localPosition.dx;
                                final double sectionWidth = totalWidth / 2;
                                final double delta = details.delta.dy;

                                if (tapPosition < sectionWidth) {
                                  // 左边区域
                                  playerController.brightnessSeeking = true;
                                  playerController.showBrightness = true;
                                  final double level = (totalHeight) * 2;
                                  final double brightness =
                                      playerController.brightness -
                                          delta / level;
                                  final double result =
                                      brightness.clamp(0.0, 1.0);
                                  setBrightness(result);
                                  playerController.brightness = result;
                                } else {
                                  // 右边区域
                                  playerController.volumeSeeking = true;
                                  playerController.showVolume = true;
                                  final double level = (totalHeight) * 0.03;
                                  final double volume =
                                      playerController.volume - delta / level;
                                  playerController.setVolume(volume);
                                }
                              },
                              onVerticalDragEnd: (_) {
                                if (playerController.volumeSeeking) {
                                  playerController.volumeSeeking = false;
                                  Future.delayed(const Duration(seconds: 1),
                                      () {
                                    FlutterVolumeController.updateShowSystemUI(
                                        true);
                                  });
                                }
                                if (playerController.brightnessSeeking) {
                                  playerController.brightnessSeeking = false;
                                }
                                playerController.showVolume = false;
                                playerController.showBrightness = false;
                              },
                            ),
                    ),
                  ]),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
