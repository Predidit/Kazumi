// Generated from ./assets/bbcode/BBCode.g4 by ANTLR 4.13.2
// ignore_for_file: unused_import, unused_local_variable, prefer_single_quotes
import 'package:antlr4/antlr4.dart';

import 'BBCodeListener.dart';
const int RULE_document = 0, RULE_element = 1, RULE_tag = 2, RULE_plain = 3, 
          RULE_bgm = 4, RULE_musume = 5, RULE_sticker = 6;
class BBCodeParser extends Parser {
  static final checkVersion = () => RuntimeMetaData.checkVersion('4.13.2', RuntimeMetaData.VERSION);
  static const int TOKEN_EOF = IntStream.EOF;

  static final List<DFA> _decisionToDFA = List.generate(
      _ATN.numberOfDecisions, (i) => DFA(_ATN.getDecisionState(i), i));
  static final PredictionContextCache _sharedContextCache = PredictionContextCache();
  static const int TOKEN_T__0 = 1, TOKEN_T__1 = 2, TOKEN_T__2 = 3, TOKEN_T__3 = 4, 
                   TOKEN_T__4 = 5, TOKEN_T__5 = 6, TOKEN_T__6 = 7, TOKEN_T__7 = 8, 
                   TOKEN_T__8 = 9, TOKEN_T__9 = 10, TOKEN_T__10 = 11, TOKEN_T__11 = 12, 
                   TOKEN_T__12 = 13, TOKEN_T__13 = 14, TOKEN_T__14 = 15, 
                   TOKEN_T__15 = 16, TOKEN_T__16 = 17, TOKEN_T__17 = 18, 
                   TOKEN_T__18 = 19, TOKEN_T__19 = 20, TOKEN_T__20 = 21, 
                   TOKEN_T__21 = 22, TOKEN_T__22 = 23, TOKEN_T__23 = 24, 
                   TOKEN_T__24 = 25, TOKEN_T__25 = 26, TOKEN_T__26 = 27, 
                   TOKEN_T__27 = 28, TOKEN_STRING = 29;

  @override
  final List<String> ruleNames = [
    'document', 'element', 'tag', 'plain', 'bgm', 'musume', 'sticker'
  ];

  static final List<String?> _LITERAL_NAMES = [
      null, "'['", "'='", "']'", "'[/'", "'/'", "'('", "')'", "'[\\u93C9\\u30E8\\u569CBangumi for android]'", 
      "'[\\u93C9\\u30E8\\u569CBangumi for iOS]'", "'(bgm'", "'(BGM'", "'(musume_'", 
      "'(=A=)'", "'(=w=)'", "'(-w=)'", "'(S_S)'", "'(=v=)'", "'(@_@)'", 
      "'(=W=)'", "'(TAT)'", "'(T_T)'", "'(='=)'", "'(=3=)'", "'(= =')'", 
      "'(=///=)'", "'(=.,=)'", "'(:P)'", "'(LOL)'"
  ];
  static final List<String?> _SYMBOLIC_NAMES = [
      null, null, null, null, null, null, null, null, null, null, null, 
      null, null, null, null, null, null, null, null, null, null, null, 
      null, null, null, null, null, null, null, "STRING"
  ];
  static final Vocabulary VOCABULARY = VocabularyImpl(_LITERAL_NAMES, _SYMBOLIC_NAMES);

  @override
  Vocabulary get vocabulary {
    return VOCABULARY;
  }

  @override
  String get grammarFileName => 'BBCode.g4';

  @override
  List<int> get serializedATN => _serializedATN;

  @override
  ATN getATN() {
   return _ATN;
  }

  BBCodeParser(TokenStream input) : super(input) {
    interpreter = ParserATNSimulator(this, _ATN, _decisionToDFA, _sharedContextCache);
  }

  DocumentContext document() {
    dynamic _localctx = DocumentContext(context, state);
    enterRule(_localctx, 0, RULE_document);
    int _la;
    try {
      enterOuterAlt(_localctx, 1);
      state = 17;
      errorHandler.sync(this);
      _la = tokenStream.LA(1)!;
      while ((((_la) & ~0x3f) == 0 && ((1 << _la) & 1073741806) != 0)) {
        state = 14;
        element();
        state = 19;
        errorHandler.sync(this);
        _la = tokenStream.LA(1)!;
      }
      state = 20;
      match(TOKEN_EOF);
    } on RecognitionException catch (re) {
      _localctx.exception = re;
      errorHandler.reportError(this, re);
      errorHandler.recover(this, re);
    } finally {
      exitRule();
    }
    return _localctx;
  }

