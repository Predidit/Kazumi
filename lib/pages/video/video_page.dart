import 'dart:async';
import 'package:canvas_danmaku/models/danmaku_content_item.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/pages/player/player_controller.dart';
import 'package:kazumi/pages/video/video_controller.dart';
import 'package:kazumi/pages/history/history_controller.dart';
import 'package:kazumi/utils/logger.dart';
import 'package:kazumi/pages/player/player_item.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:hive_ce/hive.dart';
import 'package:kazumi/utils/storage.dart';
import 'package:kazumi/utils/utils.dart';
import 'package:kazumi/bean/appbar/drag_to_move_bar.dart' as dtb;
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:screen_brightness_platform_interface/screen_brightness_platform_interface.dart';
import 'package:scrollview_observer/scrollview_observer.dart';
import 'package:kazumi/pages/player/episode_comments_sheet.dart';
import 'package:window_manager/window_manager.dart';
import 'package:kazumi/bean/widget/embedded_native_control_area.dart';
import 'package:kazumi/pages/download/download_controller.dart';
import 'package:kazumi/pages/download/download_episode_sheet.dart';
import 'package:kazumi/modules/download/download_module.dart';
import 'package:kazumi/utils/timed_shutdown_service.dart';

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
  final DownloadController downloadController =
      Modular.get<DownloadController>();
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

  // disable animation.
  late final bool disableAnimations;

  // SyncPlayChatMessage
  late final StreamSubscription<SyncPlayChatMessage> _syncChatSubscription;

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

    playResume = setting.get(SettingBoxKey.playResume, defaultValue: true);
    disableAnimations =
        setting.get(SettingBoxKey.playerDisableAnimations, defaultValue: false);

    if (videoPageController.isOfflineMode) {
      // 离线模式：跳过 WebView 订阅，直接初始化播放器
      _initOfflineMode();
    } else {
      // 在线模式：设置 WebView 订阅
      _initOnlineMode();
    }

    _syncChatSubscription = playerController.syncPlayChatStream.listen((event) {
      final localUsername = playerController.syncplayController?.username ?? '';
      final String displayText = '${event.username}：${event.message}';

      // 只有在弹幕开启时渲染弹幕并确保是别人发送的弹幕
      if (playerController.danmakuOn &&
          event.username != localUsername &&
          event.fromRemote) {
        playerController.danmakuController.addDanmaku(
          DanmakuContentItem(
            displayText,
            color: Colors.orange,
            isColorful: true,
            type: DanmakuItemType.bottom,
            extra: DateTime.now().millisecondsSinceEpoch,
          ),
        );
      }
    });
  }

  void _initOfflineMode() {
    videoPageController.showTabBody = true;
    videoPageController.historyOffset = 0;
    currentRoad = videoPageController.currentRoad;

    // 检查历史记录（使用离线插件名）
    var progress = historyController.lastWatching(
        videoPageController.bangumiItem, videoPageController.offlinePluginName);
    if (progress != null && playResume) {
      // 在离线模式下，只恢复播放进度，不改变集数
      videoPageController.historyOffset = progress.progress.inSeconds;
    }

    // 初始化播放器
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (videoPageController.offlineVideoPath != null) {
        final params = PlaybackInitParams(
          videoUrl: videoPageController.offlineVideoPath!,
          offset: videoPageController.historyOffset,
          isLocalPlayback: true,
          bangumiId: videoPageController.bangumiItem.id,
          pluginName: videoPageController.offlinePluginName,
          episode: videoPageController.actualEpisodeNumber,
          httpHeaders: {},
          adBlockerEnabled: false,
          episodeTitle: videoPageController
              .roadList[videoPageController.currentRoad]
              .identifier[videoPageController.currentEpisode - 1],
          referer: '',
          currentRoad: videoPageController.currentRoad,
        );
        await playerController.init(params);
      }
    });
  }

  void _initOnlineMode() {
    videoPageController.currentEpisode = 1;
    videoPageController.currentRoad = 0;
    videoPageController.historyOffset = 0;
    videoPageController.showTabBody = true;

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

    // 使用 Provider 模式启动播放
    WidgetsBinding.instance.addPostFrameCallback((_) {
      changeEpisode(videoPageController.currentEpisode,
          currentRoad: videoPageController.currentRoad,
          offset: videoPageController.historyOffset);
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
      _syncChatSubscription.cancel();
    } catch (_) {}
    try {
      playerController.dispose();
    } catch (e) {
      KazumiLogger().e(
          'VideoPageController: failed to dispose playerController',
          error: e);
    }
    // 取消正在进行的视频源解析
    videoPageController.cancelVideoSourceResolution();
    if (!Utils.isDesktop()) {
      try {
        ScreenBrightnessPlatform.instance.resetApplicationScreenBrightness();
      } catch (_) {}
    }
    videoPageController.episodeInfo.reset();
    videoPageController.episodeCommentsList.clear();
    // 重置离线模式
    videoPageController.resetOfflineMode();
    Utils.unlockScreenRotation();
    tabController.dispose();
    // Cancel timed shutdown when leaving anime page
    TimedShutdownService().cancel();
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

  /// Callback for timed shutdown - pauses video when timer expires
  void pauseForTimedShutdown() {
    if (playerController.playing) {
      playerController.pause();
    }
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

    final destination = playerController.danmakuDestination;

    if (destination == DanmakuDestination.chatRoom) {
      if (playerController.syncplayRoom.isEmpty) {
        KazumiDialog.showToast(message: '你还没有加入一起看，无法发送聊天室弹幕');
        return;
      }

      final sender = playerController.syncplayController?.username ?? '我';
      final String displayText = '$sender：$msg';

      // 在播放器渲染自己发送的弹幕
      playerController.danmakuController.addDanmaku(
        DanmakuContentItem(
          displayText,
          color: Colors.orange,
          isColorful: true,
          type: DanmakuItemType.bottom,
          extra: DateTime.now().millisecondsSinceEpoch,
        ),
      );

      // 发送弹幕到聊天室
      playerController.sendSyncPlayChatMessage(msg);
    } else {
      // Todo 接口方限制

      playerController.danmakuController
          .addDanmaku(DanmakuContentItem(msg, selfSend: true));
    }
  }

  void showMobileDanmakuInput() {
    final TextEditingController textController = TextEditingController();
    showModalBottomSheet(
      shape: const BeveledRectangleBorder(),
      isScrollControlled: true,
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
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
                          showDanmakuDestinationPickerAndSend(msg);
                          textController.clear();
                          Navigator.pop(context);
                        },
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      final msg = textController.text;
                      Navigator.pop(context);
                      showDanmakuDestinationPickerAndSend(msg);
                      textController.clear();
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
      },
    );
  }

  void showDanmakuDestinationPickerAndSend(String msg) async {
    if (msg.trim().isEmpty) {
      KazumiDialog.showToast(message: '弹幕内容为空');
      return;
    }

    final DanmakuDestination? result =
        await showModalBottomSheet<DanmakuDestination>(
      context: context,
      shape: const BeveledRectangleBorder(),
      builder: (context) {
        return SafeArea(
          left: false,
          right: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: const Text('发送到聊天室'),
                onTap: () =>
                    Navigator.of(context).pop(DanmakuDestination.chatRoom),
              ),
              ListTile(
                title: const Text('发送到远程弹幕库'),
                onTap: () =>
                    Navigator.of(context).pop(DanmakuDestination.remoteDanmaku),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );

    if (result != null) {
      setState(() {});
      playerController.danmakuDestination = result;
      sendDanmaku(msg);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool islandScape =
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
            appBar: null,
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
                          flex: (islandScape) ? 1 : 0,
                          child: Container(
                            color: Colors.black,
                            height: (islandScape)
                                ? MediaQuery.sizeOf(context).height
                                : MediaQuery.sizeOf(context).width * 9 / 16,
                            width: MediaQuery.sizeOf(context).width,
                            child: playerBody,
                          ),
                        ),
                        // when not wideScreen, show tabBody on the bottom
                        if (!islandScape) Expanded(child: tabBody),
                      ],
                    ),

                    // when is wideScreen, show tabBody on the right side with SlideTransition or direct visibility
                    if (islandScape && videoPageController.showTabBody) ...[
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
                child: playerController.loading
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
                visible:
                    (videoPageController.loading || playerController.loading) &&
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
              Stack(
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
                              changeEpisode(videoPageController.currentEpisode,
                                  currentRoad: videoPageController.currentRoad);
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
              ),
            ],
          ),
        ),
        Positioned.fill(
          child: playerController.loading
              ? Container()
              : PlayerItem(
                  openMenu: openTabBodyAnimated,
                  locateEpisode: menuJumpToCurrentEpisode,
                  changeEpisode: changeEpisode,
                  onBackPressed: onBackPressed,
                  keyboardFocus: keyboardFocus,
                  sendDanmaku: sendDanmaku,
                  disableAnimations: disableAnimations,
                  showDanmakuDestinationPickerAndSend:
                      showDanmakuDestinationPickerAndSend,
                  pauseForTimedShutdown: pauseForTimedShutdown,
                ),
        ),
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

  Widget _buildDownloadStatusIcon(int episodeNumber, String episodePageUrl) {
    // 离线模式下不显示下载状态图标
    if (videoPageController.isOfflineMode) return const SizedBox.shrink();
    final bangumiId = videoPageController.bangumiItem.id;
    final pluginName = videoPageController.currentPlugin.name;
    final episode = downloadController.getEpisodeByUrl(
            bangumiId, pluginName, episodePageUrl) ??
        downloadController.getEpisode(bangumiId, pluginName, episodeNumber);
    if (episode == null) return const SizedBox.shrink();
    switch (episode.status) {
      case DownloadStatus.completed:
        return Icon(Icons.offline_pin,
            size: 16, color: Theme.of(context).colorScheme.primary);
      case DownloadStatus.downloading:
        return SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(
            value: episode.progressPercent,
            strokeWidth: 2,
          ),
        );
      case DownloadStatus.failed:
        return Icon(Icons.error_outline,
            size: 16, color: Theme.of(context).colorScheme.error);
      case DownloadStatus.paused:
        return Icon(Icons.pause_circle_outline,
            size: 16, color: Theme.of(context).colorScheme.outline);
      case DownloadStatus.pending:
      case DownloadStatus.resolving:
        return SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        );
      default:
        return const SizedBox.shrink();
    }
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
                  KazumiLogger()
                      .i('VideoPageController: video URL is $urlItem');
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
                          _buildDownloadStatusIcon(count0, urlItem),
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

    return Scaffold(
      floatingActionButton: videoPageController.isOfflineMode
          ? null
          : FloatingActionButton(
              child: const Icon(Icons.download_rounded),
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  builder: (context) => DownloadEpisodeSheet(road: currentRoad),
                );
              },
            ),
      body: Container(
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
      ),
    );
  }
}
