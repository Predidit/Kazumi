import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kazumi/services/player/syncplay_client.dart';

void main() {
  group('SyncplayClient TLS upgrade', () {
    test('connect without TLS keeps the plaintext protocol working', () async {
      final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      final client = SyncplayClient(
        host: InternetAddress.loopbackIPv4.address,
        port: server.port,
      );

      addTearDown(() async {
        await client.disconnect();
        await server.close();
      });

      final connection = server.first;
      await client.connect(enableTLS: false);
      final socket = await connection;
      final messages = _socketMessages(socket);

      expect(client.isConnected, isTrue);
      expect(client.isTLS, isFalse);

      await client.joinRoom('plaintext-room', 'PlainTest');
      expect(await _nextMessage(messages), {
        'Hello': {
          'username': 'PlainTest',
          'room': {'name': 'plaintext-room'},
          'version': '1.7.0',
          'features': {
            'sharedPlaylists': true,
            'chat': true,
            'featureList': true,
            'readiness': true,
            'managedRooms': false,
          },
        },
      });

      final helloFuture = client.onGeneralMessage.first;
      socket.write(
        '{"Hello":{"username":"PlainTest","room":{"name":"plaintext-room"},"version":"1.7.0"}}\r\n',
      );
      expect(await helloFuture, {
        'username': 'PlainTest',
        'room': 'plaintext-room',
      });
      await messages.cancel();
    });

    test('connect waits for TLS before allowing room messages', () async {
      final plainServer = await ServerSocket.bind(
        InternetAddress.loopbackIPv4,
        0,
      );
      final upgradedServer = await ServerSocket.bind(
        InternetAddress.loopbackIPv4,
        0,
      );
      final upgradeStarted = Completer<void>();
      final allowUpgrade = Completer<void>();

      final client = SyncplayClient(
        host: InternetAddress.loopbackIPv4.address,
        port: plainServer.port,
        secureSocketUpgrader: (socket, subscription, host) async {
          upgradeStarted.complete();
          await allowUpgrade.future;
          await subscription.cancel();
          await socket.close();
          return RawSocket.connect(
            InternetAddress.loopbackIPv4,
            upgradedServer.port,
          );
        },
      );

      addTearDown(() async {
        await client.disconnect();
        await plainServer.close();
        await upgradedServer.close();
      });

      final plainConnection = plainServer.first;
      var connectCompleted = false;
      final connectFuture = client.connect().then((_) {
        connectCompleted = true;
      });
      final plainSocket = await plainConnection;
      final plainMessages = _socketMessages(plainSocket);

      expect(await _nextMessage(plainMessages), {
        'TLS': {'startTLS': 'send'},
      });

      plainSocket.write('{"TLS":{"startTLS":"true"}}\r\n');
      await upgradeStarted.future;
      await Future<void>.delayed(Duration.zero);

      expect(connectCompleted, isFalse);
      expect(client.isConnected, isFalse);
      expect(client.isTLS, isFalse);

      final upgradedConnection = upgradedServer.first;
      allowUpgrade.complete();
      final upgradedSocket = await upgradedConnection;
      final upgradedMessages = _socketMessages(upgradedSocket);
      await connectFuture;

      expect(client.isConnected, isTrue);
      expect(client.isTLS, isTrue);

      await client.joinRoom('123456', 'Tester');
      final hello = await _nextMessage(upgradedMessages);

      expect(hello['Hello']['username'], 'Tester');
      expect(hello['Hello']['room']['name'], '123456');
      await plainMessages.cancel();
      await upgradedMessages.cancel();
    });

    test('connect fails when the server rejects TLS', () async {
      final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      final client = SyncplayClient(
        host: InternetAddress.loopbackIPv4.address,
        port: server.port,
      );

      addTearDown(() async {
        await client.disconnect();
        await server.close();
      });

      final connection = server.first;
      final connectFuture = client.connect();
      final socket = await connection;
      final messages = _socketMessages(socket);

      expect(await _nextMessage(messages), {
        'TLS': {'startTLS': 'send'},
      });

      final connectExpectation = expectLater(
        connectFuture,
        throwsA(
          isA<SyncplayConnectionException>().having(
            (error) => error.message,
            'message',
            contains('rejected TLS'),
          ),
        ),
      );
      socket.write('{"TLS":{"startTLS":"false"}}\r\n');

      await connectExpectation;
      expect(client.isConnected, isFalse);
      expect(client.isTLS, isFalse);
      await messages.cancel();
    });

    test(
      'connect closes the socket when the TLS handshake times out',
      () async {
        final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
        final client = SyncplayClient(
          host: InternetAddress.loopbackIPv4.address,
          port: server.port,
          tlsHandshakeTimeout: const Duration(milliseconds: 200),
        );

        addTearDown(() async {
          await client.disconnect();
          await server.close();
        });

        final connection = server.first;
        final connectFuture = client.connect();
        final connectExpectation = expectLater(
          connectFuture,
          throwsA(
            isA<SyncplayConnectionException>().having(
              (error) => error.message,
              'message',
              contains('timed out'),
            ),
          ),
        );
        final socket = await connection;
        final messages = _socketMessages(socket);
        await _nextMessage(messages);

        await connectExpectation;
        expect(client.isConnected, isFalse);
        expect(client.isTLS, isFalse);
        await messages.cancel();
      },
    );

    test('TLS handshake timeout closes the upgraded TCP connection', () async {
      final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      final client = SyncplayClient(
        host: InternetAddress.loopbackIPv4.address,
        port: server.port,
        tlsHandshakeTimeout: const Duration(seconds: 1),
      );

      addTearDown(() async {
        await client.disconnect();
        await server.close();
      });

      final connection = server.first;
      final connectFuture = client.connect();
      final connectExpectation = expectLater(
        connectFuture,
        throwsA(
          isA<SyncplayConnectionException>().having(
            (error) => error.message,
            'message',
            contains('timed out'),
          ),
        ),
      );
      final socket = await connection;
      final messages = StreamIterator<List<int>>(socket);
      expect(jsonDecode(await _nextRawLine(messages)), {
        'TLS': {'startTLS': 'send'},
      });
      socket.write('{"TLS":{"startTLS":"true"}}\r\n');

      await connectExpectation;
      expect(client.isConnected, isFalse);
      expect(client.isTLS, isFalse);

      var serverSawClose = false;
      var tlsBytes = 0;
      try {
        while (await messages.moveNext().timeout(const Duration(seconds: 2))) {
          tlsBytes += messages.current.length;
        }
        serverSawClose = true;
      } on TimeoutException {
        serverSawClose = false;
      }
      expect(tlsBytes, greaterThan(0));
      expect(serverSawClose, isTrue);
      await messages.cancel();
    });

    test(
      'disconnect prevents a pending TLS upgrade from reviving the client',
      () async {
        final plainServer = await ServerSocket.bind(
          InternetAddress.loopbackIPv4,
          0,
        );
        final upgradedServer = await ServerSocket.bind(
          InternetAddress.loopbackIPv4,
          0,
        );
        final upgradeStarted = Completer<void>();
        final allowUpgrade = Completer<void>();
        final client = SyncplayClient(
          host: InternetAddress.loopbackIPv4.address,
          port: plainServer.port,
          secureSocketUpgrader: (socket, subscription, host) async {
            upgradeStarted.complete();
            await allowUpgrade.future;
            await subscription.cancel();
            await socket.close();
            return RawSocket.connect(
              InternetAddress.loopbackIPv4,
              upgradedServer.port,
            );
          },
        );

        addTearDown(() async {
          await client.disconnect();
          await plainServer.close();
          await upgradedServer.close();
        });

        final plainConnection = plainServer.first;
        final connectFuture = client.connect();
        final plainSocket = await plainConnection;
        final plainMessages = _socketMessages(plainSocket);
        await _nextMessage(plainMessages);
        plainSocket.write('{"TLS":{"startTLS":"true"}}\r\n');
        await upgradeStarted.future;

        final connectExpectation = expectLater(
          connectFuture,
          throwsA(isA<SyncplayConnectionException>()),
        );
        final upgradedConnection = upgradedServer.first;
        await client.disconnect();
        allowUpgrade.complete();
        final upgradedSocket = await upgradedConnection;

        await connectExpectation;
        await Future<void>.delayed(Duration.zero);
        expect(client.isConnected, isFalse);
        expect(client.isTLS, isFalse);

        await plainMessages.cancel();
        await upgradedSocket.close();
      },
    );

    test('a stale TLS failure does not overwrite a newer connection', () async {
      final firstServer = await ServerSocket.bind(
        InternetAddress.loopbackIPv4,
        0,
      );
      final secondServer = await ServerSocket.bind(
        InternetAddress.loopbackIPv4,
        0,
      );
      final upgradedServer = await ServerSocket.bind(
        InternetAddress.loopbackIPv4,
        0,
      );
      final firstUpgradeStarted = Completer<void>();
      final failFirstUpgrade = Completer<void>();
      var connectionCount = 0;
      var upgradeCount = 0;

      final client = SyncplayClient(
        host: InternetAddress.loopbackIPv4.address,
        port: 1,
        socketConnector: (host, port) {
          connectionCount++;
          final target = connectionCount == 1 ? firstServer : secondServer;
          return RawSocket.connect(InternetAddress.loopbackIPv4, target.port);
        },
        secureSocketUpgrader: (socket, subscription, host) async {
          upgradeCount++;
          if (upgradeCount == 1) {
            firstUpgradeStarted.complete();
            await failFirstUpgrade.future;
            throw StateError('stale TLS failure');
          }
          await subscription.cancel();
          await socket.close();
          return RawSocket.connect(
            InternetAddress.loopbackIPv4,
            upgradedServer.port,
          );
        },
      );

      addTearDown(() async {
        await client.disconnect();
        await firstServer.close();
        await secondServer.close();
        await upgradedServer.close();
      });

      final firstConnection = firstServer.first;
      final firstConnect = client.connect();
      final firstSocket = await firstConnection;
      final firstMessages = _socketMessages(firstSocket);
      await _nextMessage(firstMessages);
      firstSocket.write('{"TLS":{"startTLS":"true"}}\r\n');
      await firstUpgradeStarted.future;

      final firstResult = firstConnect.then<Object?>(
        (_) => null,
        onError: (Object error) => error,
      );
      final secondConnection = secondServer.first;
      final secondConnect = client.connect();
      final secondSocket = await secondConnection;
      final secondMessages = _socketMessages(secondSocket);
      await _nextMessage(secondMessages);
      secondSocket.write('{"TLS":{"startTLS":"true"}}\r\n');

      final upgradedConnection = upgradedServer.first;
      final upgradedSocket = await upgradedConnection;
      await secondConnect;
      expect(client.isConnected, isTrue);
      expect(client.isTLS, isTrue);

      failFirstUpgrade.complete();
      expect(await firstResult, isA<SyncplayConnectionException>());
      await Future<void>.delayed(Duration.zero);
      expect(client.isConnected, isTrue);
      expect(client.isTLS, isTrue);

      await firstMessages.cancel();
      await secondMessages.cancel();
      await upgradedSocket.close();
    });
  });
}

StreamIterator<String> _socketMessages(Socket socket) {
  return StreamIterator(
    utf8.decoder.bind(socket).transform(const LineSplitter()),
  );
}

Future<Map<String, dynamic>> _nextMessage(
  StreamIterator<String> messages,
) async {
  if (!await messages.moveNext()) {
    fail('Socket closed before the next Syncplay message');
  }
  return jsonDecode(messages.current) as Map<String, dynamic>;
}

Future<String> _nextRawLine(StreamIterator<List<int>> messages) async {
  final bytes = <int>[];
  while (await messages.moveNext()) {
    bytes.addAll(messages.current);
    for (int i = 0; i + 1 < bytes.length; i++) {
      if (bytes[i] == 13 && bytes[i + 1] == 10) {
        return utf8.decode(bytes.sublist(0, i));
      }
    }
  }
  fail('Socket closed before the next raw line');
}
