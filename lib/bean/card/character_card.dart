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
      child: ExpansionTile(
        shape: const RoundedRectangleBorder(
          side: BorderSide.none, 
          borderRadius: BorderRadius.zero, 
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundImage: NetworkImage(characterItem.avator.grid),
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
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(characterItem.actorList.isEmpty
                  ? ''
                  : characterItem.actorList[0].shortSummary),
            ),
          ),
        ],
      ),
    );
  }
}
