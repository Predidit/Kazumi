import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_volume_controller/flutter_volume_controller.dart';
import 'package:media_kit/media_kit.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/services/player/external_playback_launcher.dart';
import 'package:kazumi/pages/player/controller/player_danmaku_controller.dart';
import 'package:kazumi/pages/player/controller/player_debug_controller.dart';
import 'package:kazumi/pages/player/controller/player_models.dart';
import 'package:kazumi/pages/player/controller/player_aspect_ratio.dart';
import 'package:kazumi/pages/player/controller/player_panel_controller.dart';
import 'package:kazumi/pages/player/controller/player_playback_controller.dart';
import 'package:kazumi/pages/player/controller/player_super_resolution.dart';
import 'package:kazumi/pages/player/controller/player_syncplay_controller.dart';
import 'package:kazumi/services/storage/storage.dart';
import 'package:kazumi/services/logging/logger.dart';
import 'package:kazumi/services/shaders/shader_asset_service.dart';
import 'package:kazumi/utils/device.dart';

export 'package:kazumi/pages/player/controller/player_models.dart';

class PlayerController {
  final ShaderAssetService shaderAssetService =
      Modular.get<ShaderAssetService>();
  final PlayerPanelController panel = PlayerPanelController();
  final PlayerDebugController debug = PlayerDebugController();

  late final PlayerDanmakuController danmaku = PlayerDanmakuController(
    isLocalPlayback: () => isLocalPlayback,
  );
  late final PlayerPlaybackController playback = PlayerPlaybackController(
    shaderAssetService: shaderAssetService,
    debug: debug,
    videoUrl: () => videoUrl,
    onExitSyncPlayRoom: () => syncplay.exitRoom(),
  );
  late final PlayerSyncPlayController syncplay = PlayerSyncPlayController(
    bangumiId: () => bangumiId,
    currentEpisode: () => currentEpisode,
    currentEpisodeStableId: () => currentEpisodeStableId,
    currentRoad: () => currentRoad,
    playing: () => playback.playing,
    currentPosition: () => playback.currentPosition,
    playerPosition: () => playback.playerPosition,
    duration: () => playback.duration,
    pause: pause,
    play: play,
    seek: seek,
  );
  late final ExternalPlaybackLauncher externalPlayback =
      ExternalPlaybackLauncher(
    videoUrl: () => videoUrl,
    referer: () => referer,
  );

  late int bangumiId;
  late int currentEpisode;
  late int currentDanmakuEpisodeNumber;
  late String currentEpisodeStableId;
  late int currentRoad;
  late String referer;
  String? coverUrl;
  String videoUrl = '';
  bool isLocalPlayback = false;
  Timer? hideVolumeUITimer;
  Timer? _volumeGestureSyncTimer;
  double? _pendingGestureVolume;

  bool muted = false;
  double _preMuteVolume = 100;

  Future<void> toggleMute() async {
    if (!muted && playback.volume > 0) {
      _preMuteVolume = playback.volume;
      muted = true;
      _persistMuteState();
      await setVolume(0);
    } else {
      muted = false;
      _persistMuteState();
      await setVolume(_preMuteVolume > 0 ? _preMuteVolume : 100);
    }
  }

  void _persistMuteState() {
    if (!isDesktop()) {
      return;
    }
    unawaited(GStorage.putSetting<bool>(SettingsKeys.playerMuted, muted));
  }

  /// 在音量被主动调高（手势 / 按键 / 滚轮）时退出静音状态。
  void _clearMuteIfNeeded(double value) {
    if (muted && value > 0) {
      muted = false;
      _persistMuteState();
    }
  }

  void setVolumeDuringGesture(double value) {
    _pendingGestureVolume = value.clamp(0.0, 100.0);
    playback.updateVolume(_pendingGestureVolume!);
    _volumeGestureSyncTimer?.cancel();
    _volumeGestureSyncTimer = Timer(const Duration(milliseconds: 80), () {
      final vol = _pendingGestureVolume;
      if (vol == null) {
        return;
      }
      unawaited(playback.syncVolumeToDevice(vol));
    });
  }

  Future<void> finishVolumeGesture() async {
    _volumeGestureSyncTimer?.cancel();
    _volumeGestureSyncTimer = null;
    final vol = _pendingGestureVolume;
    _pendingGestureVolume = null;
    if (vol != null) {
      playback.volume = vol;
    }
    playback.invalidatePreciseVolume();
    await playback.syncVolumeToDevice(vol);
    final resolved = vol ?? playback.volume;
    _clearMuteIfNeeded(resolved);
    _persistDesktopVolume(resolved);
  }

