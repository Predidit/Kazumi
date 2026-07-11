// https://syncplay.pl/about/protocol/

import 'dart:async';
import 'dart:convert';
import 'dart:io';

const double PING_MOVING_AVERAGE_WEIGHT = 0.85;
const Duration _defaultTLSHandshakeTimeout = Duration(seconds: 10);
const Duration _defaultSocketWriteTimeout = Duration(seconds: 10);

class SyncplayException implements Exception {
  final String message;
  SyncplayException(this.message);

  @override
  String toString() => message;
}

class SyncplayConnectionException extends SyncplayException {
  SyncplayConnectionException(super.message);
}

class SyncplayProtocolException extends SyncplayException {
  SyncplayProtocolException(super.message);
}

abstract class SyncplayMessage {
  Map<String, dynamic> toJson();
}

class HelloMessage extends SyncplayMessage {
  final String username;
  final String version;
  final String room;

  HelloMessage({
    required this.username,
    required this.version,
    required this.room,
  });

  @override
  Map<String, dynamic> toJson() => {
        'Hello': {
          'username': username,
          'room': {
            'name': room,
          },
          'version': version,
          'features': {
            'sharedPlaylists': true,
            'chat': true,
            'featureList': true,
            'readiness': true,
            'managedRooms': false,
          }
        },
      };
}

class StateMessage extends SyncplayMessage {
  final double position;
  final bool paused;
  final bool? doSeek;
  final String? setBy;

  // Syncplay control message.
  final int? clientAck;
  final int? serverAck;

  // latency calculation
  double clientLatencyCalculation;
  double? latencyCalculation;
  final double clientRtt;

  StateMessage({
    required this.position,
    required this.paused,
    this.setBy,
    this.doSeek,
    this.clientAck,
    this.serverAck,
    required this.clientLatencyCalculation,
    this.latencyCalculation,
    this.clientRtt = 0.0,
  });

  @override
  Map<String, dynamic> toJson() => {
        'State': {
          if (clientAck != null || serverAck != null)
            'ignoringOnTheFly': {
              if (clientAck != null) 'client': clientAck,
              if (serverAck != null) 'server': serverAck,
            },
          'ping': {
            'clientRtt': clientRtt,
            'clientLatencyCalculation': clientLatencyCalculation,
            if (latencyCalculation != null)
              'latencyCalculation': latencyCalculation,
          },
          'playstate': {
            'position': position,
            'paused': paused,
            if (setBy != null) 'setBy': setBy,
            'doSeek': doSeek,
          },
        },
      };
}

class SetMessage extends SyncplayMessage {
  final double? duration;
  final String? fileName;
  final String? username;
  final int? size;
  final String? setBy;
  final String? room;
  final bool? setJoined;
  final bool? setReady;

  SetMessage({
    this.duration,
    this.fileName,
    this.username,
    this.size,
    this.setBy,
    this.room,
    this.setJoined,
    this.setReady,
  });

  @override
  Map<String, dynamic> toJson() {
    if (setJoined != null && room != null && username != null) {
      return {
        "Set": {
          room: {
            "room": {"name": room},
            "event": {"joined": true}
          },
        }
      };
    }
    if (setReady != null) {
      return {
        'Set': {
          "ready": {"isReady": true, "manuallyInitiated": false}
        }
      };
    }
    return {
      'Set': {
        if (fileName != null)
          'file': {
            'duration': duration,
            'name': fileName,
            'size': size,
          },
        if (room != null)
          "user": {
            setBy: {
              "room": {"name": room},
            },
          },
      },
    };
  }
}

class ChatMessage extends SyncplayMessage {
  final String message;

  ChatMessage({
    required this.message,
  });

  @override
  Map<String, dynamic> toJson() => {'Chat': message};
}

class TLSMessage extends SyncplayMessage {
  final String message;

  TLSMessage({
    required this.message,
  });

  @override
  Map<String, dynamic> toJson() => {
        'TLS': {
          'startTLS': message,
        },
      };
}

