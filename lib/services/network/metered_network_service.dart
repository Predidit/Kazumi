import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:kazumi/services/logging/logger.dart';

class MeteredNetworkService {
  MeteredNetworkService._();

  static final ValueNotifier<bool> _metered = ValueNotifier<bool>(false);
  static StreamSubscription<List<ConnectivityResult>>? _subscription;
  static int _revision = 0;

  static bool get _supported =>
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;

  static bool get isMetered => _metered.value;

  static ValueListenable<bool> get listenable => _metered;

  static Future<void> refresh() async {
    if (!_supported) return;
    final revision = ++_revision;
    try {
      // Reset event deduplication after missed background network changes.
      final previous = _subscription;
      _subscription = null;
      await previous?.cancel();
      if (revision != _revision) return;
      _subscription = Connectivity().onConnectivityChanged.listen(
        (results) {
          _revision++;
          _apply(results);
        },
        onError: (Object error) {
          KazumiLogger().w('Network: 网络类型监听中断 $error');
        },
      );
      final results = await Connectivity()
          .checkConnectivity()
          .timeout(const Duration(seconds: 3));
      // Discard queries superseded by a refresh or a network event.
      if (revision == _revision) {
        _apply(results);
      }
    } catch (error) {
      KazumiLogger().w('Network: 读取网络类型失败，保留上次状态 $error');
    }
  }

  static void _apply(List<ConnectivityResult> results) {
    final metered = _isMetered(results);
    if (metered == null || metered == _metered.value) {
      return;
    }
    KazumiLogger()
        .i(metered ? 'Network: 切换到移动数据网络' : 'Network: 切换到 WLAN / 局域网');
    _metered.value = metered;
  }

  // WLAN wins during handovers; unknown transports retain the last known state.
  static bool? _isMetered(List<ConnectivityResult> results) {
    if (results.contains(ConnectivityResult.wifi) ||
        results.contains(ConnectivityResult.ethernet)) {
      return false;
    }
    if (results.contains(ConnectivityResult.mobile)) {
      return true;
    }
    return null;
  }
}
