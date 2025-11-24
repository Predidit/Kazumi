import 'package:flutter/material.dart';
import 'package:kazumi/modules/roads/road_module.dart';
import 'dart:math' as math;
import 'package:kazumi/utils/logger.dart';
import 'package:logger/logger.dart';

/// 集数选择器组件
///
/// 用于在视频源选择面板中快速选择要观看的集数
/// - 支持最多50集的分页显示
/// - 超过50集时提供滑动条快速切换范围
/// - 支持显示当前播放集数（带高亮和动画图标）
class EpisodeSelector extends StatefulWidget {
  const EpisodeSelector({
    super.key,
    required this.roadList,
    required this.onEpisodeSelected,
    this.initialRoad = 0,
    this.currentEpisode,
    this.currentRoad,
    this.showPlayingIndicator = false,
  });

  final List<Road> roadList;
  final Function(int episode, int road) onEpisodeSelected;
  final int initialRoad;

  /// 当前播放的集数（用于高亮显示）
  final int? currentEpisode;

  /// 当前播放列表索引
  final int? currentRoad;

  /// 是否显示播放指示器（动画图标）
  final bool showPlayingIndicator;

  @override
  State<EpisodeSelector> createState() => _EpisodeSelectorState();
}

class _EpisodeSelectorState extends State<EpisodeSelector> {
  static const int maxEpisodesPerPage = 50;

  int currentRoadIndex = 0;
  int totalEpisodes = 0;
  int totalPages = 0;
  int currentPage = 0;

  @override
  void initState() {
    super.initState();
    currentRoadIndex = widget.initialRoad;
    _updateEpisodeInfo();

    // 如果指定了当前播放集数，自动跳转到包含该集数的页面
    if (widget.currentEpisode != null && widget.currentRoad == currentRoadIndex) {
      final episodeIndex = widget.currentEpisode! - 1;
      currentPage = episodeIndex ~/ maxEpisodesPerPage;
      currentPage = currentPage.clamp(0, math.max(0, totalPages - 1));
    }

    // 调试信息：打印播放列表详情
    if (widget.roadList.length > 1) {
      KazumiLogger().log(Level.debug, '=== 播放列表调试信息 ===');
      for (int i = 0; i < widget.roadList.length; i++) {
        final road = widget.roadList[i];
        KazumiLogger().log(Level.debug, '播放列表${i + 1}: ${road.name}');
        KazumiLogger().log(Level.debug, '  集数: ${road.data.length}');
        KazumiLogger().log(Level.debug, '  前3集标识: ${road.identifier.take(3).join(", ")}');
        KazumiLogger().log(Level.debug, '  前3集URL: ${road.data.take(3).join(", ")}');
        KazumiLogger().log(Level.debug, '---');
      }
      KazumiLogger().log(Level.debug, '======================');
    }
  }

  void _updateEpisodeInfo() {
    if (widget.roadList.isEmpty || currentRoadIndex >= widget.roadList.length) {
      totalEpisodes = 0;
      totalPages = 0;
      currentPage = 0;
      return;
    }

    totalEpisodes = widget.roadList[currentRoadIndex].data.length;
    totalPages = (totalEpisodes / maxEpisodesPerPage).ceil();
    // 确保 currentPage 在有效范围内
    if (currentPage >= totalPages) {
      currentPage = 0;
    }
    currentPage = currentPage.clamp(0, math.max(0, totalPages - 1));
  }

  List<Widget> _buildEpisodeCards() {
    if (widget.roadList.isEmpty || currentRoadIndex >= widget.roadList.length) {
      return [];
    }

    final road = widget.roadList[currentRoadIndex];
    final startIndex = currentPage * maxEpisodesPerPage;
    final endIndex = math.min(startIndex + maxEpisodesPerPage, totalEpisodes);

    final cards = <Widget>[];
    for (int i = startIndex; i < endIndex; i++) {
      final episodeNumber = i + 1;
      final episodeTitle = road.identifier[i];

      // 判断是否为当前播放的集数
      final isCurrentPlaying = widget.showPlayingIndicator &&
          widget.currentEpisode == episodeNumber &&
          widget.currentRoad == currentRoadIndex;

      cards.add(
        Card(
          elevation: 0,
          margin: const EdgeInsets.all(4),
          color: isCurrentPlaying
              ? Theme.of(context).colorScheme.primaryContainer
              : null,
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () {
              widget.onEpisodeSelected(episodeNumber, currentRoadIndex);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // 如果是当前播放，显示播放图标
                  if (isCurrentPlaying) ...[
                    Image.asset(
                      'assets/images/playing.gif',
                      color: Theme.of(context).colorScheme.primary,
                      height: 12,
                    ),
                    const SizedBox(height: 4),
                  ],
                  Text(
                    episodeTitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w500,
                          color: isCurrentPlaying
                              ? Theme.of(context).colorScheme.primary
                              : null,
                        ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return cards;
  }

  Widget _buildPageNavigator() {
    if (totalPages <= 1) {
      return const SizedBox.shrink();
    }

    return Column(
      children: [
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '集数范围: ${currentPage * maxEpisodesPerPage + 1}-${math.min((currentPage + 1) * maxEpisodesPerPage, totalEpisodes)} / 共$totalEpisodes集',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Slider(
                          value: currentPage.toDouble(),
                          min: 0,
                          max: (totalPages - 1).toDouble(),
                          divisions: totalPages - 1,
                          label: '第${currentPage + 1}页',
                          onChanged: (value) {
                            setState(() {
                              currentPage = value.toInt();
                            });
                          },
                        ),
                      ),
                      Text(
                        '${currentPage + 1}/$totalPages',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(width: 8),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRoadSelector() {
    if (widget.roadList.length <= 1) {
      return const SizedBox.shrink();
    }

    return Column(
      children: [
        const SizedBox(height: 8),
        SizedBox(
          height: 40,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: widget.roadList.length,
            itemBuilder: (context, index) {
              final isSelected = index == currentRoadIndex;
              final road = widget.roadList[index];
              final episodeCount = road.data.length;

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: ChoiceChip(
                  label: Text('${road.name} ($episodeCount集)'),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected && index != currentRoadIndex) {
                      setState(() {
                        currentRoadIndex = index;
                        currentPage = 0;
                        _updateEpisodeInfo();
                      });
                    }
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCurrentRoadInfo() {
    if (currentRoadIndex >= widget.roadList.length) {
      return const SizedBox.shrink();
    }

    final road = widget.roadList[currentRoadIndex];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Icon(
            Icons.playlist_play,
            size: 20,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${road.name} · 共${road.data.length}集',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.roadList.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Text('暂无播放列表'),
        ),
      );
    }

    return Container(
      constraints: const BoxConstraints(maxHeight: 500),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildRoadSelector(),
          if (widget.roadList.length > 1) _buildCurrentRoadInfo(),
          _buildPageNavigator(),
          const SizedBox(height: 8),
          Flexible(
            child: GridView.count(
              shrinkWrap: true,
              crossAxisCount: 5,
              childAspectRatio: 1.8,
              mainAxisSpacing: 4,
              crossAxisSpacing: 4,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              children: _buildEpisodeCards(),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
