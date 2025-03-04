class UserAvatar {
  final String small;
  final String medium;
  final String large;

  UserAvatar({
    required this.small,
    required this.medium,
    required this.large,
  });

  factory UserAvatar.fromJson(Map<String, dynamic> json) {
    return UserAvatar(
      small: json['small'] ?? '',
      medium: json['medium'] ?? '',
      large: json['large'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'small': small,
      'medium': medium,
      'large': large,
    };
  }
}

class User {
  final int id;
  final String username;
  final String nickname;
  final UserAvatar avatar;
  final String sign;
  final int joinedAt;

  User({
    required this.id,
    required this.username,
    required this.nickname,
    required this.avatar,
    required this.sign,
    required this.joinedAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] ?? 0,
      username: json['username'] ?? '',
      nickname: json['nickname'] ?? '',
      avatar: UserAvatar.fromJson(json['avatar'] as Map<String, dynamic>),
      sign: json['sign'] ?? '',
      joinedAt: json['joinedAt'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'nickname': nickname,
      'avatar': avatar.toJson(),
      'sign': sign,
      'joinedAt': joinedAt,
    };
  }
}

class Comment {
  final int rate;
  final String comment;
  final int updatedAt;

  Comment({
    required this.rate,
    required this.comment,
    required this.updatedAt,
  });


  factory Comment.fromJson(Map<String, dynamic> json) {
    return Comment(
      rate: json['rate'] ?? 0,
      comment: json['comment'] ?? '',
      updatedAt: json['updatedAt'] ?? 0,
    );
  }


  Map<String, dynamic> toJson() {
    return {
      'rate': rate,
      'comment': comment,
      'updatedAt': updatedAt,
    };
  }
}

class CommentItem {
  final User user;
  final Comment comment;

  CommentItem({
    required this.user,
    required this.comment,
  });

  factory CommentItem.fromJson(Map<String, dynamic> json) {
    return CommentItem(
      user: User.fromJson(json['user']),
      comment: Comment.fromJson(json),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user': user.toJson(),
      'comment': comment.toJson(),
    };
  }
}

class EpisodeComment {
  final User user;
  final String comment;
  final int createdAt;

  EpisodeComment({
    required this.user,
    required this.comment,
    required this.createdAt,
  });


  factory EpisodeComment.fromJson(Map<String, dynamic> json) {
    return EpisodeComment(
      user: User.fromJson(json['user']),
      comment: json['content'] ?? '',
      createdAt: json['createdAt'] ?? 0,
    );
  }


  Map<String, dynamic> toJson() {
    return {
      'user': user.toJson(),
      'content': comment,
      'createdAt': createdAt,
    };
  }
}

class EpisodeCommentItem {
  final EpisodeComment comment;
  final List<EpisodeComment> replies;

  EpisodeCommentItem({
    required this.comment,
    required this.replies
  });

  factory EpisodeCommentItem.fromJson(Map<String, dynamic> json) {
    var list = json['replies'] as List;
    List<EpisodeComment> tempList =
        list.map((i) => EpisodeComment.fromJson(i)).toList();
    return EpisodeCommentItem(
      comment: EpisodeComment.fromJson(json),
      replies: tempList
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'comment': comment.toJson(),
      'list': replies,
    };
  }
}

class CharacterComment {
  final User user;
  final String comment;
  final int createdAt;

  CharacterComment({
    required this.user,
    required this.comment,
    required this.createdAt,
  });


  factory CharacterComment.fromJson(Map<String, dynamic> json) {
    return CharacterComment(
      user: User.fromJson(json['user']),
      comment: json['content'] ?? '',
      createdAt: json['createdAt'] ?? 0,
    );
  }


  Map<String, dynamic> toJson() {
    return {
      'user': user.toJson(),
      'content': comment,
      'createdAt': createdAt,
    };
  }
}

class CharacterCommentItem {
  final CharacterComment comment;
  final List<CharacterComment> replies;

  CharacterCommentItem({
    required this.comment,
    required this.replies
  });

  factory CharacterCommentItem.fromJson(Map<String, dynamic> json) {
    var list = json['replies'] as List;
    List<CharacterComment> tempList =
        list.map((i) => CharacterComment.fromJson(i)).toList();
    return CharacterCommentItem(
      comment: CharacterComment.fromJson(json),
      replies: tempList
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'comment': comment.toJson(),
      'list': replies,
    };
  }
}