  void _persistDesktopVolume(double value) {
    if (!isDesktop()) {
      return;
    }
    if (muted) {
      return;
    }
    final clamped = value.clamp(0.0, 100.0);
    final stored = GStorage.getSetting(SettingsKeys.defaultVolume);
    if (stored.round() == clamped.round()) {
      return;
    }
    unawaited(GStorage.putSetting<double>(SettingsKeys.defaultVolume, clamped));
  }

  Future<bool> init(PlaybackInitParams params) async {
    videoUrl = params.videoUrl;
    isLocalPlayback = params.isLocalPlayback;
    bangumiId = params.bangumiId;
    currentEpisode = params.episode;
    currentDanmakuEpisodeNumber = params.danmakuEpisodeNumber;
    currentEpisodeStableId = params.stableId;
    currentRoad = params.currentRoad;
    referer = params.referer;

    KazumiLogger().i(
        'PlayerController: ${params.isLocalPlayback ? "local" : "online"} playback, url: ${params.videoUrl}');

    playback.resetForInit();
    debug.playerLogLevel = GStorage.getSetting(SettingsKeys.playerLogLevel);
    playback.playerSpeed = GStorage.getSetting(SettingsKeys.defaultPlaySpeed);
    panel.aspectRatioMode = PlayerAspectRatio.fromStorageValue(
      GStorage.getSetting(SettingsKeys.defaultAspectRatioType),
    );

    playback.buttonSkipTime = GStorage.getSetting(SettingsKeys.buttonSkipTime);
    playback.arrowKeySkipTime =
        GStorage.getSetting(SettingsKeys.arrowKeySkipTime);
    try {
      await dispose(
        disposeSyncPlayController: false,
      );
    } catch (_) {}
    final Player? player;
    try {
      player = await playback.createVideoController(
        params.httpHeaders,
        params.adBlockerEnabled,
        offset: params.offset,
      );
    } catch (e) {
      playback.loading = false;
      KazumiLogger()
          .e('PlayerController: failed to initialize video', error: e);
      return false;
    }
    if (player == null || !playback.isCurrentPlayer(player)) {
      return false;
    }

    if (isDesktop()) {
      final freshStart = playback.volume == -1;
      if (freshStart) {
        muted = GStorage.getSetting(SettingsKeys.playerMuted);
        final remembered = GStorage.getSetting(SettingsKeys.defaultVolume);
        _preMuteVolume = remembered > 0 ? remembered : 100;
        playback.volume = muted ? 0 : remembered;
      }
      await setVolume(playback.volume);
      if (!playback.isCurrentPlayer(player)) {
        return false;
      }
    } else {
      await FlutterVolumeController.getVolume().then((value) {
        playback.volume = (value ?? 0.0) * 100;
      });
      if (!playback.isCurrentPlayer(player)) {
        return false;
      }

      await FlutterVolumeController.updateShowSystemUI(false);
      if (!playback.isCurrentPlayer(player)) {
        await FlutterVolumeController.updateShowSystemUI(true);
        return false;
      }

      FlutterVolumeController.addListener((volume) {
        if (player == null || !playback.isCurrentPlayer(player)) {
          return;
        }
        if (panel.volumeSeeking) {
          return;
        }
        playback.applyExternalVolume(volume * 100);
        if (!Platform.isAndroid && !panel.volumeSeeking) {
          panel.showVolume = true;
          hideVolumeUITimer?.cancel();
          hideVolumeUITimer = Timer(const Duration(seconds: 1), () {
            panel.showVolume = false;
            hideVolumeUITimer = null;
          });
        }
      }, category: AudioSessionCategory.playback, emitOnStart: false);
      if (!playback.isCurrentPlayer(player)) {
        return false;
      }
    }
    setPlaybackSpeed(playback.playerSpeed);
    if (!playback.isCurrentPlayer(player)) {
      return false;
    }
    KazumiLogger().i('PlayerController: video initialized');
    playback.loading = false;

    coverUrl = params.coverUrl;

    if (syncplay.syncplayController?.isConnected ?? false) {
      if (syncplay.syncplayController!.currentFileName !=
          syncplay.currentSyncPlayFileName()) {
        setSyncPlayPlayingBangumi(
            forceSyncPlaying: true, forceSyncPosition: 0.0);
      }
    }
    return true;
  }

  Future<void> setShader(SuperResolutionMode mode, {Player? player}) async {
    await playback.setShader(
      mode,
      player: player,
    );
  }

