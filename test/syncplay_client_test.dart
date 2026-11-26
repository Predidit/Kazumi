import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kazumi/services/player/syncplay_client.dart';

void main() {
  late Socket peer;
  late SyncplayClient client;
  Completer<Map<String, dynamic>>? pendingReply;

  Future<void> connect({double Function()? getPosition}) async {
    final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final accepted = Completer<Socket>();
    final connections = server.listen(accepted.complete);
    client = SyncplayClient(
      host: '127.0.0.1',
      port: server.port,
      getPosition: getPosition,
    );
    await client.connect(enableTLS: false);
    peer = await accepted.future;
    final responses = peer
        .cast<List<int>>()
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) {
          final reply = pendingReply;
          if (reply != null && !reply.isCompleted) {
            reply.complete(jsonDecode(line)['State'] as Map<String, dynamic>);
          }
        });
    addTearDown(() async {
      await client.disconnect();
      await responses.cancel();
      peer.destroy();
      await connections.cancel();
      await server.close();
    });
  }

  Future<Map<String, dynamic>> replyTo(Future<void> Function() send) async {
    final reply = Completer<Map<String, dynamic>>();
    pendingReply = reply;
    await send();
    return reply.future.timeout(const Duration(seconds: 5));
  }

  Future<Map<String, dynamic>> receiveState(
    double position, {
    bool paused = false,
    bool doSeek = false,
    Map<String, int>? ack,
    bool withLatency = false,
  }) => replyTo(() async {
    peer.writeln(
      jsonEncode({
        'State': {
          'playstate': {
            'position': position,
            'paused': paused,
            'doSeek': doSeek,
          },
          'ignoringOnTheFly': ?ack,
          if (withLatency)
            'ping': {
              'clientLatencyCalculation':
                  DateTime.now().millisecondsSinceEpoch / 1000.0 - 0.2,
              'serverRtt': 0.2,
            },
        },
      }),
    );
    await peer.flush();
  });

  test('remote progress does not replace the last local position', () async {
    await connect();
    client.setPosition(100);
    client.setPaused(false);
    for (final target in [100.2, 100.4, 100.6]) {
      final reply = await receiveState(target);
      expect(reply['playstate']['position'], 100);
    }
  });

  test(
    'heartbeats sample current progress while events retain compensation',
    () async {
      var actualPosition = 100.0;
      await connect(getPosition: () => actualPosition);
      client.setPosition(90);
      final event = client.onPositionChangedMessage.first;
      final reply = await receiveState(100.2, withLatency: true);
      final target = await event;
      expect(reply['playstate']['position'], 100);
      expect(target['position'], 100.2);
      expect(target['fd'], greaterThan(0));
      expect(
        target['calculatedPositon'],
        closeTo(100.2 + target['fd'], 0.000001),
      );
      actualPosition = 100.6;
      final next = await receiveState(101);
      expect(next['playstate']['position'], 100.6);
    },
  );

  test(
    'local seek keeps its target until the matching acknowledgement',
    () async {
      var actualPosition = 100.0;
      await connect(getPosition: () => actualPosition);
      client.setPosition(500);
      client.setPaused(true);
      final sent = await replyTo(
        () => client.sendSyncPlaySyncRequest(doSeek: true),
      );
      final ack = sent['ignoringOnTheFly']['client'] as int;
      expect(sent['playstate']['position'], 500);
      expect(sent['playstate']['doSeek'], isTrue);
      for (final confirmation in [
        null,
        {'client': ack + 1},
      ]) {
        final reply = await receiveState(100.2, ack: confirmation);
        expect(reply['playstate']['position'], 500);
        expect(reply['playstate']['paused'], isTrue);
        expect(reply['ignoringOnTheFly']['client'], ack);
      }
      actualPosition = 500.5;
      final confirmed = await receiveState(
        500,
        paused: true,
        ack: {'client': ack},
      );
      expect(confirmed['playstate']['position'], 500.5);
      expect(confirmed.containsKey('ignoringOnTheFly'), isFalse);
    },
  );

  test(
    'remote controls acknowledge targets before the player catches up',
    () async {
      var actualPosition = 100.0;
      await connect(getPosition: () => actualPosition);
      for (final paused in [true, false]) {
        final target = paused ? 500.0 : 700.0;
        final confirmed = await receiveState(
          target,
          paused: paused,
          doSeek: true,
          ack: {'server': 7},
        );
        expect(confirmed['playstate']['position'], target);
        expect(confirmed['playstate']['paused'], paused);
        expect(confirmed['ignoringOnTheFly'], {'server': 7});
        expect(confirmed['playstate']['doSeek'], isNull);
        actualPosition = target + 0.25;
        final next = await receiveState(target, paused: paused);
        expect(next['playstate']['position'], actualPosition);
        expect(next.containsKey('ignoringOnTheFly'), isFalse);
      }
    },
  );
}
