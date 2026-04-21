import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:kazumi/bbcode/bbcode_widget.dart';
import 'package:kazumi/modules/comments/comment_item.dart';
import 'package:kazumi/pages/player/episode_comment_replies.dart';
import 'package:kazumi/utils/utils.dart';

class EpisodeCommentsCard extends StatelessWidget {
  const EpisodeCommentsCard({
    super.key,
    required this.commentItem,
  });

  final EpisodeCommentItem commentItem;

  static const int _maxPreviewReplies = 2;

  @override
  Widget build(BuildContext context) {
    // 对 用户评论 做判空操作，如果为空则显示“用户已删除”
    String userComment = commentItem.comment.comment;
    if (userComment.isEmpty) {
      userComment = "<用户已删除>";
    }

    final totalReplies = commentItem.replies.length;
    final bool hasMoreReplies = totalReplies > _maxPreviewReplies;
    final int previewCount =
        math.min(_maxPreviewReplies, totalReplies);

    return Card(
      // color: Theme.of(context).colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  backgroundImage:
                      NetworkImage(commentItem.comment.user.avatar.large),
                ),
                const SizedBox(width: 8),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(commentItem.comment.user.nickname),
                    Text(
                      Utils.dateFormat(commentItem.comment.createdAt),
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.outline,
                      ),
                    ),
                    const SizedBox(height: 8),
                    BBCodeWidget(bbcode: userComment),
                    if (commentItem.replies.isNotEmpty)
                      _buildRepliesPreview(
                        context: context,
                        previewCount: previewCount,
                        hasMoreReplies: hasMoreReplies,
                        totalReplies: totalReplies,
                      ),
                  ],
                ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRepliesPreview({
    required BuildContext context,
    required int previewCount,
    required bool hasMoreReplies,
    required int totalReplies,
  }) {
    final surfaceColor =
        Theme.of(context).colorScheme.surfaceContainerHighest;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListView.builder(
          // Don't know why but ohos has bottom padding,
          // needs to set to 0 manually.
          padding: const EdgeInsets.only(bottom: 0),
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          itemCount: previewCount,
          itemBuilder: (context, index) {
            final bool isFirst = index == 0;
            final bool isLastVisibleReply = index == previewCount - 1;
            final bool isBottomOfStack = isLastVisibleReply && !hasMoreReplies;
            return Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: surfaceColor,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(isFirst ? 10 : 0),
                  topRight: Radius.circular(isFirst ? 10 : 0),
                  bottomLeft: Radius.circular(isBottomOfStack ? 10 : 0),
                  bottomRight: Radius.circular(isBottomOfStack ? 10 : 0),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        backgroundImage: NetworkImage(
                            commentItem.replies[index].user.avatar.large),
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(commentItem.replies[index].user.nickname),
                          Text(
                            Utils.dateFormat(
                                commentItem.replies[index].createdAt),
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context).colorScheme.outline,
                            ),
                          ),
                        ],
                      ),
                      ),
                    ],
                  ),
                  BBCodeWidget(
                      bbcode: commentItem.replies[index].comment),
                  if (!isLastVisibleReply)
                    Divider(
                      height: 16,
                      thickness: 1,
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                ],
              ),
            );
          },
        ),
        if (hasMoreReplies)
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(10),
                bottomRight: Radius.circular(10),
              ),
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 4),
                  minimumSize: const Size(0, 36),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(10),
                      bottomRight: Radius.circular(10),
                    ),
                  ),
                ),
                onPressed: () {
                  Navigator.of(context).push(
                    EpisodeCommentReplies.route(commentItem),
                  );
                },
                child: Text('共 $totalReplies 条回复'),
              ),
            ),
          ),
      ],
    );
  }
}
