import 'package:dio/dio.dart';
import 'package:kazumi/request/core/dio_factory.dart';
import 'package:kazumi/request/core/network_error_mapper.dart';

class DownloadHttpClient {
  DownloadHttpClient._();

  static final DownloadHttpClient instance = DownloadHttpClient._();

  Future<Response<ResponseBody>> getStream(
    String url, {
    Map<String, dynamic> headers = const {},
    Duration? receiveTimeout,
    CancelToken? cancelToken,
  }) async {
    try {
      return await DioFactory.downloadDio.get<ResponseBody>(
        url,
        options: Options(
          headers: headers,
          responseType: ResponseType.stream,
          receiveTimeout: receiveTimeout,
        ),
        cancelToken: cancelToken,
      );
    } on DioException catch (e) {
      throw await NetworkErrorMapper.mapException(e);
    }
  }

  Future<String> getPlain(
    String url, {
    Map<String, dynamic> headers = const {},
    Duration? receiveTimeout,
    CancelToken? cancelToken,
    ProgressCallback? onReceiveProgress,
  }) async {
    try {
      final response = await DioFactory.downloadDio.get<String>(
        url,
        options: Options(
          headers: headers,
          responseType: ResponseType.plain,
          receiveTimeout: receiveTimeout,
        ),
        cancelToken: cancelToken,
        onReceiveProgress: onReceiveProgress,
      );
      return response.data ?? '';
    } on DioException catch (e) {
      throw await NetworkErrorMapper.mapException(e);
    }
  }

  Future<void> download(
    String url,
    String savePath, {
    Map<String, dynamic> headers = const {},
    CancelToken? cancelToken,
    ProgressCallback? onReceiveProgress,
  }) async {
    try {
      await DioFactory.downloadDio.download(
        url,
        savePath,
        options: Options(headers: headers),
        cancelToken: cancelToken,
        onReceiveProgress: onReceiveProgress,
      );
    } on DioException catch (e) {
      throw await NetworkErrorMapper.mapException(e);
    }
  }
}
