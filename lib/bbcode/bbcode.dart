import 'package:antlr4/antlr4.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/material.dart';
import 'package:kazumi/bbcode/bbcode_elements.dart';

import 'generated/BBCodeListener.dart';
import 'generated/BBCodeParser.dart';
import 'generated/BBCodeLexer.dart';

/// This class provides an empty implementation of [BBCodeListener],
/// which can be extended to create a listener which only needs to handle
/// a subset of the available methods.
class BBCodeBaseListener implements BBCodeListener {
  final List<dynamic> bbcode = [];
  final List<Widget> widgets = [];
  final Set<PlainContext> _handledPlains = {};

  // 处理嵌套标签
  List<Widget> _parseElements(List<ElementContext> elements) {
    final List<Widget> result = [];
    for (final element in elements) {
      if (element.tag() != null) {
        result.add(_parseTag(element.tag()!));
      } else if (element.plain() != null) {
        result.add(_parsePlain(element.plain()!));
      } else if (element.bgm() != null) {
        result.add(_parseBgm(element.bgm()!));
      } else if (element.sticker() != null) {
        result.add(_parseSticker(element.sticker()!));
      }
    }
    return result;
  }

  // 处理标签
  Widget _parseTag(TagContext ctx) {
    final tagName = ctx.tagName?.text;
    final content = ctx.content != null ? _parseElements(ctx.elements()) : [];
    final attr = ctx.attr?.text;

    switch (tagName) {
      case 'URL':
      case 'url':
        return InkWell(
          onTap: () {
            if (attr != null) {
              launchUrl(Uri.parse(attr));
            } else {
              launchUrl(Uri.parse(ctx.content!.text));
            }
          },
          child: Text.rich(
            TextSpan(
              style: const TextStyle(color: Colors.blue),
              children: content.map((widget) {
                if (widget is Text) {
                  return TextSpan(text: widget.data);
                }
                return WidgetSpan(child: widget);
              }).toList(),
            ),
          ),
        );
      case 'USER':
      case 'user':
        return InkWell(
          onTap: () {
            launchUrl(Uri.parse('https://bangumi.tv/user/$attr'));
          },
          child: Text.rich(
            TextSpan(
              text: '@${ctx.content?.text} ',
              style: const TextStyle(color: Colors.blue),
            ),
          ),
        );
      case 'QUOTE':
      case 'quote':
        return Wrap(
          children: [
            Text.rich(
              TextSpan(
                children: content.map((widget) {
                  if (widget is Text) {
                    return TextSpan(text: widget.data);
                  }
                  return WidgetSpan(child: widget);
                }).toList(),
              ),
              style: const TextStyle(color: Colors.white70),
            ),
            const Icon(Icons.format_quote, color: Colors.white70),
          ],
        );
      case 'B':
      case 'b':
        return Text.rich(
          TextSpan(
            children: content.map((widget) {
              if (widget is Text) {
                return TextSpan(text: widget.data);
              }
              return WidgetSpan(child: widget);
            }).toList(),
          ),
          style: const TextStyle(fontWeight: FontWeight.bold),
        );
      case 'I':
      case 'i':
        return Text.rich(
          TextSpan(
            children: content.map((widget) {
              if (widget is Text) {
                return TextSpan(text: widget.data);
              }
              return WidgetSpan(child: widget);
            }).toList(),
          ),
          style: const TextStyle(fontStyle: FontStyle.italic),
        );
      case 'S':
      case 's':
        return Text.rich(
          TextSpan(
            children: content.map((widget) {
              if (widget is Text) {
                return TextSpan(text: widget.data);
              }
              return WidgetSpan(child: widget);
            }).toList(),
          ),
          style: const TextStyle(decoration: TextDecoration.lineThrough),
        );
      case 'U':
      case 'u':
        return Text.rich(
          TextSpan(
            children: content.map((widget) {
              if (widget is Text) {
                return TextSpan(text: widget.data);
              }
              return WidgetSpan(child: widget);
            }).toList(),
          ),
          style: const TextStyle(decoration: TextDecoration.underline),
        );
      case 'PHOTO':
      case 'photo':
      case 'IMG':
      case 'img':
        return CachedNetworkImage(
          imageUrl: ctx.content!.text,
          placeholder: (context, url) => const SizedBox(width: 1, height: 1),
          errorWidget: (context, error, stackTrace) {
            return const Text('.');
          },
        );
      case 'MASK':
      case 'mask':
        return Text.rich(
                TextSpan(
                  children: content.map((widget) {
                    if (widget is Text) {
                      return TextSpan(text: widget.data);
                    }
                    return WidgetSpan(child: widget);
                  }).toList(),
                ),
              );
      default:
        return Text(ctx.text);
    }
  }

