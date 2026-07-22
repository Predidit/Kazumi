import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:kazumi/services/network/system_proxy_service.dart';

HttpClientAdapter createPlatformHttpClientAdapter({
  String? proxyHost,
  int? proxyPort,
}) {
  return IOHttpClientAdapter(
    createHttpClient: () {
      final client = HttpClient();
      if (proxyHost != null && proxyPort != null) {
        client.findProxy = (_) => 'PROXY $proxyHost:$proxyPort';
      } else if (Platform.isWindows) {
        client.findProxy = SystemProxyService.findProxy;
      }
      return client;
    },
  );
}
