// ignore_for_file: library_private_types_in_public_api

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_volume_controller/flutter_volume_controller.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/pages/player/controller/player_debug_controller.dart';
import 'package:kazumi/pages/player/controller/player_super_resolution.dart';
import 'package:kazumi/services/shaders/shader_asset_service.dart';
import 'package:kazumi/utils/constants.dart';
import 'package:kazumi/services/logging/logger.dart';
import 'package:kazumi/services/network/proxy_utils.dart';
import 'package:kazumi/services/player/player_screenshot_service.dart';
import 'package:kazumi/services/storage/storage.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:mobx/mobx.dart';
import 'package:kazumi/utils/device.dart';
import 'package:kazumi/utils/media.dart';
import 'package:kazumi/services/platform/platform_environment_service.dart';

part 'player_playback_controller.g.dart';

class PlayerPlaybackController = _PlayerPlaybackController
    with _$PlayerPlaybackController;

abstract class _PlayerPlaybackController with Store {
  _PlayerPlaybackController({
    required this.shaderAssetService,
    required this.debug,
    required this.videoUrl,
    required this.onExitSyncPlayRoom,
  });

  final ShaderAssetService shaderAssetService;
  final PlayerDebugController debug;
  final String Function() videoUrl;
  final Future<void> Function() onExitSyncPlayRoom;
  final PlayerScreenshotService screenshotService =
      const PlayerScreenshotService();

  Player? mediaPlayer;
  VideoController? videoController;

  bool hAenable = true;
  late String hardwareDecoder;
  bool androidEnableOpenSLES = true;
  bool lowMemoryMode = false;
  bool autoPlay = true;
  bool playerDebugMode = false;
  int buttonSkipTime = 80;
  int arrowKeySkipTime = 10;

  /// 当前超分辨率模式
  @observable
  SuperResolutionMode superResolutionMode = SuperResolutionMode.off;

  @observable
  double volume = -1;

  /// 手势调节时的精确音量，避免 UI 节流导致累计误差
  double preciseVolume = -1;

  @observable
  bool loading = true;
  @observable
  bool playing = false;
  @observable
  bool isBuffering = true;
  @observable
  bool completed = false;
  @observable
  Duration currentPosition = Duration.zero;
  @observable
  Duration buffer = Duration.zero;
  @observable
  Duration duration = Duration.zero;
  @observable
  double playerSpeed = 1.0;

  bool isCurrentPlayer(Player player) {
    return identical(mediaPlayer, player);
  }

  Future<Player?> _discardIfNotCurrent(Player player) async {
    if (isCurrentPlayer(player)) {
      return player;
    }
    await _disposePlayer(player);
    return null;
  }

  Future<void> _disposePlayer(Player? player) async {
    if (player == null) return;
    try {
      await player.dispose();
    } catch (error, stackTrace) {
      KazumiLogger().e(
        'PlayerPlaybackController: failed to dispose media player',
        error: error,
        stackTrace: stackTrace,
      );
      try {
        await player.stop();
      } catch (_) {}
    }
  }

  Future<void> _cancelDebugInfo() async {
    try {
      await debug.cancel();
    } catch (_) {}
  }

  Future<void> _exitSyncPlayRoom() async {
    try {
      await onExitSyncPlayRoom();
    } catch (_) {}
  }

  @action
  void resetForInit() {
    playing = false;
    loading = true;
    isBuffering = true;
    currentPosition = Duration.zero;
    buffer = Duration.zero;
    duration = Duration.zero;
    completed = false;
  }

  bool get playerPlaying {
    try {
      return mediaPlayer?.state.playing ?? false;
    } catch (_) {
      return false;
    }
  }

  bool get playerBuffering {
    try {
      return mediaPlayer?.state.buffering ?? false;
    } catch (_) {
      return false;
    }
  }

  bool get playerCompleted {
    try {
      return mediaPlayer?.state.completed ?? false;
    } catch (_) {
      return false;
    }
  }

