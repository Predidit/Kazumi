import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

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

    test('connect may only be called once per client', () async {
      final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      final client = SyncplayClient(
        host: InternetAddress.loopbackIPv4.address,
        port: server.port,
      );

      addTearDown(() async {
        await client.disconnect();
        await server.close();
      });

      await client.connect(enableTLS: false);
      await expectLater(client.connect(enableTLS: false), throwsStateError);

      await client.disconnect();
      await expectLater(client.connect(enableTLS: false), throwsStateError);
      expect(client.isConnected, isFalse);
    });
  });

  group('SyncplayClient socket writes', () {
    test('TLS deadline includes a stalled STARTTLS write', () async {
      final socket = _FakeRawSocket(stallWrites: true);
      final client = SyncplayClient(
        host: 'syncplay.test',
        port: 8995,
        socketConnector: (host, port) async => socket,
        tlsHandshakeTimeout: const Duration(milliseconds: 50),
        socketWriteTimeout: const Duration(seconds: 5),
      );

      addTearDown(() async {
        await client.disconnect();
        await socket.dispose();
      });

      await expectLater(
        client.connect(),
        throwsA(
          isA<SyncplayConnectionException>().having(
            (error) => error.message,
            'message',
            contains('TLS connection upgrade timed out'),
          ),
        ),
      );

      expect(socket.writeCalls, greaterThan(0));
      expect(socket.closeCalls, 1);
      expect(client.isConnected, isFalse);
    });

    test('a stalled write times out and closes the connection', () async {
      final socket = _FakeRawSocket(stallWrites: true);
      final client = SyncplayClient(
        host: 'syncplay.test',
        port: 8995,
        socketConnector: (host, port) async => socket,
        socketWriteTimeout: const Duration(milliseconds: 50),
      );
      final streamError = Completer<Object>();
      final subscription = client.onGeneralMessage.listen(
        (_) {},
        onError: (Object error) {
          if (!streamError.isCompleted) {
            streamError.complete(error);
          }
        },
      );

      addTearDown(() async {
        await subscription.cancel();
        await client.disconnect();
        await socket.dispose();
      });

      await client.connect(enableTLS: false);
      await expectLater(
        client.joinRoom('stalled-room', 'Tester'),
        throwsA(
          isA<SyncplayConnectionException>().having(
            (error) => error.message,
            'message',
            contains('socket write timed out'),
          ),
        ),
      );

      expect(await streamError.future, isA<SyncplayConnectionException>());
      await socket.closeStarted.future;
      expect(socket.closeCalls, 1);
      expect(client.isConnected, isFalse);
    });

    test('sync request surfaces a write timeout to its caller', () async {
      final socket = _FakeRawSocket(stallWrites: true);
      final client = SyncplayClient(
        host: 'syncplay.test',
        port: 8995,
        socketConnector: (host, port) async => socket,
        socketWriteTimeout: const Duration(milliseconds: 50),
      );
      final streamError = Completer<Object>();
      final subscription = client.onGeneralMessage.listen(
        (_) {},
        onError: (Object error) {
          if (!streamError.isCompleted) {
            streamError.complete(error);
          }
        },
      );

      addTearDown(() async {
        await subscription.cancel();
        await client.disconnect();
        await socket.dispose();
      });

      await client.connect(enableTLS: false);
      await expectLater(
        client.sendSyncPlaySyncRequest(doSeek: true),
        throwsA(
          isA<SyncplayConnectionException>().having(
            (error) => error.message,
            'message',
            contains('socket write timed out'),
          ),
        ),
      );

      expect(
        await streamError.future.timeout(const Duration(seconds: 1)),
        isA<SyncplayConnectionException>().having(
          (error) => error.message,
          'message',
          contains('socket write timed out'),
        ),
      );
      await socket.closeStarted.future;
      expect(client.isConnected, isFalse);
    });

    test(
      'socket close fails a pending write instead of completing it',
      () async {
        final socket = _FakeRawSocket(stallWrites: true);
        final client = SyncplayClient(
          host: 'syncplay.test',
          port: 8995,
          socketConnector: (host, port) async => socket,
          socketWriteTimeout: const Duration(seconds: 5),
        );

        addTearDown(() async {
          await client.disconnect();
          await socket.dispose();
        });

        await client.connect(enableTLS: false);
        final sendExpectation = expectLater(
          client.joinRoom('closing-room', 'Tester'),
          throwsA(
            isA<SyncplayConnectionException>().having(
              (error) => error.message,
              'message',
              contains('connection closed'),
            ),
          ),
        );
        socket.emit(RawSocketEvent.closed);

        await sendExpectation;
        await socket.closeStarted.future;
        expect(socket.closeCalls, 1);
        expect(client.isConnected, isFalse);
      },
    );

    test(
      'disconnect awaits subscription cancellation before closing',
      () async {
        final operations = <String>[];
        final cancelStarted = Completer<void>();
        final allowCancel = Completer<void>();
        final socket = _FakeRawSocket(
          operations: operations,
          onCancel: () async {
            operations.add('cancel');
            cancelStarted.complete();
            await allowCancel.future;
          },
        );
        final client = SyncplayClient(
          host: 'syncplay.test',
          port: 8995,
          socketConnector: (host, port) async => socket,
        );

        addTearDown(() async {
          if (!allowCancel.isCompleted) {
            allowCancel.complete();
          }
          await client.disconnect();
          await socket.dispose();
        });

        await client.connect(enableTLS: false);
        final disconnectFuture = client.disconnect();
        await cancelStarted.future;

        expect(operations, ['cancel']);
        expect(socket.closeCalls, 0);

        allowCancel.complete();
        await disconnectFuture;
        expect(operations, ['cancel', 'close']);
        expect(socket.closeCalls, 1);
      },
    );
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

class _FakeRawSocket extends Stream<RawSocketEvent> implements RawSocket {
  _FakeRawSocket({
    this.stallWrites = false,
    this.operations,
    FutureOr<void> Function()? onCancel,
  }) {
    _events = StreamController<RawSocketEvent>(onCancel: onCancel);
  }

  final bool stallWrites;
  final List<String>? operations;
  late final StreamController<RawSocketEvent> _events;
  final List<Uint8List> _readBuffers = [];
  final List<int> writtenBytes = [];
  final Completer<void> closeStarted = Completer<void>();
  int writeCalls = 0;
  int closeCalls = 0;

  @override
  bool readEventsEnabled = false;

  @override
  bool writeEventsEnabled = false;

  void emit(RawSocketEvent event) {
    _events.add(event);
  }

  void emitData(String data) {
    _readBuffers.add(Uint8List.fromList(utf8.encode(data)));
    emit(RawSocketEvent.read);
  }

  Future<void> dispose() async {
    if (!_events.isClosed) {
      await _events.close();
    }
  }

  @override
  int write(List<int> buffer, [int offset = 0, int? count]) {
    writeCalls++;
    if (stallWrites) {
      return 0;
    }
    final bytesToWrite = count ?? buffer.length - offset;
    writtenBytes.addAll(buffer.getRange(offset, offset + bytesToWrite));
    return bytesToWrite;
  }

  @override
  Uint8List? read([int? len]) {
    return _readBuffers.isEmpty ? null : _readBuffers.removeAt(0);
  }

  @override
  Future<RawSocket> close() async {
    closeCalls++;
    if (!closeStarted.isCompleted) {
      closeStarted.complete();
    }
    operations?.add('close');
    return this;
  }

  @override
  StreamSubscription<RawSocketEvent> listen(
    void Function(RawSocketEvent event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return _events.stream.listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