class SyncplayClient {
  final String _host;
  final int _port;
  final Future<RawSocket> Function(String host, int port) _socketConnector;
  final Future<RawSocket> Function(
    RawSocket socket,
    StreamSubscription<RawSocketEvent> subscription,
    String host,
  ) _secureSocketUpgrader;
  final Duration _tlsHandshakeTimeout;
  final Duration _socketWriteTimeout;
  bool _isTLS = false;
  RawSocket? _socket;
  // Retained across STARTTLS so a stalled RawSecureSocket can be force-closed.
  RawSocket? _transportSocket;
  RawSocket? _tlsUpgradeSocket;
  StreamSubscription<RawSocketEvent>? _socketSubscription;
  Completer<void>? _tlsHandshakeCompleter;
  final List<int> _pendingWrites = [];
  Completer<void>? _pendingWriteCompleter;
  Timer? _pendingWriteTimer;
  RawSocket? _pendingWriteSocket;
  int? _pendingWriteGeneration;
  int _connectionGeneration = 0;
  int? _tlsHandshakeGeneration;
  String? _username;
  String? _currentRoom;
  String? _currentFileName;
  double _currentPositon = 0.0;
  bool _isPaused = true;
  StreamController<Map<String, dynamic>>? _generalMessageController =
      StreamController.broadcast();
  StreamController<Map<String, dynamic>>? _roomMessageController =
      StreamController.broadcast();
  StreamController<Map<String, dynamic>>? _chatMessageController =
      StreamController.broadcast();
  StreamController<Map<String, dynamic>>? _flieChangedMessageController =
      StreamController.broadcast();
  StreamController<Map<String, dynamic>>? _positionChangedMessageController =
      StreamController.broadcast();
  double? _lastLatencyCalculation;

  // Network status
  double _clientRtt = 0.0;
  double _serverRtt = 0.0;
  double _avrRtt = 0.0;
  double _fd = 0.0;

  // IgnoringOnTheFly
  int _clientIgnoringOnTheFly = 0;
  int _serverIgnoringOnTheFly = 0;

  bool get isConnected =>
      _socket != null && (_tlsHandshakeGeneration == null || _isTLS);
  bool get isTLS => _isTLS;
  String? get username => _username;
  String? get currentRoom => _currentRoom;
  String? get currentFileName => _currentFileName;
  double get clientRtt => _clientRtt;
  double get serverRtt => _serverRtt;
  double get avgRtt => _avrRtt;
  double get fd => _fd;

  Stream<Map<String, dynamic>> get onGeneralMessage {
    _generalMessageController ??= StreamController.broadcast();
    return _generalMessageController!.stream;
  }

  Stream<Map<String, dynamic>> get onRoomMessage {
    _roomMessageController ??= StreamController.broadcast();
    return _roomMessageController!.stream;
  }

  Stream<Map<String, dynamic>> get onChatMessage {
    _chatMessageController ??= StreamController.broadcast();
    return _chatMessageController!.stream;
  }

  Stream<Map<String, dynamic>> get onFileChangedMessage {
    _flieChangedMessageController ??= StreamController.broadcast();
    return _flieChangedMessageController!.stream;
  }

  Stream<Map<String, dynamic>> get onPositionChangedMessage {
    _positionChangedMessageController ??= StreamController.broadcast();
    return _positionChangedMessageController!.stream;
  }

  SyncplayClient({
    required String host,
    required int port,
    Future<RawSocket> Function(String host, int port)? socketConnector,
    Future<RawSocket> Function(
      RawSocket socket,
      StreamSubscription<RawSocketEvent> subscription,
      String host,
    )? secureSocketUpgrader,
    Duration tlsHandshakeTimeout = _defaultTLSHandshakeTimeout,
    Duration socketWriteTimeout = _defaultSocketWriteTimeout,
  })  : _host = host,
        _port = port,
        _socketConnector =
            socketConnector ?? ((host, port) => RawSocket.connect(host, port)),
        _secureSocketUpgrader = secureSocketUpgrader ??
            ((socket, subscription, host) => RawSecureSocket.secure(
                  socket,
                  subscription: subscription,
                  host: host,
                )),
        _tlsHandshakeTimeout = tlsHandshakeTimeout,
        _socketWriteTimeout = socketWriteTimeout;

