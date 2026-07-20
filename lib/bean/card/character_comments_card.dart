import 'package:flutter/material.dart';
import 'package:kazumi/bbcode/bbcode_widget.dart';
import 'package:kazumi/modules/comments/comment_item.dart';
import 'package:kazumi/utils/date_time.dart';

class CharacterCommentsCard extends StatelessWidget {
  const CharacterCommentsCard({
    super.key,
    required this.commentItem,
  });

  final CharacterCommentItem commentItem;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(24),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _CommentAuthor(
                comment: commentItem.comment,
                avatarRadius: 20,
              ),
              const SizedBox(height: 12),
              BBCodeWidget(bbcode: commentItem.comment.comment),
              if (commentItem.replies.isNotEmpty) ...[
                const SizedBox(height: 16),
                _RepliesContainer(replies: commentItem.replies),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _RepliesContainer extends StatelessWidget {
  const _RepliesContainer({required this.replies});

  final List<CharacterComment> replies;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var index = 0; index < replies.length; index++) ...[
            if (index > 0)
              Divider(
                height: 25,
                color: colorScheme.outlineVariant,
              )
            else
              const SizedBox(height: 8),
            _CommentAuthor(
              comment: replies[index],
              avatarRadius: 16,
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(left: 40),
              child: BBCodeWidget(bbcode: replies[index].comment),
            ),
          ],
        ],
      ),
    );
  }
}

class _CommentAuthor extends StatelessWidget {
  const _CommentAuthor({
    required this.comment,
    required this.avatarRadius,
  });

  final CharacterComment comment;
  final double avatarRadius;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        CircleAvatar(
          radius: avatarRadius,
          backgroundImage: NetworkImage(comment.user.avatar.large),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                comment.user.nickname,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                dateFormat(comment.createdAt),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
