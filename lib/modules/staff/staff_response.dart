import 'package:kazumi/modules/staff/staff_item.dart';

class StaffResponse {
  final List<StaffFullItem> data;
  final int total;

  StaffResponse({
    required this.data,
    required this.total,
  });

  /// Parses the full response of `GET /v0/subjects/{id}/persons`.
  ///
  /// The v0 API returns a flat (person × relation) list, so entries are
  /// merged by person id and prioritized roles are sorted to the front
  /// via [_staffRelationPriority].
  factory StaffResponse.fromJson(List<dynamic> persons) {
    final positionsById = <int, List<Position>>{};
    final staffById = <int, Staff>{};
    for (final raw in persons) {
      try {
        final json = raw as Map<String, dynamic>;
        final id = int.tryParse('${json['id']}');
        if (id == null) continue;
        positionsById.putIfAbsent(id, () => []).add(_positionFrom(json));
        staffById.putIfAbsent(id, () => Staff.fromJson(json));
      } catch (_) {
        // Skip malformed entries instead of failing the whole list.
      }
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

  factory StaffResponse.fromTemplate() {
    return StaffResponse(
      data: [],
      total: 0,
    );
  }

  static Position _positionFrom(Map<String, dynamic> json) {
    return Position(
      type: PositionType(
        id: 0,
        en: '',
        cn: json['relation'] as String? ?? '',
        jp: '',
      ),
      summary: '',
      appearEps: json['eps']?.toString() ?? '',
    );
  }

  static int _relationPriority(String cn) =>
      _staffRelationPriority[cn] ?? 0x7fffffff;

  static List<Position> _sortedByPriority(List<Position> positions) {
    return _stableSortedBy(
      positions,
      (a, b) =>
          _relationPriority(a.type.cn).compareTo(_relationPriority(b.type.cn)),
    );
  }

  // [List.sort] is not stable, so keep the original index as a tie-breaker.
  static List<T> _stableSortedBy<T>(List<T> list, int Function(T, T) compare) {
    final indexed = list.asMap().entries.toList()
      ..sort((a, b) {
        final byCompare = compare(a.value, b.value);
        return byCompare != 0 ? byCompare : a.key.compareTo(b.key);
      });
    return [for (final entry in indexed) entry.value];
  }

  // Lower value sorts first; unlisted roles keep their original order.
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
