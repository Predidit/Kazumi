import 'package:flutter/material.dart';
import 'package:kazumi/utils/utils.dart';
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
    required this.scrollController,
    required this.tabGridHeight,
  });

  final TabController tabController;
  final InfoController infoController;
  final ScrollController scrollController;
  final double tabGridHeight;

  @override
  State<SourceSheet> createState() => _SourceSheetState();
}

class _SourceSheetState extends State<SourceSheet> with SingleTickerProviderStateMixin {
  bool expandedByScroll = false; //通过滚动展开
  var expandedByClick = 0; //通过点击展开
  bool _showOnlySuccess = false;
  final tabBarHeight = 48.0;
  void _maybeExpandTabGridOnListViewHeight(BoxConstraints constraints) {
    final screenHeight = MediaQuery.of(context).size.height;
    if (constraints.maxHeight >= screenHeight - tabBarHeight - 1 - 48 && !_showTabGrid && !expandedByScroll && expandedByClick !=2) { //48为小白条高度 手动点击按钮后不响应弹出
      WidgetsBinding.instance.addPostFrameCallback((_) {
        setState(() {
          _showTabGrid = true;
        expandedByScroll = true;
        });
      });
    } else if (constraints.maxHeight < screenHeight * ( 1 - widget.tabGridHeight ) - tabBarHeight - 1 - 48 - 40 && _showTabGrid &&expandedByScroll && expandedByClick !=1) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        setState(() {
          _showTabGrid = false;
        expandedByScroll = false;
        });
      });
    }
  }
  final ScrollController _tabGridScrollController = ScrollController();
  bool _showTabGrid = false;
  final VideoPageController videoPageController =
      Modular.get<VideoPageController>();
  final CollectController collectController = Modular.get<CollectController>();
  final PluginsController pluginsController = Modular.get<PluginsController>();
  final Map<int, MenuController> _menuControllers = {};
  late String keyword;

  /// Concurrent query manager
  QueryManager? queryManager;

  @override
  void initState() {
    keyword = widget.infoController.bangumiItem.nameCn == ''
        ? widget.infoController.bangumiItem.name
        : widget.infoController.bangumiItem.nameCn;
    queryManager = QueryManager(infoController: widget.infoController);
    queryManager?.queryAllSource(keyword);
    super.initState();
    widget.tabController.addListener(() {
      if (!mounted) return;
      setState(() {});
    });
  }

  @override
  void dispose() {
    _tabGridScrollController.dispose();
    queryManager?.cancel();
    queryManager = null;
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
            Listener(
              onPointerSignal: (event) {
                if (event is PointerScrollEvent) {
                  if (!_showTabGrid && (event.scrollDelta.dy.abs() > 8)) {
                    setState(() {
                      _showTabGrid = true;
                    });
                  } else if (_showTabGrid && (event.scrollDelta.dy.abs() > 8)) {
                    // 仅当面板内部无需滚动时才允许收起
                    final maxScroll = _tabGridScrollController.hasClients
                        ? _tabGridScrollController.position.maxScrollExtent
                        : 0.0;
                    if (maxScroll == 0.0) {
                      setState(() {
                        _showTabGrid = false;
                      });
                    }
                  }
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                    height: _showTabGrid ? MediaQuery.of(context).size.height * widget.tabGridHeight + tabBarHeight - 12 : tabBarHeight,
                child: Stack(
                  children: [
                    // TabBar（收起时显示）
                    AnimatedOpacity(
                      opacity: _showTabGrid ? 0 : 1,
                      duration: const Duration(milliseconds: 200),
                      child: SizedBox(
                        height: tabBarHeight,
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: Observer(
                                  builder: (context) => TabBar(
                                    isScrollable: true,
                                    tabAlignment: TabAlignment.center,
                                    dividerHeight: 0,
                                    controller: widget.tabController,
                                    labelPadding: const EdgeInsets.symmetric(horizontal: 10.0),
                                    indicatorColor: (() {
                                      final list = pluginsController.pluginList;
                                      final idx = widget.tabController.index;
                                      if (idx < 0 || idx >= list.length) {
                                        return Theme.of(context).colorScheme.secondary;
                                      }
                                      final status = widget.infoController.pluginSearchStatus[list[idx].name];
                                      return status == 'success'
                                          ? Theme.of(context).colorScheme.onSurface
                                          : Color.lerp(
                                              Theme.of(context).colorScheme.secondary,
                                              status == 'pending'
                                                  ? Colors.blueGrey
                                                  : status == 'noresult'
                                                      ? Colors.orange
                                                      : Colors.red,
                                              Theme.of(context).brightness == Brightness.dark ? 0.5 : 0.8,
                                            )!;
                                    })(),
                                    tabs: pluginsController.pluginList
                                        .asMap()
                                        .entries
                                        .map((entry) {
                                          final plugin = entry.value;
                                          final status = widget.infoController.pluginSearchStatus[plugin.name];
                                          return Tab(
                                              child: Text(
                                                plugin.name,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  fontSize: Theme.of(context)
                                                      .textTheme
                                                      .titleMedium!
                                                      .fontSize,
                                                  fontWeight: FontWeight.bold,
                                                  color: status == 'success'
                                                      ? Theme.of(context).colorScheme.onSurface
                                                      : Color.lerp(
                                                          Theme.of(context).colorScheme.onSurface,
                                                          status == 'pending'
                                                              ? Colors.blueGrey
                                                              : status == 'noresult'
                                                                  ? Colors.orange
                                                                  : Colors.red,
                                                          Theme.of(context).brightness == Brightness.dark ? 0.5 : 0.8,)
                                                ),
                                              ),
                                            );
                                        }).toList(),
                                  ),
                                ),
                            ),
                            // Fading background behind the expand button to increase contrast
                            Positioned(
                              right: 0,
                              top: 0,
                              bottom: 0,
                              width: 50,
                              child: IgnorePointer(
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.centerLeft,
                                      end: Alignment.centerRight,
                                      // left: gradual fade (transparent -> semi), right: fully opaque
                                      colors: [
                                        Theme.of(context).colorScheme.surface.withAlpha(0),
                                        Theme.of(context).colorScheme.surface.withAlpha(230),
                                        Theme.of(context).colorScheme.surface,
                                        Theme.of(context).colorScheme.surface,
                                      ],
                                      stops: const [0.0, 0.3, 0.5, 1.0],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Positioned(
                              right: 2,
                              top: 0,
                              bottom: 0,
                              child: IconButton(
                                onPressed: () {
                                  expandedByClick = 1;
                                  setState(() {
                                    _showTabGrid = true;
                                  });
                                },
                                icon: const Icon(Icons.keyboard_arrow_down),
                                tooltip: '展开',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // 展开时显示的按钮网格
                    AnimatedOpacity(
                      opacity: _showTabGrid ? 1 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: _showTabGrid
                          ? Container(
                              color: Theme.of(context).scaffoldBackgroundColor,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children:[
                                  Row(
                                    children:[
                                      Row(
                                        children: [
                                          SizedBox(width : 16),
                                          Tooltip(
                                            message:"点击打开规则管理",
                                            child: TextButton(
                                              onPressed: () {
                                                Modular.to.pushNamed('/settings/plugin/');
                                              },
                                              style: TextButton.styleFrom(
                                                padding: EdgeInsets.zero,
                                                minimumSize: const Size(0, 0),
                                              ),
                                              child: Text(
                                                '番源',
                                                style: TextStyle(
                                                  fontSize: 18,
                                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                                ),
                                              ),
                                            )
                                          ),
                                        ]
                                      ),
                                      Spacer(),
                                      Row(
                                        children: [
                                          IconButton(
                                            onPressed: () {
                                              setState(() {
                                                _showOnlySuccess = !_showOnlySuccess;
                                              });
                                            },
                                            icon: Icon(_showOnlySuccess ? Icons.filter_alt : Icons.filter_alt_outlined,),
                                            tooltip: '筛选有结果项',
                                          ),
                                          IconButton(
                                            onPressed: () {
                                              expandedByClick = 2;
                                              setState(() {
                                                _showTabGrid = false;
                                              });},
                                            icon: const Icon(Icons.keyboard_arrow_up),
                                            tooltip: '收起',
                                          ),
                                          SizedBox(width: 2),
                                        ]
                                      ),
                                    ]
                                  ),
                                  Expanded(
                                    child: ScrollConfiguration(
                                      behavior: const ScrollBehavior().copyWith(scrollbars: false),
                                      child:SingleChildScrollView(
                                        controller: _tabGridScrollController,
                                        physics: const ClampingScrollPhysics(),
                                        padding: const EdgeInsets.fromLTRB(16, 2, 16, 16),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Observer(
                                              builder: (_) {
                                                // 根据筛选条件生成要显示的插件列表
                                                final visiblePluginsWithIndex = pluginsController.pluginList
                                                  .asMap()
                                                  .entries
                                                  .where((entry) {
                                                    final plugin = entry.value;
                                                    final status = widget.infoController.pluginSearchStatus[plugin.name];
                                                    if (_showOnlySuccess) return status == 'success';
                                                    return true;
                                                  })
                                                  .toList(); // entry.key = 原始索引

                                                return Wrap(
                                                  spacing: 8,
                                                  runSpacing: 8,
                                                  alignment: WrapAlignment.start,
                                                  children: visiblePluginsWithIndex.map((entry){
                                                    final originalIndex = entry.key;
                                                    final plugin = entry.value;
                                                    final status = widget.infoController.pluginSearchStatus[plugin.name];

                                                    return DragTarget<int>(
                                                      onAcceptWithDetails: (details) async {
                                                        final fromIndex = details.data;
                                                        // 如果拖放到自身，则弹出菜单而不是进行排序
                                                        if (fromIndex == originalIndex) {
                                                          widget.tabController.index = originalIndex;
                                                          final controller = _menuControllers[originalIndex];
                                                          if (controller != null) {
                                                            controller.open();
                                                            return;
                                                          }
                                                        }
                                                        final targetIndex = originalIndex;
                                                        setState(() {
                                                          final item = pluginsController.pluginList.removeAt(fromIndex);
                                                          pluginsController.pluginList.insert(targetIndex, item);
                                                          // menu controllers keyed by indices may now be stale; clear so they'll be re-cached
                                                          _menuControllers.clear();
                                                        });
                                                        // Persist the new plugin order so it survives restarts
                                                        pluginsController.savePlugins();
                                                        widget.tabController.index = targetIndex;
                                                      },
                                                      builder: (context, candidateData, rejectedData) {
                                                        return MenuAnchor(
                                                          menuChildren: [
                                                            MenuItemButton(
                                                              onPressed: () {
                                                                queryManager?.querySource(keyword, plugin.name);
                                                              },
                                                              child: Row(
                                                                children: [
                                                                  Icon(Icons.refresh),
                                                                  SizedBox(width: 8),
                                                                  Text('重新检索'),
                                                                ],
                                                              ),
                                                            ),
                                                            MenuItemButton(
                                                              onPressed: () {
                                                                showAliasSearchDialog(pluginsController.pluginList[widget.tabController.index].name);
                                                              },
                                                              child: Row(
                                                                children: [
                                                                  Icon(Icons.saved_search_rounded),
                                                                  SizedBox(width: 8),
                                                                  Text('别名检索'),
                                                                ],
                                                              ),
                                                            ),
                                                            MenuItemButton(
                                                              onPressed: () {
                                                                showCustomSearchDialog(pluginsController.pluginList[widget.tabController.index].name);
                                                              },
                                                              child: Row(
                                                                children: [
                                                                  Icon(Icons.search_rounded),
                                                                  SizedBox(width: 8),
                                                                  Text('手动检索'),
                                                                ],
                                                              ),
                                                            ),
                                                            MenuItemButton(
                                                              onPressed: () {
                                                                launchUrl(
                                                                  Uri.parse(pluginsController.pluginList[widget.tabController.index].searchURL.replaceFirst('@keyword', keyword)),
                                                                  mode: LaunchMode.externalApplication,
                                                                );
                                                              },
                                                              child: Row(
                                                                children: [
                                                                  Icon(Icons.open_in_browser_rounded),
                                                                  SizedBox(width: 8),
                                                                  Text('打开网页'),
                                                                ],
                                                              ),
                                                            ),
                                                            MenuItemButton(
                                                              onPressed: () {
                                                                Modular.to.pushNamed('/settings/plugin/');
                                                              },
                                                              child: Row(
                                                                children: [
                                                                  Icon(Icons.extension),
                                                                  SizedBox(width: 8),
                                                                  Text('规则管理'),
                                                                ],
                                                              ),
                                                            ),
                                                          ],
                                                          builder: (context, controller, child) {
                                                            // cache controller so we can open the same menu on drop
                                                            _menuControllers[originalIndex] = controller;
                                                            return GestureDetector(
                                                              onSecondaryTap: () {
                                                                widget.tabController.index = originalIndex;
                                                                controller.open();
                                                              },
                                                              onLongPress: () {
                                                                widget.tabController.index = originalIndex;
                                                                controller.open();
                                                              },
                                                              child: child,
                                                            );
                                                          },
                                                          child: LongPressDraggable<int>(
                                                            data: originalIndex,
                                                            feedback: Material(
                                                              color: Colors.transparent,
                                                              child: ActionChip(
                                                                label: Text(
                                                                  plugin.name,
                                                                  overflow: TextOverflow.ellipsis,
                                                                  style: TextStyle(fontSize: 15),
                                                                ),
                                                              ),
                                                            ),
                                                            childWhenDragging: Opacity(
                                                              opacity: 0.4,
                                                              child: ActionChip(
                                                                label: Text(
                                                                  plugin.name,
                                                                  overflow: TextOverflow.ellipsis,
                                                                  style: TextStyle(fontSize: 15),
                                                                ),
                                                              ),
                                                            ),
                                                            child: ActionChip(
                                                              label: Text(
                                                                plugin.name,
                                                                overflow: TextOverflow.ellipsis,
                                                                style: TextStyle(
                                                                  fontSize: 15,
                                                                  color: widget.tabController.index == originalIndex
                                                                      ? status == 'success'
                                                                          ? Theme.of(context).colorScheme.surface
                                                                          : Color.lerp(
                                                                              Theme.of(context).colorScheme.surface,
                                                                              status == 'pending' ? Colors.blueGrey : status == 'noresult' ? Colors.orange : Colors.red,
                                                                              0.15,
                                                                            )
                                                                      : null,
                                                                ),
                                                              ),
                                                              backgroundColor: widget.tabController.index == originalIndex
                                                                  ? status == 'success'
                                                                      ? Theme.of(context).colorScheme.onSurface
                                                                      : Color.lerp(
                                                                          Theme.of(context).colorScheme.onSurface,
                                                                          status == 'pending' ? Colors.blueGrey : status == 'noresult' ? Colors.orange : Colors.red,
                                                                          Theme.of(context).brightness == Brightness.dark ? 0.5 : 0.8,
                                                                        )
                                                                  : status == 'success'
                                                                      ? null
                                                                      : Color.lerp(
                                                                          null,
                                                                          status == 'pending' ? Colors.blueGrey : status == 'noresult' ? Colors.orange : Colors.red,
                                                                          0.075,
                                                                        ),
                                                              shape: RoundedRectangleBorder(
                                                                borderRadius: BorderRadius.circular(9),
                                                                side: BorderSide(
                                                                  color: status == 'success'
                                                                      ? Color.lerp(Theme.of(context).colorScheme.outlineVariant, Theme.of(context).colorScheme.secondary, 0.15)!
                                                                      : Color.lerp(
                                                                          Theme.of(context).colorScheme.outlineVariant,
                                                                          status == 'pending' ? Colors.blueGrey : status == 'noresult' ? Colors.orange : Colors.red,
                                                                          0.15,
                                                                        )!,
                                                                ),
                                                              ),
                                                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                                              onPressed: () {
                                                                widget.tabController.index = originalIndex;
                                                              },
                                                            ),
                                                          ),
                                                        );
                                                      },
                                                    );
                                                  }).toList(),
                                                );
                                              }
                                            )
                                          ],
                                        )
                                      ),
                                    ),
                                  ),
                                ]
                              ),
                            )
                          : const SizedBox.shrink(),
                    ),
                  ],
                ),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  _maybeExpandTabGridOnListViewHeight(constraints);
                  return Observer(
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
                                  KazumiDialog.showLoading(
                                    msg: '获取中',
                                    barrierDismissible: Utils.isDesktop(),
                                    onDismiss: () {
                                      videoPageController.cancelQueryRoads();
                                    },
                                  );
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
                                      } catch (_) {
                                        KazumiLogger()
                                            .log(Level.warning, "获取视频播放列表失败");
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
                            ? SingleChildScrollView(
                                controller: widget.scrollController,
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(
                                    minHeight: MediaQuery.of(context).size.height * (1 - widget.tabGridHeight) * 0.75,
                                  ),
                                  child: const Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                ),
                              )
                            : (widget.infoController
                                        .pluginSearchStatus[plugin.name] ==
                                    'error'
                                ? SingleChildScrollView(
                                    controller: widget.scrollController,
                                    child: ConstrainedBox(
                                      constraints: BoxConstraints(
                                        minHeight: MediaQuery.of(context).size.height * (1 - widget.tabGridHeight) * 0.75,
                                      ),
                                      child: Center(
                                        child: GeneralErrorWidget(
                                          errMsg: '${plugin.name} 检索失败 重试或左右滑动以切换到其他视频来源',
                                          actions: [
                                            GeneralErrorButton(
                                              onPressed: () {
                                                queryManager?.querySource(keyword, plugin.name);
                                              },
                                              text: '重试',
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  )

                                : (widget.infoController
                                        .pluginSearchStatus[plugin.name] ==
                                    'noresult'
                                    ? SingleChildScrollView(
                                        controller: widget.scrollController,
                                        child: ConstrainedBox(
                                          constraints: BoxConstraints(
                                            minHeight: MediaQuery.of(context).size.height * (1 - widget.tabGridHeight) * 0.75,
                                          ),
                                          child: Center(
                                            child: GeneralErrorWidget(
                                              errMsg: '${plugin.name} 无结果 使用别名或左右滑动以切换到其他视频来源',
                                              actions: [
                                                GeneralErrorButton(
                                                  onPressed: () {
                                                    showAliasSearchDialog(plugin.name);
                                                  },
                                                  text: '别名检索',
                                                ),
                                                GeneralErrorButton(
                                                  onPressed: () {
                                                    showCustomSearchDialog(plugin.name);
                                                  },
                                                  text: '手动检索',
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      )
                                    : ListView(
                                        controller: widget.scrollController,
                                        children: cardList,
                                      )
                                  )
                                );
                      }),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
