import 'package:flutter/material.dart';
import 'package:kazumi/bean/widget/bangumi_avatar.dart';
import 'package:kazumi/modules/comments/comment_item.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:kazumi/utils/date_time.dart';

class CommentsCard extends StatelessWidget {
  const CommentsCard({
    super.key,
    required CommentItem this.commentItem,
  }) : _isOwn = false;

  const CommentsCard.bone({super.key})
      : commentItem = null,
        _isOwn = false;

  const CommentsCard.own({
    super.key,
    required CommentItem this.commentItem,
  }) : _isOwn = true;

  final CommentItem? commentItem;
  final bool _isOwn;

  @override
  Widget build(BuildContext context) {
    final item = commentItem;
    if (item == null) {
      return Skeletonizer.zone(
        enabled: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Bone.circle(size: 36),
                const SizedBox(width: 8),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Bone.text(width: 80),
                    SizedBox(height: 8),
                    Bone.text(width: 60),
                  ],
                ),
              ],
            ),
            SizedBox(height: 8),
            const Bone.multiText(lines: 2),
            Divider(thickness: 0.5, indent: 10, endIndent: 10),
          ],
        ),
      );
    }
    return SelectionArea(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                BangumiAvatar(
                  imageUrl: item.user.avatar.large,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 5,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(item.user.nickname),
                          if (_isOwn)
                            Container(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 2),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.primary,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  '我的吐槽',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .primaryContainer),
                                ))
                        ],
                      ),
                      Text(dateFormat(item.comment.updatedAt)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                RatingBarIndicator(
                  itemCount: 5,
                  rating: item.comment.rate.toDouble() / 2,
                  itemBuilder: (context, index) => const Icon(
                    Icons.star_rounded,
                  ),
                  itemSize: 20.0,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(item.comment.comment),
          ],
        ),
      ),
    );
  }
}
