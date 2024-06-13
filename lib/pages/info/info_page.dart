import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:kazumi/pages/info/info_controller.dart';
import 'package:kazumi/bean/card/bangumi_info_card.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:kazumi/plugins/plugins_controller.dart';
import 'package:kazumi/pages/video/video_controller.dart';
import 'package:kazumi/pages/popular/popular_controller.dart';
import 'package:kazumi/pages/menu/menu.dart';
import 'package:provider/provider.dart';
import 'package:kazumi/bean/card/network_img_layer.dart';
import 'package:kazumi/bean/appbar/sys_app_bar.dart';

class InfoPage extends StatefulWidget {
  const InfoPage({super.key});

  @override
  State<InfoPage> createState() => _InfoPageState();
}

class _InfoPageState extends State<InfoPage>
    with SingleTickerProviderStateMixin {
  final InfoController infoController = Modular.get<InfoController>();
  final VideoPageController videoPageController =
      Modular.get<VideoPageController>();
  final PluginsController pluginsController = Modular.get<PluginsController>();
  final PopularController popularController = Modular.get<PopularController>();
  // List<String> pluginSearchStatusList = [];
  late NavigationBarState navigationBarState;
  late TabController tabController;

  @override
  void initState() {
    super.initState();
    tabController =
        TabController(length: pluginsController.pluginList.length, vsync: this);
    // 测试用例
    infoController.querySource(popularController.keyword);
    navigationBarState =
        Provider.of<NavigationBarState>(context, listen: false);
  }

  void onBackPressed(BuildContext context) {
    navigationBarState.showNavigate();
    // Navigator.of(context).pop();
  }

  @override
  void dispose() {
    // 测试
    videoPageController.currentEspisode = 1;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      navigationBarState.hideNavigate();
    });
    return PopScope(
      canPop: true,
      onPopInvoked: (bool didPop) {
        onBackPressed(context);
      },
      child: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: Opacity(
                opacity: 0.1,
                child: LayoutBuilder(builder: (context, boxConstraints) {
                  return NetworkImgLayer(
                    src: infoController.bangumiItem.images['large'] ?? '',
                    width: boxConstraints.maxWidth,
                    height: boxConstraints.maxHeight,
                  );
                }),
              ),
            ),
            Scaffold(
              backgroundColor: Colors.transparent,
              appBar: const SysAppBar(backgroundColor: Colors.transparent),
              body: Column(
                children: [
                  BangumiInfoCardV(bangumiItem: infoController.bangumiItem),
                  TabBar(
                    isScrollable: true,
                    tabAlignment: TabAlignment.center,
                    controller: tabController,
                    tabs: pluginsController.pluginList
                        .map((plugin) => Observer(
                              builder: (context) => Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    plugin.name,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(width: 5.0),
                                  Container(
                                    width: 8.0,
                                    height: 8.0,
                                    decoration: BoxDecoration(
                                      color: infoController.pluginSearchStatus[
                                                  plugin.name] ==
                                              'success'
                                          ? Colors.green
                                          : (infoController.pluginSearchStatus[
                                                      plugin.name] ==
                                                  'pending')
                                              ? Colors.grey
                                              : Colors.red,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ],
                              ),
                            ))
                        .toList(),
                  ),
                  Expanded(
                    child: Observer(
                      builder: (context) => TabBarView(
                        controller: tabController,
                        children: List.generate(
                            pluginsController.pluginList.length, (pluginIndex) {
                          var plugin =
                              pluginsController.pluginList[pluginIndex];
                          var cardList = <Widget>[];
                          for (var searchResponse
                              in infoController.pluginSearchResponseList) {
                            if (searchResponse.pluginName == plugin.name) {
                              for (var searchItem in searchResponse.data) {
                                cardList.add(Card(
                                  color: Colors.transparent,
                                  child: ListTile(
                                    tileColor: Colors.transparent,
                                    title: Text(searchItem.name),
                                    onTap: () async {
                                      SmartDialog.showLoading(msg: '获取中');
                                      videoPageController.currentPlugin =
                                          plugin;
                                      videoPageController.title =
                                          searchItem.name;
                                      videoPageController.src = searchItem.src;
                                      try {
                                        await infoController.queryRoads(
                                            searchItem.src, plugin.name);
                                        SmartDialog.dismiss();
                                        Modular.to.pushNamed('/tab/video/');
                                      } catch (e) {
                                        debugPrint(e.toString());
                                        SmartDialog.dismiss();
                                      }
                                    },
                                  ),
                                ));
                              }
                            }
                          }
                          return ListView(children: cardList);
                        }),
                      ),
                    ),
                  )
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
