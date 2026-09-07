import 'package:flutter/foundation.dart';
import 'package:kazumi/modules/collect/collect_sync_merger.dart';
import 'package:kazumi/services/storage/storage.dart';
import 'package:kazumi/services/logging/logger.dart';
import 'package:kazumi/modules/bangumi/sync_priority.dart';
import 'package:kazumi/request/apis/bangumi_api.dart';
import 'package:kazumi/request/core/network_exception.dart';
import 'package:kazumi/utils/async_serial_queue.dart';

class BangumiSyncService extends ChangeNotifier {
  String _username = '';
  String get username => initialized ? _username : '';

  String? _verifiedToken;
  bool get initialized =>
      _verifiedToken != null && _verifiedToken == _configuredToken;

  bool _isConnecting = false;
  bool get isConnecting => _isConnecting;

  String? _lastError;
  String? get lastError => _lastError;

  final _operations = AsyncSerialQueue();

  String get _configuredToken =>
      GStorage.getSetting(SettingsKeys.bangumiAccessToken).trim();

  BangumiSyncService._internal();
  static final BangumiSyncService _instance = BangumiSyncService._internal();
  factory BangumiSyncService() => _instance;

  @visibleForTesting
  void resetForTesting() {
    _verifiedToken = null;
    _username = '';
    _lastError = null;
    notifyListeners();
  }

  Future<void> ping() => _operations.run(_connectConfiguredToken);

  Future<void> setEnabled(bool enabled) {
    return _operations.run(() async {
      if (enabled) {
        await _connectConfiguredToken();
      }
      await GStorage.putSetting(SettingsKeys.bangumiSyncEnable, enabled);
      notifyListeners();
    });
  }

  Future<String> _validateToken(String token) async {
    if (token.isEmpty) {
      throw StateError('请先在 Bangumi 配置中填写并保存 Access Token');
    }
    final user = await BangumiApi.getCurrentUser(accessToken: token);
    final name = user?.username;
    if (name == null || name.trim().isEmpty) {
      throw const FormatException('Bangumi 用户信息不完整');
    }
    return name;
  }

  Future<void> _connectConfiguredToken() async {
    _isConnecting = true;
    _lastError = null;
    notifyListeners();
    try {
      final token = _configuredToken;
      final name = await _validateToken(token);
      _verifiedToken = token;
      _username = name;
    } catch (e) {
      _verifiedToken = null;
      _username = '';
      _lastError = describeError(e);
      KazumiLogger().w('Bangumi: connection failed', error: e);
      rethrow;
    } finally {
      _isConnecting = false;
      notifyListeners();
    }
  }

  // Validate draft credentials before exposing them to other requests.
  Future<void> saveToken(String value) {
    return _operations.run(() async {
      final token = value.trim();
      _isConnecting = true;
      notifyListeners();
      try {
        final name = await _validateToken(token);
        await GStorage.putSetting(SettingsKeys.bangumiAccessToken, token);
        _verifiedToken = token;
        _username = name;
        _lastError = null;
      } catch (e) {
        if (token == _configuredToken) {
          _verifiedToken = null;
          _username = '';
          _lastError = describeError(e);
        }
        rethrow;
      } finally {
        _isConnecting = false;
        notifyListeners();
      }
    });
  }

  static String describeError(Object error) {
    if (error is NetworkException) {
      switch (error.statusCode) {
        case 401:
          return 'Access Token 无效或已过期，请在 Bangumi 配置中更换 Token';
        case 403:
          return 'Bangumi 拒绝访问，请检查 Token 权限或稍后重试';
        case 429:
          return 'Bangumi 请求过于频繁，请稍后重试';
      }
      if (error.statusCode != null) {
        return 'Bangumi 服务请求失败（HTTP ${error.statusCode}），请稍后重试';
      }
      return error.message;
    }
    if (error is FormatException || error is TypeError) {
      return 'Bangumi 返回的用户信息格式异常，请稍后重试';
    }
    if (error is StateError) return error.message.toString();
    return 'Bangumi 操作失败，请稍后重试';
  }

