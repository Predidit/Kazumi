import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:mobx/mobx.dart';
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
import 'package:kazumi/pages/info/episode_selector.dart';
import 'package:kazumi/modules/roads/road_module.dart';
import 'package:kazumi/repositories/video_source_repository.dart';

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

class _SourceSheetState extends State<SourceSheet>
    with SingleTickerProviderStateMixin {
  final VideoPageController videoPageController =
      Modular.get<VideoPageController>();
  final CollectController collectController = Modular.get<CollectController>();
  final PluginsController pluginsController = Modular.get<PluginsController>();
  final IVideoSourceRepository videoSourceRepository =
      Modular.get<IVideoSourceRepository>();
  late String keyword;

  /// Concurrent query manager
  QueryManager? queryManager;

  /// 当前展开的搜索结果索引（用于显示集数选择器）
  String? expandedCardKey;

  /// 当前加载的播放列表
  List<Road>? currentRoadList;

  /// 是否正在加载播放列表
  bool isLoadingRoads = false;

  @override
  void initState() {
    keyword = widget.infoController.bangumiItem.nameCn == ''
        ? widget.infoController.bangumiItem.name
        : widget.infoController.bangumiItem.nameCn;
    queryManager = QueryManager(infoController: widget.infoController);
    queryManager?.queryAllSource(keyword);
    super.initState();
  }

  @override
  void dispose() {
    queryManager?.cancel();
    queryManager = null;
    super.dispose();
  }

  /// 响应式等待播放列表加载完成（使用 MobX reaction）
  Future<void> _waitForRoadListLoadedViaRepository(String cardKey, String src) async {
    final completer = Completer<void>();
    ReactionDisposer? dispose;

    try {
      // 使用 MobX reaction 响应式监听状态变化
      dispose = reaction<RoadListLoadStatus>(
        (_) => videoSourceRepository.getLoadStatus(src),
        (status) {
          // 如果用户已经切换到其他卡片，取消等待
          if (expandedCardKey != cardKey) {
            if (!completer.isCompleted) {
              completer.complete();
            }
            return;
          }

          // 状态变化为非 pending 时完成
          if (status != RoadListLoadStatus.pending) {
            if (!completer.isCompleted) {
              completer.complete();
            }
          }
        },
      );

      // 最多等待10秒
      await completer.future.timeout(const Duration(seconds: 10));

      // 检查用户是否已经切换到其他卡片
      if (expandedCardKey != cardKey) {
        return;
      }

      final cached = videoSourceRepository.getRoadList(src);
      final status = videoSourceRepository.getLoadStatus(src);

      if (cached != null && status == RoadListLoadStatus.success) {
        // 加载成功，更新UI
        setState(() {
          currentRoadList = List.from(cached.roadList);
          isLoadingRoads = false;
        });
        // 同步到 videoPageController（使用封装方法）
        videoPageController.updateRoadList(cached.roadList);
      } else if (status == RoadListLoadStatus.error) {
        // 加载失败
        setState(() {
          isLoadingRoads = false;
          expandedCardKey = null;
        });
        KazumiDialog.showToast(
            message: '获取播放列表失败：${cached?.errorMessage ?? "未知错误"}');
      }
    } catch (e) {
      // 超时或其他错误
      if (expandedCardKey == cardKey) {
        setState(() {
          isLoadingRoads = false;
          expandedCardKey = null;
        });
        KazumiDialog.showToast(message: '获取播放列表超时');
      }
    } finally {
      // 清理 reaction
      dispose?.call();
    }
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
                            builder: (context) {
                              bool isSuccessButEmpty = false;
                              if (widget.infoController
                                      .pluginSearchStatus[plugin.name] ==
                                  'success') {
                                bool hasContent = false;
                                for (var searchResponse in widget
                                    .infoController.pluginSearchResponseList) {
                                  if (searchResponse.pluginName ==
                                          plugin.name &&
                                      searchResponse.data.isNotEmpty) {
                                    hasContent = true;
                                    break;
                                  }
                                }
                                isSuccessButEmpty = !hasContent;
                              }

                              return Tab(
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
                                        color: isSuccessButEmpty
                                            ? Colors.orange
                                            : (widget.infoController
                                                            .pluginSearchStatus[
                                                        plugin.name] ==
                                                    'success'
                                                ? Colors.green
                                                : (widget.infoController
                                                                .pluginSearchStatus[
                                                            plugin.name] ==
                                                        'pending')
                                                    ? Colors.grey
                                                    : Colors.red),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
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
                        in widget.infoController.pluginSearchResponseList) {
                      if (searchResponse.pluginName == plugin.name) {
                        for (var searchItem in searchResponse.data) {
                          final cardKey = '${plugin.name}_${searchItem.src}';
                          final isExpanded = expandedCardKey == cardKey;

                          cardList.add(
                            Card(
                              elevation: 0,
                              margin: const EdgeInsets.only(
                                  left: 10, right: 10, top: 10),
                              child: Column(
                                children: [
                                  InkWell(
                                    borderRadius: BorderRadius.circular(12),
                                    onTap: () async {
                                      if (isExpanded) {
                                        // 如果已展开，点击后折叠
                                        setState(() {
                                          expandedCardKey = null;
                                          currentRoadList = null;
                                        });
                                        return;
                                      }

                                      // 设置播放控制器的基本信息
                                      videoPageController.bangumiItem =
                                          widget.infoController.bangumiItem;
                                      videoPageController.currentPlugin = plugin;
                                      videoPageController.title = searchItem.name;
                                      videoPageController.src = searchItem.src;

                                      // 通过 Repository 获取播放列表缓存
                                      final cached = videoSourceRepository.getRoadList(searchItem.src);
                                      final loadStatus = videoSourceRepository.getLoadStatus(searchItem.src);

                                      if (cached != null && cached.isSuccess) {
                                        // 缓存命中且成功，直接使用
                                        setState(() {
                                          expandedCardKey = cardKey;
                                          currentRoadList = List.from(cached.roadList);
                                          isLoadingRoads = false;
                                        });
                                        // 同步到 videoPageController（使用封装方法）
                                        videoPageController.updateRoadList(cached.roadList);
                                      } else if (loadStatus == RoadListLoadStatus.pending) {
                                        // 正在加载中，显示加载状态并等待
                                        setState(() {
                                          expandedCardKey = cardKey;
                                          isLoadingRoads = true;
                                          currentRoadList = null;
                                        });
                                        _waitForRoadListLoadedViaRepository(cardKey, searchItem.src);
                                      } else {
                                        // 未加载或加载失败，通过 Repository 查询
                                        setState(() {
                                          expandedCardKey = cardKey;
                                          isLoadingRoads = true;
                                          currentRoadList = null;
                                        });

                                        try {
                                          final result = await videoSourceRepository.queryRoadList(
                                              searchItem.src, plugin);

                                          if (result.isSuccess) {
                                            setState(() {
                                              currentRoadList = List.from(result.roadList);
                                              isLoadingRoads = false;
                                            });
                                            // 同步到 videoPageController（使用封装方法）
                                            videoPageController.updateRoadList(result.roadList);
                                          } else {
                                            setState(() {
                                              isLoadingRoads = false;
                                              expandedCardKey = null;
                                            });
                                            KazumiDialog.showToast(
                                                message: '获取播放列表失败：${result.errorMessage ?? "未知错误"}');
                                          }
                                        } catch (e) {
                                          KazumiLogger().log(Level.warning,
                                              "获取视频播放列表失败: $e");
                                          setState(() {
                                            isLoadingRoads = false;
                                            expandedCardKey = null;
                                          });
                                          KazumiDialog.showToast(
                                              message: '获取播放列表失败，请重试');
                                        }
                                      }
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.all(20),
                                      child: Row(
                                        children: [
                                          Expanded(child: Text(searchItem.name)),
                                          Icon(
                                            isExpanded
                                                ? Icons.expand_less
                                                : Icons.expand_more,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSurfaceVariant,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  // 展开的集数选择器
                                  if (isExpanded)
                                    AnimatedSize(
                                      duration:
                                          const Duration(milliseconds: 300),
                                      curve: Curves.easeInOut,
                                      child: Container(
                                        width: double.infinity,
                                        decoration: BoxDecoration(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .surfaceContainerHighest
                                              .withOpacity(0.3),
                                          borderRadius: const BorderRadius.only(
                                            bottomLeft: Radius.circular(12),
                                            bottomRight: Radius.circular(12),
                                          ),
                                        ),
                                        child: isLoadingRoads
                                            ? const Padding(
                                                padding: EdgeInsets.all(40),
                                                child: Center(
                                                  child:
                                                      CircularProgressIndicator(),
                                                ),
                                              )
                                            : (currentRoadList == null ||
                                                    currentRoadList!.isEmpty
                                                ? const Padding(
                                                    padding: EdgeInsets.all(20),
                                                    child: Text('暂无播放列表'),
                                                  )
                                                : EpisodeSelector(
                                                    roadList: currentRoadList!,
                                                    onEpisodeSelected:
                                                        (episode, road) {
                                                      // 选择集数后跳转到播放页面
                                                      videoPageController
                                                              .currentEpisode =
                                                          episode;
                                                      videoPageController
                                                          .currentRoad = road;
                                                      videoPageController
                                                          .hasManuallySelectedEpisode = true;
                                                      Navigator.of(context)
                                                          .pop();
                                                      Modular.to.pushNamed(
                                                          '/video/');
                                                    },
                                                  )),
                                      ),
                                    ),
                                ],
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
            )
          ],
        ),
      ),
    );
  }
}
