import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:kazumi/modules/comments/comment_item.dart';
import 'package:kazumi/utils/utils.dart';
import 'package:styled_text/styled_text.dart';

class EpisodeCommentsCard extends StatelessWidget {
  const EpisodeCommentsCard({
    super.key,
    required this.commentItem,
  });

  final EpisodeCommentItem commentItem;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
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
          commentsWithStyledText(Utils.richTextParser(commentItem.comment.comment), context),
          (commentItem.replies.isNotEmpty)
              ? ListView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  shrinkWrap: true,
                  itemCount: commentItem.replies.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.only(left: 48),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Divider(color: Theme.of(context).dividerColor.withAlpha(60)),
                            Row(
                              children: [
                                CircleAvatar(
                                  backgroundImage: NetworkImage(commentItem
                                      .replies[index].user.avatar.large),
                                ),
                                const SizedBox(width: 8),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(commentItem
                                        .replies[index].user.nickname),
                                    Text(Utils.dateFormat(
                                        commentItem.replies[index].createdAt)),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            commentsWithStyledText(Utils.richTextParser(commentItem.replies[index].comment), context),
                          ]),
                    );
                  })
              : Container()
        ]),
      ),
    );
  }

  Widget commentsWithStyledText(String comment, BuildContext context) {
    return StyledText(text: comment, tags: {
      'b': StyledTextTag(
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      'i': StyledTextTag(
        style: const TextStyle(fontStyle: FontStyle.italic),
      ),
      'q': StyledTextTag(
        style: TextStyle(color: Theme.of(context).colorScheme.outline),
      ),
      'format_quote': StyledTextIconTag(
        Icons.format_quote,
        color: Theme.of(context).colorScheme.outline,
        alignment: PlaceholderAlignment.top
      ),
      's': StyledTextTag(
        style: const TextStyle(decoration: TextDecoration.lineThrough),
      ),
      'u': StyledTextTag(
        style: const TextStyle(decoration: TextDecoration.underline),
      ),
      'image': StyledTextWidgetBuilderTag(
        (_, attributes, textContent) {
          return Image.network(
            textContent!,
            errorBuilder: (context, error, stackTrace) {
              return const Text('.');
            },
          );
        },
      ),
      'link': StyledTextActionTag(
            (_, attrs) {
              _copyLink(attrs);
            },
        style: const TextStyle(color: Colors.blue),
      ),
      'color': StyledTextCustomTag(
        baseStyle: const TextStyle(fontStyle: FontStyle.normal),
        parse: (baseStyle, attributes) {
          if (attributes.containsKey('color')) {
            final String color = attributes['color']!;
            switch (color) {
              case 'red': return baseStyle?.copyWith(color: Colors.red);
              case 'blue': return baseStyle?.copyWith(color: Colors.blue);
              case 'orange': return baseStyle?.copyWith(color: Colors.orange);
              case 'green': return baseStyle?.copyWith(color: Colors.green);
              case 'grey': return baseStyle?.copyWith(color: Colors.grey);
              default: return baseStyle;
            }
          } else {
            return baseStyle;
          }
        }
      ),
      'size': StyledTextCustomTag(
        baseStyle: const TextStyle(fontStyle: FontStyle.normal),
        parse: (baseStyle, attributes) {
          if (attributes.containsKey('size')) {
            double size = double.tryParse(attributes['size']!) ?? 14;
            return baseStyle?.copyWith(fontSize: size);
          } else {
            return baseStyle;
          }
        }
      ),
    });
  }

  Future<void> _copyLink(Map<String?, String?> attrs) async {
    final String? link = attrs['href'];
    await Clipboard.setData(ClipboardData(text: link!));
    SmartDialog.showToast('已复制链接到剪贴板');
  }
}
