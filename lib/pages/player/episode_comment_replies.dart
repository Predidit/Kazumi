import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:kazumi/bbcode/bbcode_widget.dart';
import 'package:kazumi/modules/comments/comment_item.dart';
import 'package:kazumi/utils/utils.dart';

class EpisodeCommentReplies extends StatelessWidget {
  const EpisodeCommentReplies({super.key, required this.commentItem});

  final EpisodeCommentItem commentItem;

  static Route<void> route(EpisodeCommentItem commentItem) {
    return PageRouteBuilder<void>(
      transitionDuration: const Duration(milliseconds: 260),
      reverseTransitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (context, animation, secondaryAnimation) {
        return EpisodeCommentReplies(commentItem: commentItem);
      },
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1, 0),
            end: Offset.zero,
          ).animate(curved),
          child: FadeTransition(
            opacity: curved,
            child: child,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    String userComment = commentItem.comment.comment;
    if (userComment.isEmpty) {
      userComment = "<用户已删除>";
    }

    return Scaffold(
      body: SelectionArea(
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: Theme.of(context).colorScheme.outline,
                    width: 0.2,
                  )
                )
              ),
              child: Row(
                spacing: 10,
                children: [
                  InkWell(
                    onTap: () => Navigator.of(context).pop(),
                    child: const Icon(Icons.arrow_back_outlined),
                  ),
                  Text('共 ${commentItem.replies.length} 条回复'),
                ],
              ),
            ),
            Expanded(child: CustomScrollView(
              scrollBehavior: const ScrollBehavior().copyWith(
                scrollbars: false,
                dragDevices: {
                  PointerDeviceKind.mouse,
                  PointerDeviceKind.touch,
                  PointerDeviceKind.trackpad,
                },
              ),
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          backgroundImage: NetworkImage(
                              commentItem.comment.user.avatar.large),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Flexible(
                                    child: Text(
                                      commentItem.comment.user.nickname,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  _buildMainCommentBadge(context),
                                ],
                              ),
                              Text(
                                Utils.dateFormat(commentItem.comment.createdAt),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Theme.of(context).colorScheme.outline,
                                ),
                              ),
                              const SizedBox(height: 8),
                              BBCodeWidget(bbcode: userComment),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Divider(
                    height: 1,
                    thickness: 1,
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                    child: Text(
                      '相关回复 共 ${commentItem.replies.length} 条',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Theme.of(context).colorScheme.outline,
                      ),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                          (context, index) {
                        final reply = commentItem.replies[index];
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CircleAvatar(
                                backgroundImage:
                                NetworkImage(reply.user.avatar.large),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(reply.user.nickname),
                                    Text(
                                      Utils.dateFormat(reply.createdAt),
                                      style: TextStyle(
                                        fontSize: 12,
                                        color:
                                        Theme.of(context).colorScheme.outline,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    BBCodeWidget(bbcode: reply.comment),
                                    if (index < commentItem.replies.length - 1)
                                      Divider(
                                        height: 16,
                                        thickness: 1,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .outlineVariant,
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                      childCount: commentItem.replies.length,
                    ),
                  ),
                ),
              ],
            ))
          ],
        ),
      ),
    );
  }

  /// 主评论徽标
  Widget _buildMainCommentBadge(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        '主评论',
        style: TextStyle(
          fontSize: 11,
          height: 1.2,
          color: scheme.onPrimaryContainer,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
