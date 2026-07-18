import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/bean/card/network_img_layer.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/modules/bangumi/bangumi_item.dart';
import 'package:kazumi/utils/device.dart';
import 'package:kazumi/design_system/kazumi_surfaces.dart';

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
    final title =
        bangumiItem.nameCn.isNotEmpty ? bangumiItem.nameCn : bangumiItem.name;
    return KazumiInteractiveSurface(
      semanticLabel: title,
      onTap: () {
        if (!canTap) {
          KazumiDialog.showToast(message: '编辑模式');
          return;
        }
        context.pushNamed('/info/', arguments: bangumiItem);
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
                      flightShuttleBuilder:
                          NetworkImgLayer.heroFlightShuttleBuilder,
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
          BangumiContent(bangumiItem: bangumiItem),
        ],
      ),
    );
  }
}

class BangumiContent extends StatelessWidget {
  const BangumiContent({super.key, required this.bangumiItem});

  final BangumiItem bangumiItem;

  @override
  Widget build(BuildContext context) {
    final title =
        bangumiItem.nameCn.isNotEmpty ? bangumiItem.nameCn : bangumiItem.name;
    final int maxTextLines = isDesktop()
        ? 3
        : (isTablet() &&
                MediaQuery.of(context).orientation == Orientation.landscape)
            ? 3
            : 2;

    return Expanded(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(5, 3, 5, 1),
        child: Text(
          title,
          textAlign: TextAlign.start,
          style: const TextStyle(
            fontWeight: FontWeight.w500,
            letterSpacing: 0.3,
          ),
          maxLines: maxTextLines,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}
