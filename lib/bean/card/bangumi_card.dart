import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/bean/card/network_img_layer.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/modules/bangumi/bangumi_item.dart';

// 视频卡片 - 垂直布局
class BangumiCardV extends StatefulWidget {
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
  State<BangumiCardV> createState() => _BangumiCardVState();
}

class _BangumiCardVState extends State<BangumiCardV> {

  Timer? _imageResizeTimer;
  String? _imageUrl;
  late Size _imageSize;
  late Size _targetImageSize;

  Size _resolveImageSize(String imageUrl, Size targetSize) {
    if (_imageUrl != imageUrl) {
      _imageResizeTimer?.cancel();
      _imageUrl = imageUrl;
      _imageSize = targetSize;
      _targetImageSize = targetSize;
    } else if (_targetImageSize != targetSize) {
      _imageResizeTimer?.cancel();
      _targetImageSize = targetSize;
      if (_imageSize != targetSize) {
        _imageResizeTimer = Timer(const Duration(milliseconds: 200), () {
          setState(() => _imageSize = targetSize);
        });
      }
    }
    return _imageSize;
  }

  @override
  void dispose() {
    _imageResizeTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bangumiItem = widget.bangumiItem;
    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      child: GestureDetector(
        child: InkWell(
          onTap: () {
            if (!widget.canTap) {
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
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final imageUrl = bangumiItem.images['large'] ?? '';
                    // AspectRatio keeps the image laid out at the current size.
                    final imageSize =
                    _resolveImageSize(imageUrl, constraints.biggest);
                    final image = NetworkImgLayer(
                      src: imageUrl,
                      width: imageSize.width,
                      height: imageSize.height,
                    );
                    return widget.enableHero
                        ? Hero(
                      transitionOnUserGestures: true,
                      flightShuttleBuilder:
                      NetworkImgLayer.heroFlightShuttleBuilder,
                      tag: bangumiItem.id,
                      child: image,
                    )
                        : image;
                  },
                ),
              ),
              BangumiContent(bangumiItem: bangumiItem),
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
