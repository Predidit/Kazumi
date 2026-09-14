import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:canvas_danmaku/models/danmaku_content_item.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:kazumi/bean/widget/play_pause_icon.dart';
import 'package:kazumi/pages/player/player_adjustment_hud.dart';
import 'package:kazumi/pages/player/danmaku_destination_sheet.dart';
import 'package:kazumi/pages/player/controller/player_aspect_ratio.dart';
import 'package:kazumi/pages/player/controller/player_super_resolution.dart';
import 'package:kazumi/bean/widget/embedded_native_control_area.dart';
import 'package:kazumi/pages/player/player_panel_hold.dart';
import 'package:kazumi/services/player/pip_utils.dart';
import 'package:kazumi/pages/video/video_controller.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/pages/player/player_controller.dart';
import 'package:flutter/services.dart';
import 'package:kazumi/services/player/remote.dart';
import 'package:kazumi/bean/appbar/drag_to_move_bar.dart' as dtb;
import 'package:kazumi/pages/settings/danmaku/danmaku_settings_sheet.dart';
import 'package:kazumi/utils/constants.dart';
import 'package:audio_video_progress_bar/audio_video_progress_bar.dart';
import 'package:kazumi/services/player/timed_shutdown_service.dart';
import 'package:kazumi/utils/format.dart';
import 'package:kazumi/pages/player/player_transport_bar.dart';

class PlayerItemPanel extends StatefulWidget {
  const PlayerItemPanel({
    super.key,
    required this.playerController,
    required this.videoPageController,
    required this.fillsWindow,
    required this.onBackPressed,
    required this.setPlaybackSpeed,
    required this.showDanmakuSwitch,
    required this.handleFullscreen,
    required this.enterAndroidPictureInPicture,
    required this.handleScreenShot,
    required this.onNextEpisode,
    required this.handleProgressBarDragStart,
    required this.handleProgressBarSeek,
    required this.handleSuperResolutionChange,
    required this.panelVisibilityController,
    this.onToggleSidePanel,
    required this.keyboardFocus,
    required this.acquirePlayerPanelHold,
    required this.onMenuVisibilityChanged,
    required this.handleDanmaku,
    required this.skipOP,
    required this.showVideoInfo,
    required this.showSyncPlayPanel,
    required this.pauseForTimedShutdown,
    this.disableAnimations = false,
  });

  final PlayerController playerController;
  final VideoPageController videoPageController;
  final bool fillsWindow;
  final VoidCallback onBackPressed;
  final Future<void> Function(double) setPlaybackSpeed;
  final VoidCallback showDanmakuSwitch;
  final VoidCallback? onToggleSidePanel;
  final VoidCallback handleFullscreen;
  final Future<void> Function() enterAndroidPictureInPicture;
  final VoidCallback handleScreenShot;
  final VoidCallback handleProgressBarDragStart;
  final Future<void> Function(Duration duration) handleProgressBarSeek;
  final Future<void> Function(SuperResolutionMode mode)
      handleSuperResolutionChange;
  final AnimationController panelVisibilityController;
  final FocusNode keyboardFocus;
  final PlayerPanelHold Function() acquirePlayerPanelHold;
  final ValueChanged<bool> onMenuVisibilityChanged;
  final VoidCallback handleDanmaku;
  final VoidCallback onNextEpisode;
  final VoidCallback skipOP;
  final VoidCallback showVideoInfo;
  final VoidCallback showSyncPlayPanel;
  final VoidCallback pauseForTimedShutdown;
  final bool disableAnimations;

  @override
  State<PlayerItemPanel> createState() => _PlayerItemPanelState();
}

class _PlayerItemPanelState extends State<PlayerItemPanel> {
  late final Animation<Offset> _topOffsetAnimation;
  late final Animation<Offset> _bottomOffsetAnimation;
  late final Animation<Offset> _rightOffsetAnimation;
  late final VideoPageController videoPageController =
      widget.videoPageController;
  late final PlayerController playerController;
  final TextEditingController textController = TextEditingController();
  final FocusNode textFieldFocus = FocusNode();

  String? _cachedDanmakuColorHex;
  late Widget _cachedDanmakuOnIcon;
  late final Widget _cachedDanmakuOffIcon;
  late final Widget _cachedDanmakuSettingsIcon;

