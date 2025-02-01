import 'package:antlr4/antlr4.dart';

import 'BBCodeParser.dart';

/// This abstract class defines a complete generic visitor for a parse tree
/// produced by [BBCodeParser].
///
/// [T] is the eturn type of the visit operation. Use `void` for
/// operations with no return type.
abstract class BBCodeVisitor<T> extends ParseTreeVisitor<T> {
  /// Visit a parse tree produced by [BBCodeParser.document].
  /// [ctx] the parse tree.
  /// Return the visitor result.
  T? visitDocument(DocumentContext ctx);

  /// Visit a parse tree produced by [BBCodeParser.element].
  /// [ctx] the parse tree.
  /// Return the visitor result.
  T? visitElement(ElementContext ctx);

  /// Visit a parse tree produced by [BBCodeParser.tag].
  /// [ctx] the parse tree.
  /// Return the visitor result.
  T? visitTag(TagContext ctx);

  /// Visit a parse tree produced by [BBCodeParser.plain].
  /// [ctx] the parse tree.
  /// Return the visitor result.
  T? visitPlain(PlainContext ctx);

  /// Visit a parse tree produced by [BBCodeParser.bgm].
  /// [ctx] the parse tree.
  /// Return the visitor result.
  T? visitBgm(BgmContext ctx);

  /// Visit a parse tree produced by [BBCodeParser.sticker].
  /// [ctx] the parse tree.
  /// Return the visitor result.
  T? visitSticker(StickerContext ctx);
}