  ElementContext element() {
    dynamic _localctx = ElementContext(context, state);
    enterRule(_localctx, 2, RULE_element);
    try {
      state = 27;
      errorHandler.sync(this);
      switch (interpreter!.adaptivePredict(tokenStream, 1, context)) {
      case 1:
        enterOuterAlt(_localctx, 1);
        state = 22;
        tag();
        break;
      case 2:
        enterOuterAlt(_localctx, 2);
        state = 23;
        plain();
        break;
      case 3:
        enterOuterAlt(_localctx, 3);
        state = 24;
        bgm();
        break;
      case 4:
        enterOuterAlt(_localctx, 4);
        state = 25;
        musume();
        break;
      case 5:
        enterOuterAlt(_localctx, 5);
        state = 26;
        sticker();
        break;
      }
    } on RecognitionException catch (re) {
      _localctx.exception = re;
      errorHandler.reportError(this, re);
      errorHandler.recover(this, re);
    } finally {
      exitRule();
    }
    return _localctx;
  }

  TagContext tag() {
    dynamic _localctx = TagContext(context, state);
    enterRule(_localctx, 4, RULE_tag);
    int _la;
    try {
      enterOuterAlt(_localctx, 1);
      state = 29;
      match(TOKEN_T__0);
      state = 30;
      _localctx.tagName = match(TOKEN_STRING);
      state = 33;
      errorHandler.sync(this);
      _la = tokenStream.LA(1)!;
      if (_la == TOKEN_T__1) {
        state = 31;
        match(TOKEN_T__1);
        state = 32;
        _localctx.attr = match(TOKEN_STRING);
      }

      state = 35;
      match(TOKEN_T__2);
      state = 39;
      errorHandler.sync(this);
      _la = tokenStream.LA(1)!;
      while ((((_la) & ~0x3f) == 0 && ((1 << _la) & 1073741806) != 0)) {
        state = 36;
        _localctx.content = element();
        state = 41;
        errorHandler.sync(this);
        _la = tokenStream.LA(1)!;
      }
      state = 42;
      match(TOKEN_T__3);
      state = 43;
      match(TOKEN_STRING);
      state = 44;
      match(TOKEN_T__2);
    } on RecognitionException catch (re) {
      _localctx.exception = re;
      errorHandler.reportError(this, re);
      errorHandler.recover(this, re);
    } finally {
      exitRule();
    }
    return _localctx;
  }

  PlainContext plain() {
    dynamic _localctx = PlainContext(context, state);
    enterRule(_localctx, 6, RULE_plain);
    int _la;
    try {
      int _alt;
      state = 53;
      errorHandler.sync(this);
      switch (tokenStream.LA(1)!) {
      case TOKEN_T__0:
      case TOKEN_T__1:
      case TOKEN_T__2:
      case TOKEN_T__4:
      case TOKEN_T__5:
      case TOKEN_T__6:
      case TOKEN_STRING:
        enterOuterAlt(_localctx, 1);
        state = 47; 
        errorHandler.sync(this);
        _alt = 1;
        do {
          switch (_alt) {
          case 1:
            state = 46;
            _la = tokenStream.LA(1)!;
            if (!((((_la) & ~0x3f) == 0 && ((1 << _la) & 536871150) != 0))) {
            errorHandler.recoverInline(this);
            } else {
              if ( tokenStream.LA(1)! == IntStream.EOF ) matchedEOF = true;
              errorHandler.reportMatch(this);
              consume();
            }
            break;
          default:
            throw NoViableAltException(this);
          }
          state = 49; 
          errorHandler.sync(this);
          _alt = interpreter!.adaptivePredict(tokenStream, 4, context);
        } while (_alt != 2 && _alt != ATN.INVALID_ALT_NUMBER);
        break;
      case TOKEN_T__7:
        enterOuterAlt(_localctx, 2);
        state = 51;
        match(TOKEN_T__7);
        break;
      case TOKEN_T__8:
        enterOuterAlt(_localctx, 3);
        state = 52;
        match(TOKEN_T__8);
        break;
      default:
        throw NoViableAltException(this);
      }
    } on RecognitionException catch (re) {
      _localctx.exception = re;
      errorHandler.reportError(this, re);
      errorHandler.recover(this, re);
    } finally {
      exitRule();
    }
    return _localctx;
  }

  BgmContext bgm() {
    dynamic _localctx = BgmContext(context, state);
    enterRule(_localctx, 8, RULE_bgm);
    int _la;
    try {
      enterOuterAlt(_localctx, 1);
      state = 55;
      _la = tokenStream.LA(1)!;
      if (!(_la == TOKEN_T__9 || _la == TOKEN_T__10)) {
      errorHandler.recoverInline(this);
      } else {
        if ( tokenStream.LA(1)! == IntStream.EOF ) matchedEOF = true;
        errorHandler.reportMatch(this);
        consume();
      }
      state = 56;
      _localctx.id = match(TOKEN_STRING);
      state = 57;
      match(TOKEN_T__6);
    } on RecognitionException catch (re) {
      _localctx.exception = re;
      errorHandler.reportError(this, re);
      errorHandler.recover(this, re);
    } finally {
      exitRule();
    }
    return _localctx;
  }

