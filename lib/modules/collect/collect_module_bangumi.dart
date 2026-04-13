import 'package:hive_ce/hive.dart';
import 'package:kazumi/modules/bangumi/bangumi_item.dart';

/// Bangumi 远程收藏信息（包含最后更新时间）
@HiveType(typeId: 6)
class CollectedBangumiAndUpdate {
  @HiveField(0)
  BangumiItem bangumiItem;

  // 1. 在看
  // 2. 想看
  // 3. 搁置
  // 4. 看过
  // 5. 抛弃
  @HiveField(1)
  int type;

  @HiveField(2)
  int updatedAt;  // 最后更新时间

  CollectedBangumiAndUpdate(this.bangumiItem, this.type, this.updatedAt);
}