  Future<void> connect({bool enableTLS = true}) async {
    final generation = ++_connectionGeneration;
    final supersededException =
        SyncplayConnectionException('SyncPlay: connection superseded');
    _completeTLSHandshakeError(supersededException);
    _ensureMessageControllers();
    try {
      await _closeSockets(pendingWriteError: supersededException);
      _isTLS = false;
      print('SyncPlay: connecting to Syncplay server: $_host:$_port');
      final socket = await _socketConnector(_host, _port);
      if (generation != _connectionGeneration) {
        await _forceCloseSocket(socket);
        throw SyncplayConnectionException('SyncPlay: connection superseded');
      }
      _socket = socket;
      _transportSocket = socket;
      print('SyncPlay: connected to Syncplay server: $_host:$_port');
      _setupSocketHandlers(socket, generation);
      if (enableTLS) {
        final handshakeCompleter = Completer<void>();
        _tlsHandshakeCompleter = handshakeCompleter;
        _tlsHandshakeGeneration = generation;
        try {
          await Future.wait<void>(
            [
              requestTLS(),
              handshakeCompleter.future,
            ],
            eagerError: true,
          ).timeout(_tlsHandshakeTimeout);
          if (generation != _connectionGeneration) {
            throw SyncplayConnectionException(
              'SyncPlay: connection superseded',
            );
          }
          if (_socket == null || !_isTLS) {
            throw SyncplayConnectionException(
              'SyncPlay: TLS connection closed during upgrade',
            );
          }
        } on TimeoutException {
          throw SyncplayConnectionException(
            'SyncPlay: TLS connection upgrade timed out',
          );
        } finally {
          if (identical(_tlsHandshakeCompleter, handshakeCompleter)) {
            _tlsHandshakeCompleter = null;
            _tlsHandshakeGeneration = null;
          }
        }
      }
    } catch (error, stackTrace) {
      if (generation == _connectionGeneration) {
        await _closeSockets(
          pendingWriteError: error,
          stackTrace: stackTrace,
        );
        _isTLS = false;
      }
      if (error is SyncplayException) {
        Error.throwWithStackTrace(error, stackTrace);
      }
      if (error is SocketException) {
        Error.throwWithStackTrace(
          SyncplayConnectionException(
            'SyncPlay: connection failed: ${error.message}',
          ),
          stackTrace,
        );
      }
      Error.throwWithStackTrace(
        SyncplayConnectionException('SyncPlay: connection failed: $error'),
        stackTrace,
      );
    }
  }

  Future<void> requestTLS() async {
    if (_socket == null) {
      throw SyncplayConnectionException(
        'SyncPlay: cannot request TLS before connecting',
      );
    }
    print('SyncPlay: requesting TLS connection upgrade');
    await _sendMessage(TLSMessage(message: 'send'));
  }

  Future<void> joinRoom(String room, String username) async {
    print('SyncPlay: joining room: $room as $username');
    await _sendMessage(HelloMessage(
      username: username,
      version: '1.7.0',
      room: room,
    ));
  }

  Future<void> sendChatMessage(String message) async {
    if (_currentRoom == null || _username == null) {
      _generalMessageController?.addError(
        SyncplayProtocolException(
            'SyncPlay: send chat message failed, not in a room'),
      );
      return;
    }
    await _sendMessage(ChatMessage(
      message: message,
    ));
  }

  Future<void> setSyncPlayPlaying(
      String bangumiName, double duration, int size) async {
    if (_currentRoom == null || _username == null) {
      _generalMessageController?.addError(
        SyncplayProtocolException(
            'SyncPlay: set playing bangumi failed, not in a room'),
      );
      return;
    }
    await _sendMessage(SetMessage(
        duration: duration,
        fileName: bangumiName,
        size: size,
        setBy: _username ?? '',
        room: _currentRoom ?? ''));
  }

