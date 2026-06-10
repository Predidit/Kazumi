import 'dart:async';
import 'package:canvas_danmaku/canvas_danmaku.dart';
import 'package:flutter/material.dart';
import 'package:kazumi/modules/danmaku/danmaku_module.dart';
import 'package:kazumi/pages/player/controller/player_danmaku_controller.dart';
import 'package:kazumi/pages/player/player_controller.dart';
import 'package:kazumi/pages/video/video_controller.dart';
import 'package:kazumi/pages/my/my_controller.dart';
import 'package:kazumi/services/storage/storage.dart';
import 'package:kazumi/utils/constants.dart';

/// Result of [PlayerDanmakuHandler.toggle], indicating what the caller
/// (the State) should do after the toggle.
enum DanmakuToggleResult {
  turnedOff,
  turnedOn,
  needsSource,
}

/// Extracted danmaku state and logic from PlayerItem's State.
///
/// Holds all danmaku rendering configuration, emits danmaku entries on the
/// canvas controller each playback tick, and builds the [DanmakuScreen] widget.
/// Dialog methods (search / source switch) remain in the State because they
/// need [BuildContext].
class PlayerDanmakuHandler {
  PlayerDanmakuHandler({
    required this.playerController,
    required this.videoPageController,
    required this.myController,
    required this.isCompact,
    required this.mounted,
  });

  final PlayerController playerController;
  final VideoPageController videoPageController;
  final MyController myController;
  final bool Function() isCompact;
  final bool Function() mounted;

  // ---- Danmaku rendering state ------------------------------------------------

  final danmuKey = GlobalKey();
  late bool border;
  late double opacity;
  late double fontSize;
  late double danmakuArea;
  late bool hideTop;
  late bool hideBottom;
  late bool hideScroll;
  late bool massiveMode;
  late bool danmakuColor;
  late bool danmakuBiliBiliSource;
  late bool danmakuGamerSource;
  late bool danmakuDanDanSource;
  late double danmakuDuration;
  late double danmakuLineHeight;
  late int danmakuFontWeight;
  late bool danmakuUseSystemFont;
  late double danmakuBorderSize;

  // ---- Initialization ---------------------------------------------------------

  /// Load all danmaku settings from [GStorage]. Call once during initState.
  void loadSettings() {
    playerController.danmaku.danmakuOn =
        GStorage.getSetting(SettingsKeys.danmakuEnabledByDefault);
    border = GStorage.getSetting(SettingsKeys.danmakuBorder);
    opacity = GStorage.getSetting(SettingsKeys.danmakuOpacity);
    fontSize = GStorage.getSetting(
      SettingsKeys.danmakuFontSize,
      context: SettingContext(compactLayout: isCompact()),
    );
    danmakuArea = GStorage.getSetting(SettingsKeys.danmakuArea);
    hideTop = !GStorage.getSetting(SettingsKeys.danmakuTop);
    hideBottom = !GStorage.getSetting(SettingsKeys.danmakuBottom);
    hideScroll = !GStorage.getSetting(SettingsKeys.danmakuScroll);
    massiveMode = GStorage.getSetting(SettingsKeys.danmakuMassive);
    danmakuColor = GStorage.getSetting(SettingsKeys.danmakuColor);
    danmakuDuration = GStorage.getSetting(SettingsKeys.danmakuDuration);
    danmakuLineHeight = GStorage.getSetting(SettingsKeys.danmakuLineHeight);
    danmakuBiliBiliSource =
        GStorage.getSetting(SettingsKeys.danmakuBiliBiliSource);
    danmakuGamerSource = GStorage.getSetting(SettingsKeys.danmakuGamerSource);
    danmakuDanDanSource =
        GStorage.getSetting(SettingsKeys.danmakuDanDanSource);
    danmakuFontWeight = GStorage.getSetting(SettingsKeys.danmakuFontWeight);
    danmakuUseSystemFont = GStorage.getSetting(SettingsKeys.useSystemFont);
    danmakuBorderSize = GStorage.getSetting(SettingsKeys.danmakuBorderSize);
  }

  // ---- Toggle -----------------------------------------------------------------

