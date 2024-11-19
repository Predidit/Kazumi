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

class CharacterExtraInfo {
  String nameCn;
  String summary;

  CharacterExtraInfo({required this.nameCn, required this.summary});

  factory CharacterExtraInfo.fromJson(Map<String, dynamic> json) {
    String nameCn = '';
    final String hasNameCn = json['infobox'][0]['key'];
    if (hasNameCn == '简体中文名') {
      nameCn = json['infobox'][0]['value'];
    }
    return CharacterExtraInfo(
      nameCn: nameCn,
      summary: json['summary']
    );
  }
}

class CharacterItem {
  final int id;
  final int type;
  final String name;
  final CharacterAvator avator;
  final List<ActorItem> actorList;
  CharacterExtraInfo info;

  CharacterItem({
    required this.id,
    required this.type,
    required this.name,
    required this.avator,
    required this.actorList,
    required this.info
  });

  factory CharacterItem.fromJson(Map<String, dynamic> json) {
    var list = json['actors'] as List;
    List<ActorItem> resActorList =
        list.map((i) => ActorItem.fromJson(i)).toList();
    var resAvator = CharacterAvator(
        small: 'https://bangumi.tv/img/info_only.png',
        medium: 'https://bangumi.tv/img/info_only.png',
        grid: 'https://bangumi.tv/img/info_only.png',
        large: 'https://bangumi.tv/img/info_only.png');
    if (json['character']['images'] != null) {
      resAvator = CharacterAvator.fromJson(
          json['character']['images'] as Map<String, dynamic>);
    }
    return CharacterItem(
      id: json['character']['id'] ?? 0,
      type: json['type'] ?? 0,
      name: json['character']['name'] ?? '',
      avator: resAvator,
      actorList: resActorList,
      info: CharacterExtraInfo(nameCn: '', summary: '')
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'name': name,
      'images': avator.toJson(),
      'actors': actorList.map((e) => e.toJson()).toList(),
    };
  }

  String readType() {
    switch (type) {
      case 1:
        return '主角';
      case 2:
        return '配角';
      case 3:
        return '客串';
      default:
        return '';
    }
  }
}