import 'dart:async';

import 'package:kazumi/repositories/danmaku_shield_repository.dart';
import 'package:kazumi/services/logging/logger.dart';
import 'package:kazumi/services/sync/webdav.dart';

class DanmakuShieldSyncService {
  DanmakuShieldSyncService(this._repository, this._webDav);

  final IDanmakuShieldRepository _repository;
  final WebDav _webDav;
  StreamSubscription<DanmakuShieldChange>? _subscription;
  Timer? _timer;

  void start() {
    _subscription ??= _repository.changes
        .where((change) => change == DanmakuShieldChange.localEdit)
        .listen((_) => _schedule());
  }

  void _schedule() {
    _timer?.cancel();
    if (!_webDav.isDanmakuShieldSyncEnabled) return;
    _timer = Timer(const Duration(milliseconds: 500), () {
      unawaited(syncIfEnabled());
    });
  }

  Future<void> sync() async {
    _timer?.cancel();
    if (!_webDav.isDanmakuShieldSyncEnabled) return;
    await _webDav.syncDanmakuShield(
      deviceId: await _repository.getDeviceId(),
      merge: _repository.mergeSyncState,
    );
  }

  Future<void> syncIfEnabled() async {
    try {
      await sync();
    } catch (e, stackTrace) {
      KazumiLogger().w(
        'WebDav: automatic danmaku shield sync failed; keeping local changes',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> dispose() async {
    _timer?.cancel();
    await _subscription?.cancel();
    _subscription = null;
  }
}
