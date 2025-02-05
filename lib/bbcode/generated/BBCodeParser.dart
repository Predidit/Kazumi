import 'package:antlr4/antlr4.dart';

import 'BBCodeListener.dart';
const int RULE_document = 0, RULE_element = 1, RULE_tag = 2, RULE_plain = 3, 
          RULE_bgm = 4, RULE_sticker = 5;
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
                   TOKEN_STRING = 28;

  @override
  final List<String> ruleNames = [
    'document', 'element', 'tag', 'plain', 'bgm', 'sticker'
  ];

  static final List<String?> _LITERAL_NAMES = [
      null, "'['", "'='", "']'", "'[/'", "'/'", "'('", "')'", "'[\\u6765\\u81EABangumi for android]'", 
      "'[\\u6765\\u81EABangumi for iOS]'", "'(bgm'", "'(BGM'", "'(=A=)'", 
      "'(=w=)'", "'(-w=)'", "'(S_S)'", "'(=v=)'", "'(@_@)'", "'(=W=)'", 
      "'(TAT)'", "'(T_T)'", "'(='=)'", "'(=3=)'", "'(= =')'", "'(=///=)'", 
      "'(=.,=)'", "'(:P)'", "'(LOL)'"
  ];
  static final List<String?> _SYMBOLIC_NAMES = [
      null, null, null, null, null, null, null, null, null, null, null, 
      null, null, null, null, null, null, null, null, null, null, null, 
      null, null, null, null, null, null, "STRING"
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
      state = 15;
      errorHandler.sync(this);
      _la = tokenStream.LA(1)!;
      while ((((_la) & ~0x3f) == 0 && ((1 << _la) & 536870894) != 0)) {
        state = 12;
        element();
        state = 17;
        errorHandler.sync(this);
        _la = tokenStream.LA(1)!;
      }
      state = 18;
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
      state = 24;
      errorHandler.sync(this);
      switch (interpreter!.adaptivePredict(tokenStream, 1, context)) {
      case 1:
        enterOuterAlt(_localctx, 1);
        state = 20;
        tag();
        break;
      case 2:
        enterOuterAlt(_localctx, 2);
        state = 21;
        plain();
        break;
      case 3:
        enterOuterAlt(_localctx, 3);
        state = 22;
        bgm();
        break;
      case 4:
        enterOuterAlt(_localctx, 4);
        state = 23;
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
      state = 26;
      match(TOKEN_T__0);
      state = 27;
      _localctx.tagName = match(TOKEN_STRING);
      state = 30;
      errorHandler.sync(this);
      _la = tokenStream.LA(1)!;
      if (_la == TOKEN_T__1) {
        state = 28;
        match(TOKEN_T__1);
        state = 29;
        _localctx.attr = match(TOKEN_STRING);
      }

      state = 32;
      match(TOKEN_T__2);
      state = 36;
      errorHandler.sync(this);
      _la = tokenStream.LA(1)!;
      while ((((_la) & ~0x3f) == 0 && ((1 << _la) & 536870894) != 0)) {
        state = 33;
        _localctx.content = element();
        state = 38;
        errorHandler.sync(this);
        _la = tokenStream.LA(1)!;
      }
      state = 39;
      match(TOKEN_T__3);
      state = 40;
      match(TOKEN_STRING);
      state = 41;
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
      state = 50;
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
        state = 44; 
        errorHandler.sync(this);
        _alt = 1;
        do {
          switch (_alt) {
          case 1:
            state = 43;
            _la = tokenStream.LA(1)!;
            if (!((((_la) & ~0x3f) == 0 && ((1 << _la) & 268435694) != 0))) {
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
          state = 46; 
          errorHandler.sync(this);
          _alt = interpreter!.adaptivePredict(tokenStream, 4, context);
        } while (_alt != 2 && _alt != ATN.INVALID_ALT_NUMBER);
        break;
      case TOKEN_T__7:
        enterOuterAlt(_localctx, 2);
        state = 48;
        match(TOKEN_T__7);
        break;
      case TOKEN_T__8:
        enterOuterAlt(_localctx, 3);
        state = 49;
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
      state = 52;
      _la = tokenStream.LA(1)!;
      if (!(_la == TOKEN_T__9 || _la == TOKEN_T__10)) {
      errorHandler.recoverInline(this);
      } else {
        if ( tokenStream.LA(1)! == IntStream.EOF ) matchedEOF = true;
        errorHandler.reportMatch(this);
        consume();
      }
      state = 53;
      _localctx.id = match(TOKEN_STRING);
      state = 54;
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
    enterRule(_localctx, 10, RULE_sticker);
    int _la;
    try {
      enterOuterAlt(_localctx, 1);
      state = 56;
      _la = tokenStream.LA(1)!;
      if (!((((_la) & ~0x3f) == 0 && ((1 << _la) & 268431360) != 0))) {
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
      4,1,28,59,2,0,7,0,2,1,7,1,2,2,7,2,2,3,7,3,2,4,7,4,2,5,7,5,1,0,5,0,
      14,8,0,10,0,12,0,17,9,0,1,0,1,0,1,1,1,1,1,1,1,1,3,1,25,8,1,1,2,1,2,
      1,2,1,2,3,2,31,8,2,1,2,1,2,5,2,35,8,2,10,2,12,2,38,9,2,1,2,1,2,1,2,
      1,2,1,3,4,3,45,8,3,11,3,12,3,46,1,3,1,3,3,3,51,8,3,1,4,1,4,1,4,1,4,
      1,5,1,5,1,5,0,0,6,0,2,4,6,8,10,0,3,3,0,1,3,5,7,28,28,1,0,10,11,1,0,
      12,27,61,0,15,1,0,0,0,2,24,1,0,0,0,4,26,1,0,0,0,6,50,1,0,0,0,8,52,
      1,0,0,0,10,56,1,0,0,0,12,14,3,2,1,0,13,12,1,0,0,0,14,17,1,0,0,0,15,
      13,1,0,0,0,15,16,1,0,0,0,16,18,1,0,0,0,17,15,1,0,0,0,18,19,5,0,0,1,
      19,1,1,0,0,0,20,25,3,4,2,0,21,25,3,6,3,0,22,25,3,8,4,0,23,25,3,10,
      5,0,24,20,1,0,0,0,24,21,1,0,0,0,24,22,1,0,0,0,24,23,1,0,0,0,25,3,1,
      0,0,0,26,27,5,1,0,0,27,30,5,28,0,0,28,29,5,2,0,0,29,31,5,28,0,0,30,
      28,1,0,0,0,30,31,1,0,0,0,31,32,1,0,0,0,32,36,5,3,0,0,33,35,3,2,1,0,
      34,33,1,0,0,0,35,38,1,0,0,0,36,34,1,0,0,0,36,37,1,0,0,0,37,39,1,0,
      0,0,38,36,1,0,0,0,39,40,5,4,0,0,40,41,5,28,0,0,41,42,5,3,0,0,42,5,
      1,0,0,0,43,45,7,0,0,0,44,43,1,0,0,0,45,46,1,0,0,0,46,44,1,0,0,0,46,
      47,1,0,0,0,47,51,1,0,0,0,48,51,5,8,0,0,49,51,5,9,0,0,50,44,1,0,0,0,
      50,48,1,0,0,0,50,49,1,0,0,0,51,7,1,0,0,0,52,53,7,1,0,0,53,54,5,28,
      0,0,54,55,5,7,0,0,55,9,1,0,0,0,56,57,7,2,0,0,57,11,1,0,0,0,6,15,24,
      30,36,46,50
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

