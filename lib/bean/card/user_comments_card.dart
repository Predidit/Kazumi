import 'package:flutter/material.dart';
import 'package:kazumi/bbcode/bbcode_widget.dart';
import 'package:kazumi/bean/widget/bangumi_avatar.dart';
import 'package:kazumi/bean/widget/split_list_row.dart';
import 'package:kazumi/bean/widget/tonal_card.dart';
import 'package:kazumi/modules/comments/comment_item.dart';
import 'package:kazumi/utils/date_time.dart';
import 'package:skeletonizer/skeletonizer.dart';

class UserCommentsCard extends StatefulWidget {
  UserCommentsCard.episode(EpisodeCommentItem item, {super.key})
      : _source = item,
        _comment = _fromEpisode(item.comment),
        _replies = item.replies.map(_fromEpisode).toList();

  UserCommentsCard.character(CharacterCommentItem item, {super.key})
      : _source = item,
        _comment = _fromCharacter(item.comment),
        _replies = item.replies.map(_fromCharacter).toList();

  final Object _source;
  final _CommentData _comment;
  final List<_CommentData> _replies;

  @override
  State<UserCommentsCard> createState() => _UserCommentsCardState();
}

class _UserCommentsCardState extends State<UserCommentsCard> {
  static const _previewCount = 2;
  bool _expanded = false;

  @override
  void didUpdateWidget(covariant UserCommentsCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget._source != widget._source) _expanded = false;
  }

  void _toggleExpanded() => setState(() => _expanded = !_expanded);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final replies = widget._replies;
    final hasOverflowReplies = replies.length > _previewCount;
    final visibleCount =
        _expanded || !hasOverflowReplies ? replies.length : _previewCount;
    final disableAnimations = MediaQuery.disableAnimationsOf(context);

    Widget? repliesList;
    if (replies.isNotEmpty) {
      final list = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < visibleCount; i++)
            Padding(
              padding: EdgeInsets.only(top: i == 0 ? 0 : splitListRowGap),
              child: _ReplyTile(
                reply: replies[i],
                topRadius: i == 0 ? 12 : 4,
                bottomRadius:
                    i == visibleCount - 1 && !hasOverflowReplies ? 12 : 4,
              ),
            ),
          if (hasOverflowReplies) ...[
            const SizedBox(height: splitListRowGap),
            _RepliesToggleSegment(
              expanded: _expanded,
              remainingCount: replies.length - _previewCount,
              onTap: _toggleExpanded,
            ),
          ],
        ],
      );
      repliesList = disableAnimations
          ? list
          : AnimatedSize(
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeInOutCubicEmphasized,
              alignment: Alignment.topCenter,
              child: list,
            );
    }

    return _CommentSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              ExcludeSemantics(
                child: BangumiAvatar(
                  radius: 18,
                  imageUrl: widget._comment.user.avatar.large,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _displayName(widget._comment.user),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: colors.onSurface,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      dateFormat(widget._comment.createdAt),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colors.onSurfaceVariant,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
              if (replies.isNotEmpty) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: colors.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.chat_bubble_outline_rounded,
                        size: 12,
                        color: colors.onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${replies.length}',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colors.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          _CommentBody(content: widget._comment.content),
          if (repliesList != null) ...[
            const SizedBox(height: 12),
            repliesList,
          ],
        ],
      ),
    );
  }
}

class _ReplyTile extends StatelessWidget {
  const _ReplyTile({
    required this.reply,
    required this.topRadius,
    required this.bottomRadius,
  });

  final _CommentData reply;
  final double topRadius;
  final double bottomRadius;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceContainerHigh,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(topRadius),
          bottom: Radius.circular(bottomRadius),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ExcludeSemantics(
                  child: BangumiAvatar(
                    radius: 12,
                    imageUrl: reply.user.avatar.large,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: _displayName(reply.user),
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: colors.onSurface,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        TextSpan(
                          text: ' · ${dateFormat(reply.createdAt)}',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: colors.onSurfaceVariant,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            _CommentBody(content: reply.content, compact: true),
          ],
        ),
      ),
    );
  }
}

class _RepliesToggleSegment extends StatelessWidget {
  const _RepliesToggleSegment({
    required this.expanded,
    required this.remainingCount,
    required this.onTap,
  });

  final bool expanded;
  final int remainingCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final disableAnimations = MediaQuery.disableAnimationsOf(context);
    final label = expanded ? '收起回复' : '展开其余 $remainingCount 条回复';

    return Semantics(
      button: true,
      expanded: expanded,
      label: label,
      onTap: onTap,
      excludeSemantics: true,
      child: Material(
        color: colors.secondaryContainer,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(4),
          bottom: Radius.circular(12),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: colors.onSecondaryContainer,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  AnimatedRotation(
                    turns: expanded ? 0.5 : 0,
                    duration: disableAnimations
                        ? Duration.zero
                        : const Duration(milliseconds: 200),
                    curve: Curves.easeOutCubic,
                    child: Icon(
                      Icons.expand_more_rounded,
                      size: 18,
                      color: colors.onSecondaryContainer,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CommentBody extends StatelessWidget {
  const _CommentBody({
    required this.content,
    this.compact = false,
  });

  final String content;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    if (content.isEmpty) {
      return Text(
        '该评论已被删除',
        style: theme.textTheme.bodyMedium?.copyWith(
          color: colors.onSurfaceVariant,
          fontStyle: FontStyle.italic,
        ),
      );
    }

    return DefaultTextStyle.merge(
      style: theme.textTheme.bodyMedium?.copyWith(
        color: colors.onSurface,
        height: compact ? 1.55 : 1.6,
      ),
      child: BBCodeWidget(
        bbcode: content,
        textScaler: MediaQuery.textScalerOf(context),
      ),
    );
  }
}

class UserCommentsCardBone extends StatelessWidget {
  const UserCommentsCardBone({super.key});

  @override
  Widget build(BuildContext context) {
    return const _CommentSurface(
      child: Skeletonizer.zone(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Bone.circle(size: 36),
                SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Bone.text(width: 88),
                    SizedBox(height: 4),
                    Bone.text(width: 56, fontSize: 10),
                  ],
                ),
              ],
            ),
            SizedBox(height: 12),
            Bone.multiText(lines: 2),
          ],
        ),
      ),
    );
  }
}

class _CommentSurface extends StatelessWidget {
  const _CommentSurface({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TonalCard(padding: const EdgeInsets.all(16), child: child),
    );
  }
}

String _displayName(User user) =>
    user.nickname.trim().isNotEmpty ? user.nickname.trim() : user.username;

typedef _CommentData = ({User user, String content, int createdAt});

_CommentData _fromEpisode(EpisodeComment comment) => (
      user: comment.user,
      content: comment.comment,
      createdAt: comment.createdAt,
    );

_CommentData _fromCharacter(CharacterComment comment) => (
      user: comment.user,
      content: comment.comment,
      createdAt: comment.createdAt,
    );
