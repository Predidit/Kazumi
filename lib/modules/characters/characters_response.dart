import 'package:kazumi/request/api.dart';
import 'package:kazumi/modules/characters/character_item.dart';

/// The response from [Api.bangumiInfoByID]
/// It contains a list of [CharacterItem]
/// It is used to show general information about seraval bangumi characters
class CharactersResponse {
  final List<CharacterItem> charactersList;

  CharactersResponse({
    required this.charactersList,
  });

  factory CharactersResponse.fromJson(List list) {
    List<CharacterItem> resCharactersList =
        list.map((i) => CharacterItem.fromJson(i)).toList();
    return CharactersResponse(
      charactersList: resCharactersList,
    );
  }

  factory CharactersResponse.fromTemplate() {
    return CharactersResponse(
      charactersList: [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'charactersList': charactersList.map((e) => e.toJson()).toList(),
    };
  }
}
