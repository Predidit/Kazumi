import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:kazumi/utils/constants.dart';
import 'package:kazumi/utils/extension.dart';
import 'package:kazumi/utils/logger.dart';
import 'package:logger/logger.dart';

class NetworkImgLayer extends StatelessWidget {
  const NetworkImgLayer({
    super.key,
    this.src,
    required this.width,
    required this.height,
    this.type,
    this.fadeOutDuration,
    this.fadeInDuration,
    // 图片质量 默认1%
    this.quality,
    this.origAspectRatio,
    this.sigmaX = 0,
    this.sigmaY = 0,
  });

  final String? src;
  final double width;
  final double height;
  final String? type;
  final Duration? fadeOutDuration;
  final Duration? fadeInDuration;
  final int? quality;
  final double? origAspectRatio;
  final double sigmaX;
  final double sigmaY;

  @override
  Widget build(BuildContext context) {
    final String imageUrl = src ?? '';

    //// We need this to shink memory usage
    int? memCacheWidth, memCacheHeight;
    double aspectRatio = (width / height).toDouble();

    void setMemCacheSizes() {
      if (aspectRatio > 1) {
        memCacheHeight = height.cacheSize(context);
      } else if (aspectRatio < 1) {
        memCacheWidth = width.cacheSize(context);
      } else {
        if (origAspectRatio != null && origAspectRatio! > 1) {
          memCacheWidth = width.cacheSize(context);
        } else if (origAspectRatio != null && origAspectRatio! < 1) {
          memCacheHeight = height.cacheSize(context);
        } else {
          memCacheWidth = width.cacheSize(context);
          memCacheHeight = height.cacheSize(context);
        }
      }
    }

    setMemCacheSizes();

    if (memCacheWidth == null && memCacheHeight == null) {
      memCacheWidth = width.toInt();
    }

    return src != '' && src != null
        ? CachedNetworkImage(
            imageUrl: imageUrl,
            width: width,
            height: height,
            memCacheWidth: memCacheWidth,
            memCacheHeight: memCacheHeight,
            fadeOutDuration:
                fadeOutDuration ?? const Duration(milliseconds: 120),
            fadeInDuration: fadeInDuration ?? const Duration(milliseconds: 120),
            errorListener: (e) {
              KazumiLogger().log(Level.warning, "网络图片加载错误 ${e.toString()}");
            },
            errorWidget: (BuildContext context, String url, Object error) =>
                placeholder(context),
            placeholder: (BuildContext context, String url) =>
                placeholder(context),
            imageBuilder: (context, imageProvider) => Container(
              decoration: BoxDecoration(
                image: DecorationImage(
                  filterQuality: FilterQuality.high,
                  image: imageProvider,
                  fit: BoxFit.cover,
                ),
                borderRadius: BorderRadius.circular(
                  type == 'avatar'
                      ? 50
                      : type == 'emote'
                          ? 0
                          : StyleString.imgRadius.x,
                ),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: sigmaX, sigmaY: sigmaY),
                child: Container(
                  color: Colors.transparent,
                ),
              ),
            ),
          )
        : placeholder(context);
  }

  Widget placeholder(BuildContext context) {
    return Container(
      width: width,
      height: height,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.onInverseSurface.withOpacity(0.4),
        borderRadius: BorderRadius.circular(type == 'avatar'
            ? 50
            : type == 'emote'
                ? 0
                : StyleString.imgRadius.x),
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
