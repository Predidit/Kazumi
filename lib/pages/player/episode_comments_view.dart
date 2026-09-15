import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:kazumi/bean/card/user_comments_card.dart';
import 'package:kazumi/bean/widget/error_widget.dart';
import 'package:kazumi/bean/widget/empty_state_widget.dart';
import 'package:kazumi/bean/widget/loading_indicator.dart';
import 'package:kazumi/modules/bangumi/episode_item.dart';
import 'package:kazumi/modules/comments/comment_item.dart';

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
      child: LayoutBuilder(builder: (context, constraints) {
        final gutter = constraints.maxWidth > 760
            ? (constraints.maxWidth - 728) / 2
            : 16.0;
        return CustomScrollView(
          key: ValueKey(episode),
          scrollBehavior: const ScrollBehavior().copyWith(
            scrollbars: false,
            dragDevices: {
              PointerDeviceKind.mouse,
              PointerDeviceKind.touch,
              PointerDeviceKind.trackpad,
            },
          ),
          slivers: [
            SliverPadding(
              padding: EdgeInsets.fromLTRB(gutter, 16, gutter, 0),
              sliver: SliverToBoxAdapter(
                child: _EpisodeHeader(
                  episode: episode,
                  info: episodeInfo,
                  onSelectEpisode: onSelectEpisode,
                ),
              ),
            ),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(gutter + 4, 16, gutter, 12),
              sliver: SliverToBoxAdapter(child: _buildToolbar(context)),
            ),
            if (!isLoading && hasError && comments.isEmpty)
              SliverToBoxAdapter(
                child: GeneralErrorWidget(
                  icon: Icons.cloud_off_rounded,
                  title: '评论暂时未能加载',
                  errMsg: '请检查网络后重试，或切换分集查看讨论。',
                  onRetry: onRefresh,
                  retryText: '重新加载',
                ),
              )
            else if (!isLoading && comments.isEmpty)
              const SliverToBoxAdapter(
                child: GeneralEmptyState(
                  icon: Icons.chat_bubble_outline_rounded,
                  title: '本集还没有讨论',
                ),
              )
            else if (comments.isNotEmpty) ...[
              if (hasError)
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(gutter, 0, gutter, 12),
                  sliver: SliverToBoxAdapter(
                    child: Material(
                      color: colors.errorContainer,
                      borderRadius: BorderRadius.circular(16),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
                        child: Row(children: [
                          Expanded(
                            child: Text('刷新失败，已保留现有讨论',
                                style:
                                    TextStyle(color: colors.onErrorContainer)),
                          ),
                          TextButton(
                            onPressed: onRefresh,
                            style: TextButton.styleFrom(
                                foregroundColor: colors.onErrorContainer),
                            child: const Text('重试'),
                          ),
                        ]),
                      ),
                    ),
                  ),
                ),
              SliverPadding(
                padding: EdgeInsets.symmetric(horizontal: gutter),
                sliver: SliverList(
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
                    findChildIndexCallback: (key) {
                      final index = comments.indexOf(
                          (key as ObjectKey).value as EpisodeCommentItem);
                      return index < 0 ? null : index;
                    },
                    addAutomaticKeepAlives: false,
                    addRepaintBoundaries: false,
                    addSemanticIndexes: false,
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  child: Text('已显示全部 ${comments.length} 条讨论 · 来自 Bangumi',
                      textAlign: TextAlign.center,
                      style: Theme.of(context)
                          .textTheme
                          .labelMedium
                          ?.copyWith(color: colors.onSurfaceVariant)),
                ),
              ),
            ],
            SliverToBoxAdapter(
              child: SizedBox(height: MediaQuery.paddingOf(context).bottom),
            ),
          ],
        );
      }),
    );
  }

  Widget _buildToolbar(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final type = Theme.of(context).textTheme;
    return LayoutBuilder(builder: (context, constraints) {
      final title = Row(mainAxisSize: MainAxisSize.min, children: [
        Text('讨论',
            style: type.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
        if ((!isLoading && !hasError) || comments.isNotEmpty) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: colors.secondaryContainer,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text('${comments.length}',
                style: type.labelLarge
                    ?.copyWith(color: colors.onSecondaryContainer)),
          ),
        ],
      ]);
      final actions = Row(mainAxisSize: MainAxisSize.min, children: [
        TextButton.icon(
          onPressed: comments.length > 1 ? onToggleSort : null,
          style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
          icon: Icon(
              isAscending
                  ? Icons.arrow_upward_rounded
                  : Icons.arrow_downward_rounded,
              size: 18),
          label: Text(isAscending ? '最早优先' : '最新优先'),
        ),
        const SizedBox(width: 4),
        SizedBox.square(
          dimension: 48,
          child: IconButton.filledTonal(
            tooltip: isLoading ? '正在加载评论' : '刷新评论',
            onPressed: isLoading ? null : onRefresh,
            style: IconButton.styleFrom(
              backgroundColor: colors.secondaryContainer,
              disabledBackgroundColor: colors.secondaryContainer,
              foregroundColor: colors.onSecondaryContainer,
              disabledForegroundColor: colors.onSecondaryContainer,
            ),
            icon: isLoading
                ? LoadingIndicator(
                    size: 24,
                    color: colors.onSecondaryContainer,
                    semanticsLabel: '正在加载评论',
                  )
                : const Icon(Icons.refresh_rounded, size: 24),
          ),
        ),
      ]);
      if (constraints.maxWidth < 310 ||
          MediaQuery.textScalerOf(context).scale(14) > 19) {
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          title,
          const SizedBox(height: 4),
          Align(alignment: Alignment.centerRight, child: actions),
        ]);
      }
      return Row(children: [title, const Spacer(), actions]);
    });
  }
}