  Future<void> setPlaybackSpeed(double playerSpeed) async {
    await playback.setPlaybackSpeed(playerSpeed);
    try {
      updateDanmakuSpeed();
    } catch (_) {}
  }

  void updateDanmakuSpeed() {
    danmaku.updateDanmakuSpeed(playback.playerSpeed);
  }

  Future<void> setVolume(double value) async {
    await playback.setVolume(value);
    _clearMuteIfNeeded(value);
    _persistDesktopVolume(value);
  }

  void syncPlaybackState() {
    playback.syncPlaybackState();
  }

  Future<void> playOrPause() async {
    await playback.playOrPause(pause: pause, play: play);
  }

  Future<void> seek(Duration duration, {bool enableSync = true}) async {
    final player = playback.mediaPlayer;
    if (player == null) return;
    playback.currentPosition = duration;
    danmaku.canvasController.clear();
    try {
      await player.seek(duration);
    } catch (_) {
      return;
    }
    if (syncplay.syncplayController != null) {
      setSyncPlayCurrentPosition();
      if (enableSync) {
        await requestSyncPlaySync(doSeek: true);
      }
    }
  }

  Future<void> pause({bool enableSync = true}) async {
    final player = playback.mediaPlayer;
    if (player == null) return;
    danmaku.canvasController.pause();
    try {
      await player.pause();
    } catch (_) {
      return;
    }
    playback.playing = false;
    if (syncplay.syncplayController != null) {
      setSyncPlayCurrentPosition();
      if (enableSync) {
        await requestSyncPlaySync();
      }
    }
  }

  Future<void> play({bool enableSync = true}) async {
    final player = playback.mediaPlayer;
    if (player == null) return;
    danmaku.canvasController.resume();
    try {
      await player.play();
    } catch (_) {
      return;
    }
    playback.playing = true;
    if (syncplay.syncplayController != null) {
      setSyncPlayCurrentPosition();
      if (enableSync) {
        await requestSyncPlaySync();
      }
    }
  }

  Future<void> dispose({
    bool disposeSyncPlayController = true,
  }) async {
    hideVolumeUITimer?.cancel();
    _volumeGestureSyncTimer?.cancel();
    FlutterVolumeController.removeListener();
    await FlutterVolumeController.updateShowSystemUI(true);
    await playback.dispose(
      disposeSyncPlayController: disposeSyncPlayController,
    );
  }

  Future<void> stop() async {
    await playback.stop();
  }

  Future<Uint8List?> screenshot({String format = 'image/jpeg'}) async {
    return await playback.screenshot(format: format);
  }

  Future<Uint8List?> screenshotPng() async {
    return await playback.screenshotPng();
  }

  void setButtonForwardTime(int time) {
    playback.buttonSkipTime = time;
    GStorage.putSetting(SettingsKeys.buttonSkipTime, time);
  }

  void setArrowKeyForwardTime(int time) {
    playback.arrowKeySkipTime = time;
    GStorage.putSetting(SettingsKeys.arrowKeySkipTime, time);
  }

  Future<void> launchExternalPlayer() async {
    await externalPlayback.launch();
  }

  Future<void> createSyncPlayRoom(
      String room,
      String username,
      Future<void> Function(int episode, {int currentRoad, int offset})
          changeEpisode,
      Future<void> Function(String stableId, {int currentRoad, int offset})
          changeEpisodeByStableId,
      {bool enableTLS = true}) async {
    await syncplay.createRoom(
      room,
      username,
      changeEpisode,
      changeEpisodeByStableId,
      enableTLS: enableTLS,
    );
  }

  void setSyncPlayCurrentPosition(
      {bool? forceSyncPlaying, double? forceSyncPosition}) {
    syncplay.setCurrentPosition(
      forceSyncPlaying: forceSyncPlaying,
      forceSyncPosition: forceSyncPosition,
    );
  }

  Future<void> setSyncPlayPlayingBangumi(
      {bool? forceSyncPlaying, double? forceSyncPosition}) async {
    await syncplay.setPlayingBangumi(
      forceSyncPlaying: forceSyncPlaying,
      forceSyncPosition: forceSyncPosition,
    );
  }

  Future<void> requestSyncPlaySync({bool? doSeek}) async {
    await syncplay.requestSync(doSeek: doSeek);
  }

  Future<void> sendSyncPlayChatMessage(String message) async {
    await syncplay.sendChatMessage(message);
  }

  Future<void> exitSyncPlayRoom() async {
    await syncplay.exitRoom();
  }
}
