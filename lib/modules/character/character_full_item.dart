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
  final String name;
  final String nameCn;
  final String unstructuredInfo;

  CharacterFullItem._({
    required this.id,
    required this.infobox,
    required this.summary,
    required this.image,
    this.name = '',
    this.nameCn = '',
    this.unstructuredInfo = '',
  });

  factory CharacterFullItem.fromJson(Map<String, dynamic> json) {
    var fields = _parseInfobox(json['infobox']);
    var unstructuredInfo = '';
    if (fields.isEmpty) {
      (fields, unstructuredInfo) = _parseInfo(_text(json['info']));
    }
    var nameCn = _text(json['nameCN'] ?? json['name_cn']);
    if (nameCn.isEmpty) {
      nameCn = fields
              .where((field) => field.key == '简体中文名')
              .map((field) => field.value)
              .firstOrNull ??
          '';
    }
    final images = json['images'];
    return CharacterFullItem._(
      id: json['id'] ?? 0,
      infobox: List.unmodifiable(fields),
      summary: _text(json['summary']),
      image: images is Map
          ? ['large', 'medium', 'small']
              .map((size) => _text(images[size]))
              .firstWhere((url) => url.isNotEmpty, orElse: () => '')
          : '',
      name: _text(json['name']),
      nameCn: nameCn,
      unstructuredInfo: unstructuredInfo,
    );
  }

  factory CharacterFullItem.fromTemplate() {
    return CharacterFullItem._(
      id: 0,
      infobox: const [],
      summary: '',
      image: '',
    );
  }

  static String _text(Object? value) =>
      value is String || value is num ? value.toString().trim() : '';

  // /p1 uses `values`; /v0 uses `value`, including labeled aliases.
  static List<CharacterInfoField> _parseInfobox(Object? raw) {
    if (raw is! List) return const [];
    final fields = <CharacterInfoField>[];
    for (final entry in raw) {
      if (entry is! Map) continue;
      final key = _text(entry['key']);
      final rawValues = entry['values'] ?? entry['value'];
      if (key.isEmpty) continue;
      final values = rawValues is List ? rawValues : [rawValues];
      final parts = <String>[];
      for (final value in values) {
        final text = _text(value is Map ? value['v'] : value);
        if (text.isEmpty) continue;
        final label = value is Map ? _text(value['k']) : '';
        parts.add(label.isEmpty ? text : '$label：$text');
      }
      if (parts.isEmpty) continue;
      fields.add(CharacterInfoField(key: key, value: parts.join(' / ')));
    }
    return fields;
  }

  // The mirror replaces infobox with text; preserve lines without a field key.
  static (List<CharacterInfoField>, String) _parseInfo(String info) {
    final fields = <CharacterInfoField>[];
    final remaining = <String>[];
    for (final line in info.split(RegExp(r'\r?\n'))) {
      if (line.trim().isEmpty) continue;
      final separator = line.indexOf(RegExp('[:：]'));
      if (separator < 1) {
        remaining.add(line.trim());
        continue;
      }
      final key = line.substring(0, separator).trim();
      final value = line.substring(separator + 1).trim();
      if (key.isNotEmpty && value.isNotEmpty) {
        fields.add(CharacterInfoField(key: key, value: value));
      }
    }
    return (fields, remaining.join('\n'));
  }
}
