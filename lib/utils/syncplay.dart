// https://syncplay.pl/about/protocol/

import 'dart:async';
import 'dart:convert';
import 'dart:io';

const double PING_MOVING_AVERAGE_WEIGHT = 0.85;

class SyncplayException implements Exception {
  final String message;
  SyncplayException(this.message);
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

  // syncplay controll message
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
  bool _isTLS = false;
  Socket? _socket;
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

  bool get isConnected => _socket != null;
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
    if (_generalMessageController?.isClosed ?? true) {
      _generalMessageController = StreamController.broadcast();
    }
    if (_flieChangedMessageController?.isClosed ?? true) {
      _flieChangedMessageController = StreamController.broadcast();
    }
    if (_positionChangedMessageController?.isClosed ?? true) {
      _positionChangedMessageController = StreamController.broadcast();
    }
    try {
      await _socket?.close();
      _socket = null;
      print('SyncPlay: connecting to Syncplay server: $_host:$_port');
      _socket = await Socket.connect(_host, _port);
      print('SyncPlay: connected to Syncplay server: $_host:$_port');
      _setupSocketHandlers();
      if (enableTLS) {
        requestTLS();
      }
    } on SocketException catch (e) {
      _generalMessageController?.addError(
        SyncplayConnectionException(
            'SyncPlay: connection failed: ${e.message}'),
      );
    }
  }

  Future<void> requestTLS() async {
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
    _sendState(
      position: _currentPositon,
      paused: _isPaused,
      doSeek: doSeek,
      stateChange: true,
    );
  }

  Future<void> disconnect() async {
    print('SyncPlay: disconnecting from Syncplay server: $_host:$_port');
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
    try {
      await _socket?.close();
    } catch (_) {}
    _socket = null;
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

  void _setupSocketHandlers() {
    String buffer = '';

    _socket?.listen(
      (data) {
        final dataStr = utf8.decode(data);
        buffer += dataStr;
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
            _handleMessage(json.decode(jsonStr));
          } catch (e) {
            _generalMessageController?.addError(
              SyncplayProtocolException(
                  'SyncPlay: received data parse failed: $e'),
            );
          }
          buffer = buffer.substring(endIndex + 1);
        }
      },
      onError: (error) => _generalMessageController?.addError(
        SyncplayConnectionException('SyncPlay: socket error: $error'),
      ),
      onDone: () => _generalMessageController?.addError(
        SyncplayConnectionException('SyncPlay: connection closed'),
      ),
    );
  }

  void _handleMessage(dynamic data) async {
    final json = data as Map<String, dynamic>;
    if (json.containsKey('TLS')) {
      if (json['TLS'].containsKey('startTLS')) {
        if (json['TLS']['startTLS'] == 'true') {
          var plainSocket = _socket;
          try {
            _socket = await SecureSocket.secure(plainSocket!);
            _setupSocketHandlers();
            _isTLS = true;
            print('SyncPlay: TLS connection established');
            try {
              plainSocket.close();
            } catch (_) {}
          } catch (e) {
            print('SyncPlay: TLS connection upgrade failed: $e');
            _socket = plainSocket;
            _isTLS = false;
          }
        }
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
        _setReady();
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
      _sendState(
        position: _currentPositon,
        paused: _isPaused,
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
    if (_socket == null) {
      _generalMessageController?.addError(
        SyncplayConnectionException('SyncPlay: not connected to server'),
      );
      return;
    }
    final json = message.toJson();
    final jsonStr = jsonEncode(json);
    // print(
    //     'SyncPlay: [${DateTime.now().millisecondsSinceEpoch / 1000.0}] sending message: $jsonStr');
    _socket?.write('$jsonStr\r\n');
  }

  void _sendState(
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
    _sendMessage(StateMessage(
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
