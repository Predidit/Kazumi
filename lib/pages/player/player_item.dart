import 'dart:async';
import 'package:kazumi/utils/utils.dart';
import 'package:kazumi/utils/webdav.dart';
import 'package:provider/provider.dart';
import 'package:kazumi/pages/menu/menu.dart';
import 'package:kazumi/pages/menu/side_menu.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import 'package:kazumi/pages/player/player_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/pages/video/video_controller.dart';
import 'package:window_manager/window_manager.dart';
import 'package:canvas_danmaku/canvas_danmaku.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:audio_video_progress_bar/audio_video_progress_bar.dart';
import 'package:flutter_volume_controller/flutter_volume_controller.dart';
import 'package:kazumi/pages/history/history_controller.dart';
import 'package:kazumi/pages/info/info_controller.dart';
import 'package:kazumi/pages/favorite/favorite_controller.dart';
import 'package:hive/hive.dart';
import 'package:kazumi/utils/storage.dart';
import 'package:kazumi/request/damaku.dart';
import 'package:kazumi/modules/danmaku/danmaku_search_response.dart';
import 'package:kazumi/bean/appbar/drag_to_move_bar.dart' as dtb;

class PlayerItem extends StatefulWidget {
  const PlayerItem({super.key});

  @override
  State<PlayerItem> createState() => _PlayerItemState();
}

class _PlayerItemState extends State<PlayerItem> with WindowListener {
  Box setting = GStorage.setting;
  final PlayerController playerController = Modular.get<PlayerController>();
  final VideoPageController videoPageController =
      Modular.get<VideoPageController>();
  final HistoryController historyController = Modular.get<HistoryController>();
  final InfoController infoController = Modular.get<InfoController>();
  final FavoriteController favoriteController =
      Modular.get<FavoriteController>();
  final FocusNode _focusNode = FocusNode();
  late DanmakuController danmakuController;
  dynamic navigationBarState;
  late bool isFavorite;
  late bool webDavEnable;
  bool isPopping = false;

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

  Timer? hideTimer;
  Timer? playerTimer;
  Timer? mouseScrollerTimer;

  void _handleTap() {
    playerController.showPositioned = true;
    if (hideTimer != null) {
      hideTimer!.cancel();
    }

    hideTimer = Timer(const Duration(seconds: 4), () {
      playerController.showPositioned = false;
      hideTimer = null;
    });
  }

  void _handleMouseScroller() {
    playerController.showVolume = true;
    if (mouseScrollerTimer != null) {
      mouseScrollerTimer!.cancel();
    }

    mouseScrollerTimer = Timer(const Duration(seconds: 2), () {
      playerController.showVolume = false;
      mouseScrollerTimer = null;
    });
  }

  getPlayerTimer() {
    return Timer.periodic(const Duration(seconds: 1), (timer) {
      playerController.playing = playerController.mediaPlayer.state.playing;
      playerController.isBuffering =
          playerController.mediaPlayer.state.buffering;
      playerController.currentPosition =
          playerController.mediaPlayer.state.position;
      playerController.buffer = playerController.mediaPlayer.state.buffer;
      playerController.duration = playerController.mediaPlayer.state.duration;
      playerController.completed = playerController.mediaPlayer.state.completed;
      // 弹幕相关
      if (playerController.currentPosition.inMicroseconds != 0 &&
          playerController.mediaPlayer.state.playing == true &&
          playerController.danmakuOn == true) {
        // debugPrint('当前播放到 ${videoController.currentPosition.inSeconds}');
        playerController.danDanmakus[playerController.currentPosition.inSeconds]
            ?.asMap()
            .forEach((idx, danmaku) async {
          if (!_danmakuColor) {
            danmaku.color = Colors.white;
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
                      playerController.mediaPlayer.state.playing &&
                      !playerController.mediaPlayer.state.buffering
                  ? danmakuController.addDanmaku(DanmakuContentItem(
                      danmaku.message,
                      color: danmaku.color,
                      type: danmaku.type == 4
                          ? DanmakuItemType.bottom
                          : (danmaku.type == 5
                              ? DanmakuItemType.top
                              : DanmakuItemType.scroll)))
                  : null);
        });
      }
      // 历史记录相关
      if (playerController.mediaPlayer.state.playing) {
        historyController.updateHistory(
            videoPageController.currentEspisode,
            videoPageController.currentRoad,
            videoPageController.currentPlugin.name,
            infoController.bangumiItem,
            playerController.mediaPlayer.state.position,
            videoPageController.src);
      }
      // 自动播放下一集
      if (playerController.completed &&
          videoPageController.currentEspisode <
              videoPageController
                  .roadList[videoPageController.currentRoad].data.length &&
          !videoPageController.loading) {
        SmartDialog.showToast(
            '正在加载第 ${videoPageController.currentEspisode + 1} 话');
        try {
          playerTimer!.cancel();
        } catch (_) {}
        videoPageController
            .changeEpisode(videoPageController.currentEspisode + 1);
      }
      windowManager.addListener(this);
    });
  }

