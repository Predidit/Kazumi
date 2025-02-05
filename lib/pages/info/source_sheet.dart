import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/pages/info/info_controller.dart';
import 'package:kazumi/utils/logger.dart';
import 'package:logger/logger.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/plugins/plugins_controller.dart';
import 'package:kazumi/pages/video/video_controller.dart';
import 'package:url_launcher/url_launcher.dart';

class SourceSheet extends StatefulWidget {
  const SourceSheet({super.key});

  @override
  State<SourceSheet> createState() => _SourceSheetState();
}

class _SourceSheetState extends State<SourceSheet>
    with SingleTickerProviderStateMixin {
  final infoController = Modular.get<InfoController>();
  final VideoPageController videoPageController =
      Modular.get<VideoPageController>();
  final PluginsController pluginsController = Modular.get<PluginsController>();
  late TabController tabController;

  @override
  void initState() {
    super.initState();
    tabController =
        TabController(length: pluginsController.pluginList.length, vsync: this);
  }

  @override
  void dispose() {
    tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        body: Column(
          children: [
            Row(
              children: [
                Expanded(child:
                TabBar(
                  isScrollable: true,
                  tabAlignment: TabAlignment.center,
                  dividerHeight: 0,
                  controller: tabController,
                  tabs: pluginsController.pluginList
                      .map(
                        (plugin) => Observer(
                          builder: (context) => Tab(
                            child: Row(
                              children: [
                                Text(
                                  plugin.name,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      fontSize: Theme.of(context)
                                          .textTheme
                                          .titleMedium!
                                          .fontSize,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface),
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
                          ),
                        ),
                      )
                      .toList(),
                ),),
                IconButton(
                  onPressed: () {
                    int currentIndex = tabController.index;
                    KazumiDialog.show(builder: (context) {
                      return AlertDialog(
                        title: const Text('退出确认'),
                        content: const Text('您想要离开 Kazumi 并在浏览器中打开此视频源吗？'),
                        actions: [
                          TextButton(
                              onPressed: () => KazumiDialog.dismiss(),
                              child: const Text('取消')),
                          TextButton(
                              onPressed: () {
                                KazumiDialog.dismiss();
                                launchUrl(Uri.parse(pluginsController
                                    .pluginList[currentIndex].baseUrl));
                              },
                              child: const Text('确认')),
                        ],
                      );
                    });
                  },
                  icon: const Icon(Icons.open_in_browser),
                ),
                const SizedBox(width: 4),
              ],
            ),
            const Divider(height: 0),
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
                          cardList.add(
                            Card(
                              margin: const EdgeInsets.only(
                                  left: 10, right: 10, top: 10),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: () async {
                                  KazumiDialog.showLoading(msg: '获取中');
                                  videoPageController.currentPlugin = plugin;
                                  videoPageController.title = searchItem.name;
                                  videoPageController.src = searchItem.src;
                                  try {
                                    await infoController.queryRoads(
                                        searchItem.src, plugin.name);
                                    KazumiDialog.dismiss();
                                    Modular.to.pushNamed('/video/');
                                  } catch (e) {
                                    KazumiLogger()
                                        .log(Level.error, e.toString());
                                    KazumiDialog.dismiss();
                                  }
                                },
                                child: Padding(
                                  padding: const EdgeInsets.all(20),
                                  child: Text(searchItem.name),
                                ),
                              ),
                            ),
                          );
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
    );
  }
}
