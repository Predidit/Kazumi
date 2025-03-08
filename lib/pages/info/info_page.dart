import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/bean/widget/collect_button.dart';
import 'package:kazumi/bean/widget/embedded_native_control_area.dart';
import 'package:kazumi/utils/constants.dart';
import 'package:kazumi/utils/storage.dart';
import 'package:kazumi/bean/widget/error_widget.dart';
import 'package:kazumi/pages/collect/collect_controller.dart';
import 'package:kazumi/pages/info/info_controller.dart';
import 'package:kazumi/bean/card/bangumi_info_card.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:kazumi/pages/info/source_sheet.dart';
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
        infoController.bangumiItem.votes == 0) {
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
    final List<String> tabs = <String>['概览', '吐槽', '角色', '制作人员'];
    final bool showWindowButton = GStorage.setting
        .get(SettingBoxKey.showWindowButton, defaultValue: false);
    return PopScope(
      canPop: true,
      child: DefaultTabController(
        length: tabs.length, // This is the number of tabs.
        child: Scaffold(
          body: NestedScrollView(
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
                    actions: [
                      if (innerBoxIsScrolled)
                        EmbeddedNativeControlArea(
                          child: CollectButton(
                            bangumiItem: infoController.bangumiItem,
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      EmbeddedNativeControlArea(
                        child: IconButton(
                          onPressed: () {
                            launchUrl(
                              Uri.parse(
                                  'https://bangumi.tv/subject/${infoController.bangumiItem.id}'),
                            );
                          },
                          icon: const Icon(Icons.open_in_browser),
                        ),
                      ),
                      SizedBox(width: 8),
                    ],
                    toolbarHeight: (Platform.isMacOS && showWindowButton)
                        ? kToolbarHeight + 22
                        : kToolbarHeight,
                    stretch: true,
                    centerTitle: false,
                    expandedHeight: (Platform.isMacOS && showWindowButton)
                        ? 350 + kTextTabBarHeight + kToolbarHeight + 22
                        : 350 + kTextTabBarHeight + kToolbarHeight,
                    collapsedHeight: (Platform.isMacOS && showWindowButton)
                        ? kTextTabBarHeight +
                            kToolbarHeight +
                            MediaQuery.paddingOf(context).top +
                            22
                        : kTextTabBarHeight +
                            kToolbarHeight +
                            MediaQuery.paddingOf(context).top,
                    flexibleSpace: FlexibleSpaceBar(
                      collapseMode: CollapseMode.pin,
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
                                      },
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          SafeArea(
                            left: false,
                            right: false,
                            bottom: false,
                            child: EmbeddedNativeControlArea(
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(
                                    16, kToolbarHeight, 16, 0),
                                child: BangumiInfoCardV(
                                    bangumiItem: infoController.bangumiItem),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    forceElevated: innerBoxIsScrolled,
                    bottom: TabBar(
                      isScrollable: true,
                      tabAlignment: TabAlignment.center,
                      dividerHeight: 0,
                      controller: tabController,
                      tabs: tabs.map((name) => Tab(text: name)).toList(),
                    ),
                  ),
                ),
              ];
            },
            body: TabBarView(
              children: tabs.map((name) {
                return Builder(
                  // This Builder is needed to provide a BuildContext that is
                  // "inside" the NestedScrollView, so that
                  // sliverOverlapAbsorberHandleFor() can find the
                  // NestedScrollView.
                  builder: (BuildContext context) {
                    return CustomScrollView(
                      // The PageStorageKey should be unique to this ScrollView;
                      // it allows the list to remember its scroll position when
                      // the tab view is not on the screen.
                      key: PageStorageKey<String>(name),
                      slivers: <Widget>[
                        SliverOverlapInjector(
                          handle:
                              NestedScrollView.sliverOverlapAbsorberHandleFor(
                                  context),
                        ),
                        SliverToBoxAdapter(
                          child: SelectionArea(
                            child: Padding(
                              padding: const EdgeInsets.all(10.0),
                              child: SingleChildScrollView(
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(infoController.bangumiItem.summary),
                                      Text(infoController.bangumiItem.summary),
                                      const SizedBox(height: 8),
                                      Wrap(
                                          spacing: 8.0,
                                          runSpacing: Utils.isDesktop() ? 8 : 0,
                                          children: List<Widget>.generate(
                                              infoController.bangumiItem.tags
                                                  .length, (int index) {
                                            return Chip(
                                              label: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Text(
                                                      '${infoController.bangumiItem.tags[index].name} '),
                                                  Text(
                                                    '${infoController.bangumiItem.tags[index].count}',
                                                    style: TextStyle(
                                                        color: Theme.of(context)
                                                            .colorScheme
                                                            .primary),
                                                  ),
                                                ],
                                              ),
                                            );
                                          }).toList())
                                    ]),
                              ),
                            ),
                          ),
                        )
                      ],
                    );
                  },
                );
              }).toList(),
            ),
          ),
          floatingActionButton: FloatingActionButton.extended(
            icon: const Icon(Icons.play_arrow_rounded),
            label: Text('开始观看'),
            onPressed: () async {
              showModalBottomSheet(
                isScrollControlled: true,
                constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 3 / 4,
                    maxWidth: (MediaQuery.sizeOf(context).width >=
                            LayoutBreakpoint.medium['width']!)
                        ? MediaQuery.of(context).size.width * 9 / 16
                        : MediaQuery.of(context).size.width),
                clipBehavior: Clip.antiAlias,
                context: context,
                builder: (context) {
                  return const SourceSheet();
                },
              );
            },
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
