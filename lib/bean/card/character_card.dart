import 'package:flutter/material.dart';
import 'package:kazumi/modules/characters/character_item.dart';
import 'package:kazumi/request/bangumi.dart';

import '../../utils/utils.dart';

class CharacterCard extends StatefulWidget {
  const CharacterCard({
    super.key,
    required this.characterItem,
  });

  final CharacterItem characterItem;

  @override
  State<CharacterCard> createState() => _CharacterCard();
}

class _CharacterCard extends State<CharacterCard> {

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
                  backgroundImage: NetworkImage(widget.characterItem.avator.grid),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.characterItem.name),
                    SizedBox(
                        width: (Utils.isTablet() || Utils.isDesktop()) ? 300 : 150,
                        child: Text(
                            widget.characterItem.actorList.isEmpty
                                ? ''
                                : widget.characterItem.actorList.map((actor) => actor.name).join(' / '),
                            overflow: TextOverflow.ellipsis
                        )
                    )
                  ],
                ),
                const Expanded(child: SizedBox(height: 10)),
                Text(widget.characterItem.readType())
              ],
            ),
          ],
        ),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    (widget.characterItem.info.nameCn.isNotEmpty)
                        ? Text('中文名：${widget.characterItem.info.nameCn}')
                        : Container(),
                    (widget.characterItem.info.summary.isNotEmpty)
                        ? Text('简介：\n${widget.characterItem.info.summary}')
                        : const Text('加载中...')
                  ],
                )
            ),
          ),
        ],
        onExpansionChanged: (value) async {
          if (value == false || widget.characterItem.info.summary.isNotEmpty) {
            return;
          }
          widget.characterItem.info = await BangumiHTTP.getCharactersExtraInfo(widget.characterItem);
          if (widget.characterItem.info.summary.isEmpty) {
            widget.characterItem.info.summary = '无';
          }
          setState(() {});
        },
      ),
    );
  }
}
