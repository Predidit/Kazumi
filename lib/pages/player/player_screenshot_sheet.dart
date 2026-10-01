import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:kazumi/bean/widget/kazumi_menu.dart';
import 'package:kazumi/pages/player/controller/player_screenshot_controller.dart';
import 'package:kazumi/pages/player/player_screenshot_image.dart';
import 'package:kazumi/services/player/screenshot_candidate.dart';
import 'package:kazumi/services/player/screenshot_export_service.dart';
import 'package:kazumi/services/player/screenshot_image_cache.dart';
import 'package:mobx/mobx.dart' as mobx;

Future<void> showPlayerScreenshotSheet(
  BuildContext context, {
  required PlayerScreenshotController controller,
}) => showDialog<void>(
  context: context,
  barrierDismissible: true,
  builder: (context) => LayoutBuilder(
    builder: (context, constraints) {
      final inset = constraints.maxWidth < 700 || constraints.maxHeight < 500
          ? 16.0
          : 24.0;
      return Dialog(
        clipBehavior: Clip.antiAlias,
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHigh,
        insetPadding: EdgeInsets.all(inset),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        child: SizedBox(
          width: 1120,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: math.min(840, constraints.maxHeight - inset * 2),
            ),
            child: _PlayerScreenshotSheet(controller: controller),
          ),
        ),
      );
    },
  ),
);

class _PlayerScreenshotSheet extends StatefulWidget {
  const _PlayerScreenshotSheet({required this.controller});
  final PlayerScreenshotController controller;

  @override
  State<_PlayerScreenshotSheet> createState() => _PlayerScreenshotSheetState();
}

class _PlayerScreenshotSheetState extends State<_PlayerScreenshotSheet> {
  static const _exportService = ScreenshotExportService();
  late PageController _pages;
  late final mobx.ReactionDisposer _stopWatchingCandidates;
  String? _activeId;
  final FocusNode _focus = FocusNode(debugLabel: 'Screenshot review');
  final TransformationController _transform = TransformationController();
  // Preserve the preview when resizing switches layouts.
  final GlobalKey _previewKey = GlobalKey();
  final Map<String, double?> _aspectRatios = {};
  int _index = 0;
  bool _zoomed = false;
  String? _notice;
  bool _noticeError = false;
  Timer? _noticeTimer;

  PlayerScreenshotController get collection => widget.controller;
  ScreenshotCandidate? get current =>
      collection.candidates.isEmpty ? null : collection.candidates[_index];
  double get _aspectRatio => _aspectRatios[current?.id] ?? 16 / 9;
  Duration get _motion => MediaQuery.disableAnimationsOf(context)
      ? Duration.zero
      : const Duration(milliseconds: 220);

  @override
  void initState() {
    super.initState();
    _index = math.max(0, collection.candidates.length - 1);
    _activeId = current?.id;
    _pages = PageController(initialPage: _index, keepPage: false);
    _stopWatchingCandidates = mobx.reaction<List<String>>(
      (_) => collection.candidates.map((item) => item.id).toList(),
      _candidatesChanged,
    );
  }

  void _candidatesChanged(List<String> ids) {
    final retainedIndex = _activeId == null ? -1 : ids.indexOf(_activeId!);
    final oldPages = _pages;
    setState(() {
      _index = retainedIndex >= 0
          ? retainedIndex
          : math.max(0, math.min(_index, ids.length - 1));
      _activeId = ids.isEmpty ? null : ids[_index];
      _zoomed = false;
      _transform.value = Matrix4.identity();
      _aspectRatios.removeWhere((id, _) => !ids.contains(id));
      _pages = PageController(initialPage: _index, keepPage: false);
    });
    // Detach the old PageView before disposing its controller.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      oldPages.dispose();
      if (mounted) _warmNeighbors();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _warmNeighbors();
  }

