import 'package:antlr4/antlr4.dart';

import 'BBCodeParser.dart';
import 'BBCodeListener.dart';


/// This class provides an empty implementation of [BBCodeListener],
/// which can be extended to create a listener which only needs to handle
/// a subset of the available methods.
class BBCodeBaseListener implements BBCodeListener {
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
  void enterTag(TagContext ctx) {}

  /// The default implementation does nothing.
  @override
  void exitTag(TagContext ctx) {}

  /// The default implementation does nothing.
  @override
  void enterPlain(PlainContext ctx) {}

  /// The default implementation does nothing.
  @override
  void exitPlain(PlainContext ctx) {}

  /// The default implementation does nothing.
  @override
  void enterBgm(BgmContext ctx) {}

  /// The default implementation does nothing.
  @override
  void exitBgm(BgmContext ctx) {}

  /// The default implementation does nothing.
  @override
  void enterSticker(StickerContext ctx) {}

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
