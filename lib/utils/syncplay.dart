// https://syncplay.pl/about/protocol/

import 'dart:async';
import 'dart:convert';
import 'dart:io';

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

  static HelloMessage fromJson(Map<String, dynamic> json) {
    return HelloMessage(
      username: json['Hello']['username'],
      version: json['Hello']['version'],
      room: json['Hello']['room']['name'],
    );
  }
}

class StateMessage extends SyncplayMessage {
  final double position;
  final bool paused;
  final bool doSeek;
  final String setBy;

  // syncplay controll message
  final bool clientAck;
  final bool serverAck;

  // latency calculation
  double clientLatencyCalculation;
  double? latencyCalculation;

  StateMessage({
    required this.position,
    required this.paused,
    required this.setBy,
    this.doSeek = false,
    this.clientAck = false,
    this.serverAck = false,
    required this.clientLatencyCalculation,
    this.latencyCalculation,
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
            'clientRtt': 0,
            'clientLatencyCalculation': clientLatencyCalculation,
            // 'latencyCalculation':
            //     DateTime.now().millisecondsSinceEpoch / 1000.0,
            if (latencyCalculation != null)
              'latencyCalculation': latencyCalculation,
            'playstate': {
              'position': position,
              'paused': paused,
              'setBy': setBy,
              'doSeek': doSeek,
            },
          }
        },
      };

  static StateMessage fromJson(Map<String, dynamic> json) {
    return StateMessage(
      position: json['State']['playstate']['position']?.toDouble() ?? 0.0,
      paused: json['State']['playstate']['paused'] ?? true,
      setBy: json['State']['playstate']['setBy'] ?? '',
      doSeek: json['State']['playstate']['doSeek'] ?? false,
      clientLatencyCalculation: DateTime.now().millisecondsSinceEpoch / 1000.0,
      latencyCalculation:
          json['State']['ping']['latencyCalculation']?.toDouble() ?? 0.0,
    );
  }
}

class SetMessage extends SyncplayMessage {
  final double duration;
  final String name;
  final int size;
  final String setBy;
  final String room;

  SetMessage({
    required this.duration,
    required this.name,
    required this.size,
    required this.setBy,
    required this.room,
  });

  @override
  Map<String, dynamic> toJson() => {
        'Set': {
          'file': {
            'duration': duration,
            'name': name,
            'size': size,
          },
          "user": {
            setBy: {
              "room": {"name": room},
            },
          }
        },
      };

