import 'dart:async';
import 'package:canvas_danmaku/models/danmaku_content_item.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/bean/appbar/sys_app_bar.dart';
import 'package:kazumi/pages/player/player_controller.dart';
import 'package:kazumi/pages/video/video_controller.dart';
import 'package:kazumi/pages/webview/webview_item.dart';
import 'package:kazumi/pages/webview/webview_controller.dart';
import 'package:kazumi/pages/history/history_controller.dart';
import 'package:logger/logger.dart';
import 'package:kazumi/utils/logger.dart';
import 'package:kazumi/pages/player/player_item.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:hive/hive.dart';
import 'package:kazumi/utils/storage.dart';
import 'package:kazumi/utils/utils.dart';
import 'package:kazumi/bean/appbar/drag_to_move_bar.dart' as dtb;
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:screen_brightness_platform_interface/screen_brightness_platform_interface.dart';
import 'package:scrollview_observer/scrollview_observer.dart';
import 'package:kazumi/pages/player/episode_comments_sheet.dart';
import 'package:window_manager/window_manager.dart';
import 'package:kazumi/bean/widget/embedded_native_control_area.dart';

class VideoPage extends StatefulWidget {
  const VideoPage({super.key});

  @override
  State<VideoPage> createState() => _VideoPageState();
}

