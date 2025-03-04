import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/bean/card/network_img_layer.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/modules/bangumi/bangumi_item.dart';
import 'package:kazumi/pages/info/info_controller.dart';
import 'package:kazumi/utils/constants.dart';
import 'package:kazumi/utils/utils.dart';

// 视频卡片 - 垂直布局
class BangumiCardV extends StatelessWidget {
  const BangumiCardV({
    super.key,
    required this.bangumiItem,
    this.canTap = true,
    this.longPress,
    this.longPressEnd,
  });

  final BangumiItem bangumiItem;
  final bool canTap;
  final Function()? longPress;
  final Function()? longPressEnd;

  @override
  Widget build(BuildContext context) {
    final InfoController infoController = Modular.get<InfoController>();
    return Card(
      elevation: 0,
      clipBehavior: Clip.hardEdge,
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
            infoController.bangumiItem = bangumiItem;
            Modular.to.pushNamed('/info/');
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
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
                    return Hero(
                      transitionOnUserGestures: true,
                      tag: bangumiItem.id,
                      child: NetworkImgLayer(
                        src: bangumiItem.images['large'] ?? '',
                        width: maxWidth,
                        height: maxHeight,
                      ),
                    );
                  }),
                ),
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
          maxLines: Utils.isDesktop() || Utils.isTablet() ? 3 : 2,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}
