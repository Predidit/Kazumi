import 'package:hive/hive.dart';
import 'package:kazumi/utils/storage.dart';
import 'package:kazumi/modules/collect/collect_type.dart';
import 'package:kazumi/utils/logger.dart';
import 'package:logger/logger.dart';

/// 收藏数据访问接口
///
/// 提供收藏相关的数据访问抽象，解耦业务逻辑与数据存储
abstract class ICollectRepository {
  /// 根据收藏类型获取番剧ID集合
  ///
  /// [type] 收藏类型
  /// 返回符合条件的番剧ID集合
  Set<int> getBangumiIdsByType(CollectType type);

  /// 更新过滤器设置
  ///
  /// [key] 设置键
  /// [value] 设置值
  Future<void> updateFilterSetting(String key, bool value);

  /// 获取过滤器设置
  ///
  /// [key] 设置键
  /// [defaultValue] 默认值
  /// 返回设置值
  bool getFilterSetting(String key, {bool defaultValue = false});

  /// 批量获取多种类型的番剧ID集合
  ///
  /// [types] 收藏类型列表
  /// 返回符合条件的番剧ID集合（并集）
  Set<int> getBangumiIdsByTypes(List<CollectType> types);
}

/// 收藏数据访问实现类
///
/// 基于Hive实现的收藏数据访问层
class CollectRepository implements ICollectRepository {
  final Box _collectiblesBox;
  final Box _settingBox;

  /// 构造函数
  ///
  /// [collectiblesBox] 收藏数据Box，默认使用GStorage.collectibles
  /// [settingBox] 设置数据Box，默认使用GStorage.setting
  CollectRepository({
    Box? collectiblesBox,
    Box? settingBox,
  })  : _collectiblesBox = collectiblesBox ?? GStorage.collectibles,
        _settingBox = settingBox ?? GStorage.setting;

  @override
  Set<int> getBangumiIdsByType(CollectType type) {
    try {
      return _collectiblesBox.values
          .where((item) => item.type == type.value)
          .map<int>((item) => item.bangumiItem.id)
          .toSet();
    } catch (e, stackTrace) {
      KazumiLogger().log(
        Level.warning,
        '获取收藏番剧ID失败: type=${type.label}',
        error: e,
        stackTrace: stackTrace,
      );
      return <int>{};
    }
  }

  @override
  Set<int> getBangumiIdsByTypes(List<CollectType> types) {
    try {
      final typeValues = types.map((t) => t.value).toSet();
      return _collectiblesBox.values
          .where((item) => typeValues.contains(item.type))
          .map<int>((item) => item.bangumiItem.id)
          .toSet();
    } catch (e, stackTrace) {
      KazumiLogger().log(
        Level.warning,
        '批量获取收藏番剧ID失败: types=${types.map((t) => t.label).join(", ")}',
        error: e,
        stackTrace: stackTrace,
      );
      return <int>{};
    }
  }

  @override
  Future<void> updateFilterSetting(String key, bool value) async {
    try {
      await _settingBox.put(key, value);
    } catch (e, stackTrace) {
      KazumiLogger().log(
        Level.error,
        '更新过滤器设置失败: key=$key, value=$value',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  bool getFilterSetting(String key, {bool defaultValue = false}) {
    try {
      final value = _settingBox.get(key, defaultValue: defaultValue);
      return value is bool ? value : defaultValue;
    } catch (e, stackTrace) {
      KazumiLogger().log(
        Level.warning,
        '获取过滤器设置失败: key=$key, 使用默认值=$defaultValue',
        error: e,
        stackTrace: stackTrace,
      );
      return defaultValue;
    }
  }
}
