// ignore_for_file: library_private_types_in_public_api

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_volume_controller/flutter_volume_controller.dart';
import 'package:hive_ce/hive.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/pages/player/controller/player_debug_controller.dart';
import 'package:kazumi/shaders/shaders_controller.dart';
import 'package:kazumi/utils/constants.dart';
import 'package:kazumi/utils/logger.dart';
import 'package:kazumi/utils/proxy_utils.dart';
import 'package:kazumi/utils/storage.dart';
import 'package:kazumi/utils/utils.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:mobx/mobx.dart';

part 'player_playback_controller.g.dart';

class PlayerPlaybackController = _PlayerPlaybackController
    with _$PlayerPlaybackController;

abstract class _PlayerPlaybackController with Store {
  _PlayerPlaybackController({
    required this.setting,
    required this.shadersController,
    required this.debug,
    required this.videoUrl,
    required this.onExitSyncPlayRoom,
  });

  final Box setting;
  final ShadersController shadersController;
  final PlayerDebugController debug;
  final String Function() videoUrl;
  final Future<void> Function() onExitSyncPlayRoom;

  Player? mediaPlayer;
  VideoController? videoController;
  int lifecycleId = 0;

  bool hAenable = true;
  late String hardwareDecoder;
  bool androidEnableOpenSLES = true;
  bool lowMemoryMode = false;
  bool autoPlay = true;
  bool playerDebugMode = false;
  int buttonSkipTime = 80;
  int arrowKeySkipTime = 10;

  /// 视频超分
  /// 1. OFF
  /// 2. Anime4K Efficiency
  /// 3. Anime4K Quality
  @observable
  int superResolutionType = 1;

  // 视频音量
  @observable
  double volume = -1;

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

  int beginInit() => ++lifecycleId;

  void cancelActiveInit() {
    lifecycleId++;
  }

  bool isCurrentPlayer(int expectedLifecycleId, Player player) {
    return lifecycleId == expectedLifecycleId && identical(mediaPlayer, player);
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
      {int offset = 0, required int lifecycleId}) async {
    superResolutionType =
        setting.get(SettingBoxKey.defaultSuperResolutionType, defaultValue: 1);
    hAenable = setting.get(SettingBoxKey.hAenable, defaultValue: true);
    androidEnableOpenSLES =
        setting.get(SettingBoxKey.androidEnableOpenSLES, defaultValue: true);
    hardwareDecoder =
        setting.get(SettingBoxKey.hardwareDecoder, defaultValue: 'auto-safe');
    autoPlay = setting.get(SettingBoxKey.autoPlay, defaultValue: true);
    lowMemoryMode =
        setting.get(SettingBoxKey.lowMemoryMode, defaultValue: false);
    playerDebugMode =
        setting.get(SettingBoxKey.playerDebugMode, defaultValue: false);

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
      lifecycleId: lifecycleId,
      isCurrentPlayer: isCurrentPlayer,
      playerDebugMode: playerDebugMode,
    );
    if (!isCurrentPlayer(lifecycleId, player)) return null;

    var pp = player.platform as NativePlayer;
    // media-kit 默认启用硬盘作为双重缓存，这可以维持大缓存的前提下减轻内存压力
    // media-kit 内部硬盘缓存目录按照 Linux 配置，这导致该功能在其他平台上被损坏
    // 该设置可以在所有平台上正确启用双重缓存
    await pp.setProperty("demuxer-cache-dir", await Utils.getPlayerTempPath());
    if (!isCurrentPlayer(lifecycleId, player)) return null;
    await pp.setProperty("af", "scaletempo2=max-speed=8");
    if (!isCurrentPlayer(lifecycleId, player)) return null;
    if (Platform.isAndroid) {
      await pp.setProperty("volume-max", "100");
      if (!isCurrentPlayer(lifecycleId, player)) return null;
      if (androidEnableOpenSLES) {
        await pp.setProperty("ao", "opensles");
      } else {
        await pp.setProperty("ao", "audiotrack");
      }
      if (!isCurrentPlayer(lifecycleId, player)) return null;
    }

    // 设置 HTTP 代理
    final bool proxyEnable =
        setting.get(SettingBoxKey.proxyEnable, defaultValue: false);
    if (proxyEnable) {
      final String proxyUrl =
          setting.get(SettingBoxKey.proxyUrl, defaultValue: '');
      final formattedProxy = ProxyUtils.getFormattedProxyUrl(proxyUrl);
      if (formattedProxy != null) {
        await pp.setProperty("http-proxy", formattedProxy);
        if (!isCurrentPlayer(lifecycleId, player)) return null;
        KazumiLogger().i('Player: HTTP 代理设置成功 $formattedProxy');
      }
    }

