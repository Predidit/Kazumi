// ignore_for_file: library_private_types_in_public_api

import 'dart:async';

import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/pages/player/controller/player_models.dart';
import 'package:kazumi/services/logging/logger.dart';
import 'package:kazumi/services/storage/storage.dart';
import 'package:kazumi/services/player/syncplay_client.dart';
import 'package:kazumi/services/player/syncplay_endpoint.dart';
import 'package:mobx/mobx.dart';

part 'player_syncplay_controller.g.dart';

class PlayerSyncPlayController = _PlayerSyncPlayController
    with _$PlayerSyncPlayController;

abstract class _PlayerSyncPlayController with Store {
  _PlayerSyncPlayController({
    required this.bangumiId,
    required this.currentEpisode,
    required this.currentEpisodeStableId,
    required this.currentRoad,
    required this.playing,
    required this.currentPosition,
    required this.playerPosition,
    required this.duration,
    required this.pause,
    required this.play,
    required this.seek,
  });

  final int Function() bangumiId;
  final int Function() currentEpisode;
  final String Function() currentEpisodeStableId;
  final int Function() currentRoad;
  final bool Function() playing;
  final Duration Function() currentPosition;
  final Duration Function() playerPosition;
  final Duration Function() duration;
  final Future<void> Function({bool enableSync}) pause;
  final Future<void> Function({bool enableSync}) play;
  final Future<void> Function(Duration duration, {bool enableSync}) seek;

  SyncplayClient? syncplayController;
  @observable
  String syncplayRoom = '';
  @observable
  int syncplayClientRtt = 0;

  final StreamController<SyncPlayChatMessage> _chatStreamController =
      StreamController<SyncPlayChatMessage>.broadcast();

  Stream<SyncPlayChatMessage> get chatStream => _chatStreamController.stream;

  void emitChatMessage({
    required String username,
    required String message,
    required bool fromRemote,
  }) {
    if (_chatStreamController.isClosed) {
      return;
    }
    _chatStreamController.add(SyncPlayChatMessage(
      username: username,
      message: message,
      fromRemote: fromRemote,
    ));
  }

