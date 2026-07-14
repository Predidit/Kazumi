// ignore_for_file: library_private_types_in_public_api

import 'dart:async';

import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/pages/player/controller/player_models.dart';
import 'package:kazumi/services/logging/logger.dart';
import 'package:kazumi/services/storage/storage.dart';
import 'package:kazumi/services/player/syncplay_client.dart';
import 'package:kazumi/services/player/syncplay_endpoint.dart';
import 'package:kazumi/utils/async_session.dart';
import 'package:mobx/mobx.dart';

part 'player_syncplay_controller.g.dart';

class PlayerSyncPlayController = _PlayerSyncPlayController
    with _$PlayerSyncPlayController;

abstract class _PlayerSyncPlayController with Store {
  _PlayerSyncPlayController({
    required this.bangumiId,
    required this.currentEpisode,
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
  final int Function() currentRoad;
  final bool Function() playing;
  final Duration Function() currentPosition;
  final Duration Function() playerPosition;
  final Duration Function() duration;
  final Future<void> Function({bool enableSync}) pause;
  final Future<void> Function({bool enableSync}) play;
  final Future<void> Function(Duration duration, {bool enableSync}) seek;

  SyncplayClient? syncplayController;
  final AsyncSessionOwner _connectionSessions = AsyncSessionOwner();
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
      {bool enableTLS = true}) async {
    if (_connectionSessions.isClosed) {
      return;
    }
    final session = _connectionSessions.begin();
    final previousClient = syncplayController;
    syncplayController = null;
    syncplayRoom = '';
    syncplayClientRtt = 0;
    await previousClient?.disconnect();
    if (session.isStale) {
      return;
    }
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
    final client =
        SyncplayClient(host: syncPlayEndPointHost, port: syncPlayEndPointPort);
    syncplayController = client;
    try {
      await client.connect(enableTLS: enableTLS);
      if (!_isCurrentConnection(session, client)) {
        await client.disconnect();
        return;
      }
      KazumiLogger().i(
          'SyncPlay: connected to $syncPlayEndPointHost:$syncPlayEndPointPort');
      client.onGeneralMessage.listen(
        (message) {
          // print('SyncPlay: general message: ${message.toString()}');
        },
        onError: (error) {
          if (!_isCurrentConnection(session, client)) {
            return;
          }
          final message =
              error is SyncplayException ? error.message : error.toString();
          KazumiLogger().e('SyncPlay: error $message', error: error);
          if (error is SyncplayConnectionException) {
            exitRoom();
            KazumiDialog.showToast(
              message: 'SyncPlay: 同步中断 $message',
              duration: const Duration(seconds: 5),
              showActionButton: true,
              actionLabel: '重新连接',
              onActionPressed: () => createRoom(room, username, changeEpisode,
                  enableTLS: enableTLS),
            );
          }
        },
      );
      client.onRoomMessage.listen(
        (message) {
          if (!_isCurrentConnection(session, client)) {
            return;
          }
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
      client.onFileChangedMessage.listen(
        (message) {
          if (!_isCurrentConnection(session, client)) {
            return;
          }
          KazumiLogger().i(
              'SyncPlay: file changed by ${message['setBy']}: ${message['name']}');
          RegExp regExp = RegExp(r'(\d+)\[(\d+)\]');
          Match? match = regExp.firstMatch(message['name']);
          if (match != null) {
            int bangumiID = int.tryParse(match.group(1) ?? '0') ?? 0;
            int episode = int.tryParse(match.group(2) ?? '0') ?? 0;
            if (bangumiID != 0 && episode != 0 && episode != currentEpisode()) {
              KazumiDialog.showToast(
                  message:
                      'SyncPlay: ${message['setBy'] ?? 'unknown'} 切换到第 $episode 话',
                  duration: const Duration(seconds: 3));
              changeEpisode(episode, currentRoad: currentRoad());
            }
          }
        },
      );
      client.onChatMessage.listen(
        (message) {
          if (!_isCurrentConnection(session, client)) {
            return;
          }
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
          if (!_isCurrentConnection(session, client)) {
            return;
          }
          final message =
              error is SyncplayException ? error.message : error.toString();
          KazumiLogger().e('SyncPlay: error $message', error: error);
        },
      );
      client.onPositionChangedMessage.listen(
        (message) {
          if (!_isCurrentConnection(session, client)) {
            return;
          }
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
      await client.joinRoom(room, username);
      if (!_isCurrentConnection(session, client)) {
        await client.disconnect();
        return;
      }
      syncplayRoom = room;
    } catch (e) {
      KazumiLogger().e('SyncPlay: error', error: e);
      if (!_isCurrentConnection(session, client)) {
        await client.disconnect();
        return;
      }
      syncplayController = null;
      syncplayRoom = '';
      syncplayClientRtt = 0;
      await client.disconnect();
      final message = e is SyncplayException ? e.message : e.toString();
      KazumiDialog.showToast(
        message: 'SyncPlay: 连接失败 $message',
        duration: const Duration(seconds: 5),
      );
    }
  }

  bool _isCurrentConnection(AsyncSession session, SyncplayClient client) {
    return session.isActive && identical(syncplayController, client);
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
    final client = syncplayController;
    if (client == null) {
      return;
    }
    await _runBestEffortSync(() async {
      await client.setSyncPlayPlaying(
          "${bangumiId()}[${currentEpisode()}]", 10800, 220514438);
      if (!identical(syncplayController, client)) {
        return;
      }
      setCurrentPosition(
          forceSyncPlaying: forceSyncPlaying,
          forceSyncPosition: forceSyncPosition);
      await client.sendSyncPlaySyncRequest(doSeek: null);
    });
  }

  Future<void> requestSync({bool? doSeek}) async {
    final client = syncplayController;
    if (client == null) {
      return;
    }
    await _runBestEffortSync(
        () => client.sendSyncPlaySyncRequest(doSeek: doSeek));
  }

  Future<void> sendChatMessage(String message) async {
    final client = syncplayController;
    if (client == null) {
      return;
    }
    await _runBestEffortSync(() => client.sendChatMessage(message));
  }

  Future<void> _runBestEffortSync(Future<void> Function() operation) async {
    try {
      await operation();
    } on SyncplayConnectionException {
      // Socket handlers report active connection failures.
    }
  }

  @action
  Future<void> exitRoom() async {
    _connectionSessions.cancel();
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
    _connectionSessions.close();
    await exitRoom();
    await _chatStreamController.close();
  }
}
