import 'package:antlr4/antlr4.dart';

import 'BBCodeParser.dart';

/// This abstract class defines a complete listener for a parse tree produced by
/// [BBCodeParser].
abstract class BBCodeListener extends ParseTreeListener {
  /// Enter a parse tree produced by [BBCodeParser.document].
  /// [ctx] the parse tree
  void enterDocument(DocumentContext ctx);
  /// Exit a parse tree produced by [BBCodeParser.document].
  /// [ctx] the parse tree
  void exitDocument(DocumentContext ctx);

  /// Enter a parse tree produced by [BBCodeParser.element].
  /// [ctx] the parse tree
  void enterElement(ElementContext ctx);
  /// Exit a parse tree produced by [BBCodeParser.element].
  /// [ctx] the parse tree
  void exitElement(ElementContext ctx);

  /// Enter a parse tree produced by [BBCodeParser.tag].
  /// [ctx] the parse tree
  void enterTag(TagContext ctx);
  /// Exit a parse tree produced by [BBCodeParser.tag].
  /// [ctx] the parse tree
  void exitTag(TagContext ctx);

  /// Enter a parse tree produced by [BBCodeParser.plain].
  /// [ctx] the parse tree
  void enterPlain(PlainContext ctx);
  /// Exit a parse tree produced by [BBCodeParser.plain].
  /// [ctx] the parse tree
  void exitPlain(PlainContext ctx);

  /// Enter a parse tree produced by [BBCodeParser.bgm].
  /// [ctx] the parse tree
  void enterBgm(BgmContext ctx);
  /// Exit a parse tree produced by [BBCodeParser.bgm].
  /// [ctx] the parse tree
  void exitBgm(BgmContext ctx);

  /// Enter a parse tree produced by [BBCodeParser.sticker].
  /// [ctx] the parse tree
  void enterSticker(StickerContext ctx);
  /// Exit a parse tree produced by [BBCodeParser.sticker].
  /// [ctx] the parse tree
  void exitSticker(StickerContext ctx);
}