  void onBackPressed(BuildContext context) async {
    if (videoPageController.androidFullscreen) {
      debugPrint('当前播放器全屏');
      try {
        await videoPageController.exitFullScreen();
        videoPageController.androidFullscreen = false;
        danmakuController.clear();
        return;
      } catch (e) {
        debugPrint(e.toString());
      }
    }
    debugPrint('当前播放器非全屏');
    // workaround on flutter 3.22.1
    if (!isPopping) {
      isPopping = true;
      if (webDavEnable) {
        try {
          var webDav = WebDav();
          webDav.updateHistory();
        } catch (e) {
          SmartDialog.showToast('同步记录失败 ${e.toString()}');
        }
      }
      Navigator.of(context).pop();
    }
    // Navigator.of(context).pop();
  }

  void _handleFullscreen() {
    if (videoPageController.androidFullscreen) {
      try {
        danmakuController.onClear();
      } catch (_) {}
      videoPageController.exitFullScreen();
    } else {
      videoPageController.enterFullScreen();
      navigationBarState.hideNavigate();
    }
    videoPageController.androidFullscreen =
        !videoPageController.androidFullscreen;
  }

  void _handleDanmaku() {
    if (playerController.danDanmakus.isEmpty) {
      SmartDialog.showToast('当前剧集没有找到弹幕的说 尝试手动检索',
          displayType: SmartToastType.last);
      showDanmakuSwitch();
      return;
    }
    danmakuController.onClear();
    playerController.danmakuOn = !playerController.danmakuOn;
    debugPrint('弹幕开关变更为 ${playerController.danmakuOn}');
  }

  // 选择倍速
  void showSetSpeedSheet() {
    final double currentSpeed = playerController.playerSpeed;
    final List<double> speedsList = [
      0.25,
      0.5,
      0.75,
      1.0,
      1.25,
      1.5,
      1.75,
      2.0
    ];
    SmartDialog.show(
        useAnimation: false,
        builder: (context) {
          return AlertDialog(
            title: const Text('播放速度'),
            content: StatefulBuilder(
                builder: (BuildContext context, StateSetter setState) {
              return Wrap(
                spacing: 8,
                runSpacing: 2,
                children: [
                  for (final double i in speedsList) ...<Widget>[
                    if (i == currentSpeed) ...<Widget>[
                      FilledButton(
                        onPressed: () async {
                          await playerController.setPlaybackSpeed(i);
                          SmartDialog.dismiss();
                        },
                        child: Text(i.toString()),
                      ),
                    ] else ...[
                      FilledButton.tonal(
                        onPressed: () async {
                          await playerController.setPlaybackSpeed(i);
                          SmartDialog.dismiss();
                        },
                        child: Text(i.toString()),
                      ),
                    ]
                  ]
                ],
              );
            }),
            actions: <Widget>[
              TextButton(
                onPressed: () => SmartDialog.dismiss(),
                child: Text(
                  '取消',
                  style:
                      TextStyle(color: Theme.of(context).colorScheme.outline),
                ),
              ),
              TextButton(
                onPressed: () async {
                  await playerController.setPlaybackSpeed(1.0);
                  SmartDialog.dismiss();
                },
                child: const Text('默认速度'),
              ),
            ],
          );
        });
  }

