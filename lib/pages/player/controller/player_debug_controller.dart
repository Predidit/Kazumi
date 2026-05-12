// ignore_for_file: library_private_types_in_public_api

import 'dart:async';

import 'package:kazumi/utils/logger.dart';
import 'package:media_kit/media_kit.dart';
import 'package:mobx/mobx.dart';

part 'player_debug_controller.g.dart';

class PlayerDebugController = _PlayerDebugController
    with _$PlayerDebugController;

abstract class _PlayerDebugController with Store {
  /// LogLevel 0: 错误 1: 警告 2: 简略 3: 详细
  int playerLogLevel = 2;

  @observable
  ObservableList<String> playerLog = ObservableList.of([]);
  @observable
  int playerWidth = 0;
  @observable
  int playerHeight = 0;
  @observable
  String playerVideoParams = '';
  @observable
  String playerAudioParams = '';
  @observable
  String playerPlaylist = '';
  @observable
  String playerAudioTracks = '';
  @observable
  String playerVideoTracks = '';
  @observable
  String playerAudioBitrate = '';

  StreamSubscription<PlayerLog>? playerLogSubscription;
  StreamSubscription<int?>? playerWidthSubscription;
  StreamSubscription<int?>? playerHeightSubscription;
  StreamSubscription<VideoParams>? playerVideoParamsSubscription;
  StreamSubscription<AudioParams>? playerAudioParamsSubscription;
  StreamSubscription<Playlist>? playerPlaylistSubscription;
  StreamSubscription<Track>? playerTracksSubscription;
  StreamSubscription<double?>? playerAudioBitrateSubscription;

  Future<void> setup(
    Player player, {
    required int lifecycleId,
    required bool Function(int lifecycleId, Player player) isCurrentPlayer,
    required bool playerDebugMode,
  }) async {
    await playerLogSubscription?.cancel();
    if (!isCurrentPlayer(lifecycleId, player)) return;
    playerLogSubscription = player.stream.log.listen((event) {
      playerLog.add(event.toString());
      if (playerDebugMode) {
        KazumiLogger().i("MPV: ${event.toString()}", forceLog: true);
      }
    });
    await playerWidthSubscription?.cancel();
    if (!isCurrentPlayer(lifecycleId, player)) return;
    playerWidthSubscription = player.stream.width.listen((event) {
      playerWidth = event ?? 0;
    });
    await playerHeightSubscription?.cancel();
    if (!isCurrentPlayer(lifecycleId, player)) return;
    playerHeightSubscription = player.stream.height.listen((event) {
      playerHeight = event ?? 0;
    });
    await playerVideoParamsSubscription?.cancel();
    if (!isCurrentPlayer(lifecycleId, player)) return;
    playerVideoParamsSubscription = player.stream.videoParams.listen((event) {
      playerVideoParams = event.toString();
    });
    await playerAudioParamsSubscription?.cancel();
    if (!isCurrentPlayer(lifecycleId, player)) return;
    playerAudioParamsSubscription = player.stream.audioParams.listen((event) {
      playerAudioParams = event.toString();
    });
    await playerPlaylistSubscription?.cancel();
    if (!isCurrentPlayer(lifecycleId, player)) return;
    playerPlaylistSubscription = player.stream.playlist.listen((event) {
      playerPlaylist = event.toString();
    });
    await playerTracksSubscription?.cancel();
    if (!isCurrentPlayer(lifecycleId, player)) return;
    playerTracksSubscription = player.stream.track.listen((event) {
      playerAudioTracks = event.audio.toString();
      playerVideoTracks = event.video.toString();
    });
    await playerAudioBitrateSubscription?.cancel();
    if (!isCurrentPlayer(lifecycleId, player)) return;
    playerAudioBitrateSubscription = player.stream.audioBitrate.listen((event) {
      playerAudioBitrate = event.toString();
    });
  }

  Future<void> cancel() async {
    // Detach fields before awaiting so a new player cannot lose its listeners.
    final logSubscription = playerLogSubscription;
    final widthSubscription = playerWidthSubscription;
    final heightSubscription = playerHeightSubscription;
    final videoParamsSubscription = playerVideoParamsSubscription;
    final audioParamsSubscription = playerAudioParamsSubscription;
    final playlistSubscription = playerPlaylistSubscription;
    final tracksSubscription = playerTracksSubscription;
    final audioBitrateSubscription = playerAudioBitrateSubscription;

    playerLogSubscription = null;
    playerWidthSubscription = null;
    playerHeightSubscription = null;
    playerVideoParamsSubscription = null;
    playerAudioParamsSubscription = null;
    playerPlaylistSubscription = null;
    playerTracksSubscription = null;
    playerAudioBitrateSubscription = null;

    await logSubscription?.cancel();
    await widthSubscription?.cancel();
    await heightSubscription?.cancel();
    await videoParamsSubscription?.cancel();
    await audioParamsSubscription?.cancel();
    await playlistSubscription?.cancel();
    await tracksSubscription?.cancel();
    await audioBitrateSubscription?.cancel();
  }
}