  static SetMessage fromJson(Map<String, dynamic> json) {
    var userData = json['Set']?['user'];
    if (userData == null) {
      return SetMessage(
        duration: 0.0,
        name: '',
        size: 0,
        setBy: '',
        room: '',
      );
    }
    var fileData = userData[userData.keys.first]?['file'];
    if (fileData == null) {
      return SetMessage(
        duration: 0.0,
        name: '',
        size: 0,
        setBy: '',
        room: '',
      );
    }
    return SetMessage(
      duration: fileData['duration']?.toDouble() ?? 0.0,
      name: fileData['name'] ?? '',
      size: fileData['size'] ?? 0,
      setBy: userData.keys.first,
      room: userData[userData.keys.first]['room']['name'] ?? '',
    );
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
  StreamController<SyncplayMessage>? _messageController =
      StreamController.broadcast();
  Timer? _heartbeatTimer;
  double? _lastLatencyCalculation;

  bool get isConnected => _socket != null;
  String? get username => _username;
  String? get currentRoom => _currentRoom;
  Stream<SyncplayMessage> get onMessage {
    _messageController ??= StreamController.broadcast();
    return _messageController!.stream;
  }

  SyncplayClient({required String host, required int port})
      : _host = host,
        _port = port;

  Future<void> connect() async {
    if (_messageController?.isClosed ?? true) {
      _messageController = StreamController.broadcast();
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

  void setLocked(bool locked) {
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
                'SyncPlay: received message [${DateTime.now().millisecondsSinceEpoch / 1000.0}]: $jsonStr');
            final message = _parseMessage(json.decode(jsonStr));
            if (!_isLocked) {
              _messageController?.add(message);
            } else {
              print(
                  'SyncPlay: received message is blocked due to unsolved message, not adding: ${message.toJson()}');
            }
          } catch (e) {
            _messageController?.addError(
              SyncplayProtocolException(
                  'SyncPlay: received data parse failed: $e'),
            );
          }
          buffer = buffer.substring(endIndex + 1);
        }
      },
      onError: (error) => _messageController?.addError(
        SyncplayConnectionException('SyncPlay: socket error: $error'),
      ),
      onDone: () => _messageController?.addError(
        SyncplayConnectionException('SyncPlay: connection closed'),
      ),
    );
  }

  SyncplayMessage _parseMessage(dynamic data) {
    final json = data as Map<String, dynamic>;

    if (json.containsKey('Hello')) {
      return HelloMessage.fromJson(json);
    } else if (json.containsKey('State')) {
      if (json['State'].containsKey('ignoringOnTheFly')) {
        sendSyncPlaySyncRequestAck();
      }
      if (json['State'].containsKey('ping')) {
        _lastLatencyCalculation =
            json['State']['ping']['latencyCalculation']?.toDouble();
      }
      return StateMessage.fromJson(json);
    } else if (json.containsKey('Set')) {
      return SetMessage.fromJson(json);
    } else {
      throw SyncplayProtocolException('SyncPlay: unknown message ty');
    }
  }

  Future<void> joinRoom(String room, String username) async {
    if (_socket == null) {
      throw SyncplayConnectionException('SyncPlay: not connected to server');
    }
    await sendMessage(HelloMessage(
      username: username,
      version: '1.7.0',
      room: room,
    ));
    _username = username;
    _currentRoom = room;
  }

  Future<void> setSyncPlayPlaying(
      String bangumiName, double duration, int size) async {
    if (_socket == null) {
      throw SyncplayConnectionException('SyncPlay: not connected to server');
    }
    if (_currentRoom == null || _username == null) {
      throw SyncplayProtocolException('SyncPlay: not in a room');
    }
    await sendMessage(SetMessage(
        duration: duration,
        name: bangumiName,
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
    await sendMessage(StateMessage(
        position: _currentPositon,
        paused: _isPaused,
        setBy: _username ?? '',
        doSeek: true,
        latencyCalculation: _lastLatencyCalculation,
        clientLatencyCalculation: DateTime.now().millisecondsSinceEpoch / 1000.0,
        clientAck: true));
    setLocked(true);
  }

  Future<void> sendSyncPlaySyncRequestAck() async {
    if (_socket == null) {
      throw SyncplayConnectionException('SyncPlay: not connected to server');
    }
    if (_currentRoom == null || _username == null) {
      throw SyncplayProtocolException('SyncPlay: not in a room');
    }
    await sendMessage(
        StateMessage(
            position: _currentPositon,
            paused: _isPaused,
            setBy: _username ?? '',
            latencyCalculation: _lastLatencyCalculation,
            clientLatencyCalculation: DateTime.now().millisecondsSinceEpoch / 1000.0,
            serverAck: true),
        force: true);
    setLocked(false);
  }

  Future<void> sendMessage(SyncplayMessage message,
      {bool force = false}) async {
    if (_isLocked && !force) {
      print(
          'SyncPlay: sending message is blocked due to unsolved message, not sending: ${message.toJson()}');
      return;
    }
    final json = message.toJson();
    final jsonStr = jsonEncode(json);
    print(
        'SyncPlay: sending message [${DateTime.now().millisecondsSinceEpoch / 1000.0}]: $jsonStr');
    _socket?.write('$jsonStr\r\n');
  }

  void _startHeartbeat() {
    _heartbeatTimer = Timer.periodic(
      const Duration(seconds: 1),
      (timer) => sendMessage(_createHeartbeat()),
    );
  }

  SyncplayMessage _createHeartbeat() {
    return StateMessage(
        position: _currentPositon,
        paused: _isPaused,
        latencyCalculation: _lastLatencyCalculation,
        clientLatencyCalculation: DateTime.now().millisecondsSinceEpoch / 1000.0,
        setBy: _username ?? '');
  }

  Future<void> disconnect() async {
    print('SyncPlay: disconnecting from Syncplay server: $_host:$_port');
    await _messageController?.close();
    _messageController = null;
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    await _socket?.close();
    _socket = null;
    _currentRoom = null;
    _username = null;
    _currentPositon = 0.0;
    _isPaused = true;
    _lastLatencyCalculation = null;
  }
}
