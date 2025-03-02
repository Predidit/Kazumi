import 'package:kazumi/modules/comments/comment_item.dart';

class CommentResponse {
  List<CommentItem> commentList;
  int total;

  CommentResponse({
    required this.commentList,
    required this.total,
  });

  factory CommentResponse.fromJson(Map<String, dynamic> json) {
    List? list = (json['list'] as List?) ?? (json['data'] as List?);
    List<CommentItem>? resCommentList =
        list?.map((i) => CommentItem.fromJson(i)).toList();
    return CommentResponse(
      commentList: resCommentList ?? <CommentItem>[],
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

class EpisodeCommentResponse {
  List<EpisodeCommentItem> commentList;

  EpisodeCommentResponse({
    required this.commentList,
  });

  factory EpisodeCommentResponse.fromJson(List<dynamic> json) {
    List<EpisodeCommentItem>? resCommentList =
        (json as List?)?.map((i) => EpisodeCommentItem.fromJson(i)).toList();
    return EpisodeCommentResponse(
      commentList: resCommentList ?? <EpisodeCommentItem>[],
    );
  }

  factory EpisodeCommentResponse.fromTemplate() {
    return EpisodeCommentResponse(
      commentList: [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'list': commentList,
    };
  }
}

class CharacterCommentResponse {
  List<CharacterCommentItem> commentList;

  CharacterCommentResponse({
    required this.commentList,
  });

  factory CharacterCommentResponse.fromJson(List<dynamic> json) {
    List<CharacterCommentItem>? resCommentList =
        (json as List?)?.map((i) => CharacterCommentItem.fromJson(i)).toList();
    return CharacterCommentResponse(
      commentList: resCommentList ?? <CharacterCommentItem>[],
    );
  }

  factory CharacterCommentResponse.fromTemplate() {
    return CharacterCommentResponse(
      commentList: [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'list': commentList,
    };
  }
}
