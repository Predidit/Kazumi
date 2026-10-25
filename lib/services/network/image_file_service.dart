import 'dart:io' show HttpClientResponseCompressionState;

import 'package:ech_http/ech_http.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:kazumi/request/core/ech_transport.dart';
import 'package:kazumi/request/core/network_config.dart';
import 'package:kazumi/services/network/bangumi_image_url_rewriter.dart';
import 'package:kazumi/services/network/image_acceleration.dart';
import 'package:kazumi/services/network/image_file_response.dart';
import 'package:kazumi/utils/constants.dart' show bangumiHTTPHeader;

class ImageFileService extends FileService {
  final _clients = <http.Client>{};
  bool _closed = false;

  void close() {
    _closed = true;
    for (final client in _clients) {
      client.close();
    }
    _clients.clear();
  }

  @override
  Future<FileServiceResponse> get(
    String url, {
    Map<String, String>? headers,
  }) async {
    if (_closed) throw StateError('Image file service is closed');
    final mode = ImageAcceleration.current;
    var uri = Uri.parse(url);
    final ech =
        mode == ImageAcceleration.ech &&
        BangumiImageUrlRewriter.isBangumiImage(uri);
    if (ech) {
      uri = uri.replace(scheme: 'https');
    } else if (mode == ImageAcceleration.mirror) {
      uri = BangumiImageUrlRewriter.rewrite(uri);
    }

    final request = http.Request('GET', uri);
    final Future<http.StreamedResponse> Function(http.BaseRequest) send;
    final void Function() release;
    if (ech) {
      final lease = EchTransport.lease(uri);
      send = lease.send;
      release = lease.release;
      request.headers['user-agent'] = bangumiHTTPHeader['user-agent']!;
    } else {
      final client = IOClient(NetworkConfig.fromSettings().createHttpClient());
      _clients.add(client);
      send = client.send;
      release = () => _release(client);
    }
    if (headers != null) request.headers.addAll(headers);

    final http.StreamedResponse response;
    try {
      response = await send(request);
    } catch (_) {
      release();
      rethrow;
    }
    return createImageFileResponse(
      response,
      // ECH preserves wire lengths after decompression; decoded size is unknown.
      contentLength:
          response is EchResponse &&
              response.compressionState ==
                  HttpClientResponseCompressionState.decompressed
          ? null
          : response.contentLength,
      onComplete: release,
    );
  }

  void _release(http.Client client) {
    if (_clients.remove(client)) client.close();
  }
}
