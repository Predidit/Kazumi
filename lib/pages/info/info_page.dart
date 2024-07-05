import 'package:kazumi/utils/utils.dart';
import 'package:adaptive_theme/adaptive_theme.dart';
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
import 'package:kazumi/pages/menu/side_menu.dart';
import 'package:provider/provider.dart';
import 'package:kazumi/bean/card/network_img_layer.dart';
import 'package:kazumi/bean/appbar/sys_app_bar.dart';
import 'package:kazumi/request/query_manager.dart';

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
  dynamic navigationBarState;
  late TabController tabController;

  /// 用于并发查询
  late QueryManager queryManager;

  @override
  void initState() {
    super.initState();
    queryManager = QueryManager();
    queryManager.querySource(popularController.keyword);
    tabController =
        TabController(length: pluginsController.pluginList.length, vsync: this);
    if (Utils.isCompact()) {
      navigationBarState =
          Provider.of<NavigationBarState>(context, listen: false);
    } else {
      navigationBarState =
          Provider.of<SideNavigationBarState>(context, listen: false);
    }
  }

  void onBackPressed(BuildContext context) {
    navigationBarState.showNavigate();
  }

  @override
  void dispose() {
    queryManager.cancel();
    videoPageController.currentEspisode = 1;
    super.dispose();
  }

  // 获取当前主题模式
  bool get isLightTheme {
    final currentMode = AdaptiveTheme.of(context).mode;
    if (currentMode == AdaptiveThemeMode.light) {
      return true;
    }

    // 检查 AdaptiveThemeMode.system 的情况
    if (currentMode == AdaptiveThemeMode.system) {
      final brightness = MediaQuery.of(context).platformBrightness;
      if (brightness == Brightness.light) {
        return true;
      }
    }
    return false;
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
      child: Stack(
        children: [
          Scaffold(
            backgroundColor: isLightTheme ? Colors.white : Colors.black,
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
                        var plugin = pluginsController.pluginList[pluginIndex];
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
                                    videoPageController.currentPlugin = plugin;
                                    videoPageController.title = searchItem.name;
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
          Positioned.fill(
            child: IgnorePointer(
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
          ),
        ],
      ),
    );
  }
}
