import 'dart:async';
import 'dart:io';

import 'package:canvas_danmaku/models/danmaku_content_item.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:kazumi/bean/dialog/adaptive_bottom_sheet.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/bean/dialog/material_bottom_sheet.dart';
import 'package:kazumi/bean/widget/embedded_native_control_area.dart';
import 'package:kazumi/pages/player/controller/player_super_resolution.dart';
import 'package:kazumi/pages/player/danmaku_destination_sheet.dart';
import 'package:kazumi/pages/player/player_adjustment_hud.dart';
import 'package:kazumi/pages/player/player_control_widgets.dart';
import 'package:kazumi/pages/player/player_controller.dart';
import 'package:kazumi/pages/player/player_controls_settings.dart';
import 'package:kazumi/pages/player/player_panel_hold.dart';
import 'package:kazumi/pages/settings/danmaku/danmaku_settings_sheet.dart';
import 'package:kazumi/pages/video/video_controller.dart';
import 'package:kazumi/services/player/pip_utils.dart';
import 'package:kazumi/services/player/remote.dart';
import 'package:kazumi/services/player/timed_shutdown_service.dart';
import 'package:kazumi/utils/device.dart';

class PlayerItemPanel extends StatefulWidget {
  const PlayerItemPanel({
    super.key,
    required this.playerController,
    required this.videoPageController,
    required this.onBackPressed,
    required this.setPlaybackSpeed,
    required this.showDanmakuSwitch,
    required this.handleFullscreen,
    required this.enterAndroidPictureInPicture,
    required this.handleScreenShot,
    required this.handlePreNextEpisode,
    required this.handleProgressBarDragStart,
    required this.handleProgressBarSeek,
    required this.handleSuperResolutionChange,
    required this.panelVisibilityController,
    required this.toggleMenu,
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
  final void Function(BuildContext) onBackPressed;
  final Future<void> Function(double) setPlaybackSpeed;
  final void Function() showDanmakuSwitch;
  final void Function() toggleMenu;
  final void Function() handleFullscreen;
  final Future<void> Function() enterAndroidPictureInPicture;
  final void Function() handleScreenShot;
  final VoidCallback handleProgressBarDragStart;
  final Future<void> Function(Duration duration) handleProgressBarSeek;
  final Future<void> Function(SuperResolutionMode mode)
      handleSuperResolutionChange;
  final AnimationController panelVisibilityController;
  final FocusNode keyboardFocus;
  final PlayerPanelHold Function() acquirePlayerPanelHold;
  final ValueChanged<bool> onMenuVisibilityChanged;
  final void Function() handleDanmaku;
  final void Function(String direction) handlePreNextEpisode;
  final void Function() skipOP;
  final void Function() showVideoInfo;
  final void Function() showSyncPlayPanel;
  final VoidCallback pauseForTimedShutdown;
  final bool disableAnimations;

  @override
  State<PlayerItemPanel> createState() => _PlayerItemPanelState();
}

class _PlayerItemPanelState extends State<PlayerItemPanel> {
  PlayerController get player => widget.playerController;
  VideoPageController get video => widget.videoPageController;

  bool get _canPictureInPicture =>
      Platform.isAndroid || (isDesktop() && !video.isFullscreen);
  bool get _canLock => !isDesktop() && video.isFullscreen;
  bool get _canPrevious => video.selectedEpisode.episode > 1;
  bool get _canNext {
    final selection = video.selectedEpisode;
    return selection.road >= 0 &&
        selection.road < video.roadList.length &&
        selection.episode < video.roadList[selection.road].data.length;
  }

  String get _episodeLabel {
    final selection = video.playbackEpisode;
    final road = selection.road;
    final episode = selection.episode - 1;
    if (road >= 0 && road < video.roadList.length) {
      final names = video.roadList[road].identifier;
      if (episode >= 0 && episode < names.length) return names[episode];
    }
    return '第 ${selection.episode} 集';
  }

  /// A route holds both panel visibility and keyboard shortcut dispatch until
  /// it closes. Follow-up sheets run under the same lease.
  Future<void> _withPanelHold(Future<void> Function() action) async {
    final hold = widget.acquirePlayerPanelHold();
    widget.onMenuVisibilityChanged(true);
    try {
      await action();
    } finally {
      widget.onMenuVisibilityChanged(false);
      hold.release();
      if (mounted) widget.keyboardFocus.requestFocus();
    }
  }

  Widget _collection(BuildContext context) => PlayerPanelHoldCollectButton(
        acquirePlayerPanelHold: widget.acquirePlayerPanelHold,
        bangumiItem: video.bangumiItem,
        color: Theme.of(context).colorScheme.onSurface,
      );

  Future<void> _showSettings(BuildContext context, {int tab = 0}) =>
      _withPanelHold(() async {
        final action = await showAdaptiveBottomSheet<PlayerSettingsAction>(
          context: context,
          maxHeightFactor: 0.85,
          builder: (context) => PlayerControlsSettings(
            player: player,
            setSpeed: widget.setPlaybackSpeed,
            setSuperResolution: widget.handleSuperResolutionChange,
            toggleDanmaku: widget.handleDanmaku,
            onTimerExpired: widget.pauseForTimedShutdown,
            canPrevious: _canPrevious,
            canNext: _canNext,
            canPictureInPicture: _canPictureInPicture,
            canLock: _canLock,
            collection: _collection(context),
            canScreenshot: !isDesktop(),
            initialTab: tab,
          ),
        );
        if (!context.mounted || action == null) return;
        switch (action) {
          case PlayerSettingsAction.episodes:
            widget.toggleMenu();
          case PlayerSettingsAction.previous:
            widget.handlePreNextEpisode('prev');
          case PlayerSettingsAction.next:
            widget.handlePreNextEpisode('next');
          case PlayerSettingsAction.skip:
            widget.skipOP();
          case PlayerSettingsAction.skipTime:
            await _editSkipTime(context);
          case PlayerSettingsAction.compose:
            await _composeDanmaku(context);
          case PlayerSettingsAction.danmakuSource:
            widget.showDanmakuSwitch();
          case PlayerSettingsAction.danmakuSettings:
            await showDanmakuSettingsSheet(
              context: context,
              danmakuController: player.danmaku.canvasController,
              onUpdateDanmakuSpeed: player.updateDanmakuSpeed,
              onTimelineOffsetChanged:
                  player.danmaku.clearAndInvalidateScheduledDanmakus,
            );
          case PlayerSettingsAction.screenshot:
            widget.handleScreenShot();
          case PlayerSettingsAction.pictureInPicture:
            await _togglePictureInPicture();
          case PlayerSettingsAction.cast:
            final resume = player.playback.playing;
            await player.pause();
            try {
              await RemotePlay()
                  .castVideo(player.videoUrl, video.currentPlugin.referer);
            } finally {
              if (mounted && resume) await player.play();
            }
          case PlayerSettingsAction.externalPlayer:
            await player.launchExternalPlayer();
          case PlayerSettingsAction.videoInfo:
            widget.showVideoInfo();
          case PlayerSettingsAction.syncPlay:
            widget.showSyncPlayPanel();
          case PlayerSettingsAction.customTimer:
            TimedShutdownService.showCustomTimerDialog(
                onExpired: widget.pauseForTimedShutdown);
          case PlayerSettingsAction.lock:
            player.panel.lockPanel = true;
        }
      });

  Future<void> _togglePictureInPicture() async {
    if (!isDesktop()) {
      await widget.enterAndroidPictureInPicture();
      return;
    }
    if (video.isPip) {
      await PipUtils.exitDesktopPIPWindow();
    } else {
      await PipUtils.enterDesktopPIPWindow(
        width: player.debug.playerWidth,
        height: player.debug.playerHeight,
      );
    }
    video.isPip = !video.isPip;
  }

  Future<void> _editSkipTime(BuildContext context) async {
    final form = GlobalKey<FormState>();
    var seconds = player.playback.buttonSkipTime;
    final result = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('跳过时长'),
        content: Form(
          key: form,
          child: TextFormField(
            initialValue: '$seconds',
            autofocus: true,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration:
                const InputDecoration(labelText: '每次跳过', suffixText: '秒'),
            validator: (value) {
              final parsed = int.tryParse(value ?? '');
              return parsed == null || parsed < 1 || parsed > 3600
                  ? '请输入 1 至 3600 秒'
                  : null;
            },
            onSaved: (value) => seconds = int.parse(value!),
            onFieldSubmitted: (_) {
              if (form.currentState!.validate()) {
                form.currentState!.save();
                Navigator.of(context).pop(seconds);
              }
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              if (form.currentState!.validate()) {
                form.currentState!.save();
                Navigator.of(context).pop(seconds);
              }
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
    if (mounted && result != null) {
      player.setButtonForwardTime(result);
      setState(() {});
    }
  }

  Future<void> _composeDanmaku(BuildContext context) async {
    if (!player.danmaku.danmakuOn) {
      KazumiDialog.showToast(message: '请先打开弹幕');
      return;
    }
    if (player.danmaku.danDanmakus.isEmpty) {
      KazumiDialog.showToast(message: '当前剧集不支持弹幕发送的说');
      return;
    }
    final message = await showAdaptiveBottomSheet<String>(
      context: context,
      builder: (context) => const _DanmakuComposer(),
    );
    if (!context.mounted || message == null) return;
    final destination = await showDanmakuDestinationSheet(context);
    if (!mounted || destination == null) return;
    if (destination == DanmakuDestination.chatRoom) {
      if (player.syncplay.syncplayRoom.isEmpty) {
        KazumiDialog.showToast(message: '你还没有加入一起看，无法发送聊天室弹幕');
        return;
      }
      final sender = player.syncplay.syncplayController?.username ?? '我';
      player.danmaku.canvasController.addDanmaku(DanmakuContentItem(
        '$sender：$message',
        color: Colors.orange,
        isColorful: true,
        type: DanmakuItemType.bottom,
        extra: DateTime.now().millisecondsSinceEpoch,
      ));
      unawaited(player.sendSyncPlayChatMessage(message));
    } else {
      // This provider has no send API; preserve the existing local echo.
      player.danmaku.canvasController
          .addDanmaku(DanmakuContentItem(message, selfSend: true));
    }
  }

  Widget _timeline() => Observer(
      builder: (context) => PlayerTimeline(
            position: player.playback.currentPosition,
            buffered: player.playback.buffer,
            duration: player.playback.duration,
            onStart: widget.handleProgressBarDragStart,
            onUpdate: player.seeking.updateInteractiveSeek,
            onEnd: widget.handleProgressBarSeek,
          ));

  Widget _volume() => Observer(builder: (context) {
        final volume = player.playback.volume.clamp(0.0, 100.0);
        return Row(children: [
          PlayerControlButton(
            icon: volume == 0
                ? Icons.volume_off_rounded
                : Icons.volume_up_rounded,
            tooltip: volume == 0 ? '取消静音' : '静音',
            onPressed: player.toggleMute,
            disableAnimations: widget.disableAnimations,
          ),
          Expanded(
            child: Slider(
              value: volume,
              max: 100,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              label: '${volume.round()}%',
              semanticFormatterCallback: (value) => '音量 ${value.round()}%',
              onChanged: player.setVolume,
            ),
          ),
        ]);
      });

  Widget _holdOnHover(Widget child) => PlayerPanelHoldMouseRegion(
        acquirePlayerPanelHold: widget.acquirePlayerPanelHold,
        child: child,
      );

  @override
  Widget build(BuildContext context) {
    final reduceMotion =
        widget.disableAnimations || MediaQuery.disableAnimationsOf(context);
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion),
      child: Theme(
        data: playerControlsTheme(Theme.of(context)),
        child: Builder(builder: (context) {
          return Stack(
            children: [
              Positioned.fill(
                child: Observer(builder: (context) {
                  final visible = player.panel.showVideoController;
                  final locked = player.panel.lockPanel;
                  final chrome = SafeArea(
                    top: video.isFullscreen,
                    bottom: video.isFullscreen,
                    left: video.isFullscreen,
                    right: video.isFullscreen,
                    child: locked
                        ? Align(
                            alignment: Alignment.centerRight,
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: _holdOnHover(PlayerControlButton(
                                icon: Icons.lock_rounded,
                                tooltip: '解锁面板',
                                selected: true,
                                onPressed: () => player.panel.lockPanel = false,
                                disableAnimations: reduceMotion,
                              )),
                            ),
                          )
                        : EmbeddedNativeControlArea(
                            requireOffset: !video.isFullscreen,
                            child: PlayerControlsView(
                              title: video.title,
                              episode: _episodeLabel,
                              playing: player.playback.playing,
                              fullscreen: video.isFullscreen,
                              isPip: video.isPip,
                              danmakuOn: player.danmaku.danmakuOn,
                              danmakuLoading: player.danmaku.danmakuLoading,
                              speed: player.playback.playerSpeed,
                              skipSeconds: player.playback.buttonSkipTime,
                              timeline: _timeline(),
                              visibility: widget.panelVisibilityController,
                              superResolutionBuilder: (showLabel) => Observer(
                                builder: (context) =>
                                    PlayerSuperResolutionButton(
                                  mode: player.playback.superResolutionMode,
                                  onSelected:
                                      widget.handleSuperResolutionChange,
                                  acquirePlayerPanelHold:
                                      widget.acquirePlayerPanelHold,
                                  onMenuVisibilityChanged:
                                      widget.onMenuVisibilityChanged,
                                  showLabel: showLabel,
                                  disableAnimations: reduceMotion,
                                ),
                              ),
                              volume: isDesktop() ? _volume() : null,
                              collection: _collection(context),
                              wrapControls: _holdOnHover,
                              onBack: () => widget.onBackPressed(context),
                              onPlayPause: player.playOrPause,
                              onPrevious: _canPrevious
                                  ? () => widget.handlePreNextEpisode('prev')
                                  : null,
                              onNext: _canNext
                                  ? () => widget.handlePreNextEpisode('next')
                                  : null,
                              onSkip: widget.skipOP,
                              onSkipSettings: () =>
                                  _withPanelHold(() => _editSkipTime(context)),
                              onSpeed: () => _showSettings(context),
                              onDanmaku: widget.handleDanmaku,
                              onEpisodes: widget.toggleMenu,
                              onFullscreen: () {
                                if (video.isPip) {
                                  unawaited(_togglePictureInPicture());
                                } else {
                                  widget.handleFullscreen();
                                }
                              },
                              onSettings: () => _showSettings(context),
                              onSyncPlay: widget.showSyncPlayPanel,
                              onLock: _canLock
                                  ? () => player.panel.lockPanel = true
                                  : null,
                              disableAnimations: reduceMotion,
                            ),
                          ),
                  );
                  return PlayerControlsVisibility(
                    visible: visible,
                    animation: widget.panelVisibilityController,
                    disableAnimations: reduceMotion,
                    child: chrome,
                  );
                }),
              ),
              // HUDs stay independent of chrome visibility and don't subscribe to
              // playback ticks while hidden.
              Positioned(
                top: 24,
                left: 16,
                right: 16,
                child: IgnorePointer(
                  child: Stack(alignment: Alignment.topCenter, children: [
                    Observer(builder: (context) {
                      final visible = player.panel.showSeekTime;
                      return PlayerSeekHud(
                        visible: visible,
                        currentPosition: visible
                            ? player.playback.currentPosition
                            : Duration.zero,
                        playerPosition: visible
                            ? player.playback.playerPosition
                            : Duration.zero,
                        duration:
                            visible ? player.playback.duration : Duration.zero,
                        direction: player.panel.seekDirection,
                        disableAnimations: reduceMotion,
                      );
                    }),
                    Observer(
                        builder: (context) => PlayerSpeedHud(
                              visible: player.panel.showPlaySpeed,
                              speed: player.playback.playerSpeed,
                              disableAnimations: reduceMotion,
                            )),
                    Observer(builder: (context) {
                      final showVolume = player.panel.showVolume;
                      final showBrightness = player.panel.showBrightness;
                      return PlayerAdjustmentHud(
                        visible: showVolume || showBrightness,
                        type: showVolume
                            ? PlayerAdjustmentHudType.volume
                            : PlayerAdjustmentHudType.brightness,
                        value: showVolume
                            ? player.playback.volume
                            : player.panel.brightness,
                        disableAnimations: reduceMotion,
                      );
                    }),
                  ]),
                ),
              ),
            ],
          );
        }),
      ),
    );
  }
}

class _DanmakuComposer extends StatefulWidget {
  const _DanmakuComposer();

  @override
  State<_DanmakuComposer> createState() => _DanmakuComposerState();
}

class _DanmakuComposerState extends State<_DanmakuComposer> {
  final _text = TextEditingController();
  final _form = GlobalKey<FormState>();

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _submit() {
    if (_form.currentState!.validate()) {
      Navigator.of(context).pop(_text.text.trim());
    }
  }

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        padding:
            EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            MaterialBottomSheetHeader(
              title: '分享这一刻',
              onClose: () => Navigator.of(context).pop(),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: Form(
                key: _form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: _text,
                      autofocus: true,
                      maxLength: 100,
                      textInputAction: TextInputAction.send,
                      decoration: const InputDecoration(
                        hintText: '发个友善的弹幕见证当下',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                              ? '写点什么再发送吧'
                              : null,
                      onFieldSubmitted: (_) => _submit(),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _submit,
                      icon: const Icon(Icons.send_rounded),
                      label: const Text('选择发送位置'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
}