  bool get _desktop => switch (defaultTargetPlatform) {
        TargetPlatform.windows ||
        TargetPlatform.linux ||
        TargetPlatform.macOS =>
          true,
        _ => false,
      };

  static const double _danmakuIconSize = 24.0;
  static const double _loadingIndicatorStrokeWidth = 2.0;

  @override
  void dispose() {
    textController.dispose();
    textFieldFocus.dispose();
    super.dispose();
  }

  Future<void> _submitDanmakuText(String message) async {
    textFieldFocus.unfocus();

    if (message.trim().isEmpty) {
      KazumiDialog.showToast(message: '弹幕内容为空');
      return;
    }

    final destination = await showDanmakuDestinationSheet(context);
    if (!mounted || destination == null) {
      return;
    }

    widget.keyboardFocus.requestFocus();
    if (playerController.danmaku.danDanmakus.isEmpty) {
      KazumiDialog.showToast(message: '当前剧集不支持弹幕发送的说');
      return;
    }
    if (message.length > 100) {
      KazumiDialog.showToast(message: '弹幕内容过长');
      return;
    }

    if (destination == DanmakuDestination.chatRoom) {
      if (playerController.syncplay.syncplayRoom.isEmpty) {
        KazumiDialog.showToast(message: '你还没有加入一起看，无法发送聊天室弹幕');
        return;
      }

      final sender =
          playerController.syncplay.syncplayController?.username ?? '我';
      playerController.danmaku.canvasController.addDanmaku(
        DanmakuContentItem(
          '$sender：$message',
          color: Colors.orange,
          isColorful: true,
          type: DanmakuItemType.bottom,
          extra: DateTime.now().millisecondsSinceEpoch,
        ),
      );
      unawaited(playerController.sendSyncPlayChatMessage(message));
    } else {
      // This provider has no send API; display a local echo.
      playerController.danmaku.canvasController
          .addDanmaku(DanmakuContentItem(message, selfSend: true));
    }
    textController.clear();
  }

