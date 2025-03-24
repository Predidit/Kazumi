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
  final String setBy;

  // syncplay controll message
  final bool clientAck;
  final bool serverAck;

  // latency calculation
  double clientLatencyCalculation;
  double? latencyCalculation;
  final double clientRtt;

  StateMessage({
    required this.position,
    required this.paused,
    required this.setBy,
    this.doSeek,
    this.clientAck = false,
    this.serverAck = false,
    required this.clientLatencyCalculation,
    this.latencyCalculation,
    this.clientRtt = 0.0,
  });

  @override
  Map<String, dynamic> toJson() => {
        'State': {
          if (clientAck || serverAck)
            'ignoringOnTheFly': {
              if (clientAck) 'client': 1,
              if (serverAck) 'server': 1,
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
            'setBy': setBy,
            if (doSeek != null) 'doSeek': doSeek,
          },
        },
      };
}

class SetMessage extends SyncplayMessage {
  final double? duration;
  final String? fileName;
  final int? size;
  final String? setBy;
  final String? room;
  final bool? setJoined;
  final bool? setReady;

  SetMessage({
    this.duration,
    this.fileName,
    this.size,
    this.setBy,
    this.room,
    this.setJoined,
    this.setReady,
  });

  @override
  Map<String, dynamic> toJson() {
    if (setJoined != null && room != null) {
      return {
        "Set": {
          "32421321": {
            room: {"name": room},
            "event": {"joined": true}
          }
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

class SyncplayClient {
  final String _host;
  final int _port;
  Socket? _socket;
  String? _username;
  String? _currentRoom;
  double _currentPositon = 0.0;
  bool _isPaused = true;
  bool _isLocked = false;
  StreamController<Map<String, dynamic>>? _generalMessageController =
      StreamController.broadcast();
  StreamController<Map<String, dynamic>>? _roomMessageController =
      StreamController.broadcast();
  StreamController<Map<String, dynamic>>? _flieChangedMessageController =
      StreamController.broadcast();
  StreamController<Map<String, dynamic>>? _positionChangedMessageController =
      StreamController.broadcast();
  Timer? _heartbeatTimer;
  double? _lastLatencyCalculation;

  // Network status
  double _clientRtt = 0.0;
  double _serverRtt = 0.0;
  double _avrRtt = 0.0;
  double _fd = 0.0;

  bool get isConnected => _socket != null;
  String? get username => _username;
  String? get currentRoom => _currentRoom;
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

  Future<void> connect() async {
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
      _startHeartbeat();
    } on SocketException catch (e) {
      throw SyncplayConnectionException(
          'SyncPlay: connection failed: ${e.message}');
    }
  }

  void setPosition(double position) {
    _currentPositon = position;
  }

  void setPaused(bool paused) {
    _isPaused = paused;
  }

  void _setLocked(bool locked) {
    _isLocked = locked;
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
            print(
                'SyncPlay: [${DateTime.now().millisecondsSinceEpoch / 1000.0}] received message: $jsonStr');
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

  void _handleMessage(dynamic data) {
    final json = data as Map<String, dynamic>;

    if (json.containsKey('Hello')) {
      if (json['Hello'].containsKey('room') &&
          json['Hello']['room'].containsKey('name')) {
        _setLocked(false);
        _username = json['Hello']['username'];
        _currentRoom = json['Hello']['room']['name'];
        print(
            'SyncPlay: joined room: $_currentRoom as $_username, version: ${json['Hello']['version']}');
        _setReady();
      }
      if (_isLocked) {
        return;
      }
      _generalMessageController?.add({
        'username': json['Hello']['username'],
        'room': json['Hello']['room']['name'],
      });
      return;
    } else if (json.containsKey('State')) {
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
        sendSyncPlaySyncRequestAck();
        return;
      }
      if (!json['State'].containsKey('playstate')) {
        return;
      }
      if (_isLocked) {
        return;
      }
      _positionChangedMessageController?.add({
        'calculatedPositon': (json['State']['playstate']['paused'] ?? true)
            ? (json['State']['playstate']['position']?.toDouble() ?? 0.0)
            : ((json['State']['playstate']['position']?.toDouble() ?? 0.0) +
                _fd),
        'position': json['State']['playstate']['position']?.toDouble() ?? 0.0,
        'paused': json['State']['playstate']['paused'] ?? true,
        'setBy': json['State']['playstate']['setBy'] ?? '',
        'clientRtt': _clientRtt,
        'serverRtt': _serverRtt,
        'avrRtt': _avrRtt,
        'fd': _fd,
      });
      return;
    } else if (json.containsKey('Set')) {
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
          var event = details['event'].keys.first ?? 'unknown';
          _roomMessageController?.add({
            'type': event,
            'username': username,
          });
        });
        return;
      }
      if (!json['Set'].containsKey('file')) {
        return;
      }
      if (_isLocked) {
        return;
      }
      _flieChangedMessageController?.add({
        'name': json['Set']['file']['name'] ?? '',
        'setBy': json['Set']['user'].keys.first ?? '',
      });
      return;
    } else {
      throw SyncplayProtocolException('SyncPlay: unknown message ty');
    }
  }

  Future<void> joinRoom(String room, String username) async {
    if (_socket == null) {
      throw SyncplayConnectionException('SyncPlay: not connected to server');
    }
    print('SyncPlay: joining room: $room as $username');
    await _sendMessage(HelloMessage(
      username: username,
      version: '1.7.0',
      room: room,
    ));
    _setLocked(true);
  }

  Future<void> setSyncPlayPlaying(
      String bangumiName, double duration, int size) async {
    if (_socket == null) {
      throw SyncplayConnectionException('SyncPlay: not connected to server');
    }
    if (_currentRoom == null || _username == null) {
      throw SyncplayProtocolException('SyncPlay: not in a room');
    }
    await _sendMessage(SetMessage(
        duration: duration,
        fileName: bangumiName,
        size: size,
        setBy: _username ?? '',
        room: _currentRoom ?? ''));
  }

  Future<void> sendSyncPlaySyncRequest() async {
    if (_socket == null) {
      throw SyncplayConnectionException('SyncPlay: not connected to server');
    }
    if (_currentRoom == null || _username == null) {
      throw SyncplayProtocolException('SyncPlay: not in a room');
    }
    await _sendMessage(StateMessage(
        position: _currentPositon,
        paused: _isPaused,
        setBy: _username ?? '',
        doSeek: null,
        clientLatencyCalculation:
            DateTime.now().millisecondsSinceEpoch / 1000.0,
        clientAck: true));
    _setLocked(true);
  }

  Future<void> sendSyncPlaySyncRequestAck() async {
    if (_socket == null) {
      throw SyncplayConnectionException('SyncPlay: not connected to server');
    }
    if (_currentRoom == null || _username == null) {
      throw SyncplayProtocolException('SyncPlay: not in a room');
    }
    await _sendMessage(
        StateMessage(
            position: _currentPositon,
            paused: _isPaused,
            setBy: _username ?? '',
            latencyCalculation: _lastLatencyCalculation,
            clientLatencyCalculation:
                DateTime.now().millisecondsSinceEpoch / 1000.0,
            serverAck: true),
        force: true);
    _setLocked(false);
  }

  Future<void> _setReady() async {
    if (_socket == null) {
      throw SyncplayConnectionException('SyncPlay: not connected to server');
    }
    if (_currentRoom == null || _username == null) {
      throw SyncplayProtocolException('SyncPlay: not in a room');
    }
    await _sendMessage(SetMessage(
      setJoined: true,
      room: _currentRoom,
    ));
    await _sendMessage(SetMessage(
      setReady: true,
    ));
  }

  Future<void> disconnect() async {
    print('SyncPlay: disconnecting from Syncplay server: $_host:$_port');
    await _generalMessageController?.close();
    _generalMessageController = null;
    await _roomMessageController?.close();
    _roomMessageController = null;
    await _flieChangedMessageController?.close();
    _flieChangedMessageController = null;
    await _positionChangedMessageController?.close();
    _positionChangedMessageController = null;
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    await _socket?.close();
    _socket = null;
    _currentRoom = null;
    _username = null;
    _currentPositon = 0.0;
    _isPaused = true;
    _lastLatencyCalculation = null;
    _isLocked = false;
    _clientRtt = 0.0;
    _serverRtt = 0.0;
    _avrRtt = 0.0;
    _fd = 0.0;
  }

  Future<void> _sendMessage(SyncplayMessage message,
      {bool force = false}) async {
    if (_isLocked && !force) {
      print(
          'SyncPlay: sending message is blocked due to unsolved message, not sending: ${message.toJson()}');
      return;
    }
    final json = message.toJson();
    final jsonStr = jsonEncode(json);
    print(
        'SyncPlay: [${DateTime.now().millisecondsSinceEpoch / 1000.0}] sending message: $jsonStr');
    _socket?.write('$jsonStr\r\n');
  }

  void _startHeartbeat() {
    _heartbeatTimer = Timer.periodic(
      const Duration(seconds: 1),
      (timer) => _sendMessage(_createHeartbeat()),
    );
  }

  SyncplayMessage _createHeartbeat() {
    return StateMessage(
        position: _currentPositon,
        paused: _isPaused,
        latencyCalculation: _lastLatencyCalculation,
        clientLatencyCalculation:
            DateTime.now().millisecondsSinceEpoch / 1000.0,
        clientRtt: _clientRtt,
        setBy: _username ?? '');
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
