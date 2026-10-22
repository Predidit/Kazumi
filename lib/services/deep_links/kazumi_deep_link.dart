sealed class KazumiDeepLink {
  const KazumiDeepLink();

  static KazumiDeepLink? parse(Uri uri) {
    if (uri.scheme != 'kazumi') return null;
    try {
      if (uri.host == 'bangumi' && uri.pathSegments.length == 1) {
        final raw = uri.pathSegments.single;
        final id = int.tryParse(raw);
        // Plain digits only: no sign, whitespace or leading zeros.
        if (id != null && id > 0 && '$id' == raw) return BangumiDeepLink(id);
      }
      if (uri.host == 'search') {
        final query = uri.queryParameters['query']?.trim() ?? '';
        if (query.isNotEmpty) return SearchDeepLink(query);
      }
    } on FormatException {
      // Malformed percent-encoding.
    }
    return null;
  }
}

final class BangumiDeepLink extends KazumiDeepLink {
  const BangumiDeepLink(this.id);
  final int id;
}

final class SearchDeepLink extends KazumiDeepLink {
  const SearchDeepLink(this.query);
  final String query;
}
