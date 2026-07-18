// https://syncplay.pl/about/protocol/

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:kazumi/services/logging/logger.dart';

const double pingMovingAverageWeight = 0.85;
const Duration _tlsHandshakeTimeout = Duration(seconds: 10);
const Duration _socketWriteTimeout = Duration(seconds: 10);

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

/// Single-use connection to a Syncplay server: [connect] may be called once,
/// and [disconnect] permanently closes the client. Callers create a new
/// instance for every connection attempt.
class SyncplayClient {
  final String _host;
  final int _port;
  bool _connectCalled = false;
  bool _closed = false;
  bool _isTLS = false;
  RawSocket? _socket;
  // Retained across STARTTLS so a stalled RawSecureSocket can be force-closed.
  RawSocket? _transportSocket;
  StreamSubscription<RawSocketEvent>? _socketSubscription;
  Completer<void>? _tlsHandshakeCompleter;
  final List<int> _pendingWrites = [];
  Completer<void>? _pendingWriteCompleter;
  Timer? _pendingWriteTimer;
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
      !_closed && _socket != null && (_tlsHandshakeCompleter == null || _isTLS);
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

  SyncplayClient({required String host, required int port})
      : _host = host,
        _port = port;

  Future<void> connect({bool enableTLS = true}) async {
    if (_closed) {
      throw StateError('SyncplayClient cannot connect after disconnect');
    }
    if (_connectCalled) {
      throw StateError('SyncplayClient.connect may only be called once');
    }
    _connectCalled = true;
    try {
      KazumiLogger().d('SyncPlay: opening server connection');
      final socket = await RawSocket.connect(_host, _port);
      if (_closed) {
        await _forceCloseSocket(socket);
        throw SyncplayConnectionException('SyncPlay: connection closed');
      }
      _socket = socket;
      _transportSocket = socket;
      KazumiLogger().d('SyncPlay: server connection established');
      _setupSocketHandlers(socket);
      if (enableTLS) {
        final handshakeCompleter = Completer<void>();
        _tlsHandshakeCompleter = handshakeCompleter;
        try {
          await Future.wait<void>(
            [
              requestTLS(),
              handshakeCompleter.future,
            ],
            eagerError: true,
          ).timeout(_tlsHandshakeTimeout);
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
          _tlsHandshakeCompleter = null;
        }
      }
    } catch (error, stackTrace) {
      if (!_closed) {
        await _closeSockets(
          pendingWriteError: error,
          stackTrace: stackTrace,
        );
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
    KazumiLogger().d('SyncPlay: requesting TLS connection upgrade');
    await _sendMessage(TLSMessage(message: 'send'));
  }

  Future<void> joinRoom(String room, String username) async {
    KazumiLogger().d('SyncPlay: sending room join request');
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

  Future<void> sendSyncPlaySyncRequest({bool? doSeek}) {
    return _sendState(
      position: _currentPositon,
      paused: _isPaused,
      doSeek: doSeek,
      stateChange: true,
    );
  }

  Future<void> disconnect() async {
    if (_closed) {
      return;
    }
    _closed = true;
    KazumiLogger().d('SyncPlay: disconnecting from server');
    final exception =
        SyncplayConnectionException('SyncPlay: connection closed');
    _completeTLSHandshakeError(exception);
    await _closeSockets(pendingWriteError: exception);
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
    final subscription = _socketSubscription;
    _socket = null;
    _transportSocket = null;
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
    if (transportSocket != null) {
      await _forceCloseSocket(transportSocket);
    }
    if (socket != null &&
        !identical(socket, transportSocket) &&
        socket is! RawSecureSocket) {
      await _forceCloseSocket(socket);
    }
  }

  Future<void> _forceCloseSocket(RawSocket socket) async {
    try {
      socket.shutdown(SocketDirection.both);
    } catch (_) {}
    try {
      await socket.close();
    } catch (_) {}
  }

  void _setupSocketHandlers(RawSocket socket) {
    String buffer = '';

    _socketSubscription = socket.listen(
      (event) {
        if (!identical(socket, _socket)) {
          return;
        }
        if (event == RawSocketEvent.write) {
          _flushPendingWrites(socket);
          return;
        }
        if (event == RawSocketEvent.readClosed ||
            event == RawSocketEvent.closed) {
          _handleSocketClosed(socket);
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
                _handleMessage(json.decode(jsonStr), socket);
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
          _handleSocketError(socket, error, stackTrace),
      onDone: () => _handleSocketClosed(socket),
    );
    socket.readEventsEnabled = true;
    _flushPendingWrites(socket);
  }

  void _handleSocketError(
    RawSocket socket,
    Object error,
    StackTrace stackTrace,
  ) {
    _failCurrentSocket(
      socket,
      SyncplayConnectionException('SyncPlay: socket error: $error'),
      stackTrace,
    );
  }

  void _handleSocketClosed(RawSocket socket) {
    _failCurrentSocket(
      socket,
      SyncplayConnectionException('SyncPlay: connection closed'),
    );
  }

  void _failCurrentSocket(
    RawSocket socket,
    SyncplayConnectionException exception, [
    StackTrace? stackTrace,
  ]) {
    if (!identical(socket, _socket)) {
      return;
    }
    final handshakePending = !(_tlsHandshakeCompleter?.isCompleted ?? true);
    final closeFuture = _closeSockets(
      pendingWriteError: exception,
      stackTrace: stackTrace,
    );
    _completeTLSHandshakeError(exception, stackTrace);
    if (!handshakePending) {
      _generalMessageController?.addError(exception, stackTrace);
    }
    unawaited(closeFuture);
  }

  void _handleMessage(dynamic data, RawSocket sourceSocket) {
    final json = data as Map<String, dynamic>;
    if (json.containsKey('TLS')) {
      final tlsData = json['TLS'];
      if (tlsData is! Map || !tlsData.containsKey('startTLS')) {
        _completeTLSHandshakeError(
          SyncplayProtocolException('SyncPlay: invalid TLS response'),
        );
      } else if (tlsData['startTLS'] == 'true') {
        unawaited(_upgradeToTLS(sourceSocket));
      } else {
        _completeTLSHandshakeError(
          SyncplayConnectionException(
            'SyncPlay: server rejected TLS connection upgrade',
          ),
        );
      }
      return;
    }
    if (json.containsKey('Hello')) {
      if (json['Hello'].containsKey('room') &&
          json['Hello']['room'].containsKey('name')) {
        _username = json['Hello']['username'];
        _currentRoom = json['Hello']['room']['name'];
        KazumiLogger().d('SyncPlay: room join acknowledged');
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

  Future<void> _upgradeToTLS(RawSocket plainSocket) async {
    if (!identical(plainSocket, _socket)) {
      return;
    }
    final subscription = _socketSubscription;
    if (subscription == null) {
      _completeTLSHandshakeError(
        SyncplayConnectionException(
          'SyncPlay: TLS connection upgrade lost its socket subscription',
        ),
      );
      return;
    }
    _socketSubscription = null;
    _socket = null;
    try {
      final secureSocket = await RawSecureSocket.secure(
        plainSocket,
        subscription: subscription,
        host: _host,
      );
      if (!identical(_transportSocket, plainSocket)) {
        await _forceCloseSocket(secureSocket);
        return;
      }
      _socket = secureSocket;
      _isTLS = true;
      _setupSocketHandlers(secureSocket);
      KazumiLogger().d('SyncPlay: TLS connection established');
      final handshakeCompleter = _tlsHandshakeCompleter;
      if (handshakeCompleter != null && !handshakeCompleter.isCompleted) {
        handshakeCompleter.complete();
      }
    } catch (error, stackTrace) {
      await _forceCloseSocket(plainSocket);
      if (!identical(_transportSocket, plainSocket)) {
        return;
      }
      _transportSocket = null;
      final exception = SyncplayConnectionException(
        'SyncPlay: TLS connection upgrade failed: $error',
      );
      KazumiLogger().w(
        'SyncPlay: TLS connection upgrade failed',
        error: exception,
      );
      _completeTLSHandshakeError(exception, stackTrace);
    }
  }

  void _completeTLSHandshakeError(Object error, [StackTrace? stackTrace]) {
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
    if (_closed || socket == null) {
      throw SyncplayConnectionException('SyncPlay: not connected to server');
    }
    final jsonStr = jsonEncode(message.toJson());
    _pendingWrites.addAll(utf8.encode('$jsonStr\r\n'));
    var completer = _pendingWriteCompleter;
    if (completer == null) {
      completer = Completer<void>();
      _pendingWriteCompleter = completer;
      _restartPendingWriteTimer(socket, completer);
    }
    _flushPendingWrites(socket);
    await completer.future;
  }

  void _flushPendingWrites(RawSocket socket) {
    if (!identical(socket, _socket)) {
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
            _restartPendingWriteTimer(socket, completer);
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
      _failCurrentSocket(socket, exception, stackTrace);
    }
  }

  void _restartPendingWriteTimer(RawSocket socket, Completer<void> completer) {
    _pendingWriteTimer?.cancel();
    _pendingWriteTimer = Timer(_socketWriteTimeout, () {
      if (!identical(socket, _socket) ||
          !identical(completer, _pendingWriteCompleter) ||
          _pendingWrites.isEmpty) {
        return;
      }
      _failCurrentSocket(
        socket,
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
      future.catchError((Object error, StackTrace stackTrace) {
        if (error is! SyncplayConnectionException) {
          Error.throwWithStackTrace(error, stackTrace);
        }
      }),
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
    _avrRtt = _avrRtt * pingMovingAverageWeight +
        _clientRtt * (1 - pingMovingAverageWeight);

    // Calculate the forward delay based on the sender's RTT
    if (senderRtt < _clientRtt) {
      _fd = _avrRtt / 2 + (_clientRtt - senderRtt);
    } else {
      _fd = _avrRtt / 2;
    }
  }
}
