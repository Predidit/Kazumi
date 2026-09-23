abstract final class BangumiImageUrlRewriter {
  static const _apiImageKinds = {'subjects', 'characters', 'persons'};

  static Uri rewrite(Uri uri) {
    if (!isBangumiImage(uri)) return uri;

    final sourceUrl =
        uri.host + uri.path + (uri.hasQuery ? '?${uri.query}' : '');
    return Uri.https('wsrv.nl', '/', {
      'url': sourceUrl,
      if (uri.path.toLowerCase().endsWith('.gif')) 'n': '-1',
    });
  }

  static bool _isHttp(Uri uri) => uri.scheme == 'http' || uri.scheme == 'https';

  static bool isBangumiImage(Uri uri) =>
      _isHttp(uri) && (uri.host == 'lain.bgm.tv' || _isApiImage(uri));

  static bool _isApiImage(Uri uri) {
    if (uri.host != 'api.bgm.tv') return false;

    final segments = uri.pathSegments;
    if (segments.length != 4 || segments[0] != 'v0' || segments[3] != 'image') {
      return false;
    }
    final id = int.tryParse(segments[2]);
    return _apiImageKinds.contains(segments[1]) && id != null && id > 0;
  }
}
