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

  /// 批量获取多种类型的番剧ID集合
  ///
  /// [types] 收藏类型列表
  /// 返回符合条件的番剧ID集合（并集）
  Set<int> getBangumiIdsByTypes(List<CollectType> types);

  // ========== 搜索页过滤器设置 ==========

  /// 获取搜索页"不显示已看过番剧"设置
  bool getSearchNotShowWatchedBangumis();

  /// 更新搜索页"不显示已看过番剧"设置
  Future<void> updateSearchNotShowWatchedBangumis(bool value);

  /// 获取搜索页"不显示已抛弃番剧"设置
  bool getSearchNotShowAbandonedBangumis();

  /// 更新搜索页"不显示已抛弃番剧"设置
  Future<void> updateSearchNotShowAbandonedBangumis(bool value);

  // ========== 时间表页过滤器设置 ==========

  /// 获取时间表页"不显示已抛弃番剧"设置
  bool getTimelineNotShowAbandonedBangumis();

  /// 更新时间表页"不显示已抛弃番剧"设置
  Future<void> updateTimelineNotShowAbandonedBangumis(bool value);

  /// 获取时间表页"不显示已看过番剧"设置
  bool getTimelineNotShowWatchedBangumis();

  /// 更新时间表页"不显示已看过番剧"设置
  Future<void> updateTimelineNotShowWatchedBangumis(bool value);

  // ========== 其他设置 ==========

  /// 获取隐私模式设置
  bool getPrivateMode();
}

/// 收藏数据访问实现类
///
/// 基于Hive实现的收藏数据访问层
class CollectRepository implements ICollectRepository {
  final _collectiblesBox = GStorage.collectibles;
  final _settingBox = GStorage.setting;

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

  // ========== 搜索页过滤器设置实现 ==========

  @override
  bool getSearchNotShowWatchedBangumis() {
    try {
      final value = _settingBox.get(
        SettingBoxKey.searchNotShowWatchedBangumis,
        defaultValue: false,
      );
      return value is bool ? value : false;
    } catch (e, stackTrace) {
      KazumiLogger().log(
        Level.warning,
        '获取搜索页"不显示已看过"设置失败，使用默认值false',
        error: e,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  @override
  Future<void> updateSearchNotShowWatchedBangumis(bool value) async {
    try {
      await _settingBox.put(SettingBoxKey.searchNotShowWatchedBangumis, value);
    } catch (e, stackTrace) {
      KazumiLogger().log(
        Level.error,
        '更新搜索页"不显示已看过"设置失败: value=$value',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  bool getSearchNotShowAbandonedBangumis() {
    try {
      final value = _settingBox.get(
        SettingBoxKey.searchNotShowAbandonedBangumis,
        defaultValue: false,
      );
      return value is bool ? value : false;
    } catch (e, stackTrace) {
      KazumiLogger().log(
        Level.warning,
        '获取搜索页"不显示已抛弃"设置失败，使用默认值false',
        error: e,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  @override
  Future<void> updateSearchNotShowAbandonedBangumis(bool value) async {
    try {
      await _settingBox.put(SettingBoxKey.searchNotShowAbandonedBangumis, value);
    } catch (e, stackTrace) {
      KazumiLogger().log(
        Level.error,
        '更新搜索页"不显示已抛弃"设置失败: value=$value',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  // ========== 时间表页过滤器设置实现 ==========

  @override
  bool getTimelineNotShowAbandonedBangumis() {
    try {
      final value = _settingBox.get(
        SettingBoxKey.timelineNotShowAbandonedBangumis,
        defaultValue: false,
      );
      return value is bool ? value : false;
    } catch (e, stackTrace) {
      KazumiLogger().log(
        Level.warning,
        '获取时间表页"不显示已抛弃"设置失败，使用默认值false',
        error: e,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  @override
  Future<void> updateTimelineNotShowAbandonedBangumis(bool value) async {
    try {
      await _settingBox.put(SettingBoxKey.timelineNotShowAbandonedBangumis, value);
    } catch (e, stackTrace) {
      KazumiLogger().log(
        Level.error,
        '更新时间表页"不显示已抛弃"设置失败: value=$value',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  bool getTimelineNotShowWatchedBangumis() {
    try {
      final value = _settingBox.get(
        SettingBoxKey.timelineNotShowWatchedBangumis,
        defaultValue: false,
      );
      return value is bool ? value : false;
    } catch (e, stackTrace) {
      KazumiLogger().log(
        Level.warning,
        '获取时间表页"不显示已看过"设置失败，使用默认值false',
        error: e,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  @override
  Future<void> updateTimelineNotShowWatchedBangumis(bool value) async {
    try {
      await _settingBox.put(SettingBoxKey.timelineNotShowWatchedBangumis, value);
    } catch (e, stackTrace) {
      KazumiLogger().log(
        Level.error,
        '更新时间表页"不显示已看过"设置失败: value=$value',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  // ========== 其他设置实现 ==========

  @override
  bool getPrivateMode() {
    try {
      final value = _settingBox.get(
        SettingBoxKey.privateMode,
        defaultValue: false,
      );
      return value is bool ? value : false;
    } catch (e, stackTrace) {
      KazumiLogger().log(
        Level.warning,
        '获取隐私模式设置失败，使用默认值false',
        error: e,
        stackTrace: stackTrace,
      );
      return false;
    }
  }
}
