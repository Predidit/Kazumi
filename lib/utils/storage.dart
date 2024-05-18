import 'package:hive/hive.dart';
import 'package:kazumi/modules/bangumi/bangumi_item.dart';
import 'package:kazumi/modules/history/history_module.dart';

class GStorage {
  static late Box<BangumiItem> favorites;
  static late Box<History> histories;

  static Future init() async {
    Hive.registerAdapter(BangumiItemAdapter());
    Hive.registerAdapter(ProgressAdapter());
    Hive.registerAdapter(HistoryAdapter());
    favorites = await Hive.openBox('favorites');
    histories = await Hive.openBox('histories');
  }

  // 阻止实例化
  GStorage._();
}