import 'package:kazumi/modules/characters/actor_item.dart';

class CharacterAvator {
  final String small;
  final String medium;
  final String grid;
  final String large;

  CharacterAvator({
    required this.small,
    required this.medium,
    required this.grid,
    required this.large,
  });

  factory CharacterAvator.fromJson(Map<String, dynamic> json) {
    return CharacterAvator(
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

class CharacterItem {
  final int id;
  final int type;
  final String name;
  final String relation;
  final CharacterAvator avator;
  final List<ActorItem> actorList;

  CharacterItem({
    required this.id,
    required this.type,
    required this.name,
    required this.relation,
    required this.avator,
    required this.actorList,
  });

  factory CharacterItem.fromJson(Map<String, dynamic> json) {
    var list = json['actors'] as List;
    List<ActorItem> resActorList =
        list.map((i) => ActorItem.fromJson(i)).toList();
    return CharacterItem(
      id: json['id'] ?? 0,
      type: json['type'] ?? 0,
      name: json['name'] ?? '',
      relation: json['relation'] ?? '未知',
      avator: CharacterAvator.fromJson(json['images'] as Map<String, dynamic>),
      actorList: resActorList,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'name': name,
      'relation': relation,
      'images': avator.toJson(),
      'actors': actorList.map((e) => e.toJson()).toList(),
    };
  }
}