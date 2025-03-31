import 'package:kazumi/utils/utils.dart';
import 'package:flutter/material.dart';
import 'package:kazumi/modules/characters/character_item.dart';
import 'package:kazumi/pages/info/character_page.dart';

class CharacterCard extends StatelessWidget {
  CharacterCard({
    super.key,
    required this.characterItem,
  }) {
    isPreview = false;
  }

  CharacterCard.preview({
    super.key,
    required this.characterItem,
  }) {
    isPreview = true;
  }

  final CharacterItem characterItem;
  late final bool isPreview;

  Widget buildFullCharacters(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        backgroundImage: NetworkImage(characterItem.avator.grid),
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
        showModalBottomSheet(
            barrierColor: Colors.transparent,
            isScrollControlled: true,
            constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 3 / 4,
                maxWidth: (Utils.isDesktop() || Utils.isTablet())
                    ? MediaQuery.of(context).size.width * 9 / 16
                    : MediaQuery.of(context).size.width),
            clipBehavior: Clip.antiAlias,
            context: context,
            builder: (context) {
              return CharacterPage(characterID: characterItem.id);
            });
      },
    );
  }

  Widget buildPreviewCharacters(BuildContext context) {
    return Column(children: []);
  }

  @override
  Widget build(BuildContext context) {
    if (isPreview) {
      return buildPreviewCharacters(context);
    }
    return buildFullCharacters(context);
  }
}
