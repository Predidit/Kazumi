import 'dart:async';
import 'package:canvas_danmaku/models/danmaku_content_item.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/bean/appbar/sys_app_bar.dart';
import 'package:kazumi/pages/info/info_controller.dart';
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
import 'package:scrollview_observer/scrollview_observer.dart';
import 'package:kazumi/pages/player/episode_comments_sheet.dart';

class VideoPage extends StatefulWidget {
  const VideoPage({super.key});

  @override
  State<VideoPage> createState() => _VideoPageState();
}

class _VideoPageState extends State<VideoPage>
    with SingleTickerProviderStateMixin {
  Box setting = GStorage.setting;
  final InfoController infoController = Modular.get<InfoController>();
  final VideoPageController videoPageController =
      Modular.get<VideoPageController>();
  final PlayerController playerController = Modular.get<PlayerController>();
  final HistoryController historyController = Modular.get<HistoryController>();
  final WebviewItemController webviewItemController =
      Modular.get<WebviewItemController>();
  late bool playResume;
  bool showDebugLog = false;
  List<String> logLines = [];
  final FocusNode keyboardFocus = FocusNode();

  ScrollController scrollController = ScrollController();
  late GridObserverController observerController;
  late AnimationController animation;
  late Animation<Offset> _rightOffsetAnimation;

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

  @override
  void initState() {
    super.initState();
    observerController = GridObserverController(controller: scrollController);
    animation = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );
    _rightOffsetAnimation = Tween<Offset>(
      begin: const Offset(1.0, 0.0),
      end: const Offset(0.0, 0.0),
    ).animate(CurvedAnimation(
      parent: animation,
      curve: Curves.easeInOut,
    ));
    videoPageController.currentEpisode = 1;
    videoPageController.currentRoad = 0;
    videoPageController.historyOffset = 0;
    videoPageController.showTabBody = true;
    playResume = setting.get(SettingBoxKey.playResume, defaultValue: true);
    var progress = historyController.lastWatching(
        infoController.bangumiItem, videoPageController.currentPlugin.name);
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
      debugPrint('Kazumi Webview log: $event');
      if (event == 'clear') {
        clearLogs();
        return;
      }
      if (event == 'showDebug') {
        showDebugConsole();
        return;
      }
      setState(() {
        logLines.add(event);
      });
    });
  }

  @override
  void dispose() {
    observerController.controller?.dispose();
    animation.dispose();
    _initSubscription.cancel();
    _videoLoadedSubscription.cancel();
    _videoURLSubscription.cancel();
    _logSubscription.cancel();
    playerController.dispose();
    Utils.unlockScreenRotation();
    super.dispose();
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

  void clearLog() {
    setState(() {
      logLines.clear();
    });
  }

  Future<void> changeEpisode(int episode,
      {int currentRoad = 0, int offset = 0}) async {
    clearLogs();
    hideDebugConsole();
    videoPageController.loading = true;
    await playerController.stop();
    await videoPageController.changeEpisode(episode,
        currentRoad: currentRoad, offset: offset);
  }

  void menuJumpToCurrentEpisode() {
    Future.delayed(const Duration(milliseconds: 20), () {
      observerController.jumpTo(
          index: videoPageController.currentEpisode > 1
              ? videoPageController.currentEpisode - 1
              : videoPageController.currentEpisode);
    });
  }

  void openTabBodyAnimated() {
    if (videoPageController.showTabBody) {
      animation.forward();
      menuJumpToCurrentEpisode();
    }
  }

  void closeTabBodyAnimated() {
    animation.reverse();
    Future.delayed(const Duration(milliseconds: 100), () {
      videoPageController.showTabBody = false;
    });
    keyboardFocus.requestFocus();
  }

  void onBackPressed(BuildContext context) async {
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      openTabBodyAnimated();
    });
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        debugPrint("checkPoint: didPop: $didPop");
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
                : SysAppBar(
                    title: Text(videoPageController.title),
                  )),
            body: SafeArea(
              top: !videoPageController.isFullscreen,
              // set iOS and Android navigation bar to immersive
              bottom: false,
              left: !videoPageController.isFullscreen,
              right: !videoPageController.isFullscreen,
              child: (Utils.isDesktop()) ||
                      ((Utils.isTablet()) &&
                          MediaQuery.of(context).size.height <
                              MediaQuery.of(context).size.width)
                  ? Stack(
                      alignment: Alignment.centerRight,
                      children: [
                        Container(
                          color: Colors.black,
                          height: MediaQuery.of(context).size.height,
                          width: MediaQuery.of(context).size.width,
                          child: playerBody,
                        ),
                        if (videoPageController.showTabBody) ...[
                          GestureDetector(
                            onTap: () {
                              closeTabBodyAnimated();
                            },
                            child: Container(
                              color: Colors.black38,
                              width: double.infinity,
                              height: double.infinity,
                            ),
                          ),
                          SlideTransition(
                            position: _rightOffsetAnimation,
                            child: SizedBox(
                              height: MediaQuery.of(context).size.height,
                              width: MediaQuery.of(context).size.width * 1 / 3 >
                                      420
                                  ? 420
                                  : MediaQuery.of(context).size.width * 1 / 3,
                              child: tabBody,
                            ),
                          ),
                        ],
                      ],
                    )
                  : (!videoPageController.isFullscreen)
                      ? Column(
                          children: [
                            Container(
                              color: Colors.black,
                              height:
                                  MediaQuery.of(context).size.width * 9 / 16,
                              width: MediaQuery.of(context).size.width,
                              child: playerBody,
                            ),
                            Expanded(
                              child: tabBody,
                            ),
                          ],
                        )
                      : Stack(
                          alignment: Alignment.centerRight,
                          children: [
                            Container(
                                color: Colors.black,
                                height: MediaQuery.of(context).size.height,
                                width: MediaQuery.of(context).size.width,
                                child: playerBody),
                            if (videoPageController.showTabBody) ...[
                              GestureDetector(
                                onTap: () {
                                  closeTabBodyAnimated();
                                },
                                child: Container(
                                  color: Colors.black38,
                                  width: double.infinity,
                                  height: double.infinity,
                                ),
                              ),
                              SlideTransition(
                                position: _rightOffsetAnimation,
                                child: SizedBox(
                                  height: MediaQuery.of(context).size.height,
                                  width: (Utils.isTablet())
                                      ? MediaQuery.of(context).size.width / 2
                                      : MediaQuery.of(context).size.height,
                                  child: Container(
                                    color: Theme.of(context).canvasColor,
                                    child: GridViewObserver(
                                      controller: observerController,
                                      child: Column(
                                        children: [
                                          menuBar,
                                          menuBody,
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
            ),
          );
        });
      }),
    );
  }

  Widget get playerBody {
    return Stack(
      children: [
        // 日志组件
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
                      itemCount: logLines.length,
                      itemBuilder: (context, index) {
                        return Text(
                          logLines.isEmpty ? '' : logLines[index],
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
                          child: Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.arrow_back,
                                    color: Colors.white),
                                onPressed: () {
                                  if (videoPageController.isFullscreen ==
                                          true &&
                                      !Utils.isTablet()) {
                                    Utils.exitFullScreen();
                                    menuJumpToCurrentEpisode();
                                    videoPageController.isFullscreen = false;
                                    return;
                                  }
                                  if (videoPageController.isFullscreen ==
                                      true) {
                                    Utils.exitFullScreen();
                                    videoPageController.isFullscreen = false;
                                  }
                                  Navigator.of(context).pop();
                                },
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
                                  visible:
                                      Utils.isDesktop() || Utils.isTablet(),
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
                                      ))),
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
          SizedBox(
            height: 34,
            child: TextButton(
              style: ButtonStyle(
                padding: WidgetStateProperty.all(EdgeInsets.zero),
              ),
              onPressed: () {
                KazumiDialog.show(builder: (context) {
                  return AlertDialog(
                    title: const Text('播放列表'),
                    content: StatefulBuilder(builder:
                        (BuildContext context, StateSetter innerSetState) {
                      return Wrap(
                        spacing: 8,
                        runSpacing: Utils.isDesktop() ? 8 : 0,
                        children: [
                          for (int i = 1;
                              i <= videoPageController.roadList.length;
                              i++) ...<Widget>[
                            if (i == currentRoad + 1) ...<Widget>[
                              FilledButton(
                                onPressed: () {
                                  KazumiDialog.dismiss();
                                  setState(() {
                                    currentRoad = i - 1;
                                  });
                                },
                                child: Text('播放列表$i'),
                              ),
                            ] else ...[
                              FilledButton.tonal(
                                onPressed: () {
                                  KazumiDialog.dismiss();
                                  setState(() {
                                    currentRoad = i - 1;
                                  });
                                },
                                child: Text('播放列表$i'),
                              ),
                            ]
                          ]
                        ],
                      );
                    }),
                  );
                });
              },
              child: Text(
                '播放列表${currentRoad + 1} ',
                style: const TextStyle(fontSize: 13),
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
                              'assets/images/live.png',
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
            crossAxisCount:
                (Utils.isDesktop() && !Utils.isWideScreen()) ? 2 : 3,
            crossAxisSpacing: 10,
            mainAxisSpacing: 5,
            childAspectRatio: 1.7,
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
                if (!Utils.isDesktop() && !Utils.isTablet()) ...[
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
                  EpisodeCommentsSheet(episode: episodeNum),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
