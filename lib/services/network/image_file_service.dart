import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:http/http.dart' as http;
import 'package:kazumi/services/network/bangumi_ech_image_service.dart';
import 'package:kazumi/services/network/bangumi_image_url_rewriter.dart';
import 'package:kazumi/services/network/image_acceleration.dart';
import 'package:kazumi/services/network/image_file_response.dart';

class ImageFileService extends FileService {
  ImageFileService({
    required ImageAcceleration Function() acceleration,
    required http.Client Function() clientFactory,
    required BangumiEchImageService echService,
  }) : _acceleration = acceleration,
       _clientFactory = clientFactory,
       _echService = echService;

  final ImageAcceleration Function() _acceleration;
  final http.Client Function() _clientFactory;
  final BangumiEchImageService _echService;
  final _clients = <http.Client>{};
  bool _closed = false;

  void resetNetworkClients() => _echService.reset();

  void close() {
    _closed = true;
    _echService.close();
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
    final mode = _acceleration();
    var uri = Uri.parse(url);
    if (mode == ImageAcceleration.ech &&
        BangumiImageUrlRewriter.isBangumiImage(uri)) {
      return _echService.get(
        uri.replace(scheme: 'https').toString(),
        headers: headers,
      );
    }
    if (mode == ImageAcceleration.mirror) {
      uri = BangumiImageUrlRewriter.rewrite(uri);
    }

    final client = _clientFactory();
    _clients.add(client);
    final http.StreamedResponse response;
    try {
      final request = http.Request('GET', uri);
      if (headers != null) request.headers.addAll(headers);
      response = await client.send(request);
    } catch (_) {
      _release(client);
      rethrow;
    }
    return createImageFileResponse(
      response,
      onComplete: () => _release(client),
    );
  }

  void _release(http.Client client) {
    if (_clients.remove(client)) client.close();
  }
}
