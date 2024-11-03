import 'dart:async';
import 'dart:io';
import 'package:kazumi/utils/logger.dart';
import 'package:kazumi/utils/remote.dart';
import 'package:kazumi/utils/utils.dart';
import 'package:kazumi/utils/webdav.dart';
import 'package:logger/logger.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import 'package:kazumi/pages/player/player_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:video_player/video_player.dart';
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
import 'package:kazumi/modules/danmaku/danmaku_episode_response.dart';
import 'package:kazumi/bean/appbar/drag_to_move_bar.dart' as dtb;
import 'package:kazumi/pages/settings/danmaku/danmaku_settings_window.dart';
import 'package:kazumi/utils/constans.dart';

class PlayerItem extends StatefulWidget {
  const PlayerItem(
      {super.key, required this.openMenu, required this.locateEpisode});

  final VoidCallback openMenu;
  final VoidCallback locateEpisode;

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
  final FavoriteController favoriteController =
      Modular.get<FavoriteController>();
  final FocusNode _focusNode = FocusNode();
  late DanmakuController danmakuController;
  late bool isFavorite;
  late bool webDavEnable;
  late bool haEnable;

  // 界面管理
  bool showPositioned = false;
  bool showPosition = false;
  bool showBrightness = false;
  bool showVolume = false;
  bool showPlaySpeed = false;
  bool brightnessSeeking = false;
  bool volumeSeeking = false;
  bool lockPanel = false;

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

  // 过渡动画
  late AnimationController _animationController;
  late Animation<Offset> _bottomOffsetAnimation;
  late Animation<Offset> _topOffsetAnimation;
  late Animation<Offset> _leftOffsetAnimation;

  Timer? hideTimer;
  Timer? playerTimer;
  Timer? mouseScrollerTimer;

  double lastPlayerSpeed = 1.0;
  List<double> playSpeedList = defaultPlaySpeedList;

