// ignore_for_file: library_private_types_in_public_api

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_volume_controller/flutter_volume_controller.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/pages/player/controller/player_debug_controller.dart';
import 'package:kazumi/pages/player/controller/player_super_resolution.dart';
import 'package:kazumi/services/shaders/shader_asset_service.dart';
import 'package:kazumi/services/enhancement/upscaling.dart';
import 'package:kazumi/services/enhancement/frame_interpolation.dart';
import 'package:kazumi/services/enhancement/video_model_cache.dart';
import 'package:kazumi/services/enhancement/video_enhancement_advice.dart';
import 'package:kazumi/services/enhancement/video_gpu.dart';
import 'package:kazumi/services/logging/logger.dart';
import 'package:kazumi/services/network/proxy_utils.dart';
import 'package:kazumi/services/network/system_proxy_service.dart';
import 'package:kazumi/services/player/playback_cache_policy.dart';
import 'package:kazumi/services/player/player_error_mapper.dart';
import 'package:kazumi/services/storage/storage.dart';
import 'package:kazumi/services/video_source/video_source_format.dart';
import 'package:kazumi/utils/async_serial_queue.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:mobx/mobx.dart';
import 'package:kazumi/utils/device.dart';
import 'package:kazumi/utils/media.dart';
import 'package:kazumi/utils/constants.dart' show nearEndWatchedThreshold;
import 'package:kazumi/services/platform/platform_environment_service.dart';

part 'player_playback_controller.g.dart';

class PlayerPlaybackController = _PlayerPlaybackController
    with _$PlayerPlaybackController;

final class _OwnedPlayer {
  _OwnedPlayer(this.player);

  final Player player;
  Future<void>? _disposeFuture;

  Future<void> dispose() {
    return _disposeFuture ??= _dispose();
  }

  Future<void> _dispose() async {
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
}

abstract class _PlayerPlaybackController with Store {
  _PlayerPlaybackController({
    required this.shaderAssetService,
    required this.debug,
    required this.videoUrl,
    required this.isLocalPlayback,
  });

  final ShaderAssetService shaderAssetService;
  final PlayerDebugController debug;
  final String Function() videoUrl;
  final bool Function() isLocalPlayback;
  late final PlaybackCachePolicy cachePolicy = PlaybackCachePolicy(
    isLocalPlayback: isLocalPlayback,
    currentPlayer: () => mediaPlayer,
  );

  _OwnedPlayer? _ownedPlayer;
  Player? get mediaPlayer => _ownedPlayer?.player;
  VideoController? videoController;

  final _enhancementWrites = AsyncSerialQueue();
  final _interpolationMode = Observable(InterpolationMode.off);
  final _interpolationBusy = Observable(false);
  InterpolationMode get interpolationMode => _interpolationMode.value;
  bool get interpolationBusy => _interpolationBusy.value;
  int _interpolationGeneration = 0;
  String? _interpolationDevice;
  InterpolationOptions _interpolationOptions = const InterpolationOptions();
  Upscaler _selectedUpscaler = Upscaler.anime4k;
  final _appliedUpscaler = Observable<Upscaler?>(null);
  Upscaler? get appliedUpscaler => _appliedUpscaler.value;
  UpscalingOutputLimit _outputLimit = UpscalingOutputLimit.automatic;
  String? _videoRenderer;
  final _windowsSoftwareRenderer = Observable(false);

  bool get _canRenderShaders => _videoRenderer != 'mediacodec_embed' &&
      (!Platform.isWindows || (hAenable && !_windowsSoftwareRenderer.value));
  bool get supportsComputeShaders => _canRenderShaders &&
      (Platform.isWindows || (Platform.isAndroid && _videoRenderer == 'gpu-next'));

  int get upscalingOutputEdge => _outputLimit.pixels ?? (Platform.isAndroid ? 2560 : 3840);

  final AsyncSerialQueue _prefetchWrites = AsyncSerialQueue();
  bool _prefetchSuspendWanted = false;

  bool hAenable = true;
  late String hardwareDecoder;
  bool androidEnableOpenSLES = true;
  bool autoPlay = true;
  bool playerDebugMode = false;
  int buttonSkipTime = 80;
  int arrowKeySkipTime = 10;

