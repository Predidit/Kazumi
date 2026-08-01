import 'package:flutter/material.dart';
import 'package:kazumi/bbcode/bbcode_widget.dart';
import 'package:kazumi/bean/widget/bangumi_avatar.dart';
import 'package:kazumi/modules/comments/comment_item.dart';
import 'package:kazumi/utils/date_time.dart';

class EpisodeCommentsCard extends StatelessWidget {
  const EpisodeCommentsCard({
    super.key,
    required this.commentItem,
  });

  final EpisodeCommentItem commentItem;

  @override
  Widget build(BuildContext context) {
    String userComment = commentItem.comment.comment;
    if (userComment.isEmpty) {
      userComment = "<用户已删除>";
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                BangumiAvatar(
                  imageUrl: commentItem.comment.user.avatar.large,
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(commentItem.comment.user.nickname),
                    Text(dateFormat(commentItem.comment.createdAt)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            BBCodeWidget(bbcode: userComment),
            if (commentItem.replies.isNotEmpty)
              ListView.builder(
                // Some OHOS builds inject bottom padding into nested lists.
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
                            BangumiAvatar(
                              imageUrl:
                                  commentItem.replies[index].user.avatar.large,
                            ),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(commentItem.replies[index].user.nickname),
                                Text(
                                  dateFormat(
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
