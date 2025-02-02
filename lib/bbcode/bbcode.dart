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
        if (bbcode[bbCodeTag.link!] is BBCodeText) {
          if (ctx.attr != null) {
            bbcode[bbCodeTag.link!].link = ctx.attr!.text;
          } else {
            bbcode[bbCodeTag.link!].link = bbcode[bbCodeTag.link!].text;
          }
        }
        break;
      case 'USER':
      case 'user':
        if (ctx.attr != null && bbcode[bbCodeTag.link!] is BBCodeText) {
          bbcode[bbCodeTag.link!].link = ctx.attr!.text;
        }
        break;
      case 'QUOTE':
      case 'quote':
        for (int i = bbCodeTag.quoted!; i < bbcode.length; i++) {
          if (bbcode[i] is BBCodeText) {
            bbcode[i].quoted = true;
          }
        }
        break;
      case 'B':
      case 'b':
        for (int i = bbCodeTag.bold!; i < bbcode.length; i++) {
          if (bbcode[i] is BBCodeText) {
            bbcode[i].bold = true;
          }
        }
        break;
      case 'I':
      case 'i':
        for (int i = bbCodeTag.italic!; i < bbcode.length; i++) {
          if (bbcode[i] is BBCodeText) {
            bbcode[i].italic = true;
          }
        }
        break;
      case 'S':
      case 's':
        for (int i = bbCodeTag.strikeThrough!; i < bbcode.length; i++) {
          if (bbcode[i] is BBCodeText) {
            bbcode[i].strikeThrough = true;
          }
        }
        break;
      case 'U':
      case 'u':
        for (int i = bbCodeTag.underline!; i < bbcode.length; i++) {
          if (bbcode[i] is BBCodeText) {
            bbcode[i].underline = true;
          }
        }
        break;
      case 'PHOTO':
      case 'photo':
      case 'IMG':
      case 'img':
        if (bbcode[bbCodeTag.img!] is BBCodeText) {
          bbcode[bbCodeTag.img!] =
              BBCodeImg(imageUrl: bbcode[bbCodeTag.img!].text);
        }
        break;
      case 'MASK':
      case 'mask':
        for (int i = bbCodeTag.masked!; i < bbcode.length; i++) {
          if (bbcode[i] is BBCodeText) {
            bbcode[i].masked = true;
          }
        }
        break;
      case 'SIZE':
      case 'size':
        for (int i = bbCodeTag.size!; i < bbcode.length; i++) {
          if (bbcode[i] is BBCodeText) {
            bbcode[i].size = int.parse(ctx.attr!.text!);
          }
        }
        break;
      case 'COLOR':
      case 'color':
        for (int i = bbCodeTag.color!; i < bbcode.length; i++) {
          if (bbcode[i] is BBCodeText) {
            bbcode[i].color = ctx.attr?.text;
          }
        }
        break;
      default:
        KazumiLogger()
            .log(Level.error, '未识别 Tag: ${ctx.text}, 请提交 issue 包含 log, 番剧及集数');
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
    // 处理 (bgm35) 类型的表情
    bbcode.add(BBCodeBgm(id: int.tryParse(ctx.id!.text!) ?? 0));
  }

  @override
  void exitBgm(BgmContext ctx) {}

  @override
  void enterSticker(StickerContext ctx) {
    // 处理 (=A=) 类型的表情
    // ctx.start!.type 为 BBCode.tokens 内的 token 值
    bbcode.add(BBCodeSticker(id: ctx.start!.type - 9));
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

class BBCodeWidget extends StatefulWidget {
  const BBCodeWidget({super.key, required this.bbcode});

  final String bbcode;

  @override
  State<StatefulWidget> createState() => _BBCodeWidgetState();
}

class _BBCodeWidgetState extends State<BBCodeWidget> {
  bool _isVisible = false;

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
        SelectableText.rich(
          TextSpan(
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
                          fontSize: e.size,
                          color: Colors.blue,
                        ),
                      ),
                    ),
                  );
                } else if (e.masked) {
                  return TextSpan(
                    text: e.text,
                    onEnter: (_) {
                      setState(() {
                        _isVisible = true;
                      });
                    },
                    onExit: (_) {
                      setState(() {
                        _isVisible = false;
                      });
                    },
                    style: TextStyle(
                      fontWeight: (e.bold) ? FontWeight.bold : null,
                      fontStyle: (e.italic) ? FontStyle.italic : null,
                      decoration: (e.underline)
                          ? TextDecoration.underline
                          : (e.strikeThrough)
                              ? TextDecoration.lineThrough
                              : null,
                      fontSize: e.size,
                      color: (!_isVisible) ? Colors.transparent : null,
                      backgroundColor: Colors.grey,
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
                      fontSize: e.size,
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
