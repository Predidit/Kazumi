import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/pages/info/info_controller.dart';
import 'package:kazumi/bean/card/bangumi_info_card.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:kazumi/plugins/plugins_controller.dart';
import 'package:kazumi/pages/video/video_controller.dart';
import 'package:kazumi/pages/popular/popular_controller.dart';
import 'package:kazumi/bean/card/network_img_layer.dart';
import 'package:kazumi/bean/appbar/sys_app_bar.dart';
import 'package:kazumi/request/query_manager.dart';
import 'package:kazumi/utils/utils.dart';
import 'package:logger/logger.dart';
import 'package:kazumi/utils/logger.dart';
import 'package:kazumi/pages/info/comments_sheet.dart';
import 'package:url_launcher/url_launcher.dart';

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
  late TabController tabController;

  /// Concurrent query manager
  late QueryManager queryManager;

  @override
  void initState() {
    super.initState();
    // Because the gap between different bangumi API reponse is too large, sometimes we need to query the bangumi info again
    // We need the type parameter to determine whether to attach the new data to the old data
    // We can't generally replace the old data with the new data, because the old data containes images url, update them will cause the image to reload and flicker
    if (infoController.bangumiItem.summary == '' || infoController.bangumiItem.tags.isEmpty) {
      queryBangumiInfoByID(infoController.bangumiItem.id, type: 'attach');
    }
    queryManager = QueryManager();
    queryManager.querySource(popularController.keyword);
    tabController =
        TabController(length: pluginsController.pluginList.length, vsync: this);
  }

  @override
  void dispose() {
    queryManager.cancel();
    infoController.characterList.clear();
    infoController.commentsList.clear();
    videoPageController.currentEpisode = 1;
    tabController.dispose();
    super.dispose();
  }

  Future<void> queryBangumiInfoByID(int id, {String type = "init"}) async {
    try {
      await infoController.queryBangumiInfoByID(id, type: type);
      setState(() {});
    } catch (e) {
      KazumiLogger().log(Level.error, e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      child: Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: Container(
                color: Theme.of(context).brightness == Brightness.light
                    ? Colors.white
                    : Colors.black,
                child: Opacity(
                  opacity: 0.2,
                  child: LayoutBuilder(builder: (context, boxConstraints) {
                    return ImageFiltered(
                      imageFilter: ImageFilter.blur(sigmaX: 15.0, sigmaY: 15.0),
                      child: NetworkImgLayer(
                        src: infoController.bangumiItem.images['large'] ?? '',
                        width: boxConstraints.maxWidth,
                        height: boxConstraints.maxHeight,
                        fadeInDuration: const Duration(milliseconds: 0),
                        fadeOutDuration: const Duration(milliseconds: 0),
                      ),
                    );
                  }),
                ),
              ),
            ),
          ),
          Scaffold(
            backgroundColor: Colors.transparent,
            appBar: SysAppBar(
              backgroundColor: Colors.transparent,
              actions: [
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
                    icon: const Icon(Icons.open_in_browser))
              ],
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
            floatingActionButton: FloatingActionButton(
              child: const Icon(Icons.widgets_rounded),
              onPressed: () async {
                showModalBottomSheet(
                    isScrollControlled: true,
                    constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(context).size.height * 3 / 4,
                        maxWidth: (Utils.isDesktop() || Utils.isTablet())
                            ? MediaQuery.of(context).size.width * 9 / 16
                            : MediaQuery.of(context).size.width),
                    clipBehavior: Clip.antiAlias,
                    context: context,
                    builder: (context) {
                      return const CommentsBottomSheet();
                    });
              },
            ),
          ),
        ],
      ),
    );
  }
}
