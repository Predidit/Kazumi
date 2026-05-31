import 'package:dio/dio.dart';
import 'package:kazumi/request/config/api_endpoints.dart';
import 'package:kazumi/request/core/dio_logger_interceptor.dart';
import 'package:kazumi/request/core/network_config.dart';
import 'package:kazumi/services/logging/logger.dart';
import 'package:kazumi/services/storage/storage.dart';
import 'package:kazumi/utils/http_headers.dart';

class DioFactory {
  DioFactory._();

  static Dio? _apiDio;
  static Dio? _githubDio;
  static Dio? _pluginDio;
  static Dio? _downloadDio;
  static Dio? _translateDio;

  static Dio get apiDio => _apiDio ??= _create(
        NetworkConfig.fromSettings(),
        defaultHeaders: {
          'referer': '',
          'user-agent': getRandomUA(),
        },
        interceptors: [_BangumiMirrorInterceptor()],
      );

  static Dio get githubDio => _githubDio ??= _create(
        NetworkConfig.fromSettings(),
        defaultHeaders: {
          'accept': 'application/vnd.github+json',
          'user-agent': getRandomUA(),
        },
        interceptors: [_GithubMirrorInterceptor()],
      );

  static Dio get pluginDio => _pluginDio ??= _create(
        NetworkConfig.fromSettings(),
        defaultHeaders: {
          'user-agent': getRandomUA(),
          'accept-language': getRandomAcceptedLanguage(),
        },
      );

  static Dio get downloadDio => _downloadDio ??= _create(
        NetworkConfig.fromSettings(
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 30),
        ),
        defaultHeaders: {
          'user-agent': getRandomUA(),
        },
      );

  static Dio createForConfig(NetworkConfig config) {
    return _create(config);
  }

  /// Dedicated client for the translation endpoint (no mirror interceptors).
  static Dio get translateDio => _translateDio ??= _create(
        NetworkConfig.fromSettings(
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 15),
        ),
        defaultHeaders: {
          'user-agent': getRandomUA(),
        },
      );

  static void reset() {
    _apiDio = null;
    _githubDio = null;
    _pluginDio = null;
    _downloadDio = null;
    _translateDio = null;
  }

  static Dio _create(
    NetworkConfig config, {
    Map<String, dynamic> defaultHeaders = const {},
    List<Interceptor> interceptors = const [],
  }) {
    // Keep the constructor tear-off form so the migration guard can flag
    // direct Dio construction outside this factory with a simple search.
    // ignore: unnecessary_constructor_name
    final dio = Dio.new(
      BaseOptions(
        connectTimeout: config.connectTimeout,
        receiveTimeout: config.receiveTimeout,
        sendTimeout: config.sendTimeout,
        headers: defaultHeaders,
        validateStatus: (status) =>
            status != null && status >= 200 && status < 300,
      ),
    );
    dio.httpClientAdapter = config.createAdapter();
    dio.transformer = BackgroundTransformer();
    dio.interceptors.addAll(interceptors);
    if (config.enableLog) {
      dio.interceptors.add(DioLoggerInterceptor());
    }
    return dio;
  }
}

class _BangumiMirrorInterceptor extends Interceptor {
  static const _mirrorableHosts = {
    'api.bgm.tv',
    'next.bgm.tv',
  };

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final enableBangumiProxy = GStorage.setting
        .get(SettingBoxKey.enableBangumiProxy, defaultValue: false);
    if (!enableBangumiProxy) {
      handler.next(options);
      return;
    }

    final uri = options.uri;
    if (!_mirrorableHosts.contains(uri.host)) {
      handler.next(options);
      return;
    }

    final mirrored = ApiEndpoints.bangumiMirrorDomain +
        uri.path +
        (uri.hasQuery ? '?${uri.query}' : '');
    KazumiLogger().d('Bangumi mirror: $mirrored');
    options.path = mirrored;
    handler.next(options);
  }
}

class _GithubMirrorInterceptor extends Interceptor {
  static const _mirrorableHosts = {
    'api.github.com',
    'github.com',
    'raw.githubusercontent.com',
    'objects.githubusercontent.com',
    'github-releases.githubusercontent.com',
  };

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final enableGitProxy =
        GStorage.setting.get(SettingBoxKey.enableGitProxy, defaultValue: false);
    if (!enableGitProxy) {
      handler.next(options);
      return;
    }

    final uri = options.uri;
    if (!_mirrorableHosts.contains(uri.host)) {
      handler.next(options);
      return;
    }

    final mirrored = '${ApiEndpoints.gitMirror}${uri.toString()}';
    KazumiLogger().d('GitHub mirror: $mirrored');
    options.path = mirrored;
    handler.next(options);
  }
}
