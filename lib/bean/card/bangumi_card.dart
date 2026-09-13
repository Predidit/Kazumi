import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/bean/card/network_img_layer.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/modules/bangumi/bangumi_item.dart';
import 'package:kazumi/utils/device.dart';
import 'package:kazumi/bean/widget/tv_focusable_surface.dart';
import 'package:kazumi/services/platform/tv_mode.dart';

// 视频卡片 - 垂直布局
class BangumiCardV extends StatelessWidget {
  const BangumiCardV({
    super.key,
    required this.bangumiItem,
    this.canTap = true,
    this.enableHero = true,
    this.channelNumber,
    this.highlighted = false,
    this.focusNode,
    this.onPressed,
    this.onKeyEvent,
    this.onFocusChange,
    this.ensureVisibleOnFocus = true,
  });

  final BangumiItem bangumiItem;
  final bool canTap;
  final bool enableHero;
  final int? channelNumber;
  final bool highlighted;
  final FocusNode? focusNode;
  final VoidCallback? onPressed;
  final FocusOnKeyEventCallback? onKeyEvent;
  final ValueChanged<bool>? onFocusChange;
  final bool ensureVisibleOnFocus;

  @override
  Widget build(BuildContext context) {
    void openBangumi() {
      if (!canTap) {
        KazumiDialog.showToast(
          message: '编辑模式',
        );
        return;
      }
      if (onPressed != null) {
        onPressed!();
      } else {
        context.pushNamed('/info/', arguments: bangumiItem);
      }
    }

    final card = Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      child: GestureDetector(
        child: InkWell(
          canRequestFocus: !TvMode.enabled,
          onTap: openBangumi,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AspectRatio(
                aspectRatio: 0.65,
                child: LayoutBuilder(builder: (context, boxConstraints) {
                  final double maxWidth = boxConstraints.maxWidth;
                  final double maxHeight = boxConstraints.maxHeight;
                  final image = NetworkImgLayer(
                    src: bangumiItem.images['large'] ?? '',
                    width: maxWidth,
                    height: maxHeight,
                  );
                  final poster = enableHero
                      ? Hero(
                          transitionOnUserGestures: true,
                          flightShuttleBuilder:
                              NetworkImgLayer.heroFlightShuttleBuilder,
                          tag: bangumiItem.id,
                          child: image,
                        )
                      : image;
                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      poster,
                      if (channelNumber != null)
                        Positioned(
                          left: 8,
                          top: 8,
                          child: _ChannelNumberBadge(number: channelNumber!),
                        ),
                    ],
                  );
                }),
              ),
              BangumiContent(bangumiItem: bangumiItem)
            ],
          ),
        ),
      ),
    );
    final surface = TvFocusableSurface(
      focusScale: channelNumber != null ? 1 : 1.035,
      onPressed: openBangumi,
      onKeyEvent: onKeyEvent,
      onFocusChange: onFocusChange,
      ensureVisibleOnFocus: ensureVisibleOnFocus,
      focusNode: focusNode,
      highlighted: highlighted,
      child: card,
    );
    if (TvMode.enabled && channelNumber != null) {
      return LayoutBuilder(builder: (context, constraints) {
        final posterHeight =
            constraints.maxHeight - BangumiContent.tvTitleHeight(context);
        final width = (posterHeight * 0.65).clamp(1.0, constraints.maxWidth);
        return Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
              width: width, height: constraints.maxHeight, child: surface),
        );
      });
    }
    return surface;
  }
}

class _ChannelNumberBadge extends StatelessWidget {
  const _ChannelNumberBadge({required this.number});

  final int number;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$number 号节目',
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(7),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.25),
          ),
          boxShadow: const [
            BoxShadow(color: Colors.black38, blurRadius: 4),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Text(
            number.toString(),
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}

class BangumiContent extends StatelessWidget {
  const BangumiContent({super.key, required this.bangumiItem});

  final BangumiItem bangumiItem;

  static int maxTextLinesFor(BuildContext context) {
    if (TvMode.enabled) return 2;
    return isDesktop()
        ? 3
        : (isTablet() &&
                MediaQuery.of(context).orientation == Orientation.landscape)
            ? 3
            : 2;
  }

  static double tvTitleHeight(BuildContext context) =>
      MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.1).scale(14) *
          1.3 *
          2 +
      4;

  @override
  Widget build(BuildContext context) {
    final ts = MediaQuery.textScalerOf(context);
    final int maxTextLines = maxTextLinesFor(context);

    return Expanded(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(5, 3, 5, 1),
        child: Text(
          bangumiItem.nameCn,
          textAlign: TextAlign.start,
          style: TextStyle(
            fontSize: TvMode.enabled ? 14 : null,
            height: TvMode.enabled ? 1.3 : null,
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