  Future<void> createRoom(
      String room,
      String username,
      Future<void> Function(int episode, {int currentRoad, int offset})
          changeEpisode,
      Future<void> Function(String stableId, {int currentRoad, int offset})
          changeEpisodeByStableId,
      {bool enableTLS = true}) async {
    await syncplayController?.disconnect();
    final String syncPlayEndPoint =
        GStorage.getSetting(SettingsKeys.syncPlayEndPoint);
    String syncPlayEndPointHost = '';
    int syncPlayEndPointPort = 0;
    KazumiLogger().i('SyncPlay: connecting to $syncPlayEndPoint');
    try {
      final parsed = parseSyncPlayEndPoint(syncPlayEndPoint);
      if (parsed != null) {
        syncPlayEndPointHost = parsed.host;
        syncPlayEndPointPort = parsed.port;
      }
    } catch (_) {}
    if (syncPlayEndPointHost == '' || syncPlayEndPointPort == 0) {
      KazumiDialog.showToast(
        message: 'SyncPlay: 服务器地址不合法 $syncPlayEndPoint',
      );
      KazumiLogger().e('SyncPlay: invalid server address $syncPlayEndPoint');
      return;
    }
    syncplayController =
        SyncplayClient(host: syncPlayEndPointHost, port: syncPlayEndPointPort);
    try {
      await syncplayController!.connect(enableTLS: enableTLS);
      KazumiLogger().i(
          'SyncPlay: connected to $syncPlayEndPointHost:$syncPlayEndPointPort');
      syncplayController!.onGeneralMessage.listen(
        (message) {
          // print('SyncPlay: general message: ${message.toString()}');
        },
        onError: (error) {
          KazumiLogger().e('SyncPlay: error ${error.message}', error: error);
          if (error is SyncplayConnectionException) {
            exitRoom();
            KazumiDialog.showToast(
              message: 'SyncPlay: 同步中断 ${error.message}',
              duration: const Duration(seconds: 5),
              showActionButton: true,
              actionLabel: '重新连接',
              onActionPressed: () => createRoom(
                room,
                username,
                changeEpisode,
                changeEpisodeByStableId,
              ),
            );
          }
        },
      );
      syncplayController!.onRoomMessage.listen(
        (message) {
          if (message['type'] == 'init') {
            if (message['username'] == '') {
              KazumiDialog.showToast(
                  message: 'SyncPlay: 您是当前房间中的唯一用户',
                  duration: const Duration(seconds: 5));
              setPlayingBangumi();
            } else {
              KazumiDialog.showToast(
                  message:
                      'SyncPlay: 您不是当前房间中的唯一用户, 当前以用户 ${message['username']} 进度为准');
            }
          }
          if (message['type'] == 'left') {
            KazumiDialog.showToast(
                message: 'SyncPlay: ${message['username']} 离开了房间',
                duration: const Duration(seconds: 5));
          }
          if (message['type'] == 'joined') {
            KazumiDialog.showToast(
                message: 'SyncPlay: ${message['username']} 加入了房间',
                duration: const Duration(seconds: 5));
          }
        },
      );
      syncplayController!.onFileChangedMessage.listen(
        (message) {
          KazumiLogger().i(
              'SyncPlay: file changed by ${message['setBy']}: ${message['name']}');
          final identity =
              SyncPlayEpisodeIdentity.parse((message['name'] ?? '').toString());
          if (identity == null || identity.bangumiId != bangumiId()) {
            return;
          }
          if (identity.hasStableId) {
            final targetRoad = identity.road ?? currentRoad();
            if (!identity.targetsStableEpisode(
              currentStableId: currentEpisodeStableId(),
              currentRoad: currentRoad(),
            )) {
              KazumiDialog.showToast(
                  message: 'SyncPlay: ${message['setBy'] ?? 'unknown'} 切换到同步集数',
                  duration: const Duration(seconds: 3));
              changeEpisodeByStableId(
                identity.stableId,
                currentRoad: targetRoad,
              );
            }
            return;
          }

          final episode = identity.episode ?? 0;
          if (episode != 0 && episode != currentEpisode()) {
            KazumiDialog.showToast(
                message:
                    'SyncPlay: ${message['setBy'] ?? 'unknown'} 切换到第 $episode 话',
                duration: const Duration(seconds: 3));
            changeEpisode(episode, currentRoad: currentRoad());
          }
        },
      );
      syncplayController!.onChatMessage.listen(
        (message) {
          final String sender = (message['username'] ?? '').toString();
          final String text = (message['message'] ?? '').toString();
          final bool fromRemote = message['username'] != username;

          emitChatMessage(
            username: sender,
            message: text,
            fromRemote: fromRemote,
          );
        },
        onError: (error) {
          KazumiLogger().e('SyncPlay: error ${error.message}', error: error);
        },
      );
      syncplayController!.onPositionChangedMessage.listen(
        (message) {
          syncplayClientRtt = (message['clientRtt'].toDouble() * 1000).toInt();
          KazumiLogger().i(
              'SyncPlay: position changed by ${message['setBy']}: [${DateTime.now().millisecondsSinceEpoch / 1000.0}] calculatedPosition ${message['calculatedPositon']} position: ${message['position']} doSeek: ${message['doSeek']} paused: ${message['paused']} clientRtt: ${message['clientRtt']} serverRtt: ${message['serverRtt']} fd: ${message['fd']}');
          if (message['paused'] != !playing()) {
            if (message['paused']) {
              if (message['position'] != 0) {
                KazumiDialog.showToast(
                    message: 'SyncPlay: ${message['setBy'] ?? 'unknown'} 暂停了播放',
                    duration: const Duration(seconds: 3));
                pause(enableSync: false);
              }
            } else {
              if (message['position'] != 0) {
                KazumiDialog.showToast(
                    message: 'SyncPlay: ${message['setBy'] ?? 'unknown'} 开始了播放',
                    duration: const Duration(seconds: 3));
                play(enableSync: false);
              }
            }
          }
          if ((((playerPosition().inMilliseconds -
                              (message['calculatedPositon'].toDouble() * 1000)
                                  .toInt())
                          .abs() >
                      1000) ||
                  message['doSeek']) &&
              duration().inMilliseconds > 0) {
            seek(
                Duration(
                    milliseconds:
                        (message['calculatedPositon'].toDouble() * 1000)
                            .toInt()),
                enableSync: false);
          }
        },
      );
      await syncplayController!.joinRoom(room, username);
      syncplayRoom = room;
    } catch (e) {
      KazumiLogger().e('SyncPlay: error', error: e);
    }
  }

  void setCurrentPosition({bool? forceSyncPlaying, double? forceSyncPosition}) {
    if (syncplayController == null) {
      return;
    }
    forceSyncPlaying ??= playing();
    syncplayController!.setPaused(!forceSyncPlaying);
    syncplayController!.setPosition((forceSyncPosition ??
        (((currentPosition().inMilliseconds - playerPosition().inMilliseconds)
                    .abs() >
                2000)
            ? currentPosition().inMilliseconds.toDouble() / 1000
            : playerPosition().inMilliseconds.toDouble() / 1000)));
  }

  Future<void> setPlayingBangumi(
      {bool? forceSyncPlaying, double? forceSyncPosition}) async {
    await syncplayController!
        .setSyncPlayPlaying(currentSyncPlayFileName(), 10800, 220514438);
    setCurrentPosition(
        forceSyncPlaying: forceSyncPlaying,
        forceSyncPosition: forceSyncPosition);
    await requestSync(doSeek: null);
  }

  String currentSyncPlayFileName() {
    return SyncPlayEpisodeIdentity.fileNameFor(
      bangumiId: bangumiId(),
      road: currentRoad(),
      episode: currentEpisode(),
      stableId: currentEpisodeStableId(),
    );
  }

  Future<void> requestSync({bool? doSeek}) async {
    await syncplayController!.sendSyncPlaySyncRequest(doSeek: doSeek);
  }

  Future<void> sendChatMessage(String message) async {
    if (syncplayController == null) {
      return;
    }
    await syncplayController!.sendChatMessage(message);
  }

  @action
  Future<void> exitRoom() async {
    final controller = syncplayController;
    syncplayController = null;
    syncplayRoom = '';
    syncplayClientRtt = 0;
    if (controller == null) {
      return;
    }
    await controller.disconnect();
  }

  Future<void> dispose() async {
    await exitRoom();
    await _chatStreamController.close();
  }
}
