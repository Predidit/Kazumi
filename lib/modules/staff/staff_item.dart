class StaffFullItem {
  final Staff staff;
  final List<String> relations;

  StaffFullItem({
    required this.staff,
    required this.relations,
  });
}

class Staff {
  final int id;
  final String name;
  final String nameCN;
  final Images? images;

  Staff({
    required this.id,
    required this.name,
    required this.nameCN,
    this.images,
  });

  factory Staff.fromJson(Map<String, dynamic> json) {
    return Staff(
      id: json['id'] is int ? json['id'] as int : 0,
      name: json['name'] as String? ?? '',
      nameCN: json['nameCN'] as String? ?? '',
      images: json['images'] != null
          ? Images.fromJson(json['images'] as Map<String, dynamic>)
          : null,
    );
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
}
