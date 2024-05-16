import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/bean/appbar/sys_app_bar.dart';
import 'package:kazumi/pages/info/info_controller.dart';
import 'package:kazumi/pages/player/player_controller.dart';
import 'package:kazumi/pages/video/video_controller.dart';
import 'package:kazumi/pages/webview/webview_item.dart';
import 'package:kazumi/pages/webview_desktop/webview_desktop_controller.dart';
import 'package:kazumi/pages/webview_desktop/webview_desktop_item.dart';
import 'package:kazumi/pages/player/player_item.dart';
import 'package:flutter_mobx/flutter_mobx.dart';

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
  late TabController tabController;

  @override
  void initState() {
    super.initState();
    tabController =
        TabController(length: videoPageController.roadList.length, vsync: this);
  }

  @override
  void dispose() {
    // try {
    //   if (Platform.isWindows) {
    //     final WebviewDesktopItemController webviewDesktopItemController =
    //         Modular.get<WebviewDesktopItemController>();
    //     webviewDesktopItemController.webviewController.loadUrl('about:blank');
    //     webviewDesktopItemController.webviewController.clearCache();
    //   } else {
    //     final WebviewItemController webviewItemController =
    //         Modular.get<WebviewItemController>();
    //     webviewItemController.webviewController.loadRequest(Uri.parse('about:blank'));
    //     webviewItemController.webviewController.clearCache();
    //   }
    // } catch (_) {}
    try {
      playerController.mediaPlayer.dispose();
    } catch (_) {}
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (Platform.isWindows) {
        final WebviewDesktopItemController webviewDesktopItemController =
            Modular.get<WebviewDesktopItemController>();
        if (!webviewDesktopItemController
            .webviewController.value.isInitialized) {
          await webviewDesktopItemController.init();
        }
      }
      videoPageController.changeEpisode(videoPageController.currentEspisode);
    });
    return Scaffold(
      appBar: (videoPageController.currentPlugin.useNativePlayer ? null : SysAppBar()),
      body: Column(
        children: [
          Observer(builder: (context) {
            return Container(
              color: Colors.black,
              height: MediaQuery.of(context).size.width * 9 / 16,
              width: MediaQuery.of(context).size.width,
              child: Stack(
                children: [
                  Positioned.fill(
                      child: Visibility(
                    visible: videoPageController.loading,
                    child: (!videoPageController.currentPlugin.useNativePlayer)
                        ? Container(
                            color: Colors.black,
                            child: const Center(
                                child: CircularProgressIndicator()))
                        : Container(),
                  )),
                  Positioned.fill(
                    child: (!videoPageController.currentPlugin.useNativePlayer || playerController.loading)
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
            );
          }),
          TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.center,
            controller: tabController,
            tabs: videoPageController.roadList
                .map((road) => Observer(
                      builder: (context) => Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            road.name,
                            overflow: TextOverflow.ellipsis,
                          ),
                          // const SizedBox(width: 5.0),
                          // Container(
                          //   width: 8.0,
                          //   height: 8.0,
                          //   decoration: const BoxDecoration(
                          //     shape: BoxShape.circle,
                          //   ),
                          // ),
                        ],
                      ),
                    ))
                .toList(),
          ),
          Expanded(
            child: Observer(
              builder: (context) => TabBarView(
                controller: tabController,
                children: List.generate(videoPageController.roadList.length,
                    (roadIndex) {
                  var cardList = <Widget>[];
                  for (var road in videoPageController.roadList) {
                    if (road.name == '播放列表${roadIndex + 1}') {
                      int count = 1;
                      for (var urlItem in road.data) {
                        int _count = count;
                        cardList.add(Container(
                          margin:
                              const EdgeInsets.only(bottom: 10), // 改为bottom间距
                          child: Material(
                            color:
                                Theme.of(context).colorScheme.onInverseSurface,
                            borderRadius: BorderRadius.circular(6),
                            clipBehavior: Clip.hardEdge,
                            child: InkWell(
                              onTap: () async {
                                debugPrint('视频链接为 $urlItem');
                                videoPageController.changeEpisode(_count,
                                    currentRoad: roadIndex);
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    vertical: 8, horizontal: 10),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Row(
                                      children: [
                                        if (_count ==
                                            (videoPageController
                                                .currentEspisode)) ...<Widget>[
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
                                              color: _count ==
                                                      (videoPageController
                                                          .currentEspisode)
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
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: Platform.isWindows ||
                              Platform.isLinux ||
                              Platform.isMacOS
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
          // InkWell(
          //   child: const Card(
          //     child: ListTile(
          //       title: Text('刮削测试'),
          //     ),
          //   ),
          //   onTap: () async {
          //     if (Platform.isWindows) {
          //       final WebviewDesktopItemController
          //           webviewDesktopItemController =
          //           Modular.get<WebviewDesktopItemController>();
          //       await webviewDesktopItemController.parseIframeUrl();
          //     } else {
          //       final WebviewItemController webviewItemController =
          //           Modular.get<WebviewItemController>();
          //       await webviewItemController.parseIframeUrl();
          //     }
          //   },
          // )
        ],
      ),
    );
  }
}
