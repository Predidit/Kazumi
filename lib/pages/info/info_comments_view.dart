import 'package:flutter/material.dart';
import 'package:kazumi/bean/card/comments_card.dart';
import 'package:kazumi/bean/widget/empty_state_widget.dart';
import 'package:kazumi/bean/widget/error_widget.dart';
import 'package:kazumi/modules/bangumi/bangumi_interest.dart';
import 'package:kazumi/modules/comments/comment_item.dart';

class InfoCommentsView extends StatelessWidget {
  const InfoCommentsView({
    super.key,
    required this.interest,
    required this.comments,
    required this.isLoading,
    required this.hasLoaded,
    required this.hasError,
    required this.onReviewTap,
    required this.onRetry,
    required this.onLoadMore,
  });

  static const _writeReviewLabel = '下面我简单喵两句';
  static const _maxWidth = 950.0;

  final BangumiInterest? interest;
  final List<CommentItem> comments;
  final bool isLoading;
  final bool hasLoaded;
  final bool hasError;
  final VoidCallback onReviewTap;
  final VoidCallback onRetry;
  final VoidCallback onLoadMore;

  CommentItem? get _ownComment {
    final review = interest;
    final user = review?.user;
    if (review == null || !review.hasReviewContent || user == null) return null;
    return CommentItem(
      user: user,
      comment: Comment(
        rate: review.rate,
        comment: review.comment,
        updatedAt: review.updatedAt,
      ),
    );
  }

  bool _onScrollEnd(ScrollEndNotification notification) {
    // Nested error views must not trigger pagination.
    if (notification.depth == 0 &&
        notification.metrics.axis == Axis.vertical &&
        !isLoading &&
        comments.isNotEmpty &&
        notification.metrics.extentAfter < 200) {
      onLoadMore();
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final ownComment = _ownComment;
    final hasReview = interest?.hasReviewContent ?? false;
    final showEmpty =
        hasLoaded && !isLoading && !hasError && comments.isEmpty && !hasReview;
    return SafeArea(
      top: false,
      bottom: false,
      child: LayoutBuilder(builder: (context, constraints) {
        final gutter = ((constraints.maxWidth - _maxWidth) / 2)
            .clamp(16.0, double.infinity);
        return NotificationListener<ScrollEndNotification>(
          onNotification: _onScrollEnd,
          child: CustomScrollView(
            key: const PageStorageKey<String>('吐槽'),
            scrollBehavior: const ScrollBehavior().copyWith(scrollbars: false),
            slivers: [
              SliverOverlapInjector(
                handle:
                    NestedScrollView.sliverOverlapAbsorberHandleFor(context),
              ),
              if (ownComment == null && !showEmpty)
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(gutter, 12, gutter, 8),
                  sliver: SliverToBoxAdapter(
                    child: _reviewEntry(context, editing: hasReview),
                  ),
                ),
              if (ownComment != null || comments.isNotEmpty)
                SliverPadding(
                  padding: EdgeInsets.symmetric(horizontal: gutter),
                  sliver: SliverList.separated(
                    addAutomaticKeepAlives: false,
                    itemCount: comments.length + (ownComment == null ? 0 : 1),
                    itemBuilder: (context, index) {
                      if (ownComment != null && index == 0) {
                        return _ownReview(ownComment);
                      }
                      return CommentsCard(
                        commentItem:
                            comments[index - (ownComment == null ? 0 : 1)],
                      );
                    },
                    separatorBuilder: (_, __) => const Divider(
                      thickness: 0.5,
                      indent: 10,
                      endIndent: 10,
                    ),
                  ),
                )
              else if (hasError)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: GeneralErrorWidget(
                    title: '评论加载失败',
                    errMsg: '请检查网络连接后重试。',
                    onRetry: onRetry,
                  ),
                )
              else if (showEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: GeneralEmptyState(
                    icon: Icons.chat_bubble_outline_rounded,
                    title: '暂无吐槽',
                    actions: [
                      TextButton(
                        onPressed: onReviewTap,
                        style: TextButton.styleFrom(
                          minimumSize: const Size(48, 48),
                        ),
                        child: const Text(_writeReviewLabel),
                      ),
                    ],
                  ),
                )
              else if (isLoading || !hasLoaded)
                SliverPadding(
                  padding: EdgeInsets.symmetric(horizontal: gutter),
                  sliver: SliverList.builder(
                    itemCount: 4,
                    itemBuilder: (_, __) => const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: CommentsCard.bone(),
                    ),
                  ),
                ),
              if (ownComment != null || comments.isNotEmpty)
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 96 + MediaQuery.paddingOf(context).bottom,
                  ),
                ),
            ],
          ),
        );
      }),
    );
  }

  Widget _reviewEntry(BuildContext context, {required bool editing}) {
    final colors = Theme.of(context).colorScheme;
    return TextButton(
      onPressed: onReviewTap,
      style: TextButton.styleFrom(
        minimumSize: const Size(48, 48),
        padding: const EdgeInsets.all(16),
        backgroundColor: colors.surfaceContainerLow,
        foregroundColor: colors.onSurfaceVariant,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      child: Row(children: [
        Expanded(child: Text(editing ? '编辑' : _writeReviewLabel)),
        const SizedBox(width: 8),
        const Icon(Icons.chevron_right_rounded, size: 20),
      ]),
    );
  }

  Widget _ownReview(CommentItem comment) {
    return Card.filled(
      margin: const EdgeInsets.symmetric(vertical: 12),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        CommentsCard.own(commentItem: comment),
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
          child: Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: onReviewTap,
              style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
              child: const Text('编辑'),
            ),
          ),
        ),
      ]),
    );
  }
}
