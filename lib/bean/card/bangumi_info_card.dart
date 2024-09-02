import 'package:flutter/material.dart';
import 'package:kazumi/utils/constans.dart';
import 'package:kazumi/utils/utils.dart';
import 'package:kazumi/modules/bangumi/bangumi_item.dart';
import 'package:kazumi/bean/card/network_img_layer.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/pages/favorite/favorite_controller.dart';

// 视频卡片 - 水平布局
class BangumiInfoCardV extends StatefulWidget {
  const BangumiInfoCardV({super.key, required this.bangumiItem});

  final BangumiItem bangumiItem;

  @override
  State<BangumiInfoCardV> createState() => _BangumiInfoCardVState();
}

class _BangumiInfoCardVState extends State<BangumiInfoCardV> {
  late bool isFavorite;

  @override
  Widget build(BuildContext context) {
    TextStyle style =
        TextStyle(fontSize: Theme.of(context).textTheme.labelMedium!.fontSize);
    String heroTag = Utils.makeHeroTag(widget.bangumiItem.id);
    // final PlayerController playerController = Modular.get<PlayerController>();
    final FavoriteController favoriteController =
        Modular.get<FavoriteController>();
    isFavorite = favoriteController.isFavorite(widget.bangumiItem);
    return SizedBox(
      height: 300,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
            StyleString.safeSpace, 7, StyleString.safeSpace, 7),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: StyleString.imgRadius,
                topRight: StyleString.imgRadius,
                bottomLeft: StyleString.imgRadius,
                bottomRight: StyleString.imgRadius,
              ),
              child: AspectRatio(
                aspectRatio: 0.65,
                child: LayoutBuilder(builder: (context, boxConstraints) {
                  final double maxWidth = boxConstraints.maxWidth;
                  final double maxHeight = boxConstraints.maxHeight;
                  return Stack(
                    children: [
                      Hero(
                        tag: heroTag,
                        child: NetworkImgLayer(
                          src: widget.bangumiItem.images['large'] ?? '',
                          width: maxWidth,
                          height: maxHeight,
                          fadeInDuration: const Duration(milliseconds: 0),
                          fadeOutDuration: const Duration(milliseconds: 0),
                        ),
                      ),
                    ],
                  );
                }),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  RichText(
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    text: TextSpan(
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface),
                      children: [
                        TextSpan(
                          text: widget.bangumiItem.nameCn == ''
                              ? widget.bangumiItem.name
                              : (widget.bangumiItem.nameCn),
                          style: TextStyle(
                            fontSize: MediaQuery.textScalerOf(context).scale(
                                Theme.of(context)
                                    .textTheme
                                    .titleSmall!
                                    .fontSize!),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  // 测试 因为API问题评分功能搁置
                  Text('排名: ${widget.bangumiItem.rank}', style: style),
                  Row(
                    children: [
                      Text(widget.bangumiItem.type == 2 ? '番剧' : '其他',
                          style: style),
                      const SizedBox(width: 3),
                      const Text(' '),
                      const SizedBox(width: 3),
                      Text(widget.bangumiItem.airDate, style: style),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Container(
                      height: 140,
                      child: Text(widget.bangumiItem.summary,
                          style: style, softWrap: true)),
                  const SizedBox(height: 18),
                  SizedBox(
                    height: 32,
                    child: IconButton(
                      icon: Icon(
                          isFavorite ? Icons.favorite : Icons.favorite_outline),
                      onPressed: () async {
                        if (isFavorite) {
                          favoriteController.deleteFavorite(widget.bangumiItem);
                        } else {
                          favoriteController.addFavorite(widget.bangumiItem);
                        }
                        setState(() {
                          isFavorite = !isFavorite;
                        });
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
