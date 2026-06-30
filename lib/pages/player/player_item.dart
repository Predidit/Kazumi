import 'dart:async';
import 'dart:io';
import 'package:audio_video_progress_bar/audio_video_progress_bar.dart';
import 'package:kazumi/pages/player/player_item_panel.dart';
import 'package:kazumi/pages/player/controller/player_super_resolution.dart';
import 'package:kazumi/pages/player/player_panel_hold.dart';
import 'package:kazumi/pages/player/player_pointer_interaction.dart';
import 'package:kazumi/pages/player/player_screenshot_feedback_overlay.dart';
import 'package:kazumi/pages/player/smallest_player_item_panel.dart';
import 'package:kazumi/utils/constants.dart';
import 'package:kazumi/services/logging/logger.dart';
import 'package:kazumi/services/player/pip_utils.dart';
import 'package:kazumi/services/sync/webdav.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import 'package:kazumi/pages/player/player_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/pages/video/video_controller.dart';
import 'package:window_manager/window_manager.dart';
import 'package:canvas_danmaku/canvas_danmaku.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:screen_brightness_platform_interface/screen_brightness_platform_interface.dart';
import 'package:kazumi/pages/history/history_controller.dart';
import 'package:kazumi/pages/collect/collect_controller.dart';
import 'package:kazumi/services/storage/storage.dart';
import 'package:kazumi/request/apis/danmaku_api.dart';
import 'package:kazumi/modules/danmaku/danmaku_search_response.dart';
import 'package:kazumi/modules/danmaku/danmaku_episode_response.dart';
import 'package:kazumi/modules/danmaku/danmaku_module.dart';
import 'package:kazumi/pages/player/controller/player_danmaku_controller.dart';
import 'package:kazumi/pages/player/player_item_surface.dart';
import 'package:mobx/mobx.dart' as mobx;
import 'package:kazumi/pages/my/my_controller.dart';
import 'package:saver_gallery/saver_gallery.dart';
import 'package:kazumi/services/player/audio_controller.dart';
import 'package:kazumi/utils/device.dart';
import 'package:kazumi/services/platform/display_mode_service.dart';
import 'package:kazumi/services/platform/player_menu_service.dart';

class PlayerItem extends StatefulWidget {
  const PlayerItem({
    super.key,
    required this.playerController,
    required this.toggleMenu,
    required this.showMenuImmediately,
    required this.hideMenuImmediately,
    required this.changeEpisode,
    required this.onBackPressed,
    required this.keyboardFocus,
    required this.sendDanmaku,
    required this.showDanmakuDestinationPickerAndSend,
    required this.pauseForTimedShutdown,
    this.disableAnimations = false,
  });

  final PlayerController playerController;
  final VoidCallback toggleMenu;
  final VoidCallback showMenuImmediately;
  final VoidCallback hideMenuImmediately;
  final Future<void> Function(int episode, {int currentRoad, int offset})
      changeEpisode;
  final void Function(BuildContext) onBackPressed;
  final void Function(String) sendDanmaku;
  final FocusNode keyboardFocus;
  final bool disableAnimations;
  final void Function(String) showDanmakuDestinationPickerAndSend;
  final VoidCallback pauseForTimedShutdown;

  @override
  State<PlayerItem> createState() => _PlayerItemState();
}

