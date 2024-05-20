import 'package:hive/hive.dart';
import 'package:kazumi/modules/bangumi/bangumi_item.dart';
import 'package:kazumi/modules/history/history_module.dart';

class GStorage {
  static late Box<BangumiItem> favorites;
  static late Box<History> histories;
  static late final Box<dynamic> setting;

  static Future init() async {
    Hive.registerAdapter(BangumiItemAdapter());
    Hive.registerAdapter(ProgressAdapter());
    Hive.registerAdapter(HistoryAdapter());
    favorites = await Hive.openBox('favorites');
    histories = await Hive.openBox('histories');
    setting = await Hive.openBox('setting');
  }

  // 阻止实例化
  GStorage._();
}

class SettingBoxKey {
  static const String hAenable = 'hAenable',
      searchEnhanceEnable = 'searchEnhanceEnable', 
      autoUpdate = 'autoUpdate',
      alwaysOntop = 'alwaysOntop',
      danmakuEnhance = 'danmakuEnhance',
      danmakuBorder = 'danmakuBorder',
      danmakuOpacity = 'danmakuOpacity',
      danmakuFontSize = 'danmakuFontSize',
      danmakuTop = 'danmakuTop',
      danmakuScroll = 'danmakuScroll',
      danmakuBottom = 'danmakuBottom',
      danmakuArea = 'danmakuArea',
      themeMode = 'themeMode',
      themeColor = 'themeColor',
      privateMode = 'privateMode',
      autoPlay = 'autoPlay',
      playResume = 'playResume',
      oledEnhance = 'oledEnhance',
      displayMode = 'displayMode',
      enableSystemProxy = 'enableSystemProxy';
}