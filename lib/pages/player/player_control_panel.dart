import 'package:flutter/material.dart';

class PlayerControlPanel extends StatelessWidget {
  const PlayerControlPanel({
    super.key,
    required this.visible,
    required this.panelWidth,
    required this.child,
    this.onClose,
    this.duration = const Duration(milliseconds: 200),
  });

  final bool visible;
  final double panelWidth;
  final Widget child;
  final VoidCallback? onClose;
  final Duration duration;
  static const Color _panelBackgroundColor = Color(0xCC000000);

  @override
  Widget build(BuildContext context) {
    const Offset hiddenOffset = Offset(1, 0);

    return Positioned.fill(
      child: IgnorePointer(
        ignoring: !visible,
        child: AnimatedOpacity(
          opacity: visible ? 1 : 0,
          duration: duration,
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

    return SizedBox(
      width: panelWidth,
      child: AnimatedSlide(
        offset: visible ? Offset.zero : hiddenOffset,
        duration: duration,
        curve: Curves.easeOutCubic,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Container(color: _panelBackgroundColor),

            MediaQuery.removePadding(
              context: context,
              removeLeft: true,
              removeRight: true,
              child: Theme(
                data: panelTheme,
                child: child,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
