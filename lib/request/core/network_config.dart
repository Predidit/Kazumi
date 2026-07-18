import 'dart:io';

import 'package:dio/io.dart';
import 'package:kazumi/services/logging/logger.dart';
import 'package:kazumi/services/network/proxy_utils.dart';
import 'package:kazumi/services/network/system_proxy_service.dart';
import 'package:kazumi/services/storage/storage.dart';

class NetworkConfig {
  const NetworkConfig({
    this.connectTimeout = const Duration(seconds: 12),
    this.receiveTimeout = const Duration(seconds: 12),
    this.sendTimeout,
    this.proxyHost,
    this.proxyPort,
    this.enableLog = true,
  });

  final Duration connectTimeout;
  final Duration receiveTimeout;
  final Duration? sendTimeout;
  final String? proxyHost;
  final int? proxyPort;
  final bool enableLog;

  bool get hasProxy => proxyHost != null && proxyPort != null;

  IOHttpClientAdapter createAdapter() {
    return IOHttpClientAdapter(
      createHttpClient: () {
        final client = HttpClient();
        if (hasProxy) {
          client.findProxy = (_) => 'PROXY $proxyHost:$proxyPort';
        } else if (Platform.isWindows) {
          client.findProxy = SystemProxyService.findProxy;
        }
        return client;
      },
    );
  }

  NetworkConfig copyWith({
    Duration? connectTimeout,
    Duration? receiveTimeout,
    Duration? sendTimeout,
    String? proxyHost,
    int? proxyPort,
    bool? clearProxy,
    bool? enableLog,
  }) {
    final shouldClearProxy = clearProxy ?? false;
    return NetworkConfig(
      connectTimeout: connectTimeout ?? this.connectTimeout,
      receiveTimeout: receiveTimeout ?? this.receiveTimeout,
      sendTimeout: sendTimeout ?? this.sendTimeout,
      proxyHost: shouldClearProxy ? null : proxyHost ?? this.proxyHost,
      proxyPort: shouldClearProxy ? null : proxyPort ?? this.proxyPort,
      enableLog: enableLog ?? this.enableLog,
    );
  }

  static NetworkConfig fromSettings({
    Duration connectTimeout = const Duration(seconds: 12),
    Duration receiveTimeout = const Duration(seconds: 12),
    Duration? sendTimeout,
  }) {
    final bool proxyEnable = GStorage.getSetting(SettingsKeys.proxyEnable);
    if (!proxyEnable) {
      return NetworkConfig(
        connectTimeout: connectTimeout,
        receiveTimeout: receiveTimeout,
        sendTimeout: sendTimeout,
      );
    }

    final proxyUrl = GStorage.getSetting(SettingsKeys.proxyUrl);
    final parsed = ProxyUtils.parseProxyUrl(proxyUrl);
    if (parsed == null) {
      KazumiLogger().w('Proxy: 代理地址格式错误或为空');
      return NetworkConfig(
        connectTimeout: connectTimeout,
        receiveTimeout: receiveTimeout,
        sendTimeout: sendTimeout,
      );
    }

    return NetworkConfig(
      connectTimeout: connectTimeout,
      receiveTimeout: receiveTimeout,
      sendTimeout: sendTimeout,
      proxyHost: parsed.$1,
      proxyPort: parsed.$2,
    );
  }
}
