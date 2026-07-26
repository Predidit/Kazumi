import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:kazumi/services/logging/logger.dart';

/// Tracks whether the active link is cellular data rather than WLAN / LAN.
class MeteredNetworkService {
  MeteredNetworkService._();

  static final ValueNotifier<bool> _metered = ValueNotifier<bool>(false);
  static StreamSubscription<List<ConnectivityResult>>? _subscription;

  static bool get _supported => Platform.isAndroid || Platform.isIOS;

  static bool get isMetered => _metered.value;

  static ValueListenable<bool> get listenable => _metered;

  static void init() {
    if (!_supported || _subscription != null) {
      return;
    }
    // The platform emits the current state on subscription, so no initial read.
    _subscription = Connectivity().onConnectivityChanged.listen(
      _apply,
      onError: (Object error) {
        KazumiLogger().w('Network: 网络类型监听中断 $error');
      },
    );
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

  /// An unmetered transport wins over `mobile`, which Android reports alongside
  /// `wifi` during a handover. Null means unresolvable (`none`, or a bare
  /// `vpn`); the last known value stands rather than releasing the protection.
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
