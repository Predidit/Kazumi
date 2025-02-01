import 'package:antlr4/antlr4.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:logger/logger.dart';
import 'package:flutter/material.dart';
import 'package:kazumi/utils/logger.dart';
import 'package:kazumi/bbcode/bbcode_elements.dart';

import 'generated/BBCodeListener.dart';
import 'generated/BBCodeParser.dart';
import 'generated/BBCodeLexer.dart';

/// This class provides an empty implementation of [BBCodeListener],
/// which can be extended to create a listener which only needs to handle
/// a subset of the available methods.
class BBCodeBaseListener implements BBCodeListener {
  final List<dynamic> bbcode = [];

  // 处理标签
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
            .log(Level.error, '未识别 Tag: ${ctx.text}, 请提交 issue 包含 log, 番剧及集数');
        break;
    }
  }

  void _exitTag(TagContext ctx) {
    final tagName = ctx.tagName?.text;

    switch (tagName) {
      case 'URL':
      case 'url':
        if (ctx.attr != null) {
          (bbcode[bbCodeTag.link!] as BBCodeText).link = ctx.attr!.text;
        } else {
          (bbcode[bbCodeTag.link!] as BBCodeText).link =
              (bbcode[bbCodeTag.link!] as BBCodeText).text;
        }
        break;
      case 'USER':
      case 'user':
        if (ctx.attr != null) {
          (bbcode[bbCodeTag.link!] as BBCodeText).link = ctx.attr!.text;
        }
        break;
      case 'QUOTE':
      case 'quote':
        for (int i = bbCodeTag.quoted!; i < bbcode.length; i++) {
          if (bbcode[i] == BBCodeText) {
            (bbcode[i] as BBCodeText).quoted = true;
          }
        }
        break;
      case 'B':
      case 'b':
        for (int i = bbCodeTag.bold!; i < bbcode.length; i++) {
          if (bbcode[i] == BBCodeText) {
            (bbcode[i] as BBCodeText).bold = true;
          }
        }
        break;
      case 'I':
      case 'i':
        for (int i = bbCodeTag.italic!; i < bbcode.length; i++) {
          if (bbcode[i] == BBCodeText) {
            (bbcode[i] as BBCodeText).italic = true;
          }
        }
        break;
      case 'S':
      case 's':
        for (int i = bbCodeTag.strikeThrough!; i < bbcode.length; i++) {
          if (bbcode[i] == BBCodeText) {
            (bbcode[i] as BBCodeText).strikeThrough = true;
          }
        }
        break;
      case 'U':
      case 'u':
        for (int i = bbCodeTag.underline!; i < bbcode.length; i++) {
          if (bbcode[i] == BBCodeText) {
            (bbcode[i] as BBCodeText).underline = true;
          }
        }
        break;
      case 'PHOTO':
      case 'photo':
      case 'IMG':
      case 'img':
        bbcode[bbCodeTag.img!] =
            BBCodeImg(imageUrl: (bbcode[bbCodeTag.img!] as BBCodeText).text);
        break;
      case 'MASK':
      case 'mask':
        for (int i = bbCodeTag.masked!; i < bbcode.length; i++) {
          if (bbcode[i] == BBCodeText) {
            (bbcode[i] as BBCodeText).masked = true;
          }
        }
        break;
      case 'SIZE':
      case 'size':
        for (int i = bbCodeTag.size!; i < bbcode.length; i++) {
          if (bbcode[i] == BBCodeText) {
            (bbcode[i] as BBCodeText).size = int.parse(ctx.attr!.text!);
          }
        }
        break;
      case 'COLOR':
      case 'color':
        for (int i = bbCodeTag.color!; i < bbcode.length; i++) {
          if (bbcode[i] == BBCodeText) {
            (bbcode[i] as BBCodeText).color = ctx.attr?.text;
          }
        }
        break;
      default:
        KazumiLogger()
            .log(Level.error, '未识别 Tag: ${ctx.text}, 请提交 issue 包含 log, 番剧及集数');
        break;
    }
  }

  /// The default implementation does nothing.
  @override
  void enterDocument(DocumentContext ctx) {}

  /// The default implementation does nothing.
  @override
  void exitDocument(DocumentContext ctx) {}

  /// The default implementation does nothing.
  @override
  void enterElement(ElementContext ctx) {}

  /// The default implementation does nothing.
  @override
  void exitElement(ElementContext ctx) {}

  /// The default implementation does nothing.
  @override
  void enterTag(TagContext ctx) {
    _enterTag(ctx);
    debugPrint(ctx.tagName?.text);
  }

  /// The default implementation does nothing.
  @override
  void exitTag(TagContext ctx) {
    _exitTag(ctx);
    debugPrint(ctx.tagName?.text);
  }

  /// The default implementation does nothing.
  @override
  void enterPlain(PlainContext ctx) {
    bbcode.add(BBCodeText(text: ctx.text));
    debugPrint(ctx.text);
  }

  /// The default implementation does nothing.
  @override
  void exitPlain(PlainContext ctx) {}

  /// The default implementation does nothing.
  @override
  void enterBgm(BgmContext ctx) {
    // 处理 (bgm35) 类型的表情
    bbcode.add(BBCodeBgm(id: int.tryParse(ctx.id!.text!) ?? 0));
    debugPrint(ctx.id?.text);
  }

  /// The default implementation does nothing.
  @override
  void exitBgm(BgmContext ctx) {}

  /// The default implementation does nothing.
  @override
  void enterSticker(StickerContext ctx) {
    // 处理 (=A=) 类型的表情
    // ctx.start!.type 为 BBCode.tokens 内的 token 值
    bbcode.add(BBCodeSticker(id: ctx.start!.type - 9));
    debugPrint(ctx.text);
  }

  /// The default implementation does nothing.
  @override
  void exitSticker(StickerContext ctx) {}

  /// The default implementation does nothing.
  @override
  void enterEveryRule(ParserRuleContext ctx) {}

  /// The default implementation does nothing.
  @override
  void exitEveryRule(ParserRuleContext ctx) {}

  /// The default implementation does nothing.
  @override
  void visitTerminal(TerminalNode node) {}

  /// The default implementation does nothing.
  @override
  void visitErrorNode(ErrorNode node) {}
}