class _PlayerItemState extends State<PlayerItem>
    with WindowListener, WidgetsBindingObserver, TickerProviderStateMixin {
  late final PlayerController playerController;
  final VideoPageController videoPageController =
      Modular.get<VideoPageController>();
  final HistoryController historyController = Modular.get<HistoryController>();
  final CollectController collectController = Modular.get<CollectController>();
  final MyController myController = Modular.get<MyController>();
  final AudioController _audioController = AudioController();
  late Map<String, List<String>> keyboardShortcuts;
  late List<String> keyboardActionsNeedLongPress;
  late Map<String, void Function()> keyboardActions;

  // 1. 在看
  // 2. 想看
  // 3. 搁置
  // 4. 看过
  // 5. 抛弃
  late int collectType;
  late bool webDavEnable;
  late bool webDavEnableHistory;

  // 弹幕
  final _danmuKey = GlobalKey();
  late bool _border;
  late double _opacity;
  late double _fontSize;
  late double _danmakuArea;
  late bool _hideTop;
  late bool _hideBottom;
  late bool _hideScroll;
  late bool _massiveMode;
  late bool _danmakuColor;
  late bool _danmakuBiliBiliSource;
  late bool _danmakuGamerSource;
  late bool _danmakuDanDanSource;
  late double _danmakuDuration;
  late double _danmakuLineHeight;
  late int _danmakuFontWeight;
  late bool _danmakuUseSystemFont;
  late double _danmakuBorderSize;

  // 硬件解码
  late bool haEnable;
  late bool autoPlayNext;
  late bool backgroundPlayback;
  late bool brightnessVolumeGesture;

  // 播放器控制面板无交互后自动隐藏所需时间 （单位：毫秒）
  late int playerControllerLayerDisappearTime;

  Timer? hideTimer;
  Timer? playerTimer;
  Timer? mouseScrollerTimer;
  Timer? _adjustmentHudHideTimer;
  final Set<PlayerPanelHold> _playerPanelHolds = <PlayerPanelHold>{};
  PlayerPanelHold? _progressBarDragHold;
  PointerDeviceKind? _lastTapPointerKind;
  PointerDeviceKind? _lastDoubleTapPointerKind;

  late final AnimationController _panelVisibilityController;
  late final AnimationController _screenshotFeedbackController;
  late final Animation<double> _screenshotFeedbackAnimation;

  double lastPlayerSpeed = 1.0;
  late double longPressPlaySpeed;
  int episodeNum = 0;
  bool? _lastPipPlaying;
  bool? _lastPipDanmakuEnabled;
  late mobx.ReactionDisposer _playerSizeListener;

  late mobx.ReactionDisposer _fullscreenListener;

  /// 处理 Android/iOS 应用后台或熄屏
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.paused &&
        !backgroundPlayback &&
        playerController.playback.mediaPlayer != null &&
        playerController.playback.playerPlaying) {
      try {
        await playerController.pause(enableSync: false);
      } catch (_) {}
      return;
    }
    try {
      if (playerController.playback.playerPlaying) {
        playerController.danmaku.canvasController.resume();
      }
    } catch (_) {}
  }

  Future<void> _syncAndroidAutoEnterPIPSetting() async {
    if (!Platform.isAndroid) {
      return;
    }
    final bool autoEnterPIPEnabled =
        GStorage.getSetting(SettingsKeys.androidAutoEnterPIP);
    try {
      await PipUtils.setAndroidAutoEnterPIPEnabled(autoEnterPIPEnabled);
    } catch (e) {
      KazumiLogger().w(
        'PlayerItem: failed to sync android auto enter pip setting',
        error: e,
      );
    }
  }

  Future<void> _syncAndroidPIPPlayerPageState(bool inPlayerPage) async {
    if (!Platform.isAndroid) {
      return;
    }
    try {
      await PipUtils.setAndroidPIPInPlayerPage(inPlayerPage);
    } catch (e) {
      KazumiLogger().w(
        'PlayerItem: failed to sync android pip player page state',
        error: e,
      );
    }
  }

  Future<void> _updateAndroidPIPActions({bool force = false}) async {
    if (!Platform.isAndroid) {
      return;
    }
    final bool playing = playerController.playback.playing;
    final bool danmakuEnabled = playerController.danmaku.danmakuOn;
    if (!force &&
        _lastPipPlaying == playing &&
        _lastPipDanmakuEnabled == danmakuEnabled) {
      return;
    }

    _lastPipPlaying = playing;
    _lastPipDanmakuEnabled = danmakuEnabled;
    await PipUtils.updateAndroidPIPActions(
      playing: playing,
      danmakuEnabled: danmakuEnabled,
      width: playerController.debug.playerWidth,
      height: playerController.debug.playerHeight,
    );
  }

  Future<void> _syncPIPAspectWhenVideoSizeReady() async {
    if (playerController.debug.playerWidth <= 0 ||
        playerController.debug.playerHeight <= 0) {
      return;
    }
    if (Platform.isAndroid) {
      await _updateAndroidPIPActions(force: true);
      return;
    }
    if (isDesktop() && videoPageController.isPip) {
      await PipUtils.enterDesktopPIPWindow(
        width: playerController.debug.playerWidth,
        height: playerController.debug.playerHeight,
      );
    }
  }

  void _loadShortcuts() {
    keyboardShortcuts = {};
    defaultShortcuts.forEach((key, defaultValue) {
      keyboardShortcuts[key] = GStorage.getStringListSettingByName(
        'shortcut_$key',
        defaultValue: defaultValue,
      );
    });
  }

  void _initKeyboardActions() {
    //需要实现长按的功能列表。
    keyboardActionsNeedLongPress = ["forward"];
    //快捷键功能对应表
    keyboardActions = {
      'playorpause': () => playerController.playOrPause(),
      'forward': () async => handleShortcutForwardDown(),
      'rewind': () async => handleShortcutRewind(),
      'next': () async => handlePreNextEpisode('next'),
      'prev': () async => handlePreNextEpisode('prev'),
      'volumeup': () async => handleShortcutVolumeChange('up'),
      'volumedown': () async => handleShortcutVolumeChange('down'),
      'togglemute': () async => handleShortcutVolumeChange('mute'),
      'fullscreen': () => handleShortcutFullscreen(),
      'screenshot': () async => handleScreenshot(),
      'skip': () async => skipOP(),
      'exitfullscreen': () => handleShortcutExitFullscreen(),
      'toggledanmaku': () => handleDanmaku(),
      'speed1': () async => setPlaybackSpeed(1.0),
      'speed2': () async => setPlaybackSpeed(2.0),
      'speed3': () async => setPlaybackSpeed(3.0),
      'speedup': () async => handleSpeedChange('up'),
      'speeddown': () async => handleSpeedChange('down'),
      // 开始对应长按功能
      // 如需对应长按功能，例如对功能'func'对应长按，请分别添加'funcRepeat'和'funcUp'。
      'forwardRepeat': () async => handleShortcutForwardRepeat(),
      'forwardUp': () async => handleShortcutForwardUp(),
    };
  }

  //初始化播放器菜单
  void _initPlayerMenu() {
    PlayerMenuService.initialize(keyboardActions);
  }

  //销毁播放器菜单
  void _disposePlayerMenu() {
    PlayerMenuService.dispose();
  }

  //快捷键按下
  bool handleShortcutDown(String keyLabel) {
    for (final entry in keyboardShortcuts.entries) {
      final func = entry.key;
      final keys = entry.value;
      if (keys.contains(keyLabel)) {
        final action = keyboardActions[func];
        if (action != null) {
          action();
          return true;
        }
      }
    }
    return false;
  }

  // 快捷键长按
  bool handleShortcutLongPress(String keyLabel, String mode) {
    for (final func in keyboardActionsNeedLongPress) {
      final keys = keyboardShortcuts[func];
      if (keys?.contains(keyLabel) == true) {
        final action = keyboardActions[func + mode];
        if (action != null) {
          action();
          return true;
        }
      }
    }
    return false;
  }

  //上一集下一集动作
  Future<void> handlePreNextEpisode(String direction) async {
    if (videoPageController.loading) return;
    final selection = videoPageController.selectedEpisode;
    final currentRoad = selection.road;
    final episodes = videoPageController.roadList[currentRoad].data;
    int targetEpisode;
    if (direction == 'next') {
      targetEpisode = selection.episode + 1;
    } else if (direction == 'prev') {
      targetEpisode = selection.episode - 1;
    } else {
      return;
    }

    if (targetEpisode > episodes.length) {
      KazumiDialog.showToast(message: '已经是最新一集');
      return;
    }
    if (targetEpisode <= 0) {
      KazumiDialog.showToast(message: '已经是第一集');
      return;
    }

    final targetSelection = VideoEpisodeSelection(
      episode: targetEpisode,
      road: currentRoad,
    );
    final targetRef = videoPageController.resolveEpisode(targetSelection);
    if (targetRef == null) {
      KazumiDialog.showToast(message: '集数解析失败');
      return;
    }
    KazumiDialog.showToast(message: '正在加载${targetRef.displayTitle}');
    widget.changeEpisode(targetEpisode, currentRoad: currentRoad);
  }

  //快退快捷键动作
  Future<void> handleShortcutRewind() async {
    int skipTime = playerController.playback.arrowKeySkipTime;
    int current = playerController.playback.currentPosition.inSeconds;
    int targetPosition;

    targetPosition = current - skipTime;
    if (targetPosition < 0) targetPosition = 0;

    try {
      playerTimer?.cancel();
      await playerController.seek(Duration(seconds: targetPosition));
      playerTimer = getPlayerTimer();
    } catch (e) {
      KazumiLogger().e('PlayerController: seek failed', error: e);
    }
  }

  // 快进快捷键动作
  Future<void> handleShortcutForwardDown() async {
    lastPlayerSpeed = playerController.playback.playerSpeed;
  }

  Future<void> handleShortcutForwardRepeat() async {
    final double defaultShortcutForwardPlaySpeed =
        GStorage.getSetting(SettingsKeys.defaultShortcutForwardPlaySpeed);
    if (playerController.playback.playerSpeed <
        defaultShortcutForwardPlaySpeed) {
      playerController.panel.showPlaySpeed = true;
      setPlaybackSpeed(defaultShortcutForwardPlaySpeed);
    }
  }

  Future<void> handleShortcutForwardUp() async {
    int skipTime = playerController.playback.arrowKeySkipTime;
    int current = playerController.playback.currentPosition.inSeconds;
    int total = playerController.playback.duration.inSeconds;
    int targetPosition;

    targetPosition = current + skipTime;
    if (targetPosition > total) targetPosition = total;
    if (playerController.panel.showPlaySpeed) {
      playerController.panel.showPlaySpeed = false;
      setPlaybackSpeed(lastPlayerSpeed);
    } else {
      try {
        playerTimer?.cancel();
        playerController.seek(Duration(seconds: targetPosition));
        playerTimer = getPlayerTimer();
      } catch (e) {
        KazumiLogger().e('PlayerController: seek failed', error: e);
      }
    }
  }

  //全屏快捷键动作
  void handleShortcutFullscreen() {
    if (!videoPageController.isPip) handleFullscreen();
  }

  //退出全屏快捷键动作
  void handleShortcutExitFullscreen() {
    if (videoPageController.isFullscreen && !isTablet()) {
      try {
        playerController.danmaku.canvasController.clear();
      } catch (_) {}
      DisplayModeService.exitFullScreen();
      videoPageController.isFullscreen = !videoPageController.isFullscreen;
    } else if (!Platform.isMacOS) {
      playerController.pause();
      windowManager.hide();
    }
  }

  void _toggleVideoController() {
    if (playerController.panel.showVideoController) {
      hideVideoController();
    } else {
      displayVideoController();
    }
  }

  void _handleTap(PointerDeviceKind? pointerKind) {
    if (shouldToggleControllerOnPrimaryTap(
      isDesktop: isDesktop(),
      pointerKind: pointerKind,
    )) {
      _toggleVideoController();
      return;
    }
    playerController.playOrPause();
  }

  void _handleDoubleTap(PointerDeviceKind? pointerKind) {
    if (shouldToggleFullscreenOnDoubleTap(
      isDesktop: isDesktop(),
      isPip: videoPageController.isPip,
      pointerKind: pointerKind,
    )) {
      handleFullscreen();
      return;
    }
    playerController.playOrPause();
  }

  void _handleMouseScroller() {
    playerController.panel.showVolume = true;
    mouseScrollerTimer?.cancel();
    mouseScrollerTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) {
        playerController.panel.showVolume = false;
      }
      mouseScrollerTimer = null;
    });
  }

  void _cancelAdjustmentHudHideTimer() {
    _adjustmentHudHideTimer?.cancel();
    _adjustmentHudHideTimer = null;
  }

  void _showVolumeAdjustmentHud() {
    _cancelAdjustmentHudHideTimer();
    playerController.panel.showBrightness = false;
    playerController.panel.showVolume = true;
  }

  void _showBrightnessAdjustmentHud() {
    _cancelAdjustmentHudHideTimer();
    playerController.panel.showVolume = false;
    playerController.panel.showBrightness = true;
  }

  void _scheduleAdjustmentHudHide({
    Duration delay = const Duration(milliseconds: 650),
  }) {
    _cancelAdjustmentHudHideTimer();
    _adjustmentHudHideTimer = Timer(delay, () {
      if (mounted) {
        playerController.panel.showVolume = false;
        playerController.panel.showBrightness = false;
      }
      _adjustmentHudHideTimer = null;
    });
  }

  void _finishAdjustmentGesture() {
    if (!brightnessVolumeGesture) {
      return;
    }
    if (playerController.panel.volumeSeeking) {
      playerController.panel.volumeSeeking = false;
      unawaited(playerController.finishVolumeGesture());
    }
    if (playerController.panel.brightnessSeeking) {
      playerController.panel.brightnessSeeking = false;
    }
    _scheduleAdjustmentHudHide();
  }

  // 跳过指定秒数
  Future<void> skipOP() async {
    await playerController.seek(playerController.playback.currentPosition +
        Duration(seconds: playerController.playback.buttonSkipTime));
  }

  void handleDanmaku() {
    playerController.danmaku.canvasController.clear();
    if (playerController.danmaku.danmakuOn) {
      playerController.danmaku.setDanmakuEnabled(false);
      GStorage.putSetting(SettingsKeys.danmakuEnabledByDefault, false);
      unawaited(_updateAndroidPIPActions(force: true));
      return;
    }
    if (playerController.danmaku.danDanmakus.isEmpty) {
      showDanmakuSwitch();
      unawaited(_updateAndroidPIPActions(force: true));
      return;
    }
    playerController.danmaku.setDanmakuEnabled(true);
    GStorage.putSetting(SettingsKeys.danmakuEnabledByDefault, true);
    unawaited(_updateAndroidPIPActions(force: true));
  }

  Future<void> _syncHistoryWithWebDav() async {
    if (webDavEnable && webDavEnableHistory) {
      try {
        var webDav = WebDav();
        await webDav.syncHistory();
      } catch (e) {
        KazumiLogger().w('WebDav: auto history sync failed', error: e);
      }
    }
  }

  Future<void> _bindAudioService() async {
    try {
      await _audioController.bindCallbacks(
        onPlay: () => playerController.play(),
        onPause: () => playerController.pause(),
        onSkipToNext: () => handlePreNextEpisode('next'),
        onSkipToPrevious: () => handlePreNextEpisode('prev'),
        onSeek: (position) => playerController.seek(position),
      );
      _syncAudioServiceState();
    } catch (e) {
      KazumiLogger().w('AudioController: failed to bind callbacks', error: e);
    }
  }

  void _syncAudioServiceState() {
    try {
      final selection = videoPageController.playbackEpisode;
      final currentRoad = selection.road;
      final currentEpisode = selection.episode;
      if (videoPageController.roadList.isEmpty ||
          currentRoad < 0 ||
          currentRoad >= videoPageController.roadList.length) {
        return;
      }
      final currentRoadData = videoPageController.roadList[currentRoad];
      if (currentEpisode <= 0 || currentRoadData.data.isEmpty) return;
      final episodeRef = videoPageController.resolveEpisode(selection);
      if (episodeRef == null) return;
      final queueIndex = episodeRef.listIndex - 1;

      if (playerController.playback.duration <= Duration.zero) return;

      final canSkipToPrevious = currentEpisode > 1;
      final canSkipToNext = currentEpisode < currentRoadData.data.length;
      final bangumiTitle = videoPageController.bangumiItem.nameCn.isNotEmpty
          ? videoPageController.bangumiItem.nameCn
          : videoPageController.bangumiItem.name;
      final artworkUrl = videoPageController.bangumiItem.images['large'];
      final artworkUri = (artworkUrl == null || artworkUrl.isEmpty)
          ? null
          : Uri.tryParse(artworkUrl);

      unawaited(
        _audioController.updateSession(
          mediaId:
              '${videoPageController.bangumiItem.id}_${currentRoad}_$currentEpisode',
          title: bangumiTitle,
          album: videoPageController.isOfflineMode
              ? videoPageController.offlinePluginName
              : videoPageController.currentPlugin.name,
          artist: episodeRef.displayTitle,
          artUri: artworkUri,
          duration: playerController.playback.duration,
          playing: playerController.playback.playing,
          loading: playerController.playback.loading,
          buffering: playerController.playback.isBuffering,
          completed: playerController.playback.completed,
          updatePosition: playerController.playback.currentPosition,
          bufferedPosition: playerController.playback.buffer,
          speed: playerController.playback.playerSpeed,
          queueIndex: queueIndex,
          canSkipToNext: canSkipToNext,
          canSkipToPrevious: canSkipToPrevious,
        ),
      );
    } catch (e) {
      KazumiLogger()
          .w('AudioController: failed to sync playback state', error: e);
    }
  }

  void _handleFullscreenChange(BuildContext context) async {
    playerController.panel.lockPanel = false;
    _releasePlayerPanelHolds();
    playerController.danmaku.canvasController.clear();

    await _syncHistoryWithWebDav();
  }

  void handleProgressBarDragStart(ThumbDragDetails details) {
    playerTimer?.cancel();
    playerController.pause(enableSync: false);
    _syncAudioServiceState();
    _progressBarDragHold?.release();
    _progressBarDragHold = acquirePlayerPanelHold();
  }

  void handleProgressBarDragEnd() {
    playerController.play(enableSync: false);
    _syncAudioServiceState();
    _progressBarDragHold?.release();
    _progressBarDragHold = null;
    playerTimer?.cancel();
    playerTimer = getPlayerTimer();
  }

  //截图
  Future<void> handleScreenshot() async {
    _playScreenshotFeedback();

    if (isDesktop()) {
      KazumiDialog.showToast(message: '桌面端暂未支持保存截图');
      return;
    }

    try {
      Uint8List? screenshot = await playerController.screenshotPng();

      if (screenshot == null) {
        KazumiDialog.showToast(message: '截图失败：未获取到图像');
        return;
      }

      final result = await SaverGallery.saveImage(
        screenshot,
        fileName: DateTime.timestamp().millisecondsSinceEpoch.toString(),
        skipIfExists: false,
      );
      if (!result.isSuccess) {
        KazumiDialog.showToast(message: '截图保存失败：${result.errorMessage}');
      }
    } catch (e) {
      KazumiDialog.showToast(message: '截图失败：$e');
    }
  }

  void _playScreenshotFeedback() {
    if (!mounted) {
      return;
    }
    _screenshotFeedbackController.forward(from: 0);
  }

  Future<void> handleSuperResolutionChange(SuperResolutionMode mode) async {
    if (!mounted) return;

    // mediacodec_embed 不支持超分辨率
    if (Platform.isAndroid && mode != SuperResolutionMode.off) {
      final String androidVideoRenderer =
          GStorage.getSetting(SettingsKeys.androidVideoRenderer);

      if (androidVideoRenderer == 'mediacodec_embed') {
        await KazumiDialog.show(builder: (context) {
          return AlertDialog(
            title: const Text('兼容性提示'),
            content: const Text('MediaCodec 渲染器不支持超分辨率功能。\n\n'
                '如需使用超分辨率，请在播放设置中将视频渲染器切换为 gpu 或 gpu-next。'),
            actions: [
              TextButton(
                onPressed: () {
                  KazumiDialog.dismiss();
                },
                child: const Text('确定'),
              ),
            ],
          );
        });
        return;
      }
    }

    final bool requiresPerformanceWarning = mode == SuperResolutionMode.quality;
    final bool warningDisabled = GStorage.getSetting(
      SettingsKeys.disableSuperResolutionWarning,
    );

    if (requiresPerformanceWarning && !warningDisabled) {
      bool confirmed = false;

      await KazumiDialog.show(builder: (context) {
        bool dontAskAgain = false;

        return StatefulBuilder(builder: (context, setState) {
          return AlertDialog(
            title: const Text('性能提示'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('启用超分辨率（质量档）可能会造成设备卡顿，是否继续？'),
                const SizedBox(height: 12),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Checkbox(
                      value: dontAskAgain,
                      onChanged: (value) =>
                          setState(() => dontAskAgain = value ?? false),
                    ),
                    const Text('下次不再询问'),
                  ],
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () async {
                  if (dontAskAgain) {
                    await GStorage.putSetting(
                      SettingsKeys.disableSuperResolutionWarning,
                      true,
                    );
                  }
                  KazumiDialog.dismiss();
                },
                child: const Text('取消'),
              ),
              TextButton(
                onPressed: () async {
                  confirmed = true;
                  if (dontAskAgain) {
                    await GStorage.putSetting(
                      SettingsKeys.disableSuperResolutionWarning,
                      true,
                    );
                  }
                  KazumiDialog.dismiss();
                },
                child: const Text('确认'),
              ),
            ],
          );
        });
      });

      if (confirmed) {
        playerController.setShader(mode);
      }
    } else {
      playerController.setShader(mode);
    }
  }

  void handleFullscreen() {
    _handleFullscreenChange(context);
    if (videoPageController.isFullscreen) {
      DisplayModeService.exitFullScreen();
      if (!isDesktop()) {
        widget.showMenuImmediately();
      }
    } else {
      DisplayModeService.enterFullScreen();
      widget.hideMenuImmediately();
    }
    videoPageController.isFullscreen = !videoPageController.isFullscreen;
  }

  bool get _canHidePlayerPanel =>
      playerController.panel.canHidePlayerPanel && _playerPanelHolds.isEmpty;

  void showVideoController({bool restartHideTimer = true}) {
    _panelVisibilityController.forward();
    playerController.panel.showVideoController = true;
    if (restartHideTimer && _canHidePlayerPanel) {
      _startHideTimer();
    }
  }

  void displayVideoController() {
    showVideoController();
  }

  void hideVideoController() {
    if (!_canHidePlayerPanel) {
      return;
    }
    _panelVisibilityController.reverse();
    _cancelHideTimer();
    playerController.panel.showVideoController = false;
  }

  // All temporary panel blockers flow through this single lease registry.
  PlayerPanelHold acquirePlayerPanelHold() {
    late final PlayerPanelHold hold;
    hold = PlayerPanelHold(
      onRelease: () {
        _playerPanelHolds.remove(hold);
        if (_playerPanelHolds.isNotEmpty) {
          return;
        }
        playerController.panel.canHidePlayerPanel = true;
        _startHideTimer();
      },
    );
    _playerPanelHolds.add(hold);
    playerController.panel.canHidePlayerPanel = false;
    _cancelHideTimer();
    showVideoController(restartHideTimer: false);
    return hold;
  }

  // Fullscreen/system overlay changes can dispose menus without delivering
  // MenuAnchor.onClose, so the parent owns the emergency release path.
  void _releasePlayerPanelHolds() {
    for (final hold in _playerPanelHolds.toList()) {
      hold.releaseSilently();
    }
    _playerPanelHolds.clear();
    _progressBarDragHold = null;
    playerController.panel.canHidePlayerPanel = true;
    _startHideTimer();
  }

  Future<void> setPlaybackSpeed(double speed) async {
    await playerController.setPlaybackSpeed(speed);
  }

  Future<void> handleSpeedChange(String type) async {
    try {
      final currentSpeed = playerController.playback.playerSpeed;
      int index = defaultPlaySpeedList.indexOf(currentSpeed);
      if (type == "up") {
        if (index < defaultPlaySpeedList.length - 1) {
          index++;
          setPlaybackSpeed(defaultPlaySpeedList[index]);
        } else {
          KazumiDialog.showToast(message: '已达倍速上限');
        }
      } else if (type == "down") {
        if (index > 0) {
          index--;
          setPlaybackSpeed(defaultPlaySpeedList[index]);
        } else {
          KazumiDialog.showToast(message: '已达倍速下限');
        }
      }
    } catch (e) {
      KazumiLogger().e('PlayerController: speed change failed', error: e);
    }
  }

  Future<void> handleShortcutVolumeChange(String type) async {
    try {
      switch (type) {
        case 'up':
          await playerController
              .setVolume(playerController.playback.volume + 10);
          break;
        case 'down':
          await playerController
              .setVolume(playerController.playback.volume - 10);
          break;
        case 'mute':
          await playerController.toggleMute();
          break;
        default:
          return;
      }
      _showVolumeAdjustmentHud();
      _scheduleAdjustmentHudHide(delay: const Duration(seconds: 1));
    } catch (e) {
      KazumiLogger().e('PlayerController: volume change failed', error: e);
    }
  }

  Future<void> setBrightness(double value) async {
    try {
      await ScreenBrightnessPlatform.instance
          .setApplicationScreenBrightness(value);
    } catch (_) {}
  }

  void _startHideTimer() {
    _cancelHideTimer();
    if (!_canHidePlayerPanel) {
      return;
    }
    hideTimer =
        Timer(Duration(milliseconds: playerControllerLayerDisappearTime), () {
      if (mounted) {
        hideVideoController();
      }
      hideTimer = null;
    });
  }

  void _cancelHideTimer() {
    hideTimer?.cancel();
    hideTimer = null;
  }

  bool _isDanmakuSourceEnabled(DanmakuEntry danmaku) {
    if (!_danmakuBiliBiliSource && danmaku.source.contains('BiliBili')) {
      return false;
    }
    if (!_danmakuGamerSource && danmaku.source.contains('Gamer')) {
      return false;
    }
    if (!_danmakuDanDanSource &&
        !(danmaku.source.contains('BiliBili') ||
            danmaku.source.contains('Gamer'))) {
      return false;
    }
    return true;
  }

  DanmakuItemType _danmakuItemType(DanmakuEntry danmaku) {
    if (danmaku.type == 4) {
      return DanmakuItemType.bottom;
    }
    if (danmaku.type == 5) {
      return DanmakuItemType.top;
    }
    return DanmakuItemType.scroll;
  }

  void _emitDanmakusForCurrentPosition() {
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
      if (!_isDanmakuSourceEnabled(danmaku)) {
        continue;
      }

      final color = _danmakuColor ? danmaku.color : Colors.white;
      final delay = DanmakuTimeline.staggerDelayMilliseconds(
        index: idx,
        total: danmakuCount,
      );
      final scheduledDanmakuGeneration =
          playerController.danmaku.scheduledDanmakuGeneration;
      Future.delayed(Duration(milliseconds: delay), () {
        if (!mounted ||
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
            type: _danmakuItemType(danmaku),
          ),
        );
      });
    }
  }

  Timer getPlayerTimer() {
    return Timer.periodic(const Duration(seconds: 1), (timer) {
      playerController.syncPlaybackState();
      unawaited(_updateAndroidPIPActions());
      _syncAudioServiceState();
      _emitDanmakusForCurrentPosition();
      // 音量相关
      if (!playerController.panel.volumeSeeking) {
        if (isDesktop()) {
          playerController.playback
              .applyExternalVolume(playerController.playback.playerVolume);
        }
      }
      // 亮度相关
      if (!Platform.isWindows &&
          !Platform.isMacOS &&
          !Platform.isLinux &&
          !playerController.panel.brightnessSeeking) {
        ScreenBrightnessPlatform.instance.application.then((value) {
          if (!mounted) return;
          playerController.panel.brightness = value;
        });
      }
      // 历史记录相关
      final historyIdentity = videoPageController.currentHistoryIdentity;
      if (playerController.playback.playerPlaying &&
          !videoPageController.loading &&
          historyIdentity != null &&
          historyIdentity.canRecord) {
        historyController.updateHistory(
          historyIdentity,
          playerController.playback.playerPosition,
        );
      }
      // 自动播放下一集
      final playingSelection = videoPageController.playbackEpisode;
      final playingRoadData =
          videoPageController.roadList[playingSelection.road];
      if (playerController.playback.completed &&
          playingSelection.episode < playingRoadData.data.length &&
          !videoPageController.loading &&
          autoPlayNext) {
        final nextSelection = VideoEpisodeSelection(
          episode: playingSelection.episode + 1,
          road: playingSelection.road,
        );
        final nextRef = videoPageController.resolveEpisode(nextSelection);
        if (nextRef == null) {
          return;
        }
        KazumiDialog.showToast(message: '正在加载${nextRef.displayTitle}');
        try {
          playerTimer!.cancel();
        } catch (_) {}
        widget.changeEpisode(playingSelection.episode + 1,
            currentRoad: playingSelection.road);
      }
      // 一起去看相关
      playerController.setSyncPlayCurrentPosition();
    });
  }

  void showDanmakuSearchDialog(String keyword) async {
    KazumiDialog.dismiss();
    KazumiDialog.showLoading(msg: '弹幕检索中');
    DanmakuSearchResponse danmakuSearchResponse;
    DanmakuEpisodeResponse danmakuEpisodeResponse;
    try {
      danmakuSearchResponse =
          await DanmakuApi.getDanmakuSearchResponse(keyword);
    } catch (e) {
      KazumiDialog.dismiss();
      KazumiDialog.showToast(message: '弹幕检索错误: ${e.toString()}');
      return;
    }
    KazumiDialog.dismiss();
    if (danmakuSearchResponse.animes.isEmpty) {
      KazumiDialog.showToast(message: '未找到匹配结果');
      return;
    }
    await KazumiDialog.show(builder: (context) {
      return Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            shrinkWrap: true,
            children: danmakuSearchResponse.animes.map((danmakuInfo) {
              return ListTile(
                title: Text(danmakuInfo.animeTitle),
                onTap: () async {
                  KazumiDialog.dismiss();
                  KazumiDialog.showLoading(msg: '弹幕检索中');
                  try {
                    danmakuEpisodeResponse =
                        await DanmakuApi.getDanDanEpisodesByDanDanBangumiID(
                            danmakuInfo.animeId);
                  } catch (e) {
                    KazumiDialog.dismiss();
                    KazumiDialog.showToast(message: '弹幕检索错误: ${e.toString()}');
                    return;
                  }
                  KazumiDialog.dismiss();
                  if (danmakuEpisodeResponse.episodes.isEmpty) {
                    KazumiDialog.showToast(message: '未找到匹配结果');
                    return;
                  }
                  KazumiDialog.show(builder: (context) {
                    return Dialog(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 560),
                        child: ListView(
                          shrinkWrap: true,
                          children:
                              danmakuEpisodeResponse.episodes.map((episode) {
                            return ListTile(
                              title: Text(episode.episodeTitle),
                              onTap: () async {
                                KazumiDialog.dismiss();
                                try {
                                  videoPageController
                                      .cancelAutomaticDanmakuLoad();
                                  final hasDanmakus = await playerController
                                      .danmaku
                                      .getDanDanmakuByEpisodeID(
                                          episode.episodeId);
                                  if (!mounted) {
                                    return;
                                  }
                                  if (hasDanmakus) {
                                    playerController.danmaku
                                        .setDanmakuEnabled(true);
                                    KazumiDialog.showToast(message: '弹幕切换成功');
                                  } else {
                                    playerController.danmaku
                                        .setDanmakuEnabled(false);
                                    KazumiDialog.showToast(message: '未找到弹幕内容');
                                  }
                                } catch (e) {
                                  KazumiDialog.showToast(message: '弹幕切换失败');
                                }
                              },
                            );
                          }).toList(),
                        ),
                      ),
                    );
                  });
                },
              );
            }).toList(),
          ),
        ),
      );
    });
  }

  // 弹幕查询
  void showDanmakuSwitch() {
    String searchKeyword = videoPageController.title;
    KazumiDialog.show(
      builder: (context) {
        return AlertDialog(
          title: const Text('弹幕检索'),
          content: TextFormField(
            initialValue: searchKeyword,
            decoration: const InputDecoration(
              hintText: '番剧名',
            ),
            onChanged: (value) => searchKeyword = value,
            onFieldSubmitted: (keyword) {
              showDanmakuSearchDialog(keyword);
            },
          ),
          actions: [
            TextButton(
              onPressed: () {
                KazumiDialog.dismiss();
                widget.keyboardFocus.requestFocus();
              },
              child: Text(
                '取消',
                style: TextStyle(color: Theme.of(context).colorScheme.outline),
              ),
            ),
            TextButton(
              onPressed: () {
                showDanmakuSearchDialog(searchKeyword);
              },
              child: const Text(
                '提交',
              ),
            ),
          ],
        );
      },
    );
  }

  Widget get videoInfoBody {
    return Observer(builder: (context) {
      return ListView(
        children: [
          ListTile(
            title: const Text("Source"),
            subtitle: Text(playerController.videoUrl),
            onTap: () {
              KazumiDialog.showToast(message: '已复制到剪贴板');
              Clipboard.setData(
                ClipboardData(text: playerController.videoUrl),
              );
            },
          ),
          ListTile(
            title: const Text("Resolution"),
            subtitle: Text(
                '${playerController.debug.playerWidth}x${playerController.debug.playerHeight}'),
            onTap: () {
              KazumiDialog.showToast(message: '已复制到剪贴板');
              Clipboard.setData(
                ClipboardData(
                  text:
                      "Resolution\n${playerController.debug.playerWidth}x${playerController.debug.playerHeight}",
                ),
              );
            },
          ),
          ListTile(
            title: const Text("VideoParams"),
            subtitle: Text(playerController.debug.playerVideoParams.toString()),
            onTap: () {
              KazumiDialog.showToast(message: '已复制到剪贴板');
              Clipboard.setData(
                ClipboardData(
                  text:
                      "VideoParams\n${playerController.debug.playerVideoParams.toString()}",
                ),
              );
            },
          ),
          ListTile(
            title: const Text("AudioParams"),
            subtitle: Text(playerController.debug.playerAudioParams.toString()),
            onTap: () {
              KazumiDialog.showToast(message: '已复制到剪贴板');
              Clipboard.setData(
                ClipboardData(
                  text:
                      "AudioParams\n${playerController.debug.playerAudioParams.toString()}",
                ),
              );
            },
          ),
          ListTile(
            title: const Text("Media"),
            subtitle: Text(playerController.debug.playerPlaylist.toString()),
            onTap: () {
              KazumiDialog.showToast(message: '已复制到剪贴板');
              Clipboard.setData(
                ClipboardData(
                  text:
                      "Media\n${playerController.debug.playerPlaylist.toString()}",
                ),
              );
            },
          ),
          ListTile(
            title: const Text("AudioTrack"),
            subtitle: Text(playerController.debug.playerAudioTracks.toString()),
            onTap: () {
              KazumiDialog.showToast(message: '已复制到剪贴板');
              Clipboard.setData(
                ClipboardData(
                  text:
                      "AudioTrack\n${playerController.debug.playerAudioTracks.toString()}",
                ),
              );
            },
          ),
          ListTile(
            title: const Text("VideoTrack"),
            subtitle: Text(playerController.debug.playerVideoTracks.toString()),
            onTap: () {
              KazumiDialog.showToast(message: '已复制到剪贴板');
              Clipboard.setData(
                ClipboardData(
                  text:
                      "VideoTrack\n${playerController.debug.playerVideoTracks.toString()}",
                ),
              );
            },
          ),
          ListTile(
            title: const Text("VideoBitrate"),
            subtitle:
                Text(playerController.debug.playerVideoBitrate.toString()),
            onTap: () {
              KazumiDialog.showToast(message: '已复制到剪贴板');
              Clipboard.setData(
                ClipboardData(
                  text:
                      "VideoBitrate\n${playerController.debug.playerVideoBitrate.toString()}",
                ),
              );
            },
          ),
          ListTile(
            title: const Text("AudioBitrate"),
            subtitle:
                Text(playerController.debug.playerAudioBitrate.toString()),
            onTap: () {
              KazumiDialog.showToast(message: '已复制到剪贴板');
              Clipboard.setData(
                ClipboardData(
                  text:
                      "AudioBitrate\n${playerController.debug.playerAudioBitrate.toString()}",
                ),
              );
            },
          ),
        ],
      );
    });
  }

  Widget get videoDebugLogBody {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.fromLTRB(8.0, 8.0, 8.0, 0),
        child: Observer(builder: (context) {
          return ListView.builder(
            itemCount: playerController.debug.playerLog.length,
            itemBuilder: (context, index) {
              return Text(playerController.debug.playerLog[index]);
            },
          );
        }),
      ),
      floatingActionButton: FloatingActionButton(
          child: const Icon(Icons.copy),
          onPressed: () {
            Clipboard.setData(
              ClipboardData(text: playerController.debug.playerLog.join('\n')),
            );
          }),
    );
  }

  void showVideoInfo() async {
    showModalBottomSheet(
        isScrollControlled: true,
        constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 3 / 4,
            maxWidth: (isDesktop() || isTablet())
                ? MediaQuery.of(context).size.width * 9 / 16
                : MediaQuery.of(context).size.width),
        clipBehavior: Clip.antiAlias,
        context: context,
        builder: (context) {
          return DefaultTabController(
            length: 2,
            child: Scaffold(
              body: Column(
                children: [
                  const PreferredSize(
                    preferredSize: Size.fromHeight(kToolbarHeight),
                    child: Material(
                      child: TabBar(
                        tabs: [
                          Tab(text: '状态'),
                          Tab(text: '日志'),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        videoInfoBody,
                        videoDebugLogBody,
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        });
  }

  void showSyncPlayEndPointSwitchDialog() {
    if (playerController.syncplay.syncplayController != null) {
      KazumiDialog.showToast(message: 'SyncPlay: 请先退出当前房间再切换服务器');
      return;
    }

    final String defaultCustomSyncPlayEndPoint = '自定义服务器';
    String customSyncPlayEndPoint = defaultCustomSyncPlayEndPoint;
    String selectedSyncPlayEndPoint =
        GStorage.getSetting(SettingsKeys.syncPlayEndPoint);

    KazumiDialog.show(
      builder: (context) {
        return StatefulBuilder(builder: (context, setDialogState) {
          List<String> syncPlayEndPoints = [];
          syncPlayEndPoints.addAll(defaultSyncPlayEndPoints);
          syncPlayEndPoints.add(customSyncPlayEndPoint);
          if (!syncPlayEndPoints.contains(selectedSyncPlayEndPoint)) {
            syncPlayEndPoints.add(selectedSyncPlayEndPoint);
          }
          return AlertDialog(
            title: const Text('选择服务器'),
            content: SingleChildScrollView(
              child: ListBody(
                children: <Widget>[
                  DropdownButtonFormField<String>(
                    key: ValueKey(selectedSyncPlayEndPoint),
                    decoration: InputDecoration(
                      border: OutlineInputBorder(),
                    ),
                    isExpanded: true,
                    initialValue: selectedSyncPlayEndPoint,
                    items: syncPlayEndPoints.map((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(
                          value,
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    selectedItemBuilder: (context) {
                      return syncPlayEndPoints.map((String value) {
                        return Text(
                          value,
                          overflow: TextOverflow.ellipsis,
                        );
                      }).toList();
                    },
                    onChanged: (String? newValue) {
                      if (newValue != null) {
                        if (newValue == defaultCustomSyncPlayEndPoint) {
                          String serverText = '';
                          KazumiDialog.show(
                            builder: (context) {
                              return AlertDialog(
                                title: const Text('自定义服务器'),
                                content: TextField(
                                  decoration: const InputDecoration(
                                    hintText: '请输入服务器地址',
                                  ),
                                  onChanged: (value) => serverText = value,
                                ),
                                actions: <Widget>[
                                  TextButton(
                                    child: const Text('取消'),
                                    onPressed: () {
                                      KazumiDialog.dismiss();
                                    },
                                  ),
                                  TextButton(
                                    child: const Text('确认'),
                                    onPressed: () {
                                      if (serverText.isNotEmpty &&
                                          !syncPlayEndPoints
                                              .contains(serverText)) {
                                        KazumiDialog.dismiss();
                                        setDialogState(() {
                                          customSyncPlayEndPoint = serverText;
                                          selectedSyncPlayEndPoint = serverText;
                                        });
                                      } else {
                                        KazumiDialog.showToast(
                                            message: '服务器地址不能重复或为空');
                                      }
                                    },
                                  ),
                                ],
                              );
                            },
                          );
                        } else {
                          setDialogState(() {
                            selectedSyncPlayEndPoint = newValue;
                          });
                        }
                      }
                    },
                  ),
                ],
              ),
            ),
            actions: <Widget>[
              TextButton(
                child: const Text('取消'),
                onPressed: () {
                  KazumiDialog.dismiss();
                },
              ),
              TextButton(
                child: const Text('确认'),
                onPressed: () {
                  GStorage.putSetting(
                    SettingsKeys.syncPlayEndPoint,
                    selectedSyncPlayEndPoint,
                  );
                  KazumiDialog.dismiss();
                },
              ),
            ],
          );
        });
      },
    );
  }

  void showSyncPlayRoomCreateDialog() {
    final formKey = GlobalKey<FormState>();
    String room = '';
    String username = '';
    KazumiDialog.show(builder: (BuildContext context) {
      return AlertDialog(
        title: const Text('加入房间'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: '房间号',
                ),
                onChanged: (value) => room = value,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '请输入房间号';
                  }
                  final regex = RegExp(r'^[0-9]{6,10}$');
                  if (!regex.hasMatch(value)) {
                    return '房间号需要6到10位数字';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                decoration: const InputDecoration(
                  labelText: '用户名',
                ),
                onChanged: (value) => username = value,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '请输入用户名';
                  }
                  final regex = RegExp(r'^[a-zA-Z]{4,12}$');
                  if (!regex.hasMatch(value)) {
                    return '用户名必须为4到12位英文字符';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              KazumiDialog.dismiss();
            },
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                KazumiDialog.dismiss();
                playerController.createSyncPlayRoom(
                    room, username, widget.changeEpisode);
              }
            },
            child: const Text('确定'),
          ),
        ],
      );
    });
  }

  /// Used to decide which panel is used.
  /// It's too complicated to write these in conditional sentence.
  /// * true: use [PlayerItemPanel]
  /// * false: use [SmallestPlayerItemPanel]
  bool needFullPanel(BuildContext context) {
    // windows too small, workaround for ohos floating window
    if (MediaQuery.sizeOf(context).width < LayoutBreakpoint.compact['width']!) {
      return false;
    }
    // in desktop pip mode
    if (videoPageController.isPip) {
      return false;
    }
    // does not meet Google's phone landscape height and tablet landscape width requirements.
    if (!isDesktop() &&
        (MediaQuery.sizeOf(context).height >
                LayoutBreakpoint.compact['height']! &&
            MediaQuery.sizeOf(context).width <
                LayoutBreakpoint.medium['width']!)) {
      return false;
    }
    if (isDesktop() &&
        (MediaQuery.sizeOf(context).height >
                LayoutBreakpoint.compact['height']! &&
            MediaQuery.sizeOf(context).width <
                LayoutBreakpoint.compact['width']!)) {
      return false;
    }
    return true;
  }

  @override
  void onWindowRestore() {
    playerController.danmaku.canvasController.clear();
  }

  @override
  void initState() {
    super.initState();
    playerController = widget.playerController;
    _loadShortcuts();
    _initKeyboardActions();
    _initPlayerMenu();
    _fullscreenListener = mobx.reaction<bool>(
      (_) => videoPageController.isFullscreen,
      (_) {
        _handleFullscreenChange(context);
      },
    );
    _playerSizeListener = mobx.reaction<String>(
      (_) =>
          '${playerController.debug.playerWidth}:${playerController.debug.playerHeight}',
      (_) {
        unawaited(_syncPIPAspectWhenVideoSizeReady());
      },
    );
    if (Platform.isAndroid) {
      PipUtils.initPipHandler(
        onAction: (action) async {
          if (!mounted) return;

          switch (action) {
            case 'play_pause':
              playerController.playOrPause();
              break;

            case 'toggle_danmaku':
              handleDanmaku();
              break;

            case 'forward':
              await skipOP();
              break;
          }

          await _updateAndroidPIPActions(force: true);
        },
      );
      unawaited(_syncAndroidAutoEnterPIPSetting());
      unawaited(_syncAndroidPIPPlayerPageState(true));
      unawaited(_updateAndroidPIPActions(force: true));
    }
    WidgetsBinding.instance.addObserver(this);
    _panelVisibilityController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _screenshotFeedbackController = AnimationController(
      duration: const Duration(milliseconds: 420),
      vsync: this,
    );
    _screenshotFeedbackAnimation = CurvedAnimation(
      parent: _screenshotFeedbackController,
      curve: Curves.linear,
    );
    webDavEnable = GStorage.getSetting(SettingsKeys.webDavEnable);
    webDavEnableHistory = GStorage.getSetting(SettingsKeys.webDavEnableHistory);
    playerController.danmaku.setDanmakuEnabled(
      GStorage.getSetting(SettingsKeys.danmakuEnabledByDefault),
    );
    _border = GStorage.getSetting(SettingsKeys.danmakuBorder);
    _opacity = GStorage.getSetting(SettingsKeys.danmakuOpacity);
    _fontSize = GStorage.getSetting(
      SettingsKeys.danmakuFontSize,
      context: SettingContext(compactLayout: isCompact()),
    );
    _danmakuArea = GStorage.getSetting(SettingsKeys.danmakuArea);
    _hideTop = !GStorage.getSetting(SettingsKeys.danmakuTop);
    _hideBottom = !GStorage.getSetting(SettingsKeys.danmakuBottom);
    _hideScroll = !GStorage.getSetting(SettingsKeys.danmakuScroll);
    _massiveMode = GStorage.getSetting(SettingsKeys.danmakuMassive);
    _danmakuColor = GStorage.getSetting(SettingsKeys.danmakuColor);
    _danmakuDuration = GStorage.getSetting(SettingsKeys.danmakuDuration);
    _danmakuLineHeight = GStorage.getSetting(SettingsKeys.danmakuLineHeight);
    _danmakuBiliBiliSource =
        GStorage.getSetting(SettingsKeys.danmakuBiliBiliSource);
    _danmakuGamerSource = GStorage.getSetting(SettingsKeys.danmakuGamerSource);
    _danmakuDanDanSource =
        GStorage.getSetting(SettingsKeys.danmakuDanDanSource);
    _danmakuFontWeight = GStorage.getSetting(SettingsKeys.danmakuFontWeight);
    _danmakuUseSystemFont = GStorage.getSetting(SettingsKeys.useSystemFont);
    _danmakuBorderSize = GStorage.getSetting(SettingsKeys.danmakuBorderSize);
    haEnable = GStorage.getSetting(SettingsKeys.hAenable);
    autoPlayNext = GStorage.getSetting(SettingsKeys.autoPlayNext);
    backgroundPlayback = GStorage.getSetting(SettingsKeys.backgroundPlayback);
    brightnessVolumeGesture =
        GStorage.getSetting(SettingsKeys.brightnessVolumeGesture);
    playerControllerLayerDisappearTime =
        GStorage.getSetting(SettingsKeys.playerControllerLayerDisappearTime);
    longPressPlaySpeed =
        GStorage.getSetting(SettingsKeys.defaultShortcutForwardPlaySpeed);
    unawaited(_bindAudioService());
    playerTimer = getPlayerTimer();
    windowManager.addListener(this);
    displayVideoController();
  }

  @override
  void dispose() {
    // Playback lifetime is owned by the route-scoped PlayerController.
    // This widget only detaches UI listeners and timers.
    _fullscreenListener();
    _playerSizeListener();
    WidgetsBinding.instance.removeObserver(this);
    windowManager.removeListener(this);
    playerTimer?.cancel();
    hideTimer?.cancel();
    mouseScrollerTimer?.cancel();
    _adjustmentHudHideTimer?.cancel();
    _panelVisibilityController.dispose();
    _screenshotFeedbackController.dispose();
    _disposePlayerMenu();
    if (Platform.isAndroid) {
      unawaited(_syncAndroidPIPPlayerPageState(false));
      PipUtils.disposePipHandler();
    }
    playerController.panel.reset();
    unawaited(_audioController.deactivate());
    _audioController.clearCallbacks();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    collectType =
        collectController.getCollectType(videoPageController.bangumiItem);
    return Observer(
      builder: (context) {
        return ClipRect(
          child: Container(
            color: Colors.black,
            child: MouseRegion(
              cursor: (videoPageController.isFullscreen &&
                      !playerController.panel.showVideoController)
                  ? SystemMouseCursors.none
                  : SystemMouseCursors.basic,
              onHover: (PointerEvent pointerEvent) {
                // workaround for android.
                // I don't know why, but android tap event will trigger onHover event.
                if (isDesktop()) {
                  if (pointerEvent.position.dy > 50 &&
                      pointerEvent.position.dy <
                          MediaQuery.of(context).size.height - 70) {
                    displayVideoController();
                  } else {
                    if (!playerController.panel.showVideoController) {
                      _panelVisibilityController.forward();
                      playerController.panel.showVideoController = true;
                    }
                  }
                }
              },
              child: Listener(
                onPointerSignal: (pointerSignal) {
                  if (pointerSignal is PointerScrollEvent) {
                    _handleMouseScroller();
                    final scrollDelta = pointerSignal.scrollDelta;
                    final double volume =
                        playerController.playback.volume - scrollDelta.dy / 60;
                    playerController.setVolume(volume);
                  }
                },
                child: SizedBox(
                  height: videoPageController.isFullscreen ||
                          videoPageController.isPip
                      ? (MediaQuery.of(context).size.height)
                      : (MediaQuery.of(context).size.width * 9.0 / (16.0)),
                  width: MediaQuery.of(context).size.width,
                  child: Stack(alignment: Alignment.center, children: [
                    Center(
                        child: Focus(
                            // workaround for #461
                            // I don't know why, but the focus node will break popscope.
                            focusNode: widget.keyboardFocus,
                            autofocus: true,
                            onKeyEvent: (focusNode, KeyEvent event) {
                              bool handled = false;
                              final keyLabel =
                                  event.logicalKey.keyLabel.isNotEmpty
                                      ? event.logicalKey.keyLabel
                                      : event.logicalKey.debugName ?? '';
                              if (event is KeyDownEvent) {
                                handled = handleShortcutDown(keyLabel);
                              } else if (event is KeyRepeatEvent) {
                                handled =
                                    handleShortcutLongPress(keyLabel, "Repeat");
                              } else if (event is KeyUpEvent) {
                                handled =
                                    handleShortcutLongPress(keyLabel, "Up");
                              }
                              return handled
                                  ? KeyEventResult.handled
                                  : KeyEventResult.ignored;
                            },
                            child: PlayerItemSurface(
                                playerController: playerController))),
                    (playerController.playback.isBuffering ||
                            videoPageController.loading)
                        ? const Positioned.fill(
                            child: Center(
                              child: CircularProgressIndicator(),
                            ),
                          )
                        : Container(),
                    GestureDetector(
                      onTapDown: (details) {
                        _lastTapPointerKind = details.kind;
                      },
                      onTap: () {
                        _handleTap(_lastTapPointerKind);
                        _lastTapPointerKind = null;
                      },
                      onTapCancel: () {
                        _lastTapPointerKind = null;
                      },
                      onDoubleTapDown: (playerController.panel.lockPanel)
                          ? null
                          : (details) {
                              _lastDoubleTapPointerKind = details.kind;
                            },
                      onDoubleTap: (playerController.panel.lockPanel)
                          ? null
                          : () {
                              _handleDoubleTap(
                                _lastDoubleTapPointerKind ??
                                    _lastTapPointerKind,
                              );
                              _lastDoubleTapPointerKind = null;
                              _lastTapPointerKind = null;
                            },
                      onLongPressStart: (_) {
                        if (playerController.panel.lockPanel) {
                          return;
                        }
                        setState(() {
                          playerController.panel.showPlaySpeed = true;
                        });
                        lastPlayerSpeed = playerController.playback.playerSpeed;
                        setPlaybackSpeed(longPressPlaySpeed);
                      },
                      onLongPressEnd: (_) {
                        if (playerController.panel.lockPanel) {
                          return;
                        }
                        setState(() {
                          playerController.panel.showPlaySpeed = false;
                        });
                        setPlaybackSpeed(lastPlayerSpeed);
                      },
                      child: Container(
                        color: Colors.transparent,
                        width: double.infinity,
                        height: double.infinity,
                      ),
                    ),
                    // 弹幕面板
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      height: videoPageController.isFullscreen ||
                              videoPageController.isPip
                          ? MediaQuery.sizeOf(context).height
                          : (MediaQuery.sizeOf(context).width * 9 / 16),
                      child: DanmakuScreen(
                        key: _danmuKey,
                        createdController: (DanmakuController e) {
                          playerController.danmaku.canvasController = e;
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            playerController.updateDanmakuSpeed();
                          });
                        },
                        option: DanmakuOption(
                          hideTop: _hideTop,
                          hideScroll: _hideScroll,
                          hideBottom: _hideBottom,
                          area: _danmakuArea,
                          opacity: _opacity,
                          fontSize: _fontSize,
                          duration: _danmakuDuration /
                              playerController.playback.playerSpeed,
                          lineHeight: _danmakuLineHeight,
                          strokeWidth: _border ? _danmakuBorderSize : 0.0,
                          fontWeight: _danmakuFontWeight,
                          massiveMode: _massiveMode,
                          fontFamily: _danmakuUseSystemFont
                              ? null
                              : customAppFontFamily,
                        ),
                      ),
                    ),
                    Positioned.fill(
                      child: PlayerScreenshotFeedbackOverlay(
                        animation: _screenshotFeedbackAnimation,
                      ),
                    ),
                    // 播放器控制面板
                    (needFullPanel(context))
                        ? PlayerItemPanel(
                            playerController: playerController,
                            onBackPressed: widget.onBackPressed,
                            setPlaybackSpeed: setPlaybackSpeed,
                            showDanmakuSwitch: showDanmakuSwitch,
                            changeEpisode: widget.changeEpisode,
                            toggleMenu: widget.toggleMenu,
                            handleFullscreen: handleFullscreen,
                            handleProgressBarDragStart:
                                handleProgressBarDragStart,
                            handleProgressBarDragEnd: handleProgressBarDragEnd,
                            handleSuperResolutionChange:
                                handleSuperResolutionChange,
                            handlePreNextEpisode: handlePreNextEpisode,
                            panelVisibilityController:
                                _panelVisibilityController,
                            keyboardFocus: widget.keyboardFocus,
                            sendDanmaku: widget.sendDanmaku,
                            acquirePlayerPanelHold: acquirePlayerPanelHold,
                            handleDanmaku: handleDanmaku,
                            showVideoInfo: showVideoInfo,
                            showSyncPlayRoomCreateDialog:
                                showSyncPlayRoomCreateDialog,
                            showSyncPlayEndPointSwitchDialog:
                                showSyncPlayEndPointSwitchDialog,
                            showDanmakuDestinationPickerAndSend:
                                widget.showDanmakuDestinationPickerAndSend,
                            pauseForTimedShutdown: widget.pauseForTimedShutdown,
                            disableAnimations: widget.disableAnimations,
                            handleScreenShot: handleScreenshot,
                            skipOP: skipOP,
                          )
                        : SmallestPlayerItemPanel(
                            playerController: playerController,
                            onBackPressed: widget.onBackPressed,
                            setPlaybackSpeed: setPlaybackSpeed,
                            showDanmakuSwitch: showDanmakuSwitch,
                            handleFullscreen: handleFullscreen,
                            handleProgressBarDragStart:
                                handleProgressBarDragStart,
                            handleProgressBarDragEnd: handleProgressBarDragEnd,
                            handleSuperResolutionChange:
                                handleSuperResolutionChange,
                            panelVisibilityController:
                                _panelVisibilityController,
                            keyboardFocus: widget.keyboardFocus,
                            acquirePlayerPanelHold: acquirePlayerPanelHold,
                            handleDanmaku: handleDanmaku,
                            showVideoInfo: showVideoInfo,
                            showSyncPlayRoomCreateDialog:
                                showSyncPlayRoomCreateDialog,
                            showSyncPlayEndPointSwitchDialog:
                                showSyncPlayEndPointSwitchDialog,
                            pauseForTimedShutdown: widget.pauseForTimedShutdown,
                            disableAnimations: widget.disableAnimations,
                            skipOP: skipOP,
                          ),
                    // 播放器手势控制
                    Positioned.fill(
                      left: 16,
                      top: 25,
                      right: 15,
                      bottom: 15,
                      child: (isDesktop() || playerController.panel.lockPanel)
                          ? Container()
                          : GestureDetector(
                              onHorizontalDragStart: (_) {
                                playerController.panel.seekDirection = 0;
                              },
                              onHorizontalDragUpdate:
                                  (DragUpdateDetails details) {
                                playerController.panel.showSeekTime = true;
                                if (details.delta.dx != 0) {
                                  playerController.panel.seekDirection =
                                      details.delta.dx > 0 ? 1 : -1;
                                }
                                playerTimer?.cancel();
                                playerController.pause(enableSync: false);
                                final double scale =
                                    180000 / MediaQuery.sizeOf(context).width;
                                int ms = (playerController.playback
                                            .currentPosition.inMilliseconds +
                                        (details.delta.dx * scale).round())
                                    .clamp(
                                        0,
                                        playerController
                                            .playback.duration.inMilliseconds);
                                playerController.playback.currentPosition =
                                    Duration(milliseconds: ms);
                              },
                              onHorizontalDragEnd: (_) {
                                playerController.play(enableSync: false);
                                playerController.seek(
                                    playerController.playback.currentPosition);
                                playerTimer?.cancel();
                                playerTimer = getPlayerTimer();
                                playerController.panel.showSeekTime = false;
                                playerController.panel.seekDirection = 0;
                              },
                              onVerticalDragUpdate:
                                  (DragUpdateDetails details) async {
                                if (!brightnessVolumeGesture) {
                                  return;
                                }
                                final double totalWidth =
                                    MediaQuery.sizeOf(context).width;
                                final double totalHeight =
                                    MediaQuery.sizeOf(context).height;
                                final double tapPosition =
                                    details.localPosition.dx;
                                final double sectionWidth = totalWidth / 2;
                                final double delta = details.delta.dy;

                                if (tapPosition < sectionWidth) {
                                  // 左边区域
                                  playerController.panel.brightnessSeeking =
                                      true;
                                  _showBrightnessAdjustmentHud();
                                  final double level = (totalHeight) * 2;
                                  final double brightness =
                                      playerController.panel.brightness -
                                          delta / level;
                                  final double result =
                                      brightness.clamp(0.0, 1.0);
                                  setBrightness(result);
                                  playerController.panel.brightness = result;
                                } else {
                                  // 右边区域
                                  _showVolumeAdjustmentHud();
                                  if (!playerController.panel.volumeSeeking) {
                                    playerController.panel.volumeSeeking = true;
                                    playerController.playback
                                        .invalidatePreciseVolume();
                                  }
                                  final double baseVolume = playerController
                                              .playback.preciseVolume >=
                                          0
                                      ? playerController.playback.preciseVolume
                                      : playerController.playback.volume;
                                  final double level = (totalHeight) * 0.03;
                                  final double volume =
                                      baseVolume - delta / level;
                                  playerController
                                      .setVolumeDuringGesture(volume);
                                }
                              },
                              onVerticalDragEnd: (_) {
                                _finishAdjustmentGesture();
                              },
                              onVerticalDragCancel: () {
                                _finishAdjustmentGesture();
                              },
                            ),
                    ),
                  ]),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
