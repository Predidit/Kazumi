class Danmaku {
  double p;
  String m;

  Danmaku({required this.p, required this.m});

  factory Danmaku.fromJson(Map<String, dynamic> json) {
    List<String> parts = json['p'].split(',');
    double pValue = double.parse(parts[0]);
    String mValue = json['m'];
    return Danmaku(p: pValue, m: mValue);
  }
}