  Future<void> sendSyncPlaySyncRequest({bool? doSeek}) async {
    await _sendState(
      position: _currentPositon,
      paused: _isPaused,
      doSeek: doSeek,
      stateChange: true,
    );
  }

  Future<void> disconnect() async {
    print('SyncPlay: disconnecting from Syncplay server: $_host:$_port');
    _connectionGeneration++;
    final exception =
        SyncplayConnectionException('SyncPlay: connection closed');
    _completeTLSHandshakeError(exception);
    await _closeSockets(pendingWriteError: exception);
    _isTLS = false;
    await _generalMessageController?.close();
    _generalMessageController = null;
    await _roomMessageController?.close();
    _roomMessageController = null;
    await _chatMessageController?.close();
    _chatMessageController = null;
    await _flieChangedMessageController?.close();
    _flieChangedMessageController = null;
    await _positionChangedMessageController?.close();
    _positionChangedMessageController = null;
    _currentRoom = null;
    _username = null;
    _currentFileName = null;
    _currentPositon = 0.0;
    _isPaused = true;
    _isTLS = false;
    _lastLatencyCalculation = null;
    _clientIgnoringOnTheFly = 0;
    _serverIgnoringOnTheFly = 0;
    _clientRtt = 0.0;
    _serverRtt = 0.0;
    _avrRtt = 0.0;
    _fd = 0.0;
  }

  void setPosition(double position) {
    _currentPositon = position;
  }

  void setPaused(bool paused) {
    _isPaused = paused;
  }

  Future<void> _closeSockets({
    Object? pendingWriteError,
    StackTrace? stackTrace,
  }) async {
    final socket = _socket;
    final transportSocket = _transportSocket;
    final upgradeSocket = _tlsUpgradeSocket;
    final subscription = _socketSubscription;
    _socket = null;
    _transportSocket = null;
    _tlsUpgradeSocket = null;
    _socketSubscription = null;
    _isTLS = false;
    _failPendingWrites(
      pendingWriteError ??
          SyncplayConnectionException('SyncPlay: connection closed'),
      stackTrace,
    );
    try {
      await subscription?.cancel();
    } catch (_) {}

    // RawSecureSocket.close() can wait for buffered TLS writes indefinitely.
    // Closing its retained transport is the force-close path in that case.
    final sockets = <RawSocket>[];
    for (final candidate in <RawSocket?>[
      transportSocket,
      upgradeSocket,
      if (socket is! RawSecureSocket ||
          transportSocket == null ||
          identical(socket, transportSocket))
        socket,
    ]) {
      if (candidate != null &&
          !sockets.any((existing) => identical(existing, candidate))) {
        sockets.add(candidate);
      }
    }
    await Future.wait(sockets.map(_forceCloseSocket));
  }

  Future<void> _forceCloseSocket(RawSocket socket) async {
    try {
      socket.shutdown(SocketDirection.both);
    } catch (_) {}
    try {
      await socket.close();
    } catch (_) {}
  }

  void _ensureMessageControllers() {
    if (_generalMessageController?.isClosed ?? true) {
      _generalMessageController = StreamController.broadcast();
    }
    if (_roomMessageController?.isClosed ?? true) {
      _roomMessageController = StreamController.broadcast();
    }
    if (_chatMessageController?.isClosed ?? true) {
      _chatMessageController = StreamController.broadcast();
    }
    if (_flieChangedMessageController?.isClosed ?? true) {
      _flieChangedMessageController = StreamController.broadcast();
    }
    if (_positionChangedMessageController?.isClosed ?? true) {
      _positionChangedMessageController = StreamController.broadcast();
    }
  }

