import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/bean/appbar/sys_app_bar.dart';
import 'package:kazumi/pages/info/info_controller.dart';
import 'package:kazumi/pages/player/player_controller.dart';
import 'package:kazumi/pages/video/video_controller.dart';
import 'package:kazumi/pages/webview/webview_item.dart';
import 'package:kazumi/pages/history/history_controller.dart';
import 'package:logger/logger.dart';
import 'package:kazumi/utils/logger.dart';
import 'package:kazumi/pages/player/player_item.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:hive/hive.dart';
import 'package:kazumi/utils/storage.dart';
import 'package:kazumi/utils/utils.dart';
import 'package:flutter/services.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:kazumi/bean/appbar/drag_to_move_bar.dart' as dtb;
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';

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
  late bool playResume;

  // 当前播放列表
  late int currentRoad;

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
    videoPageController.currentEspisode = 1;
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
          videoPageController.currentEspisode = progress.episode;
          videoPageController.currentRoad = progress.road;
          if (playResume) {
            videoPageController.historyOffset = progress.progress.inSeconds;
          }
        }
      }
    }
    currentRoad = videoPageController.currentRoad;
  }

  @override
  void dispose() {
    try {
      playerController.mediaPlayer.dispose();
    } catch (_) {}
    WakelockPlus.disable();
    Utils.unlockScreenRotation();
    super.dispose();
  }

  void showDebugConsole() {
    videoPageController.showDebugLog = !videoPageController.showDebugLog;
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {});
    return OrientationBuilder(builder: (context, orientation) {
      if (!Utils.isTablet() && !Utils.isDesktop()) {
        if (orientation == Orientation.landscape &&
            !videoPageController.androidFullscreen) {
          Utils.enterFullScreen(lockOrientation: false);
          videoPageController.androidFullscreen = true;
        } else if (orientation == Orientation.portrait &&
            videoPageController.androidFullscreen) {
          Utils.exitFullScreen(lockOrientation: false);
          videoPageController.androidFullscreen = false;
        }
      }
      return Observer(builder: (context) {
        return Scaffold(
          appBar: ((videoPageController.currentPlugin.useNativePlayer ||
                  videoPageController.androidFullscreen)
              ? null
              : SysAppBar(
                  title: Text(videoPageController.title),
                )),
          body: SafeArea(
            top: !videoPageController.androidFullscreen,
            bottom: !videoPageController.androidFullscreen,
            left: !videoPageController.androidFullscreen,
            right: !videoPageController.androidFullscreen,
            child: (Utils.isDesktop()) ||
                    ((Utils.isTablet()) &&
                        MediaQuery.of(context).size.height <
                            MediaQuery.of(context).size.width)
                ? Row(
                    children: [
                      Container(
                          color: Colors.black,
                          height: MediaQuery.of(context).size.height,
                          width: (!videoPageController.androidFullscreen &&
                                  videoPageController.showTabBody)
                              ? MediaQuery.of(context).size.height
                              : MediaQuery.of(context).size.width,
                          child: playerBody),
                      (videoPageController.androidFullscreen ||
                              !videoPageController.showTabBody)
                          ? Container()
                          : Expanded(
                              child: Column(
                              children: [
                                tabBar,
                                tabBody,
                              ],
                            ))
                    ],
                  )
                : Column(
                    children: [
                      Container(
                          color: Colors.black,
                          height: videoPageController.androidFullscreen
                              ? MediaQuery.of(context).size.height
                              : MediaQuery.of(context).size.width * 9 / 16,
                          width: MediaQuery.of(context).size.width,
                          child: playerBody),
                      videoPageController.androidFullscreen
                          ? Container()
                          : Expanded(
                              child: Column(
                              children: [
                                tabBar,
                                tabBody,
                              ],
                            ))
                    ],
                  ),
          ),
        );
      });
    });
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
                    videoPageController.showDebugLog,
                child: Container(
                  color: Colors.black,
                  child: Align(
                    alignment: Alignment.center,
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: videoPageController.logLines.length,
                      itemBuilder: (context, index) {
                        return Text(
                          videoPageController.logLines.isEmpty
                              ? ''
                              : videoPageController.logLines[index],
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
                      videoPageController.androidFullscreen))
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
                                  if (videoPageController.androidFullscreen ==
                                      true) {
                                    Utils.exitFullScreen();
                                    videoPageController.androidFullscreen =
                                        false;
                                    return;
                                  }
                                  Navigator.of(context).pop();
                                },
                              ),
                              const Expanded(
                                  child: dtb.DragToMoveArea(
                                      child: SizedBox(height: 40))),
                              IconButton(
                                icon: const Icon(Icons.bug_report,
                                    color: Colors.white),
                                onPressed: () {
                                  showDebugConsole();
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
              : const PlayerItem(),
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

  Widget get tabBar {
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 6),
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
                SmartDialog.show(
                    useAnimation: false,
                    builder: (context) {
                      return AlertDialog(
                        title: const Text('播放列表'),
                        content: StatefulBuilder(builder:
                            (BuildContext context, StateSetter innerSetState) {
                          return Wrap(
                            spacing: 8,
                            runSpacing: 2,
                            children: [
                              for (int i = 1;
                                  i <= videoPageController.roadList.length;
                                  i++) ...<Widget>[
                                if (i == currentRoad + 1) ...<Widget>[
                                  FilledButton(
                                    onPressed: () {
                                      SmartDialog.dismiss();
                                      setState(() {
                                        currentRoad = i - 1;
                                      });
                                    },
                                    child: Text('播放列表$i'),
                                  ),
                                ] else ...[
                                  FilledButton.tonal(
                                    onPressed: () {
                                      SmartDialog.dismiss();
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

  Widget get tabBody {
    var cardList = <Widget>[];
    for (var road in videoPageController.roadList) {
      if (road.name == '播放列表${currentRoad + 1}') {
        int count = 1;
        for (var urlItem in road.data) {
          int count0 = count;
          cardList.add(Container(
            margin: const EdgeInsets.only(bottom: 10), // 改为bottom间距
            child: Material(
              color: Theme.of(context).colorScheme.onInverseSurface,
              borderRadius: BorderRadius.circular(6),
              clipBehavior: Clip.hardEdge,
              child: InkWell(
                onTap: () async {
                  if (count0 == videoPageController.currentEspisode &&
                      videoPageController.currentRoad == currentRoad) {
                    return;
                  }
                  KazumiLogger().log(Level.info, '视频链接为 $urlItem');
                  videoPageController.currentRoad = currentRoad;
                  videoPageController.changeEpisode(count0,
                      currentRoad: videoPageController.currentRoad);
                },
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: [
                          if (count0 == (videoPageController.currentEspisode) &&
                              currentRoad ==
                                  videoPageController.currentRoad) ...<Widget>[
                            Image.asset(
                              'assets/images/live.png',
                              color: Theme.of(context).colorScheme.primary,
                              height: 12,
                            ),
                            const SizedBox(width: 6)
                          ],
                          Text(
                            road.identifier[count0 - 1],
                            style: TextStyle(
                                fontSize: 13,
                                color: (count0 ==
                                            videoPageController
                                                .currentEspisode &&
                                        currentRoad ==
                                            videoPageController.currentRoad)
                                    ? Theme.of(context).colorScheme.primary
                                    : Theme.of(context).colorScheme.onSurface),
                          ),
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
        padding: const EdgeInsets.only(top: 0, right: 5, left: 5),
        child: GridView.builder(
          scrollDirection: Axis.vertical,
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
}
