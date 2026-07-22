import 'package:dio/browser.dart';
import 'package:dio/dio.dart';

HttpClientAdapter createPlatformHttpClientAdapter({
  String? proxyHost,
  int? proxyPort,
}) {
  // Browser networking follows the browser/OS proxy and CORS policy. An
  // application-level arbitrary proxy cannot be configured safely here.
  return BrowserHttpClientAdapter(withCredentials: false);
}
