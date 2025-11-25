import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:kazumi/request/interceptor.dart';
import 'package:kazumi/utils/utils.dart';

class Request {
  static final Request _instance = Request._internal();
  static late final Dio dio;
  // Box setting = GStorage.setting;
  // static Box localCache = GStorage.localCache;
  // late bool enableSystemProxy;
  factory Request() => _instance;

  // 初始化 （一般只在应用启动时调用）
  static Future<void> setCookie() async {
    setOptionsHeaders();
  }

  // 设置请求头
  static void setOptionsHeaders() {
    dio.options.headers['referer'] = '';
    dio.options.headers['user-agent'] = Utils.getRandomUA();
  }

  // 设置代理
  static void setProxy() {
    // var systemProxyHost =
    //     localCache.get(LocalCacheKey.systemProxyHost, defaultValue: '');
    // var systemProxyPort =
    //     localCache.get(LocalCacheKey.systemProxyPort, defaultValue: '');
    // dio.httpClientAdapter = IOHttpClientAdapter(
    //     createHttpClient: () {
    //       final HttpClient client = HttpClient();
    //       // Config the client.
    //       client.findProxy = (Uri uri) {
    //         // return 'PROXY host:port';
    //         return 'PROXY $systemProxyHost:$systemProxyPort';
    //       };
    //       client.badCertificateCallback =
    //           (X509Certificate cert, String host, int port) => true;
    //       return client;
    //     },
    //   );
    // debugPrint('代理设置更新成功');
  }

  // 禁用代理
  static void disableProxy() {
    dio.httpClientAdapter = IOHttpClientAdapter(
        createHttpClient: () {
          final HttpClient client = HttpClient();
          return client;
        },
      );
    print('代理禁用');
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