class BBCodeWidget extends StatefulWidget {
  const BBCodeWidget({super.key, required this.bbcode});

  final String bbcode;

  @override
  State<StatefulWidget> createState() => _BBCodeWidgetState();
}

class _BBCodeWidgetState extends State<BBCodeWidget> {
  @override
  Widget build(BuildContext context) {
    BBCodeParser.checkVersion();
    BBCodeParser.checkVersion();
    final input = InputStream.fromString(widget.bbcode);
    final lexer = BBCodeLexer(input);
    final tokens = CommonTokenStream(lexer);
    final parser = BBCodeParser(tokens);
    final tree = parser.document();
    final bbcodeBaseListener = BBCodeBaseListener();
    ParseTreeWalker.DEFAULT.walk(bbcodeBaseListener, tree);
    bbCodeTag.clear();

    return Wrap(
      children: [
        RichText(
          text: TextSpan(
            children: bbcodeBaseListener.bbcode.map((e) {
              if (e is BBCodeText) {
                if (e.link != null) {
                  return WidgetSpan(
                    child: InkWell(
                      onTap: () {
                        launchUrl(Uri.parse(e.link!));
                      },
                      child: Text(
                        e.text,
                        style: TextStyle(
                          fontWeight: (e.bold) ? FontWeight.bold : null,
                          fontStyle: (e.italic) ? FontStyle.italic : null,
                          decoration: (e.underline)
                              ? TextDecoration.underline
                              : (e.strikeThrough)
                                  ? TextDecoration.lineThrough
                                  : null,
                          fontSize: e.size.toDouble(),
                          color: Colors.blue,
                        ),
                      ),
                    ),
                  );
                } else {
                  return TextSpan(
                    text: e.text,
                    style: TextStyle(
                      fontWeight: (e.bold) ? FontWeight.bold : null,
                      fontStyle: (e.italic) ? FontStyle.italic : null,
                      decoration: (e.underline)
                          ? TextDecoration.underline
                          : (e.strikeThrough)
                          ? TextDecoration.lineThrough
                          : null,
                      fontSize: e.size.toDouble(),
                    ),
                  );
                }
              } else if (e is BBCodeImg) {
                return WidgetSpan(
                  child: CachedNetworkImage(
                    imageUrl: e.imageUrl,
                    placeholder: (context, url) =>
                        const SizedBox(width: 1, height: 1),
                    errorWidget: (context, error, stackTrace) {
                      return const Text('.');
                    },
                  ),
                );
              } else if (e is BBCodeBgm) {
                String url;
                if (e.id == 11 || e.id == 23) {
                  url = 'https://bangumi.tv/img/smiles/bgm/${e.id}.gif';
                }
                if (e.id < 24) {
                  url = 'https://bangumi.tv/img/smiles/bgm/${e.id}.png';
                }
                if (e.id < 33) {
                  url = 'https://bangumi.tv/img/smiles/tv/0${e.id - 23}.gif';
                }
                url = 'https://bangumi.tv/img/smiles/tv/${e.id - 23}.gif';
                return WidgetSpan(
                  child: CachedNetworkImage(
                    imageUrl: url,
                    placeholder: (context, url) =>
                        const SizedBox(width: 1, height: 1),
                    errorWidget: (context, error, stackTrace) {
                      return const Text('.');
                    },
                  ),
                );
              } else {
                // return WidgetSpan(child: Container());
                return WidgetSpan(
                  child: CachedNetworkImage(
                    imageUrl:
                        'https://bangumi.tv/img/smiles/${(e as BBCodeSticker).id}.gif',
                    placeholder: (context, url) =>
                        const SizedBox(width: 1, height: 1),
                    errorWidget: (context, error, stackTrace) {
                      return const Text('.');
                    },
                  ),
                );
              }
            }).toList(),
          ),
        ),
      ],
    );
  }
}
