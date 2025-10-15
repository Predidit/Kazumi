class Rating {
  int total;
  RatingCount count;
  double score;

  Rating({required this.total, required this.count, required this.score});

  factory Rating.fromJson(Map<String, dynamic> json) {
    return Rating(
      total: json['total'],
      count: RatingCount.fromJson(json['count']),
      score: json['score'].toDouble(),
    );
  }
}

class RatingCount {
  int? count1;
  int? count2;
  int? count3;
  int? count4;
  int? count5;
  int? count6;
  int? count7;
  int? count8;
  int? count9;
  int? count10;

  RatingCount({
    this.count1,
    this.count2,
    this.count3,
    this.count4,
    this.count5,
    this.count6,
    this.count7,
    this.count8,
    this.count9,
    this.count10,
  });

  factory RatingCount.fromJson(Map<String, dynamic> json) {
    return RatingCount(
      count1: json['1'],
      count2: json['2'],
      count3: json['3'],
      count4: json['4'],
      count5: json['5'],
      count6: json['6'],
      count7: json['7'],
      count8: json['8'],
      count9: json['9'],
      count10: json['10'],
    );
  }
}