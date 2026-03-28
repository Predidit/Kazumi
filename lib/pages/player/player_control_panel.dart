import 'package:flutter/material.dart';

class PlayerControlPanel extends StatelessWidget {
  const PlayerControlPanel({
    super.key,
    required this.visible,
    required this.panelWidth,
    required this.child,
    this.onClose,
    this.duration = const Duration(milliseconds: 120),
  });

  final bool visible;
  final double panelWidth;
  final Widget child;
  final VoidCallback? onClose;
  final Duration duration;
  static const double _innerEdgeFadeWidth = 40.0;
  static const Color _panelBackgroundColor = Color(0xB3000000);
  static const LinearGradient _leftEdgeFadeGradient = LinearGradient(
    begin: Alignment.centerRight,
    end: Alignment.centerLeft,
    colors: [
      Color(0xB3000000),
      Color(0x5B000000),
      Color(0x27000000),
      Color(0x0B000000),
      Color(0x02000000),
      Color(0x00000000),
    ],
    stops: [0.0, 0.2, 0.4, 0.6, 0.8, 1.0],
  );

  @override
  Widget build(BuildContext context) {
    const Offset hiddenOffset = Offset(1, 0);

    return Positioned.fill(
      child: IgnorePointer(
        ignoring: !visible,
        child: AnimatedOpacity(
          opacity: visible ? 1 : 0,
          duration: duration,
          curve: Curves.easeIn,
          child: Row(
            children: [
              _buildDismissArea(),
              _buildPanel(context, hiddenOffset),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDismissArea() {
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onClose,
        onSecondaryTap: onClose,
        child: const SizedBox.expand(),
      ),
    );
  }

  Widget _buildPanel(BuildContext context, Offset hiddenOffset) {
    final baseTheme = Theme.of(context);
    final darkColorScheme = baseTheme.colorScheme.brightness == Brightness.dark
        ? baseTheme.colorScheme
        : ColorScheme.fromSeed(
            seedColor: baseTheme.colorScheme.primary,
            brightness: Brightness.dark,
          );
    final panelTheme = baseTheme.copyWith(
      brightness: Brightness.dark,
      colorScheme: darkColorScheme,
      scaffoldBackgroundColor: Colors.transparent,
      canvasColor: Colors.transparent,
    );

    final double totalPanelWidth = panelWidth + _innerEdgeFadeWidth;

    return SizedBox(
      width: totalPanelWidth,
      child: AnimatedSlide(
        offset: visible ? Offset.zero : hiddenOffset,
        duration: duration,
        curve: Curves.easeOut,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Positioned(
              top: 0,
              right: 0,
              bottom: 0,
              width: panelWidth,
              child: const DecoratedBox(
                decoration: BoxDecoration(
                  color: _panelBackgroundColor,
                ),
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              bottom: 0,
              width: _innerEdgeFadeWidth,
              child: const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: _leftEdgeFadeGradient,
                ),
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: SizedBox(
                width: panelWidth,
                child: MediaQuery.removePadding(
                  context: context,
                  removeLeft: true,
                  removeRight: true,
                  child: Theme(
                    data: panelTheme,
                    child: child,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
