import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/bean/widget/embedded_native_control_area.dart';
import 'package:kazumi/bean/widget/error_widget.dart';
import 'package:kazumi/pages/collect/collect_controller.dart';
import 'package:kazumi/pages/info/info_controller.dart';
import 'package:kazumi/bean/card/bangumi_info_card.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:kazumi/plugins/plugins_controller.dart';
import 'package:kazumi/pages/video/video_controller.dart';
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
  final CollectController collectController = Modular.get<CollectController>();
  final VideoPageController videoPageController =
      Modular.get<VideoPageController>();
  final PluginsController pluginsController = Modular.get<PluginsController>();
  final ScrollController scrollController = ScrollController();
  late TabController tabController;
  late String keyword;

  /// Concurrent query manager
  late QueryManager queryManager;

  @override
  void initState() {
    super.initState();
    // Because the gap between different bangumi API reponse is too large, sometimes we need to query the bangumi info again
    // We need the type parameter to determine whether to attach the new data to the old data
    // We can't generally replace the old data with the new data, because the old data containes images url, update them will cause the image to reload and flicker
    if (infoController.bangumiItem.summary == '' ||
        infoController.bangumiItem.tags.isEmpty ||
        infoController.bangumiItem.ratingScore == 0.0) {
      queryBangumiInfoByID(infoController.bangumiItem.id, type: 'attach');
    }
    keyword = infoController.bangumiItem.nameCn == ''
        ? infoController.bangumiItem.name
        : infoController.bangumiItem.nameCn;
    queryManager = QueryManager();
    queryManager.queryAllSource(keyword);
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

  void showAliasSearchDialog(String pluginName) {
    if (infoController.bangumiItem.alias.isEmpty) {
      KazumiDialog.showToast(message: '无可用别名，试试手动检索');
      return;
    }
    final aliasNotifier =
        ValueNotifier<List<String>>(infoController.bangumiItem.alias);
    KazumiDialog.show(builder: (context) {
      return Dialog(
        clipBehavior: Clip.antiAlias,
        child: ValueListenableBuilder<List<String>>(
          valueListenable: aliasNotifier,
          builder: (context, aliasList, child) {
            return ListView(
              shrinkWrap: true,
              children: aliasList.asMap().entries.map((entry) {
                final index = entry.key;
                final alias = entry.value;
                return ListTile(
                  title: Text(alias),
                  trailing: IconButton(
                    onPressed: () {
                      KazumiDialog.show(
                        builder: (context) {
                          return AlertDialog(
                            title: const Text('删除确认'),
                            content: const Text('删除后无法恢复，确认要永久删除这个别名吗？'),
                            actions: [
                              TextButton(
                                onPressed: () {
                                  KazumiDialog.dismiss();
                                },
                                child: Text(
                                  '取消',
                                  style: TextStyle(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .outline),
                                ),
                              ),
                              TextButton(
                                onPressed: () {
                                  KazumiDialog.dismiss();
                                  aliasList.removeAt(index);
                                  aliasNotifier.value = List.from(aliasList);
                                  collectController.updateLocalCollect(
                                      infoController.bangumiItem);
                                  if (aliasList.isEmpty) {
                                    // pop whole dialog when empty
                                    Navigator.of(context).pop();
                                  }
                                },
                                child: const Text('确认'),
                              ),
                            ],
                          );
                        },
                      );
                    },
                    icon: Icon(Icons.delete),
                  ),
                  onTap: () {
                    KazumiDialog.dismiss();
                    queryManager.querySource(alias, pluginName);
                  },
                );
              }).toList(),
            );
          },
        ),
      );
    });
  }

  void showCustomSearchDialog(String pluginName) {
    KazumiDialog.show(
      builder: (context) {
        final TextEditingController textController = TextEditingController();
        return AlertDialog(
          title: const Text('输入别名'),
          content: TextField(
            controller: textController,
            onSubmitted: (keyword) {
              if (textController.text != '') {
                infoController.bangumiItem.alias.add(textController.text);
                KazumiDialog.dismiss();
                queryManager.querySource(textController.text, pluginName);
              }
            },
          ),
          actions: [
            TextButton(
              onPressed: () {
                KazumiDialog.dismiss();
              },
              child: Text(
                '取消',
                style: TextStyle(color: Theme.of(context).colorScheme.outline),
              ),
            ),
            TextButton(
              onPressed: () {
                if (textController.text != '') {
                  infoController.bangumiItem.alias.add(textController.text);
                  collectController
                      .updateLocalCollect(infoController.bangumiItem);
                  KazumiDialog.dismiss();
                  queryManager.querySource(textController.text, pluginName);
                }
              },
              child: const Text(
                '确认',
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<String> tabs = <String>['Tab 1', 'Tab 2'];
    return PopScope(
      canPop: true,
      child: DefaultTabController(
        length: tabs.length, // This is the number of tabs.
        child: Scaffold(
          body: NestedScrollView(
            controller: scrollController,
            headerSliverBuilder:
                (BuildContext context, bool innerBoxIsScrolled) {
              return <Widget>[
                SliverOverlapAbsorber(
                  handle:
                      NestedScrollView.sliverOverlapAbsorberHandleFor(context),
                  sliver: SliverAppBar.medium(
                    title: EmbeddedNativeControlArea(
                      child: Text(
                        infoController.bangumiItem.nameCn == ''
                            ? infoController.bangumiItem.name
                            : infoController.bangumiItem.nameCn,
                      ),
                    ),
                    automaticallyImplyLeading: false,
                    scrolledUnderElevation: 0.0,
                    leading: EmbeddedNativeControlArea(
                      child: IconButton(
                        onPressed: () {
                          Navigator.maybePop(context);
                        },
                        icon: Icon(Icons.arrow_back),
                      ),
                    ),
                    toolbarHeight: kToolbarHeight + 22,
                    stretch: true,
                    centerTitle: false,
                    expandedHeight: 350 + kTextTabBarHeight + kToolbarHeight + 30,
                    collapsedHeight: kTextTabBarHeight + kToolbarHeight + 22,
                    flexibleSpace: FlexibleSpaceBar(
                      background: Stack(
                        children: [
                          if (!Platform.isLinux)
                            Positioned.fill(
                              bottom: kTextTabBarHeight,
                              child: IgnorePointer(
                                child: Container(
                                  color: Theme.of(context)
                                      .appBarTheme
                                      .backgroundColor,
                                  child: Opacity(
                                    opacity: 0.2,
                                    child: LayoutBuilder(
                                        builder: (context, boxConstraints) {
                                      return ImageFiltered(
                                        imageFilter: ImageFilter.blur(
                                            sigmaX: 15.0, sigmaY: 15.0),
                                        child: NetworkImgLayer(
                                          src: infoController.bangumiItem
                                                  .images['large'] ??
                                              '',
                                          width: boxConstraints.maxWidth,
                                          height: boxConstraints.maxHeight,
                                          fadeInDuration:
                                              const Duration(milliseconds: 0),
                                          fadeOutDuration:
                                              const Duration(milliseconds: 0),
                                        ),
                                      );
                                    }),
                                  ),
                                ),
                              ),
                            ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 78, 16, 0),
                            child: BangumiInfoCardV(
                                bangumiItem: infoController.bangumiItem),
                          ),
                        ],
                      ),
                    ),
                    forceElevated: innerBoxIsScrolled,
                    bottom: TabBar(
                      // These are the widgets to put in each tab in the tab bar.
                      tabs: tabs.map((String name) => Tab(text: name)).toList(),
                    ),
                  ),
                ),
              ];
            },
            body: TabBarView(
              // These are the contents of the tab views, below the tabs.
              children: tabs.map((String name) {
                return SafeArea(
                  top: false,
                  bottom: false,
                  child: Builder(
                    // This Builder is needed to provide a BuildContext that is
                    // "inside" the NestedScrollView, so that
                    // sliverOverlapAbsorberHandleFor() can find the
                    // NestedScrollView.
                    builder: (BuildContext context) {
                      return CustomScrollView(
                        // The "controller" and "primary" members should be left
                        // unset, so that the NestedScrollView can control this
                        // inner scroll view.
                        // If the "controller" property is set, then this scroll
                        // view will not be associated with the NestedScrollView.
                        // The PageStorageKey should be unique to this ScrollView;
                        // it allows the list to remember its scroll position when
                        // the tab view is not on the screen.
                        key: PageStorageKey<String>(name),
                        slivers: <Widget>[
                          SliverOverlapInjector(
                            // This is the flip side of the SliverOverlapAbsorber
                            // above.
                            handle:
                                NestedScrollView.sliverOverlapAbsorberHandleFor(
                                    context),
                          ),
                          SliverPadding(
                            padding: const EdgeInsets.all(8.0),
                            // In this example, the inner scroll view has
                            // fixed-height list items, hence the use of
                            // SliverFixedExtentList. However, one could use any
                            // sliver widget here, e.g. SliverList or SliverGrid.
                            sliver: SliverFixedExtentList(
                              // The items in this example are fixed to 48 pixels
                              // high. This matches the Material Design spec for
                              // ListTile widgets.
                              itemExtent: 48.0,
                              delegate: SliverChildBuilderDelegate(
                                (BuildContext context, int index) {
                                  // This builder is called for each child.
                                  // In this example, we just number each list item.
                                  return ListTile(title: Text('Item $index'));
                                },
                                // The childCount of the SliverChildBuilderDelegate
                                // specifies how many children this inner list
                                // has. In this example, each tab has a list of
                                // exactly 30 items, but this is arbitrary.
                                childCount: 30,
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ),
      // Scaffold(
      //   backgroundColor: Colors.transparent,
      //   appBar: SysAppBar(
      //     backgroundColor: Colors.transparent,
      //   ),
      //   body: Column(
      //     children: [
      //       BangumiInfoCardV(bangumiItem: infoController.bangumiItem),
      //       TabBar(
      //         isScrollable: true,
      //         tabAlignment: TabAlignment.center,
      //         controller: tabController,
      //         tabs: pluginsController.pluginList
      //             .map((plugin) => Observer(
      //                   builder: (context) => Row(
      //                     mainAxisSize: MainAxisSize.min,
      //                     children: [
      //                       Text(
      //                         plugin.name,
      //                         overflow: TextOverflow.ellipsis,
      //                         style: TextStyle(
      //                             fontSize: Theme.of(context)
      //                                 .textTheme
      //                                 .titleMedium!
      //                                 .fontSize,
      //                             color: Theme.of(context)
      //                                 .colorScheme
      //                                 .onSurface),
      //                       ),
      //                       const SizedBox(width: 5.0),
      //                       Container(
      //                         width: 8.0,
      //                         height: 8.0,
      //                         decoration: BoxDecoration(
      //                           color: infoController.pluginSearchStatus[
      //                                       plugin.name] ==
      //                                   'success'
      //                               ? Colors.green
      //                               : (infoController.pluginSearchStatus[
      //                                           plugin.name] ==
      //                                       'pending')
      //                                   ? Colors.grey
      //                                   : Colors.red,
      //                           shape: BoxShape.circle,
      //                         ),
      //                       ),
      //                     ],
      //                   ),
      //                 ))
      //             .toList(),
      //       ),
      //       Expanded(
      //         child: Observer(
      //           builder: (context) => TabBarView(
      //             controller: tabController,
      //             children: List.generate(
      //                 pluginsController.pluginList.length, (pluginIndex) {
      //               var plugin = pluginsController.pluginList[pluginIndex];
      //               var cardList = <Widget>[];
      //               for (var searchResponse
      //                   in infoController.pluginSearchResponseList) {
      //                 if (searchResponse.pluginName == plugin.name) {
      //                   for (var searchItem in searchResponse.data) {
      //                     cardList.add(Card(
      //                       color: Colors.transparent,
      //                       child: ListTile(
      //                         tileColor: Colors.transparent,
      //                         title: Text(searchItem.name),
      //                         onTap: () async {
      //                           KazumiDialog.showLoading(msg: '获取中');
      //                           videoPageController.currentPlugin = plugin;
      //                           videoPageController.title = searchItem.name;
      //                           videoPageController.src = searchItem.src;
      //                           try {
      //                             await infoController.queryRoads(
      //                                 searchItem.src, plugin.name);
      //                             KazumiDialog.dismiss();
      //                             Modular.to.pushNamed('/video/');
      //                           } catch (e) {
      //                             KazumiLogger()
      //                                 .log(Level.error, e.toString());
      //                             KazumiDialog.dismiss();
      //                           }
      //                         },
      //                       ),
      //                     ));
      //                   }
      //                 }
      //               }
      //               return infoController.pluginSearchStatus[plugin.name] ==
      //                       'pending'
      //                   ? const Center(child: CircularProgressIndicator())
      //                   : (infoController.pluginSearchStatus[plugin.name] ==
      //                           'error'
      //                       ? GeneralErrorWidget(
      //                           errMsg:
      //                               '${plugin.name} 检索失败 重试或左右滑动以切换到其他视频来源',
      //                           actions: [
      //                             GeneralErrorButton(
      //                               onPressed: () {
      //                                 queryManager.querySource(
      //                                     keyword, plugin.name);
      //                               },
      //                               text: '重试',
      //                             ),
      //                           ],
      //                         )
      //                       : cardList.isEmpty
      //                           ? GeneralErrorWidget(
      //                               errMsg:
      //                                   '${plugin.name} 无结果 使用别名或左右滑动以切换到其他视频来源',
      //                               actions: [
      //                                 GeneralErrorButton(
      //                                   onPressed: () {
      //                                     showAliasSearchDialog(
      //                                       plugin.name,
      //                                     );
      //                                   },
      //                                   text: '别名检索',
      //                                 ),
      //                                 GeneralErrorButton(
      //                                   onPressed: () {
      //                                     showCustomSearchDialog(
      //                                       plugin.name,
      //                                     );
      //                                   },
      //                                   text: '手动检索',
      //                                 ),
      //                               ],
      //                             )
      //                           : ListView(children: cardList));
      //             }),
      //           ),
      //         ),
      //       )
      //     ],
      //   ),
      //   floatingActionButton: FloatingActionButton(
      //     child: const Icon(Icons.widgets_rounded),
      //     onPressed: () async {
      //       showModalBottomSheet(
      //           isScrollControlled: true,
      //           constraints: BoxConstraints(
      //               maxHeight: MediaQuery.of(context).size.height * 3 / 4,
      //               maxWidth: (Utils.isDesktop() || Utils.isTablet())
      //                   ? MediaQuery.of(context).size.width * 9 / 16
      //                   : MediaQuery.of(context).size.width),
      //           clipBehavior: Clip.antiAlias,
      //           context: context,
      //           builder: (context) {
      //             return const CommentsBottomSheet();
      //           });
      //     },
      //   ),
      // ),
    );
  }
}
