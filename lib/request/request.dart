import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:kazumi/request/interceptor.dart';
import 'package:kazumi/utils/utils.dart';
import 'package:kazumi/utils/storage.dart';
import 'package:kazumi/utils/proxy_utils.dart';
import 'package:kazumi/utils/logger.dart';
import 'package:hive/hive.dart';

class Request {
  static final Request _instance = Request._internal();
  static late final Dio dio;
  static Box setting = GStorage.setting;
  factory Request() => _instance;

  // 初始化 （一般只在应用启动时调用）
  static Future<void> setCookie() async {
    setOptionsHeaders();
    // 初始化时检查并设置代理
    final bool proxyEnable =
        setting.get(SettingBoxKey.proxyEnable, defaultValue: false);
    if (proxyEnable) {
      setProxy();
    }
  }

  // 设置请求头
  static void setOptionsHeaders() {
    dio.options.headers['referer'] = '';
    dio.options.headers['user-agent'] = Utils.getRandomUA();
  }

  // 设置代理（仅支持 HTTP 代理）
  static void setProxy() {
    final bool proxyEnable =
        setting.get(SettingBoxKey.proxyEnable, defaultValue: false);
    if (!proxyEnable) {
      disableProxy();
      return;
    }

    final String proxyUrl =
        setting.get(SettingBoxKey.proxyUrl, defaultValue: '');
    final String proxyUsername =
        setting.get(SettingBoxKey.proxyUsername, defaultValue: '');
    final String proxyPassword =
        setting.get(SettingBoxKey.proxyPassword, defaultValue: '');

    final parsed = ProxyUtils.parseProxyUrl(proxyUrl);
    if (parsed == null) {
      KazumiLogger().w('Proxy: 代理地址格式错误或为空');
      return;
    }

    final (proxyHost, proxyPort) = parsed;

    dio.httpClientAdapter = IOHttpClientAdapter(
      createHttpClient: () {
        final HttpClient client = HttpClient();
        client.findProxy = (Uri uri) {
          return 'PROXY $proxyHost:$proxyPort';
        };
        // 处理代理认证
        if (proxyUsername.isNotEmpty && proxyPassword.isNotEmpty) {
          client.addProxyCredentials(
            proxyHost,
            proxyPort,
            'Basic',
            HttpClientBasicCredentials(proxyUsername, proxyPassword),
          );
        }
        // 忽略证书验证
        client.badCertificateCallback =
            (X509Certificate cert, String host, int port) => true;
        return client;
      },
    );
    KazumiLogger().i('Proxy: HTTP 代理设置成功 $proxyHost:$proxyPort');
  }

  // 禁用代理
  static void disableProxy() {
    dio.httpClientAdapter = IOHttpClientAdapter(
        createHttpClient: () {
          final HttpClient client = HttpClient();
          return client;
        },
      );
    KazumiLogger().i('Proxy: 代理已禁用');
  }

  Request._internal() {
    //BaseOptions、Options、RequestOptions 都可以配置参数，优先级别依次递增，且可以根据优先级别覆盖参数
    BaseOptions options = BaseOptions(
      //请求基地址,可以包含子路径
      baseUrl: '',
      //连接服务器超时时间，单位是毫秒.
      connectTimeout: const Duration(milliseconds: 12000),
      //响应流上前后两次接受到数据的间隔，单位为毫秒。
      receiveTimeout: const Duration(milliseconds: 12000),
      //Http请求头.
      headers: {},
    );

    // enableSystemProxy = setting.get(SettingBoxKey.enableSystemProxy,
    //     defaultValue: false) as bool;

    dio = Dio(options);
    // debugPrint('Dio 初始化完成');
    
    // if (enableSystemProxy) {
    //   setProxy();
    //   debugPrint('系统代理启用');
    // }

    // 拦截器
    dio.interceptors.add(ApiInterceptor());

    // 日志拦截器 输出请求、响应内容
    dio.interceptors.add(LogInterceptor(
      request: false,
      requestHeader: false,
      responseHeader: false,
    ));

    dio.transformer = BackgroundTransformer();
    dio.options.validateStatus = (int? status) {
      return status! >= 200 && status < 300;
    };
  }

  Future<Response> get(url, {data, options, cancelToken, extra, bool shouldRethrow = false}) async {
    Response response;
    ResponseType resType = ResponseType.json;
    options ??= Options();
    if (extra != null) {
      resType = extra!['resType'] ?? ResponseType.json;
      if (extra['ua'] != null) {
        options.headers = {'user-agent': headerUa(type: extra['ua'])};
      }
      if (extra['customError'] != null) {
        options.extra = {'customError': extra['customError']};
      }
    }
    options.responseType = resType;
    try {
      response = await dio.get(
        url,
        queryParameters: data,
        options: options,
        cancelToken: cancelToken,
      );
      return response;
    } on DioException catch (e) {
      if (shouldRethrow) {
        rethrow;
      }
      Response errResponse = Response(
        data: {
          'message': await ApiInterceptor.dioError(e)
        }, // 将自定义 Map 数据赋值给 Response 的 data 属性
        statusCode: 200,
        requestOptions: RequestOptions(),
      );
      return errResponse;
    }
  }

  Future<Response> post(url, {data, queryParameters, options, cancelToken, extra, bool shouldRethrow = false}) async {
    // print('post-data: $data');
    Response response;
    try {
      response = await dio.post(
        url,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      );
      // print('post success: ${response.data}');
      return response;
    } on DioException catch (e) {
      if (shouldRethrow) {
        rethrow;
      }
      Response errResponse = Response(
        data: {
          'message': await ApiInterceptor.dioError(e)
        }, // 将自定义 Map 数据赋值给 Response 的 data 属性
        statusCode: 200,
        requestOptions: RequestOptions(),
      );
      return errResponse;
    }
  }

  String headerUa({type = 'mob'}) {
    return Utils.getRandomUA();
  }
}