  Widget get _danmakuTextField {
    return Observer(builder: (context) {
      return PlayerPanelHoldFocusRegion(
          acquirePlayerPanelHold: widget.acquirePlayerPanelHold,
          child: Container(
            constraints: _desktop
                ? const BoxConstraints(maxWidth: 500, maxHeight: 33)
                : const BoxConstraints(maxHeight: 33),
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: TextField(
              focusNode: textFieldFocus,
              style:
                  TextStyle(fontSize: _desktop ? 15 : 13, color: Colors.white),
              controller: textController,
              textAlignVertical: TextAlignVertical.center,
              decoration: InputDecoration(
                enabled: playerController.danmaku.danmakuOn,
                filled: true,
                fillColor: Colors.white38,
                floatingLabelBehavior: FloatingLabelBehavior.never,
                hintText: playerController.danmaku.danmakuOn
                    ? '发个友善的弹幕见证当下'
                    : '已关闭弹幕',
                hintStyle: TextStyle(
                    fontSize: _desktop ? 15 : 13, color: Colors.white60),
                alignLabelWithHint: true,
                contentPadding: EdgeInsets.symmetric(
                    vertical: 8, horizontal: _desktop ? 8 : 12),
                border: OutlineInputBorder(
                  borderSide: BorderSide.none,
                  borderRadius:
                      BorderRadius.all(Radius.circular(_desktop ? 8 : 20)),
                ),
                suffixIconConstraints: const BoxConstraints(minWidth: 0),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextButton(
                      onPressed: () {
                        unawaited(_submitDanmakuText(textController.text));
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: playerController.danmaku.danmakuOn
                            ? Theme.of(context).colorScheme.onPrimaryContainer
                            : Colors.white60,
                        backgroundColor: playerController.danmaku.danmakuOn
                            ? Theme.of(context).colorScheme.primaryContainer
                            : Theme.of(context).disabledColor,
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(_desktop ? 8 : 20),
                        ),
                      ),
                      child: const Text('发送'),
                    ),
                  ],
                ),
              ),
              onSubmitted: (msg) {
                unawaited(_submitDanmakuText(msg));
              },
              onTapOutside: (_) {
                textFieldFocus.unfocus();
                widget.keyboardFocus.requestFocus();
              },
            ),
          ));
    });
  }

  void _showForwardChange() {
    KazumiDialog.show(builder: (context) {
      var input = '';
      return AlertDialog(
        title: const Text('跳过秒数'),
        content: TextField(
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
          ],
          decoration: InputDecoration(
            floatingLabelBehavior: FloatingLabelBehavior.never,
            labelText: playerController.playback.buttonSkipTime.toString(),
          ),
          onChanged: (value) {
            input = value;
          },
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => KazumiDialog.dismiss(),
            child: Text(
              '取消',
              style: TextStyle(color: Theme.of(context).colorScheme.outline),
            ),
          ),
          TextButton(
            onPressed: () {
              if (input.isNotEmpty) {
                playerController.setButtonForwardTime(int.parse(input));
              }
              KazumiDialog.dismiss();
            },
            child: const Text('确定'),
          ),
        ],
      );
    });
  }

  @override
  void initState() {
    super.initState();
    playerController = widget.playerController;
    final visibility = widget.panelVisibilityController
        .drive(CurveTween(curve: Curves.easeInOut));
    _topOffsetAnimation = visibility.drive(Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ));
    _bottomOffsetAnimation = visibility.drive(Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ));
    _rightOffsetAnimation = visibility.drive(Tween<Offset>(
      begin: const Offset(1, 0),
      end: Offset.zero,
    ));
    _cachedDanmakuOffIcon = RepaintBoundary(
      child: SvgPicture.asset(
        'assets/images/danmaku_off.svg',
        height: _danmakuIconSize,
      ),
    );

    _cachedDanmakuSettingsIcon = RepaintBoundary(
      child: SvgPicture.asset(
        'assets/images/danmaku_setting.svg',
        height: _danmakuIconSize,
      ),
    );
  }

  Widget _danmakuOnIcon(BuildContext context) {
    final colorHex = Theme.of(context)
        .colorScheme
        .primary
        .toARGB32()
        .toRadixString(16)
        .substring(2);

    if (_cachedDanmakuColorHex != colorHex) {
      _cachedDanmakuColorHex = colorHex;
      final svgString = danmakuOnSvg.replaceFirst('00AEEC', colorHex);
      _cachedDanmakuOnIcon = RepaintBoundary(
        child: SvgPicture.string(
          svgString,
          height: _danmakuIconSize,
        ),
      );
    }

    return _cachedDanmakuOnIcon;
  }

  Widget _buildDanmakuToggleButton(BuildContext context) {
    return Observer(builder: (context) {
      final danmakuLoading = playerController.danmaku.danmakuLoading;
      final danmakuOn = playerController.danmaku.danmakuOn;
      return IconButton(
        color: Colors.white,
        icon: danmakuLoading
            ? SizedBox(
                width: _danmakuIconSize,
                height: _danmakuIconSize,
                child: CircularProgressIndicator(
                  strokeWidth: _loadingIndicatorStrokeWidth,
                ),
              )
            : (danmakuOn ? _danmakuOnIcon(context) : _cachedDanmakuOffIcon),
        onPressed: danmakuLoading ? null : widget.handleDanmaku,
        tooltip: danmakuLoading ? '弹幕加载中...' : (danmakuOn ? '关闭弹幕' : '打开弹幕'),
      );
    });
  }

  Widget _forwardButton() {
    return Tooltip(
      message: '快进${playerController.playback.buttonSkipTime}秒，长按修改时间',
      child: GestureDetector(
        onLongPress: _showForwardChange,
        child: IconButton(
          icon: Image.asset(
            'assets/images/forward_80.png',
            color: Colors.white,
            height: 24,
          ),
          onPressed: widget.skipOP,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) => _buildPanel(
          constraints.maxWidth < MediaQuery.textScalerOf(context).scale(600),
        ),
      );

  Widget _buildPanel(bool compact) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: _buildScrim(
            height: 50,
            colors: const [Colors.black45, Colors.transparent],
            offset: _topOffsetAnimation,
          ),
        ),
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: _buildScrim(
            height: 100,
            colors: const [Colors.transparent, Colors.black45],
            offset: _bottomOffsetAnimation,
          ),
        ),
        Positioned(
          top: 25,
          child: Observer(builder: (context) {
            // Hidden HUDs must not observe playback ticks.
            final visible = playerController.panel.showSeekTime;
            return PlayerSeekHud(
              visible: visible,
              currentPosition: visible
                  ? playerController.playback.currentPosition
                  : Duration.zero,
              playerPosition: visible
                  ? playerController.playback.playerPosition
                  : Duration.zero,
              duration:
                  visible ? playerController.playback.duration : Duration.zero,
              direction: playerController.panel.seekDirection,
              disableAnimations: widget.disableAnimations,
            );
          }),
        ),
        Positioned(
          top: 25,
          child: Observer(builder: (context) {
            return PlayerSpeedHud(
              visible: playerController.panel.showPlaySpeed,
              speed: playerController.playback.playerSpeed,
              disableAnimations: widget.disableAnimations,
            );
          }),
        ),
        Positioned(
          top: 25,
          child: Observer(builder: (context) {
            final showVolume = playerController.panel.showVolume;
            final showBrightness = playerController.panel.showBrightness;
            return PlayerAdjustmentHud(
              visible: showVolume || showBrightness,
              type: showVolume
                  ? PlayerAdjustmentHudType.volume
                  : PlayerAdjustmentHudType.brightness,
              value: showVolume
                  ? playerController.playback.volume
                  : playerController.panel.brightness,
              disableAnimations: widget.disableAnimations,
            );
          }),
        ),
        if (!_desktop)
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            child: Observer(builder: (context) {
              if ((compact || !widget.fillsWindow) &&
                  !playerController.panel.lockPanel) {
                return const SizedBox.shrink();
              }
              return Visibility(
                visible: widget.disableAnimations
                    ? playerController.panel.showVideoController
                    : true,
                child: widget.disableAnimations
                    ? _rightControls
                    : SlideTransition(
                        position: _rightOffsetAnimation, child: _rightControls),
              );
            }),
          ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Observer(builder: (context) {
            return Visibility(
              visible: !playerController.panel.lockPanel &&
                  (widget.disableAnimations
                      ? playerController.panel.showVideoController
                      : true),
              child: widget.disableAnimations
                  ? _buildTopControls(compact)
                  : SlideTransition(
                      position: _topOffsetAnimation,
                      child: _buildTopControls(compact)),
            );
          }),
        ),
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Observer(builder: (context) {
            return Visibility(
              visible: !playerController.panel.lockPanel &&
                  (widget.disableAnimations
                      ? playerController.panel.showVideoController
                      : true),
              child: widget.disableAnimations
                  ? _buildBottomControls(compact)
                  : SlideTransition(
                      position: _bottomOffsetAnimation,
                      child: _buildBottomControls(compact)),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildScrim({
    required double height,
    required List<Color> colors,
    required Animation<Offset> offset,
  }) =>
      Observer(builder: (context) {
        final scrim = Container(
          height: height,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: colors,
            ),
          ),
        );
        return Visibility(
          visible: !playerController.panel.lockPanel &&
              (!widget.disableAnimations ||
                  playerController.panel.showVideoController),
          child: widget.disableAnimations
              ? scrim
              : SlideTransition(position: offset, child: scrim),
        );
      });

  void _showDanmakuSettings() {
    showDanmakuSettingsSheet(
      context: context,
      danmakuController: playerController.danmaku.canvasController,
      onUpdateDanmakuSpeed: playerController.updateDanmakuSpeed,
      onTimelineOffsetChanged:
          playerController.danmaku.clearAndInvalidateScheduledDanmakus,
    );
  }

  List<Widget> _choiceItems<T>(
    Iterable<T> values, {
    required String Function(T) label,
    required bool Function(T) selected,
    required void Function(T) onSelected,
  }) =>
      [
        for (final value in values)
          MenuItemButton(
            onPressed: () => onSelected(value),
            child: _menuLabel(label(value), selected: selected(value)),
          ),
      ];

  List<Widget> get _aspectRatioItems => _choiceItems(
        PlayerAspectRatio.values,
        label: (value) => value.label,
        selected: (value) => value == playerController.panel.aspectRatioMode,
        onSelected: (value) => playerController.panel.aspectRatioMode = value,
      );

  List<Widget> get _speedItems => _choiceItems(
        defaultPlaySpeedList,
        label: (value) => '${value}x',
        selected: (value) => value == playerController.playback.playerSpeed,
        onSelected: widget.setPlaybackSpeed,
      );

  List<Widget> get _superResolutionItems => _choiceItems(
        SuperResolutionMode.values,
        label: (value) => value.label,
        selected: (value) =>
            value == playerController.playback.superResolutionMode,
        onSelected: widget.handleSuperResolutionChange,
      );

  Widget _menuButton(
          {required Widget child,
          required List<Widget> items,
          String? tooltip}) =>
      PlayerPanelHoldMenuAnchor(
        acquirePlayerPanelHold: widget.acquirePlayerPanelHold,
        onVisibilityChanged: widget.onMenuVisibilityChanged,
        consumeOutsideTap: true,
        builder: (context, controller, menuChild) {
          void toggle() =>
              controller.isOpen ? controller.close() : controller.open();
          return tooltip == null
              ? TextButton(onPressed: toggle, child: child)
              : IconButton(onPressed: toggle, icon: child, tooltip: tooltip);
        },
        menuChildren: items,
      );

  Widget get _danmakuSettingsButton => IconButton(
        onPressed: _showDanmakuSettings,
        color: Colors.white,
        icon: _cachedDanmakuSettingsIcon,
        tooltip: '弹幕设置',
      );

  Widget get _desktopDanmakuControls => LayoutBuilder(
        builder: (context, constraints) => Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildDanmakuToggleButton(context),
              _danmakuSettingsButton,
              if (constraints.maxWidth > 600) _danmakuTextField,
            ],
          ),
        ),
      );

  Widget get _syncPlayMenuItem => MenuItemButton(
        onPressed: widget.showSyncPlayPanel,
        child: _menuLabel('一起看'),
      );

  Widget get _danmakuSettingsMenuItem => MenuItemButton(
        onPressed: _showDanmakuSettings,
        child: _menuLabel('弹幕设置'),
      );

  Widget _menuLabel(String label, {bool selected = false}) => Container(
        height: 48,
        constraints: const BoxConstraints(minWidth: 112),
        alignment: Alignment.centerLeft,
        child: Text(label,
            style: selected
                ? TextStyle(color: Theme.of(context).colorScheme.primary)
                : null),
      );

  Widget get _wideControls => Row(children: [
        if (_desktop) Expanded(child: _desktopDanmakuControls),
        if (!_desktop) ...[
          IconButton(
            color: Colors.white,
            icon: playerController.danmaku.danmakuOn
                ? _danmakuOnIcon(context)
                : _cachedDanmakuOffIcon,
            onPressed: widget.handleDanmaku,
            tooltip: playerController.danmaku.danmakuOn ? '关闭弹幕' : '打开弹幕',
          ),
          if (playerController.danmaku.danmakuOn) ...[
            _danmakuSettingsButton,
            Expanded(child: _danmakuTextField),
          ] else
            const Spacer(),
        ],
        _menuButton(
          child: const Text('超分辨率', style: TextStyle(color: Colors.white)),
          items: _superResolutionItems,
        ),
        _menuButton(
          child: Text(
              playerController.playback.playerSpeed == 1
                  ? '倍速'
                  : '${playerController.playback.playerSpeed}x',
              style: const TextStyle(color: Colors.white)),
          items: _speedItems,
        ),
        _menuButton(
          child: const Icon(Icons.aspect_ratio_rounded, color: Colors.white),
          tooltip: '视频比例',
          items: _aspectRatioItems,
        ),
        if (widget.onToggleSidePanel != null)
          IconButton(
            color: Colors.white,
            icon: const Icon(Icons.menu_open_rounded),
            tooltip: '选集面板',
            onPressed: widget.onToggleSidePanel,
          ),
      ]);

  Widget _buildBottomControls(bool compact) => SafeArea(
        top: false,
        bottom: !compact && widget.fillsWindow,
        left: !compact && widget.fillsWindow,
        right: !compact && widget.fillsWindow,
        child: PlayerPanelHoldMouseRegion(
          acquirePlayerPanelHold: widget.acquirePlayerPanelHold,
          cursor: (videoPageController.isFullscreen &&
                  !playerController.panel.showVideoController)
              ? SystemMouseCursors.none
              : SystemMouseCursors.basic,
          child: PlayerTransportBar(
            compact: compact,
            timePlacement: PlayerTimeLabelPlacement.forViewport(
              MediaQuery.sizeOf(context),
              desktop: _desktop,
            ),
            playPause: IconButton(
              tooltip: playerController.playback.playing ? '暂停' : '播放',
              onPressed: () => playerController.playOrPause(),
              icon: PlayPauseIcon(
                iconColor: Colors.white,
                playing: playerController.playback.playing,
              ),
            ),
            nextEpisode: IconButton(
              color: Colors.white,
              icon: const Icon(Icons.skip_next_rounded),
              tooltip: '下一集',
              onPressed: widget.onNextEpisode,
            ),
            // Playback ticks only rebuild the progress bar and its time labels.
            progressBuilder: (location) => Observer(
                builder: (context) => ProgressBar(
                      thumbRadius: 8,
                      thumbGlowRadius: 18,
                      timeLabelLocation: location,
                      timeLabelTextStyle: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                      progress: playerController.playback.currentPosition,
                      buffered: playerController.playback.buffer,
                      total: playerController.playback.duration,
                      onSeek: widget.handleProgressBarSeek,
                      onDragStart: (_) => widget.handleProgressBarDragStart(),
                      onDragUpdate: (details) => playerController.seeking
                          .updateInteractiveSeek(details.timeStamp),
                    )),
            timeLabel: Observer(
                builder: (context) => Text(
                      '${compact ? '    ' : ''}${durationToString(playerController.playback.currentPosition)} / ${durationToString(playerController.playback.duration)}',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: !compact && _desktop ? 16 : 12,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    )),
            controls: compact ? const SizedBox.shrink() : _wideControls,
            fullscreen: _buildFullscreenButton(compact),
          ),
        ),
      );

  Widget _buildFullscreenButton(bool compact) {
    if (videoPageController.isPip) {
      return compact ? const Text('    ') : const SizedBox.shrink();
    }
    if (!_desktop && widget.fillsWindow && !videoPageController.isFullscreen) {
      return const SizedBox.shrink();
    }
    return IconButton(
      color: Colors.white,
      icon: Icon(videoPageController.isFullscreen
          ? Icons.fullscreen_exit_rounded
          : Icons.fullscreen_rounded),
      tooltip: videoPageController.isFullscreen ? '退出全屏' : '全屏',
      onPressed: widget.handleFullscreen,
    );
  }

  Widget _buildTopControls(bool compact) {
    return EmbeddedNativeControlArea(
      requireOffset: compact || !videoPageController.isFullscreen,
      child: SafeArea(
        top: false,
        bottom: false,
        left: !compact && widget.fillsWindow,
        right: !compact && widget.fillsWindow,
        child: PlayerPanelHoldMouseRegion(
          acquirePlayerPanelHold: widget.acquirePlayerPanelHold,
          cursor: (videoPageController.isFullscreen &&
                  !playerController.panel.showVideoController)
              ? SystemMouseCursors.none
              : SystemMouseCursors.basic,
          child: Row(
            children: [
              IconButton(
                color: Colors.white,
                icon: const Icon(Icons.arrow_back_rounded),
                tooltip: '返回',
                onPressed: widget.onBackPressed,
              ),
              Expanded(
                child: dtb.DragToMoveArea(
                  child: compact
                      ? const SizedBox(height: 40)
                      : Text(
                          ' ${videoPageController.title} [${videoPageController.roadList[videoPageController.selectedEpisode.road].identifier[videoPageController.selectedEpisode.episode - 1]}]',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: Theme.of(context)
                                .textTheme
                                .titleMedium!
                                .fontSize,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                ),
              ),
              _forwardButton(),
              if ((_desktop &&
                      (compact || !videoPageController.isFullscreen)) ||
                  (defaultTargetPlatform == TargetPlatform.android))
                IconButton(
                  onPressed: () async {
                    if (_desktop) {
                      if (videoPageController.isPip) {
                        await PipUtils.exitDesktopPIPWindow();
                      } else {
                        await PipUtils.enterDesktopPIPWindow(
                          width: playerController.debug.playerWidth,
                          height: playerController.debug.playerHeight,
                        );
                      }
                      videoPageController.isPip = !videoPageController.isPip;
                      return;
                    }
                    await widget.enterAndroidPictureInPicture();
                  },
                  tooltip: '画中画',
                  icon: const Icon(
                    Icons.picture_in_picture,
                    color: Colors.white,
                  ),
                ),
              if (compact) _buildDanmakuToggleButton(context),
              PlayerPanelHoldCollectButton(
                acquirePlayerPanelHold: widget.acquirePlayerPanelHold,
                bangumiItem: videoPageController.bangumiItem,
              ),
              PlayerPanelHoldMenuAnchor(
                acquirePlayerPanelHold: widget.acquirePlayerPanelHold,
                onVisibilityChanged: widget.onMenuVisibilityChanged,
                consumeOutsideTap: true,
                builder: (BuildContext context, MenuController controller,
                    Widget? child) {
                  return IconButton(
                    onPressed: () {
                      if (controller.isOpen) {
                        controller.close();
                      } else {
                        controller.open();
                      }
                    },
                    tooltip: '更多选项',
                    icon: const Icon(
                      Icons.more_vert,
                      color: Colors.white,
                    ),
                  );
                },
                menuChildren: [
                  if (compact) ...[
                    SubmenuButton(
                        menuChildren: _aspectRatioItems,
                        child: _menuLabel('视频比例')),
                    SubmenuButton(
                        menuChildren: _speedItems, child: _menuLabel('倍速')),
                    SubmenuButton(
                        menuChildren: _superResolutionItems,
                        child: _menuLabel('超分辨率')),
                    _syncPlayMenuItem,
                  ],
                  MenuItemButton(
                    onPressed: widget.showDanmakuSwitch,
                    child: _menuLabel('弹幕切换'),
                  ),
                  if (compact) _danmakuSettingsMenuItem,
                  MenuItemButton(
                    onPressed: widget.showVideoInfo,
                    child: _menuLabel('视频详情'),
                  ),
                  MenuItemButton(
                    onPressed: () {
                      final needRestart = playerController.playback.playing;
                      playerController.pause();
                      RemotePlay()
                          .castVideo(playerController.videoUrl,
                              videoPageController.currentPlugin.referer)
                          .whenComplete(() {
                        if (mounted && needRestart) {
                          playerController.play();
                        }
                      });
                    },
                    child: _menuLabel('远程投屏'),
                  ),
                  MenuItemButton(
                    onPressed: playerController.launchExternalPlayer,
                    child: _menuLabel('外部播放'),
                  ),
                  SubmenuButton(
                    menuChildren: [
                      MenuItemButton(
                        onPressed: TimedShutdownService().cancel,
                        child: _menuLabel('不开启',
                            selected: !TimedShutdownService().isActive),
                      ),
                      for (final int minutes in [15, 30, 60])
                        MenuItemButton(
                          onPressed: () {
                            TimedShutdownService().start(minutes,
                                onExpired: widget.pauseForTimedShutdown);
                            KazumiDialog.showToast(
                                message:
                                    '已设置 ${TimedShutdownService().formatMinutesToDisplay(minutes)} 后定时关闭');
                          },
                          child: _menuLabel('$minutes 分钟',
                              selected:
                                  TimedShutdownService().setMinutes == minutes),
                        ),
                      MenuItemButton(
                        onPressed: () {
                          TimedShutdownService.showCustomTimerDialog(
                            onExpired: widget.pauseForTimedShutdown,
                          );
                        },
                        child: _menuLabel('自定义'),
                      ),
                    ],
                    child: Container(
                      height: 48,
                      constraints: BoxConstraints(minWidth: 112),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: ValueListenableBuilder<int>(
                          valueListenable:
                              TimedShutdownService().remainingSecondsNotifier,
                          builder: (context, remainingSeconds, child) {
                            return Text(
                              remainingSeconds > 0
                                  ? "定时关闭 (${TimedShutdownService().formatRemainingTime()})"
                                  : "定时关闭",
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                  if (!compact) _syncPlayMenuItem,
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget get _rightControls {
    return SafeArea(
      top: false,
      bottom: false,
      left: widget.fillsWindow,
      right: widget.fillsWindow,
      child: Column(
        children: [
          const Spacer(),
          if (!playerController.panel.lockPanel)
            IconButton(
              icon: const Icon(
                Icons.photo_camera_outlined,
                color: Colors.white,
              ),
              tooltip: '截图',
              onPressed: widget.handleScreenShot,
            ),
          IconButton(
            icon: Icon(
              playerController.panel.lockPanel
                  ? Icons.lock_outline
                  : Icons.lock_open,
              color: Colors.white,
            ),
            tooltip: playerController.panel.lockPanel ? '解锁面板' : '锁定面板',
            onPressed: () {
              playerController.panel.lockPanel =
                  !playerController.panel.lockPanel;
            },
          ),
          const Spacer(),
        ],
      ),
    );
  }
}
