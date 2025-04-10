class SearchParser {
  final String query;
  final RegExp _idRegExp = RegExp(r'id:(\d+)', caseSensitive: false);
  final RegExp _tagRegExp = RegExp(r'tag:([\w\u4e00-\u9fa5\u30A0-\u30FF\.\-]+)', caseSensitive: false);

  SearchParser(this.query);

  String? parseId() {
    final match = _idRegExp.firstMatch(query);
    return match != null ? match.group(1) : null;
  }

  String? parseTag() {
    final match = _tagRegExp.firstMatch(query);
    return match != null ? match.group(1) : null;
  }

  String parseKeywords() {
    String cleaned = query.replaceAll(_idRegExp, '');
    cleaned = cleaned.replaceAll(_tagRegExp, '');
    return cleaned.trim();
  }
}