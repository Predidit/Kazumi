import 'package:kazumi/modules/staff/staff_item.dart';

class StaffResponse {
  final List<StaffFullItem> data;
  final int total;

  StaffResponse({
    required this.data,
    required this.total,
  });

  factory StaffResponse.fromJson(Map<String, dynamic> json) {
    return StaffResponse(
      data: (json['data'] as List<dynamic>? ?? [])
          .map((item) => StaffFullItem.fromJson(item as Map<String, dynamic>))
          .toList(),
      total: json['total'] is int ? json['total'] as int : 0,
    );
  }

  factory StaffResponse.fromTemplate() {
    return StaffResponse(
      data: [],
      total: 0,
    );
  }

  /// 解析 api.bgm.tv `/v0/subjects/{id}/persons` 的完整返回。
  ///
  /// v0 接口按 (人物 × 关系) 返回扁平数组,这里按人物 ID 合并为
  /// [StaffFullItem],并按 [_staffRelationPriority] 把重要职位
  /// (动画制作、原作、导演、脚本等)前置,未收录的职位保持 v0
  /// 原始顺序排在后面;每个条目内的职位也按同一优先级排列,
  /// 保证行首职位与排序依据一致。
  factory StaffResponse.fromV0Persons(List<dynamic> persons) {
    final positionsById = <int, List<Position>>{};
    final staffById = <int, Staff>{};
    for (final raw in persons) {
      final json = raw as Map<String, dynamic>;
      final id = json['id'] as int? ?? 0;
      positionsById.putIfAbsent(id, () => []).add(_positionFrom(json));
      staffById.putIfAbsent(id, () => Staff.fromJson(json));
    }

    final items = <({StaffFullItem item, int priority})>[];
    for (final entry in staffById.entries) {
      final positions = _sortedByPriority(positionsById[entry.key]!);
      items.add((
        item: StaffFullItem(staff: entry.value, positions: positions),
        priority: _relationPriority(positions.first.type.cn),
      ));
    }
    return StaffResponse(
      data: _stableSortedBy(items, (a, b) => a.priority.compareTo(b.priority))
          .map((e) => e.item)
          .toList(),
      total: items.length,
    );
  }

  /// v0 人物行 → [Position],职位名取自 `relation`。
  static Position _positionFrom(Map<String, dynamic> json) {
    return Position(
      type: PositionType(
        id: 0,
        en: '',
        cn: json['relation'] as String? ?? '',
        jp: '',
      ),
      summary: '',
      appearEps: json['eps'] as String? ?? '',
    );
  }

  /// 职位名 → 优先级,越小越靠前;未收录的职位返回最大值,排在最后。
  static int _relationPriority(String cn) =>
      _staffRelationPriority[cn] ?? 0x7fffffff;

  /// 职位按优先级稳定排序(同优先级保持原顺序)。
  static List<Position> _sortedByPriority(List<Position> positions) {
    return _stableSortedBy(
      positions,
      (a, b) =>
          _relationPriority(a.type.cn).compareTo(_relationPriority(b.type.cn)),
    );
  }

  /// Dart 的 [List.sort] 不稳定,这里用原序号兜底实现稳定排序。
  static List<T> _stableSortedBy<T>(
      List<T> list, int Function(T, T) compare) {
    final indexed = list.asMap().entries.toList()
      ..sort((a, b) {
        final byCompare = compare(a.value, b.value);
        return byCompare != 0 ? byCompare : a.key.compareTo(b.key);
      });
    return [for (final entry in indexed) entry.value];
  }

  /// 职位 → 排序优先级,越小越靠前;未收录的职位为普通级别。
  static const Map<String, int> _staffRelationPriority = {
    '动画制作': 0,
    '原作': 10,
    '总导演': 20,
    '导演': 30,
    '系列构成': 40,
    '脚本': 50,
    '人物设定': 60,
    '总作画监督': 70,
    '作画监督': 80,
    '美术监督': 90,
    '色彩设计': 100,
    '音乐': 110,
    '音响监督': 120,
    '摄影监督': 130,
  };

  Map<String, dynamic> toJson() {
    return {
      'data': data.map((item) => item.toJson()).toList(),
      'total': total,
    };
  }
}
