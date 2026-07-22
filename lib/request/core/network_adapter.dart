import 'package:dio/dio.dart';

import 'network_adapter_web.dart'
    if (dart.library.io) 'network_adapter_native.dart' as platform;

HttpClientAdapter createPlatformHttpClientAdapter({
  String? proxyHost,
  int? proxyPort,
}) {
  return platform.createPlatformHttpClientAdapter(
    proxyHost: proxyHost,
    proxyPort: proxyPort,
  );
}
