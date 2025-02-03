// 记录进入 tag 时 list 所在位置
class BBCodeTag {
  int? bold;
  int? italic;
  int? underline;
  int? strikeThrough;
  int? masked;
  int? quoted;
  int? code;
  int? size;
  int? color;
  int? link;
  int? img;

  void clear() {
    bold = null;
    italic = null;
    underline = null;
    strikeThrough = null;
    masked = null;
    quoted = null;
    code = null;
    size = null;
    color = null;
    link = null;
    img = null;
  }
}

class BBCodeText {
  String text;

  bool bold = false;
  bool italic = false;
  bool underline = false;
  bool strikeThrough = false;
  bool masked = false;
  bool quoted = false;
  bool code = false;

  int size = 14;
  String? color;
  String? link;

  BBCodeText({
    required this.text,
    this.bold = false,
    this.italic = false,
    this.underline = false,
    this.strikeThrough = false,
    this.masked = false,
    this.quoted = false,
    this.code = false,
    this.size = 14,
    this.color,
    this.link,
  });
}

class BBCodeBgm {
  int id;

  BBCodeBgm({required this.id});
}

class BBCodeSticker {
  int id;

  BBCodeSticker({required this.id});
}

class BBCodeImg {
  String imageUrl;

  BBCodeImg({required this.imageUrl});
}

BBCodeTag bbCodeTag = BBCodeTag();
