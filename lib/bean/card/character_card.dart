import 'package:flutter/material.dart';
import 'package:kazumi/bean/dialog/adaptive_bottom_sheet.dart';
import 'package:kazumi/modules/characters/character_item.dart';
import 'package:kazumi/pages/info/character_page.dart';

class CharacterCard extends StatelessWidget {
  const CharacterCard({
    super.key,
    required this.characterItem,
  });

  final CharacterItem characterItem;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        backgroundImage: characterItem.avator.grid.isEmpty
            ? NetworkImage('https://bangumi.tv/img/info_only.png')
            : NetworkImage(characterItem.avator.grid),
      ),
      title: Text(
        characterItem.name,
        overflow: TextOverflow.ellipsis,
        maxLines: 1,
      ),
      subtitle: characterItem.actorList.isNotEmpty
          ? Text(characterItem.actorList[0].name)
          : null,
      trailing: Text(characterItem.relation),
      onTap: () {
        showAdaptiveBottomSheet<void>(
          context: context,
          builder: (context) {
            return CharacterPage(characterID: characterItem.id);
          },
        );
      },
    );
  }
}
