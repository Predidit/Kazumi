import 'dart:io';

import 'package:dio/io.dart';
import 'package:hive_ce/hive.dart';
import 'package:kazumi/utils/logger.dart';
import 'package:kazumi/utils/proxy_utils.dart';
import 'package:kazumi/utils/storage.dart';

class NetworkConfig {
  const NetworkConfig({
    this.connectTimeout = const Duration(seconds: 12),
    this.receiveTimeout = const Duration(seconds: 12),
    this.sendTimeout,
    this.proxyHost,
    this.proxyPort,
    this.allowBadCertificates = false,
    this.enableLog = true,
  });

  final Duration connectTimeout;
  final Duration receiveTimeout;
  final Duration? sendTimeout;
  final String? proxyHost;
  final int? proxyPort;
  final bool allowBadCertificates;
  final bool enableLog;

  bool get hasProxy => proxyHost != null && proxyPort != null;

  IOHttpClientAdapter createAdapter() {
    return IOHttpClientAdapter(
      createHttpClient: () {
        final client = HttpClient();
        if (hasProxy) {
          client.findProxy = (_) => 'PROXY $proxyHost:$proxyPort';
        }
        if (allowBadCertificates) {
          client.badCertificateCallback = (cert, host, port) => true;
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
    bool? allowBadCertificates,
    bool? enableLog,
  }) {
    final shouldClearProxy = clearProxy ?? false;
    return NetworkConfig(
      connectTimeout: connectTimeout ?? this.connectTimeout,
      receiveTimeout: receiveTimeout ?? this.receiveTimeout,
      sendTimeout: sendTimeout ?? this.sendTimeout,
      proxyHost: shouldClearProxy ? null : proxyHost ?? this.proxyHost,
      proxyPort: shouldClearProxy ? null : proxyPort ?? this.proxyPort,
      allowBadCertificates: allowBadCertificates ?? this.allowBadCertificates,
      enableLog: enableLog ?? this.enableLog,
    );
  }

  static NetworkConfig fromSettings({
    Duration connectTimeout = const Duration(seconds: 12),
    Duration receiveTimeout = const Duration(seconds: 12),
    Duration? sendTimeout,
  }) {
    final Box setting = GStorage.setting;
    final bool proxyEnable =
        setting.get(SettingBoxKey.proxyEnable, defaultValue: false);
    if (!proxyEnable) {
      return NetworkConfig(
        connectTimeout: connectTimeout,
        receiveTimeout: receiveTimeout,
        sendTimeout: sendTimeout,
      );
    }

    final proxyUrl = setting.get(SettingBoxKey.proxyUrl, defaultValue: '');
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
      allowBadCertificates: true,
    );
  }
}