class _EpisodeHeader extends StatelessWidget {
  const _EpisodeHeader({
    required this.episode,
    required this.info,
    required this.onSelectEpisode,
  });

  final int episode;
  final EpisodeInfo? info;
  final VoidCallback onSelectEpisode;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final type = Theme.of(context).textTheme;
    final number = info?.episode ?? episode;
    final translatedTitle = info?.nameCn ?? '';
    final originalTitle = info?.name ?? '';
    final title = translatedTitle.isNotEmpty
        ? translatedTitle
        : originalTitle.isNotEmpty
            ? originalTitle
            : '第 $number 集';
    final subtitle = originalTitle.isNotEmpty && originalTitle != title
        ? originalTitle
        : 'Bangumi 分集讨论';
    final episodeType = info?.readType().toUpperCase() ?? 'EP';

    return Material(
      color: colors.primaryContainer,
      borderRadius: BorderRadius.circular(28),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: double.infinity,
              child: Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12,
                runSpacing: 12,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: colors.primary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text('$episodeType $number'.trim(),
                        style: type.titleSmall?.copyWith(
                            color: colors.onPrimary,
                            fontWeight: FontWeight.w700)),
                  ),
                  FilledButton.icon(
                    onPressed: onSelectEpisode,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(48, 48),
                      backgroundColor: colors.surface,
                      foregroundColor: colors.primary,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                    icon: const Icon(Icons.video_library_outlined, size: 18),
                    label: const Text('切换分集'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Semantics(
              header: true,
              child: Text(title,
                  style: type.titleLarge?.copyWith(
                    color: colors.onPrimaryContainer,
                    fontWeight: FontWeight.w700,
                    height: 1.3,
                  )),
            ),
            const SizedBox(height: 6),
            // Reserve one line to prevent jumps when metadata arrives.
            Tooltip(
              message: subtitle,
              child: Text(subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: type.bodySmall?.copyWith(
                      color: colors.onPrimaryContainer, height: 1.5)),
            ),
          ],
        ),
      ),
    );
  }
}
