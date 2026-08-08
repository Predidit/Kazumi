/// One `key: value` row of a character's infobox, e.g. `性别: 男`.
class CharacterInfoField {
  final String key;
  final String value;

  const CharacterInfoField({
    required this.key,
    required this.value,
  });
}

class CharacterFullItem {
  final int id;
  final List<CharacterInfoField> infobox;
  final String summary;
  final String image;

  CharacterFullItem({
    required this.id,
    required this.infobox,
    required this.summary,
    required this.image,
  });

  factory CharacterFullItem.fromJson(Map<String, dynamic> json) {
    return CharacterFullItem(
      id: json['id'] ?? 0,
      infobox: _parseInfobox(json['infobox']),
      summary: json['summary'] ?? '',
      image: json['images']['large'] ?? '',
    );
  }

  factory CharacterFullItem.fromTemplate() {
    return CharacterFullItem(
      id: 0,
      infobox: const [],
      summary: '',
      image: '',
    );
  }

  /// Entries arrive as `{key, values: [{v, k?}]}`. Rows whose values are all
  /// blank are common — the wiki template ships empty slots — and are dropped.
  static List<CharacterInfoField> _parseInfobox(dynamic raw) {
    if (raw is! List) return const [];
    final fields = <CharacterInfoField>[];
    for (final entry in raw) {
      if (entry is! Map) continue;
      final key = (entry['key'] ?? '').toString().trim();
      final values = entry['values'];
      if (key.isEmpty || values is! List) continue;
      final parts = <String>[];
      for (final value in values) {
        if (value is! Map) continue;
        final text = (value['v'] ?? '').toString().trim();
        if (text.isNotEmpty) parts.add(text);
      }
      if (parts.isEmpty) continue;
      fields.add(CharacterInfoField(key: key, value: parts.join(' / ')));
    }
    return fields;
  }
}
