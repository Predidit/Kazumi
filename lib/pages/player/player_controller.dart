import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_volume_controller/flutter_volume_controller.dart';
import 'package:media_kit/media_kit.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:hive_ce/hive.dart';
import 'package:kazumi/pages/player/controller/external_playback_launcher.dart';
import 'package:kazumi/pages/player/controller/player_danmaku_controller.dart';
import 'package:kazumi/pages/player/controller/player_debug_controller.dart';
import 'package:kazumi/pages/player/controller/player_models.dart';
import 'package:kazumi/pages/player/controller/player_panel_controller.dart';
import 'package:kazumi/pages/player/controller/player_playback_controller.dart';
import 'package:kazumi/pages/player/controller/player_syncplay_controller.dart';
import 'package:kazumi/utils/storage.dart';
import 'package:kazumi/utils/logger.dart';
import 'package:kazumi/utils/utils.dart';
import 'package:kazumi/shaders/shaders_controller.dart';

export 'package:kazumi/pages/player/controller/player_models.dart';

class PlayerController {
  final Box setting = GStorage.setting;
  final ShadersController shadersController = Modular.get<ShadersController>();
  final PlayerPanelController panel = PlayerPanelController();
  final PlayerDebugController debug = PlayerDebugController();

  late final PlayerDanmakuController danmaku = PlayerDanmakuController(
    setting: setting,
    isLocalPlayback: () => isLocalPlayback,
  );
  late final PlayerPlaybackController playback = PlayerPlaybackController(
    setting: setting,
    shadersController: shadersController,
    debug: debug,
    videoUrl: () => videoUrl,
    onExitSyncPlayRoom: () => syncplay.exitRoom(),
  );
  late final PlayerSyncPlayController syncplay = PlayerSyncPlayController(
    setting: setting,
    bangumiId: () => bangumiId,
    currentEpisode: () => currentEpisode,
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
  late int currentRoad;
  late String referer;
  String? coverUrl;
  String videoUrl = '';
  bool isLocalPlayback = false;
  Timer? hideVolumeUITimer;

  Future<void> init(PlaybackInitParams params) async {
    final int lifecycleId = playback.beginInit();
    videoUrl = params.videoUrl;
    isLocalPlayback = params.isLocalPlayback;
    bangumiId = params.bangumiId;
    currentEpisode = params.episode;
    currentRoad = params.currentRoad;
    referer = params.referer;

    KazumiLogger().i(
        'PlayerController: ${params.isLocalPlayback ? "local" : "online"} playback, url: ${params.videoUrl}');

    playback.resetForInit();
    debug.playerLogLevel =
        setting.get(SettingBoxKey.playerLogLevel, defaultValue: 2);
    playback.playerSpeed =
        setting.get(SettingBoxKey.defaultPlaySpeed, defaultValue: 1.0);
    panel.aspectRatioType =
        setting.get(SettingBoxKey.defaultAspectRatioType, defaultValue: 1);

    playback.buttonSkipTime =
        setting.get(SettingBoxKey.buttonSkipTime, defaultValue: 80);
    playback.arrowKeySkipTime =
        setting.get(SettingBoxKey.arrowKeySkipTime, defaultValue: 10);
    try {
      await dispose(
        disposeSyncPlayController: false,
        cancelActiveInit: false,
      );
    } catch (_) {}
    if (playback.lifecycleId != lifecycleId) {
      return;
    }
    int episodeFromTitle = 0;
    try {
      episodeFromTitle = Utils.extractEpisodeNumber(params.episodeTitle);
    } catch (e) {
      KazumiLogger().e(
          'PlayerController: failed to extract episode number from title',
          error: e);
    }
    if (episodeFromTitle == 0) {
      episodeFromTitle = params.episode;
    }
    _loadDanmaku(params.bangumiId, params.pluginName, episodeFromTitle);
    final Player? player;
    try {
      player = await playback.createVideoController(
        params.httpHeaders,
        params.adBlockerEnabled,
        offset: params.offset,
        lifecycleId: lifecycleId,
      );
    } catch (e) {
      if (playback.lifecycleId == lifecycleId) {
        playback.loading = false;
        KazumiLogger()
            .e('PlayerController: failed to initialize video', error: e);
      }
      return;
    }
    if (player == null || !playback.isCurrentPlayer(lifecycleId, player)) {
      return;
    }

    if (Utils.isDesktop()) {
      playback.volume = playback.volume != -1 ? playback.volume : 100;
      await setVolume(playback.volume);
      if (!playback.isCurrentPlayer(lifecycleId, player)) {
        return;
      }
    } else {
      await FlutterVolumeController.getVolume().then((value) {
        playback.volume = (value ?? 0.0) * 100;
      });
      if (!playback.isCurrentPlayer(lifecycleId, player)) {
        return;
      }

      await FlutterVolumeController.updateShowSystemUI(false);
      if (!playback.isCurrentPlayer(lifecycleId, player)) {
        await FlutterVolumeController.updateShowSystemUI(true);
        return;
      }

      FlutterVolumeController.addListener((volume) {
        if (player == null || !playback.isCurrentPlayer(lifecycleId, player)) {
          return;
        }
        playback.volume = volume * 100;
        if (!Platform.isAndroid && !panel.volumeSeeking) {
          panel.showVolume = true;
          hideVolumeUITimer?.cancel();
          hideVolumeUITimer = Timer(const Duration(seconds: 1), () {
            panel.showVolume = false;
            hideVolumeUITimer = null;
          });
        }
      }, category: AudioSessionCategory.playback, emitOnStart: false);
      if (!playback.isCurrentPlayer(lifecycleId, player)) {
        return;
      }
    }
    setPlaybackSpeed(playback.playerSpeed);
    if (!playback.isCurrentPlayer(lifecycleId, player)) {
      return;
    }
    KazumiLogger().i('PlayerController: video initialized');
    playback.loading = false;

    coverUrl = params.coverUrl;

    if (syncplay.syncplayController?.isConnected ?? false) {
      if (syncplay.syncplayController!.currentFileName !=
          "$bangumiId[$currentEpisode]") {
        setSyncPlayPlayingBangumi(
            forceSyncPlaying: true, forceSyncPosition: 0.0);
      }
    }
  }

  Future<void> setShader(int type,
      {bool synchronized = true, Player? player}) async {
    await playback.setShader(
      type,
      synchronized: synchronized,
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
    bool cancelActiveInit = true,
  }) async {
    hideVolumeUITimer?.cancel();
    FlutterVolumeController.removeListener();
    await FlutterVolumeController.updateShowSystemUI(true);
    await playback.dispose(
      disposeSyncPlayController: disposeSyncPlayController,
      cancelActiveInit: cancelActiveInit,
    );
  }

  Future<void> stop() async {
    await playback.stop();
  }

  Future<Uint8List?> screenshot({String format = 'image/jpeg'}) async {
    return await playback.screenshot(format: format);
  }

  void setButtonForwardTime(int time) {
    playback.buttonSkipTime = time;
    setting.put(SettingBoxKey.buttonSkipTime, time);
  }

  void setArrowKeyForwardTime(int time) {
    playback.arrowKeySkipTime = time;
    setting.put(SettingBoxKey.arrowKeySkipTime, time);
  }

  /// 加载弹幕 (离线模式优先从缓存加载，无缓存时尝试在线获取)
  Future<void> _loadDanmaku(
      int bangumiId, String pluginName, int episode) async {
    await danmaku.loadDanmaku(bangumiId, pluginName, episode);
  }

  Future<void> launchExternalPlayer() async {
    await externalPlayback.launch();
  }

  Future<void> createSyncPlayRoom(
      String room,
      String username,
      Future<void> Function(int episode, {int currentRoad, int offset})
          changeEpisode,
      {bool enableTLS = true}) async {
    await syncplay.createRoom(
      room,
      username,
      changeEpisode,
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