  void _warmNeighbors() {
    for (
      var i = math.max(0, _index - 1);
      i <= math.min(collection.candidates.length - 1, _index + 1);
      i++
    ) {
      final item = collection.candidates[i];
      if (_aspectRatios.containsKey(item.id)) continue;
      _aspectRatios[item.id] = null;
      unawaited(_readAspectRatio(item));
      unawaited(
        precacheImage(MemoryImage(item.bytes), context, onError: (_, _) {}),
      );
    }
  }

  Future<void> _readAspectRatio(ScreenshotCandidate item) async {
    ui.ImmutableBuffer? buffer;
    ui.ImageDescriptor? descriptor;
    try {
      buffer = await ui.ImmutableBuffer.fromUint8List(item.bytes);
      descriptor = await ui.ImageDescriptor.encoded(buffer);
      if (!mounted || !_aspectRatios.containsKey(item.id)) return;
      final ratio = descriptor.width / descriptor.height;
      final resize = current?.id == item.id && ratio != _aspectRatio;
      _aspectRatios[item.id] = ratio;
      if (resize) setState(() {});
    } catch (_) {
      // The image widget handles invalid image data.
    } finally {
      descriptor?.dispose();
      buffer?.dispose();
    }
  }

  @override
  void dispose() {
    _stopWatchingCandidates();
    _pages.dispose();
    _focus.dispose();
    _transform.dispose();
    _noticeTimer?.cancel();
    super.dispose();
  }

  void _goTo(int index) {
    if (index < 0 || index >= collection.candidates.length || index == _index) {
      return;
    }
    _pages.jumpToPage(index);
  }

  void _step(int delta) => _goTo(_index + delta);

  void _toggleZoom() {
    final size = _previewKey.currentContext?.size;
    if (size == null || size.isEmpty) return;
    setState(() {
      _zoomed = !_zoomed;
      _transform.value = _zoomed
          ? (Matrix4.identity()
              ..translateByDouble(-size.width * 0.5, -size.height * 0.5, 0, 1)
              ..scaleByDouble(2, 2, 1, 1))
          : Matrix4.identity();
    });
  }

  void _toggle() {
    final item = current;
    if (item != null) collection.toggle(item);
  }

  void _close() {
    if (!collection.saving) Navigator.maybePop(context);
  }

  Future<void> _save() async {
    _noticeTimer?.cancel();
    setState(() => _notice = null);
    await collection.save(
      chooseDestination: _exportService.chooseDestination,
      write: _exportService.write,
    );
    if (mounted) _showNotice();
  }

