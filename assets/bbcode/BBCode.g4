grammar BBCode;

options { language=Dart; }

document
    : element* EOF
    ;

element
    : tag
    | plain
    | bgm
    | sticker
    ;

tag
    : '[' tagName=STRING ('=' attr=STRING)? ']' content=element* '[/' STRING ']'
    ;

plain
    : (STRING | '=' | '/' | '[' | ']' | '(' | ')')+
    // workaround unless these will break tag reconginze
    | '[来自Bangumi for android]'
    | '[来自Bangumi for iOS]'
    ;

bgm
    : ('(bgm' | '(BGM') id=STRING ')'
    ;

sticker
    : '(=A=)'
    | '(=w=)'
    | '(-w=)'
    | '(S_S)'
    | '(=v=)'
    | '(@_@)'
    | '(=W=)'
    | '(TAT)'
    | '(T_T)'
    | '(=\'=)'
    | '(=3=)'
    | '(= =\')'
    | '(=///=)'
    | '(=.,=)'
    | '(:P)'
    | '(LOL)';

STRING : ~[=[\]()]+;
