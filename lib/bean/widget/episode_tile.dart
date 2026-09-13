import 'package:flutter/material.dart';
import 'package:kazumi/bean/widget/tv_focusable_surface.dart';
import 'package:kazumi/services/platform/tv_mode.dart';

/// The playing indicator is persistent state; the outer frame is focus only.
class EpisodeTile extends StatelessWidget {
  static const _tvFontSize = 12.0;
  static const _tvLineHeight = 1.4;

  /// Two lines plus focus frame (10), inner padding (10) and row margin (2).
  /// Keep the compact grid usable with TV accessibility text scaling too.
  static double tvGridMainAxisExtent(BuildContext context) => (22 +
          MediaQuery.textScalerOf(context).scale(_tvFontSize) *
              _tvLineHeight *
              2)
      .ceilToDouble();

  const EpisodeTile(
      {super.key,
      required this.label,
      required this.isPlaying,
      required this.onPressed,
      this.focusNode,
      this.onKeyEvent,
      this.status = const SizedBox.shrink()});

  final String label;
  final bool isPlaying;
  final VoidCallback onPressed;
  final FocusNode? focusNode;
  final FocusOnKeyEventCallback? onKeyEvent;
  final Widget status;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      selected: isPlaying,
      label: isPlaying ? '正在播放' : null,
      child: TvFocusableSurface(
        focusScale: 1,
        focusNode: focusNode,
        autofocus: TvMode.enabled && isPlaying,
        borderRadius: 6,
        onPressed: onPressed,
        onKeyEvent: onKeyEvent,
        child: Material(
          color: colors.onInverseSurface
              .withValues(alpha: TvMode.enabled ? 0.30 : 1),
          borderRadius: BorderRadius.circular(6),
          clipBehavior: Clip.hardEdge,
          child: InkWell(
            canRequestFocus: !TvMode.enabled,
            onTap: onPressed,
            child: Padding(
              padding: EdgeInsets.symmetric(
                  vertical: TvMode.enabled ? 5 : 8,
                  horizontal: TvMode.enabled ? 8 : 10),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      if (isPlaying) ...[
                        Icon(Icons.graphic_eq_rounded,
                            color: colors.primary, size: 12),
                        const SizedBox(width: 6),
                      ],
                      Expanded(
                          child: Text(label,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: TvMode.enabled ? _tvFontSize : 13,
                                  height: TvMode.enabled ? _tvLineHeight : null,
                                  color: isPlaying
                                      ? colors.primary
                                      : colors.onSurface))),
                      status,
                      const SizedBox(width: 2),
                    ]),
                  ]),
            ),
          ),
        ),
      ),
    );
  }
}