  void _setupSocketHandlers(RawSocket socket, int generation) {
    String buffer = '';

    _socketSubscription = socket.listen(
      (event) {
        if (generation != _connectionGeneration ||
            !identical(socket, _socket)) {
          return;
        }
        if (event == RawSocketEvent.write) {
          _flushPendingWrites(socket, generation);
          return;
        }
        if (event == RawSocketEvent.readClosed ||
            event == RawSocketEvent.closed) {
          _handleSocketClosed(socket, generation);
          return;
        }
        if (event == RawSocketEvent.read) {
          while (true) {
            final data = socket.read();
            if (data == null || data.isEmpty) {
              break;
            }
            buffer += utf8.decode(data);
            while (true) {
              final startIndex = buffer.indexOf('{');
              if (startIndex == -1) {
                break;
              }

              int braceCount = 0;
              int? endIndex;
              for (int i = startIndex; i < buffer.length; i++) {
                if (buffer[i] == '{') {
                  braceCount++;
                } else if (buffer[i] == '}') {
                  braceCount--;
                  if (braceCount == 0) {
                    endIndex = i;
                    break;
                  }
                }
              }
              if (endIndex == null) break;

              final jsonStr = buffer.substring(startIndex, endIndex + 1);
              try {
                // print(
                //     'SyncPlay: [${DateTime.now().millisecondsSinceEpoch / 1000.0}] received message: $jsonStr');
                _handleMessage(json.decode(jsonStr), socket, generation);
              } catch (e) {
                _generalMessageController?.addError(
                  SyncplayProtocolException(
                      'SyncPlay: received data parse failed: $e'),
                );
              }
              buffer = buffer.substring(endIndex + 1);
              if (!identical(socket, _socket)) {
                return;
              }
            }
          }
        }
      },
      onError: (error, stackTrace) =>
          _handleSocketError(socket, generation, error, stackTrace),
      onDone: () => _handleSocketClosed(socket, generation),
    );
    socket.readEventsEnabled = true;
    _flushPendingWrites(socket, generation);
  }

  void _handleSocketError(
    RawSocket socket,
    int generation,
    Object error,
    StackTrace stackTrace,
  ) {
    if (generation != _connectionGeneration ||
        !identical(socket, _socket)) {
      return;
    }
    final exception = SyncplayConnectionException(
      'SyncPlay: socket error: $error',
    );
    _failCurrentSocket(socket, generation, exception, stackTrace);
  }

  void _handleSocketClosed(RawSocket socket, int generation) {
    if (generation != _connectionGeneration ||
        !identical(socket, _socket)) {
      return;
    }
    final exception = SyncplayConnectionException(
      'SyncPlay: connection closed',
    );
    _failCurrentSocket(socket, generation, exception);
  }

  void _failCurrentSocket(
    RawSocket socket,
    int generation,
    SyncplayConnectionException exception, [
    StackTrace? stackTrace,
  ]) {
    if (generation != _connectionGeneration ||
        !identical(socket, _socket)) {
      return;
    }
    final handshakePending = _tlsHandshakeGeneration == generation;
    final closeFuture = _closeSockets(
      pendingWriteError: exception,
      stackTrace: stackTrace,
    );
    _completeTLSHandshakeError(exception, stackTrace, generation);
    if (!handshakePending) {
      _generalMessageController?.addError(exception, stackTrace);
    }
    unawaited(closeFuture);
  }

