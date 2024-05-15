import 'package:hive/hive.dart';
import 'package:kazumi/modules/bangumi/bangumi_item.dart';

class GStorage {
  static late Box<BangumiItem> favorites;

  static Future init() async {
    Hive.registerAdapter(BangumiItemAdapter());
    favorites = await Hive.openBox('favorites');
  }

  // 阻止实例化
  GStorage._();
}