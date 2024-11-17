import 'package:flutter/material.dart';
import 'package:kazumi/modules/characters/character_item.dart';

class CharacterCard extends StatelessWidget {
  const CharacterCard({
    super.key,
    required this.characterItem,
  });

  final CharacterItem characterItem;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8.0, 8.0, 16.0, 8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundImage: NetworkImage(characterItem.avator.large),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(characterItem.name),
                    Text(characterItem.actorList.isEmpty
                        ? ''
                        : characterItem.actorList[0].name),
                  ],
                ),
                const Expanded(child: SizedBox(height: 10)),
                Text(characterItem.relation)
              ],
            ),
          ],
        ),
      ),
    );
  }
}