  void _handleMessage(dynamic data, RawSocket sourceSocket, int generation) {
    final json = data as Map<String, dynamic>;
    if (json.containsKey('TLS')) {
      final tlsData = json['TLS'];
      if (tlsData is! Map || !tlsData.containsKey('startTLS')) {
        _completeTLSHandshakeError(
          SyncplayProtocolException('SyncPlay: invalid TLS response'),
          null,
          generation,
        );
      } else if (tlsData['startTLS'] == 'true') {
        unawaited(_upgradeToTLS(sourceSocket, generation));
      } else {
        _completeTLSHandshakeError(
          SyncplayConnectionException(
            'SyncPlay: server rejected TLS connection upgrade',
          ),
          null,
          generation,
        );
      }
      return;
    }
    if (json.containsKey('Hello')) {
      if (json['Hello'].containsKey('room') &&
          json['Hello']['room'].containsKey('name')) {
        _username = json['Hello']['username'];
        _currentRoom = json['Hello']['room']['name'];
        print(
            'SyncPlay: joined room: $_currentRoom as $_username, version: ${json['Hello']['version']}');
        _runInBackground(_setReady());
      }
      _generalMessageController?.add({
        'username': json['Hello']['username'],
        'room': json['Hello']['room']['name'],
      });
      return;
    }
    if (json.containsKey('State')) {
      if (json['State'].containsKey('ping')) {
        _lastLatencyCalculation =
            json['State']['ping']['latencyCalculation']?.toDouble();
        if (json['State']['ping'].containsKey('serverRtt')) {
          _serverRtt = json['State']['ping']['serverRtt']?.toDouble() ?? 0.0;
        }
        _updateClientRttAndFd(
            json['State']["ping"]["clientLatencyCalculation"], _serverRtt);
      }
      if (json['State'].containsKey('ignoringOnTheFly')) {
        var ignoringOnTheFly = json['State']['ignoringOnTheFly'];
        if (ignoringOnTheFly.containsKey('server')) {
          _serverIgnoringOnTheFly = ignoringOnTheFly['server'];
          _clientIgnoringOnTheFly = 0;
        } else if (ignoringOnTheFly.containsKey('client')) {
          if (ignoringOnTheFly['client'] == _clientIgnoringOnTheFly) {
            _clientIgnoringOnTheFly = 0;
          }
        }
      }
      if (_clientIgnoringOnTheFly == 0) {
        _currentPositon = (json['State']['playstate']['paused'] ?? true)
            ? (json['State']['playstate']['position']?.toDouble() ?? 0.0)
            : ((json['State']['playstate']['position']?.toDouble() ?? 0.0) +
                _fd);
        _isPaused = json['State']['playstate']['paused'] ?? true;
        _positionChangedMessageController?.add({
          'calculatedPositon': (json['State']['playstate']['paused'] ?? true)
              ? (json['State']['playstate']['position']?.toDouble() ?? 0.0)
              : ((json['State']['playstate']['position']?.toDouble() ?? 0.0) +
                  _fd),
          'position': json['State']['playstate']['position']?.toDouble() ?? 0.0,
          'paused': json['State']['playstate']['paused'] ?? true,
          'doSeek': json['State']['playstate']['doSeek'] ?? false,
          'setBy': json['State']['playstate']['setBy'] ?? '',
          'clientRtt': _clientRtt,
          'serverRtt': _serverRtt,
          'avrRtt': _avrRtt,
          'fd': _fd,
        });
      }
      _runInBackground(
        _sendState(
          position: _currentPositon,
          paused: _isPaused,
        ),
      );
      return;
    }
    if (json.containsKey('Set')) {
      if (json['Set'].containsKey('playlistIndex')) {
        _roomMessageController?.add({
          'type': 'init',
          'username': json['Set']['playlistIndex']['user'] ?? '',
        });
        return;
      }
      if (json['Set'].containsKey('user')) {
        Map<String, dynamic> userMap = data['Set']['user'];
        userMap.forEach((username, details) {
          if (!details.containsKey('event')) {
            return;
          }
          var event = details['event'].keys.first ?? 'unknown';
          _roomMessageController?.add({
            'type': event,
            'username': username,
          });
        });
        for (var username in userMap.keys) {
          var userData = userMap[username];
          if (userData is Map && userData.containsKey('file')) {
            var fileData = userData['file'];
            var fileName = fileData['name'];
            _currentFileName = fileName;
            _flieChangedMessageController?.add({
              'name': fileName,
              'setBy': username,
            });
          }
        }
      }
      return;
    }
    if (json.containsKey('Chat')) {
      if (json['Chat'].containsKey('message') &&
          json['Chat'].containsKey('username')) {
        _chatMessageController?.add({
          'message': json['Chat']['message'],
          'username': json['Chat']['username'],
        });
      }
      return;
    }
    _generalMessageController?.addError(
      SyncplayProtocolException('SyncPlay: unknown message type'),
    );
  }