  void _showNotice() {
    _noticeTimer?.cancel();
    _focus.requestFocus();
    setState(() {
      _notice = collection.message;
      _noticeError = collection.hasError;
    });
    _noticeTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) setState(() => _notice = null);
    });
  }

  void _removeSelected() {
    if (collection.busy || collection.selectedCount == 0) return;
    collection.removeSelected();
    _showNotice();
  }

  Future<void> _clearCandidates() async {
    if (collection.busy || collection.candidates.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清空候选截图？'),
        content: Text('这将丢弃 ${collection.candidates.length} 张未保存的截图，无法恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('清空'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    _focus.requestFocus();
    if (confirmed != true || collection.busy) return;
    collection.clearCandidates();
    _showNotice();
  }

  @override
  Widget build(BuildContext context) => Observer.withBuiltChild(
    builder: (context, child) =>
        PopScope(canPop: !collection.saving, child: child),
    child: CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.arrowLeft): () => _step(-1),
        const SingleActivator(LogicalKeyboardKey.arrowRight): () => _step(1),
        const SingleActivator(LogicalKeyboardKey.space): _toggle,
        const SingleActivator(LogicalKeyboardKey.escape): _close,
      },
      child: Focus(
        focusNode: _focus,
        autofocus: true,
        child: IconButtonTheme(
          data: const IconButtonThemeData(
            style: ButtonStyle(
              minimumSize: WidgetStatePropertyAll(Size(48, 48)),
            ),
          ),
          child: Material(
            color: Theme.of(context).colorScheme.surfaceContainerHigh,
            child: LayoutBuilder(
              builder: (context, constraints) => Observer(
                builder: (context) {
                  final compact = constraints.maxHeight < 500;
                  final wide = constraints.maxWidth >= 700;
                  final landscape =
                      compact &&
                      constraints.maxWidth >= 480 &&
                      constraints.maxWidth > constraints.maxHeight;
                  final padding = compact || !wide ? 16.0 : 24.0;
                  if (current != null && landscape) {
                    return _landscape(context, constraints);
                  }
                  return Column(
                    mainAxisSize: wide ? MainAxisSize.max : MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _header(context, compact: compact, padding: padding),
                      if (current == null)
                        Expanded(child: _empty(context))
                      else ...[
                        Flexible(
                          fit: wide ? FlexFit.tight : FlexFit.loose,
                          child: Padding(
                            padding: EdgeInsets.symmetric(horizontal: padding),
                            child: wide
                                ? Center(child: _preview())
                                : _preview(),
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.fromLTRB(
                            padding,
                            compact ? 8 : 16,
                            padding,
                            0,
                          ),
                          child: Material(
                            color: Theme.of(
                              context,
                            ).colorScheme.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(20),
                            clipBehavior: Clip.antiAlias,
                            child: Column(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    16,
                                    8,
                                    16,
                                    0,
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          '${current!.episode} · ${current!.timeLabel}',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: Theme.of(context)
                                              .textTheme
                                              .labelMedium
                                              ?.copyWith(
                                                color: Theme.of(
                                                  context,
                                                ).colorScheme.onSurfaceVariant,
                                              ),
                                        ),
                                      ),
                                      _navigation(),
                                    ],
                                  ),
                                ),
                                _thumbnails(compact: compact),
                              ],
                            ),
                          ),
                        ),
                        _footer(
                          context,
                          compact: compact,
                          padding: padding,
                          showReturn: wide,
                        ),
                      ],
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    ),
  );

  Widget _landscape(BuildContext context, BoxConstraints constraints) {
    final panelWidth = math.min(
      constraints.maxWidth * 0.4,
      math.max(208.0, MediaQuery.textScalerOf(context).scale(160)),
    );
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Column(
              children: [
                Expanded(child: Center(child: _preview())),
                const SizedBox(height: 8),
                Material(
                  color: Theme.of(context).colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(16),
                  clipBehavior: Clip.antiAlias,
                  child: _thumbnails(compact: true),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          SizedBox(
            width: panelWidth,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _header(context, compact: true, padding: 0),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          current!.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${current!.episode} · ${current!.timeLabel}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ),
                Center(child: _navigation()),
                _footer(context, compact: true, padding: 0, stackActions: true),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _preview() => AspectRatio(
    key: _previewKey,
    aspectRatio: _aspectRatio,
    child: ClipRRect(borderRadius: BorderRadius.circular(16), child: _stage()),
  );

  Widget _navigation() => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      IconButton(
        tooltip: '上一张',
        onPressed: _index > 0 ? () => _step(-1) : null,
        icon: const Icon(Icons.chevron_left_rounded),
      ),
      Text(
        '${_index + 1} / ${collection.candidates.length}',
        style: Theme.of(context).textTheme.labelMedium,
      ),
      IconButton(
        tooltip: '下一张',
        onPressed: _index < collection.candidates.length - 1
            ? () => _step(1)
            : null,
        icon: const Icon(Icons.chevron_right_rounded),
      ),
    ],
  );

  Widget _header(
    BuildContext context, {
    required bool compact,
    required double padding,
  }) => Padding(
    padding: EdgeInsets.fromLTRB(
      padding,
      compact ? 4 : 16,
      math.max(0, padding - 8),
      compact ? 4 : 16,
    ),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '挑选截图',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: compact
                    ? Theme.of(context).textTheme.titleLarge
                    : Theme.of(context).textTheme.headlineSmall,
              ),
              if (!compact && current != null)
                Text(
                  current!.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ),
        if (current != null)
          KazumiMenuButton(
            animated: true,
            enabled: !collection.busy,
            builder: (context, toggle) => IconButton(
              tooltip: '管理截图',
              icon: const Icon(Icons.more_vert_rounded),
              onPressed: toggle,
            ),
            menuChildren: [
              KazumiMenuItem(
                label: '移除所选',
                onPressed: !collection.busy && collection.selectedCount > 0
                    ? _removeSelected
                    : null,
              ),
              KazumiMenuItem(
                label: '清空候选',
                onPressed: collection.busy
                    ? null
                    : () => unawaited(_clearCandidates()),
              ),
            ],
          ),
        if (current != null)
          IconButton(
            tooltip: _zoomed ? '还原大小' : '放大查看',
            onPressed: _toggleZoom,
            icon: Icon(
              _zoomed ? Icons.zoom_out_rounded : Icons.zoom_in_rounded,
            ),
          ),
        Observer(
          builder: (context) => IconButton(
            tooltip: '返回播放',
            onPressed: collection.saving ? null : _close,
            icon: const Icon(Icons.close_rounded),
          ),
        ),
      ],
    ),
  );

  Widget _stage() => ColoredBox(
    color: const Color(0xff101114),
    child: Stack(
      fit: StackFit.expand,
      children: [
        PageView.builder(
          key: ObjectKey(_pages),
          controller: _pages,
          physics: _zoomed
              ? const NeverScrollableScrollPhysics()
              : const ClampingScrollPhysics(),
          onPageChanged: (index) {
            if (index >= collection.candidates.length) return;
            _transform.value = Matrix4.identity();
            setState(() {
              _index = index;
              _activeId = current?.id;
              _zoomed = false;
            });
            _warmNeighbors();
          },
          itemCount: collection.candidates.length,
          itemBuilder: (context, index) => GestureDetector(
            key: ValueKey(collection.candidates[index].id),
            onDoubleTap: index == _index ? _toggleZoom : null,
            child: InteractiveViewer(
              transformationController: index == _index ? _transform : null,
              minScale: 1,
              maxScale: 4,
              panEnabled: index == _index && _zoomed,
              onInteractionEnd: (_) {
                if (index == _index) {
                  setState(() {
                    _zoomed = _transform.value.getMaxScaleOnAxis() > 1.01;
                  });
                }
              },
              child: PlayerScreenshotImage(
                bytes: collection.candidates[index].bytes,
                semanticLabel:
                    '${collection.candidates[index].episode} '
                    '${collection.candidates[index].timeLabel} 截图',
              ),
            ),
          ),
        ),
        Positioned(
          left: 8,
          right: 8,
          bottom: 8,
          child: Align(
            alignment: Alignment.bottomCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: AnimatedSwitcher(
                duration: _motion,
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.15),
                      end: Offset.zero,
                    ).animate(animation),
                    child: child,
                  ),
                ),
                child: _notice == null
                    ? const SizedBox.shrink()
                    : _noticeView(),
              ),
            ),
          ),
        ),
      ],
    ),
  );

  Widget _pickButton(ScreenshotCandidate item) => Observer(
    builder: (context) {
      final selected = collection.isSelected(item);
      return Semantics(
        selected: selected,
        child: FilledButton.tonalIcon(
          style: _actionStyle(selected: selected).copyWith(
            backgroundColor: WidgetStatePropertyAll(
              selected
                  ? Theme.of(context).colorScheme.secondaryContainer
                  : Theme.of(context).colorScheme.surfaceContainerHighest,
            ),
          ),
          onPressed: collection.saving ? null : _toggle,
          icon: Icon(
            selected
                ? Icons.check_circle_rounded
                : Icons.radio_button_unchecked_rounded,
            size: 20,
          ),
          label: Text(selected ? '已选中' : '选择这张'),
        ),
      );
    },
  );

  Widget _thumbnails({required bool compact}) => _ScreenshotFilmstrip(
    controller: collection,
    activeIndex: _index,
    compact: compact,
    duration: _motion,
    onBrowse: _goTo,
  );

  Widget _noticeView() {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      key: ValueKey(_notice),
      liveRegion: true,
      child: Material(
        color: colors.inverseSurface,
        elevation: 6,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.only(left: 16, top: 4, bottom: 4),
          child: Row(
            children: [
              Icon(
                _noticeError
                    ? Icons.error_outline_rounded
                    : Icons.info_outline_rounded,
                size: 20,
                color: colors.onInverseSurface,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _notice!,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colors.onInverseSurface,
                  ),
                ),
              ),
              IconButton(
                tooltip: '关闭提示',
                color: colors.onInverseSurface,
                onPressed: () => setState(() => _notice = null),
                icon: const Icon(Icons.close_rounded, size: 20),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _footer(
    BuildContext context, {
    required bool compact,
    required double padding,
    bool showReturn = false,
    bool stackActions = false,
  }) {
    final scaler = MediaQuery.textScalerOf(context);
    final buttonHeight = math.max(48.0, scaler.scale(20) + 24);
    final saveWidth = math.max(148.0, scaler.scale(100) + 48);
    final save = SizedBox(
      height: buttonHeight,
      child: Observer(
        builder: (context) => FilledButton.icon(
          style: _actionStyle(),
          onPressed: !collection.busy && collection.selectedCount > 0
              ? _save
              : null,
          icon: collection.saving
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.save_alt_rounded, size: 20),
          label: Text(
            collection.saving
                ? '${collection.saveCompleted}/${collection.saveTotal}'
                : '保存${collection.selectedCount > 0 ? ' ${collection.selectedCount} 张' : '所选'}',
            maxLines: 1,
          ),
        ),
      ),
    );
    return Padding(
      padding: EdgeInsets.fromLTRB(
        padding,
        compact ? 8 : 16,
        padding,
        compact ? 8 : 24,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stacked =
              stackActions ||
              constraints.maxWidth < saveWidth + scaler.scale(96) + 48;
          final pick = SizedBox(
            height: buttonHeight,
            child: _pickButton(current!),
          );
          if (stacked) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [pick, const SizedBox(height: 8), save],
            );
          }
          return Row(
            children: [
              pick,
              const Spacer(),
              if (showReturn) ...[
                Observer(
                  builder: (context) => TextButton(
                    onPressed: collection.saving ? null : _close,
                    child: const Text('返回播放'),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              SizedBox(width: saveWidth, child: save),
            ],
          );
        },
      ),
    );
  }

  ButtonStyle _actionStyle({bool selected = false}) => ButtonStyle(
    minimumSize: const WidgetStatePropertyAll(Size(48, 48)),
    padding: const WidgetStatePropertyAll(
      EdgeInsets.symmetric(horizontal: 20, vertical: 12),
    ),
    animationDuration: _motion,
    shape: WidgetStateProperty.resolveWith(
      (states) => RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(
          states.contains(WidgetState.pressed)
              ? 12
              : selected
              ? 16
              : 24,
        ),
      ),
    ),
  );

  Widget _empty(BuildContext context) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.photo_camera_outlined,
            size: 40,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 20),
          Text('暂无待处理截图', style: Theme.of(context).textTheme.titleLarge),
          if (_notice != null) ...[const SizedBox(height: 16), _noticeView()],
          const SizedBox(height: 8),
          const Text(
            '返回视频，点击相机收集喜欢的画面。\n保存或移除截图后，可以继续截图。',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          FilledButton.tonal(onPressed: _close, child: const Text('返回视频截图')),
        ],
      ),
    ),
  );
}

