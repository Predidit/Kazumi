import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:kazumi/bean/widget/collect_button.dart';
import 'package:kazumi/utils/constants.dart';
import 'package:kazumi/modules/bangumi/bangumi_item.dart';
import 'package:kazumi/bean/card/network_img_layer.dart';

// 视频卡片 - 水平布局
class BangumiInfoCardV extends StatefulWidget {
  const BangumiInfoCardV({super.key, required this.bangumiItem});

  final BangumiItem bangumiItem;

  @override
  State<BangumiInfoCardV> createState() => _BangumiInfoCardVState();
}

class _BangumiInfoCardVState extends State<BangumiInfoCardV> {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 350,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.bangumiItem.nameCn == ''
                ? widget.bangumiItem.name
                : (widget.bangumiItem.nameCn),
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          SizedBox(height: 16),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Flexible(
                  child: ClipRRect(
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
                        return Hero(
                          transitionOnUserGestures: true,
                          tag: widget.bangumiItem.id,
                          child: Stack(
                            children: [
                              NetworkImgLayer(
                                src: widget.bangumiItem.images['large'] ?? '',
                                width: maxWidth,
                                height: maxHeight,
                                fadeInDuration: const Duration(milliseconds: 0),
                                fadeOutDuration:
                                    const Duration(milliseconds: 0),
                              ),
                            ],
                          ),
                        );
                      }),
                    ),
                  ),
                ),
                SizedBox(width: 16),
                Flexible(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '放送开始:',
                          ),
                          Text(
                            widget.bangumiItem.airDate,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            '${widget.bangumiItem.votes} 人评分:',
                          ),
                          Row(
                            children: [
                              Text(
                                '${widget.bangumiItem.ratingScore}',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                              const SizedBox(width: 8),
                              RatingBarIndicator(
                                itemCount: 5,
                                rating:
                                    widget.bangumiItem.ratingScore.toDouble() /
                                        2,
                                itemBuilder: (context, index) => Icon(
                                  Icons.star_rounded,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                                itemSize: 20.0,
                              ),
                            ],
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Bangumi Ranked:',
                          ),
                          Text(
                            '#${widget.bangumiItem.rank}',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(
                        width: 120,
                        height: 40,
                        child: CollectButton.extend(
                          bangumiItem: widget.bangumiItem,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
