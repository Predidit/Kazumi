import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:ech_http/ech_http.dart';
import 'package:http/http.dart' as http;
import 'package:kazumi/request/core/network_config.dart';
import 'package:kazumi/request/core/ech_transport.dart';

const _echKey = 'ech';

extension EchRequestOptions on RequestOptions {
  void requireEch() => extra[_echKey] = true;
}

class EchAdapter implements HttpClientAdapter {
  EchAdapter({
    required HttpClientAdapter fallback,
    required NetworkConfig config,
  }) : _fallback = fallback,
       _config = config;

  final HttpClientAdapter _fallback;
  final NetworkConfig _config;

  static Duration _positive(Duration? value, Duration fallback) =>
      value != null && value > Duration.zero ? value : fallback;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (options.extra[_echKey] != true) {
      return _fallback.fetch(options, requestStream, cancelFuture);
    }

    final abort = Completer<void>();
    void cancel() {
      if (!abort.isCompleted) abort.complete();
    }

    cancelFuture?.then((_) => cancel());
    EchLease? lease;
    void release() {
      cancel();
      lease?.release();
    }

    try {
      final connectTimeout = _positive(
        options.connectTimeout,
        _config.connectTimeout,
      );
      final receiveTimeout = _positive(
        options.receiveTimeout,
        _config.receiveTimeout,
      );
      lease = EchTransport.lease(
        options.uri,
        connectTimeout: connectTimeout,
        timeout:
            connectTimeout +
            receiveTimeout +
            _positive(options.sendTimeout, const Duration(seconds: 12)),
      );
      final request =
          _EchRequest(options.method, options.uri, requestStream, abort.future)
            ..followRedirects = options.followRedirects
            ..maxRedirects = options.maxRedirects
            ..persistentConnection = options.persistentConnection;
      for (final entry in options.headers.entries) {
        final value = entry.value;
        if (value != null) {
          request.headers[entry.key] = value is Iterable
              ? value.join(', ')
              : value.toString();
        }
      }
      // Native connect timeouts exclude DoH discovery.
      final timeout = connectTimeout + receiveTimeout;
      final response = await lease
          .send(request)
          .timeout(
            timeout,
            onTimeout: () {
              cancel();
              throw DioException.receiveTimeout(
                timeout: timeout,
                requestOptions: options,
              );
            },
          );
      return ResponseBody(
        _responseStream(response.stream, options, release),
        response.statusCode,
        headers: response.headers.map((key, value) => MapEntry(key, [value])),
        statusMessage: response.reasonPhrase,
        isRedirect: response.isRedirect,
        onClose: release,
      );
    } catch (error, stackTrace) {
      release();
      throw _mapError(error, stackTrace, options);
    }
  }

  Stream<Uint8List> _responseStream(
    Stream<List<int>> stream,
    RequestOptions options,
    void Function() release,
  ) async* {
    try {
      await for (final chunk in stream) {
        yield chunk is Uint8List ? chunk : Uint8List.fromList(chunk);
      }
    } catch (error, stackTrace) {
      throw _mapError(error, stackTrace, options);
    } finally {
      release();
    }
  }

  DioException _mapError(
    Object error,
    StackTrace stack,
    RequestOptions options,
  ) {
    if (error is DioException) return error;
    if (error is http.RequestAbortedException) {
      return DioException.requestCancelled(
        requestOptions: options,
        reason: error,
        stackTrace: stack,
      );
    }
    if (error is EchException && error.nativeCode == 28) {
      return DioException.receiveTimeout(
        requestOptions: options,
        timeout: options.receiveTimeout ?? _config.receiveTimeout,
        error: error,
      );
    }
    return DioException.connectionError(
      requestOptions: options,
      reason: error.toString(),
      error: error,
      stackTrace: stack,
    );
  }

  @override
  void close({bool force = false}) => _fallback.close(force: force);
}

class _EchRequest extends http.BaseRequest with http.Abortable {
  _EchRequest(super.method, super.url, this._stream, this.abortTrigger);

  final Stream<Uint8List>? _stream;
  @override
  final Future<void> abortTrigger;

  @override
  http.ByteStream finalize() {
    super.finalize();
    return http.ByteStream(_stream ?? const Stream.empty());
  }
}
