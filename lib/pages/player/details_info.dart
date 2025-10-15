import 'dart:ui' as ui;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/modules/bangumi/bangumi_item.dart';
import 'package:kazumi/pages/player/player_controller.dart';
import 'package:kazumi/pages/video/video_controller.dart';
import 'package:logger/logger.dart';

import '../../bean/card/network_img_layer.dart';
import '../../request/bangumi.dart';
import '../../utils/logger.dart';
import '../../utils/utils.dart';
import '../history/history_controller.dart';

class DetailsCommentsSheet extends StatefulWidget {
  const DetailsCommentsSheet({super.key});

  @override
  State<DetailsCommentsSheet> createState() => _DetailsCommentsSheetState();
}

class _DetailsCommentsSheetState extends State<DetailsCommentsSheet> {
  final VideoPageController videoPageController =
      Modular.get<VideoPageController>();
  final HistoryController historyController = Modular.get<HistoryController>();
  final PlayerController playerController = Modular.get<PlayerController>();

  late BangumiItem _currentBangumiItem;

  bool fullIntro = false;
  bool fullTag = false;
  int touchedIndex = -1;

  @override
  void initState() {
    super.initState();
    _currentBangumiItem = videoPageController.bangumiItem;
  }

  // 修改：detailsBar读取当前状态的_bangumiItem（而非直接读控制器）
  Widget get detailsBar {
    return Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 显示当前状态的bangumiId
                  Text('BangumiId:${_currentBangumiItem.id.toString()}',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.outline)),
                  // 显示当前状态的剧名
                  Text(
                      (videoPageController.episodeInfo.nameCn != '')
                          ? '剧名:${_currentBangumiItem.nameCn}'
                          : '剧名:${_currentBangumiItem.name}',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.outline)),
                ],
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              height: 34,
              child: TextButton(
                style: ButtonStyle(
                  padding: WidgetStateProperty.all(
                      const EdgeInsets.only(left: 4.0, right: 4.0)),
                ),
                onPressed: () {
                  showBangumiItemSelection();
                },
                child: const Text(
                  '手动切换',
                  style: TextStyle(fontSize: 13),
                ),
              ),
            ),
          ],
        ));
  }

  Widget _buildRatingDistribution(BangumiItem bangumiItem) {
    // 1. 数据安全校验：避免空数组、除零错误
    if (bangumiItem.votesCount.isEmpty || bangumiItem.votes == 0) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child:
            Text("暂无评分数据", style: TextStyle(color: Colors.grey, fontSize: 14)),
      );
    }

    // 补全 votesCount 到10个元素（避免数组越界）
    final List<int> safeVotesCount = List.generate(10, (index) {
      return index < bangumiItem.votesCount.length
          ? bangumiItem.votesCount[index]
          : 0;
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '评分透视:',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: 150, // 最小高度（根据需求调整）
            maxHeight: 200, // 最大高度（防止图表过高）
          ),
          child: AspectRatio(
            aspectRatio: 2.5, // 宽高比（2.5:1，可根据布局调整）
            child: BarChart(
              duration: const Duration(milliseconds: 80),
              BarChartData(
                borderData: FlBorderData(show: false),
                gridData: FlGridData(show: false),
                barTouchData: BarTouchData(
                  touchCallback: (FlTouchEvent event, barTouchResponse) {
                    setState(() {
                      if (!event.isInterestedForInteractions ||
                          barTouchResponse == null ||
                          barTouchResponse.spot == null) {
                        touchedIndex = -1;
                        return;
                      }
                      touchedIndex =
                          barTouchResponse.spot!.touchedBarGroupIndex;
                    });
                  },
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) =>
                        Theme.of(context).colorScheme.inverseSurface,
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      // 3. 数据安全：避免除零错误
                      final double percentage =
                          (safeVotesCount[groupIndex] / bangumiItem.votes) *
                              100;
                      return BarTooltipItem(
                        '${percentage.toStringAsFixed(2)}% (${safeVotesCount[groupIndex]}人)',
                        TextStyle(
                            color:
                                Theme.of(context).colorScheme.onInverseSurface),
                      );
                    },
                  ),
                ),
                // 4. 使用安全的 votesCount 数组，避免越界
                barGroups: List<BarChartGroupData>.generate(
                  10, // 固定生成10组（对应1-10分）
                  (i) => BarChartGroupData(
                    x: i + 1, // x轴标签（1-10）
                    barRods: [
                      BarChartRodData(
                        toY: safeVotesCount[i].toDouble(), // 用安全数组的值
                        color: touchedIndex == i
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).disabledColor,
                        width: 30,
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(5)),
                      )
                    ],
                  ),
                ),
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30, // 预留底部标签空间
                      getTitlesWidget: (value, meta) => SideTitleWidget(
                        meta: meta,
                        space: 10,
                        child: Text(
                          value.toInt().toString(),
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ),
                  ),
                  topTitles: const AxisTitles(),
                  leftTitles: const AxisTitles(),
                  rightTitles: const AxisTitles(),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // 构建别名列表（保留原有逻辑）
  Widget _buildAliases(List<String> aliases) {
    if (aliases.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '别名',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: aliases.map((alias) {
            return Text(
              alias,
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // 修改：detailsBody读取当前状态的_bangumiItem（通过DetailsInfo传递）
  Widget get detailsBody {
    final BangumiItem bangumiItem = _currentBangumiItem; // 直接用当前状态的对象
    final String mainImage = bangumiItem.images.isNotEmpty
        ? bangumiItem.images['large'] ?? bangumiItem.images.values.first
        : '';
    final double introMaxWidth = MediaQuery.of(context).size.width - 32;

    return Expanded(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 顶部封面和基本信息（使用当前状态的bangumiItem）
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (mainImage.isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: NetworkImgLayer(
                      src: mainImage,
                      width: 150,
                      height: 225,
                    ),
                  )
                else
                  Container(
                    width: 120,
                    height: 180,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceVariant,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.image_not_supported, size: 40),
                  ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        bangumiItem.nameCn.isNotEmpty
                            ? bangumiItem.nameCn
                            : bangumiItem.name,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (bangumiItem.nameCn.isNotEmpty &&
                          bangumiItem.name != bangumiItem.nameCn)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            bangumiItem.name,
                            style: TextStyle(
                              fontSize: 14,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                              // fontStyle: FontStyle.italic,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      const SizedBox(height: 12),
                      Text(
                        '放送开始:',
                      ),
                      Text(
                        bangumiItem.airDate == ''
                            ? '2000-11-11' // Skeleton Loader 占位符
                            : bangumiItem.airDate,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        '${bangumiItem.votes} 人评分:',
                      ),
                      Row(
                        children: [
                          Text(
                            '${bangumiItem.ratingScore}',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          const SizedBox(width: 8),
                          RatingBarIndicator(
                            itemCount: 5,
                            rating: bangumiItem.ratingScore.toDouble() / 2,
                            itemBuilder: (context, index) => Icon(
                              Icons.star_rounded,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            itemSize: 20.0,
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Bangumi Ranked:',
                      ),
                      Text(
                        '#${bangumiItem.rank}',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildAliases(bangumiItem.alias),
            const SizedBox(height: 8),
            // 简介折叠功能（使用当前状态的bangumiItem）
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('简介', style: TextStyle(fontSize: 18)),
                const SizedBox(height: 8),
                LayoutBuilder(builder: (context, constraints) {
                  final span = TextSpan(text: bangumiItem.summary);
                  final tp =
                      TextPainter(text: span, textDirection: TextDirection.ltr);
                  tp.layout(maxWidth: constraints.maxWidth);
                  final numLines = tp.computeLineMetrics().length;

                  if (numLines > 7) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        SizedBox(
                          // make intro expandable
                          height: fullIntro ? null : 120,
                          width: MediaQuery.sizeOf(context).width - 32,
                          child: SelectableText(
                            bangumiItem.summary,
                            textAlign: TextAlign.start,
                            scrollBehavior: const ScrollBehavior().copyWith(
                              scrollbars: false,
                            ),
                            scrollPhysics: NeverScrollableScrollPhysics(),
                            selectionHeightStyle: ui.BoxHeightStyle.max,
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            setState(() {
                              fullIntro = !fullIntro;
                            });
                          },
                          child: Text(fullIntro ? '加载更少' : '加载更多'),
                        ),
                      ],
                    );
                  } else {
                    return SelectableText(
                      bangumiItem.summary,
                      textAlign: TextAlign.start,
                      scrollPhysics: NeverScrollableScrollPhysics(),
                      selectionHeightStyle: ui.BoxHeightStyle.max,
                    );
                  }
                }),
              ],
            ),
            const SizedBox(height: 8),
            _buildRatingDistribution(bangumiItem),
            const SizedBox(height: 12),
            Text('标签', style: TextStyle(fontSize: 18)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8.0,
              runSpacing: Utils.isDesktop() ? 8 : 0,
              children: List<Widget>.generate(
                  bangumiItem.tags.length < 13
                      ? bangumiItem.tags.length
                      : fullTag
                          ? bangumiItem.tags.length + 1
                          : 13, (int index) {
                if (!fullTag && index == 12) {
                  // make tag expandable
                  return ActionChip(
                    label: Text(
                      '更多 +',
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.primary),
                    ),
                    onPressed: () {
                      setState(() {
                        fullTag = !fullTag;
                      });
                    },
                  );
                }
                if (fullTag && index == bangumiItem.tags.length) {
                  // make tag expandable
                  return ActionChip(
                    label: Text(
                      '更少 -',
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.primary),
                    ),
                    onPressed: () {
                      setState(() {
                        fullTag = !fullTag;
                      });
                    },
                  );
                }
                return Chip(
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('${bangumiItem.tags[index].name} '),
                      Text(
                        '${bangumiItem.tags[index].count}',
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.primary),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  void showBangumiItemSelection() {
    // 1. 用 ValueNotifier 管理弹窗内所有状态（仅触发必要重绘，无 StatefulBuilder）
    final TextEditingController textController = TextEditingController();
    final ValueNotifier<List<BangumiItem>> _searchResults = ValueNotifier([]);
    final ValueNotifier<bool> _isLoading = ValueNotifier(false);
    final ValueNotifier<bool> _hasSearched = ValueNotifier(false);

    // 2. 搜索逻辑：独立函数，仅更新 ValueNotifier（不直接操作弹窗UI）
    Future<void> _doSearch() async {
      final keyword = textController.text.trim();
      if (keyword.isEmpty) {
        KazumiDialog.showToast(message: '请输入bangumi名称');
        return;
      }

      _isLoading.value = true;
      _hasSearched.value = true;

      try {
        // 调用搜索API
        final results = await BangumiHTTP.bangumiSearch(
          keyword,
          tags: [],
          offset: 0,
          sort: 'heat',
        );
        // 仅更新结果状态（由 ValueListenableBuilder 触发列表重绘）
        _searchResults.value = results;
      } catch (e) {
        KazumiDialog.showToast(message: '搜索失败，请重试');
        _searchResults.value = [];
      } finally {
        _isLoading.value = false;
      }
    }

    // 3. 选择逻辑：关闭弹窗→延迟→更新页面（确保弹窗完全销毁）
    void _onSelect(BangumiItem item) {
      // 第一步：立即关闭弹窗
      KazumiDialog.dismiss();

      // 第二步：延迟150ms（确保弹窗动画/渲染树完全清理）
      Future.delayed(const Duration(milliseconds: 150), () {
        // 避免重复选择
        if (item.id == _currentBangumiItem.id) {
          KazumiDialog.showToast(message: '已选择当前bangumi');
          return;
        }
        item.images = videoPageController.bangumiItem.images;
        item.nameCn = videoPageController.bangumiItem.name;
        // 更新历史记录
        historyController.updateHistoryByKey(
          videoPageController.currentPlugin.name,
          _currentBangumiItem,
          item,
        );

        if (playerController.danDanmakus.isEmpty) {
          int episodeFromTitle = 0;
          try {
            episodeFromTitle = Utils.extractEpisodeNumber(videoPageController
                .roadList[videoPageController.currentRoad]
                .identifier[videoPageController.currentEpisode - 1]);
          } catch (e) {
            KazumiLogger().log(Level.error, '从标题解析集数错误 ${e.toString()}');
          }
          if (episodeFromTitle == 0) {
            episodeFromTitle = videoPageController.currentEpisode;
          }
          playerController.getDanDanmakuByBgmBangumiID(
              item.id, episodeFromTitle);
        }

        // 第三步：更新页面状态（此时弹窗已销毁，无渲染冲突）
        setState(() {
          videoPageController.bangumiItem = item;
          _currentBangumiItem = item;
        });
      });
    }

    // 4. 构建弹窗：用 ValueListenableBuilder 包裹局部UI（仅局部重绘）
    KazumiDialog.show(
      builder: (context) {
        // 禁用弹窗过渡动画（减少渲染时序冲突，关键！）
        textController.text = videoPageController.title;
        return Dialog(
          elevation: 2,
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 标题
                const Text('搜索bangumi',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),

                // 搜索输入框（无状态，仅触发搜索）
                TextField(
                  controller: textController,
                  decoration: const InputDecoration(
                    hintText: '输入bangumi名称',
                    border: OutlineInputBorder(),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _doSearch(),
                  style: const TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 12),

                // 加载状态（仅加载时重绘）
                ValueListenableBuilder(
                  valueListenable: _isLoading,
                  builder: (context, isLoading, child) {
                    if (isLoading) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: Column(
                            children: [
                              CircularProgressIndicator(strokeWidth: 2),
                              SizedBox(height: 8),
                              Text('正在搜索...', style: TextStyle(fontSize: 14)),
                            ],
                          ),
                        ),
                      );
                    }
                    return child!;
                  },
                  child: ValueListenableBuilder(
                    valueListenable: _hasSearched,
                    builder: (context, hasSearched, child) {
                      // 未搜索时不显示结果区
                      if (!hasSearched) return const SizedBox.shrink();

                      // 搜索结果列表（仅结果变化时重绘）
                      return ValueListenableBuilder(
                        valueListenable: _searchResults,
                        builder: (context, results, _) {
                          // 无结果
                          if (results.isEmpty) {
                            return const Center(
                              child: Padding(
                                padding: EdgeInsets.symmetric(vertical: 24),
                                child: Text('未找到匹配结果，请换关键词',
                                    style: TextStyle(
                                        fontSize: 14, color: Colors.grey)),
                              ),
                            );
                          }

                          // 结果列表（简化Item，避免复杂组件）
                          return ConstrainedBox(
                            constraints: const BoxConstraints(maxHeight: 280),
                            child: ListView.builder(
                              shrinkWrap: true,
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              itemCount: results.length,
                              itemBuilder: (context, index) {
                                final item = results[index];
                                final imgUrl = item.images.isNotEmpty
                                    ? item.images['small'] ??
                                        item.images.values.first
                                    : '';

                                return ListTile(
                                  leading: imgUrl.isNotEmpty
                                      ? ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(3),
                                          // 简化图片组件：用Image.network+错误占位，避免自定义NetworkImgLayer的潜在冲突
                                          child: Image.network(
                                            imgUrl,
                                            width: 40,
                                            height: 56,
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) =>
                                                const Icon(
                                                    Icons.image_not_supported,
                                                    size: 24),
                                            loadingBuilder: (_, child,
                                                    progress) =>
                                                progress == null
                                                    ? child
                                                    : const SizedBox(
                                                        width: 40,
                                                        height: 56,
                                                        child:
                                                            CircularProgressIndicator(
                                                                strokeWidth:
                                                                    1)),
                                          ),
                                        )
                                      : const SizedBox(
                                          width: 40,
                                          height: 56,
                                          child: Icon(Icons.image_not_supported,
                                              size: 24)),
                                  title: Text(
                                    item.nameCn.isNotEmpty
                                        ? item.nameCn
                                        : item.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                  subtitle: Text(
                                    'ID: ${item.id}',
                                    style: const TextStyle(
                                        fontSize: 12, color: Colors.grey),
                                  ),
                                  onTap: () =>
                                      _onSelect(item), // 仅触发选择逻辑，无弹窗内状态更新
                                );
                              },
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),

                // 底部按钮（无状态，仅触发搜索/关闭）
                // 底部按钮（修正 onPressed 类型问题）
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => KazumiDialog.dismiss(),
                      child: Text('取消',
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.outline)),
                    ),
                    const SizedBox(width: 8),
                    ValueListenableBuilder(
                      valueListenable: _isLoading,
                      builder: (context, isLoading, _) {
                        return TextButton(
                          // 推荐用箭头函数包装，显式声明“无参数”，避免类型歧义
                          onPressed: isLoading ? null : () => _doSearch(),
                          child: const Text('搜索'),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // 关键修改：用_currentBangumiItem更新DetailsInfo，确保子Widget同步刷新
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [detailsBar, detailsBody],
      ),
    );
  }
}
