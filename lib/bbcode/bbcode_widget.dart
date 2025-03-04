import 'dart:ui' as ui;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:antlr4/antlr4.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';

import 'bbcode_base_listener.dart';
import 'bbcode_elements.dart';
import 'generated/BBCodeParser.dart';
import 'generated/BBCodeLexer.dart';

class BBCodeWidget extends StatefulWidget {
  const BBCodeWidget({super.key, required this.bbcode});

  final String bbcode;

  @override
  State<StatefulWidget> createState() => _BBCodeWidgetState();
}

class _BBCodeWidgetState extends State<BBCodeWidget> {
  bool _isVisible = false;

  /// color 可以为三种表现形式
  ///
  /// `ARGB: #FFFFFFFF`
  ///
  /// `RGB: #FFFFFF`
  ///
  /// `NAME: red`
  ///
  /// 若全部解析失败则返回 null 使用默认颜色
  Color? _parseColor(String hex) {
    if (hex.startsWith('#')) {
      hex = hex.replaceFirst('#', '');
      if (hex.length == 6) {
        hex = "FF$hex";
      }
      if (hex.length == 8) {
        return Color(int.parse(hex, radix: 16));
      }
    }
    switch (hex) {
      case 'red':
        return Colors.red;
      case 'blue':
        return Colors.blue;
      case 'orange':
        return Colors.orange;
      case 'green':
        return Colors.green;
      case 'grey':
        return Colors.grey;
      default:
        return null;
    }
  }

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
                Color? textColor = (!_isVisible && e.masked)
                    ? Colors.transparent
                    : (e.link != null)
                        ? Colors.blue
                        : (e.quoted)
                            ? Theme.of(context).colorScheme.outline
                            : (e.color != null)
                                ? _parseColor(e.color!)
                                : null;
                return TextSpan(
                  text: e.text,
                  mouseCursor: (e.link != null || e.masked)
                      ? SystemMouseCursors.click
                      : SystemMouseCursors.text,
                  recognizer: TapGestureRecognizer()
                    ..onTap = (e.link != null || e.masked)
                        ? () {
                            if ((!e.masked || _isVisible) && e.link != null) {
                              launchUrl(Uri.parse(e.link!));
                            } else if (e.masked) {
                              setState(() {
                                _isVisible = !_isVisible;
                              });
                            }
                          }
                        : null,
                  style: TextStyle(
                    fontWeight: (e.bold) ? FontWeight.bold : null,
                    fontStyle: (e.italic) ? FontStyle.italic : null,
                    decoration: TextDecoration.combine([
                      if (e.underline || e.link != null)
                        TextDecoration.underline,
                      if (e.strikeThrough) TextDecoration.lineThrough,
                    ]),
                    decorationColor: textColor,
                    fontSize: e.size.toDouble(),
                    color: textColor,
                    backgroundColor:
                        (!_isVisible && e.masked) ? Color(0xFF555555) : null,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                );
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
              } else if (e is BBCodeSticker) {
                return WidgetSpan(
                  child: CachedNetworkImage(
                    imageUrl: 'https://bangumi.tv/img/smiles/${e.id}.gif',
                    placeholder: (context, url) =>
                        const SizedBox(width: 1, height: 1),
                    errorWidget: (context, error, stackTrace) {
                      return const Text('.');
                    },
                  ),
                );
              } else {
                // e is Icon
                return WidgetSpan(
                  child: Icon(
                    (e as Icon).icon,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                  alignment: PlaceholderAlignment.top,
                );
              }
            }).toList(),
          ),
          selectionHeightStyle: ui.BoxHeightStyle.max,
        ),
      ],
    );
  }
}
