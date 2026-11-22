import 'package:flutter/material.dart';

import 'package:kazumi/bean/card/user_comments_card.dart';
import 'package:kazumi/bean/widget/connected_button_group.dart';
import 'package:kazumi/bean/widget/empty_state_widget.dart';
import 'package:kazumi/bean/widget/error_widget.dart';
import 'package:kazumi/bean/widget/loading_indicator.dart';
import 'package:kazumi/bean/widget/split_list_selector.dart';
import 'package:kazumi/bean/widget/state_presentation.dart';
import 'package:kazumi/modules/bangumi/episode_item.dart';
import 'package:kazumi/modules/comments/comment_item.dart';
import 'package:kazumi/pages/video/player_panel_layout.dart';

class EpisodeCommentsView extends StatelessWidget {
  const EpisodeCommentsView({
    super.key,
    required this.episode,
    required this.episodeInfo,
    required this.comments,
    required this.isLoading,
    required this.hasError,
    required this.isAscending,
    required this.onToggleSort,
    required this.onSelectEpisode,
    required this.onRefresh,
  });

  final int episode;
  final EpisodeInfo? episodeInfo;
  final List<EpisodeCommentItem> comments;
  final bool isLoading;
  final bool hasError;
  final bool isAscending;
  final VoidCallback onToggleSort;
  final VoidCallback onSelectEpisode;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return ColoredBox(
      color: colors.surface,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final gutter = playerPanelGutter(constraints.maxWidth);
          final contentWidth =
              (constraints.maxWidth - gutter * 2).clamp(0.0, double.infinity);
          final info = episodeInfo ?? EpisodeInfo.fromTemplate();
          final badgeText = info.badgeLabel(episode);
          final title = info.displayTitle(episode);

          return CustomScrollView(
            key: ValueKey('episode-comments-$episode'),
            scrollBehavior:
                playerPanelScrollBehavior(context, scrollbars: false),
            slivers: [
              SliverPadding(
                padding: EdgeInsets.fromLTRB(gutter, 10, gutter, 6),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SplitListSelectorCard(
                        leading: Text(badgeText),
                        title: title,
                        subtitle: info.displaySubtitle(episode),
                        semanticsLabel: '切换讨论分集，$badgeText，$title',
                        onTap: onSelectEpisode,
                      ),
                      const SizedBox(height: 8),
                      _CommentsControlBar(
                        availableWidth: contentWidth,
                        count: comments.length,
                        showCount:
                            (!isLoading && !hasError) || comments.isNotEmpty,
                        isLoading: isLoading,
                        isAscending: isAscending,
                        canSort: comments.length > 1,
                        onToggleSort: onToggleSort,
                        onRefresh: onRefresh,
                      ),
                    ],
                  ),
                ),
              ),
              if (isLoading && comments.isEmpty)
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(gutter, 6, gutter, 24),
                  sliver: SliverList.builder(
                    itemCount: 4,
                    itemBuilder: (_, _) => const UserCommentsCardBone(),
                  ),
                )
              else if (!isLoading && hasError && comments.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: GeneralErrorWidget(
                    compact: true,
                    icon: Icons.cloud_off_rounded,
                    title: '评论暂时未能加载',
                    errMsg: '请检查网络连接后重试',
                    onRetry: onRefresh,
                    retryText: '重试',
                  ),
                )
              else if (!isLoading && comments.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: GeneralEmptyState(
                    compact: true,
                    icon: Icons.forum_outlined,
                    title: '本集还没有讨论',
                    actions: [
                      StateActionButton.tonal(
                        onPressed: onSelectEpisode,
                        icon: Icons.swap_horiz_rounded,
                        text: '切换分集',
                      ),
                    ],
                  ),
                )
              else ...[
                if (hasError && !isLoading)
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(gutter, 4, gutter, 10),
                    sliver: SliverToBoxAdapter(
                      child: _RefreshErrorBanner(onRetry: onRefresh),
                    ),
                  ),
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(gutter, 4, gutter, 0),
                  sliver: SliverList(
                    key: ValueKey(isAscending),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => KeepAlive(
                        // Retain BBCode image geometry and expanded discussions.
                        key: ObjectKey(comments[index]),
                        keepAlive: true,
                        child: IndexedSemantics(
                          index: index,
                          child: UserCommentsCard.episode(comments[index]),
                        ),
                      ),
                      childCount: comments.length,
                      addAutomaticKeepAlives: false,
                      addRepaintBoundaries: false,
                      addSemanticIndexes: false,
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      16,
                      8,
                      16,
                      24 + MediaQuery.paddingOf(context).bottom,
                    ),
                    child: Text(
                      '共 ${comments.length} 条讨论 · 来自 Bangumi',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: colors.onSurfaceVariant,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                    ),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _CommentsControlBar extends StatelessWidget {
  const _CommentsControlBar({
    required this.availableWidth,
    required this.count,
    required this.showCount,
    required this.isLoading,
    required this.isAscending,
    required this.canSort,
    required this.onToggleSort,
    required this.onRefresh,
  });

  final double availableWidth;
  final int count;
  final bool showCount;
  final bool isLoading;
  final bool isAscending;
  final bool canSort;
  final VoidCallback onToggleSort;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final disableAnimations = MediaQuery.disableAnimationsOf(context);
    final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;
    final compactSort = availableWidth < 324 || textScale > 1.25;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    '讨论',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: colors.onSurface,
                    ),
                  ),
                ),
                if (showCount) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: colors.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$count',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: colors.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (!compactSort)
            ConnectedButtonGroup<bool>(
              expanded: false,
              segments: const [
                ButtonSegment<bool>(
                  value: false,
                  label: Text('最新'),
                ),
                ButtonSegment<bool>(
                  value: true,
                  label: Text('最早'),
                ),
              ],
              selected: isAscending,
              onSelected: canSort
                  ? (ascending) {
                      if (ascending != isAscending) onToggleSort();
                    }
                  : null,
            )
          else
            IconButton.filledTonal(
              tooltip: isAscending ? '最早优先，切换为最新优先' : '最新优先，切换为最早优先',
              onPressed: canSort ? onToggleSort : null,
              style: IconButton.styleFrom(
                minimumSize: const Size(40, 40),
                backgroundColor: colors.surfaceContainer,
                foregroundColor: colors.onSurfaceVariant,
              ),
              icon: Icon(
                isAscending
                    ? Icons.arrow_upward_rounded
                    : Icons.arrow_downward_rounded,
                size: 20,
              ),
            ),
          const SizedBox(width: 6),
          IconButton.filledTonal(
            tooltip: isLoading ? '正在加载评论' : '刷新评论',
            onPressed: isLoading ? null : onRefresh,
            style: IconButton.styleFrom(
              minimumSize: const Size(40, 40),
              backgroundColor: colors.surfaceContainer,
              disabledBackgroundColor: colors.surfaceContainer,
              foregroundColor: colors.onSurfaceVariant,
              disabledForegroundColor: colors.primary,
            ),
            icon: AnimatedSwitcher(
              duration: disableAnimations
                  ? Duration.zero
                  : const Duration(milliseconds: 180),
              child: isLoading
                  ? LoadingIndicator(
                      key: const ValueKey('loading'),
                      size: 18,
                      color: colors.primary,
                      semanticsLabel: '正在加载评论',
                    )
                  : const Icon(
                      Icons.refresh_rounded,
                      key: ValueKey('refresh'),
                      size: 20,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RefreshErrorBanner extends StatelessWidget {
  const _RefreshErrorBanner({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.errorContainer,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
        child: Row(
          children: [
            Icon(
              Icons.cloud_off_rounded,
              size: 18,
              color: colors.onErrorContainer,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '刷新失败，已保留当前讨论',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colors.onErrorContainer,
                      fontWeight: FontWeight.w500,
                    ),
              ),
            ),
            TextButton(
              onPressed: onRetry,
              style: TextButton.styleFrom(
                foregroundColor: colors.onErrorContainer,
                minimumSize: const Size(48, 40),
              ),
              child: const Text('重试'),
            ),
          ],
        ),
      ),
    );
  }
}