    await player.setAudioTrack(
      AudioTrack.auto(),
    );
    if (!isCurrentPlayer(lifecycleId, player)) return null;

    String? videoRenderer;
    if (Platform.isAndroid) {
      final String androidVideoRenderer =
          setting.get(SettingBoxKey.androidVideoRenderer, defaultValue: 'auto');

      if (androidVideoRenderer == 'auto') {
        // Android 14 及以上使用基于 Vulkan 的 MPV GPU-NEXT 视频输出，着色器性能更好
        // GPU-NEXT 需要 Vulkan 1.2 支持
        // 避免 Android 14 及以下设备上部分机型 Vulkan 支持不佳导致的黑屏问题
        final int androidSdkVersion = await Utils.getAndroidSdkVersion();
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
      superResolutionType = 1;
    }

    videoController ??= VideoController(
      player,
      configuration: VideoControllerConfiguration(
        vo: videoRenderer,
        enableHardwareAcceleration: hAenable,
        hwdec: hAenable ? hardwareDecoder : 'no',
        androidAttachSurfaceAfterVideoParameters: false,
      ),
    );
    player.setPlaylistMode(PlaylistMode.none);
    if (!isCurrentPlayer(lifecycleId, player)) return null;

    // error handle
    bool showPlayerError =
        setting.get(SettingBoxKey.showPlayerError, defaultValue: true);
    player.stream.error.listen((event) {
      if (showPlayerError) {
        if (!isCurrentPlayer(lifecycleId, player)) {
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

    if (superResolutionType != 1) {
      await setShader(superResolutionType, player: player);
      if (!isCurrentPlayer(lifecycleId, player)) return null;
    }

    await player.open(
      Media(videoUrl(),
          start: Duration(seconds: offset), httpHeaders: httpHeaders),
      play: autoPlay,
    );
    if (!isCurrentPlayer(lifecycleId, player)) return null;

    return player;
  }

  Future<void> setShader(int type,
      {bool synchronized = true, Player? player}) async {
    final currentPlayer = player ?? mediaPlayer;
    if (currentPlayer == null) return;
    try {
      var pp = currentPlayer.platform as NativePlayer;
      await pp.waitForPlayerInitialization;
      await pp.waitForVideoControllerInitializationIfAttached;
      if (!identical(mediaPlayer, currentPlayer)) {
        return;
      }
      if (type == 2) {
        await pp.command([
          'change-list',
          'glsl-shaders',
          'set',
          Utils.buildShadersAbsolutePath(
              shadersController.shadersDirectory.path, mpvAnime4KShadersLite),
        ]);
        superResolutionType = 2;
        return;
      }
      if (type == 3) {
        await pp.command([
          'change-list',
          'glsl-shaders',
          'set',
          Utils.buildShadersAbsolutePath(
              shadersController.shadersDirectory.path, mpvAnime4KShaders),
        ]);
        superResolutionType = 3;
        return;
      }
      await pp.command(['change-list', 'glsl-shaders', 'clr', '']);
      superResolutionType = 1;
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
    value = value.clamp(0.0, 100.0);
    volume = value;
    try {
      if (Utils.isDesktop()) {
        await mediaPlayer!.setVolume(value);
      } else {
        await FlutterVolumeController.setVolume(value / 100);
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
    bool cancelActiveInit = true,
  }) async {
    // Bump the generation first so late init continuations cannot touch it.
    if (cancelActiveInit) {
      this.cancelActiveInit();
    }
    final player = mediaPlayer;
    mediaPlayer = null;
    videoController = null;
    final cancelDebugInfoFuture = debug.cancel();
    if (disposeSyncPlayController) {
      try {
        await onExitSyncPlayRoom();
      } catch (_) {}
    }
    try {
      await cancelDebugInfoFuture;
    } catch (_) {}
    try {
      await player?.dispose();
    } catch (_) {}
  }

  Future<void> stop() async {
    try {
      final player = mediaPlayer;
      await player?.stop();
      loading = true;
    } catch (_) {}
  }

  Future<Uint8List?> screenshot({String format = 'image/jpeg'}) async {
    return await mediaPlayer!.screenshot(format: format);
  }
}
