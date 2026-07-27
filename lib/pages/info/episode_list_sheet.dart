import 'package:flutter/material.dart';
import 'package:kazumi/bean/widget/error_widget.dart';
import 'package:kazumi/modules/bangumi/bangumi_item.dart';
import 'package:kazumi/modules/bangumi/episode_item.dart';
import 'package:skeletonizer/skeletonizer.dart';

/// 番剧详情页的「集数详情」浮动展示。
///
/// 仅展示 Bangumi `/v0/episodes` 返回的分集元信息，点击不跳转播放页，
/// 与视频源/播放链路完全解耦。
class EpisodeListSheet extends StatelessWidget {
  const EpisodeListSheet({
    super.key,
    required this.bangumiItem,
    required this.episodeList,
    required this.isLoading,
    required this.queryTimeout,
    required this.isEmpty,
    required this.onRetry,
  });

  final BangumiItem bangumiItem;
  final List<EpisodeInfo> episodeList;
  final bool isLoading;
  final bool queryTimeout;
  final bool isEmpty;
  final Future<void> Function() onRetry;

  /// 把 [EpisodeInfo.type] 映射为分段标题。
  /// 0=本篇 / 1=特别篇 / 2=片头曲 / 3=片尾曲。
  String _sectionTitle(int type) {
    switch (type) {
      case 0:
        return '本篇';
      case 1:
        return '特别篇';
      case 2:
        return '片头曲';
      case 3:
        return '片尾曲';
      default:
        return '其它';
    }
  }

  /// 渲染单集编号前缀，例如 `EP1`、`SP2`、`OP`、`ED`。
  /// type=2/3 的 OP/ED 通常没有 sort，直接显示类型缩写。
  String _episodePrefix(EpisodeInfo episode) {
    final typeStr = episode.readType().toUpperCase();
    final sort = episode.episode;
    if (sort == 0 && (episode.type == 2 || episode.type == 3)) {
      return typeStr;
    }
    // sort 是 num，可能是 1.0 或 1.5。整数显示为整数。
    final sortStr =
        sort == sort.toInt() ? sort.toInt().toString() : sort.toString();
    return '$typeStr$sortStr';
  }

  /// 优先用中文名，回退到日文名。
  String _episodeName(EpisodeInfo episode) {
    final cn = episode.nameCn.trim();
    if (cn.isNotEmpty) return cn;
    return episode.name.trim();
  }

  /// 按 type 分组并保留 Bangumi 返回顺序。
  List<({String title, List<EpisodeInfo> episodes})> _groupedSections() {
    final byType = <int, List<EpisodeInfo>>{};
    final order = <int>[];
    for (final ep in episodeList) {
      final type = ep.type;
      if (!byType.containsKey(type)) {
        byType[type] = <EpisodeInfo>[];
        order.add(type);
      }
      byType[type]!.add(ep);
    }
    return [
      for (final type in order)
        (title: _sectionTitle(type), episodes: byType[type]!),
    ];
  }

  Widget _buildSectionHeader(BuildContext context, String title, int count) {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '($count)',
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEpisodeTile(BuildContext context, EpisodeInfo episode) {
    final prefix = _episodePrefix(episode);
    final name = _episodeName(episode);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 56),
            child: SelectableText(
              '$prefix:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: SelectableText(
              name,
              style: name.isEmpty
                  ? TextStyle(
                      color: Theme.of(context).colorScheme.outline,
                      fontStyle: FontStyle.italic,
                    )
                  : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    if (isLoading && episodeList.isEmpty) {
      return Skeletonizer.zone(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (int i = 0; i < 6; i++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Bone.text(fontSize: 14, width: 40),
                    const SizedBox(width: 8),
                    Expanded(child: Bone.text(fontSize: 14, width: 200)),
                  ],
                ),
              ),
          ],
        ),
      );
    }

    if (queryTimeout && episodeList.isEmpty) {
      return GeneralErrorWidget(
        errMsg: '集数获取失败',
        actions: [
          GeneralErrorButton(
            onPressed: () => onRetry(),
            text: '重试',
          ),
        ],
      );
    }

    if (isEmpty && episodeList.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 32),
          child: Text('什么都没有找到 (´;ω;`)'),
        ),
      );
    }

    final sections = _groupedSections();
    return ListView.builder(
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      itemCount: sections.length,
      itemBuilder: (context, sectionIndex) {
        final section = sections[sectionIndex];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader(context, section.title, section.episodes.length),
            for (final episode in section.episodes)
              _buildEpisodeTile(context, episode),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 16, 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '集数详情',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '数据来源：Bangumi · 仅作参考，请以实际播放源集数为准',
                        style: TextStyle(
                          fontSize: 11,
                          color: Theme.of(context).colorScheme.outline,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: '关闭',
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Flexible(child: _buildContent(context)),
        ],
      ),
    );
  }
}