  // 弹幕查询
  void showDanmakuSwitch() {
    DanmakuSearchResponse danmakuSearchResponse;
    SmartDialog.show(
      useAnimation: false,
      builder: (context) {
        return Dialog(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              decoration: const InputDecoration(
                hintText: '搜索弹幕源',
              ),
              onSubmitted: (keyword) async {
                SmartDialog.dismiss();
                SmartDialog.showLoading(msg: '弹幕检索中');
                try {
                  danmakuSearchResponse =
                      await DanmakuRequest.getDanmakuSearchResponse(keyword);
                } catch (e) {
                  SmartDialog.dismiss();
                  SmartDialog.showToast('检索弹幕失败 ${e.toString()}');
                  return;
                }
                SmartDialog.dismiss();
                SmartDialog.show(
                    useAnimation: false,
                    builder: (context) {
                      return Dialog(
                        child: danmakuSearchResponse.animes.isEmpty
                            ? const Text('未找到匹配结果')
                            : ListView(
                                shrinkWrap: true,
                                children: danmakuSearchResponse.animes
                                    .map((danmakuInfo) {
                                  return ListTile(
                                    title: Text(danmakuInfo.animeTitle),
                                    onTap: () async {
                                      SmartDialog.showToast('弹幕切换中');
                                      try {
                                        await playerController.getDanDanmaku(
                                            danmakuInfo.animeTitle,
                                            videoPageController
                                                .currentEspisode);
                                      } catch (e) {
                                        SmartDialog.showToast('弹幕切换失败');
                                      }
                                      SmartDialog.dismiss();
                                    },
                                  );
                                }).toList(),
                              ),
                      );
                    });
              },
            ),
          ),
        );
      },
    );
  }

  Future<void> setVolume(double value) async {
    try {
      FlutterVolumeController.updateShowSystemUI(false);
      await FlutterVolumeController.setVolume(value);
    } catch (_) {}
  }

  Future<void> setBrightness(double value) async {
    try {
      await ScreenBrightness().setScreenBrightness(value);
    } catch (_) {}
  }

  @override
  void onWindowRestore() {
    danmakuController.onClear();
  }

  @override
  void initState() {
    super.initState();
    if (Utils.isCompact()) {
      navigationBarState =
          Provider.of<NavigationBarState>(context, listen: false);
    } else {
      navigationBarState =
          Provider.of<SideNavigationBarState>(context, listen: false);
    }
    webDavEnable = setting.get(SettingBoxKey.webDavEnable, defaultValue: false);
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
    playerTimer = getPlayerTimer();
  }

  @override
  void dispose() {
    //player.dispose();
    if (playerTimer != null) {
      playerTimer!.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    isFavorite = favoriteController.isFavorite(infoController.bangumiItem);

    return PopScope(
      // key: _key,
      canPop: false,
      onPopInvoked: (bool didPop) async {
        onBackPressed(context);
      },
      child: SafeArea(
        child: Scaffold(
          body: Observer(builder: (context) {
            return Column(
              children: [
                Container(
                  color: Colors.black,
                  child: MouseRegion(
                    cursor: (videoPageController.androidFullscreen &&
                            !playerController.showPositioned)
                        ? SystemMouseCursors.none
                        : SystemMouseCursors.basic,
                    onHover: (_) {
                      _handleTap();
                    },
                    child: FocusTraversalGroup(
                      child: FocusScope(
                        node: FocusScopeNode(),
                        child: Listener(
                          onPointerSignal: (pointerSignal) {
                            if (pointerSignal is PointerScrollEvent) {
                              _handleMouseScroller();
                              final scrollDelta = pointerSignal.scrollDelta;
                              debugPrint('滚轮滑动距离: ${scrollDelta.dy}');
                              final double volume = playerController.volume -
                                  scrollDelta.dy / 6000;
                              final double result = volume.clamp(0.0, 1.0);
                              setVolume(result);
                              playerController.volume = result;
                            }
                          },
                          child: KeyboardListener(
                            autofocus: true,
                            focusNode: _focusNode,
                            onKeyEvent: (KeyEvent event) {
                              if (event is KeyDownEvent) {
                                // 当空格键被按下时
                                _handleTap();
                                if (event.logicalKey ==
                                    LogicalKeyboardKey.space) {
                                  debugPrint('空格键被按下');
                                  try {
                                    playerController.playOrPause();
                                  } catch (e) {
                                    debugPrint(e.toString());
                                  }
                                }
                                // 右方向键被按下
                                if (event.logicalKey ==
                                    LogicalKeyboardKey.arrowRight) {
                                  debugPrint('右方向键被按下');
                                  try {
                                    if (playerTimer != null) {
                                      playerTimer!.cancel();
                                    }
                                    playerController.currentPosition = Duration(
                                        seconds: playerController
                                                .currentPosition.inSeconds +
                                            10);
                                    playerController
                                        .seek(playerController.currentPosition);
                                    playerTimer = getPlayerTimer();
                                  } catch (e) {
                                    debugPrint(e.toString());
                                  }
                                }
                                // 左方向键被按下
                                if (event.logicalKey ==
                                    LogicalKeyboardKey.arrowLeft) {
                                  if (playerController
                                          .currentPosition.inSeconds >
                                      10) {
                                    try {
                                      if (playerTimer != null) {
                                        playerTimer!.cancel();
                                      }
                                      playerController.currentPosition =
                                          Duration(
                                              seconds: playerController
                                                      .currentPosition
                                                      .inSeconds -
                                                  10);
                                      playerController.seek(
                                          playerController.currentPosition);
                                      playerTimer = getPlayerTimer();
                                    } catch (e) {
                                      debugPrint(e.toString());
                                    }
                                  }
                                }
                                // Esc键被按下
                                if (event.logicalKey ==
                                    LogicalKeyboardKey.escape) {
                                  if (videoPageController.androidFullscreen) {
                                    try {
                                      danmakuController.onClear();
                                    } catch (_) {}
                                    videoPageController.exitFullScreen();
                                    videoPageController.androidFullscreen =
                                        !videoPageController.androidFullscreen;
                                  }
                                }
                                // F键被按下
                                if (event.logicalKey ==
                                    LogicalKeyboardKey.keyF) {
                                  _handleFullscreen();
                                }
                                // D键盘被按下
                                if (event.logicalKey ==
                                    LogicalKeyboardKey.keyD) {
                                  _handleDanmaku();
                                }
                              }
                            },
                            child: SizedBox(
                              height: videoPageController.androidFullscreen
                                  ? (MediaQuery.of(context).size.height)
                                  : (MediaQuery.of(context).size.width *
                                      9.0 /
                                      (16.0)),
                              width: MediaQuery.of(context).size.width,
                              child:
                                  Stack(alignment: Alignment.center, children: [
                                Center(child: playerSurface),
                                playerController.isBuffering
                                    ? const Positioned.fill(
                                        child: Center(
                                          child: CircularProgressIndicator(),
                                        ),
                                      )
                                    : Container(),
                                GestureDetector(
                                  onTap: () async {
                                    _handleTap;
                                    try {
                                      playerController.volume =
                                          await FlutterVolumeController
                                                  .getVolume() ??
                                              playerController.volume;
                                    } catch (e) {
                                      debugPrint(e.toString());
                                    }
                                  },
                                  child: Container(
                                    color: Colors.transparent,
                                    width: double.infinity,
                                    height: double.infinity,
                                  ),
                                ),

                                // 播放器手势控制
                                Positioned.fill(
                                    left: 16,
                                    top: 25,
                                    right: 15,
                                    bottom: 15,
                                    child: Utils.isDesktop()
                                        ? Container()
                                        : GestureDetector(
                                            onHorizontalDragUpdate:
                                                (DragUpdateDetails details) {
                                            playerController.showPosition =
                                                true;
                                            if (playerTimer != null) {
                                              // debugPrint('检测到拖动, 定时器取消');
                                              playerTimer!.cancel();
                                            }
                                            playerController.pause();
                                            final double scale = 180000 /
                                                MediaQuery.sizeOf(context)
                                                    .width;
                                            playerController.currentPosition =
                                                Duration(
                                                    milliseconds:
                                                        playerController
                                                                .currentPosition
                                                                .inMilliseconds +
                                                            (details.delta.dx *
                                                                    scale)
                                                                .round());
                                          }, onHorizontalDragEnd:
                                                (DragEndDetails details) {
                                            playerController.play();
                                            playerController.seek(
                                                playerController
                                                    .currentPosition);
                                            playerTimer = getPlayerTimer();
                                            playerController.showPosition =
                                                false;
                                          }, onVerticalDragUpdate:
                                                (DragUpdateDetails
                                                    details) async {
                                            final double totalWidth =
                                                MediaQuery.sizeOf(context)
                                                    .width;
                                            final double totalHeight =
                                                MediaQuery.sizeOf(context)
                                                    .height;
                                            final double tapPosition =
                                                details.localPosition.dx;
                                            final double sectionWidth =
                                                totalWidth / 2;
                                            final double delta =
                                                details.delta.dy;

                                            /// 非全屏时禁用
                                            if (!videoPageController
                                                .androidFullscreen) {
                                              return;
                                            }
                                            if (tapPosition < sectionWidth) {
                                              // 左边区域
                                              playerController.showBrightness =
                                                  true;
                                              try {
                                                playerController.brightness =
                                                    await ScreenBrightness()
                                                        .current;
                                              } catch (e) {
                                                debugPrint(e.toString());
                                              }
                                              final double level =
                                                  (totalHeight) * 3;
                                              final double brightness =
                                                  playerController.brightness -
                                                      delta / level;
                                              final double result =
                                                  brightness.clamp(0.0, 1.0);
                                              setBrightness(result);
                                            } else {
                                              // 右边区域
                                              playerController.showVolume =
                                                  true;
                                              final double level =
                                                  (totalHeight) * 3;
                                              final double volume =
                                                  playerController.volume -
                                                      delta / level;
                                              final double result =
                                                  volume.clamp(0.0, 1.0);
                                              setVolume(result);
                                              playerController.volume = result;
                                            }
                                          }, onVerticalDragEnd:
                                                (DragEndDetails details) {
                                            playerController.showBrightness =
                                                false;
                                            playerController.showVolume = false;
                                          })),
                                // 顶部进度条
                                Positioned(
                                    top: 25,
                                    width: 200,
                                    child: playerController.showPosition
                                        ? Wrap(
                                            alignment: WrapAlignment.center,
                                            children: <Widget>[
                                              Container(
                                                padding:
                                                    const EdgeInsets.all(8.0),
                                                decoration: BoxDecoration(
                                                  color: Colors.black
                                                      .withOpacity(0.5),
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          8.0), // 圆角
                                                ),
                                                child: Text(
                                                  playerController
                                                              .currentPosition
                                                              .compareTo(
                                                                  playerController
                                                                      .mediaPlayer
                                                                      .state
                                                                      .position) >
                                                          0
                                                      ? '快进 ${playerController.currentPosition.inSeconds - playerController.mediaPlayer.state.position.inSeconds} 秒'
                                                      : '快退 ${playerController.mediaPlayer.state.position.inSeconds - playerController.currentPosition.inSeconds} 秒',
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                  ),
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
                                                  padding:
                                                      const EdgeInsets.all(8.0),
                                                  decoration: BoxDecoration(
                                                    color: Colors.black
                                                        .withOpacity(0.5),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            8.0), // 圆角
                                                  ),
                                                  child: Row(
                                                    children: <Widget>[
                                                      const Icon(
                                                          Icons.brightness_7,
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
                                                  padding:
                                                      const EdgeInsets.all(8.0),
                                                  decoration: BoxDecoration(
                                                    color: Colors.black
                                                        .withOpacity(0.5),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            8.0), // 圆角
                                                  ),
                                                  child: Row(
                                                    children: <Widget>[
                                                      const Icon(
                                                          Icons.volume_down,
                                                          color: Colors.white),
                                                      Text(
                                                        ' ${(playerController.volume * 100).toInt()}%',
                                                        style: const TextStyle(
                                                          color: Colors.white,
                                                        ),
                                                      ),
                                                    ],
                                                  )),
                                            ],
                                          )
                                        : Container()),
                                // 弹幕面板
                                Positioned(
                                  top: 0,
                                  left: 0,
                                  right: 0,
                                  height: videoPageController.androidFullscreen
                                      ? MediaQuery.sizeOf(context).height *
                                          danmakuArea
                                      : (MediaQuery.sizeOf(context).width *
                                          9 /
                                          16 *
                                          danmakuArea),
                                  child: DanmakuScreen(
                                    key: _danmuKey,
                                    createdController: (DanmakuController e) {
                                      danmakuController = e;
                                      playerController.danmakuController = e;
                                      debugPrint('弹幕控制器创建成功');
                                    },
                                    option: DanmakuOption(
                                      hideTop: _hideTop,
                                      hideScroll: _hideScroll,
                                      hideBottom: _hideBottom,
                                      opacity: _opacity,
                                      fontSize: _fontSize,
                                      duration: _duration.toInt(),
                                      showStroke: _border,
                                      massiveMode: _massiveMode,
                                    ),
                                  ),
                                ),

                                // 自定义顶部组件
                                (playerController.showPositioned ||
                                        !playerController
                                            .mediaPlayer.state.playing)
                                    ? Positioned(
                                        top: 0,
                                        left: 0,
                                        right: 0,
                                        child: Row(
                                          children: [
                                            IconButton(
                                              color: Colors.white,
                                              icon:
                                                  const Icon(Icons.arrow_back),
                                              onPressed: () {
                                                onBackPressed(context);
                                              },
                                            ),
                                            // 拖动条
                                            const Expanded(
                                              child: dtb.DragToMoveArea(
                                                  child: SizedBox(height: 40)),
                                            ),
                                            TextButton(
                                              style: ButtonStyle(
                                                padding:
                                                    WidgetStateProperty.all(
                                                        EdgeInsets.zero),
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
                                                ),
                                              ),
                                            ),
                                            // 追番
                                            IconButton(
                                              icon: Icon(
                                                  isFavorite
                                                      ? Icons.favorite
                                                      : Icons.favorite_outline,
                                                  color: Colors.white),
                                              onPressed: () async {
                                                if (isFavorite) {
                                                  favoriteController
                                                      .deleteFavorite(
                                                          infoController
                                                              .bangumiItem);
                                                  SmartDialog.showToast(
                                                      '取消追番成功');
                                                } else {
                                                  favoriteController
                                                      .addFavorite(
                                                          infoController
                                                              .bangumiItem);
                                                  SmartDialog.showToast(
                                                      '自己追的番要好好看完哦');
                                                }
                                                setState(() {
                                                  isFavorite = !isFavorite;
                                                });
                                              },
                                            ),
                                          ],
                                        ),
                                      )
                                    : Container(),

                                // 自定义播放器底部组件
                                (playerController.showPositioned ||
                                        !playerController
                                            .mediaPlayer.state.playing)
                                    ? Positioned(
                                        bottom: 0,
                                        left: 0,
                                        right: 0,
                                        child: Row(
                                          children: [
                                            IconButton(
                                              color: Colors.white,
                                              icon: Icon(
                                                  playerController.playing
                                                      ? Icons.pause
                                                      : Icons.play_arrow),
                                              onPressed: () {
                                                if (playerController.playing) {
                                                  playerController.pause();
                                                } else {
                                                  playerController.play();
                                                }
                                              },
                                            ),
                                            // 更换选集
                                            (videoPageController
                                                        .androidFullscreen ==
                                                    true)
                                                ? IconButton(
                                                    color: Colors.white,
                                                    icon: const Icon(
                                                        Icons.skip_next),
                                                    onPressed: () {
                                                      if (videoPageController
                                                              .currentEspisode ==
                                                          videoPageController
                                                              .roadList[
                                                                  videoPageController
                                                                      .currentRoad]
                                                              .data
                                                              .length) {
                                                        SmartDialog.showToast(
                                                            '已经是最新一集',
                                                            displayType:
                                                                SmartToastType
                                                                    .last);
                                                        return;
                                                      }
                                                      SmartDialog.showToast(
                                                          '正在加载第 ${videoPageController.currentEspisode + 1} 话');
                                                      videoPageController.changeEpisode(
                                                          videoPageController
                                                                  .currentEspisode +
                                                              1,
                                                          currentRoad:
                                                              videoPageController
                                                                  .currentRoad);
                                                    },
                                                  )
                                                : Container(),
                                            Expanded(
                                              child: ProgressBar(
                                                timeLabelLocation:
                                                    TimeLabelLocation.none,
                                                progress: playerController
                                                    .currentPosition,
                                                buffered:
                                                    playerController.buffer,
                                                total:
                                                    playerController.duration,
                                                onSeek: (duration) {
                                                  playerController
                                                      .seek(duration);
                                                },
                                              ),
                                            ),
                                            ((Utils.isCompact()) &&
                                                    !videoPageController
                                                        .androidFullscreen)
                                                ? Container()
                                                : Container(
                                                    padding:
                                                        const EdgeInsets.only(
                                                            left: 10.0),
                                                    child: Text(
                                                      Utils.durationToString(
                                                              playerController
                                                                  .currentPosition) +
                                                          " / " +
                                                          Utils.durationToString(
                                                              playerController
                                                                  .duration),
                                                      style: TextStyle(
                                                        color: Colors.white,
                                                        fontSize:
                                                            !Utils.isCompact()
                                                                ? 16.0
                                                                : 12.0,
                                                      ),
                                                    ),
                                                  ),
                                            // 弹幕相关
                                            // (playerController.androidFullscreen ==
                                            //             true &&
                                            //         playerController.danmakuOn ==
                                            //             true)
                                            //     ? IconButton(
                                            //         color: Colors.white,
                                            //         icon:
                                            //             const Icon(Icons.notes),
                                            //         onPressed: () {
                                            //           if (playerController
                                            //                   .danDanmakus
                                            //                   .length ==
                                            //               0) {
                                            //             SmartDialog.showToast(
                                            //                 '当前剧集不支持弹幕发送的说',
                                            //                 displayType:
                                            //                     SmartToastType
                                            //                         .last);
                                            //             return;
                                            //           }
                                            //           showShootDanmakuSheet();
                                            //         },
                                            //       )
                                            //     : Container(),
                                            IconButton(
                                              color: Colors.white,
                                              icon: Icon(playerController
                                                      .danmakuOn
                                                  ? Icons.comment
                                                  : Icons.comments_disabled),
                                              onPressed: () {
                                                _handleDanmaku();
                                              },
                                            ),
                                            IconButton(
                                              color: Colors.white,
                                              icon: Icon(videoPageController
                                                      .androidFullscreen
                                                  ? Icons.fullscreen_exit
                                                  : Icons.fullscreen),
                                              onPressed: () {
                                                _handleFullscreen();
                                              },
                                            ),
                                          ],
                                        ),
                                      )
                                    : Container(),
                              ]),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                // SizedBox(child: Text("${videoController.androidFullscreen}")),
              ],
            );
          }),
        ),
      ),
    );
  }

  Widget get playerSurface {
    return Video(
      controller: playerController.videoController,
      controls: NoVideoControls,
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
    );
  }
}
