import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/pages/info/info_controller.dart';
import 'package:kazumi/pages/video/video_controller.dart';
import 'package:kazumi/pages/webview/webview_item.dart';
import 'package:kazumi/pages/webview_desktop/webview_desktop_item.dart';
import 'package:kazumi/pages/webview/webview_controller.dart';
import 'package:kazumi/pages/webview_desktop/webview_desktop_controller.dart';
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: Column(
        children: [
          SizedBox(
            height: MediaQuery.of(context).size.width * 9 / 16
                ,
            // width: (Platform.isAndroid || Platform.isIOS) ? null : 400,
            child: Platform.isWindows
                ? const WebviewDesktopItem()
                : const WebviewItem(),
          ),
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
                        cardList.add(Card(
                          child: ListTile(
                            title: Text('第${count}话'),
                            onTap: () async {
                              debugPrint('视频链接为 $urlItem');
                              String videoUrl = await videoPageController
                                  .queryVideoUrl(urlItem);
                              debugPrint('由无Webview刮削器获取的视频真实链接为 $videoUrl');
                              if (Platform.isWindows) {
                                final WebviewDesktopItemController
                                    webviewDesktopItemController =
                                    Modular.get<WebviewDesktopItemController>();
                                await webviewDesktopItemController.loadUrl(
                                    videoPageController.currentPlugin.baseUrl +
                                        urlItem);
                              } else {
                                final WebviewItemController
                                    webviewItemController =
                                    Modular.get<WebviewItemController>();
                                await webviewItemController.loadUrl(
                                    videoPageController.currentPlugin.baseUrl +
                                        urlItem);
                              }
                            },
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