  Future<void> _upgradeToTLS(RawSocket plainSocket, int generation) async {
    if (generation != _connectionGeneration ||
        !identical(plainSocket, _socket)) {
      return;
    }
    final subscription = _socketSubscription;
    if (subscription == null) {
      _completeTLSHandshakeError(
        SyncplayConnectionException(
          'SyncPlay: TLS connection upgrade lost its socket subscription',
        ),
        null,
        generation,
      );
      return;
    }
    _socketSubscription = null;
    _socket = null;
    _tlsUpgradeSocket = plainSocket;
    try {
      final secureSocket =
          await _secureSocketUpgrader(plainSocket, subscription, _host);
      if (generation != _connectionGeneration ||
          !identical(_tlsUpgradeSocket, plainSocket)) {
        await _forceCloseSocket(secureSocket);
        return;
      }
      _tlsUpgradeSocket = null;
      _socket = secureSocket;
      _isTLS = true;
      _setupSocketHandlers(secureSocket, generation);
      print('SyncPlay: TLS connection established');
      final handshakeCompleter = _tlsHandshakeCompleter;
      if (handshakeCompleter != null && !handshakeCompleter.isCompleted) {
        handshakeCompleter.complete();
      }
    } catch (error, stackTrace) {
      await _forceCloseSocket(plainSocket);
      if (generation != _connectionGeneration ||
          !identical(_tlsUpgradeSocket, plainSocket)) {
        return;
      }
      _tlsUpgradeSocket = null;
      if (identical(_transportSocket, plainSocket)) {
        _transportSocket = null;
      }
      _isTLS = false;
      final exception = SyncplayConnectionException(
        'SyncPlay: TLS connection upgrade failed: $error',
      );
      print(exception.message);
      _completeTLSHandshakeError(exception, stackTrace, generation);
    }
  }

  void _completeTLSHandshakeError(
    Object error, [
    StackTrace? stackTrace,
    int? generation,
  ]) {
    if (generation != null && generation != _tlsHandshakeGeneration) {
      return;
    }
    final handshakeCompleter = _tlsHandshakeCompleter;
    if (handshakeCompleter == null || handshakeCompleter.isCompleted) {
      return;
    }
    handshakeCompleter.completeError(error, stackTrace ?? StackTrace.current);
  }

  Future<void> _setReady() async {
    if (_currentRoom == null || _username == null) {
      _generalMessageController?.addError(
        SyncplayProtocolException('SyncPlay: set ready failed, not in a room'),
      );
      return;
    }
    await _sendMessage(
      SetMessage(
        setJoined: true,
        username: _username,
        room: _currentRoom,
      ),
    );
    await _sendMessage(
      SetMessage(
        setReady: true,
      ),
    );
  }

  Future<void> _sendMessage(SyncplayMessage message) async {
    final socket = _socket;
    if (socket == null) {
      final exception =
          SyncplayConnectionException('SyncPlay: not connected to server');
      _generalMessageController?.addError(exception);
      throw exception;
    }
    final generation = _connectionGeneration;
    final json = message.toJson();
    final jsonStr = jsonEncode(json);
    // print(
    //     'SyncPlay: [${DateTime.now().millisecondsSinceEpoch / 1000.0}] sending message: $jsonStr');
    _pendingWrites.addAll(utf8.encode('$jsonStr\r\n'));
    var completer = _pendingWriteCompleter;
    if (completer == null) {
      completer = Completer<void>();
      _pendingWriteCompleter = completer;
      _pendingWriteSocket = socket;
      _pendingWriteGeneration = generation;
      _restartPendingWriteTimer(socket, generation, completer);
    }
    _flushPendingWrites(socket, generation);
    await completer.future;
  }

  void _flushPendingWrites(RawSocket socket, int generation) {
    if (generation != _connectionGeneration ||
        !identical(socket, _socket)) {
      return;
    }
    final completer = _pendingWriteCompleter;
    if (completer == null) {
      socket.writeEventsEnabled = false;
      return;
    }
    var madeProgress = false;
    try {
      while (_pendingWrites.isNotEmpty) {
        final written = socket.write(_pendingWrites);
        if (written <= 0) {
          if (madeProgress) {
            _restartPendingWriteTimer(socket, generation, completer);
          }
          socket.writeEventsEnabled = true;
          return;
        }
        _pendingWrites.removeRange(0, written);
        madeProgress = true;
      }
      socket.writeEventsEnabled = false;
      _completePendingWrites();
    } catch (error, stackTrace) {
      final exception = SyncplayConnectionException(
        'SyncPlay: socket write failed: $error',
      );
      _failCurrentSocket(socket, generation, exception, stackTrace);
    }
  }

