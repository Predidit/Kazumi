import 'package:kazumi/modules/staff/staff_item.dart';

class StaffResponse {
  final List<StaffFullItem> data;

  StaffResponse({
    required this.data,
  });

  /// Parses `GET /v0/subjects/{id}/persons`, which returns a flat
  /// (person × relation) list, so entries are merged by person id.
  factory StaffResponse.fromJson(List list) {
    final Map<int, Staff> staffById = {};
    final Map<int, List<String>> relationsById = {};
    for (final item in list) {
      final json = item as Map<String, dynamic>;
      final staff = Staff.fromJson(json);
      staffById.putIfAbsent(staff.id, () => staff);
      relationsById
          .putIfAbsent(staff.id, () => [])
          .add(json['relation'] as String? ?? '');
    }

    final data = staffById.entries.map((entry) {
      final relations = relationsById[entry.key]!
        ..sort((a, b) => _priorityOf(a).compareTo(_priorityOf(b)));
      return StaffFullItem(staff: entry.value, relations: relations);
    }).toList()
      ..sort((a, b) => _priorityOf(a.relations.first)
          .compareTo(_priorityOf(b.relations.first)));

    return StaffResponse(data: data);
  }

  static int _priorityOf(String relation) {
    final index = _staffRelationPriority.indexOf(relation);
    return index < 0 ? _staffRelationPriority.length : index;
  }

  /// Key roles pinned to the top of the staff list, in this order.
  static const List<String> _staffRelationPriority = [
    '动画制作',
    '原作',
    '总导演',
    '导演',
    '系列构成',
    '脚本',
    '人物设定',
    '总作画监督',
    '作画监督',
    '美术监督',
    '色彩设计',
    '音乐',
    '音响监督',
    '摄影监督',
  ];
}
