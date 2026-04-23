import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:photo_view/photo_view.dart';

class ImageViewer extends StatefulWidget {
  final String imageUrl;
  final String? heroTag;

  const ImageViewer({super.key, required this.imageUrl, this.heroTag});

  /// 显示图片预览
  static void show(BuildContext context,
      {required String imageUrl, String? heroTag}) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black.withValues(alpha: 0.8),
        pageBuilder: (context, animation, secondaryAnimation) {
          return ImageViewer(imageUrl: imageUrl, heroTag: heroTag);
        },
        transitionDuration: const Duration(milliseconds: 300),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.8, end: 1.0).animate(
                CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
              ),
              child: child,
            ),
          );
        },
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

    final factor = event.scrollDelta.dy < 0 ? _wheelScaleStep : 1 / _wheelScaleStep;
    final minScale = _initialScale! * _minScaleFactor;
    final maxScale = _initialScale! * _maxScaleFactor;
    final newScale = (currentScale * factor).clamp(minScale, maxScale);

    if (newScale == currentScale) return;

    _photoViewController.scale = newScale;
    _scaleStateController.scaleState = PhotoViewScaleState.zoomedIn;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          Listener(
            onPointerSignal: _handlePointerSignal,
            child: GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: PhotoView(
                imageProvider: CachedNetworkImageProvider(widget.imageUrl),
                controller: _photoViewController,
                scaleStateController: _scaleStateController,
                minScale: PhotoViewComputedScale.contained,
                maxScale: PhotoViewComputedScale.covered * 3,
                backgroundDecoration: const BoxDecoration(
                  color: Colors.transparent,
                ),
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
                          color:
                              Theme.of(context).colorScheme.onErrorContainer,
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
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
