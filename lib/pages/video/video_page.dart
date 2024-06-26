import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/bean/appbar/sys_app_bar.dart';
import 'package:kazumi/bean/widget/text_display.dart';
import 'package:kazumi/pages/info/info_controller.dart';
import 'package:kazumi/pages/player/player_controller.dart';
import 'package:kazumi/pages/video/video_controller.dart';
import 'package:kazumi/pages/webview/webview_item.dart';
import 'package:kazumi/pages/history/history_controller.dart';
import 'package:kazumi/pages/webview_desktop/webview_desktop_item.dart';
import 'package:kazumi/pages/player/player_item.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:kazumi/utils/utils.dart';

class VideoPage extends StatefulWidget {
  const VideoPage({super.key});

  @override
  State<VideoPage> createState() => _VideoPageState();
}

class _VideoPageState extends State<VideoPage>
    with SingleTickerProviderStateMixin {
  final InfoController infoController = Modular.get<InfoController>();
  final VideoPageController videoPageController =
      Modular.get<VideoPageController>();
  final PlayerController playerController = Modular.get<PlayerController>();
  final HistoryController historyController = Modular.get<HistoryController>();
  late TabController tabController;

  @override
  void initState() {
    super.initState();
    videoPageController.currentEspisode = 1;
    videoPageController.currentRoad = 0;
    var progress = historyController.lastWatching(
        infoController.bangumiItem, videoPageController.currentPlugin.name);
    if (progress != null) {
      debugPrint('尝试恢复观看进度');
      if (videoPageController.roadList.length > progress.road) {
        debugPrint('播放列表选择恢复');
        if (videoPageController.roadList[progress.road].data.length >=
            progress.episode) {
          debugPrint('选集进度恢复');
          videoPageController.currentEspisode = progress.episode;
          videoPageController.currentRoad = progress.road;
        }
      }
    }
    tabController = TabController(
        length: videoPageController.roadList.length,
        vsync: this,
        initialIndex: videoPageController.currentRoad);
  }

  @override
  void dispose() {
    try {
      playerController.mediaPlayer.dispose();
    } catch (_) {}
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!Platform.isWindows) {
        videoPageController.changeEpisode(videoPageController.currentEspisode,
            currentRoad: videoPageController.currentRoad);
      }
    });
    return SafeArea(
      child: Observer(builder: (context) {
        return Scaffold(
          appBar: ((videoPageController.currentPlugin.useNativePlayer ||
                  videoPageController.androidFullscreen)
              ? null
              : SysAppBar(
                  title: Text(videoPageController.title),
                )),
          body: Column(
            children: [
              Container(
                color: Colors.black,
                height: MediaQuery.of(context).size.width * 9 / 16,
                width: MediaQuery.of(context).size.width,
                child: Stack(
                  children: [
                    // 日志组件
                    Positioned.fill(
                      child: Stack(
                        children: [
                          Visibility(
                            visible: videoPageController.loading,
                            child: Align(
                              alignment: Alignment.center,
                              child: ListView.builder(
                                shrinkWrap: true,
                                itemCount: videoPageController.logLines.length,
                                itemBuilder: (context, index) {
                                  return Text(
                                    videoPageController.logLines[index],
                                    style: const TextStyle(
                                      color: Colors.white,
                                    ),
                                    textAlign: TextAlign.center,
                                  );
                                },
                              ),
                            ),
                          ),
                          ((videoPageController.currentPlugin.useNativePlayer ||
                                  videoPageController.androidFullscreen))
                              ? Positioned(
                                  top: 0,
                                  left: 0,
                                  child: IconButton(
                                    icon: const Icon(Icons.arrow_back,
                                        color: Colors.white),
                                    onPressed: () {
                                      if (videoPageController
                                              .androidFullscreen ==
                                          true) {
                                        videoPageController.exitFullScreen();
                                        videoPageController.androidFullscreen =
                                            false;
                                        return;
                                      }
                                      Navigator.of(context).pop();
                                    },
                                  ),
                                )
                              : Container(),
                        ],
                      ),
                    ),
                    // Positioned.fill(
                    //     child: Visibility(
                    //   visible: videoPageController.loading,
                    //   child:
                    //       (!videoPageController.currentPlugin.useNativePlayer)
                    //           ? Container(
                    //               color: Colors.black,
                    //               child: const Center(
                    //                   child: CircularProgressIndicator()))
                    //           : Container(),
                    // )),
                    Positioned.fill(
                      child:
                          (!videoPageController.currentPlugin.useNativePlayer ||
                                  playerController.loading)
                              ? Container()
                              : const PlayerItem(),
                    ),
                    Positioned(
                        child: SizedBox(
                      height: (videoPageController.loading ||
                              videoPageController.currentPlugin.useNativePlayer)
                          ? 0
                          : null,
                      child: Platform.isWindows
                          ? const WebviewDesktopItem()
                          : const WebviewItem(),
                    ))
                  ],
                ),
              ),
              videoPageController.androidFullscreen
                  ? Container()
                  : TabBar(
                      isScrollable: true,
                      tabAlignment: TabAlignment.center,
                      controller: tabController,
                      tabs: videoPageController.roadList
                          .map(
                            (road) => Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  road.name,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          )
                          .toList(),
                    ),
              videoPageController.androidFullscreen
                  ? Container()
                  : Expanded(
                      child: Observer(
                        builder: (context) => TabBarView(
                          controller: tabController,
                          children: List.generate(
                              videoPageController.roadList.length, (roadIndex) {
                            var cardList = <Widget>[];
                            for (var road in videoPageController.roadList) {
                              if (road.name == '播放列表${roadIndex + 1}') {
                                int count = 1;
                                for (var urlItem in road.data) {
                                  int _count = count;
                                  cardList.add(Container(
                                    margin: const EdgeInsets.only(
                                        bottom: 10), // 改为bottom间距
                                    child: Material(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onInverseSurface,
                                      borderRadius: BorderRadius.circular(6),
                                      clipBehavior: Clip.hardEdge,
                                      child: InkWell(
                                        onTap: () async {
                                          debugPrint('视频链接为 $urlItem');
                                          videoPageController.changeEpisode(
                                              _count,
                                              currentRoad: roadIndex);
                                        },
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 8, horizontal: 10),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: <Widget>[
                                              Row(
                                                children: [
                                                  if (_count ==
                                                          (videoPageController
                                                              .currentEspisode) &&
                                                      roadIndex ==
                                                          videoPageController
                                                              .currentRoad) ...<Widget>[
                                                    Image.asset(
                                                      'assets/images/live.png',
                                                      color: Theme.of(context)
                                                          .colorScheme
                                                          .primary,
                                                      height: 12,
                                                    ),
                                                    const SizedBox(width: 6)
                                                  ],
                                                  Text(
                                                    '第$count话',
                                                    style: TextStyle(
                                                        fontSize: 13,
                                                        color: (_count ==
                                                                    (videoPageController
                                                                        .currentEspisode) &&
                                                                roadIndex ==
                                                                    videoPageController
                                                                        .currentRoad)
                                                            ? Theme.of(context)
                                                                .colorScheme
                                                                .primary
                                                            : Theme.of(context)
                                                                .colorScheme
                                                                .onSurface),
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
                            // return ListView(children: cardList);
                            return GridView.builder(
                              scrollDirection: Axis.vertical,
                              gridDelegate:
                                  SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: !Utils.isCompact(context)
                                    ? 10
                                    : 3,
                                crossAxisSpacing: 10,
                                mainAxisSpacing: 5,
                                childAspectRatio: 1.7,
                              ),
                              itemCount: cardList.length,
                              itemBuilder: (context, index) {
                                return cardList[index];
                              },
                            );
                          }),
                        ),
                      ),
                    ),
            ],
          ),
        );
      }),
    );
  }
}
