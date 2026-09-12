import 'dart:async';
import 'dart:io';
import 'package:kazumi/pages/player/player_item_panel.dart';
import 'package:kazumi/pages/player/player_keyboard_shortcuts.dart';
import 'package:kazumi/pages/player/controller/player_super_resolution.dart';
import 'package:kazumi/pages/player/player_panel_hold.dart';
import 'package:kazumi/pages/player/player_pointer_interaction.dart';
import 'package:kazumi/pages/player/player_screenshot_feedback_overlay.dart';
import 'package:kazumi/pages/player/smallest_player_item_panel.dart';
import 'package:kazumi/pages/player/syncplay_sheet.dart';
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
import 'package:kazumi/pages/player/video_details_sheet.dart';
import 'package:screen_brightness_platform_interface/screen_brightness_platform_interface.dart';
import 'package:kazumi/pages/history/history_controller.dart';
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
import 'package:kazumi/bean/widget/gamepad_navigation.dart';

enum _InteractiveSeekSource { progressBar, surface }

class PlayerItem extends StatefulWidget {
  const PlayerItem({
    super.key,
    required this.playerController,
    required this.videoPageController,
    required this.toggleMenu,
    required this.showMenuImmediately,
    required this.hideMenuImmediately,
    required this.changeEpisode,
    required this.onBackPressed,
    required this.keyboardFocus,
    required this.pauseForTimedShutdown,
    this.disableAnimations = false,
  });

  final PlayerController playerController;
  final VideoPageController videoPageController;
  final VoidCallback toggleMenu;
  final VoidCallback showMenuImmediately;
  final VoidCallback hideMenuImmediately;
  final Future<void> Function(int episode, {int currentRoad, int offset})
      changeEpisode;
  final void Function(BuildContext) onBackPressed;
  final FocusNode keyboardFocus;
  final bool disableAnimations;
  final VoidCallback pauseForTimedShutdown;

  @override
  State<PlayerItem> createState() => _PlayerItemState();
}

