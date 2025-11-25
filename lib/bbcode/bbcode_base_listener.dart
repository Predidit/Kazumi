import 'package:flutter/material.dart';
import 'package:antlr4/antlr4.dart';
import 'package:kazumi/utils/logger.dart';
import 'package:kazumi/bbcode/bbcode_elements.dart';

import 'generated/BBCodeListener.dart';
import 'generated/BBCodeParser.dart';

class BBCodeBaseListener implements BBCodeListener {
  final List<dynamic> bbcode = [];

  /// 记录进入标签时的位置
  void _enterTag(TagContext ctx) {
    final tagName = ctx.tagName?.text;

    switch (tagName) {
      case 'URL':
      case 'url':
        bbCodeTag.link = bbcode.length;
        break;
      case 'USER':
      case 'user':
        bbCodeTag.link = bbcode.length;
        break;
      case 'QUOTE':
      case 'quote':
        bbCodeTag.quoted = bbcode.length;
        break;
      case 'B':
      case 'b':
        bbCodeTag.bold = bbcode.length;
        break;
      case 'I':
      case 'i':
        bbCodeTag.italic = bbcode.length;
        break;
      case 'S':
      case 's':
        bbCodeTag.strikeThrough = bbcode.length;
        break;
      case 'U':
      case 'u':
        bbCodeTag.underline = bbcode.length;
        break;
      case 'PHOTO':
      case 'photo':
      case 'IMG':
      case 'img':
        bbCodeTag.img = bbcode.length;
        break;
      case 'MASK':
      case 'mask':
        bbCodeTag.masked = bbcode.length;
        break;
      case 'SIZE':
      case 'size':
        bbCodeTag.size = bbcode.length;
        break;
      case 'COLOR':
      case 'color':
        bbCodeTag.color = bbcode.length;
        break;
      default:
        KazumiLogger()
            .e('BBCode: unrecognized Tag: ${ctx.text}, please submit an issue with logs, bangumi, and episode information');
        break;
    }
  }

  /// 对标签内所有的 BBCodeText 叠加样式
  void _exitTag(TagContext ctx) {
    final tagName = ctx.tagName?.text;

    switch (tagName) {
      case 'URL':
      case 'url':
        if (bbcode.isNotEmpty && bbcode[bbCodeTag.link!] is BBCodeText) {
          if (ctx.attr != null) {
            bbcode[bbCodeTag.link!].link = ctx.attr!.text;
          } else {
            bbcode[bbCodeTag.link!].link = bbcode[bbCodeTag.link!].text;
          }
        }
        break;
      case 'USER':
      case 'user':
        if (bbcode.isNotEmpty &&
            ctx.attr != null &&
            bbcode[bbCodeTag.link!] is BBCodeText) {
          bbcode[bbCodeTag.link!].link =
              'https://bangumi.tv/user/${ctx.attr!.text}';
          bbcode[bbCodeTag.link!].text = '@${bbcode[bbCodeTag.link!].text}';
        }
        break;
      case 'QUOTE':
      case 'quote':
        for (int i = bbCodeTag.quoted!; i < bbcode.length; i++) {
          if (bbcode.isNotEmpty && bbcode[i] is BBCodeText) {
            bbcode[i].quoted = true;
          }
        }
        // Add icon to the end of quoted text
        bbcode.add(const Icon(Icons.format_quote));
        break;
      case 'B':
      case 'b':
        for (int i = bbCodeTag.bold!; i < bbcode.length; i++) {
          if (bbcode.isNotEmpty && bbcode[i] is BBCodeText) {
            bbcode[i].bold = true;
          }
        }
        break;
      case 'I':
      case 'i':
        for (int i = bbCodeTag.italic!; i < bbcode.length; i++) {
          if (bbcode.isNotEmpty && bbcode[i] is BBCodeText) {
            bbcode[i].italic = true;
          }
        }
        break;
      case 'S':
      case 's':
        for (int i = bbCodeTag.strikeThrough!; i < bbcode.length; i++) {
          if (bbcode.isNotEmpty && bbcode[i] is BBCodeText) {
            bbcode[i].strikeThrough = true;
          }
        }
        break;
      case 'U':
      case 'u':
        for (int i = bbCodeTag.underline!; i < bbcode.length; i++) {
          if (bbcode.isNotEmpty && bbcode[i] is BBCodeText) {
            bbcode[i].underline = true;
          }
        }
        break;
      case 'PHOTO':
      case 'photo':
      case 'IMG':
      case 'img':
        if (bbCodeTag.img! < bbcode.length &&
            bbcode.isNotEmpty &&
            bbcode[bbCodeTag.img!] is BBCodeText) {
          bbcode[bbCodeTag.img!] =
              BBCodeImg(imageUrl: bbcode[bbCodeTag.img!].text);
        }
        break;
      case 'MASK':
      case 'mask':
        for (int i = bbCodeTag.masked!; i < bbcode.length; i++) {
          if (bbcode.isNotEmpty && bbcode[i] is BBCodeText) {
            bbcode[i].masked = true;
          }
        }
        break;
      case 'SIZE':
      case 'size':
        for (int i = bbCodeTag.size!; i < bbcode.length; i++) {
          if (bbcode.isNotEmpty && bbcode[i] is BBCodeText) {
            bbcode[i].size = int.parse(ctx.attr!.text!);
          }
        }
        break;
      case 'COLOR':
      case 'color':
        for (int i = bbCodeTag.color!; i < bbcode.length; i++) {
          if (bbcode.isNotEmpty && bbcode[i] is BBCodeText) {
            bbcode[i].color = ctx.attr?.text;
          }
        }
        break;
      default:
        KazumiLogger()
            .e('BBCode: unrecognized Tag: ${ctx.text}, please submit an issue with logs, bangumi, and episode information');
        break;
    }
  }

  @override
  void enterDocument(DocumentContext ctx) {}

  @override
  void exitDocument(DocumentContext ctx) {}

  @override
  void enterElement(ElementContext ctx) {}

  @override
  void exitElement(ElementContext ctx) {}

  @override
  void enterTag(TagContext ctx) {
    _enterTag(ctx);
  }

  @override
  void exitTag(TagContext ctx) {
    _exitTag(ctx);
  }

  @override
  void enterPlain(PlainContext ctx) {
    bbcode.add(BBCodeText(text: ctx.text));
  }

  @override
  void exitPlain(PlainContext ctx) {}

  @override
  void enterBgm(BgmContext ctx) {
    /// 处理 (bgm35) 类型的表情
    bbcode.add(BBCodeBgm(id: int.tryParse(ctx.id!.text!) ?? 0));
  }

  @override
  void exitBgm(BgmContext ctx) {}

  @override
  void enterSticker(StickerContext ctx) {
    /// 处理 (=A=) 类型的表情
    /// ctx.start!.type 为 BBCode.tokens 内的 token 值
    bbcode.add(BBCodeSticker(id: ctx.start!.type - 11));
  }

  @override
  void exitSticker(StickerContext ctx) {}

  @override
  void enterEveryRule(ParserRuleContext ctx) {}

  @override
  void exitEveryRule(ParserRuleContext ctx) {}

  @override
  void visitTerminal(TerminalNode node) {}

  @override
  void visitErrorNode(ErrorNode node) {}
}
