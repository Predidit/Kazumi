class ActorAvator {
  final String small;
  final String medium;
  final String grid;
  final String large;

  ActorAvator({
    required this.small,
    required this.medium,
    required this.grid,
    required this.large,
  });

  factory ActorAvator.fromJson(Map<String, dynamic> json) {
    return ActorAvator(
      small: json['small'] ?? '',
      medium: json['medium'] ?? '',
      grid: json['grid'] ?? '',
      large: json['large'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'small': small,
      'medium': medium,
      'grid': grid,
      'large': large,
    };
  }
}

class ActorItem {
  final int id;
  final int type;
  final String name;
  final ActorAvator avator;

  ActorItem({
    required this.id,
    required this.type,
    required this.name,
    required this.avator,
  });

  factory ActorItem.fromJson(Map<String, dynamic> json) {
    return ActorItem(
      id: json['id'] ?? 0,
      type: json['type'] ?? 0,
      name: json['name'] ?? '',
      avator: ActorAvator.fromJson(json['images'] as Map<String, dynamic>),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'name': name,
      'images': avator.toJson(),
    };
  }
}
