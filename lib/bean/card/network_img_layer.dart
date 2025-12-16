import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:kazumi/utils/constants.dart';
import 'package:kazumi/utils/extension.dart';
import 'package:kazumi/utils/logger.dart';
class NetworkImgLayer extends StatefulWidget {
  const NetworkImgLayer({
    super.key,
    this.src,
    required this.width,
    required this.height,
    this.type,
    this.fadeOutDuration,
    this.fadeInDuration,
    this.quality,
    this.origAspectRatio,
  });

  final String? src;
  final double width;
  final double height;
  final String? type;
  final Duration? fadeOutDuration;
  final Duration? fadeInDuration;
  final int? quality;
  final double? origAspectRatio;

  @override
  State<NetworkImgLayer> createState() => _NetworkImgLayerState();
}

class _NetworkImgLayerState extends State<NetworkImgLayer> {
  int? memCacheWidth, memCacheHeight;
  @override
  Widget build(BuildContext context) {
    final String imageUrl = widget.src ?? '';

    //// We need this to shink memory usage
    if (memCacheWidth == null && memCacheHeight == null) {
      double aspectRatio = (widget.width / widget.height).toDouble();
      void setMemCacheSizes() {
        if (aspectRatio > 1) {
          memCacheHeight = widget.height.cacheSize(context);
        } else if (aspectRatio < 1) {
          memCacheWidth = widget.width.cacheSize(context);
        } else {
          if (widget.origAspectRatio != null && widget.origAspectRatio! > 1) {
            memCacheWidth = widget.width.cacheSize(context);
          } else if (widget.origAspectRatio != null && widget.origAspectRatio! < 1) {
            memCacheHeight = widget.height.cacheSize(context);
          } else {
            memCacheWidth = widget.width.cacheSize(context);
            memCacheHeight = widget.height.cacheSize(context);
          }
        }
      }

      setMemCacheSizes();

      if (memCacheWidth == null && memCacheHeight == null) {
        memCacheWidth = widget.width.toInt();
      }
    }

    return widget.src != '' && widget.src != null
        ? ClipRRect(
            clipBehavior: Clip.antiAlias,
            borderRadius: BorderRadius.circular(
              widget.type == 'avatar'
                  ? 50
                  : widget.type == 'emote'
                      ? 0
                      : StyleString.imgRadius.x,
            ),
            child: CachedNetworkImage(
              imageUrl: imageUrl,
              width: widget.width,
              height: widget.height,
              memCacheWidth: memCacheWidth,
              memCacheHeight: memCacheHeight,
              fit: BoxFit.cover,
              fadeOutDuration:
                  widget.fadeOutDuration ?? const Duration(milliseconds: 120),
              fadeInDuration:
                  widget.fadeInDuration ?? const Duration(milliseconds: 120),
              filterQuality: FilterQuality.high,
              errorListener: (e) {
                KazumiLogger().w("NetworkImage: network image load error", error: e);
              },
              errorWidget: (BuildContext context, String url, Object error) =>
                  placeholder(context),
              placeholder: (BuildContext context, String url) =>
                  placeholder(context),
            ))
        : placeholder(context);
  }

  Widget placeholder(BuildContext context) {
    return Container(
      width: widget.width,
      height: widget.height,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.onInverseSurface.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(widget.type == 'avatar'
            ? 50
            : widget.type == 'emote'
                ? 0
                : StyleString.imgRadius.x),
      ),
      child: widget.type == 'bg'
          ? const SizedBox()
          : Center(
              child: Image.asset(
                widget.type == 'avatar'
                    ? 'assets/images/noface.jpeg'
                    : 'assets/images/loading.png',
                width: widget.width,
                height: widget.height,
                cacheWidth: widget.width.cacheSize(context),
                cacheHeight: widget.height.cacheSize(context),
              ),
            ),
    );
  }
}
