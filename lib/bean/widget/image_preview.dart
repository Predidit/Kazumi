import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/utils/device.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';

class ImageViewerRouteArgs {
  ImageViewerRouteArgs({
    required List<String> imageUrls,
    this.initialIndex = 0,
    this.heroTag,
  }) : imageUrls = List.unmodifiable(imageUrls);

  final List<String> imageUrls;
  final int initialIndex;
  final Object? heroTag;
}

class ImageViewer extends StatefulWidget {
  static const String routePath = '/image-preview';

  final List<String> imageUrls;
  final int initialIndex;
  final Object? heroTag;

  ImageViewer({
    super.key,
    required List<String> imageUrls,
    this.initialIndex = 0,
    this.heroTag,
  }) : imageUrls = List.unmodifiable(imageUrls);

  /// 显示图片预览
  static Future<void> show(
    BuildContext context, {
    required List<String> imageUrls,
    int initialIndex = 0,
    Object? heroTag,
  }) async {
    if (imageUrls.isEmpty) return;

    final index = initialIndex.clamp(0, imageUrls.length - 1);
    final effectiveHeroTag = heroTag ?? imageUrls[index];
    await Modular.to.pushNamed(
      routePath,
      arguments: ImageViewerRouteArgs(
        imageUrls: imageUrls,
        initialIndex: index,
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
  late final PageController _pageController;
  late int _currentIndex;
  final Map<int, PhotoViewController> _galleryControllers = {};
  final Map<int, PhotoViewScaleStateController> _galleryScaleStateControllers = {};
  final Map<int, double?> _initialScales = {};

  /// 滚轮单次缩放步长
  static const double _wheelScaleStep = 1.1;

  /// 最小缩放倍数
  static const double _minScaleFactor = 1.0;

  /// 最大缩放倍数
  static const double _maxScaleFactor = 6.0;

  bool get _isMultiImage => widget.imageUrls.length > 1;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _photoViewController = PhotoViewController();
    _scaleStateController = PhotoViewScaleStateController();
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _photoViewController.dispose();
    _scaleStateController.dispose();
    for (final controller in _galleryControllers.values) {
      controller.dispose();
    }
    for (final controller in _galleryScaleStateControllers.values) {
      controller.dispose();
    }
    _pageController.dispose();
    super.dispose();
  }

  PhotoViewController? get _activePhotoViewController {
    if (_isMultiImage) {
      return _galleryControllers[_currentIndex];
    }
    return _photoViewController;
  }

  PhotoViewScaleStateController? get _activeScaleStateController {
    if (_isMultiImage) {
      return _galleryScaleStateControllers[_currentIndex];
    }
    return _scaleStateController;
  }

  int get _activeScaleKey => _isMultiImage ? _currentIndex : -1;

  void _handlePointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) return;

    final photoViewController = _activePhotoViewController;
    final scaleStateController = _activeScaleStateController;
    if (photoViewController == null || scaleStateController == null) return;

    final scaleKey = _activeScaleKey;
    final currentScale =
        photoViewController.scale ?? _initialScales[scaleKey] ?? 1.0;
    _initialScales[scaleKey] ??= currentScale;

    final factor =
        event.scrollDelta.dy < 0 ? _wheelScaleStep : 1 / _wheelScaleStep;
    final minScale = _initialScales[scaleKey]! * _minScaleFactor;
    final maxScale = _initialScales[scaleKey]! * _maxScaleFactor;
    final newScale = (currentScale * factor).clamp(minScale, maxScale);

    if (newScale == currentScale) return;

    photoViewController.scale = newScale;
    scaleStateController.scaleState = PhotoViewScaleState.zoomedIn;
  }

  void _closePreview() {
    Navigator.of(context).pop();
  }

  Object _heroTagForIndex(int index) {
    if (index == widget.initialIndex && widget.heroTag != null) {
      return widget.heroTag!;
    }
    return '${widget.imageUrls[index]}#$index';
  }

  void _goToPreviousImage() {
    if (_currentIndex <= 0) return;
    _pageController.previousPage(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
    );
  }

  void _goToNextImage() {
    if (_currentIndex >= widget.imageUrls.length - 1) return;
    _pageController.nextPage(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
    );
  }

  Widget _buildNavButton({
    required IconData icon,
    required VoidCallback? onPressed,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.5),
        shape: BoxShape.circle,
      ),
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(
          icon,
          color: onPressed != null ? Colors.white : Colors.white38,
          size: 32,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          _isMultiImage ? _buildGallery() : _buildSingleImage(),
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
          if (_isMultiImage)
            Positioned(
              bottom: MediaQuery.of(context).padding.bottom + 24,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    '${_currentIndex + 1} / ${widget.imageUrls.length}',
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                  ),
                ),
              ),
            ),
          if (isDesktop() && _isMultiImage) ...[
            Positioned(
              left: 16,
              top: 0,
              bottom: 0,
              child: Center(
                child: _buildNavButton(
                  icon: Icons.chevron_left,
                  onPressed: _currentIndex > 0 ? _goToPreviousImage : null,
                ),
              ),
            ),
            Positioned(
              right: 16,
              top: 0,
              bottom: 0,
              child: Center(
                child: _buildNavButton(
                  icon: Icons.chevron_right,
                  onPressed: _currentIndex < widget.imageUrls.length - 1
                      ? _goToNextImage
                      : null,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildErrorWidget(BuildContext context) {
    return Center(
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
    );
  }

  Widget _buildSingleImage() {
    return Listener(
      onPointerSignal: _handlePointerSignal,
      child: GestureDetector(
        onTap: _closePreview,
        child: PhotoView(
          imageProvider:
              CachedNetworkImageProvider(widget.imageUrls.first),
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
          errorBuilder: (context, error, stackTrace) =>
              _buildErrorWidget(context),
        ),
      ),
    );
  }

  Widget _buildGallery() {
    return Listener(
      onPointerSignal: _handlePointerSignal,
      child: GestureDetector(
        onTap: _closePreview,
        child: PhotoViewGallery.builder(
          pageController: _pageController,
          itemCount: widget.imageUrls.length,
          onPageChanged: (index) => setState(() => _currentIndex = index),
          backgroundDecoration: const BoxDecoration(color: Colors.black),
          loadingBuilder: (context, event) => const Center(
            child: CircularProgressIndicator(),
          ),
          builder: (context, index) {
            final imageUrl = widget.imageUrls[index];
            final controller = _galleryControllers.putIfAbsent(
              index,
              PhotoViewController.new,
            );
            final scaleStateController =
                _galleryScaleStateControllers.putIfAbsent(
              index,
              PhotoViewScaleStateController.new,
            );
            return PhotoViewGalleryPageOptions(
              imageProvider: CachedNetworkImageProvider(imageUrl),
              controller: controller,
              scaleStateController: scaleStateController,
              minScale: PhotoViewComputedScale.contained,
              maxScale: PhotoViewComputedScale.covered * 3,
              heroAttributes: index == _currentIndex
                  ? PhotoViewHeroAttributes(tag: _heroTagForIndex(index))
                  : null,
              errorBuilder: (context, error, stackTrace) =>
                  _buildErrorWidget(context),
            );
          },
        ),
      ),
    );
  }
}