  double get playerVolume {
    try {
      return mediaPlayer?.state.volume ?? volume;
    } catch (_) {
      return volume;
    }
  }

  Duration get playerPosition {
    try {
      return mediaPlayer?.state.position ?? currentPosition;
    } catch (_) {
      return currentPosition;
    }
  }

  Duration get playerBuffer {
    try {
      return mediaPlayer?.state.buffer ?? buffer;
    } catch (_) {
      return buffer;
    }
  }

  Duration get playerDuration {
    try {
      return mediaPlayer?.state.duration ?? duration;
    } catch (_) {
      return duration;
    }
  }

  Future<Player?> createVideoController(
      Map<String, String> httpHeaders, bool adBlockerEnabled,
      {int offset = 0}) async {
    superResolutionMode = SuperResolutionMode.fromStorageValue(
      GStorage.getSetting(SettingsKeys.defaultSuperResolutionMode),
    );
    hAenable = GStorage.getSetting(SettingsKeys.hAenable);
    androidEnableOpenSLES =
        GStorage.getSetting(SettingsKeys.androidEnableOpenSLES);
    hardwareDecoder = GStorage.getSetting(SettingsKeys.hardwareDecoder);
    autoPlay = GStorage.getSetting(SettingsKeys.autoPlay);
    lowMemoryMode = GStorage.getSetting(SettingsKeys.lowMemoryMode);
    playerDebugMode = GStorage.getSetting(SettingsKeys.playerDebugMode);

    final Player player = Player(
      configuration: PlayerConfiguration(
        bufferSize: lowMemoryMode ? 15 * 1024 * 1024 : 1500 * 1024 * 1024,
        osc: false,
        logLevel: MPVLogLevel.values[debug.playerLogLevel],
        adBlocker: adBlockerEnabled,
      ),
    );
    mediaPlayer = player;

    debug.playerLog.clear();
    await debug.setup(
      player,
      isCurrentPlayer: isCurrentPlayer,
      playerDebugMode: playerDebugMode,
    );
    if (!isCurrentPlayer(player)) {
      return await _discardIfNotCurrent(player);
    }

    var pp = player.platform as NativePlayer;
    // media-kit 默认启用硬盘作为双重缓存，这可以维持大缓存的前提下减轻内存压力
    // media-kit 内部硬盘缓存目录按照 Linux 配置，这导致该功能在其他平台上被损坏
    // 该设置可以在所有平台上正确启用双重缓存
    await pp.setProperty("demuxer-cache-dir", await getPlayerTempPath());
    if (!isCurrentPlayer(player)) {
      return await _discardIfNotCurrent(player);
    }
    await pp.setProperty("af", "scaletempo2=max-speed=8");
    if (!isCurrentPlayer(player)) {
      return await _discardIfNotCurrent(player);
    }
    if (Platform.isAndroid) {
      await pp.setProperty("volume-max", "100");
      if (!isCurrentPlayer(player)) {
        return await _discardIfNotCurrent(player);
      }
      if (androidEnableOpenSLES) {
        await pp.setProperty("ao", "opensles");
      } else {
        await pp.setProperty("ao", "audiotrack");
      }
      if (!isCurrentPlayer(player)) {
        return await _discardIfNotCurrent(player);
      }
    }

    final bool proxyEnable = GStorage.getSetting(SettingsKeys.proxyEnable);
    if (proxyEnable) {
      final String proxyUrl = GStorage.getSetting(SettingsKeys.proxyUrl);
      final formattedProxy = ProxyUtils.getFormattedProxyUrl(proxyUrl);
      if (formattedProxy != null) {
        await pp.setProperty("http-proxy", formattedProxy);
        if (!isCurrentPlayer(player)) {
          return await _discardIfNotCurrent(player);
        }
        KazumiLogger().i('Player: HTTP 代理设置成功 $formattedProxy');
      }
    }

    await player.setAudioTrack(
      AudioTrack.auto(),
    );
    if (!isCurrentPlayer(player)) {
      return await _discardIfNotCurrent(player);
    }

    String? videoRenderer;
    if (Platform.isAndroid) {
      final String androidVideoRenderer =
          GStorage.getSetting(SettingsKeys.androidVideoRenderer);

      if (androidVideoRenderer == 'auto') {
        // Android 14 及以上使用基于 Vulkan 的 MPV GPU-NEXT 视频输出，着色器性能更好
        // GPU-NEXT 需要 Vulkan 1.2 支持
        // 避免 Android 14 及以下设备上部分机型 Vulkan 支持不佳导致的黑屏问题
        final int androidSdkVersion =
            await PlatformEnvironmentService.getAndroidSdkVersion();
        if (!isCurrentPlayer(player)) {
          return await _discardIfNotCurrent(player);
        }
        if (androidSdkVersion >= 34) {
          videoRenderer = 'gpu-next';
        } else {
          videoRenderer = 'gpu';
        }
      } else {
        videoRenderer = androidVideoRenderer;
      }
    }

    if (videoRenderer == 'mediacodec_embed') {
      hAenable = true;
      hardwareDecoder = 'mediacodec';
      superResolutionMode = SuperResolutionMode.off;
    }

    videoController ??= VideoController(
      player,
      configuration: VideoControllerConfiguration(
        vo: videoRenderer,
        enableHardwareAcceleration: hAenable,
        enableAndroidSurfaceProducer: false,
        hwdec: hAenable ? hardwareDecoder : 'no',
        androidAttachSurfaceAfterVideoParameters: false,
      ),
    );
    player.setPlaylistMode(PlaylistMode.none);
    if (!isCurrentPlayer(player)) {
      return await _discardIfNotCurrent(player);
    }

    bool showPlayerError = GStorage.getSetting(SettingsKeys.showPlayerError);
    player.stream.error.listen((event) {
      if (showPlayerError) {
        if (!isCurrentPlayer(player)) {
          return;
        }
        if (event.toString().contains('Failed to open') && playerBuffering) {
          KazumiDialog.showToast(
              message: '加载失败, 请尝试更换其他视频来源', showActionButton: true);
        } else {
          KazumiDialog.showToast(
              message: '播放器内部错误 ${event.toString()} ${videoUrl()}',
              duration: const Duration(seconds: 5),
              showActionButton: true);
        }
      }
      KazumiLogger().e('PlayerController: Player intent error ${videoUrl()}',
          error: event);
    });

    if (superResolutionMode != SuperResolutionMode.off) {
      await setShader(superResolutionMode, player: player);
      if (!isCurrentPlayer(player)) {
        return await _discardIfNotCurrent(player);
      }
    }

    await player.open(
      Media(videoUrl(),
          start: Duration(seconds: offset), httpHeaders: httpHeaders),
      play: autoPlay,
    );
    if (!isCurrentPlayer(player)) {
      return await _discardIfNotCurrent(player);
    }

    return player;
  }

