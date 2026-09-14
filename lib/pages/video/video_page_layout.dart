import 'package:flutter/material.dart';

typedef VideoPlayerLayout = ({bool fillsWindow, bool hasSidePanel});

/// Fullscreen fills the available window; rotation belongs to the OS.
class VideoPageLayout extends StatelessWidget {
  const VideoPageLayout({
    super.key,
    required this.fullscreen,
    required this.isPip,
    required this.playerBuilder,
    required this.tabs,
    this.sidePanel,
  });

  final bool fullscreen;
  final bool isPip;
  final Widget Function(BuildContext context, VideoPlayerLayout layout)
      playerBuilder;
  final Widget tabs;
  final Widget? sidePanel;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final fillsWindow =
          fullscreen || isPip || constraints.maxWidth > constraints.maxHeight;
      final hasSidePanel = fillsWindow && !isPip && sidePanel != null;
      return SafeArea(
        top: !fillsWindow,
        bottom: !fillsWindow,
        left: !fillsWindow,
        right: !fillsWindow,
        child: Stack(
          alignment: Alignment.centerRight,
          children: [
            Column(
              children: [
                Flexible(
                  flex: fillsWindow ? 1 : 0,
                  child: SizedBox(
                    height: fillsWindow ? double.infinity : null,
                    width: double.infinity,
                    child: AspectRatio(
                      aspectRatio: 16 / 9,
                      child: Builder(
                          builder: (context) => playerBuilder(context, (
                                fillsWindow: fillsWindow,
                                hasSidePanel: hasSidePanel
                              ))),
                    ),
                  ),
                ),
                if (!fillsWindow) Expanded(child: tabs),
              ],
            ),
            if (hasSidePanel) sidePanel!,
          ],
        ),
      );
    });
  }
}