  /// 处理 Android/iOS 应用后台或熄屏
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    try {
      if (playerController.mediaPlayer.value.isPlaying) {
        danmakuController.resume();
      }
    } catch (_) {}
  }

  void _handleTap() {
    if (!showPositioned) {
      _animationController.forward();
      if (hideTimer != null) {
        hideTimer!.cancel();
      }
      hideTimer = Timer(const Duration(seconds: 4), () {
        if (mounted) {
          setState(() {
            showPositioned = false;
          });
          _animationController.reverse();
        }
        hideTimer = null;
      });
    } else {
      _animationController.reverse();
      if (hideTimer != null) {
        hideTimer!.cancel();
      }
    }
    setState(() {
      showPositioned = !showPositioned;
    });
  }

  void _handleHove() {
    if (!showPositioned) {
      _animationController.forward();
    }
    setState(() {
      showPositioned = true;
    });
    if (hideTimer != null) {
      hideTimer!.cancel();
    }

    hideTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) {
        setState(() {
          showPositioned = false;
        });
        _animationController.reverse();
      }
      hideTimer = null;
    });
  }

  void _handleMouseScroller() {
    setState(() {
      showVolume = true;
    });
    if (mouseScrollerTimer != null) {
      mouseScrollerTimer!.cancel();
    }

    mouseScrollerTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          showVolume = false;
        });
      }
      mouseScrollerTimer = null;
    });
  }

  void showVideoInfo() async {
    String currentDemux = await Utils.getCurrentDemux();
    SmartDialog.show(
        useAnimation: false,
        builder: (context) {
          return AlertDialog(
            title: const Text('视频详情'),
            content: SelectableText.rich(
              TextSpan(
                children: [
                  TextSpan(
                      text: '规则: ${videoPageController.currentPlugin.name}\n'),
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
              TextButton(onPressed: SmartDialog.dismiss, child: Text('取消')),
            ],
          );
        });
  }

  getPlayerTimer() {
    return Timer.periodic(const Duration(seconds: 1), (timer) {
      playerController.playing = playerController.mediaPlayer.value.isPlaying;
      playerController.isBuffering =
          playerController.mediaPlayer.value.isBuffering;
      playerController.currentPosition =
          playerController.mediaPlayer.value.position;
      playerController.buffer =
          playerController.mediaPlayer.value.buffered.isEmpty
              ? Duration.zero
              : playerController.mediaPlayer.value.buffered[0].end;
      playerController.duration = playerController.mediaPlayer.value.duration;
      playerController.completed =
          playerController.mediaPlayer.value.isCompleted;
      // 弹幕相关
      if (playerController.currentPosition.inMicroseconds != 0 &&
          playerController.mediaPlayer.value.isPlaying == true &&
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
                      playerController.mediaPlayer.value.isPlaying &&
                      !playerController.mediaPlayer.value.isBuffering &&
                      playerController.danmakuOn
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
      // 音量相关
      if (!volumeSeeking) {
        FlutterVolumeController.getVolume().then((value) {
          playerController.volume = value ?? 0.0;
        });
      }
      // 亮度相关
      if (!Platform.isWindows &&
          !Platform.isMacOS &&
          !Platform.isLinux &&
          !brightnessSeeking) {
        ScreenBrightness().current.then((value) {
          playerController.brightness = value;
        });
      }
      // 历史记录相关
      if (playerController.mediaPlayer.value.isPlaying &&
          !videoPageController.loading) {
        historyController.updateHistory(
            videoPageController.currentEspisode,
            videoPageController.currentRoad,
            videoPageController.currentPlugin.name,
            infoController.bangumiItem,
            playerController.mediaPlayer.value.position,
            videoPageController.src,
            videoPageController.roadList[videoPageController.currentRoad]
                .identifier[videoPageController.currentEspisode - 1]);
      }
      // 自动播放下一集
      if (playerController.completed &&
          videoPageController.currentEspisode <
              videoPageController
                  .roadList[videoPageController.currentRoad].data.length &&
          !videoPageController.loading) {
        SmartDialog.showToast(
            '正在加载${videoPageController.roadList[videoPageController.currentRoad].identifier[videoPageController.currentEspisode]}');
        try {
          playerTimer!.cancel();
        } catch (_) {}
        videoPageController.changeEpisode(
            videoPageController.currentEspisode + 1,
            currentRoad: videoPageController.currentRoad);
      }
    });
  }

  void onBackPressed(BuildContext context) async {
    if (videoPageController.androidFullscreen) {
      widget.locateEpisode();
      setState(() {
        lockPanel = false;
      });
      try {
        await Utils.exitFullScreen();
        videoPageController.androidFullscreen = false;
        danmakuController.clear();
        return;
      } catch (e) {
        KazumiLogger().log(Level.error, '卸载播放器错误 ${e.toString()}');
      }
    }

    if (webDavEnable) {
      try {
        var webDav = WebDav();
        webDav.updateHistory();
      } catch (e) {
        SmartDialog.showToast('同步记录失败 ${e.toString()}');
        KazumiLogger().log(Level.error, '同步记录失败 ${e.toString()}');
      }
    }
    if (mounted) {
      Navigator.of(context).pop();
    }
    // Navigator.of(context).pop();
  }

  void _handleFullscreen() {
    if (videoPageController.androidFullscreen) {
      try {
        danmakuController.onClear();
      } catch (_) {}
      setState(() {
        lockPanel = false;
      });
      Utils.exitFullScreen();
      widget.locateEpisode();
    } else {
      Utils.enterFullScreen();
      videoPageController.showTabBody = false;
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
  }

  /// 发送弹幕 由于接口限制, 暂时未提交云端
  void showShootDanmakuSheet() {
    final TextEditingController textController = TextEditingController();
    bool isSending = false; // 追踪是否正在发送
    SmartDialog.show(
        useAnimation: false,
        builder: (context) {
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
                onPressed: () => SmartDialog.dismiss(),
                child: Text(
                  '取消',
                  style:
                      TextStyle(color: Theme.of(context).colorScheme.outline),
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
                            SmartDialog.showToast('弹幕内容为空');
                            return;
                          } else if (msg.length > 100) {
                            SmartDialog.showToast('弹幕内容过长');
                            return;
                          }
                          setState(() {
                            isSending = true; // 开始发送，更新状态
                          });
                          // Todo 接口方限制

                          setState(() {
                            isSending = false; // 发送结束，更新状态
                          });
                          SmartDialog.showToast('发送成功');
                          danmakuController.addDanmaku(
                              DanmakuContentItem(msg, selfSend: true));
                          SmartDialog.dismiss();
                        },
                  child: Text(isSending ? '发送中' : '发送'),
                );
              })
            ],
          );
        });
  }

  // 选择倍速
  void showSetSpeedSheet() {
    final double currentSpeed = playerController.playerSpeed;
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
                  for (final double i in playSpeedList) ...<Widget>[
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

  void showDanmakuSeachDialog(String keyword) async {
    SmartDialog.dismiss();
    SmartDialog.showLoading(msg: '弹幕检索中');
    DanmakuSearchResponse danmakuSearchResponse;
    DanmakuEpisodeResponse danmakuEpisodeResponse;
    try {
      danmakuSearchResponse =
          await DanmakuRequest.getDanmakuSearchResponse(keyword);
    } catch (e) {
      SmartDialog.dismiss();
      SmartDialog.showToast('检索弹幕失败 ${e.toString()}');
      return;
    }
    SmartDialog.dismiss();
    if (danmakuSearchResponse.animes.isEmpty) {
      SmartDialog.showToast('未找到匹配结果');
      return;
    }
    await SmartDialog.show(
        useAnimation: false,
        builder: (context) {
          return Dialog(
            child: ListView(
              shrinkWrap: true,
              children: danmakuSearchResponse.animes.map((danmakuInfo) {
                return ListTile(
                  title: Text(danmakuInfo.animeTitle),
                  onTap: () async {
                    SmartDialog.dismiss();
                    SmartDialog.showLoading(msg: '弹幕检索中');
                    try {
                      danmakuEpisodeResponse =
                          await DanmakuRequest.getDanDanEpisodesByBangumiID(
                              danmakuInfo.animeId);
                    } catch (e) {
                      SmartDialog.dismiss();
                      SmartDialog.showToast('检索弹幕失败 ${e.toString()}');
                      return;
                    }
                    SmartDialog.dismiss();
                    if (danmakuEpisodeResponse.episodes.isEmpty) {
                      SmartDialog.showToast('未找到匹配结果');
                      return;
                    }
                    SmartDialog.show(
                        useAnimation: false,
                        builder: (context) {
                          return Dialog(
                            child: ListView(
                              shrinkWrap: true,
                              children: danmakuEpisodeResponse.episodes
                                  .map((episode) {
                                return ListTile(
                                  title: Text(episode.episodeTitle),
                                  onTap: () {
                                    SmartDialog.dismiss();
                                    SmartDialog.showToast('弹幕切换中');
                                    playerController.getDanDanmakuByEpisodeID(
                                        episode.episodeId);
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
    SmartDialog.show(
      useAnimation: false,
      onDismiss: () {
        // workaround for foucus node.
        // input in textfield generated by flutter_smart_dialog will diable autofocus, which will cause the keyboard event lost.
        _focusNode.requestFocus();
      },
      builder: (context) {
        final TextEditingController searchTextController =
            TextEditingController();
        return AlertDialog(
          title: const Text('弹幕检索'),
          content: TextField(
            controller: searchTextController,
            decoration: const InputDecoration(
              hintText: '番剧名',
            ),
            onSubmitted: (keyword) {
              showDanmakuSeachDialog(keyword);
            },
          ),
          actions: [
            TextButton(
              onPressed: () {
                SmartDialog.dismiss();
                _focusNode.requestFocus();
              },
              child: Text(
                '取消',
                style: TextStyle(color: Theme.of(context).colorScheme.outline),
              ),
            ),
            TextButton(
              onPressed: () {
                showDanmakuSeachDialog(searchTextController.text);
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
    // workaround for #214
    if (Platform.isIOS) {
      FlutterVolumeController.setIOSAudioSessionCategory(
          category: AudioSessionCategory.playback);
    }
    WidgetsBinding.instance.addObserver(this);
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _topOffsetAnimation = Tween<Offset>(
      begin: const Offset(0.0, -1.0),
      end: const Offset(0.0, 0.0),
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    _bottomOffsetAnimation = Tween<Offset>(
      begin: const Offset(0.0, 1.0),
      end: const Offset(0.0, 0.0),
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    _leftOffsetAnimation = Tween<Offset>(
      begin: const Offset(1.0, 0.0),
      end: const Offset(0.0, 0.0),
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    webDavEnable = setting.get(SettingBoxKey.webDavEnable, defaultValue: false);
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
    haEnable = setting.get(SettingBoxKey.hAenable, defaultValue: true);
    playerTimer = getPlayerTimer();
    windowManager.addListener(this);
    if ((Platform.isMacOS || Platform.isIOS) &&
        setting.get(SettingBoxKey.hAenable, defaultValue: true)) {
      playSpeedList = defaultPlaySpeedList;
    } else {
      playSpeedList = defaultPlaySpeedList + extendPlaySpeedList;
    }
    _handleTap();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    windowManager.removeListener(this);
    if (playerTimer != null) {
      playerTimer!.cancel();
    }
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    isFavorite = favoriteController.isFavorite(infoController.bangumiItem);

    return PopScope(
      // key: _key,
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (didPop) {
          return;
        }
        onBackPressed(context);
      },
      child: Observer(builder: (context) {
        return ClipRect(
          child: Container(
            color: Colors.black,
            child: MouseRegion(
              cursor: (videoPageController.androidFullscreen && !showPositioned)
                  ? SystemMouseCursors.none
                  : SystemMouseCursors.basic,
              onHover: (_) {
                // workaround for android.
                // I don't konw why, but android tap event will trigger onHover event.
                if (Utils.isDesktop()) {
                  _handleHove();
                }
              },
              child: FocusTraversalGroup(
                child: FocusScope(
                  node: FocusScopeNode(),
                  child: Listener(
                    onPointerSignal: (pointerSignal) {
                      if (pointerSignal is PointerScrollEvent) {
                        _handleMouseScroller();
                        final scrollDelta = pointerSignal.scrollDelta;
                        final double volume =
                            playerController.volume - scrollDelta.dy / 6000;
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
                          _handleHove();
                          // 当空格键被按下时
                          if (event.logicalKey == LogicalKeyboardKey.space) {
                            try {
                              playerController.playOrPause();
                            } catch (e) {
                              KazumiLogger()
                                  .log(Level.error, '播放器内部错误 ${e.toString()}');
                            }
                          }
                          // 右方向键被按下
                          if (event.logicalKey ==
                              LogicalKeyboardKey.arrowRight) {
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
                              KazumiLogger()
                                  .log(Level.error, '播放器内部错误 ${e.toString()}');
                            }
                          }
                          // 左方向键被按下
                          if (event.logicalKey ==
                              LogicalKeyboardKey.arrowLeft) {
                            int targetPosition =
                                playerController.currentPosition.inSeconds - 10;
                            if (targetPosition < 0) {
                              targetPosition = 0;
                            }
                            try {
                              if (playerTimer != null) {
                                playerTimer!.cancel();
                              }
                              playerController.currentPosition =
                                  Duration(seconds: targetPosition);
                              playerController
                                  .seek(playerController.currentPosition);
                              playerTimer = getPlayerTimer();
                            } catch (e) {
                              KazumiLogger().log(Level.error, e.toString());
                            }
                          }
                          // Esc键被按下
                          if (event.logicalKey == LogicalKeyboardKey.escape) {
                            if (videoPageController.androidFullscreen) {
                              try {
                                danmakuController.onClear();
                              } catch (_) {}
                              Utils.exitFullScreen();
                              videoPageController.androidFullscreen =
                                  !videoPageController.androidFullscreen;
                            } else if (!Platform.isMacOS) {
                              windowManager.hide();
                            }
                          }
                          // F键被按下
                          if (event.logicalKey == LogicalKeyboardKey.keyF) {
                            _handleFullscreen();
                          }
                          // D键盘被按下
                          if (event.logicalKey == LogicalKeyboardKey.keyD) {
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
                        child: Stack(alignment: Alignment.center, children: [
                          Center(child: playerSurface),
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
                            onDoubleTap: () {
                              if (!showPositioned) {
                                _handleTap();
                              }
                              if (lockPanel) {
                                return;
                              }
                              if (playerController.playing) {
                                playerController.pause();
                              } else {
                                playerController.play();
                              }
                            },
                            onLongPressStart: (_) {
                              if (lockPanel) {
                                return;
                              }
                              setState(() {
                                showPlaySpeed = true;
                              });
                              lastPlayerSpeed = playerController.playerSpeed;
                              playerController.setPlaybackSpeed(2.0);
                            },
                            onLongPressEnd: (_) {
                              if (lockPanel) {
                                return;
                              }
                              setState(() {
                                showPlaySpeed = false;
                              });
                              playerController
                                  .setPlaybackSpeed(lastPlayerSpeed);
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
                              child: (Utils.isDesktop() || lockPanel)
                                  ? Container()
                                  : GestureDetector(onHorizontalDragUpdate:
                                      (DragUpdateDetails details) {
                                      setState(() {
                                        showPosition = true;
                                      });
                                      if (playerTimer != null) {
                                        playerTimer!.cancel();
                                      }
                                      playerController.pause();
                                      final double scale = 180000 /
                                          MediaQuery.sizeOf(context).width;
                                      playerController.currentPosition =
                                          Duration(
                                              milliseconds: playerController
                                                      .currentPosition
                                                      .inMilliseconds +
                                                  (details.delta.dx * scale)
                                                      .round());
                                    }, onHorizontalDragEnd:
                                      (DragEndDetails details) {
                                      playerController.play();
                                      playerController.seek(
                                          playerController.currentPosition);
                                      playerTimer = getPlayerTimer();
                                      setState(() {
                                        showPosition = false;
                                      });
                                    }, onVerticalDragUpdate:
                                      (DragUpdateDetails details) async {
                                      final double totalWidth =
                                          MediaQuery.sizeOf(context).width;
                                      final double totalHeight =
                                          MediaQuery.sizeOf(context).height;
                                      final double tapPosition =
                                          details.localPosition.dx;
                                      final double sectionWidth =
                                          totalWidth / 2;
                                      final double delta = details.delta.dy;

                                      /// 非全屏时禁用
                                      if (!videoPageController
                                          .androidFullscreen) {
                                        return;
                                      }
                                      if (tapPosition < sectionWidth) {
                                        // 左边区域
                                        brightnessSeeking = true;
                                        setState(() {
                                          showBrightness = true;
                                        });
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
                                        volumeSeeking = true;
                                        setState(() {
                                          showVolume = true;
                                        });
                                        final double level = (totalHeight) * 3;
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
                                      if (volumeSeeking) {
                                        volumeSeeking = false;
                                      }
                                      if (brightnessSeeking) {
                                        brightnessSeeking = false;
                                      }
                                      setState(() {
                                        showVolume = false;
                                        showBrightness = false;
                                      });
                                    })),
                          // 顶部进度条
                          Positioned(
                              top: 25,
                              child: showPosition
                                  ? Wrap(
                                      alignment: WrapAlignment.center,
                                      children: <Widget>[
                                        Container(
                                          padding: const EdgeInsets.all(8.0),
                                          decoration: BoxDecoration(
                                            color:
                                                Colors.black.withOpacity(0.5),
                                            borderRadius: BorderRadius.circular(
                                                8.0), // 圆角
                                          ),
                                          child: Text(
                                            playerController.currentPosition
                                                        .compareTo(
                                                            playerController
                                                                .mediaPlayer
                                                                .value
                                                                .position) >
                                                    0
                                                ? '快进 ${playerController.currentPosition.inSeconds - playerController.mediaPlayer.value.position.inSeconds} 秒'
                                                : '快退 ${playerController.mediaPlayer.value.position.inSeconds - playerController.currentPosition.inSeconds} 秒',
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
                              child: showPlaySpeed
                                  ? Wrap(
                                      alignment: WrapAlignment.center,
                                      children: <Widget>[
                                        Container(
                                          padding: const EdgeInsets.all(8.0),
                                          decoration: BoxDecoration(
                                            color:
                                                Colors.black.withOpacity(0.5),
                                            borderRadius: BorderRadius.circular(
                                                8.0), // 圆角
                                          ),
                                          child: const Row(
                                            children: <Widget>[
                                              Icon(Icons.fast_forward,
                                                  color: Colors.white),
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
                              child: showBrightness
                                  ? Wrap(
                                      alignment: WrapAlignment.center,
                                      children: <Widget>[
                                        Container(
                                            padding: const EdgeInsets.all(8.0),
                                            decoration: BoxDecoration(
                                              color:
                                                  Colors.black.withOpacity(0.5),
                                              borderRadius:
                                                  BorderRadius.circular(
                                                      8.0), // 圆角
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
                              child: showVolume
                                  ? Wrap(
                                      alignment: WrapAlignment.center,
                                      children: <Widget>[
                                        Container(
                                            padding: const EdgeInsets.all(8.0),
                                            decoration: BoxDecoration(
                                              color:
                                                  Colors.black.withOpacity(0.5),
                                              borderRadius:
                                                  BorderRadius.circular(
                                                      8.0), // 圆角
                                            ),
                                            child: Row(
                                              children: <Widget>[
                                                const Icon(Icons.volume_down,
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
                                ? MediaQuery.sizeOf(context).height
                                : (MediaQuery.sizeOf(context).width * 9 / 16),
                            child: DanmakuScreen(
                              key: _danmuKey,
                              createdController: (DanmakuController e) {
                                danmakuController = e;
                                playerController.danmakuController = e;
                                // debugPrint('弹幕控制器创建成功');
                              },
                              option: DanmakuOption(
                                hideTop: _hideTop,
                                hideScroll: _hideScroll,
                                hideBottom: _hideBottom,
                                area: danmakuArea,
                                opacity: _opacity,
                                fontSize: _fontSize,
                                duration: _duration.toInt(),
                                showStroke: _border,
                                massiveMode: _massiveMode,
                              ),
                            ),
                          ),

                          // 右侧锁定按钮
                          (Utils.isDesktop() ||
                                  !videoPageController.androidFullscreen)
                              ? Container()
                              : Positioned(
                                  right: 0,
                                  top: 0,
                                  bottom: 0,
                                  child: SlideTransition(
                                    position: _leftOffsetAnimation,
                                    child: IconButton(
                                      icon: Icon(
                                        lockPanel
                                            ? Icons.lock_outline
                                            : Icons.lock_open,
                                        color: Colors.white,
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          lockPanel = !lockPanel;
                                        });
                                      },
                                    ),
                                  ),
                                ),

                          // 自定义顶部组件
                          Positioned(
                            top: 0,
                            left: 0,
                            right: 0,
                            child: Visibility(
                              visible: !lockPanel,
                              child: SlideTransition(
                                position: _topOffsetAnimation,
                                child: Row(
                                  children: [
                                    IconButton(
                                      color: Colors.white,
                                      icon: const Icon(Icons.arrow_back),
                                      onPressed: () {
                                        onBackPressed(context);
                                      },
                                    ),
                                    (videoPageController.androidFullscreen)
                                        ? Text(
                                            ' ${videoPageController.title} [${videoPageController.roadList[videoPageController.currentRoad].identifier[videoPageController.currentEspisode - 1]}]',
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
                                      child: dtb.DragToMoveArea(
                                          child: SizedBox(height: 40)),
                                    ),
                                    TextButton(
                                      style: ButtonStyle(
                                        padding: WidgetStateProperty.all(
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
                                    IconButton(
                                      color: Colors.white,
                                      icon: const Icon(Icons.cast),
                                      onPressed: () {
                                        if (videoPageController
                                                .currentPlugin.referer ==
                                            '') {
                                          playerController.pause();
                                          RemotePlay().castVideo(context);
                                        } else {
                                          SmartDialog.showToast('暂不支持该播放源',
                                              displayType:
                                                  SmartToastType.onlyRefresh);
                                        }
                                      },
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
                                          favoriteController.deleteFavorite(
                                              infoController.bangumiItem);
                                          SmartDialog.showToast('取消追番成功');
                                        } else {
                                          favoriteController.addFavorite(
                                              infoController.bangumiItem);
                                          SmartDialog.showToast('自己追的番要好好看完哦');
                                        }
                                        setState(() {
                                          isFavorite = !isFavorite;
                                        });
                                      },
                                    ),
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
                                        ];
                                      },
                                      onSelected: (value) {
                                        if (value == 0) {
                                          SmartDialog.show(
                                              useAnimation: false,
                                              builder: (context) {
                                                return SizedBox(
                                                    height: 440,
                                                    child: DanmakuSettingsWindow(
                                                        danmakuController:
                                                            danmakuController));
                                              });
                                        }
                                        if (value == 1) {
                                          showDanmakuSwitch();
                                        }
                                        if (value == 2) {
                                          showVideoInfo();
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
                              visible: !lockPanel,
                              child: SlideTransition(
                                position: _bottomOffsetAnimation,
                                child: Row(
                                  children: [
                                    IconButton(
                                      color: Colors.white,
                                      icon: Icon(playerController.playing
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
                                    (videoPageController.androidFullscreen ||
                                            Utils.isTablet() ||
                                            Utils.isDesktop())
                                        ? IconButton(
                                            color: Colors.white,
                                            icon: const Icon(Icons.skip_next),
                                            onPressed: () {
                                              if (videoPageController.loading) {
                                                return;
                                              }
                                              if (videoPageController
                                                      .currentEspisode ==
                                                  videoPageController
                                                      .roadList[
                                                          videoPageController
                                                              .currentRoad]
                                                      .data
                                                      .length) {
                                                SmartDialog.showToast('已经是最新一集',
                                                    displayType:
                                                        SmartToastType.last);
                                                return;
                                              }
                                              SmartDialog.showToast(
                                                  '正在加载${videoPageController.roadList[videoPageController.currentRoad].identifier[videoPageController.currentEspisode]}');
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
                                        progress:
                                            playerController.currentPosition,
                                        buffered: playerController.buffer,
                                        total: playerController.duration,
                                        onSeek: (duration) {
                                          if (playerTimer != null) {
                                            playerTimer!.cancel();
                                          }
                                          playerController.currentPosition =
                                              duration;
                                          playerController.seek(duration);
                                          playerTimer =
                                              getPlayerTimer(); //Bug_time
                                        },
                                      ),
                                    ),
                                    ((Utils.isCompact()) &&
                                            !videoPageController
                                                .androidFullscreen)
                                        ? Container()
                                        : Container(
                                            padding: const EdgeInsets.only(
                                                left: 10.0),
                                            child: Text(
                                              "${Utils.durationToString(playerController.currentPosition)} / ${Utils.durationToString(playerController.duration)}",
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: !Utils.isCompact()
                                                    ? 16.0
                                                    : 12.0,
                                              ),
                                            ),
                                          ),
                                    // 弹幕相关
                                    (playerController.danmakuOn)
                                        ? IconButton(
                                            color: Colors.white,
                                            icon: const Icon(Icons.notes),
                                            onPressed: () {
                                              if (playerController
                                                  .danDanmakus.isEmpty) {
                                                SmartDialog.showToast(
                                                    '当前剧集不支持弹幕发送的说',
                                                    displayType:
                                                        SmartToastType.last);
                                                return;
                                              }
                                              showShootDanmakuSheet();
                                            },
                                          )
                                        : Container(),
                                    IconButton(
                                      color: Colors.white,
                                      icon: Icon(playerController.danmakuOn
                                          ? Icons.comment
                                          : Icons.comments_disabled),
                                      onPressed: () {
                                        _handleDanmaku();
                                      },
                                    ),
                                    (!videoPageController.androidFullscreen &&
                                            !Utils.isTablet() &&
                                            !Utils.isDesktop())
                                        ? Container()
                                        : IconButton(
                                            color: Colors.white,
                                            icon: Icon(
                                                videoPageController.showTabBody
                                                    ? Icons.menu_open
                                                    : Icons.menu_open_outlined),
                                            onPressed: () {
                                              videoPageController.showTabBody =
                                                  !videoPageController
                                                      .showTabBody;
                                              widget.openMenu();
                                            },
                                          ),
                                    IconButton(
                                      color: Colors.white,
                                      icon: Icon(
                                          videoPageController.androidFullscreen
                                              ? Icons.fullscreen_exit
                                              : Icons.fullscreen),
                                      onPressed: () {
                                        _handleFullscreen();
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ]),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        )
            // SizedBox(child: Text("${videoController.androidFullscreen}")),
            ;
      }),
    );
  }

  Widget get playerSurface {
    return AspectRatio(
        aspectRatio: playerController.mediaPlayer.value.aspectRatio,
        child: VideoPlayer(
          playerController.mediaPlayer,
        ));
  }
}
