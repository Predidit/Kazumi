import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:kazumi/utils/storage.dart';
import 'package:kazumi/utils/utils.dart';
import 'package:window_manager/window_manager.dart';

const double windowControlOverlayReservedWidth = 132.0;

class WindowControlOverlayVisibilityController {
  static final ValueNotifier<bool?> _visibleOverride =
      ValueNotifier<bool?>(null);
  static final ValueNotifier<double?> _topShiftOverride =
      ValueNotifier<double?>(null);
  static final ValueNotifier<bool?> _lightAppearanceOverride =
      ValueNotifier<bool?>(null);

  static bool? _pendingValue;
  static double? _pendingTopShift;
  static bool? _pendingLightAppearance;
  static bool _flushScheduled = false;

  static ValueNotifier<bool?> get visibleOverride => _visibleOverride;
  static ValueNotifier<double?> get topShiftOverride => _topShiftOverride;
  static ValueNotifier<bool?> get lightAppearanceOverride =>
      _lightAppearanceOverride;

  static void setVisible(bool visible) {
    _requestValue(visible: visible, updateVisible: true);
  }

  static void clear() {
    _requestValue(visible: null, updateVisible: true);
  }

  static void setTopShift(double shift) {
    _requestValue(topShift: shift, updateTopShift: true);
  }

  static void clearTopShift() {
    _requestValue(topShift: null, updateTopShift: true);
  }

  static void setLightAppearance(bool enabled) {
    _requestValue(
      lightAppearance: enabled,
      updateLightAppearance: true,
    );
  }

  static void clearLightAppearance() {
    _requestValue(
      lightAppearance: null,
      updateLightAppearance: true,
    );
  }

  static void _requestValue({
    bool? visible,
    bool updateVisible = false,
    double? topShift,
    bool updateTopShift = false,
    bool? lightAppearance,
    bool updateLightAppearance = false,
  }) {
    if (updateVisible) {
      _pendingValue = visible;
    }
    if (updateTopShift) {
      _pendingTopShift = topShift;
    }
    if (updateLightAppearance) {
      _pendingLightAppearance = lightAppearance;
    }
    if (_flushScheduled) {
      return;
    }
    _flushScheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _flushScheduled = false;
      final bool? next = _pendingValue;
      final double? nextTopShift = _pendingTopShift;
      final bool? nextLightAppearance = _pendingLightAppearance;
      if (_visibleOverride.value != next) {
        _visibleOverride.value = next;
      }
      if (_topShiftOverride.value != nextTopShift) {
        _topShiftOverride.value = nextTopShift;
      }
      if (_lightAppearanceOverride.value != nextLightAppearance) {
        _lightAppearanceOverride.value = nextLightAppearance;
      }
      // If state changed again while this frame callback was running, schedule once more.
      if (_pendingValue != _visibleOverride.value ||
          _pendingTopShift != _topShiftOverride.value ||
          _pendingLightAppearance != _lightAppearanceOverride.value) {
        _requestValue(
          visible: _pendingValue,
          updateVisible: true,
          topShift: _pendingTopShift,
          updateTopShift: true,
          lightAppearance: _pendingLightAppearance,
          updateLightAppearance: true,
        );
      }
    });
    SchedulerBinding.instance.ensureVisualUpdate();
  }
}