  // 处理普通文字
  Widget _parsePlain(PlainContext ctx) {
    _handledPlains.add(ctx);
    return Text(ctx.text);
  }

  // 处理 (bgm12) 类型的表情
  Widget _parseBgm(BgmContext ctx) {
    final id = ctx.id?.text;
    if (id == '11' || id == '23') {
      return CachedNetworkImage(
        imageUrl: 'https://bangumi.tv/img/smiles/bgm/$id.gif',
        placeholder: (context, url) => const SizedBox(width: 1, height: 1),
        errorWidget: (context, error, stackTrace) {
          return const Text('.');
        },
      );
    }
    int num = int.tryParse(id!) ?? 0;
    if (num < 24) {
      return CachedNetworkImage(
        imageUrl: 'https://bangumi.tv/img/smiles/bgm/$id.png',
        placeholder: (context, url) => const SizedBox(width: 1, height: 1),
        errorWidget: (context, error, stackTrace) {
          return const Text('.');
        },
      );
    }
    if (num < 33) {
      return CachedNetworkImage(
        imageUrl: 'https://bangumi.tv/img/smiles/tv/0${num - 23}.gif',
        placeholder: (context, url) => const SizedBox(width: 1, height: 1),
        errorWidget: (context, error, stackTrace) {
          return const Text('.');
        },
      );
    }
    return CachedNetworkImage(
      imageUrl: 'https://bangumi.tv/img/smiles/tv/${num - 23}.gif',
      placeholder: (context, url) => const SizedBox(width: 1, height: 1),
      errorWidget: (context, error, stackTrace) {
        return const Text('.');
      },
    );
  }

  // 处理 (=A=) 类型的表情
  Widget _parseSticker(StickerContext ctx) {
    // 参考 BBCode.tokens 内的 token 值
    final sticker = ctx.start?.type;
    return CachedNetworkImage(
      imageUrl: 'https://bangumi.tv/img/smiles/${sticker! - 9}.gif',
      placeholder: (context, url) => const SizedBox(width: 1, height: 1),
      errorWidget: (context, error, stackTrace) {
        return const Text('.');
      },
    );
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
    widgets.add(_parseTag(ctx));
    debugPrint(ctx.tagName?.text);
  }

  /// The default implementation does nothing.
  @override
  void exitTag(TagContext ctx) {}

  /// The default implementation does nothing.
  @override
  void enterPlain(PlainContext ctx) {
    debugPrint(ctx.text);
    if (!_handledPlains.contains(ctx)) {
      widgets.add(_parsePlain(ctx));
    }
  }

  /// The default implementation does nothing.
  @override
  void exitPlain(PlainContext ctx) {}

  /// The default implementation does nothing.
  @override
  void enterBgm(BgmContext ctx) {
    debugPrint(ctx.id?.text);
    widgets.add(_parseBgm(ctx));
  }

  /// The default implementation does nothing.
  @override
  void exitBgm(BgmContext ctx) {}

  /// The default implementation does nothing.
  @override
  void enterSticker(StickerContext ctx) {
    debugPrint(ctx.text);
    widgets.add(_parseSticker(ctx));
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

    return Wrap(
      children: bbcodeBaseListener.widgets,
    );
  }
}

void bbcodeParse(String args) async {
  BBCodeParser.checkVersion();
  BBCodeParser.checkVersion();
  final input = InputStream.fromString(args);
  final lexer = BBCodeLexer(input);
  final tokens = CommonTokenStream(lexer);
  final parser = BBCodeParser(tokens);
  final tree = parser.document();
  ParseTreeWalker.DEFAULT.walk(BBCodeBaseListener(), tree);
}
