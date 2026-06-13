class SearchParser {
  final String query;
  final RegExp _idRegExp = RegExp(r'id:(\d+)', caseSensitive: false);
  final RegExp _tagRegExp = RegExp(r'tag:(.+?)(?=\s+(sort:|id:)|$)', caseSensitive: false);
  final RegExp _sortRegExp = RegExp(r'sort:([\w\-]+)', caseSensitive: false);

  SearchParser(this.query);

  String? parseId() {
    final match = _idRegExp.firstMatch(query);
    return match != null ? match.group(1) : null;
  }

  List<String> parseTags() {
    final match = _tagRegExp.firstMatch(query);
    if (match == null) return [];
    final tagString = (match.group(1) ?? '').trim();
    return tagString
        .split(RegExp(r'\s+'))
        .where((e) => e.isNotEmpty)
        .toList();
  }

  String? parseSort() {
    final match = _sortRegExp.firstMatch(query);
    return match != null ? match.group(1) : null;
  }

  String parseKeywords() {
    String cleaned = query.replaceAll(_idRegExp, '');
    cleaned = cleaned.replaceAll(_tagRegExp, '');
    cleaned = cleaned.replaceAll(_sortRegExp, '');
    return cleaned.trim();
  }

  bool hasSortSyntax() {
    return _sortRegExp.hasMatch(query);
  }

  String removeSort() {
    return query.replaceAll(_sortRegExp, '').trim();
  }

  String updateSort(String sortValue) {
    if (hasSortSyntax()) {
      return query.replaceAllMapped(_sortRegExp, (match) => 'sort:$sortValue');
    } else {
      return '${query.trim()} sort:$sortValue'.trim();
    }
  }
}