  MusumeContext musume() {
    dynamic _localctx = MusumeContext(context, state);
    enterRule(_localctx, 10, RULE_musume);
    try {
      enterOuterAlt(_localctx, 1);
      state = 59;
      match(TOKEN_T__11);
      state = 60;
      _localctx.id = match(TOKEN_STRING);
      state = 61;
      match(TOKEN_T__6);
    } on RecognitionException catch (re) {
      _localctx.exception = re;
      errorHandler.reportError(this, re);
      errorHandler.recover(this, re);
    } finally {
      exitRule();
    }
    return _localctx;
  }

  StickerContext sticker() {
    dynamic _localctx = StickerContext(context, state);
    enterRule(_localctx, 12, RULE_sticker);
    int _la;
    try {
      enterOuterAlt(_localctx, 1);
      state = 63;
      _la = tokenStream.LA(1)!;
      if (!((((_la) & ~0x3f) == 0 && ((1 << _la) & 536862720) != 0))) {
      errorHandler.recoverInline(this);
      } else {
        if ( tokenStream.LA(1)! == IntStream.EOF ) matchedEOF = true;
        errorHandler.reportMatch(this);
        consume();
      }
    } on RecognitionException catch (re) {
      _localctx.exception = re;
      errorHandler.reportError(this, re);
      errorHandler.recover(this, re);
    } finally {
      exitRule();
    }
    return _localctx;
  }

  static const List<int> _serializedATN = [
      4,1,29,66,2,0,7,0,2,1,7,1,2,2,7,2,2,3,7,3,2,4,7,4,2,5,7,5,2,6,7,6,
      1,0,5,0,16,8,0,10,0,12,0,19,9,0,1,0,1,0,1,1,1,1,1,1,1,1,1,1,3,1,28,
      8,1,1,2,1,2,1,2,1,2,3,2,34,8,2,1,2,1,2,5,2,38,8,2,10,2,12,2,41,9,2,
      1,2,1,2,1,2,1,2,1,3,4,3,48,8,3,11,3,12,3,49,1,3,1,3,3,3,54,8,3,1,4,
      1,4,1,4,1,4,1,5,1,5,1,5,1,5,1,6,1,6,1,6,0,0,7,0,2,4,6,8,10,12,0,3,
      3,0,1,3,5,7,29,29,1,0,10,11,1,0,13,28,68,0,17,1,0,0,0,2,27,1,0,0,0,
      4,29,1,0,0,0,6,53,1,0,0,0,8,55,1,0,0,0,10,59,1,0,0,0,12,63,1,0,0,0,
      14,16,3,2,1,0,15,14,1,0,0,0,16,19,1,0,0,0,17,15,1,0,0,0,17,18,1,0,
      0,0,18,20,1,0,0,0,19,17,1,0,0,0,20,21,5,0,0,1,21,1,1,0,0,0,22,28,3,
      4,2,0,23,28,3,6,3,0,24,28,3,8,4,0,25,28,3,10,5,0,26,28,3,12,6,0,27,
      22,1,0,0,0,27,23,1,0,0,0,27,24,1,0,0,0,27,25,1,0,0,0,27,26,1,0,0,0,
      28,3,1,0,0,0,29,30,5,1,0,0,30,33,5,29,0,0,31,32,5,2,0,0,32,34,5,29,
      0,0,33,31,1,0,0,0,33,34,1,0,0,0,34,35,1,0,0,0,35,39,5,3,0,0,36,38,
      3,2,1,0,37,36,1,0,0,0,38,41,1,0,0,0,39,37,1,0,0,0,39,40,1,0,0,0,40,
      42,1,0,0,0,41,39,1,0,0,0,42,43,5,4,0,0,43,44,5,29,0,0,44,45,5,3,0,
      0,45,5,1,0,0,0,46,48,7,0,0,0,47,46,1,0,0,0,48,49,1,0,0,0,49,47,1,0,
      0,0,49,50,1,0,0,0,50,54,1,0,0,0,51,54,5,8,0,0,52,54,5,9,0,0,53,47,
      1,0,0,0,53,51,1,0,0,0,53,52,1,0,0,0,54,7,1,0,0,0,55,56,7,1,0,0,56,
      57,5,29,0,0,57,58,5,7,0,0,58,9,1,0,0,0,59,60,5,12,0,0,60,61,5,29,0,
      0,61,62,5,7,0,0,62,11,1,0,0,0,63,64,7,2,0,0,64,13,1,0,0,0,6,17,27,
      33,39,49,53
  ];

