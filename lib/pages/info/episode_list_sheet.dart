import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:kazumi/bean/widget/error_widget.dart';
import 'package:kazumi/modules/bangumi/episode_item.dart';
import 'package:kazumi/pages/info/info_controller.dart';
import 'package:skeletonizer/skeletonizer.dart';

/// 番剧详情页的「集数详情」浮动展示。
///
/// 仅展示 Bangumi `/v0/episodes` 返回的分集元信息，点击不跳转播放页，
/// 与视频源/播放链路完全解耦。
///
/// 直接订阅 [InfoController] 的 MobX 状态，加载/重试/成功/失败切换时
/// sheet 会自动重建，无需外部传入快照。
class EpisodeListSheet extends StatelessWidget {
  const EpisodeListSheet({
    super.key,
    required this.infoController,
    required this.onRetry,
  });

  final InfoController infoController;
  final Future<void> Function() onRetry;

  /// 按 type 分组并保留 Bangumi 返回顺序。
  /// 分段标题由 [EpisodeInfo.sectionTitleForType] 提供。
  List<({String title, List<EpisodeInfo> episodes})> _groupedSections(
      List<EpisodeInfo> episodeList) {
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
        (title: EpisodeInfo.sectionTitleForType(type), episodes: byType[type]!),
    ];
  }

  Widget _buildSectionHeader(BuildContext context, String title, int count) {
    return Row(
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
    );
  }

  Widget _buildEpisodeTile(BuildContext context, EpisodeInfo episode) {
    final prefix = episode.prefix();
    final name = episode.displayName();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
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
    final episodeList = infoController.episodeList.toList();
    if (infoController.episodesIsLoading && episodeList.isEmpty) {
      return Skeletonizer.zone(
        child: SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(),
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
        ),
      );
    }

    if (infoController.episodesQueryTimeout && episodeList.isEmpty) {
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

    if (infoController.episodesIsEmpty && episodeList.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 32),
          child: Text('什么都没有找到 (´;ω;`)'),
        ),
      );
    }

    final sections = _groupedSections(episodeList);
    // 用 CustomScrollView + SliverList 实现真正的懒加载：
    // 每个 section 一个 SliverToBoxAdapter(header) + SliverList(episodes)，
    // 长番剧只构建可见区域内的 tile。
    return CustomScrollView(
      slivers: [
        const SliverToBoxAdapter(child: SizedBox(height: 4)),
        for (final section in sections) ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
              child: _buildSectionHeader(context, section.title,
                  section.episodes.length),
            ),
          ),
          SliverList.builder(
            itemCount: section.episodes.length,
            itemBuilder: (context, index) =>
                _buildEpisodeTile(context, section.episodes[index]),
          ),
        ],
        const SliverToBoxAdapter(child: SizedBox(height: 16)),
      ],
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
          Flexible(
            child: Observer(
              builder: (context) => _buildContent(context),
            ),
          ),
        ],
      ),
    );
  }
}
