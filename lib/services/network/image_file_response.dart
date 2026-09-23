import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:http/http.dart' as http;

Future<FileServiceResponse> createImageFileResponse(
  http.StreamedResponse response, {
  required void Function() onComplete,
}) async {
  // CacheManager only consumes 200/202 bodies.
  if (response.statusCode != 200 && response.statusCode != 202) {
    try {
      await response.stream.listen(null).cancel();
    } finally {
      onComplete();
    }
    return _ImageFileResponse(response, const Stream.empty());
  }
  return _ImageFileResponse(
    response,
    _releaseAfter(response.stream, onComplete),
  );
}

Stream<List<int>> _releaseAfter(
  Stream<List<int>> stream,
  void Function() onComplete,
) async* {
  try {
    yield* stream;
  } finally {
    onComplete();
  }
}

class _ImageFileResponse extends HttpGetResponse {
  _ImageFileResponse(super.response, this.content);

  @override
  final Stream<List<int>> content;
}
