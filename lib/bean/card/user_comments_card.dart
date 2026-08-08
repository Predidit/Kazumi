import 'package:flutter/material.dart';
import 'package:kazumi/bbcode/bbcode_widget.dart';
import 'package:kazumi/bean/widget/bangumi_avatar.dart';
import 'package:kazumi/modules/comments/comment_item.dart';
import 'package:kazumi/utils/date_time.dart';
import 'package:skeletonizer/skeletonizer.dart';

// 16 and 12 are M3 `large` and a 4dp-grid step; the replies block nested inside
// takes the concentric radius `outer - padding` so both sets of corners stay
// parallel.
const double _cardRadius = 16;
const double _cardPadding = 12;
const double _repliesRadius = _cardRadius - _cardPadding;

const double _avatarGap = 12;
const double _replyAvatarRadius = 16;

/// Renders one Bangumi comment and its replies. Episode and character comments
/// are distinct models of the same shape, so each gets a constructor.
class UserCommentsCard extends StatelessWidget {
  UserCommentsCard.episode(EpisodeCommentItem item, {super.key})
      : _comment = _fromEpisode(item.comment),
        _replies = item.replies.map(_fromEpisode).toList();

  UserCommentsCard.character(CharacterCommentItem item, {super.key})
      : _comment = _fromCharacter(item.comment),
        _replies = item.replies.map(_fromCharacter).toList();

  final _CommentView _comment;
  final List<_CommentView> _replies;

  static _CommentView _fromEpisode(EpisodeComment comment) => _CommentView(
        nickname: comment.user.nickname,
        avatarUrl: comment.user.avatar.large,
        createdAt: comment.createdAt,
        content: comment.comment,
      );

  static _CommentView _fromCharacter(CharacterComment comment) => _CommentView(
        nickname: comment.user.nickname,
        avatarUrl: comment.user.avatar.large,
        createdAt: comment.createdAt,
        content: comment.comment,
      );

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(_cardRadius),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.all(_cardPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _CommentAuthor(comment: _comment, avatarRadius: 20),
              const SizedBox(height: 8),
              _CommentBody(content: _comment.content),
              if (_replies.isNotEmpty) ...[
                const SizedBox(height: 12),
                _RepliesContainer(replies: _replies),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Loading placeholder for [UserCommentsCard], sharing its chrome and metrics.
class UserCommentsCardBone extends StatelessWidget {
  const UserCommentsCardBone({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(_cardRadius),
        clipBehavior: Clip.antiAlias,
        child: const Padding(
          padding: EdgeInsets.all(_cardPadding),
          child: Skeletonizer.zone(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Bone.circle(size: 40),
                    SizedBox(width: _avatarGap),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Bone.text(width: 96),
                        SizedBox(height: 6),
                        Bone.text(width: 64, fontSize: 11),
                      ],
                    ),
                  ],
                ),
                SizedBox(height: 12),
                Bone.multiText(lines: 2),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CommentView {
  const _CommentView({
    required this.nickname,
    required this.avatarUrl,
    required this.createdAt,
    required this.content,
  });

  final String nickname;
  final String avatarUrl;
  final int createdAt;
  final String content;
}

class _RepliesContainer extends StatelessWidget {
  const _RepliesContainer({required this.replies});

  final List<_CommentView> replies;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(_cardPadding),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(_repliesRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var index = 0; index < replies.length; index++) ...[
            if (index > 0) const SizedBox(height: 12),
            _CommentAuthor(
              comment: replies[index],
              avatarRadius: _replyAvatarRadius,
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.only(
                left: _replyAvatarRadius * 2 + _avatarGap,
              ),
              child: _CommentBody(content: replies[index].content),
            ),
          ],
        ],
      ),
    );
  }
}

class _CommentBody extends StatelessWidget {
  const _CommentBody({required this.content});

  final String content;

  @override
  Widget build(BuildContext context) {
    if (content.isEmpty) {
      final theme = Theme.of(context);
      return Text(
        '该评论已被删除',
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontStyle: FontStyle.italic,
        ),
      );
    }
    return BBCodeWidget(bbcode: content);
  }
}

class _CommentAuthor extends StatelessWidget {
  const _CommentAuthor({
    required this.comment,
    required this.avatarRadius,
  });

  final _CommentView comment;
  final double avatarRadius;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Row(
      children: [
        BangumiAvatar(radius: avatarRadius, imageUrl: comment.avatarUrl),
        const SizedBox(width: _avatarGap),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                comment.nickname,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
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