class _VideoPageState extends State<VideoPage>
    with TickerProviderStateMixin, WindowListener {
  Box setting = GStorage.setting;
  final VideoPageController videoPageController =
      Modular.get<VideoPageController>();
  final PlayerController playerController = Modular.get<PlayerController>();
  final HistoryController historyController = Modular.get<HistoryController>();
  final WebviewItemController webviewItemController =
      Modular.get<WebviewItemController>();
  late bool playResume;
  bool showDebugLog = false;
  List<String> webviewLogLines = [];
  final FocusNode keyboardFocus = FocusNode();

  ScrollController scrollController = ScrollController();
  late GridObserverController observerController;
  late AnimationController animation;
  late Animation<Offset> _rightOffsetAnimation;
  late Animation<double> _maskOpacityAnimation;
  late TabController tabController;

  // 当前播放列表
  late int currentRoad;

  // webview init events listener
  late final StreamSubscription<bool> _initSubscription;

  // webview logs events listener
  late final StreamSubscription<String> _logSubscription;

  // webview video loaded events listener
  late final StreamSubscription<bool> _videoLoadedSubscription;

  // webview video source events listener
  // The first parameter is the video source URL and the second parameter is the video offset (start position)
  late final StreamSubscription<(String, int)> _videoURLSubscription;

  // disable animation.
  late final bool disableAnimations;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    // Check fullscreen when enter video page
    // in case user use system controls to enter fullscreen outside video page
    videoPageController.isDesktopFullscreen();
    tabController = TabController(length: 2, vsync: this);
    observerController = GridObserverController(controller: scrollController);
    animation = AnimationController(
      duration: const Duration(milliseconds: 120),
      vsync: this,
    );
    _rightOffsetAnimation = Tween<Offset>(
      begin: const Offset(1.0, 0.0),
      end: const Offset(0.0, 0.0),
    ).animate(CurvedAnimation(
      parent: animation,
      curve: Curves.easeOut,
    ));
    _maskOpacityAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: animation,
      curve: Curves.easeIn,
    ));
    videoPageController.currentEpisode = 1;
    videoPageController.currentRoad = 0;
    videoPageController.historyOffset = 0;
    videoPageController.showTabBody = true;
    playResume = setting.get(SettingBoxKey.playResume, defaultValue: true);
    disableAnimations =
        setting.get(SettingBoxKey.playerDisableAnimations, defaultValue: false);
    var progress = historyController.lastWatching(
        videoPageController.bangumiItem,
        videoPageController.currentPlugin.name);
    if (progress != null) {
      if (videoPageController.roadList.length > progress.road) {
        if (videoPageController.roadList[progress.road].data.length >=
            progress.episode) {
          videoPageController.currentEpisode = progress.episode;
          videoPageController.currentRoad = progress.road;
          if (playResume) {
            videoPageController.historyOffset = progress.progress.inSeconds;
          }
        }
      }
    }
    currentRoad = videoPageController.currentRoad;

    // webview events listener
    _initSubscription = webviewItemController.onInitialized.listen((event) {
      if (event) {
        changeEpisode(videoPageController.currentEpisode,
            currentRoad: videoPageController.currentRoad,
            offset: videoPageController.historyOffset);
      }
    });
    _videoLoadedSubscription =
        webviewItemController.onVideoLoading.listen((event) {
      videoPageController.loading = event;
    });
    _videoURLSubscription =
        webviewItemController.onVideoURLParser.listen((event) {
      final (mediaUrl, offset) = event;
      playerController.init(mediaUrl, offset: offset);
    });
    _logSubscription = webviewItemController.onLog.listen((event) {
      debugPrint('[kazumi webview parser]: $event');
      if (event == 'clear') {
        clearWebviewLog();
        return;
      }
      if (event == 'showDebug') {
        showDebugConsole();
        return;
      }
      setState(() {
        webviewLogLines.add(event);
      });
    });
  }

  @override
  void dispose() {
    try {
      windowManager.removeListener(this);
    } catch (_) {}
    try {
      observerController.controller?.dispose();
    } catch (_) {}
    try {
      animation.dispose();
    } catch (_) {}
    try {
      _initSubscription.cancel();
    } catch (_) {}
    try {
      _videoLoadedSubscription.cancel();
    } catch (_) {}
    try {
      _videoURLSubscription.cancel();
    } catch (_) {}
    try {
      _logSubscription.cancel();
    } catch (_) {}
    try {
      playerController.dispose();
    } catch (e) {
      KazumiLogger().log(Level.error, '播放器释放失败: $e');
    }
    if (!Utils.isDesktop()) {
      try {
        ScreenBrightnessPlatform.instance.resetApplicationScreenBrightness();
      } catch (_) {}
    }
    videoPageController.episodeInfo.reset();
    videoPageController.episodeCommentsList.clear();
    Utils.unlockScreenRotation();
    tabController.dispose();
    super.dispose();
  }

  // Handle fullscreen change invoked by system controls
  @override
  void onWindowEnterFullScreen() {
    videoPageController.handleOnEnterFullScreen();
  }

  @override
  void onWindowLeaveFullScreen() {
    videoPageController.handleOnExitFullScreen();
  }

  void showDebugConsole() {
    setState(() {
      showDebugLog = true;
    });
  }

  void hideDebugConsole() {
    setState(() {
      showDebugLog = false;
    });
  }

  void switchDebugConsole() {
    setState(() {
      showDebugLog = !showDebugLog;
    });
  }

  void clearWebviewLog() {
    setState(() {
      webviewLogLines.clear();
    });
  }

  Future<void> changeEpisode(int episode,
      {int currentRoad = 0, int offset = 0}) async {
    clearWebviewLog();
    hideDebugConsole();
    videoPageController.loading = true;
    videoPageController.episodeInfo.reset();
    videoPageController.episodeCommentsList.clear();
    await playerController.stop();
    await videoPageController.changeEpisode(episode,
        currentRoad: currentRoad, offset: offset);
  }

  void menuJumpToCurrentEpisode() {
    Future.delayed(const Duration(milliseconds: 20), () async {
      await observerController.jumpTo(
          index: videoPageController.currentEpisode > 1
              ? videoPageController.currentEpisode - 1
              : videoPageController.currentEpisode);
    });
  }

  void openTabBodyAnimated() {
    if (videoPageController.showTabBody) {
      if (!disableAnimations) {
        animation.forward();
      }
      menuJumpToCurrentEpisode();
    }
  }

  void closeTabBodyAnimated() {
    if (!disableAnimations) {
      animation.reverse();
      Future.delayed(const Duration(milliseconds: 120), () {
        videoPageController.showTabBody = false;
      });
    } else {
      videoPageController.showTabBody = false;
    }
    keyboardFocus.requestFocus();
  }

  void onBackPressed(BuildContext context) async {
    if (KazumiDialog.observer.hasKazumiDialog) {
      KazumiDialog.dismiss();
      return;
    }
    if (videoPageController.isPip) {
      Utils.exitDesktopPIPWindow();
      videoPageController.isPip = false;
      return;
    }
    if (videoPageController.isFullscreen && !Utils.isTablet()) {
      menuJumpToCurrentEpisode();
      await Utils.exitFullScreen();
      videoPageController.showTabBody = false;
      videoPageController.isFullscreen = false;
      return;
    }
    if (videoPageController.isFullscreen) {
      Utils.exitFullScreen();
      videoPageController.isFullscreen = false;
    }
    Navigator.of(context).pop();
  }

  /// 发送弹幕 由于接口限制, 暂时未提交云端
  void sendDanmaku(String msg) async {
    keyboardFocus.requestFocus();
    if (playerController.danDanmakus.isEmpty) {
      KazumiDialog.showToast(
        message: '当前剧集不支持弹幕发送的说',
      );
      return;
    }
    if (msg.isEmpty) {
      KazumiDialog.showToast(message: '弹幕内容为空');
      return;
    } else if (msg.length > 100) {
      KazumiDialog.showToast(message: '弹幕内容过长');
      return;
    }
    // Todo 接口方限制

    playerController.danmakuController
        .addDanmaku(DanmakuContentItem(msg, selfSend: true));
  }

  void showMobileDanmakuInput() {
    final TextEditingController textController = TextEditingController();
    showModalBottomSheet(
      shape: const BeveledRectangleBorder(),
      isScrollControlled: true,
      context: context,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 8,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Expanded(
                child: Container(
                  constraints: const BoxConstraints(maxHeight: 34),
                  child: TextField(
                    style: const TextStyle(fontSize: 15),
                    controller: textController,
                    autofocus: true,
                    textAlignVertical: TextAlignVertical.center,
                    decoration: const InputDecoration(
                      filled: true,
                      floatingLabelBehavior: FloatingLabelBehavior.never,
                      hintText: '发个友善的弹幕见证当下',
                      hintStyle: TextStyle(fontSize: 14),
                      alignLabelWithHint: true,
                      contentPadding:
                          EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                      border: OutlineInputBorder(
                        borderSide: BorderSide.none,
                        borderRadius: BorderRadius.all(Radius.circular(20)),
                      ),
                    ),
                    onSubmitted: (msg) {
                      sendDanmaku(msg);
                      textController.clear();
                      Navigator.pop(context);
                    },
                  ),
                ),
              ),
              IconButton(
                onPressed: () {
                  sendDanmaku(textController.text);
                  textController.clear();
                  Navigator.pop(context);
                },
                icon: Icon(
                  Icons.send_rounded,
                  color: Theme.of(context).colorScheme.primary,
                ),
              )
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isWideScreen =
        MediaQuery.sizeOf(context).width > MediaQuery.sizeOf(context).height;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      openTabBodyAnimated();
    });
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (didPop) {
          return;
        }
        onBackPressed(context);
      },
      child: OrientationBuilder(builder: (context, orientation) {
        if (!Utils.isDesktop()) {
          if (orientation == Orientation.landscape &&
              !videoPageController.isFullscreen) {
            videoPageController.enterFullScreen();
          } else if (orientation == Orientation.portrait &&
              videoPageController.isFullscreen) {
            videoPageController.exitFullScreen();
            menuJumpToCurrentEpisode();
            videoPageController.showTabBody = true;
          }
        }
        return Observer(builder: (context) {
          return Scaffold(
            appBar: ((videoPageController.currentPlugin.useNativePlayer ||
                    videoPageController.isFullscreen)
                ? null
                : SysAppBar(title: Text(videoPageController.title))),
            body: SafeArea(
                top: !videoPageController.isFullscreen,
                // set iOS and Android navigation bar to immersive
                bottom: false,
                left: !videoPageController.isFullscreen,
                right: !videoPageController.isFullscreen,
                child: Stack(
                  alignment: Alignment.centerRight,
                  children: [
                    Column(
                      children: [
                        Flexible(
                          // make it unflexible when not wideScreen.
                          flex: (isWideScreen) ? 1 : 0,
                          child: Container(
                            color: Colors.black,
                            height: (isWideScreen)
                                ? MediaQuery.sizeOf(context).height
                                : MediaQuery.sizeOf(context).width * 9 / 16,
                            width: MediaQuery.sizeOf(context).width,
                            child: playerBody,
                          ),
                        ),
                        // when not wideScreen, show tabBody on the bottom
                        if (!isWideScreen) Expanded(child: tabBody),
                      ],
                    ),

                    // when is wideScreen, show tabBody on the right side with SlideTransition or direct visibility
                    if (isWideScreen && videoPageController.showTabBody) ...[
                      if (disableAnimations) ...[
                        sideTabMask,
                        sideTabBody,
                      ] else ...[
                        FadeTransition(
                          opacity: _maskOpacityAnimation,
                          child: sideTabMask,
                        ),
                        SlideTransition(
                          position: _rightOffsetAnimation,
                          child: sideTabBody,
                        ),
                      ],
                    ],
                  ],
                )),
          );
        });
      }),
    );
  }

  Widget get sideTabBody {
    return SizedBox(
      height: MediaQuery.sizeOf(context).height,
      width: (!Utils.isDesktop() && !Utils.isTablet())
          ? MediaQuery.sizeOf(context).height
          : (MediaQuery.sizeOf(context).width / 3 > 420
              ? 420
              : MediaQuery.sizeOf(context).width / 3),
      child: Container(
        color: Theme.of(context).canvasColor,
        child: GridViewObserver(
          controller: observerController,
          child: (Utils.isDesktop() || Utils.isTablet())
              ? tabBody
              : Column(
                  children: [
                    menuBar,
                    menuBody,
                  ],
                ),
        ),
      ),
    );
  }

  Widget get sideTabMask {
    return GestureDetector(
      onTap: closeTabBodyAnimated,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [
              Colors.black.withValues(alpha: 0.5),
              Colors.transparent,
            ],
          ),
        ),
        width: double.infinity,
        height: double.infinity,
      ),
    );
  }

  Widget get playerBody {
    return Stack(
      children: [
        // webview log component (not player log, used for video parsing)
        Positioned.fill(
          child: Stack(
            children: [
              Positioned.fill(
                child: (videoPageController.currentPlugin.useNativePlayer &&
                        playerController.loading)
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(
                                color: Theme.of(context)
                                    .colorScheme
                                    .tertiaryContainer),
                            const SizedBox(height: 10),
                            const Text('视频资源解析成功, 播放器加载中',
                                style: TextStyle(
                                  color: Colors.white,
                                )),
                          ],
                        ),
                      )
                    : Container(),
              ),
              Visibility(
                visible: videoPageController.loading,
                child: Container(
                  color: Colors.black,
                  child: Align(
                      alignment: Alignment.center,
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(
                                color: Theme.of(context)
                                    .colorScheme
                                    .tertiaryContainer),
                            const SizedBox(height: 10),
                            const Text('视频资源解析中',
                                style: TextStyle(
                                  color: Colors.white,
                                )),
                          ],
                        ),
                      )),
                ),
              ),
              Visibility(
                visible: (videoPageController.loading ||
                        (videoPageController.currentPlugin.useNativePlayer &&
                            playerController.loading)) &&
                    showDebugLog,
                child: Container(
                  color: Colors.black,
                  child: Align(
                    alignment: Alignment.center,
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: webviewLogLines.length,
                      itemBuilder: (context, index) {
                        return Text(
                          webviewLogLines.isEmpty ? '' : webviewLogLines[index],
                          style: const TextStyle(
                            color: Colors.white,
                          ),
                          textAlign: TextAlign.center,
                        );
                      },
                    ),
                  ),
                ),
              ),
              ((videoPageController.currentPlugin.useNativePlayer ||
                      videoPageController.isFullscreen))
                  ? Stack(
                      children: [
                        Positioned(
                          top: 0,
                          left: 0,
                          right: 0,
                          child: EmbeddedNativeControlArea(
                            requireOffset: !videoPageController.isFullscreen,
                            child: Row(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.arrow_back,
                                      color: Colors.white),
                                  onPressed: () => onBackPressed(context),
                                ),
                                const Expanded(
                                    child: dtb.DragToMoveArea(
                                        child: SizedBox(height: 40))),
                                IconButton(
                                  icon: const Icon(Icons.refresh_outlined,
                                      color: Colors.white),
                                  onPressed: () {
                                    changeEpisode(
                                        videoPageController.currentEpisode,
                                        currentRoad:
                                            videoPageController.currentRoad);
                                  },
                                ),
                                Visibility(
                                  visible: MediaQuery.sizeOf(context).width >
                                      MediaQuery.sizeOf(context).height,
                                  child: IconButton(
                                    onPressed: () {
                                      videoPageController.showTabBody =
                                          !videoPageController.showTabBody;
                                      openTabBodyAnimated();
                                    },
                                    icon: Icon(
                                      videoPageController.showTabBody
                                          ? Icons.menu_open
                                          : Icons.menu_open_outlined,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: Icon(
                                      showDebugLog
                                          ? Icons.bug_report
                                          : Icons.bug_report_outlined,
                                      color: Colors.white),
                                  onPressed: () {
                                    switchDebugConsole();
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    )
                  : Container(),
            ],
          ),
        ),
        Positioned.fill(
          child: (!videoPageController.currentPlugin.useNativePlayer ||
                  playerController.loading)
              ? Container()
              : PlayerItem(
                  openMenu: openTabBodyAnimated,
                  locateEpisode: menuJumpToCurrentEpisode,
                  changeEpisode: changeEpisode,
                  onBackPressed: onBackPressed,
                  keyboardFocus: keyboardFocus,
                  sendDanmaku: sendDanmaku,
                  disableAnimations: disableAnimations,
                ),
        ),

        /// workaround for webview_windows
        /// The webview_windows component cannot be removed from the widget tree; otherwise, it can never be reinitialized.
        Positioned(
            child: SizedBox(
                height: (videoPageController.loading ||
                        videoPageController.currentPlugin.useNativePlayer)
                    ? 0
                    : null,
                child: const WebviewItem()))
      ],
    );
  }

  Widget get menuBar {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(' 合集 '),
          Expanded(
            child: Text(
              videoPageController.title,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
          ),
          const SizedBox(width: 10),
          MenuAnchor(
            consumeOutsideTap: true,
            builder: (_, MenuController controller, __) {
              return SizedBox(
                height: 34,
                child: TextButton(
                  style: ButtonStyle(
                    padding: WidgetStateProperty.all(EdgeInsets.zero),
                  ),
                  onPressed: () {
                    if (controller.isOpen) {
                      controller.close();
                    } else {
                      controller.open();
                    }
                  },
                  child: Text(
                    '播放列表${currentRoad + 1} ',
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              );
            },
            menuChildren: List<MenuItemButton>.generate(
              videoPageController.roadList.length,
              (int i) => MenuItemButton(
                onPressed: () {
                  setState(() {
                    currentRoad = i;
                  });
                },
                child: Container(
                  height: 48,
                  constraints: BoxConstraints(minWidth: 112),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '播放列表${i + 1}',
                      style: TextStyle(
                        color: i == currentRoad
                            ? Theme.of(context).colorScheme.primary
                            : null,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget get menuBody {
    var cardList = <Widget>[];
    for (var road in videoPageController.roadList) {
      if (road.name == '播放列表${currentRoad + 1}') {
        int count = 1;
        for (var urlItem in road.data) {
          int count0 = count;
          cardList.add(Container(
            margin: const EdgeInsets.only(bottom: 4), // 改为bottom间距
            child: Material(
              color: Theme.of(context).colorScheme.onInverseSurface,
              borderRadius: BorderRadius.circular(6),
              clipBehavior: Clip.hardEdge,
              child: InkWell(
                onTap: () async {
                  if (count0 == videoPageController.currentEpisode &&
                      videoPageController.currentRoad == currentRoad) {
                    return;
                  }
                  KazumiLogger().log(Level.info, '视频链接为 $urlItem');
                  closeTabBodyAnimated();
                  changeEpisode(count0, currentRoad: currentRoad);
                },
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: [
                          if (count0 == (videoPageController.currentEpisode) &&
                              currentRoad ==
                                  videoPageController.currentRoad) ...<Widget>[
                            Image.asset(
                              'assets/images/playing.gif',
                              color: Theme.of(context).colorScheme.primary,
                              height: 12,
                            ),
                            const SizedBox(width: 6)
                          ],
                          Expanded(
                              child: Text(
                            road.identifier[count0 - 1],
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 13,
                                color: (count0 ==
                                            videoPageController
                                                .currentEpisode &&
                                        currentRoad ==
                                            videoPageController.currentRoad)
                                    ? Theme.of(context).colorScheme.primary
                                    : Theme.of(context).colorScheme.onSurface),
                          )),
                          const SizedBox(width: 2),
                        ],
                      ),
                      const SizedBox(height: 3),
                    ],
                  ),
                ),
              ),
            ),
          ));
          count++;
        }
      }
    }
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.only(top: 0, right: 8, left: 8),
        child: GridView.builder(
          scrollDirection: Axis.vertical,
          controller: scrollController,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 10,
            mainAxisSpacing: 5,
            mainAxisExtent: 70,
          ),
          itemCount: cardList.length,
          itemBuilder: (context, index) {
            return cardList[index];
          },
        ),
      ),
    );
  }

  Widget get tabBody {
    int episodeNum = 0;
    episodeNum = Utils.extractEpisodeNumber(videoPageController
        .roadList[videoPageController.currentRoad]
        .identifier[videoPageController.currentEpisode - 1]);
    if (episodeNum == 0 ||
        episodeNum >
            videoPageController
                .roadList[videoPageController.currentRoad].identifier.length) {
      episodeNum = videoPageController.currentEpisode;
    }

    return Container(
      color: Theme.of(context).canvasColor,
      child: DefaultTabController(
        length: 2,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                TabBar(
                  controller: tabController,
                  dividerHeight: 0,
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  labelPadding:
                      const EdgeInsetsDirectional.only(start: 30, end: 30),
                  onTap: (index) {
                    if (index == 0) {
                      menuJumpToCurrentEpisode();
                    }
                  },
                  tabs: const [
                    Tab(text: '选集'),
                    Tab(text: '评论'),
                  ],
                ),
                if (MediaQuery.sizeOf(context).width <=
                    MediaQuery.sizeOf(context).height) ...[
                  const Spacer(),
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(25),
                      border: Border.all(
                        color: playerController.danmakuOn
                            ? Theme.of(context).hintColor
                            : Theme.of(context).disabledColor,
                        width: 0.5,
                      ),
                    ),
                    width: 120,
                    height: 31,
                    child: GestureDetector(
                      onTap: () {
                        if (playerController.danmakuOn &&
                            !videoPageController.loading) {
                          showMobileDanmakuInput();
                        } else if (videoPageController.loading) {
                          KazumiDialog.showToast(message: '请等待视频加载完成');
                        } else {
                          KazumiDialog.showToast(message: '请先打开弹幕');
                        }
                      },
                      child: Row(
                        children: [
                          Text(
                            playerController.danmakuOn
                                ? '  点我发弹幕  '
                                : '  已关闭弹幕  ',
                            softWrap: false,
                            overflow: TextOverflow.clip,
                            style: TextStyle(
                              color: playerController.danmakuOn
                                  ? Theme.of(context).hintColor
                                  : Theme.of(context).disabledColor,
                            ),
                          ),
                          Icon(
                            Icons.send_rounded,
                            size: 20,
                            color: playerController.danmakuOn
                                ? Theme.of(context).hintColor
                                : Theme.of(context).disabledColor,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(width: 8),
              ],
            ),
            Divider(height: Utils.isDesktop() ? 0.5 : 0.2),
            Expanded(
              child: TabBarView(
                controller: tabController,
                children: [
                  GridViewObserver(
                    controller: observerController,
                    child: Column(
                      children: [
                        menuBar,
                        menuBody,
                      ],
                    ),
                  ),
                  EpisodeInfo(
                    episode: episodeNum,
                    child: EpisodeCommentsSheet(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
