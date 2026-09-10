import 'package:flutter/foundation.dart';
import 'package:kazumi/services/storage/storage.dart';
import 'package:kazumi/services/logging/logger.dart';
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
      throw StateError('请先连接 Bangumi 账号');
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
          return 'Access Token 无效或已过期，请在「Bangumi 账号」中更换';
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

  Future<T> runConnected<T>(Future<T> Function(String username) action,
          {bool requireSyncEnabled = false}) =>
      _operations.run(() async {
        if (requireSyncEnabled &&
            !GStorage.getSetting(SettingsKeys.bangumiSyncEnable)) {
          throw StateError('请先开启 Bangumi 同步');
        }
        await _connectConfiguredToken();
        return action(username);
      });

  Future<bool> updateCollectible(int bangumiId, int localType) =>
      runConnected((_) => BangumiApi.updateBangumiByType(bangumiId, localType));
}
