import 'package:flutter/material.dart';
import 'package:kazumi/bean/widget/collect_button.dart';
import 'package:kazumi/utils/constants.dart';
import 'package:kazumi/utils/utils.dart';
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
    TextStyle style =
        TextStyle(fontSize: Theme.of(context).textTheme.bodyMedium!.fontSize);
    String heroTag = Utils.makeHeroTag(widget.bangumiItem.id);
    return SizedBox(
      height: Utils.isCompact() ? 240 : 300,
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
                      Positioned(
                          right: 5,
                          bottom: 5,
                          child:
                              CollectButton(bangumiItem: widget.bangumiItem)),
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
                  RichText(
                    maxLines: 4,
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
                                    .titleLarge!
                                    .fontSize!),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Utils.isCompact() ? Container() : const SizedBox(height: 10),
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            FilledButton.tonal(
                              onPressed: () {},
                              style: OutlinedButton.styleFrom(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                side: const BorderSide(
                                    // width: 2,
                                    ),
                                backgroundColor: Colors.transparent,
                              ),
                              child: Text('#${widget.bangumiItem.rank}',
                                  style: style),
                            ),
                            Utils.isCompact()
                                ? Container()
                                : const SizedBox(height: 7),
                            FilledButton.tonal(
                              onPressed: () {},
                              style: OutlinedButton.styleFrom(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                side: const BorderSide(
                                    // width: 2,
                                    ),
                                backgroundColor: Colors.transparent,
                              ),
                              child: Text(widget.bangumiItem.airDate,
                                  style: style),
                            ),
                            Utils.isCompact()
                                ? Container()
                                : const SizedBox(height: 7),
                            Utils.isCompact()
                                ? Container()
                                : FilledButton.tonal(
                                    onPressed: () {},
                                    style: OutlinedButton.styleFrom(
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      side: const BorderSide(
                                          // width: 2,
                                          ),
                                      backgroundColor: Colors.transparent,
                                    ),
                                    child: Text(
                                        widget.bangumiItem.type == 2
                                            ? '番剧'
                                            : '其他',
                                        style: style),
                                  ),
                          ],
                        ),
                        Utils.isCompact()
                            ? Container()
                            : const SizedBox(width: 10),
                        // why there will overflow in the bottom?
                        Utils.isCompact()
                            ? Container()
                            : Expanded(
                                child: SingleChildScrollView(
                                  child: Text(
                                    widget.bangumiItem.summary,
                                    style: style,
                                    softWrap: true,
                                  ),
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
      ),
    );
  }
}
