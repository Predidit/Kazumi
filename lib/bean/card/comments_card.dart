import 'package:flutter/material.dart';
import 'package:kazumi/modules/comments/comment_item.dart';
import 'package:kazumi/utils/utils.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';

class CommentsCard extends StatelessWidget {
  const CommentsCard({
    super.key,
    required this.commentItem,
  });

  final CommentItem commentItem;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  backgroundImage: NetworkImage(commentItem.user.avatar.large),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(commentItem.user.nickname),
                    Text(Utils.dateFormat(commentItem.comment.updatedAt)),
                  ],
                ),
                Expanded(child: Container(height: 10)),
                RatingBarIndicator(
                  itemCount: 5,
                  rating: commentItem.comment.rate.toDouble() / 2,
                  itemBuilder: (context, index) => const Icon(
                    Icons.star_rounded,
                  ),
                  itemSize: 20.0,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(commentItem.comment.comment),
          ],
        ),
      ),
    );
  }
}