  Future<bool> syncCollectibleWhenIdle(int bangumiId, int localType) {
    return _operations.run(() async {
      if (!initialized) await _connectConfiguredToken();
      return BangumiApi.updateBangumiByType(
        bangumiId,
        localType,
      );
    });
  }

  Future<void> _applyLocalMutation(BangumiLocalMutation mutation) async {
    await GStorage.putCollectible(mutation.collectible);
    // Remote changes must also reach WebDAV's incremental change log.
    await GStorage.appendCollectChange(
      bangumiId: mutation.collectible.bangumiItem.id,
      action: mutation.changeAction,
      type: mutation.collectible.type,
    );
  }

  Future<void> syncCollectibles({
    void Function(String message, int current, int total)? onProgress,
  }) {
    return _operations.run(() async {
      try {
        if (!GStorage.getSetting(SettingsKeys.bangumiSyncEnable)) {
          throw StateError('请先开启 Bangumi 同步');
        }
        await _connectConfiguredToken();
        onProgress?.call('开始同步 Bangumi 状态', 0, 0);

        final priority = BangumiSyncPriority.fromValue(
          GStorage.getSetting(SettingsKeys.bangumiSyncPriority),
        );

        final remoteCollection = await BangumiApi.getBangumiCollectibles(
          username: username,
          limit: 50,
          onProgress: onProgress,
        );

        final mergePlan = CollectSyncMerger.planBangumi(
          localCollectibles: GStorage.collectibles.values.toList(),
          remoteCollections: remoteCollection,
          priority: priority,
        );
        final totalOperations = mergePlan.totalOperations;

        if (totalOperations == 0) {
          onProgress?.call('未发现状态差异，无需同步', 1, 1);
          return;
        }

        int syncedCount = 0;
        if (mergePlan.localOnlyUploads.isNotEmpty) {
          onProgress?.call('正在上传本地新增状态', syncedCount, totalOperations);
          for (final upload in mergePlan.localOnlyUploads) {
            final updated = await BangumiApi.updateBangumiByType(
              upload.bangumiId,
              upload.type,
            );
            if (!updated) {
              onProgress?.call('上传本地新增状态失败', syncedCount, totalOperations);
              throw Exception('同步失败：条目 ${upload.bangumiId} 上传到 Bangumi 失败');
            }
            syncedCount++;
            onProgress?.call('正在上传本地新增状态', syncedCount, totalOperations);
          }
        }

        if (mergePlan.remoteOnlyPuts.isNotEmpty) {
          onProgress?.call('正在补全本地缺失状态', syncedCount, totalOperations);
          for (final mutation in mergePlan.remoteOnlyPuts) {
            await _applyLocalMutation(mutation);
            syncedCount++;
            onProgress?.call('正在补全本地缺失状态', syncedCount, totalOperations);
          }
        }

        if (mergePlan.conflictUploads.isNotEmpty) {
          onProgress?.call(
              '${priority.label}：正在上传冲突状态', syncedCount, totalOperations);
          for (final upload in mergePlan.conflictUploads) {
            final updated = await BangumiApi.updateBangumiByType(
              upload.bangumiId,
              upload.type,
            );
            if (!updated) {
              throw Exception('同步失败：条目 ${upload.bangumiId} 上传到 Bangumi 失败');
            }
            syncedCount++;
            onProgress?.call(
                '${priority.label}：正在上传冲突状态', syncedCount, totalOperations);
          }
        }
        if (mergePlan.conflictLocalUpdates.isNotEmpty) {
          onProgress?.call(
              '${priority.label}：正在更新本地冲突状态', syncedCount, totalOperations);
          for (final mutation in mergePlan.conflictLocalUpdates) {
            await _applyLocalMutation(mutation);
            syncedCount++;
            onProgress?.call(
                '${priority.label}：正在更新本地冲突状态', syncedCount, totalOperations);
          }
        }
        onProgress?.call('Bangumi 状态同步完成', 1, 1);
      } catch (e) {
        KazumiLogger().e('Bangumi sync failed', error: e);
        rethrow;
      }
    });
  }
}