  /// 历史记录传入的 offset
  int startOffset = 0;

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

  Future<Player?> _discardIfNotCurrent(_OwnedPlayer candidate) async {
    if (identical(_ownedPlayer, candidate)) {
      return candidate.player;
    }
    await candidate.dispose();
    return null;
  }

  Future<void> _cancelDebugInfo() async {
    try {
      await debug.cancel();
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
    startOffset = 0;
  }

  /// 本次会话是否从距结尾 [nearEndWatchedThreshold] 以内的位置起播。
  /// 这样的"播放完成"并非真正看完，应从头重播而非切下一集
  bool get resumedNearEnd {
    if (startOffset <= 0 || duration <= Duration.zero) {
      return false;
    }
    return Duration(seconds: startOffset) >= duration - nearEndWatchedThreshold;
  }

  /// 从头重播当前视频。[startOffset] 在重播落地后才归零，
  /// 避免自动连播在此期间抢先触发
  Future<void> restartFromBeginning() async {
    final player = mediaPlayer;
    if (player == null) {
      return;
    }
    try {
      await player.seek(Duration.zero);
      if (!isCurrentPlayer(player)) {
        return;
      }
      await player.play();
      startOffset = 0;
    } catch (e) {
      KazumiLogger()
          .w('PlayerController: failed to restart from beginning', error: e);
    }
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

  /// Android blocks network access for backgrounded apps; a prefetching
  /// demuxer then burns through ffmpeg's reconnect/segment retries and marks
  /// the stream EOF, leaving playback permanently stuck once foregrounded.
  /// Suspending zeroes the readahead window so no new requests are issued
  /// while buffered data stays available; restore values are mpv defaults,
  /// which media_kit leaves untouched. Writes are serialized and apply the
  /// latest requested state, so rapid lifecycle flips cannot reorder.
  Future<void> setPrefetchSuspended(bool suspended) async {
    if (!Platform.isAndroid) {
      return;
    }
    _prefetchSuspendWanted = suspended;
    await _prefetchWrites.run(() async {
      final wanted = _prefetchSuspendWanted;
      final player = mediaPlayer;
      if (player == null) {
        return;
      }
      try {
        final pp = player.platform as NativePlayer;
        await pp.setProperty('cache-secs', wanted ? '0' : '36000');
        if (!isCurrentPlayer(player)) {
          return;
        }
        await pp.setProperty('demuxer-readahead-secs', wanted ? '0' : '1');
      } catch (e) {
        KazumiLogger().w(
          'PlayerController: failed to ${wanted ? 'suspend' : 'resume'} demuxer prefetch',
          error: e,
        );
      }
    });
  }

  Future<Player?> createVideoController(
    Map<String, String> httpHeaders,
    bool adBlockerEnabled, {
    required bool Function() canInstall,
    int offset = 0,
    VideoSourceFormat videoSourceFormat = VideoSourceFormat.auto,
  }) async {
    startOffset = offset;
    superResolutionMode = SuperResolutionMode.fromStorageValue(
      GStorage.getSetting(SettingsKeys.defaultSuperResolutionMode),
    );
    _selectedUpscaler = Upscaler.fromName(GStorage.getSetting(SettingsKeys.defaultSuperResolutionModel));
    _appliedUpscaler.value = null;
    _outputLimit = GStorage.getSetting(SettingsKeys.videoEnhancementExpertMode)
        ? UpscalingOutputLimit.decode(GStorage.getSetting(SettingsKeys.superResolutionOptions))
        : UpscalingOutputLimit.automatic;
    ++_interpolationGeneration;
    _interpolationDevice = null;
    _interpolationMode.value = InterpolationMode.off;
    _interpolationBusy.value = false;
    _interpolationOptions = GStorage.getSetting(SettingsKeys.videoEnhancementExpertMode)
        ? InterpolationOptions.decode(GStorage.getSetting(SettingsKeys.interpolationOptions))
        : const InterpolationOptions();
    hAenable = GStorage.getSetting(SettingsKeys.hAenable);
    androidEnableOpenSLES =
        GStorage.getSetting(SettingsKeys.androidEnableOpenSLES);
    hardwareDecoder = GStorage.getSetting(SettingsKeys.hardwareDecoder);
    autoPlay = GStorage.getSetting(SettingsKeys.autoPlay);
    playerDebugMode = GStorage.getSetting(SettingsKeys.playerDebugMode);

    if (!canInstall()) {
      return null;
    }
    final candidate = _OwnedPlayer(
      Player(
        configuration: PlayerConfiguration(
          bufferSize: cachePolicy.bufferSize,
          osc: false,
          logLevel: MPVLogLevel.values[debug.playerLogLevel],
          adBlocker: adBlockerEnabled,
        ),
      ),
    );
    final player = candidate.player;
    if (!canInstall()) {
      await candidate.dispose();
      return null;
    }
    _ownedPlayer = candidate;
    cachePolicy.startWatching();

    try {
      debug.playerLog.clear();
      await debug.setup(
        player,
        isCurrentPlayer: isCurrentPlayer,
        playerDebugMode: playerDebugMode,
      );
      if (!isCurrentPlayer(player)) {
        return await _discardIfNotCurrent(candidate);
      }

      var pp = player.platform as NativePlayer;
      // media-kit 默认启用硬盘作为双重缓存，这可以维持大缓存的前提下减轻内存压力
      // media-kit 内部硬盘缓存目录按照 Linux 配置，这导致该功能在其他平台上被损坏
      // 该设置可以在所有平台上正确启用双重缓存
      await pp.setProperty("demuxer-cache-dir", await getPlayerTempPath());
      if (!isCurrentPlayer(player)) {
        return await _discardIfNotCurrent(candidate);
      }
      await cachePolicy.apply();
      if (!isCurrentPlayer(player)) {
        return await _discardIfNotCurrent(candidate);
      }
      await pp.setProperty("af", "scaletempo2=max-speed=8");
      if (!isCurrentPlayer(player)) {
        return await _discardIfNotCurrent(candidate);
      }
      if (Platform.isAndroid) {
        await pp.setProperty("volume-max", "100");
        if (!isCurrentPlayer(player)) {
          return await _discardIfNotCurrent(candidate);
        }
        if (androidEnableOpenSLES) {
          await pp.setProperty("ao", "opensles");
        } else {
          await pp.setProperty("ao", "audiotrack");
        }
        if (!isCurrentPlayer(player)) {
          return await _discardIfNotCurrent(candidate);
        }
      }

      final bool proxyEnable = GStorage.getSetting(SettingsKeys.proxyEnable);
      if (proxyEnable) {
        final String proxyUrl = GStorage.getSetting(SettingsKeys.proxyUrl);
        final formattedProxy = ProxyUtils.getFormattedProxyUrl(proxyUrl);
        if (formattedProxy != null) {
          await pp.setProperty("http-proxy", formattedProxy);
          if (!isCurrentPlayer(player)) {
            return await _discardIfNotCurrent(candidate);
          }
          KazumiLogger().i('Player: HTTP 代理设置成功 $formattedProxy');
        }
      } else if (SystemProxyService.isActive) {
        final proxy = SystemProxyService.proxyFor('https');
        if (proxy != null) {
          await pp.setProperty("http-proxy", 'http://${proxy.$1}:${proxy.$2}');
          if (!isCurrentPlayer(player)) {
            return await _discardIfNotCurrent(candidate);
          }
          KazumiLogger().i('Player: 跟随系统代理 http://${proxy.$1}:${proxy.$2}');
        }
      }

      await player.setAudioTrack(
        AudioTrack.auto(),
      );
      if (!isCurrentPlayer(player)) {
        return await _discardIfNotCurrent(candidate);
      }

      String? videoRenderer;
      String? androidRenderGpu;
      String? windowsGpu;
      _windowsSoftwareRenderer.value = false;
      if (Platform.isWindows) {
        final requested = VideoGpu.selection;
        windowsGpu = requested.isNotEmpty ? requested : null;
        _interpolationDevice = windowsGpu;
        final handle = await player.handle;
        if (!isCurrentPlayer(player)) {
          return await _discardIfNotCurrent(candidate);
        }
        final warnings = VideoController.windowsRenderWarnings.listen((warning) {
          if (!isCurrentPlayer(player) || warning.handle != handle) return;
          if (warning.code == 'adapterFallback') _interpolationDevice = null;
          if (warning.code == 'softwareFallback') {
            _windowsSoftwareRenderer.value = true;
            unawaited(setShader(SuperResolutionMode.off, player: player));
          }
          final message = switch (warning.code) {
            'adapterFallback' => '所选 GPU 不可用，已使用自动选择',
            'softwareFallback' => 'GPU 渲染初始化失败，已切换到软件渲染',
            'renderFailed' => 'GPU 渲染或跨卡传输失败，请在设置中将视频处理 GPU 改为自动',
            'resizeFailed' => '无法分配超分输出纹理，继续使用原有输出尺寸',
            _ => null,
          };
          if (message != null) KazumiDialog.showToast(message: message);
        });
        pp.release.add(warnings.cancel);
      } else if (Platform.isAndroid) {
        final rendererSetting = GStorage.getSetting(SettingsKeys.androidVideoRenderer);
        final requested = VideoGpu.selection;
        final sdkVersion = rendererSetting == 'auto'
            ? await PlatformEnvironmentService.getAndroidSdkVersion()
            : 0;
        List<VideoAdapter> available = const [];
        final probeForAuto = rendererSetting == 'auto' && sdkVersion >= 34;
        final probeSelection = requested.isNotEmpty && rendererSetting != 'mediacodec_embed';
        if (probeForAuto || probeSelection) {
          try {
            available = await VideoGpu.enumerate();
          } catch (error) {
            KazumiLogger().w('GPU enumeration failed', error: error);
          }
        }
        if (!isCurrentPlayer(player)) {
          return await _discardIfNotCurrent(candidate);
        }
        final gpuPlan = androidGpuPlan(
          rendererSetting: rendererSetting,
          sdkVersion: sdkVersion,
          selectedDevice: requested,
          available: available,
        );
        videoRenderer = gpuPlan.renderer;
        androidRenderGpu = gpuPlan.renderDevice;
        _interpolationDevice = gpuPlan.interpolationDevice;
        if (gpuPlan.unavailable) {
          KazumiDialog.showToast(message: '未找到所选 Vulkan 设备，已使用自动选择');
        }
      }

      _videoRenderer = videoRenderer;
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
          windowsRenderAdapterId: windowsGpu,
          androidVulkanDeviceUuid: androidRenderGpu,
        ),
      );
      if (androidRenderGpu != null) {
        // setProperty can succeed in Dart even when mpv rejects an option.
        // The controller restores automatic backend selection in that case.
        final applied = await pp.getProperty('options/vulkan-device');
        if (!isCurrentPlayer(player)) {
          return await _discardIfNotCurrent(candidate);
        }
        if (applied != androidRenderGpu) {
          androidRenderGpu = null;
          _interpolationDevice = null;
          KazumiDialog.showToast(message: '播放器无法使用所选 Vulkan GPU，已使用自动选择');
        }
      }
      player.setPlaylistMode(PlaylistMode.none);
      if (!isCurrentPlayer(player)) {
        return await _discardIfNotCurrent(candidate);
      }

      bool showPlayerError = GStorage.getSetting(SettingsKeys.showPlayerError);
      player.stream.error.listen((event) {
        if (isCurrentPlayer(player)) {
          if (androidRenderGpu != null &&
              event.contains('Error opening/initializing the selected video_out')) {
            KazumiDialog.showToast(message: '无法在所选设备启动 Vulkan，请将 Vulkan GPU 改为自动');
          }
          final actionableMessage = PlayerErrorMapper.toActionableMessage(
            event,
            isBuffering: playerBuffering,
          );
          if (actionableMessage != null) {
            KazumiDialog.showToast(
                message: actionableMessage, showActionButton: true);
          } else if (showPlayerError) {
            KazumiDialog.showToast(
                message: '播放器内部错误 ${event.toString()} ${videoUrl()}',
                duration: const Duration(seconds: 5),
                showActionButton: true);
          }
        }
        KazumiLogger().e('PlayerController: Player intent error ${videoUrl()}',
            error: event);
      });

      if (FrameInterpolation.available) {
        final nativeWarnings = player.stream.log.listen((event) {
          if (!isCurrentPlayer(player)) return;
          if (interpolationMode == InterpolationMode.off) return;
          if (event.text.contains('KAZUMI_DRBA_OVER_BUDGET')) {
            KazumiDialog.showToast(message: '插帧耗时超过播放预算，已保留原始帧率。切换档位或跳转进度可重试');
          } else if (event.text.contains('KAZUMI_DRBA_INFERENCE_FAILED') || event.text.contains('KAZUMI_DRBA_INIT_FAILED')) {
            KazumiDialog.showToast(message: '插帧推理失败，已恢复原始帧率');
            unawaited(setInterpolation(InterpolationMode.off));
          }
        });
        pp.release.add(nativeWarnings.cancel);
      }

      if (superResolutionMode != SuperResolutionMode.off) {
        await setShader(superResolutionMode, player: player);
        if (!isCurrentPlayer(player)) {
          return await _discardIfNotCurrent(candidate);
        }
      }

      if (videoSourceFormat == VideoSourceFormat.hls) {
        await pp.setProperty('demuxer-lavf-format', 'hls');
        if (!isCurrentPlayer(player)) {
          return await _discardIfNotCurrent(candidate);
        }
      }

      await player.open(
        Media(videoUrl(),
            start: Duration(seconds: offset), httpHeaders: httpHeaders),
        play: autoPlay,
      );
      if (!isCurrentPlayer(player)) {
        return await _discardIfNotCurrent(candidate);
      }

      if (cachePolicy.networkAutomatic) {
        KazumiDialog.showToast(message: '移动数据下已自动开启低内存模式，可在播放设置中改为始终关闭');
      }

      if (FrameInterpolation.available && _videoRenderer != 'mediacodec_embed') {
        final defaultMode = InterpolationMode.fromKey(
            GStorage.getSetting(SettingsKeys.interpolationMode));
        if (defaultMode != InterpolationMode.off) {
          unawaited(setInterpolation(defaultMode));
        }
      }
      return player;
    } catch (error, stackTrace) {
      if (identical(_ownedPlayer, candidate)) {
        cachePolicy.stopWatching();
        _ownedPlayer = null;
        videoController = null;
      }
      await candidate.dispose();
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  Future<void> setShader(SuperResolutionMode mode, {Player? player, Upscaler? upscaler}) async {
    final current = player ?? mediaPlayer;
    if (current == null) return;
    await _enhancementWrites.run(() async {
      if (!isCurrentPlayer(current)) return;
      final pp = current.platform as NativePlayer;
      try {
        await pp.waitForPlayerInitialization;
        await pp.waitForVideoControllerInitializationIfAttached;
        if (!isCurrentPlayer(current)) return;
        final requested = upscaler ?? _selectedUpscaler;
        final applied = requested == Upscaler.cunny && !supportsComputeShaders ? Upscaler.anime4k : requested;
        final tier = _canRenderShaders ? applied.supportedTier(mode) : SuperResolutionMode.off;
        final shaders = applied.shadersFor(tier);
        if (shaders.isEmpty) {
          await pp.command(['change-list', 'glsl-shaders', 'clr', '']);
        } else {
          await shaderAssetService.requireShaders(shaders);
          if (!isCurrentPlayer(current)) return;
          await pp.command(['change-list', 'glsl-shaders', 'set',
            buildShadersAbsolutePath(shaderAssetService.shadersDirectory.path, shaders)]);
        }
        if (!isCurrentPlayer(current)) return;
        _selectedUpscaler = requested;
        _appliedUpscaler.value = shaders.isEmpty ? null : applied;
        superResolutionMode = tier;
        if (tier != SuperResolutionMode.off && applied != requested) {
          KazumiDialog.showToast(message: '当前渲染器不支持 CuNNy，已使用 Anime4K');
        }
      } catch (error) {
        if (!isCurrentPlayer(current)) return;
        KazumiLogger().w('PlayerController: failed to apply upscaling', error: error);
        try {
          await pp.command(['change-list', 'glsl-shaders', 'clr', '']);
        } catch (clearError) {
          KazumiLogger().w('PlayerController: failed to clear shaders', error: clearError);
        }
        if (isCurrentPlayer(current)) {
          _appliedUpscaler.value = null;
          superResolutionMode = SuperResolutionMode.off;
          KazumiDialog.showToast(message: '未能应用超分辨率');
        }
      }
    });
  }

  Future<void> _syncDecoder(NativePlayer pp, {bool attaching = false}) async {
    final baseDecoder = hAenable ? hardwareDecoder : 'no';
    final needsCopyBack = attaching || await FrameInterpolation.isAttached(pp);
    final decoder = needsCopyBack ? FrameInterpolation.copyBackDecoder(baseDecoder) : baseDecoder;
    if (await pp.getProperty('options/hwdec') != decoder) {
      await pp.command(['set', 'hwdec', decoder]);
    }
  }

  Future<void> setInterpolation(InterpolationMode mode) async {
    final player = mediaPlayer;
    if (player == null || !FrameInterpolation.available) return;
    if (_videoRenderer == 'mediacodec_embed') {
      if (mode != InterpolationMode.off) {
        KazumiDialog.showToast(message: '请使用 gpu 或 gpu-next 渲染器来开启插帧');
      }
      return;
    }
    final generation = ++_interpolationGeneration;
    bool current() =>
        isCurrentPlayer(player) && generation == _interpolationGeneration;
    _interpolationBusy.value = true;
    try {
      final advice = mode == InterpolationMode.off
          ? null
          : await VideoEnhancementAdvice.detect();
      if (!current()) return;
      final plan = _interpolationOptions.plan(
        mode,
        mobile: Platform.isAndroid,
        highMemoryGpu: advice?.ampleDedicatedMemory ?? false,
      );
      final startingEdge = plan == null
          ? null
          : advice!.interpolation(mode, cpu: plan.cpu).maximumEdge;
      // Verify bundled files outside the native command queue.
      final directory = plan == null
          ? null
          : await VideoModelCache.instance.require(BundledVideoModel.drba);
      if (!current()) return;
      await _enhancementWrites.run(() async {
        if (!current()) return;
        final pp = player.platform as NativePlayer;
        try {
          if (await FrameInterpolation.isAttached(pp)) {
            if (!current()) return;
            await pp.command(['vf', 'remove', '@${FrameInterpolation.label}']);
            if (!isCurrentPlayer(player)) return;
            _interpolationMode.value = InterpolationMode.off;
          }
          if (!current() || plan == null) return;
          await _syncDecoder(pp, attaching: true);
          if (!current()) return;
          // Estimate motion on source frames, before spatial upscaling.
          await pp.command([
            'vf',
            'pre',
            plan.filter(
              directory!.path,
              device: _interpolationDevice,
              startingEdge: startingEdge,
            ),
          ]);
          if (!await FrameInterpolation.isAttached(pp)) {
            throw StateError('DRBA did not attach');
          }
          if (isCurrentPlayer(player)) _interpolationMode.value = mode;
        } finally {
          if (isCurrentPlayer(player)) await _syncDecoder(pp);
        }
      });
    } catch (error) {
      if (!current()) return;
      KazumiLogger().w(
        'PlayerController: failed to apply frame interpolation',
        error: error,
      );
      KazumiDialog.showToast(message: '插帧未启用，请检查视频处理 GPU，或在专业参数中选择 CPU 推理');
    } finally {
      if (current()) _interpolationBusy.value = false;
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

  Future<void> stop() async {
    ++_interpolationGeneration;
    cachePolicy.stopWatching();
    final ownedPlayer = _ownedPlayer;
    _ownedPlayer = null;
    videoController = null;
    playing = false;
    loading = true;
    // media_kit stops playback as part of disposal before releasing native
    // resources. Debug subscriptions can be cancelled concurrently.
    await Future.wait([
      ownedPlayer?.dispose() ?? Future<void>.value(),
      _cancelDebugInfo(),
    ]);
  }

  Future<Uint8List?> screenshotPng() async {
    final player = mediaPlayer;
    if (player == null) {
      return null;
    }
    // Encode the captured frame natively; PlayerState dimensions may be stale.
    return player.safeScreenshot(format: 'image/png');
  }
}
