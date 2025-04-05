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

  Map<String, dynamic> toJson() {
    return {
      'data': data.map((item) => item.toJson()).toList(),
      'total': total,
    };
  }
}