  Future<void> setShader(SuperResolutionMode mode, {Player? player}) async {
    final currentPlayer = player ?? mediaPlayer;
    if (currentPlayer == null) return;
    try {
      var pp = currentPlayer.platform as NativePlayer;
      await pp.waitForPlayerInitialization;
      await pp.waitForVideoControllerInitializationIfAttached;
      if (!identical(mediaPlayer, currentPlayer)) {
        return;
      }
      switch (mode) {
        case SuperResolutionMode.efficiency:
          await pp.command([
            'change-list',
            'glsl-shaders',
            'set',
            buildShadersAbsolutePath(
              shaderAssetService.shadersDirectory.path,
              mpvAnime4KShadersLite,
            ),
          ]);
          break;
        case SuperResolutionMode.quality:
          await pp.command([
            'change-list',
            'glsl-shaders',
            'set',
            buildShadersAbsolutePath(
              shaderAssetService.shadersDirectory.path,
              mpvAnime4KShaders,
            ),
          ]);
          break;
        case SuperResolutionMode.off:
          await pp.command(['change-list', 'glsl-shaders', 'clr', '']);
          break;
      }
      superResolutionMode = mode;
    } catch (e) {
      KazumiLogger().w('PlayerController: failed to set shader', error: e);
    }
  }

