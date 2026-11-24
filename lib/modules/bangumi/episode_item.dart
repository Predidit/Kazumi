class EpisodeInfo {
  int id;
  num episode;
  int type;
  String name;
  String nameCn;

  EpisodeInfo({
    required this.id,
    required this.episode,
    required this.type,
    required this.name,
    required this.nameCn,
  });

  factory EpisodeInfo.fromJson(Map<String, dynamic> json) {
    return EpisodeInfo(
        id: json['id'] ?? 0,
        episode: json['sort'] ?? 0,
        type: json['type'] ?? 0,
        name: json['name'] ?? '',
        nameCn: json['name_cn'] ?? '');
  }

  factory EpisodeInfo.fromTemplate() {
    return EpisodeInfo(id: 0, episode: 0, type: 0, name: '', nameCn: '');
  }

  void reset() {
    id = 0;
    episode = 0;
    type = 0;
    name = '';
    nameCn = '';
  }

  String readType() {
    switch (type) {
      case 0:
        return 'ep';
      case 1:
        return 'sp';
      case 2:
        return 'op';
      case 3:
        return 'ed';
      default:
        return '';
    }
  }
}

extension EpisodeInfoDisplay on EpisodeInfo {
  static String typeLabelOf(int type) => switch (type) {
        0 => '正片',
        1 => 'SP',
        2 => 'OP',
        3 => 'ED',
        _ => '其他',
      };

  String displayNumber(int fallbackEpisode) {
    final value = episode != 0 ? episode : fallbackEpisode;
    if (value is int) return '$value';
    final rounded = value.toInt();
    return value == rounded ? '$rounded' : '$value';
  }

  String badgeLabel(int fallbackEpisode) {
    final code = readType().toUpperCase();
    final number = displayNumber(fallbackEpisode);
    return code.isEmpty ? number : '$code $number';
  }

  String displayTitle(int fallbackEpisode) {
    final translated = nameCn.trim();
    if (translated.isNotEmpty) return translated;
    final original = name.trim();
    if (original.isNotEmpty) return original;
    return '第 ${displayNumber(fallbackEpisode)} 集';
  }

  String? displaySubtitle(int fallbackEpisode) {
    final original = name.trim();
    if (original.isEmpty || original == displayTitle(fallbackEpisode)) {
      return null;
    }
    return original;
  }
}
