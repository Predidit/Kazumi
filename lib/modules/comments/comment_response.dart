import 'package:kazumi/modules/comments/comment_item.dart';

class CommentResponse {
  List<CommentItem> commentList;
  int total;

  CommentResponse({
    required this.commentList,
    required this.total,
  });

  factory CommentResponse.fromJson(Map<String, dynamic> json) {
    var list = json['list'] as List;
    List<CommentItem> resCommentList =
        list.map((i) => CommentItem.fromJson(i)).toList();
    return CommentResponse(
      commentList: resCommentList,
      total: json['total'],
    );
  }

  factory CommentResponse.fromTemplate() {
    return CommentResponse(
      commentList: [],
      total: 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'list': commentList,
      'total': total,
    };
  }
}
