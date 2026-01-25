import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/bean/card/network_img_layer.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/modules/bangumi/bangumi_item.dart';
import 'package:kazumi/utils/utils.dart';

// 视频卡片 - 垂直布局
class BangumiCardV extends StatelessWidget {
  const BangumiCardV({
    super.key,
    required this.bangumiItem,
    this.canTap = true,
    this.enableHero = true,
  });

  final BangumiItem bangumiItem;
  final bool canTap;
  final bool enableHero;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      child: GestureDetector(
        child: InkWell(
          onTap: () {
            if (!canTap) {
              KazumiDialog.showToast(
                message: '编辑模式',
              );
              return;
            }
            Modular.to.pushNamed('/info/', arguments: bangumiItem);
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AspectRatio(
                aspectRatio: 0.65,
                child: LayoutBuilder(builder: (context, boxConstraints) {
                  final double maxWidth = boxConstraints.maxWidth;
                  final double maxHeight = boxConstraints.maxHeight;
                  return enableHero
                      ? Hero(
                          transitionOnUserGestures: true,
                          tag: bangumiItem.id,
                          child: NetworkImgLayer(
                            src: bangumiItem.images['large'] ?? '',
                            width: maxWidth,
                            height: maxHeight,
                          ),
                        )
                      : NetworkImgLayer(
                          src: bangumiItem.images['large'] ?? '',
                          width: maxWidth,
                          height: maxHeight,
                        );
                }),
              ),
              BangumiContent(bangumiItem: bangumiItem)
            ],
          ),
        ),
      ),
    );
  }
}

class BangumiContent extends StatelessWidget {
  const BangumiContent({super.key, required this.bangumiItem});

  final BangumiItem bangumiItem;

  @override
  Widget build(BuildContext context) {
    final ts = MediaQuery.textScalerOf(context);

    final int maxTextLines = Utils.isDesktop() ? 3 
      : (Utils.isTablet() && MediaQuery.of(context).orientation == Orientation.landscape) ? 3 : 2;

    return Expanded(
      child: Padding(
        // 多列
        padding: const EdgeInsets.fromLTRB(5, 3, 5, 1),
        // 单列
        // padding: const EdgeInsets.fromLTRB(14, 10, 4, 8),
        child: Text(
          bangumiItem.nameCn,
          textAlign: TextAlign.start,
          style: const TextStyle(
            fontWeight: FontWeight.w500,
            letterSpacing: 0.3,
          ),
          textScaler: ts.clamp(maxScaleFactor: 1.1),
          maxLines: maxTextLines,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}
