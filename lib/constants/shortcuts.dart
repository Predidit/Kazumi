// 播放器默认快捷键
final Map<String, List<String>> defaultShortcuts = const {
  'playorpause': [' '],
  'forward': ['Arrow Right'],
  'rewind': ['Arrow Left'],
  'next': ['N'],
  'prev': ['P'],
  'volumeup': ['Arrow Up'],
  'volumedown': ['Arrow Down'],
  'togglemute': ['M'],
  'fullscreen': ['F'],
  'exitfullscreen': ['Escape'],
  'toggledanmaku': ['D'],
  'screenshot': ['S'],
  'skip': ['K'],
  'speed1': ['1'],
  'speed2': ['2'],
  'speed3': ['3'],
  'speedup': ['X'],
  'speeddown': ['Z'],
};

// 键位别名
final Map<String, String> keyAliases = {
  ' ': '空格',
  'Arrow Up': '↑',
  'Arrow Down': '↓',
  'Arrow Left': '←',
  'Arrow Right': '→',
  'Enter': '回车',
  'Tab': 'Tab',
  'Escape': 'Esc',
  'Backspace': '退格',
};

//功能中文名对应
final Map<String, String> shortcutsChineseName = {
  'playorpause': '播放 / 暂停',
  'forward': '快进 / 长按倍速',
  'rewind': '快退',
  'next': '下一集',
  'prev': '上一集',
  'volumeup': '音量加',
  'volumedown': '音量减',
  'togglemute': '静音',
  'fullscreen': '全屏',
  'exitfullscreen': '退出全屏',
  'toggledanmaku': '弹幕开关',
  'screenshot': '截图',
  'skip': '跳过',
  'speed1': '倍速：1x',
  'speed2': '倍速：2x',
  'speed3': '倍速：3x',
  'speedup': '倍速加',
  'speeddown': '倍速减',
};