  Future<void> setPlaybackSpeed(double playerSpeed) async {
    this.playerSpeed = playerSpeed;
    try {
      mediaPlayer!.setRate(playerSpeed);
    } catch (e) {
      KazumiLogger()
          .e('PlayerController: failed to set playback speed', error: e);
    }
  }

  Future<void> setVolume(double value) async {
    updateVolume(value);
    await syncVolumeToDevice(preciseVolume >= 0 ? preciseVolume : volume);
  }

  @action
  void updateVolume(double value) {
    value = value.clamp(0.0, 100.0);
    preciseVolume = value;
    if (volume.toInt() == value.toInt()) {
      return;
    }
    volume = value;
  }

  /// 外部来源（硬件键、系统面板等）变更音量时同步，并清除手势缓存
  @action
  void applyExternalVolume(double value) {
    value = value.clamp(0.0, 100.0);
    preciseVolume = -1;
    volume = value;
  }

  void invalidatePreciseVolume() {
    preciseVolume = -1;
  }

  Future<void> syncVolumeToDevice([double? value]) async {
    final vol = (value ?? volume).clamp(0.0, 100.0);
    try {
      if (isDesktop()) {
        await mediaPlayer!.setVolume(vol);
      } else {
        await FlutterVolumeController.setVolume(vol / 100);
      }
    } catch (_) {}
  }

  @action
  void syncPlaybackState() {
    final player = mediaPlayer;
    if (player == null) return;

    final PlayerState state;
    try {
      state = player.state;
    } catch (_) {
      return;
    }
    if (playing != state.playing) {
      playing = state.playing;
    }
    if (isBuffering != state.buffering) {
      isBuffering = state.buffering;
    }
    if (currentPosition != state.position) {
      currentPosition = state.position;
    }
    if (buffer != state.buffer) {
      buffer = state.buffer;
    }
    if (duration != state.duration) {
      duration = state.duration;
    }
    if (completed != state.completed) {
      completed = state.completed;
    }
  }

  Future<void> playOrPause({
    required Future<void> Function() pause,
    required Future<void> Function() play,
  }) async {
    if (playerPlaying) {
      await pause();
    } else {
      await play();
    }
  }

  Future<void> dispose({
    bool disposeSyncPlayController = true,
  }) async {
    final player = mediaPlayer;
    mediaPlayer = null;
    videoController = null;
    playing = false;
    loading = true;
    // Start media disposal before unrelated async cleanup. media_kit's
    // dispose operation stops playback before releasing native resources.
    final playerDisposeFuture = _disposePlayer(player);
    final cleanupFutures = <Future<void>>[
      playerDisposeFuture,
      _cancelDebugInfo(),
    ];
    if (disposeSyncPlayController) {
      cleanupFutures.add(_exitSyncPlayRoom());
    }
    await Future.wait(cleanupFutures);
  }

  Future<void> stop() async {
    final player = mediaPlayer;
    mediaPlayer = null;
    videoController = null;
    playing = false;
    loading = true;
    await Future.wait([
      _disposePlayer(player),
      _cancelDebugInfo(),
    ]);
  }

  Future<Uint8List?> screenshot({String format = 'image/jpeg'}) async {
    return await mediaPlayer!.screenshot(format: format);
  }

  Future<Uint8List?> screenshotPng() async {
    final player = mediaPlayer;
    if (player == null) {
      return null;
    }
    return await screenshotService.capturePng(player);
  }
}