class WindowControlOverlay extends StatefulWidget {
  const WindowControlOverlay({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  State<WindowControlOverlay> createState() => _WindowControlOverlayState();
}

class _WindowControlOverlayState extends State<WindowControlOverlay>
    with WindowListener {
  bool _isMaximized = false;
  StreamSubscription<dynamic>? _exitBehaviorSubscription;
  bool get _showOverlay {
    if (!Utils.isDesktop()) {
      return false;
    }
    return !GStorage.setting
        .get(SettingBoxKey.showWindowButton, defaultValue: false);
  }

  bool get _closeMeansMinimizeToTray {
    final int exitBehavior =
        GStorage.setting.get(SettingBoxKey.exitBehavior, defaultValue: 2);
    return exitBehavior == 1;
  }

  @override
  void initState() {
    super.initState();
    _exitBehaviorSubscription =
        GStorage.setting.watch(key: SettingBoxKey.exitBehavior).listen((_) {
      if (mounted) {
        setState(() {});
      }
    });
    if (Utils.isDesktop()) {
      windowManager.addListener(this);
      _syncWindowState();
    }
  }

  @override
  void dispose() {
    _exitBehaviorSubscription?.cancel();
    if (Utils.isDesktop()) {
      windowManager.removeListener(this);
    }
    super.dispose();
  }

  @override
  void onWindowMaximize() {
    _setMaximized(true);
  }

  @override
  void onWindowUnmaximize() {
    _setMaximized(false);
  }

  @override
  void onWindowRestore() {
    _syncWindowState();
  }

  void _setMaximized(bool value) {
    if (!mounted) {
      return;
    }
    setState(() {
      _isMaximized = value;
    });
  }

  Future<void> _syncWindowState() async {
    final bool isMaximized = await windowManager.isMaximized();
    _setMaximized(isMaximized);
  }

  Future<void> _toggleMaximize() async {
    final bool isMaximized = await windowManager.isMaximized();
    if (isMaximized) {
      await windowManager.unmaximize();
    } else {
      await windowManager.maximize();
    }
    await _syncWindowState();
  }

  @override
  Widget build(BuildContext context) {
    if (!_showOverlay) {
      return widget.child;
    }
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    return AnimatedBuilder(
      animation: Listenable.merge([
        WindowControlOverlayVisibilityController.visibleOverride,
        WindowControlOverlayVisibilityController.topShiftOverride,
        WindowControlOverlayVisibilityController.lightAppearanceOverride,
      ]),
      builder: (context, _) {
        final bool visible =
            WindowControlOverlayVisibilityController.visibleOverride.value ??
                true;
        final double topShift =
            WindowControlOverlayVisibilityController.topShiftOverride.value ??
                0;
        final bool lightAppearance = WindowControlOverlayVisibilityController
                .lightAppearanceOverride.value ??
            false;
        final Color iconColor = lightAppearance
            ? Colors.white.withValues(alpha: 0.92)
            : colorScheme.onSurface;
        final bool closeMeansMinimizeToTray = _closeMeansMinimizeToTray;
        return Stack(
          children: [
            widget.child,
            Positioned(
              top: 0,
              right: -3,
              child: IgnorePointer(
                ignoring: !visible,
                child: AnimatedSlide(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  offset: visible ? Offset.zero : const Offset(0, -1),
                  child: Padding(
                    padding: EdgeInsets.only(
                      top: 8 + MediaQuery.paddingOf(context).top + topShift,
                    ),
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onPanStart: (_) => windowManager.startDragging(),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 3),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _WindowControlButton(
                              lightAppearance: lightAppearance,
                              onPressed: () => windowManager.minimize(),
                              icon: _GlyphIcon(
                                painter: _MinimizeGlyphPainter(
                                  color: iconColor,
                                ),
                              ),
                            ),
                            _WindowControlButton(
                              lightAppearance: lightAppearance,
                              onPressed: _toggleMaximize,
                              icon: _GlyphIcon(
                                painter: _MaximizeGlyphPainter(
                                  color: iconColor,
                                  showRestore: _isMaximized,
                                ),
                              ),
                            ),
                            _WindowControlButton(
                              lightAppearance: lightAppearance,
                              danger: !closeMeansMinimizeToTray,
                              onPressed: () => windowManager.close(),
                              icon: _GlyphIcon(
                                painter: closeMeansMinimizeToTray
                                    ? _TrayMinimizeGlyphPainter(
                                        color: iconColor)
                                    : _CloseGlyphPainter(
                                        color: iconColor,
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
            ),
          ],
        );
      },
    );
  }
}

class _WindowControlButton extends StatelessWidget {
  const _WindowControlButton({
    required this.onPressed,
    required this.icon,
    this.danger = false,
    this.lightAppearance = false,
  });

  final Future<void> Function() onPressed;
  final Widget icon;
  final bool danger;
  final bool lightAppearance;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        hoverColor: danger
            ? (lightAppearance
                ? const Color(0xFFC42B1C).withValues(alpha: 0.85)
                : colorScheme.errorContainer.withValues(alpha: 0.5))
            : (lightAppearance
                ? Colors.white.withValues(alpha: 0.15)
                : colorScheme.primaryContainer.withValues(alpha: 0.5)),
        onTap: onPressed,
        child: SizedBox(
          width: 44,
          height: 32,
          child: Center(child: icon),
        ),
      ),
    );
  }
}

class _GlyphIcon extends StatelessWidget {
  const _GlyphIcon({
    required this.painter,
  });

  final CustomPainter painter;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(16, 16),
      painter: painter,
    );
  }
}

class _MinimizeGlyphPainter extends CustomPainter {
  const _MinimizeGlyphPainter({
    required this.color,
  });

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.7
      ..strokeCap = StrokeCap.round;
    final double y = size.height / 2;
    canvas.drawLine(Offset(2, y), Offset(size.width - 2, y), paint);
  }

  @override
  bool shouldRepaint(covariant _MinimizeGlyphPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

class _MaximizeGlyphPainter extends CustomPainter {
  const _MaximizeGlyphPainter({
    required this.color,
    required this.showRestore,
  });

  final Color color;
  final bool showRestore;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.6
      ..style = PaintingStyle.stroke;
    const Radius radius = Radius.circular(1.8);
    if (!showRestore) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(2.4, 2.4, size.width - 4.8, size.height - 4.8),
          radius,
        ),
        paint,
      );
      return;
    }

