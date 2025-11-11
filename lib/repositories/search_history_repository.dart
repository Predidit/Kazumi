import 'package:kazumi/utils/storage.dart';
import 'package:kazumi/modules/search/search_history_module.dart';
import 'package:kazumi/utils/logger.dart';
import 'package:logger/logger.dart';

/// 搜索历史数据访问接口
///
/// 提供搜索历史相关的数据访问抽象
abstract class ISearchHistoryRepository {
  /// 获取所有搜索历史（按时间戳倒序）
  List<SearchHistory> getAllHistories();

  /// 保存搜索历史
  ///
  /// [keyword] 搜索关键词
  /// 返回是否成功
  Future<bool> saveHistory(String keyword);

  /// 删除指定搜索历史
  ///
  /// [history] 要删除的历史记录
  Future<void> deleteHistory(SearchHistory history);

  /// 清空所有搜索历史
  Future<void> clearAllHistories();

  /// 删除重复的历史记录
  ///
  /// [keyword] 关键词
  Future<void> deleteDuplicates(String keyword);

  /// 检查是否达到最大历史记录数
  ///
  /// [maxCount] 最大记录数
  /// 返回是否已满
  bool isHistoryFull(int maxCount);

  /// 删除最旧的历史记录
  Future<void> deleteOldest();
}

/// 搜索历史数据访问实现类
///
/// 基于Hive实现的搜索历史数据访问层
class SearchHistoryRepository implements ISearchHistoryRepository {
  final _searchHistoryBox = GStorage.searchHistory;

  @override
  List<SearchHistory> getAllHistories() {
    try {
      final histories = _searchHistoryBox.values.toList().cast<SearchHistory>();
      histories.sort((a, b) => b.timestamp - a.timestamp);
      return histories;
    } catch (e, stackTrace) {
      KazumiLogger().log(
        Level.warning,
        '获取搜索历史失败',
        error: e,
        stackTrace: stackTrace,
      );
      return [];
    }
  }

  @override
  Future<bool> saveHistory(String keyword) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final history = SearchHistory(keyword, timestamp);
      await _searchHistoryBox.put(timestamp.toString(), history);
      return true;
    } catch (e, stackTrace) {
      KazumiLogger().log(
        Level.error,
        '保存搜索历史失败: keyword=$keyword',
        error: e,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  @override
  Future<void> deleteHistory(SearchHistory history) async {
    try {
      await _searchHistoryBox.delete(history.key);
    } catch (e, stackTrace) {
      KazumiLogger().log(
        Level.error,
        '删除搜索历史失败: key=${history.key}',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  Future<void> clearAllHistories() async {
    try {
      await _searchHistoryBox.clear();
    } catch (e, stackTrace) {
      KazumiLogger().log(
        Level.error,
        '清空搜索历史失败',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  Future<void> deleteDuplicates(String keyword) async {
    try {
      final histories = getAllHistories();
      final duplicates = histories.where((h) => h.keyword == keyword);
      for (var history in duplicates) {
        await deleteHistory(history);
      }
    } catch (e, stackTrace) {
      KazumiLogger().log(
        Level.warning,
        '删除重复搜索历史失败: keyword=$keyword',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  bool isHistoryFull(int maxCount) {
    try {
      return _searchHistoryBox.length >= maxCount;
    } catch (e, stackTrace) {
      KazumiLogger().log(
        Level.warning,
        '检查搜索历史数量失败',
        error: e,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  @override
  Future<void> deleteOldest() async {
    try {
      final histories = getAllHistories();
      if (histories.isNotEmpty) {
        await deleteHistory(histories.last);
      }
    } catch (e, stackTrace) {
      KazumiLogger().log(
        Level.warning,
        '删除最旧搜索历史失败',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }
}
