class Weekday {
  String? en;
  String? cn;
  String? ja;
  int? id;

  Weekday({this.en, this.cn, this.ja, this.id});

  factory Weekday.fromJson(Map<String, dynamic> json) {
    return Weekday(
      en: json['en'],
      cn: json['cn'],
      ja: json['ja'],
      id: json['id'],
    );
  }
}


