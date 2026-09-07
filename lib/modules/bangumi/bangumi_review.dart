class BangumiReview {
  BangumiReview({
    required this.score,
    required Iterable<String> tags,
    required String comment,
  })  : assert(score >= 0 && score <= 10),
        tags = List<String>.unmodifiable(tags),
        comment = comment.trim();

  final int score;
  final List<String> tags;
  final String comment;
}