  static final ATN _ATN =
      ATNDeserializer().deserialize(_serializedATN);
}
class DocumentContext extends ParserRuleContext {
  TerminalNode? EOF() => getToken(BBCodeParser.TOKEN_EOF, 0);
  List<ElementContext> elements() => getRuleContexts<ElementContext>();
  ElementContext? element(int i) => getRuleContext<ElementContext>(i);
  DocumentContext([ParserRuleContext? parent, int? invokingState]) : super(parent, invokingState);
  @override
  int get ruleIndex => RULE_document;
  @override
  void enterRule(ParseTreeListener listener) {
    if (listener is BBCodeListener) listener.enterDocument(this);
  }
  @override
  void exitRule(ParseTreeListener listener) {
    if (listener is BBCodeListener) listener.exitDocument(this);
  }
}

class ElementContext extends ParserRuleContext {
  TagContext? tag() => getRuleContext<TagContext>(0);
  PlainContext? plain() => getRuleContext<PlainContext>(0);
  BgmContext? bgm() => getRuleContext<BgmContext>(0);
  MusumeContext? musume() => getRuleContext<MusumeContext>(0);
  StickerContext? sticker() => getRuleContext<StickerContext>(0);
  ElementContext([ParserRuleContext? parent, int? invokingState]) : super(parent, invokingState);
  @override
  int get ruleIndex => RULE_element;
  @override
  void enterRule(ParseTreeListener listener) {
    if (listener is BBCodeListener) listener.enterElement(this);
  }
  @override
  void exitRule(ParseTreeListener listener) {
    if (listener is BBCodeListener) listener.exitElement(this);
  }
}

class TagContext extends ParserRuleContext {
  Token? tagName;
  Token? attr;
  ElementContext? content;
  List<TerminalNode> STRINGs() => getTokens(BBCodeParser.TOKEN_STRING);
  TerminalNode? STRING(int i) => getToken(BBCodeParser.TOKEN_STRING, i);
  List<ElementContext> elements() => getRuleContexts<ElementContext>();
  ElementContext? element(int i) => getRuleContext<ElementContext>(i);
  TagContext([ParserRuleContext? parent, int? invokingState]) : super(parent, invokingState);
  @override
  int get ruleIndex => RULE_tag;
  @override
  void enterRule(ParseTreeListener listener) {
    if (listener is BBCodeListener) listener.enterTag(this);
  }
  @override
  void exitRule(ParseTreeListener listener) {
    if (listener is BBCodeListener) listener.exitTag(this);
  }
}

class PlainContext extends ParserRuleContext {
  List<TerminalNode> STRINGs() => getTokens(BBCodeParser.TOKEN_STRING);
  TerminalNode? STRING(int i) => getToken(BBCodeParser.TOKEN_STRING, i);
  PlainContext([ParserRuleContext? parent, int? invokingState]) : super(parent, invokingState);
  @override
  int get ruleIndex => RULE_plain;
  @override
  void enterRule(ParseTreeListener listener) {
    if (listener is BBCodeListener) listener.enterPlain(this);
  }
  @override
  void exitRule(ParseTreeListener listener) {
    if (listener is BBCodeListener) listener.exitPlain(this);
  }
}

class BgmContext extends ParserRuleContext {
  Token? id;
  TerminalNode? STRING() => getToken(BBCodeParser.TOKEN_STRING, 0);
  BgmContext([ParserRuleContext? parent, int? invokingState]) : super(parent, invokingState);
  @override
  int get ruleIndex => RULE_bgm;
  @override
  void enterRule(ParseTreeListener listener) {
    if (listener is BBCodeListener) listener.enterBgm(this);
  }
  @override
  void exitRule(ParseTreeListener listener) {
    if (listener is BBCodeListener) listener.exitBgm(this);
  }
}

class MusumeContext extends ParserRuleContext {
  Token? id;
  TerminalNode? STRING() => getToken(BBCodeParser.TOKEN_STRING, 0);
  MusumeContext([ParserRuleContext? parent, int? invokingState]) : super(parent, invokingState);
  @override
  int get ruleIndex => RULE_musume;
  @override
  void enterRule(ParseTreeListener listener) {
    if (listener is BBCodeListener) listener.enterMusume(this);
  }
  @override
  void exitRule(ParseTreeListener listener) {
    if (listener is BBCodeListener) listener.exitMusume(this);
  }
}

class StickerContext extends ParserRuleContext {
  StickerContext([ParserRuleContext? parent, int? invokingState]) : super(parent, invokingState);
  @override
  int get ruleIndex => RULE_sticker;
  @override
  void enterRule(ParseTreeListener listener) {
    if (listener is BBCodeListener) listener.enterSticker(this);
  }
  @override
  void exitRule(ParseTreeListener listener) {
    if (listener is BBCodeListener) listener.exitSticker(this);
  }
}