    final RRect frontRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(2.4, 4.8, size.width - 7.2, size.height - 7.2),
      radius,
    );
    final RRect backRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(4.8, 2.4, size.width - 7.2, size.height - 7.2),
      radius,
    );

    final Path visibleBackArea = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addRRect(frontRect);

    canvas.save();
    canvas.clipPath(visibleBackArea);
    canvas.drawRRect(
      backRect,
      paint,
    );
    canvas.restore();

    canvas.drawRRect(frontRect, paint);
  }

  @override
  bool shouldRepaint(covariant _MaximizeGlyphPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.showRestore != showRestore;
  }
}

class _CloseGlyphPainter extends CustomPainter {
  const _CloseGlyphPainter({
    required this.color,
  });

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      const Offset(2.4, 2.4),
      Offset(size.width - 2.4, size.height - 2.4),
      paint,
    );
    canvas.drawLine(
      Offset(size.width - 2.4, 2.4),
      Offset(2.4, size.height - 2.4),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _CloseGlyphPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

class _TrayMinimizeGlyphPainter extends CustomPainter {
  const _TrayMinimizeGlyphPainter({
    required this.color,
  });

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    // Match maximize icon visual box and draw double downward chevrons.
    final double leftX = 2.4;
    final double rightX = size.width - 2.4;
    final double centerX = size.width / 2;

    final Offset topLeft1 = Offset(leftX, 2.4);
    final Offset topRight1 = Offset(rightX, 2.4);
    final Offset bottom1 = Offset(centerX, size.height * 0.50);
    canvas.drawLine(topLeft1, bottom1, paint);
    canvas.drawLine(bottom1, topRight1, paint);

    final Offset topLeft2 = Offset(leftX, size.height * 0.44);
    final Offset topRight2 = Offset(rightX, size.height * 0.44);
    final Offset bottom2 = Offset(centerX, size.height - 2.4);
    canvas.drawLine(topLeft2, bottom2, paint);
    canvas.drawLine(bottom2, topRight2, paint);
  }

  @override
  bool shouldRepaint(covariant _TrayMinimizeGlyphPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
