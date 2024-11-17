import 'package:kazumi/modules/characters/character_item.dart';

class CharacterResponse {
  final List<CharacterItem> characterList;

  CharacterResponse({
    required this.characterList,
  });

  factory CharacterResponse.fromJson(List list) {
    List<CharacterItem> resCharacterList =
        list.map((i) => CharacterItem.fromJson(i)).toList();
    return CharacterResponse(
      characterList: resCharacterList,
    );
  }

  factory CharacterResponse.fromTemplate() {
    return CharacterResponse(
      characterList: [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'characterList': characterList.map((e) => e.toJson()).toList(),
    };
  }
}
