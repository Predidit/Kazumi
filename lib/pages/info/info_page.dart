import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/pages/info/info_controller.dart';
import 'package:kazumi/bean/card/bangumi_info_card.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:kazumi/plugins/plugins_controller.dart';
import 'package:kazumi/pages/video/video_controller.dart';
import 'package:kazumi/pages/popular/popular_controller.dart';
import 'package:kazumi/pages/menu/menu.dart';
import 'package:kazumi/utils/utils.dart';
import 'package:provider/provider.dart';
import 'package:kazumi/modules/plugins/plugins.dart';

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
    // 初始化插件状态监听器
    // for (int i=0; i< pluginsController.pluginList.length; i++) {
    //   pluginSearchStatusList.add('pending');
    // }
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      navigationBarState.hideNavigate();
    });
    debugPrint('status 数组长度为 ${infoController.pluginSearchStatus.length}');
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            navigationBarState.showNavigate();
            Navigator.of(context).pop();
          },
        ),
      ),
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
                              color: infoController.pluginSearchStatus[plugin.name] == 'success' ? Colors.green : (infoController.pluginSearchStatus[plugin.name] == 'pending') ? Colors.grey : Colors.red,
                              // color: Colors.green,
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
                children: List.generate(pluginsController.pluginList.length,
                    (pluginIndex) {
                  var plugin = pluginsController.pluginList[pluginIndex];
                  var cardList = <Widget>[];
                  for (var searchResponse
                      in infoController.pluginSearchResponseList) {
                    if (searchResponse.pluginName == plugin.name) {
                      for (var searchItem in searchResponse.data) {
                        cardList.add(Card(
                          child: ListTile(
                            title: Text(searchItem.name),
                            onTap: () async {
                              videoPageController.currentPlugin = plugin;
                              await infoController.queryRoads(
                                  searchItem.src, plugin.name);
                              Modular.to.pushNamed('/tab/video/');
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
    );
  }
}