  void _restartPendingWriteTimer(
    RawSocket socket,
    int generation,
    Completer<void> completer,
  ) {
    _pendingWriteTimer?.cancel();
    _pendingWriteTimer = Timer(_socketWriteTimeout, () {
      if (generation != _connectionGeneration ||
          !identical(socket, _socket) ||
          !identical(socket, _pendingWriteSocket) ||
          generation != _pendingWriteGeneration ||
          !identical(completer, _pendingWriteCompleter) ||
          _pendingWrites.isEmpty) {
        return;
      }
      _failCurrentSocket(
        socket,
        generation,
        SyncplayConnectionException('SyncPlay: socket write timed out'),
        StackTrace.current,
      );
    });
  }

  void _completePendingWrites() {
    final completer = _pendingWriteCompleter;
    _clearPendingWriteState();
    if (completer != null && !completer.isCompleted) {
      completer.complete();
    }
  }

  void _failPendingWrites(Object error, [StackTrace? stackTrace]) {
    _pendingWrites.clear();
    final completer = _pendingWriteCompleter;
    _clearPendingWriteState();
    if (completer != null && !completer.isCompleted) {
      completer.completeError(error, stackTrace ?? StackTrace.current);
    }
  }

  void _clearPendingWriteState() {
    _pendingWriteTimer?.cancel();
    _pendingWriteTimer = null;
    _pendingWriteCompleter = null;
    _pendingWriteSocket = null;
    _pendingWriteGeneration = null;
  }

  Future<void> _sendState(
      {double? position,
      bool? paused,
      bool? doSeek,
      bool stateChange = false}) {
    int? clientArck;
    int? serverAck;
    if (stateChange) {
      _clientIgnoringOnTheFly = _clientIgnoringOnTheFly + 1;
    }
    if (_serverIgnoringOnTheFly > 0) {
      serverAck = _serverIgnoringOnTheFly;
      _serverIgnoringOnTheFly = 0;
    }
    if (_clientIgnoringOnTheFly > 0) {
      clientArck = _clientIgnoringOnTheFly;
    }
    return _sendMessage(StateMessage(
      position: position ?? _currentPositon,
      paused: paused ?? _isPaused,
      latencyCalculation: _lastLatencyCalculation,
      clientLatencyCalculation: DateTime.now().millisecondsSinceEpoch / 1000.0,
      clientRtt: _clientRtt,
      setBy: _username,
      clientAck: clientArck,
      serverAck: serverAck,
      doSeek: doSeek,
    ));
  }

  void _runInBackground(Future<void> future) {
    unawaited(
      future.then<void>(
        (_) {},
        onError: (Object _, StackTrace __) {},
      ),
    );
  }

  void _updateClientRttAndFd(double? timestamp, double senderRtt) {
    if (timestamp == null) return;

    // Calculate RTT: current time minus the passed timestamp
    double newClientRtt =
        DateTime.now().millisecondsSinceEpoch / 1000.0 - timestamp;

    // If the new RTT is less than 0, it means the server is not responding
    if (newClientRtt < 0 || senderRtt < 0) return;
    _clientRtt = newClientRtt;

    // If it's the first time calculating, initialize the average RTT
    if (_avrRtt == 0) {
      _avrRtt = _clientRtt;
    }

    // Use moving average to update RTT, smooth the delay data
    _avrRtt = _avrRtt * PING_MOVING_AVERAGE_WEIGHT +
        _clientRtt * (1 - PING_MOVING_AVERAGE_WEIGHT);

    // Calculate the forward delay based on the sender's RTT
    if (senderRtt < _clientRtt) {
      _fd = _avrRtt / 2 + (_clientRtt - senderRtt);
    } else {
      _fd = _avrRtt / 2;
    }
  }
}
