import 'package:flutter/material.dart';
import 'package:kazumi/bbcode/bbcode_widget.dart';
import 'package:kazumi/modules/comments/comment_item.dart';
import 'package:kazumi/utils/utils.dart';

class CharacterCommentsCard extends StatelessWidget {
  const CharacterCommentsCard({
    super.key,
    required this.commentItem,
  });

  final CharacterCommentItem commentItem;

  @override
  Widget build(BuildContext context) {
    return Card(
      // color: Theme.of(context).colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundImage:
                      NetworkImage(commentItem.comment.user.avatar.large),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(commentItem.comment.user.nickname),
                    Text(Utils.dateFormat(commentItem.comment.createdAt)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            BBCodeWidget(bbcode: commentItem.comment.comment),
            if (commentItem.replies.isNotEmpty)
              ListView.builder(
                // Don't know why but some device has bottom padding,
                // needs to set to 0 manually.
                padding: const EdgeInsets.only(bottom: 0),
                physics: const NeverScrollableScrollPhysics(),
                shrinkWrap: true,
                itemCount: commentItem.replies.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.only(left: 48),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Divider(
                          color: Theme.of(context).dividerColor.withAlpha(60),
                        ),
                        Row(
                          children: [
                            CircleAvatar(
                              backgroundImage: NetworkImage(
                                  commentItem.replies[index].user.avatar.large),
                            ),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(commentItem.replies[index].user.nickname),
                                Text(
                                  Utils.dateFormat(
                                      commentItem.replies[index].createdAt),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        BBCodeWidget(
                            bbcode: commentItem.replies[index].comment),
                      ],
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}
