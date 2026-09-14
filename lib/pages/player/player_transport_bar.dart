import 'package:audio_video_progress_bar/audio_video_progress_bar.dart';
import 'package:flutter/material.dart';

enum PlayerTimeLabelPlacement {
  aboveProgress,
  besideProgress,
  afterPlaybackButtons;

  static PlayerTimeLabelPlacement forViewport(Size viewport,
      {required bool desktop}) {
    if (desktop) return afterPlaybackButtons;
    final hasRoomForSideLabels = viewport.shortestSide >= 600 &&
        viewport.shortestSide / viewport.longestSide >= 9 / 16;
    return hasRoomForSideLabels ? besideProgress : aboveProgress;
  }
}

class PlayerTransportBar extends StatelessWidget {
  const PlayerTransportBar({
    super.key,
    required this.compact,
    required this.playPause,
    required this.nextEpisode,
    required this.progressBuilder,
    required this.timeLabel,
    required this.timePlacement,
    required this.controls,
    required this.fullscreen,
  });

  final bool compact;
  final Widget playPause;
  final Widget nextEpisode;
  final Widget Function(TimeLabelLocation location) progressBuilder;
  final Widget timeLabel;
  final PlayerTimeLabelPlacement timePlacement;
  final Widget controls;
  final Widget fullscreen;

  @override
  Widget build(BuildContext context) => compact
      ? Row(children: [
          playPause,
          Expanded(child: progressBuilder(TimeLabelLocation.none)),
          timeLabel,
          fullscreen,
        ])
      : Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (timePlacement == PlayerTimeLabelPlacement.aboveProgress)
              Padding(
                padding: const EdgeInsets.only(left: 10, bottom: 10),
                child: timeLabel,
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: progressBuilder(
                timePlacement == PlayerTimeLabelPlacement.besideProgress
                    ? TimeLabelLocation.sides
                    : TimeLabelLocation.none,
              ),
            ),
            Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Row(children: [
                  playPause,
                  nextEpisode,
                  if (timePlacement ==
                      PlayerTimeLabelPlacement.afterPlaybackButtons)
                    Padding(
                        padding: const EdgeInsets.only(left: 10),
                        child: timeLabel),
                  Expanded(child: controls),
                  fullscreen,
                ])),
            if (timePlacement != PlayerTimeLabelPlacement.aboveProgress)
              const SizedBox(height: 6),
          ],
        );
}
