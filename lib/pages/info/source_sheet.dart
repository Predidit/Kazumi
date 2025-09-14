import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
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
    required this.infoController,
  });

  final TabController tabController;
  final InfoController infoController;

  @override
  State<SourceSheet> createState() => _SourceSheetState();
}

class _SourceSheetState extends State<SourceSheet> with SingleTickerProviderStateMixin {
  bool _showTabGrid = false;
  final VideoPageController videoPageController =
      Modular.get<VideoPageController>();
  final CollectController collectController = Modular.get<CollectController>();
  final PluginsController pluginsController = Modular.get<PluginsController>();
  late String keyword;

  /// Concurrent query manager
  QueryManager? queryManager;

  @override
  void initState() {
    keyword = widget.infoController.bangumiItem.nameCn == ''
        ? widget.infoController.bangumiItem.name
        : widget.infoController.bangumiItem.nameCn;
    if (widget.infoController.pluginSearchResponseList.isEmpty) {
      queryManager = QueryManager(infoController: widget.infoController);
      queryManager?.queryAllSource(keyword);
    }
    super.initState();
  }

  @override
  void dispose() {
    queryManager?.cancel();
    super.dispose();
  }

  void showAliasSearchDialog(String pluginName) {
    if (widget.infoController.bangumiItem.alias.isEmpty) {
      KazumiDialog.showToast(message: '无可用别名，试试手动检索');
      return;
    }
    final aliasNotifier =
        ValueNotifier<List<String>>(widget.infoController.bangumiItem.alias);
    KazumiDialog.show(builder: (context) {
      return Dialog(
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          width: 560,
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
                                        widget.infoController.bangumiItem);
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
                      queryManager?.querySource(alias, pluginName);
                    },
                  );
                }).toList(),
              );
            },
          ),
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
                widget.infoController.bangumiItem.alias
                    .add(textController.text);
                KazumiDialog.dismiss();
                queryManager?.querySource(textController.text, pluginName);
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
                  widget.infoController.bangumiItem.alias
                      .add(textController.text);
                  collectController
                      .updateLocalCollect(widget.infoController.bangumiItem);
                  KazumiDialog.dismiss();
                  queryManager?.querySource(textController.text, pluginName);
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
            Expanded(
              child: Observer(
                builder: (context) => TabBarView(
                  controller: widget.tabController,
                  children: List.generate(pluginsController.pluginList.length,
                      (pluginIndex) {
                    var plugin = pluginsController.pluginList[pluginIndex];
                    var cardList = <Widget>[];
                    for (var searchResponse
                        in widget.infoController.pluginSearchResponseList) {
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
                                  videoPageController.bangumiItem =
                                      widget.infoController.bangumiItem;
                                  videoPageController.currentPlugin = plugin;
                                  videoPageController.title = searchItem.name;
                                  videoPageController.src = searchItem.src;
                                  try {
                                    await videoPageController.queryRoads(
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
                    return widget.infoController
                                .pluginSearchStatus[plugin.name] ==
                            'pending'
                        ? const Center(child: CircularProgressIndicator())
                        : (widget.infoController
                                    .pluginSearchStatus[plugin.name] ==
                                'error'
                            ? GeneralErrorWidget(
                                errMsg: '${plugin.name} 检索失败 重试或左右滑动以切换到其他视频来源',
                                actions: [
                                  GeneralErrorButton(
                                    onPressed: () {
                                      queryManager?.querySource(
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
            ),
            const Divider(height: 1),
            Listener(
              onPointerSignal: (event) {
                if (event is PointerScrollEvent) {
                  if (!_showTabGrid && event.scrollDelta.dy < -8) {
                    setState(() {
                      _showTabGrid = true;
                    });
                  }
                  // else if (_showTabGrid && event.scrollDelta.dy > 8) {
                  //   setState(() {
                  //     _showTabGrid = false;
                  //   });
                  // }
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                height: _showTabGrid ? 330 : 56,
                child: Stack(
                  children: [
                    // TabBar（收起时显示）
                    AnimatedOpacity(
                      opacity: _showTabGrid ? 0 : 1,
                      duration: const Duration(milliseconds: 200),
                      child: GestureDetector(
                        onVerticalDragUpdate: (details) {
                          if (details.primaryDelta != null && details.primaryDelta! < -8) {
                            setState(() {
                              _showTabGrid = true;
                            });
                          }
                        },
                        behavior: HitTestBehavior.opaque,
                        child: Row(
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8.0),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(16),
                                onTap: () {
                                  setState(() {
                                    _showTabGrid = true;
                                  });
                                },
                                child: const Icon(Icons.keyboard_arrow_up),
                              ),
                            ),
                            Expanded(
                              child: TabBar(
                                isScrollable: true,
                                tabAlignment: TabAlignment.center,
                                dividerHeight: 0,
                                controller: widget.tabController,
                                //需要自定义Tab指示条到上方，待完成
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
                                                  color: widget.infoController
                                                                  .pluginSearchStatus[
                                                              plugin.name] ==
                                                          'success'
                                                      ? Colors.green
                                                      : (widget.infoController
                                                                      .pluginSearchStatus[
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
                      ),
                    ),
                    // 展开时显示的按钮网格
                    AnimatedOpacity(
                      opacity: _showTabGrid ? 1 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: _showTabGrid
                          ? GestureDetector(
                              onVerticalDragUpdate: (details) {
                                if (details.primaryDelta != null && details.primaryDelta! > 8) {
                                  setState(() {
                                    _showTabGrid = false;
                                  });
                                }
                              },
                              behavior: HitTestBehavior.opaque,
                              child: Container(
                                color: Theme.of(context).scaffoldBackgroundColor,
                                child: Column(
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Container(
                                            width: 40,
                                            height: 4,
                                            decoration: BoxDecoration(
                                              color: Colors.grey[400],
                                              borderRadius: BorderRadius.circular(2),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Expanded(
                                      child: SingleChildScrollView(
                                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                                        child: Wrap(
                                          spacing: 8,
                                          runSpacing: 8,
                                          children: List.generate(
                                            pluginsController.pluginList.length,
                                            (i) => ActionChip(
                                              label: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Text(
                                                    pluginsController.pluginList[i].name,
                                                    overflow: TextOverflow.ellipsis,
                                                    style: TextStyle(
                                                      fontSize: 15,
                                                      color: widget.tabController.index == i
                                                          ? Theme.of(context).colorScheme.onPrimary
                                                          : Theme.of(context).colorScheme.onSurface,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Container(
                                                    width: 8.0,
                                                    height: 8.0,
                                                    decoration: BoxDecoration(
                                                      color: widget.infoController.pluginSearchStatus[pluginsController.pluginList[i].name] == 'success'
                                                          ? Colors.green
                                                          : (widget.infoController.pluginSearchStatus[pluginsController.pluginList[i].name] == 'pending')
                                                              ? Colors.grey
                                                              : Colors.red,
                                                      shape: BoxShape.circle,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              backgroundColor: widget.tabController.index == i
                                                  ? Theme.of(context).colorScheme.primary
                                                  : Theme.of(context).colorScheme.surfaceContainerLow,
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(20),
                                              ),
                                              onPressed: () {
                                                setState(() {
                                                  widget.tabController.index = i;
                                                  _showTabGrid = false;
                                                });
                                              },
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : const SizedBox.shrink(),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