class _PlayerItemState extends State<PlayerItem>
    with
        WindowListener,
        WidgetsBindingObserver,
        TickerProviderStateMixin,
        KazumiDialogOwner {
  static const Duration _interactiveSeekRecoveryTimeout = Duration(seconds: 5);

  late final PlayerController playerController;
  late final VideoPageController videoPageController =
      widget.videoPageController;
  final HistoryController historyController = inject<HistoryController>();
  final MyController myController = inject<MyController>();
  AudioController get _audioController => playerController.audioController;
  late final Map<String, PlayerShortcutAction> keyboardActions;
  late final Map<String, PlayerLongPressShortcutActions>
      keyboardLongPressActions;

  late bool webDavEnable;
  late bool webDavEnableHistory;

  final _danmuKey = GlobalKey();
  final _videoSurfaceKey = GlobalKey();
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

  late bool autoPlayNext;
  late bool backgroundPlayback;
  late bool brightnessVolumeGesture;

  // Auto-hide delay in milliseconds.
  late int playerControllerLayerDisappearTime;

  Timer? hideTimer;
  Timer? playerTimer;
  Timer? mouseScrollerTimer;
  Timer? _adjustmentHudHideTimer;
  final Set<PlayerPanelHold> _playerPanelHolds = <PlayerPanelHold>{};
  int _openPlayerMenuCount = 0;
  PlayerPanelHold? _progressBarDragHold;
  Timer? _interactiveSeekRecoveryTimer;
  int? _progressBarPointer;
  PointerDeviceKind? _lastTapPointerKind;
  PointerDeviceKind? _lastDoubleTapPointerKind;
  Duration _surfaceSeekStartPosition = Duration.zero;
  double _surfaceSeekCumulativeDx = 0;
  _InteractiveSeekSource? _interactiveSeekSource;
  int _interactiveSeekGeneration = 0;
  bool _interactiveSeekWasPlaying = false;
  bool _playerPanelHasFocus = false;
  final FocusScopeNode _panelFocusScopeNode =
      FocusScopeNode(debugLabel: 'Player controls');

  late final AnimationController _panelVisibilityController;
  late final AnimationController _screenshotFeedbackController;
  late final Animation<double> _screenshotFeedbackAnimation;

  double lastPlayerSpeed = 1.0;
  late double longPressPlaySpeed;
  bool? _lastPipPlaying;
  bool? _lastPipDanmakuEnabled;
  Rect? _lastPipSourceRect;
  bool _pipSourceRectSyncScheduled = false;
  bool _pipEnterRequested = false;
  late mobx.ReactionDisposer _playerSizeListener;

  late mobx.ReactionDisposer _fullscreenListener;

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    _scheduleAndroidPIPSourceRectSync();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _abortInteractiveSeek(resumePlayback: false);
    }
    if (state == AppLifecycleState.paused && !backgroundPlayback) {
      // Suspend before awaiting pause so a later resume wins; pause alone keeps prefetching.
      final suspend = playerController.playback.setPrefetchSuspended(true);
      if (playerController.playback.mediaPlayer != null &&
          playerController.playback.playerPlaying) {
        try {
          await playerController.pause(enableSync: false);
        } catch (_) {}
      }
      await suspend;
      return;
    }
    if (state == AppLifecycleState.resumed) {
      await playerController.playback.setPrefetchSuspended(false);
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
    // In picture in picture the measured rect is the small window itself.
    final Rect? sourceRect = videoPageController.isPip
        ? _lastPipSourceRect
        : _androidPIPSourceRect();
    if (!force &&
        _lastPipPlaying == playing &&
        _lastPipDanmakuEnabled == danmakuEnabled &&
        _lastPipSourceRect == sourceRect) {
      return;
    }

    _lastPipPlaying = playing;
    _lastPipDanmakuEnabled = danmakuEnabled;
    _lastPipSourceRect = sourceRect;
    await PipUtils.updateAndroidPIPActions(
      playing: playing,
      danmakuEnabled: danmakuEnabled,
      width: playerController.debug.playerWidth,
      height: playerController.debug.playerHeight,
      sourceRect: sourceRect,
    );
  }

  // Android PiP expects the letterboxed video bounds in physical pixels.
  Rect? _androidPIPSourceRect() {
    if (!mounted) {
      return null;
    }
    final renderObject = _videoSurfaceKey.currentContext?.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) {
      return null;
    }
    final Size size = renderObject.size;
    if (size.isEmpty) {
      return null;
    }
    Rect rect = renderObject.localToGlobal(Offset.zero) & size;
    final int videoWidth = playerController.debug.playerWidth;
    final int videoHeight = playerController.debug.playerHeight;
    if (videoWidth > 0 && videoHeight > 0) {
      final double scale =
          (rect.width / videoWidth) < (rect.height / videoHeight)
              ? rect.width / videoWidth
              : rect.height / videoHeight;
      rect = Rect.fromCenter(
        center: rect.center,
        width: videoWidth * scale,
        height: videoHeight * scale,
      );
    }
    final double ratio = MediaQuery.devicePixelRatioOf(context);
    return Rect.fromLTRB(
      rect.left * ratio,
      rect.top * ratio,
      rect.right * ratio,
      rect.bottom * ratio,
    );
  }

  // Remove controls before PiP entry to avoid rebuilding during the resize animation.
  Future<void> enterAndroidPictureInPicture() async {
    if (!Platform.isAndroid || !mounted) {
      return;
    }
    final bool supported = await PipUtils.isAndroidPIPSupported();
    if (!mounted) {
      return;
    }
    if (!supported) {
      KazumiDialog.showToast(message: '当前设备不支持画中画');
      return;
    }
    setState(() {
      _pipEnterRequested = true;
    });
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) {
      return;
    }
    await _updateAndroidPIPActions(force: true);
    final bool entered = await PipUtils.enterAndroidPIPWindow(
      width: playerController.debug.playerWidth,
      height: playerController.debug.playerHeight,
    );
    if (entered || !mounted) {
      return;
    }
    KazumiDialog.showToast(message: '进入画中画失败');
    setState(() {
      _pipEnterRequested = false;
    });
  }

  void _handleAndroidPIPModeChanged(bool inPipMode) {
    if (!mounted || videoPageController.isPip == inPipMode) {
      return;
    }
    setState(() {
      videoPageController.isPip = inPipMode;
    });
    if (!inPipMode) {
      _pipEnterRequested = false;
      _scheduleAndroidPIPSourceRectSync();
    }
  }

  void _scheduleAndroidPIPSourceRectSync() {
    if (!Platform.isAndroid || _pipSourceRectSyncScheduled) {
      return;
    }
    _pipSourceRectSyncScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _pipSourceRectSyncScheduled = false;
      if (!mounted) {
        return;
      }
      unawaited(_updateAndroidPIPActions());
    });
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

  void _initKeyboardActions() {
    keyboardActions = {
      'playorpause': () => playerController.playOrPause(),
      'forward': handleShortcutForwardDown,
      'rewind': handleShortcutRewind,
      'next': () => handlePreNextEpisode('next'),
      'prev': () => handlePreNextEpisode('prev'),
      'volumeup': () => handleShortcutVolumeChange('up'),
      'volumedown': () => handleShortcutVolumeChange('down'),
      'togglemute': () => handleShortcutVolumeChange('mute'),
      'fullscreen': () => handleShortcutFullscreen(),
      'screenshot': handleScreenshot,
      'skip': skipOP,
      'exitfullscreen': () => handleShortcutExitFullscreen(),
      'toggledanmaku': () => handleDanmaku(),
      'speed1': () => setPlaybackSpeed(1.0),
      'speed2': () => setPlaybackSpeed(2.0),
      'speed3': () => setPlaybackSpeed(3.0),
      'speedup': () => handleSpeedChange('up'),
      'speeddown': () => handleSpeedChange('down'),
    };
    keyboardLongPressActions = {
      'forward': PlayerLongPressShortcutActions(
        onRepeat: handleShortcutForwardRepeat,
        onRelease: handleShortcutForwardUp,
      ),
    };
  }

  void _initPlayerMenu() {
    unawaited(PlayerMenuService.initialize(keyboardActions));
  }

  void _disposePlayerMenu() {
    unawaited(PlayerMenuService.dispose());
  }

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
    if (targetRef != null) {
      KazumiDialog.showToast(message: '正在加载${targetRef.displayTitle}');
    }
    widget.changeEpisode(targetEpisode, currentRoad: currentRoad);
  }

  Future<void> handleShortcutRewind() async {
    try {
      await _seekWithPlayerTimer(
        () => playerController.seekBy(
          Duration(seconds: -playerController.playback.arrowKeySkipTime),
        ),
      );
    } catch (e) {
      KazumiLogger().e('PlayerController: seek failed', error: e);
    }
  }

  void handleShortcutForwardDown() {
    lastPlayerSpeed = playerController.playback.playerSpeed;
  }

  Future<void> handleShortcutForwardRepeat() async {
    final double defaultShortcutForwardPlaySpeed =
        GStorage.getSetting(SettingsKeys.defaultShortcutForwardPlaySpeed);
    if (playerController.playback.playerSpeed <
        defaultShortcutForwardPlaySpeed) {
      playerController.panel.showPlaySpeed = true;
      await setPlaybackSpeed(defaultShortcutForwardPlaySpeed);
    }
  }

  Future<void> handleShortcutForwardUp() async {
    if (playerController.panel.showPlaySpeed) {
      playerController.panel.showPlaySpeed = false;
      await setPlaybackSpeed(lastPlayerSpeed);
    } else {
      try {
        await _seekWithPlayerTimer(
          () => playerController.seekBy(
            Duration(seconds: playerController.playback.arrowKeySkipTime),
          ),
        );
      } catch (e) {
        KazumiLogger().e('PlayerController: seek failed', error: e);
      }
    }
  }

  void handleShortcutFullscreen() {
    if (!videoPageController.isPip) handleFullscreen();
  }

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
      showVideoController();
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

  Future<void> skipOP() async {
    await playerController.seekBy(
      Duration(seconds: playerController.playback.buttonSkipTime),
    );
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
        artworkUrl: videoPageController.bangumiItem.images['large'],
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

      unawaited(
        _audioController.updateSession(
          mediaId:
              '${videoPageController.bangumiItem.id}_${currentRoad}_$currentEpisode',
          title: bangumiTitle,
          album: videoPageController.isOfflineMode
              ? videoPageController.offlinePluginName
              : videoPageController.currentPlugin.name,
          artist: episodeRef.displayTitle,
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
    _abortInteractiveSeek();
    playerController.panel.lockPanel = false;
    _releasePlayerPanelHolds();
    playerController.danmaku.canvasController.clear();
    _scheduleAndroidPIPSourceRectSync();

    await _syncHistoryWithWebDav();
  }

  void handleProgressBarDragStart() {
    if (!_beginInteractiveSeek(_InteractiveSeekSource.progressBar)) {
      return;
    }
    _syncAudioServiceState();
    _progressBarDragHold = acquirePlayerPanelHold();
  }

  void handleProgressBarDragUpdate(Duration duration) {
    if (_interactiveSeekSource != _InteractiveSeekSource.progressBar) {
      return;
    }
    if (playerController.seeking.updateInteractiveSeek(duration)) {
      _armInteractiveSeekRecovery();
    }
  }

  Future<void> handleProgressBarSeek(Duration duration) async {
    if (_interactiveSeekSource == _InteractiveSeekSource.surface) {
      return;
    }
    if (playerController.seeking.hasActiveInteractiveSeek) {
      // An onSeek arriving again while commit is pending must not seek twice.
      if (playerController.seeking.updateInteractiveSeek(duration)) {
        await _commitInteractiveSeek();
      }
      return;
    }
    final generation = _interactiveSeekGeneration;
    try {
      await playerController.seek(duration);
    } finally {
      if (mounted && generation == _interactiveSeekGeneration) {
        _clearInteractiveSeekUi();
      }
    }
  }

  bool _beginInteractiveSeek(_InteractiveSeekSource source) {
    if (playerController.seeking.hasActiveInteractiveSeek) {
      return false;
    }
    playerTimer?.cancel();
    _interactiveSeekGeneration++;
    _interactiveSeekSource = source;
    _interactiveSeekWasPlaying = playerController.playback.playing;
    playerController.seeking.beginInteractiveSeek();
    if (!playerController.seeking.hasActiveInteractiveSeek) {
      _interactiveSeekSource = null;
      return false;
    }
    _armInteractiveSeekRecovery();
    return true;
  }

  void _armInteractiveSeekRecovery() {
    _interactiveSeekRecoveryTimer?.cancel();
    _interactiveSeekRecoveryTimer = Timer(
      _interactiveSeekRecoveryTimeout,
      _abortInteractiveSeek,
    );
  }

  Future<void> _commitInteractiveSeek() async {
    final generation = _interactiveSeekGeneration;
    var completed = false;
    try {
      completed = await playerController.seeking.commitInteractiveSeek();
    } catch (e) {
      KazumiLogger().e('PlayerController: interactive seek failed', error: e);
    } finally {
      if (mounted && generation == _interactiveSeekGeneration) {
        _clearInteractiveSeekUi(syncAudioService: completed);
      }
    }
  }

  Future<void> _cancelInteractiveSeek() async {
    final generation = _interactiveSeekGeneration;
    var completed = false;
    try {
      completed = await playerController.seeking.cancelInteractiveSeek();
    } catch (e) {
      KazumiLogger().e(
        'PlayerController: interactive seek cancellation failed',
        error: e,
      );
    } finally {
      if (mounted && generation == _interactiveSeekGeneration) {
        _clearInteractiveSeekUi(syncAudioService: completed);
      }
    }
  }

  void _beginSurfaceInteractiveSeek() {
    if (!_beginInteractiveSeek(_InteractiveSeekSource.surface)) {
      return;
    }
    _surfaceSeekStartPosition = playerController.playback.currentPosition;
    _surfaceSeekCumulativeDx = 0;
    playerController.panel.seekDirection = 0;
    playerController.panel.showSeekTime = true;
  }

  void _updateSurfaceInteractiveSeek(
    BuildContext context,
    DragUpdateDetails details,
  ) {
    if (!playerController.seeking.hasActiveInteractiveSeek) {
      return;
    }
    _surfaceSeekCumulativeDx += details.delta.dx;
    final target = horizontalDragSeekTarget(
      initialPosition: _surfaceSeekStartPosition,
      videoDuration: playerController.playback.duration,
      cumulativeDeltaX: _surfaceSeekCumulativeDx,
      surfaceWidth: MediaQuery.sizeOf(context).width,
    );
    playerController.panel.seekDirection = interactiveSeekDirection(
      initialPosition: _surfaceSeekStartPosition,
      target: target,
    );
    if (playerController.seeking.updateInteractiveSeek(target)) {
      _armInteractiveSeekRecovery();
    }
  }

  void _finishSurfaceSeekHud() {
    playerController.panel.showSeekTime = false;
    playerController.panel.seekDirection = 0;
    _surfaceSeekCumulativeDx = 0;
  }

  void _commitSurfaceInteractiveSeek() {
    _finishSurfaceSeekHud();
    if (_interactiveSeekSource == _InteractiveSeekSource.surface &&
        playerController.seeking.hasActiveInteractiveSeek) {
      unawaited(_commitInteractiveSeek());
    }
  }

  void _cancelSurfaceInteractiveSeek() {
    _finishSurfaceSeekHud();
    if (_interactiveSeekSource == _InteractiveSeekSource.surface &&
        playerController.seeking.hasActiveInteractiveSeek) {
      unawaited(_cancelInteractiveSeek());
    }
  }

  void _handleProgressBarPointerDown(int pointer) {
    _progressBarPointer ??= pointer;
  }

  void _handleProgressBarPointerUp(int pointer) {
    if (_progressBarPointer == pointer) {
      _progressBarPointer = null;
    }
  }

  void _handleProgressBarPointerCancel(int pointer) {
    if (_progressBarPointer != pointer) {
      return;
    }
    _progressBarPointer = null;
    if (_interactiveSeekSource == _InteractiveSeekSource.progressBar) {
      unawaited(_cancelInteractiveSeek());
    }
  }

  void _clearInteractiveSeekUi({bool syncAudioService = false}) {
    _interactiveSeekGeneration++;
    _interactiveSeekRecoveryTimer?.cancel();
    _interactiveSeekRecoveryTimer = null;
    _progressBarPointer = null;
    _progressBarDragHold?.release();
    _progressBarDragHold = null;
    _interactiveSeekSource = null;
    _interactiveSeekWasPlaying = false;
    _finishSurfaceSeekHud();
    if (syncAudioService) {
      _syncAudioServiceState();
    }
    _restartPlayerTimer();
  }

  void _abortInteractiveSeek({bool resumePlayback = true}) {
    if (!playerController.seeking.hasActiveInteractiveSeek &&
        _interactiveSeekSource == null) {
      return;
    }
    final shouldResume = _interactiveSeekWasPlaying;
    playerController.seeking.invalidateInteractiveSeek();
    if (mounted) {
      _clearInteractiveSeekUi();
    }
    if (shouldResume && resumePlayback) {
      unawaited(
        playerController.play(enableSync: false).catchError((_) {}),
      );
    }
  }

  void _updateSurfaceVerticalDrag(
    BuildContext context,
    DragUpdateDetails details,
  ) {
    if (!brightnessVolumeGesture) {
      return;
    }
    final double totalWidth = MediaQuery.sizeOf(context).width;
    final double totalHeight = MediaQuery.sizeOf(context).height;
    final double tapPosition = details.localPosition.dx;
    final double sectionWidth = totalWidth / 2;
    final double delta = details.delta.dy;

    if (tapPosition < sectionWidth) {
      playerController.panel.brightnessSeeking = true;
      _showBrightnessAdjustmentHud();
      final double level = totalHeight * 2;
      final double brightness =
          playerController.panel.brightness - delta / level;
      final double result = brightness.clamp(0.0, 1.0);
      setBrightness(result);
      playerController.panel.brightness = result;
    } else {
      _showVolumeAdjustmentHud();
      if (!playerController.panel.volumeSeeking) {
        playerController.panel.volumeSeeking = true;
        playerController.playback.invalidatePreciseVolume();
      }
      final double baseVolume = playerController.playback.preciseVolume >= 0
          ? playerController.playback.preciseVolume
          : playerController.playback.volume;
      final double level = totalHeight * 0.03;
      final double volume = baseVolume - delta / level;
      playerController.setVolumeDuringGesture(volume);
    }
  }

  void _restartPlayerTimer() {
    playerTimer?.cancel();
    playerTimer = getPlayerTimer();
  }

  Future<void> _seekWithPlayerTimer(
    Future<void> Function() seekAction,
  ) async {
    playerTimer?.cancel();
    try {
      await seekAction();
    } finally {
      if (mounted) {
        _restartPlayerTimer();
      }
    }
  }

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

    // The mediacodec_embed renderer cannot apply super-resolution shaders.
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
                  KazumiDialog.dismiss(context: context);
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
                  if (!context.mounted) return;
                  KazumiDialog.dismiss(context: context);
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
                  if (!context.mounted) return;
                  KazumiDialog.dismiss(context: context);
                },
                child: const Text('确认'),
              ),
            ],
          );
        });
      });

      if (confirmed && mounted) {
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

  void hideVideoController() {
    if (!_canHidePlayerPanel) {
      return;
    }
    _panelVisibilityController.reverse();
    _cancelHideTimer();
    playerController.panel.showVideoController = false;
  }

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

  void _handlePlayerMenuVisibilityChanged(bool isOpen) {
    if (isOpen) {
      _openPlayerMenuCount++;
    } else if (_openPlayerMenuCount > 0) {
      _openPlayerMenuCount--;
    }
  }

  // Fullscreen and system overlays can dispose controls before their holds are released.
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
      if (!playerController.panel.volumeSeeking) {
        if (isDesktop()) {
          playerController.playback
              .applyExternalVolume(playerController.playback.playerVolume);
        }
      }
      if (!Platform.isWindows &&
          !Platform.isMacOS &&
          !Platform.isLinux &&
          !playerController.panel.brightnessSeeking) {
        ScreenBrightnessPlatform.instance.application.then((value) {
          if (!mounted) return;
          playerController.panel.brightness = value;
        });
      }
      final historyIdentity = videoPageController.currentHistoryIdentity;
      if (playerController.playback.playerPlaying &&
          !videoPageController.loading &&
          historyIdentity != null &&
          historyIdentity.canRecord) {
        historyController.updateHistory(
          historyIdentity,
          playerController.playback.playerPosition,
          duration: playerController.playback.playerDuration,
        );
      }
      final playingSelection = videoPageController.playbackEpisode;
      final playingRoadData =
          videoPageController.roadList[playingSelection.road];
      if (playerController.playback.completed && !videoPageController.loading) {
        if (playerController.playback.resumedNearEnd) {
          // Replay stale near-end resumes instead of advancing to the next episode.
          unawaited(playerController.playback.restartFromBeginning());
        } else if (playingSelection.episode < playingRoadData.data.length &&
            autoPlayNext) {
          final nextSelection = VideoEpisodeSelection(
            episode: playingSelection.episode + 1,
            road: playingSelection.road,
          );
          // Let the controller report resolution failures without retrying every tick.
          final nextRef = videoPageController.resolveEpisode(nextSelection);
          if (nextRef != null) {
            KazumiDialog.showToast(message: '正在加载${nextRef.displayTitle}');
          }
          try {
            playerTimer!.cancel();
          } catch (_) {}
          widget.changeEpisode(playingSelection.episode + 1,
              currentRoad: playingSelection.road);
        }
      }
      playerController.setSyncPlayCurrentPosition();
    });
  }

  Future<void> showDanmakuSwitch() => dialogs.run((task) async {
        String keyword = videoPageController.title;
        final query = await task.show<String>(
          builder: (context) => AlertDialog(
            title: const Text('弹幕检索'),
            content: TextFormField(
              initialValue: keyword,
              decoration: const InputDecoration(hintText: '番剧名'),
              onChanged: (value) => keyword = value,
              onFieldSubmitted: (value) =>
                  KazumiDialog.dismiss(context: context, popWith: value),
            ),
            actions: [
              TextButton(
                onPressed: () => KazumiDialog.dismiss(context: context),
                child: const Text('取消'),
              ),
              TextButton(
                onPressed: () =>
                    KazumiDialog.dismiss(context: context, popWith: keyword),
                child: const Text('提交'),
              ),
            ],
          ),
        );
        final response = await task.loading(
          message: '弹幕检索中',
          action: () => DanmakuApi.searchAnimes(query),
        );
        if (response.animes.isEmpty) {
          KazumiDialog.showToast(message: '未找到匹配结果');
          return;
        }
        final anime = await task.show<DanmakuSearchAnime>(
          builder: (context) => Dialog(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: ListView(
                shrinkWrap: true,
                children: [
                  if (response.hasMore)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                      child: Text(
                        '结果较多，仅显示部分条目，可补充更完整的番剧名缩小范围',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.outline,
                            ),
                      ),
                    ),
                  for (final anime in response.animes)
                    ListTile(
                      title: Text(anime.animeTitle),
                      subtitle: anime.typeDescription.isEmpty
                          ? null
                          : Text(anime.typeDescription),
                      onTap: () => KazumiDialog.dismiss(
                          context: context, popWith: anime),
                    ),
                ],
              ),
            ),
          ),
        );
        final episodeResponse = await task.loading(
          message: '弹幕检索中',
          action: () =>
              DanmakuApi.getDanDanEpisodesByDanDanBangumiID(anime.animeId),
        );
        if (episodeResponse.episodes.isEmpty) {
          KazumiDialog.showToast(message: '未找到匹配结果');
          return;
        }
        final episode = await task.show<DanmakuEpisode>(
          builder: (context) => Dialog(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: episodeResponse.episodes.length,
                itemBuilder: (context, index) {
                  final episode = episodeResponse.episodes[index];
                  return ListTile(
                    title: Text(episode.episodeTitle),
                    onTap: () => KazumiDialog.dismiss(
                        context: context, popWith: episode),
                  );
                },
              ),
            ),
          ),
        );
        videoPageController.cancelAutomaticDanmakuLoad();
        final hasDanmakus = await task.wait(
          playerController.danmaku.getDanDanmakuByEpisodeID(episode.episodeId),
        );
        playerController.danmaku.setDanmakuEnabled(hasDanmakus);
        KazumiDialog.showToast(message: hasDanmakus ? '弹幕切换成功' : '未找到弹幕内容');
      }, onError: (error, stackTrace) {
        KazumiDialog.showToast(message: '弹幕检索错误: $error');
      });

  void showVideoInfo() {
    showVideoDetailsSheet(context, playerController: playerController);
  }

  void showSyncPlayPanel() {
    showSyncPlaySheet(
      context,
      playerController: playerController,
      changeEpisode: widget.changeEpisode,
    );
  }

  bool _needsFullPanel(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    if (size.width < LayoutBreakpoint.compact['width']!) {
      return false;
    }
    if (videoPageController.isPip) {
      return false;
    }
    if (!isDesktop() &&
        size.height > LayoutBreakpoint.compact['height']! &&
        size.width < LayoutBreakpoint.medium['width']!) {
      return false;
    }
    return true;
  }

  @override
  void onWindowBlur() {
    _abortInteractiveSeek();
  }

  @override
  void onWindowRestore() {
    playerController.danmaku.canvasController.clear();
  }

  @override
  void initState() {
    super.initState();
    playerController = widget.playerController;
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
        onModeChanged: _handleAndroidPIPModeChanged,
      );
      unawaited(_syncAndroidAutoEnterPIPSetting());
      unawaited(_syncAndroidPIPPlayerPageState(true));
      unawaited(_updateAndroidPIPActions(force: true));
      _scheduleAndroidPIPSourceRectSync();
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
    showVideoController();
  }

  @override
  void dispose() {
    // The route-scoped PlayerController owns playback disposal.
    _fullscreenListener();
    _playerSizeListener();
    WidgetsBinding.instance.removeObserver(this);
    windowManager.removeListener(this);
    playerController.seeking.invalidateInteractiveSeek();
    playerTimer?.cancel();
    hideTimer?.cancel();
    mouseScrollerTimer?.cancel();
    _adjustmentHudHideTimer?.cancel();
    _interactiveSeekRecoveryTimer?.cancel();
    _panelFocusScopeNode.dispose();
    _panelVisibilityController.dispose();
    _screenshotFeedbackController.dispose();
    _disposePlayerMenu();
    if (Platform.isAndroid) {
      unawaited(_syncAndroidPIPPlayerPageState(false));
      PipUtils.disposePipHandler();
    }
    playerController.panel.reset();
    super.dispose();
  }

  Map<Type, Action<Intent>> get _gamepadActions => <Type, Action<Intent>>{
        GamepadActivateIntent: CallbackAction<GamepadActivateIntent>(
          onInvoke: (_) {
            _handleGamepadActivate();
            return null;
          },
        ),
        GamepadNavigateIntent: CallbackAction<GamepadNavigateIntent>(
          onInvoke: (intent) {
            _handleGamepadNavigate(intent.direction);
            return null;
          },
        ),
        GamepadBackIntent: CallbackAction<GamepadBackIntent>(
          onInvoke: (_) {
            _handleGamepadBack();
            return null;
          },
        ),
        GamepadSecondaryActionIntent:
            CallbackAction<GamepadSecondaryActionIntent>(
          onInvoke: (_) {
            handleDanmaku();
            return null;
          },
        ),
        GamepadContextActionIntent: CallbackAction<GamepadContextActionIntent>(
          onInvoke: (_) {
            if (playerController.panel.showVideoController) {
              hideVideoController();
            } else {
              showVideoController();
            }
            return null;
          },
        ),
        GamepadMenuIntent: CallbackAction<GamepadMenuIntent>(
          onInvoke: (_) {
            unawaited(playerController.playOrPause());
            showVideoController();
            return null;
          },
        ),
        GamepadViewIntent: CallbackAction<GamepadViewIntent>(
          onInvoke: (_) {
            widget.toggleMenu();
            return null;
          },
        ),
      };

  // A confirms the control the stick selected. It is never bound to a media
  // action directly (no fullscreen or play/pause shortcut); when nothing is
  // selected yet it reveals the controls so the next press can confirm.
  void _handleGamepadActivate() {
    if (_playerPanelHasFocus) {
      final focusContext = FocusManager.instance.primaryFocus?.context;
      if (focusContext != null) {
        Actions.maybeInvoke(focusContext, const ActivateIntent());
      }
      return;
    }
    _focusPlayerPanel();
  }

  void _handleGamepadNavigate(TraversalDirection direction) {
    if (playerController.panel.lockPanel) {
      return;
    }
    // Navigation only moves between on-screen buttons. When the controls are
    // hidden the stick reveals them and focuses the first button instead of
    // seeking or changing the volume.
    if (!playerController.panel.showVideoController || !_playerPanelHasFocus) {
      _focusPlayerPanel();
      return;
    }
    if (!invokeGamepadControlDirection(direction)) {
      final focused = FocusManager.instance.primaryFocus;
      focused?.focusInDirection(direction);
    }
  }

  void _focusPlayerPanel() {
    showVideoController(restartHideTimer: false);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Validate the remembered child instead of blindly calling nextFocus,
      // which can silently do nothing after a control was rebuilt away.
      if (!focusFirstGamepadControl(_panelFocusScopeNode)) {
        widget.keyboardFocus.requestFocus();
      }
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  void _handleGamepadBack() {
    if (_playerPanelHasFocus || playerController.panel.showVideoController) {
      widget.keyboardFocus.requestFocus();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          hideVideoController();
        }
      });
      return;
    }
    widget.onBackPressed(context);
  }

  @override
  Widget build(BuildContext context) {
    return Actions(
      actions: _gamepadActions,
      child: Focus(
        focusNode: widget.keyboardFocus,
        autofocus: true,
        child: Observer(
          builder: (context) {
            final enableSurfaceVerticalDrag =
                shouldEnablePlayerSurfaceVerticalDrag(isDesktop: isDesktop());
            return ClipRect(
              child: Container(
                color: Colors.black,
                child: MouseRegion(
                  cursor: (videoPageController.isFullscreen &&
                          !playerController.panel.showVideoController)
                      ? SystemMouseCursors.none
                      : SystemMouseCursors.basic,
                  onHover: (PointerEvent pointerEvent) {
                    // Android taps can emit hover events.
                    if (isDesktop()) {
                      if (pointerEvent.position.dy > 50 &&
                          pointerEvent.position.dy <
                              MediaQuery.of(context).size.height - 70) {
                        showVideoController();
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
                        final double volume = playerController.playback.volume -
                            scrollDelta.dy / 60;
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
                        PlayerKeyboardShortcuts(
                          focusScopeNode: widget.keyboardFocus,
                          actions: keyboardActions,
                          longPressActions: keyboardLongPressActions,
                          isBlocked: () =>
                              _openPlayerMenuCount > 0 || _playerPanelHasFocus,
                        ),
                        Center(
                          key: _videoSurfaceKey,
                          child: PlayerItemSurface(
                            playerController: playerController,
                          ),
                        ),
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
                            lastPlayerSpeed =
                                playerController.playback.playerSpeed;
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
                              // Speed scaling is applied after canvas creation.
                              duration: _danmakuDuration,
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
                        Positioned.fill(
                          left: 16,
                          top: 25,
                          right: 15,
                          bottom: 15,
                          child: !shouldEnablePlayerSurfaceSeek(
                            isDesktop: isDesktop(),
                            isLinux: Platform.isLinux,
                            panelLocked: playerController.panel.lockPanel,
                            videoDuration: playerController.playback.duration,
                          )
                              ? Container()
                              : GestureDetector(
                                  supportedDevices: playerSurfaceDragDevices(
                                    isLinux: Platform.isLinux,
                                  ),
                                  onHorizontalDragStart: (_) =>
                                      _beginSurfaceInteractiveSeek(),
                                  onHorizontalDragUpdate:
                                      (DragUpdateDetails details) {
                                    _updateSurfaceInteractiveSeek(
                                        context, details);
                                  },
                                  onHorizontalDragEnd: (_) =>
                                      _commitSurfaceInteractiveSeek(),
                                  onHorizontalDragCancel:
                                      _cancelSurfaceInteractiveSeek,
                                  onVerticalDragUpdate:
                                      enableSurfaceVerticalDrag
                                          ? (details) =>
                                              _updateSurfaceVerticalDrag(
                                                context,
                                                details,
                                              )
                                          : null,
                                  onVerticalDragEnd: enableSurfaceVerticalDrag
                                      ? (_) => _finishAdjustmentGesture()
                                      : null,
                                  onVerticalDragCancel:
                                      enableSurfaceVerticalDrag
                                          ? _finishAdjustmentGesture
                                          : null,
                                ),
                        ),
                        (Platform.isAndroid &&
                                (videoPageController.isPip ||
                                    _pipEnterRequested))
                            ? const SizedBox.shrink()
                            : PlayerPanelHoldFocus(
                                acquirePlayerPanelHold: acquirePlayerPanelHold,
                                onFocusChanged: (hasFocus) {
                                  _playerPanelHasFocus = hasFocus;
                                },
                                child: FocusScope(
                                  node: _panelFocusScopeNode,
                                  child: _needsFullPanel(context)
                                      ? PlayerItemPanel(
                                          playerController: playerController,
                                          videoPageController:
                                              videoPageController,
                                          onBackPressed: widget.onBackPressed,
                                          setPlaybackSpeed: setPlaybackSpeed,
                                          showDanmakuSwitch: showDanmakuSwitch,
                                          toggleMenu: widget.toggleMenu,
                                          handleFullscreen: handleFullscreen,
                                          enterAndroidPictureInPicture:
                                              enterAndroidPictureInPicture,
                                          handleProgressBarDragStart:
                                              handleProgressBarDragStart,
                                          handleProgressBarPointerDown:
                                              _handleProgressBarPointerDown,
                                          handleProgressBarPointerUp:
                                              _handleProgressBarPointerUp,
                                          handleProgressBarPointerCancel:
                                              _handleProgressBarPointerCancel,
                                          handleProgressBarDragUpdate:
                                              handleProgressBarDragUpdate,
                                          handleProgressBarSeek:
                                              handleProgressBarSeek,
                                          handleSuperResolutionChange:
                                              handleSuperResolutionChange,
                                          handlePreNextEpisode:
                                              handlePreNextEpisode,
                                          panelVisibilityController:
                                              _panelVisibilityController,
                                          keyboardFocus: widget.keyboardFocus,
                                          acquirePlayerPanelHold:
                                              acquirePlayerPanelHold,
                                          onMenuVisibilityChanged:
                                              _handlePlayerMenuVisibilityChanged,
                                          handleDanmaku: handleDanmaku,
                                          showVideoInfo: showVideoInfo,
                                          showSyncPlayPanel: showSyncPlayPanel,
                                          pauseForTimedShutdown:
                                              widget.pauseForTimedShutdown,
                                          disableAnimations:
                                              widget.disableAnimations,
                                          handleScreenShot: handleScreenshot,
                                          skipOP: skipOP,
                                        )
                                      : SmallestPlayerItemPanel(
                                          playerController: playerController,
                                          videoPageController:
                                              videoPageController,
                                          onBackPressed: widget.onBackPressed,
                                          setPlaybackSpeed: setPlaybackSpeed,
                                          showDanmakuSwitch: showDanmakuSwitch,
                                          handleFullscreen: handleFullscreen,
                                          enterAndroidPictureInPicture:
                                              enterAndroidPictureInPicture,
                                          handleProgressBarDragStart:
                                              handleProgressBarDragStart,
                                          handleProgressBarPointerDown:
                                              _handleProgressBarPointerDown,
                                          handleProgressBarPointerUp:
                                              _handleProgressBarPointerUp,
                                          handleProgressBarPointerCancel:
                                              _handleProgressBarPointerCancel,
                                          handleProgressBarDragUpdate:
                                              handleProgressBarDragUpdate,
                                          handleProgressBarSeek:
                                              handleProgressBarSeek,
                                          handleSuperResolutionChange:
                                              handleSuperResolutionChange,
                                          panelVisibilityController:
                                              _panelVisibilityController,
                                          acquirePlayerPanelHold:
                                              acquirePlayerPanelHold,
                                          onMenuVisibilityChanged:
                                              _handlePlayerMenuVisibilityChanged,
                                          handleDanmaku: handleDanmaku,
                                          showVideoInfo: showVideoInfo,
                                          showSyncPlayPanel: showSyncPlayPanel,
                                          pauseForTimedShutdown:
                                              widget.pauseForTimedShutdown,
                                          disableAnimations:
                                              widget.disableAnimations,
                                          skipOP: skipOP,
                                        ),
                                ),
                              ),
                      ]),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
