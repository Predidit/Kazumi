class StaffFullItem {
  final Staff staff;
  final List<Position> positions;

  StaffFullItem({
    required this.staff,
    required this.positions,
  });

  factory StaffFullItem.fromJson(Map<String, dynamic> json) {
    return StaffFullItem(
      staff: json['staff'] != null
          ? Staff.fromJson(json['staff'] as Map<String, dynamic>)
          : Staff.fromTemplate(),
      positions: (json['positions'] as List<dynamic>? ?? [])
          .map((item) => Position.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'staff': staff.toJson(),
      'positions': positions.map((item) => item.toJson()).toList(),
    };
  }
}

class Staff {
  final int id;
  final String name;
  final String nameCN;
  final int type;
  final String info;
  final int comment;
  final bool lock;
  final bool nsfw;
  final Images? images;

  Staff({
    required this.id,
    required this.name,
    required this.nameCN,
    required this.type,
    required this.info,
    required this.comment,
    required this.lock,
    required this.nsfw,
    this.images,
  });

  factory Staff.fromJson(Map<String, dynamic> json) {
    return Staff(
      id: json['id'] is int ? json['id'] as int : 0,
      name: json['name'] as String? ?? '',
      nameCN: json['nameCN'] as String? ?? '',
      type: json['type'] is int ? json['type'] as int : 0,
      info: json['info'] as String? ?? '',
      comment: json['comment'] is int ? json['comment'] as int : 0,
      lock: json['lock'] as bool? ?? false,
      nsfw: json['nsfw'] as bool? ?? false,
      images: json['images'] != null
          ? Images.fromJson(json['images'] as Map<String, dynamic>)
          : null,
    );
  }

  factory Staff.fromTemplate() {
    return Staff(
      id: 0,
      name: '',
      nameCN: '',
      type: 0,
      info: '',
      comment: 0,
      lock: false,
      nsfw: false,
      images: null,
    );
  }

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{
      'id': id,
      'name': name,
      'nameCN': nameCN,
      'type': type,
      'info': info,
      'comment': comment,
      'lock': lock,
      'nsfw': nsfw,
    };
    if (images != null) {
      data['images'] = images!.toJson();
    }
    return data;
  }
}

class Images {
  final String large;
  final String medium;
  final String small;
  final String grid;

  Images({
    required this.large,
    required this.medium,
    required this.small,
    required this.grid,
  });

  factory Images.fromJson(Map<String, dynamic> json) {
    return Images(
      large: json['large'] as String? ?? '',
      medium: json['medium'] as String? ?? '',
      small: json['small'] as String? ?? '',
      grid: json['grid'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'large': large,
      'medium': medium,
      'small': small,
      'grid': grid,
    };
  }
}

class Position {
  final PositionType type;
  final String summary;
  final String appearEps;

  Position({
    required this.type,
    required this.summary,
    required this.appearEps,
  });

  factory Position.fromJson(Map<String, dynamic> json) {
    return Position(
      type: json['type'] != null
          ? PositionType.fromJson(json['type'] as Map<String, dynamic>)
          : PositionType.fromTemplate(),
      summary: json['summary'] as String? ?? '',
      appearEps: json['appearEps'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type.toJson(),
      'summary': summary,
      'appearEps': appearEps,
    };
  }
}

class PositionType {
  final int id;
  final String en;
  final String cn;
  final String jp;

  PositionType({
    required this.id,
    required this.en,
    required this.cn,
    required this.jp,
  });

  factory PositionType.fromJson(Map<String, dynamic> json) {
    return PositionType(
      id: json['id'] is int ? json['id'] as int : 0,
      en: json['en'] as String? ?? '',
      cn: json['cn'] as String? ?? '',
      jp: json['jp'] as String? ?? '',
    );
  }

  factory PositionType.fromTemplate() {
    return PositionType(
      id: 0,
      en: '',
      cn: '',
      jp: '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'en': en,
      'cn': cn,
      'jp': jp,
    };
  }
}