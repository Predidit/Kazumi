import 'dart:async';
import 'dart:io';

import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:hive_ce/hive.dart';
import 'package:kazumi/services/logging/logger.dart';
import 'package:kazumi/services/network/proxy_utils.dart';
import 'package:kazumi/services/storage/storage.dart';

class ProxyAwareImageCacheManager extends CacheManager with ImageCacheManager {
  static final ProxyAwareImageCacheManager instance =
      ProxyAwareImageCacheManager._();

  ProxyAwareImageCacheManager._()
      : super(
          Config(
            DefaultCacheManager.key,
            fileService: ProxyAwareImageFileService(),
          ),
        );
}

class ProxyAwareImageFileService extends FileService {
  static String rewriteBangumiMirrorImageUrl(
    String url, {
    required bool enableBangumiProxy,
  }) {
    if (!enableBangumiProxy) return url;

    final uri = Uri.tryParse(url);
    if (uri == null || uri.host != 'lain.bgm.tv') return url;
    if (uri.scheme != 'http' && uri.scheme != 'https') return url;

    final sourceUrl =
        uri.host + uri.path + (uri.hasQuery ? '?${uri.query}' : '');
    return 'https://wsrv.nl/?url=$sourceUrl';
  }

  @override
  Future<FileServiceResponse> get(
    String url, {
    Map<String, String>? headers,
  }) async {
    final client = _createHttpClient();
    try {
      final request = await client.getUrl(Uri.parse(
        rewriteBangumiMirrorImageUrl(
          url,
          enableBangumiProxy: _bangumiMirrorEnabled(),
        ),
      ));
      headers?.forEach(request.headers.set);
      final response = await request.close();
      return _ProxyAwareImageFileServiceResponse(response, client);
    } catch (_) {
      client.close(force: true);
      rethrow;
    }
  }

  bool _bangumiMirrorEnabled() {
    return GStorage.setting
        .get(SettingBoxKey.enableBangumiProxy, defaultValue: false);
  }

  HttpClient _createHttpClient() {
    final client = HttpClient();
    final proxy = _currentProxy();
    if (proxy == null) return client;

    client.findProxy = (_) => 'PROXY ${proxy.$1}:${proxy.$2}';
    client.badCertificateCallback = (cert, host, port) => true;
    return client;
  }

  (String, int)? _currentProxy() {
    final Box setting = GStorage.setting;
    final bool proxyEnable =
        setting.get(SettingBoxKey.proxyEnable, defaultValue: false);
    if (!proxyEnable) return null;

    final String proxyUrl =
        setting.get(SettingBoxKey.proxyUrl, defaultValue: '');
    final parsed = ProxyUtils.parseProxyUrl(proxyUrl);
    if (parsed == null) {
      KazumiLogger().w('Proxy: image cache proxy address is malformed or empty');
    }
    return parsed;
  }
}

class _ProxyAwareImageFileServiceResponse implements FileServiceResponse {
  _ProxyAwareImageFileServiceResponse(this._response, this._client);

  final HttpClientResponse _response;
  final HttpClient _client;
  final DateTime _receivedTime = DateTime.now();

  @override
  Stream<List<int>> get content async* {
    try {
      await for (final chunk in _response) {
        yield chunk;
      }
    } finally {
      _client.close();
    }
  }

  @override
  int? get contentLength =>
      _response.contentLength >= 0 ? _response.contentLength : null;

  @override
  String? get eTag => _response.headers.value(HttpHeaders.etagHeader);

  @override
  String get fileExtension {
    return switch (_response.headers.contentType?.mimeType.toLowerCase()) {
      'image/jpeg' => '.jpg',
      'image/png' => '.png',
      'image/gif' => '.gif',
      'image/webp' => '.webp',
      'image/bmp' => '.bmp',
      'image/x-icon' || 'image/vnd.microsoft.icon' => '.ico',
      'image/avif' => '.avif',
      'image/svg+xml' => '.svg',
      _ => '',
    };
  }

  @override
  int get statusCode => _response.statusCode;

  @override
  DateTime get validTill {
    var ageDuration = const Duration(days: 7);
    final controlHeader =
        _response.headers.value(HttpHeaders.cacheControlHeader);
    if (controlHeader == null) {
      return _receivedTime.add(ageDuration);
    }

    final controlSettings = controlHeader.split(',');
    for (final setting in controlSettings) {
      final sanitizedSetting = setting.trim().toLowerCase();
      if (sanitizedSetting == 'no-cache') {
        ageDuration = Duration.zero;
      }
      if (sanitizedSetting.startsWith('max-age=')) {
        final validSeconds =
            int.tryParse(sanitizedSetting.split('=').last) ?? 0;
        if (validSeconds > 0) {
          ageDuration = Duration(seconds: validSeconds);
        }
      }
    }

    return _receivedTime.add(ageDuration);
  }
}
