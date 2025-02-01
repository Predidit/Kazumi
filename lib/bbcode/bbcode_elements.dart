import 'package:flutter/material.dart';

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
