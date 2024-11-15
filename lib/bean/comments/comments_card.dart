import 'package:flutter/material.dart';
import 'package:kazumi/modules/comments/comment_item.dart';

class CommentsCard extends StatelessWidget{
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
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundImage: NetworkImage(commentItem.user.avatar.large),
                ),
                Column(
                  children: [
                    Text(commentItem.user.nickname),
                    Text(commentItem.comment.updatedAt.toString()),
                  ],
                ),
              ],
            ),
            Text(commentItem.comment.comment),
          ],
        ),
      ),
    );
  }
}