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
import 'package:kazumi/request/query_manager.dart';
import 'package:kazumi/pages/collect/collect_controller.dart';
import 'package:kazumi/bean/widget/error_widget.dart';

class SourceSheet extends StatefulWidget {
  const SourceSheet({
    super.key,
    required this.tabController,
  });

  final TabController tabController;

  @override
  State<SourceSheet> createState() => _SourceSheetState();
}

class _SourceSheetState extends State<SourceSheet>
    with SingleTickerProviderStateMixin {
  final infoController = Modular.get<InfoController>();
  final VideoPageController videoPageController =
      Modular.get<VideoPageController>();
  final CollectController collectController = Modular.get<CollectController>();
  final PluginsController pluginsController = Modular.get<PluginsController>();
  late String keyword;

  /// Concurrent query manager
  late QueryManager queryManager;

  @override
  void initState() {
    keyword = infoController.bangumiItem.nameCn == ''
        ? infoController.bangumiItem.name
        : infoController.bangumiItem.nameCn;
    queryManager = QueryManager();
    if (infoController.pluginSearchResponseList.isEmpty) {
      queryManager.queryAllSource(keyword);
    }
    super.initState();
  }

  @override
  void dispose() {
    queryManager.cancel();
    super.dispose();
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
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        body: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TabBar(
                    isScrollable: true,
                    tabAlignment: TabAlignment.center,
                    dividerHeight: 0,
                    controller: widget.tabController,
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
                  ),
                ),
                IconButton(
                  onPressed: () {
                    int currentIndex = widget.tabController.index;
                    launchUrl(
                      Uri.parse(pluginsController
                          .pluginList[currentIndex].searchURL
                          .replaceFirst('@keyword', keyword)),
                      mode: LaunchMode.externalApplication,
                    );
                  },
                  icon: const Icon(Icons.open_in_browser_rounded),
                ),
                const SizedBox(width: 4),
              ],
            ),
            const Divider(height: 1),
            Expanded(
              child: Observer(
                builder: (context) => TabBarView(
                  controller: widget.tabController,
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
                              elevation: 0,
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
                    return infoController.pluginSearchStatus[plugin.name] ==
                            'pending'
                        ? const Center(child: CircularProgressIndicator())
                        : (infoController.pluginSearchStatus[plugin.name] ==
                                'error'
                            ? GeneralErrorWidget(
                                errMsg: '${plugin.name} 检索失败 重试或左右滑动以切换到其他视频来源',
                                actions: [
                                  GeneralErrorButton(
                                    onPressed: () {
                                      queryManager.querySource(
                                          keyword, plugin.name);
                                    },
                                    text: '重试',
                                  ),
                                ],
                              )
                            : cardList.isEmpty
                                ? GeneralErrorWidget(
                                    errMsg:
                                        '${plugin.name} 无结果 使用别名或左右滑动以切换到其他视频来源',
                                    actions: [
                                      GeneralErrorButton(
                                        onPressed: () {
                                          showAliasSearchDialog(
                                            plugin.name,
                                          );
                                        },
                                        text: '别名检索',
                                      ),
                                      GeneralErrorButton(
                                        onPressed: () {
                                          showCustomSearchDialog(
                                            plugin.name,
                                          );
                                        },
                                        text: '手动检索',
                                      ),
                                    ],
                                  )
                                : ListView(children: cardList));
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
