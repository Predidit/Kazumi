import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/modules/search/search_module.dart';
import 'package:kazumi/pages/info/info_controller.dart';
import 'package:kazumi/bean/card/bangumi_info_card.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:kazumi/plugins/plugins_controller.dart';

class InfoPage extends StatefulWidget {
  const InfoPage({super.key});

  @override
  State<InfoPage> createState() => _InfoPageState();
}

class _InfoPageState extends State<InfoPage>
    with SingleTickerProviderStateMixin {
  final InfoController infoController = Modular.get<InfoController>();
  final PluginsController pluginsController = Modular.get<PluginsController>();
  late TabController tabController;

  @override
  void initState() {
    super.initState();
    tabController =
        TabController(length: pluginsController.pluginList.length, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
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
                            decoration: const BoxDecoration(
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
                children: infoController.searchResponseList.map((searchResponse) {
                  if (searchResponse.data.isNotEmpty) {
                    return ListView(
                      children: [
                        ...searchResponse.data.map((searchItem) => Card(
                          child: ListTile(
                            title: Text('${searchItem.name}'),
                          ),
                        ))
                      ],
                    );
                  } else {
                    return const Center(
                      child: Text('该番剧源获取失败'),
                    );
                  }
                }).toList(),
              ),
            ),
          )
        ],
      ),
    );
  }
}
