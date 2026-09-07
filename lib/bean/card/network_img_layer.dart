import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:kazumi/services/logging/logger.dart';
import 'package:kazumi/utils/constants.dart';
import 'package:kazumi/utils/image_extension.dart';

class NetworkImgLayer extends StatelessWidget {
  const NetworkImgLayer({
    super.key,
    this.src,
    required this.width,
    required this.height,
    this.fit = BoxFit.cover,
    this.type,
    this.fadeOutDuration,
    this.fadeInDuration,
    this.origAspectRatio,
    this.filterQuality = FilterQuality.high,
    this.color,
    this.colorBlendMode,
  });

  final String? src;
  final double width;
  final double height;
  final BoxFit fit;
  final String? type;
  final Duration? fadeOutDuration;
  final Duration? fadeInDuration;
  final double? origAspectRatio;
  final FilterQuality filterQuality;
  final Color? color;
  final BlendMode? colorBlendMode;

  static Widget heroFlightShuttleBuilder(
    BuildContext flightContext,
    Animation<double> animation,
    HeroFlightDirection flightDirection,
    BuildContext fromHeroContext,
    BuildContext toHeroContext,
  ) {
    final fromHero = fromHeroContext.widget as Hero;
    final toHero = toHeroContext.widget as Hero;
    final heroContext = flightDirection == HeroFlightDirection.push
        ? fromHeroContext
        : toHeroContext;
    final hero =
        flightDirection == HeroFlightDirection.push ? fromHero : toHero;

    return InheritedTheme.captureAll(
      heroContext,
      Material(
        type: MaterialType.transparency,
        child: hero.child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final imageUrl = src ?? '';
    if (imageUrl.isEmpty) {
      return _placeholder(context);
    }

    final (memCacheWidth, memCacheHeight) = _cacheSize(context);
    return ClipRRect(
      clipBehavior: Clip.antiAlias,
      borderRadius: _borderRadius,
      child: CachedNetworkImage(
        imageUrl: imageUrl,
        width: width,
        height: height,
        memCacheWidth: memCacheWidth,
        memCacheHeight: memCacheHeight,
        fit: fit,
        fadeOutDuration: fadeOutDuration ?? const Duration(milliseconds: 120),
        fadeInDuration: fadeInDuration ?? const Duration(milliseconds: 120),
        filterQuality: filterQuality,
        color: color,
        colorBlendMode: colorBlendMode,
        errorListener: (e) {
          KazumiLogger().w("NetworkImage: network image load error", error: e);
        },
        errorWidget: (context, url, error) => _placeholder(context),
        placeholder: (context, url) => _placeholder(context),
      ),
    );
  }

  (int?, int?) _cacheSize(BuildContext context) {
    final cacheWidth = width.cacheSize(context);
    final cacheHeight = height.cacheSize(context);
    final aspectRatio = width / height;
    final sourceAspectRatio = origAspectRatio;

    switch (fit) {
      case BoxFit.none:
      case BoxFit.scaleDown:
        // These modes depend on the original image dimensions.
        return (null, null);
      case BoxFit.fill:
        return (cacheWidth, cacheHeight);
      case BoxFit.fitWidth:
        return (cacheWidth, null);
      case BoxFit.fitHeight:
        return (null, cacheHeight);
      case BoxFit.contain:
        // A single decode axis preserves unknown source proportions.
        return sourceAspectRatio != null && sourceAspectRatio > aspectRatio
            ? (cacheWidth, null)
            : (null, cacheHeight);
      case BoxFit.cover:
        // Decode enough pixels along the axis that fills the box.
        if (sourceAspectRatio != null) {
          if (sourceAspectRatio < aspectRatio) return (cacheWidth, null);
          if (sourceAspectRatio > aspectRatio) return (null, cacheHeight);
        } else {
          if (aspectRatio > 1) return (null, cacheHeight);
          if (aspectRatio < 1) return (cacheWidth, null);
        }
        return (cacheWidth, cacheHeight);
    }
  }

  BorderRadius get _borderRadius => BorderRadius.circular(switch (type) {
        'avatar' => 50,
        'emote' => 0,
        _ => StyleString.imgRadius.x,
      });

  Widget _placeholder(BuildContext context) {
    return Container(
      width: width,
      height: height,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .onInverseSurface
            .withValues(alpha: 0.4),
        borderRadius: _borderRadius,
      ),
      child: type == 'bg'
          ? const SizedBox()
          : Center(
              child: Image.asset(
                type == 'avatar'
                    ? 'assets/images/noface.jpeg'
                    : 'assets/images/loading.png',
                width: width,
                height: height,
                cacheWidth: width.cacheSize(context),
                cacheHeight: height.cacheSize(context),
              ),
            ),
    );
  }
}