  /// Toggle danmaku on/off. Returns the result so the caller can decide
  /// whether to show the danmaku-source dialog (which requires [BuildContext]).
  DanmakuToggleResult toggle() {
    playerController.danmaku.canvasController.clear();
    if (playerController.danmaku.danmakuOn) {
      playerController.danmaku.danmakuOn = false;
      GStorage.putSetting(SettingsKeys.danmakuEnabledByDefault, false);
      return DanmakuToggleResult.turnedOff;
    }
    if (playerController.danmaku.danDanmakus.isEmpty) {
      return DanmakuToggleResult.needsSource;
    }
    playerController.danmaku.danmakuOn = true;
    GStorage.putSetting(SettingsKeys.danmakuEnabledByDefault, true);
    return DanmakuToggleResult.turnedOn;
  }

  // ---- Source filtering & type mapping ---------------------------------------

  bool isSourceEnabled(DanmakuEntry danmaku) {
    if (!danmakuBiliBiliSource && danmaku.source.contains('BiliBili')) {
      return false;
    }
    if (!danmakuGamerSource && danmaku.source.contains('Gamer')) {
      return false;
    }
    if (!danmakuDanDanSource &&
        !(danmaku.source.contains('BiliBili') ||
            danmaku.source.contains('Gamer'))) {
      return false;
    }
    return true;
  }

  DanmakuItemType danmakuItemTypeFor(DanmakuEntry danmaku) {
    if (danmaku.type == 4) return DanmakuItemType.bottom;
    if (danmaku.type == 5) return DanmakuItemType.top;
    return DanmakuItemType.scroll;
  }

  // ---- Per-tick emission -----------------------------------------------------

  /// Called every second from the player timer. Emits matching danmaku entries
  /// onto the canvas controller with staggered delays.
  void emitDanmakusForCurrentPosition() {
    if (playerController.playback.currentPosition.inMicroseconds == 0 ||
        playerController.playback.playerPlaying != true ||
        playerController.danmaku.danmakuOn != true) {
      return;
    }

    final danmakus = playerController.danmaku
        .danmakusForPlaybackPosition(playerController.playback.currentPosition);
    final danmakuCount = danmakus.length;
    for (final entry in danmakus.asMap().entries) {
      final idx = entry.key;
      final danmaku = entry.value;
      if (!isSourceEnabled(danmaku)) continue;

      final color = danmakuColor ? danmaku.color : Colors.white;
      final delay = DanmakuTimeline.staggerDelayMilliseconds(
        index: idx,
        total: danmakuCount,
      );
      final scheduledDanmakuGeneration =
          playerController.danmaku.scheduledDanmakuGeneration;
      Future.delayed(Duration(milliseconds: delay), () {
        if (!mounted() ||
            !playerController.playback.playerPlaying ||
            playerController.playback.playerBuffering ||
            !playerController.danmaku.danmakuOn ||
            playerController.danmaku.scheduledDanmakuGeneration !=
                scheduledDanmakuGeneration ||
            myController.isDanmakuBlocked(danmaku.message)) {
          return;
        }
        playerController.danmaku.canvasController.addDanmaku(
          DanmakuContentItem(
            danmaku.message,
            color: color,
            type: danmakuItemTypeFor(danmaku),
          ),
        );
      });
    }
  }

  // ---- Widget builder --------------------------------------------------------

  /// Build the [DanmakuScreen] positioned for the current video area.
  Widget buildDanmakuScreen(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      height: videoPageController.isFullscreen || videoPageController.isPip
          ? MediaQuery.sizeOf(context).height
          : (MediaQuery.sizeOf(context).width * 9 / 16),
      child: DanmakuScreen(
        key: danmuKey,
        createdController: (DanmakuController e) {
          playerController.danmaku.canvasController = e;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            playerController.updateDanmakuSpeed();
          });
        },
        option: DanmakuOption(
          hideTop: hideTop,
          hideScroll: hideScroll,
          hideBottom: hideBottom,
          area: danmakuArea,
          opacity: opacity,
          fontSize: fontSize,
          duration: danmakuDuration / playerController.playback.playerSpeed,
          lineHeight: danmakuLineHeight,
          strokeWidth: border ? danmakuBorderSize : 0.0,
          fontWeight: danmakuFontWeight,
          massiveMode: massiveMode,
          fontFamily: danmakuUseSystemFont ? null : customAppFontFamily,
        ),
      ),
    );
  }
}
