import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/bean/card/network_img_layer.dart';
import 'package:kazumi/modules/bangumi/bangumi_item.dart';

// 视频卡片 - 垂直布局
class BangumiCardV extends StatelessWidget {
  const BangumiCardV({super.key, required this.bangumiItem});

  final BangumiItem bangumiItem;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: () => context.pushNamed('/info/', arguments: bangumiItem),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(
              aspectRatio: 0.65,
              child: LayoutBuilder(
                builder: (context, constraints) => Hero(
                  transitionOnUserGestures: true,
                  flightShuttleBuilder: NetworkImgLayer.heroFlightShuttleBuilder,
                  tag: bangumiItem.id,
                  child: NetworkImgLayer(
                    src: bangumiItem.images['large'] ?? '',
                    width: constraints.maxWidth,
                    height: constraints.maxHeight,
                  ),
                ),
              ),
            ),
            BangumiContent(bangumiItem: bangumiItem),
          ],
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
        padding: const EdgeInsets.fromLTRB(5, 3, 5, 1),
        child: LayoutBuilder(builder: (context, constraints) {
          final style = DefaultTextStyle.of(context).style.copyWith(
            fontWeight: FontWeight.w500,
            letterSpacing: 0.3,
          );
          final textScaler = ts.clamp(maxScaleFactor: 1.1);
          final painter = TextPainter(
            text: TextSpan(text: bangumiItem.nameCn, style: style),
            textDirection: Directionality.of(context),
            textScaler: textScaler,
          );
          final lines = (constraints.maxHeight / painter.preferredLineHeight)
              .floor()
              .clamp(1, 3);
          painter.dispose();
          return Text(
            bangumiItem.nameCn,
            textAlign: TextAlign.start,
            style: style,
            textScaler: textScaler,
            maxLines: lines,
            overflow: TextOverflow.ellipsis,
          );
        }),
      ),
    );
  }
}