class _ScreenshotFilmstrip extends StatefulWidget {
  const _ScreenshotFilmstrip({
    required this.controller,
    required this.activeIndex,
    required this.compact,
    required this.duration,
    required this.onBrowse,
  });

  final PlayerScreenshotController controller;
  final int activeIndex;
  final bool compact;
  final Duration duration;
  final ValueChanged<int> onBrowse;

  @override
  State<_ScreenshotFilmstrip> createState() => _ScreenshotFilmstripState();
}

class _ScreenshotFilmstripState extends State<_ScreenshotFilmstrip> {
  final ScrollController _scroll = ScrollController();
  double? _target;
  bool _positioned = false;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _centerActive() {
    if (!mounted || !_scroll.hasClients) return;
    final offset = _target!.clamp(0.0, _scroll.position.maxScrollExtent);
    if (!_positioned || widget.duration == Duration.zero) {
      _scroll.jumpTo(offset);
      if (!_positioned) setState(() => _positioned = true);
    } else {
      _scroll.animateTo(
        offset,
        duration: widget.duration,
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => Observer(
      builder: (context) {
        final items = widget.controller.candidates;
        final height = widget.compact ? 52.0 : 72.0;
        final extent = widget.compact ? 80.0 : 108.0;
        final padding = math.max(
          12.0,
          (constraints.maxWidth - items.length * extent) / 2,
        );
        final target =
            padding +
            (widget.activeIndex + 0.5) * extent -
            constraints.maxWidth / 2;
        if (_target != target) {
          _target = target;
          WidgetsBinding.instance.addPostFrameCallback((_) => _centerActive());
        }
        return SizedBox(
          height: height + (widget.compact ? 4 : 16),
          child: ScrollConfiguration(
            behavior: ScrollConfiguration.of(context).copyWith(
              dragDevices: {
                PointerDeviceKind.touch,
                PointerDeviceKind.mouse,
                PointerDeviceKind.trackpad,
              },
            ),
            child: AnimatedOpacity(
              opacity: _positioned ? 1 : 0,
              duration: widget.duration == Duration.zero
                  ? Duration.zero
                  : const Duration(milliseconds: 120),
              child: ListView.builder(
                controller: _scroll,
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.symmetric(
                  horizontal: padding,
                  vertical: widget.compact ? 2 : 8,
                ),
                itemExtent: extent,
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final item = items[index];
                  return Observer(
                    builder: (context) => _FrameThumbnail(
                      item: item,
                      index: index,
                      active: index == widget.activeIndex,
                      selected: widget.controller.isSelected(item),
                      duration: widget.duration,
                      onTap: () => widget.onBrowse(index),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    ),
  );
}

class _FrameThumbnail extends StatelessWidget {
  const _FrameThumbnail({
    required this.item,
    required this.index,
    required this.active,
    required this.selected,
    required this.duration,
    required this.onTap,
  });
  final ScreenshotCandidate item;
  final int index;
  final bool active;
  final bool selected;
  final Duration duration;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      selected: active,
      label:
          '查看第 ${index + 1} 张，${item.episode} ${item.timeLabel}${selected ? '，已选中' : ''}',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: AnimatedContainer(
              duration: duration,
              curve: Curves.easeInOutCubicEmphasized,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                border: Border.all(
                  color: active ? colors.primary : Colors.transparent,
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(active ? 12 : 8),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    PlayerScreenshotImage(
                      bytes: item.bytes,
                      fit: BoxFit.cover,
                      cacheWidth: screenshotThumbnailCacheWidth,
                    ),
                    if (selected)
                      Positioned(
                        right: 3,
                        bottom: 3,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: colors.primary,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: colors.surface,
                              width: 1.5,
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(2),
                            child: Icon(
                              Icons.check_rounded,
                              size: 14,
                              color: colors.onPrimary,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
