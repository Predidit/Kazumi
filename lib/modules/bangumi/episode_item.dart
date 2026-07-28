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

  /// Bangumi 集数类型 -> 缩写。
  /// https://bangumi.github.io/api/#/Schema/getting-started
  static const Map<int, String> typeAbbreviations = {
    0: 'ep',
    1: 'sp',
    2: 'op',
    3: 'ed',
    4: 'pv',
    5: 'cm',
    6: 'mad',
  };

  /// 集数类型 -> 中文分段标题。
  static const Map<int, String> typeSectionTitles = {
    0: '本篇',
    1: '特别篇',
    2: '片头曲',
    3: '片尾曲',
    4: 'PV/CM',
    5: '广告',
    6: 'MAD',
  };

  static const String otherAbbreviation = 'other';
  static const String otherSectionTitle = '其它';

  String readType() {
    return typeAbbreviations[type] ?? otherAbbreviation;
  }

  /// 按 type 查询分段标题，用于 sheet 分组。
  static String sectionTitleForType(int type) {
    return typeSectionTitles[type] ?? otherSectionTitle;
  }

  /// 渲染单集编号前缀，例如 `EP1`、`SP2`、`OP`、`ED`。
  /// - 本篇/特别篇：有 sort 显示 `EP1`/`SP2`，无 sort 显示 `EP`/`SP`
  /// - OP/ED/PV/CM/MAD：通常没有 sort，直接显示缩写
  /// - 其它：用 `#N` 形式（N 为 type 值）避免畸形标签
  String prefix() {
    final typeStr = readType().toUpperCase();
    final isOther = typeStr == otherAbbreviation.toUpperCase();
    // 已知类型且有 sort：显示前缀+编号
    if (!isOther && episode > 0) {
      final sortStr = episode == episode.toInt()
          ? episode.toInt().toString()
          : episode.toString();
      return '$typeStr$sortStr';
    }
    // 已知类型但无 sort：仅显示前缀
    if (!isOther) {
      return typeStr;
    }
    // 未知类型：用 #type 编号标识，不显示空前缀
    return '#$type';
  }

  /// 优先用中文名，回退到日文名。
  String displayName() {
    final cn = nameCn.trim();
    if (cn.isNotEmpty) return cn;
    return name.trim();
  }
}
