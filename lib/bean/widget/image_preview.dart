import 'package:cached_network_image_ce/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:photo_view/photo_view.dart';

class ImageViewerRouteArgs {
  const ImageViewerRouteArgs({required this.imageUrl, this.heroTag});

  final String imageUrl;
  final String? heroTag;
}

class ImageViewer extends StatefulWidget {
  static const String routePath = '/image-preview';

  final String imageUrl;
  final String? heroTag;

  const ImageViewer({super.key, required this.imageUrl, this.heroTag});

  /// 显示图片预览
  static Future<void> show(BuildContext context,
      {required String imageUrl, String? heroTag}) async {
    final effectiveHeroTag = heroTag ?? imageUrl;
    await Modular.to.pushNamed(
      routePath,
      arguments: ImageViewerRouteArgs(
        imageUrl: imageUrl,
        heroTag: effectiveHeroTag,
      ),
    );
  }

  @override
  State<ImageViewer> createState() => _ImageViewerState();
}

class _ImageViewerState extends State<ImageViewer> {
  late final PhotoViewController _photoViewController;
  late final PhotoViewScaleStateController _scaleStateController;

  /// 初始缩放值
  double? _initialScale;

  /// 滚轮单次缩放步长
  static const double _wheelScaleStep = 1.1;

  /// 最小缩放倍数
  static const double _minScaleFactor = 1.0;

  /// 最大缩放倍数
  static const double _maxScaleFactor = 6.0;

  @override
  void initState() {
    super.initState();
    _photoViewController = PhotoViewController();
    _scaleStateController = PhotoViewScaleStateController();
  }

  @override
  void dispose() {
    _photoViewController.dispose();
    _scaleStateController.dispose();
    super.dispose();
  }

  void _handlePointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) return;
    final currentScale = _photoViewController.scale ?? _initialScale ?? 1.0;
    _initialScale ??= currentScale;

    final factor =
        event.scrollDelta.dy < 0 ? _wheelScaleStep : 1 / _wheelScaleStep;
    final minScale = _initialScale! * _minScaleFactor;
    final maxScale = _initialScale! * _maxScaleFactor;
    final newScale = (currentScale * factor).clamp(minScale, maxScale);

    if (newScale == currentScale) return;

    _photoViewController.scale = newScale;
    _scaleStateController.scaleState = PhotoViewScaleState.zoomedIn;
  }

  void _closePreview() {
    Modular.to.pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Listener(
            onPointerSignal: _handlePointerSignal,
            child: GestureDetector(
              onTap: _closePreview,
              child: PhotoView(
                imageProvider: CachedNetworkImageProvider(widget.imageUrl),
                controller: _photoViewController,
                scaleStateController: _scaleStateController,
                minScale: PhotoViewComputedScale.contained,
                maxScale: PhotoViewComputedScale.covered * 3,
                backgroundDecoration: const BoxDecoration(color: Colors.black),
                heroAttributes: widget.heroTag != null
                    ? PhotoViewHeroAttributes(tag: widget.heroTag!)
                    : null,
                loadingBuilder: (context, event) => const Center(
                  child: CircularProgressIndicator(),
                ),
                errorBuilder: (context, error, stackTrace) => Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.broken_image,
                        size: 48,
                        color: Theme.of(context).colorScheme.onErrorContainer,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '图片加载失败',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onErrorContainer,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // 关闭按钮
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            right: 16,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.5),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                onPressed: _closePreview,
                icon: const Icon(Icons.close, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
