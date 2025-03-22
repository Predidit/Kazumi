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

  StateMessage({
    required this.position,
    required this.paused,
  });

  @override
  Map<String, dynamic> toJson() => {
        'State': {
          'ping': {
            'clientRtt': 0,
            'clientLatencyCalculation':
                DateTime.now().millisecondsSinceEpoch / 1000.0,
            // 'latencyCalculation':
            //     DateTime.now().millisecondsSinceEpoch / 1000.0,
            'playstate': {
              'position': position,
              'paused': paused,
            },
          }
        },
      };

  static StateMessage fromJson(Map<String, dynamic> json) {
    return StateMessage(
      position: json['State']['playstate']['position']?.toDouble() ?? 0.0,
      paused: json['State']['playstate']['paused'] ?? true,
    );
  }
}

class SetMessage extends SyncplayMessage {
  final double duration;
  final String name;
  final int size;

  SetMessage({
    required this.duration,
    required this.name,
    required this.size,
  });

  @override
  Map<String, dynamic> toJson() => {
        'Set': {
          'file': {
            'duration': duration,
            'name': name,
            'size': size,
          }
        },
      };

  static SetMessage fromJson(Map<String, dynamic> json) {
    var fileData = json['Set']?['file'];
    if (fileData == null) {
      return SetMessage(
        duration: 0.0,
        name: '',
        size: 0,
      );
    }
    return SetMessage(
      duration: fileData['duration']?.toDouble() ?? 0.0,
      name: fileData['name'] ?? '',
      size: fileData['size'] ?? 0,
    );
  }
}

class SyncplayClient {
  final String _host;
  final int _port;
  Socket? _socket;
  StreamController<SyncplayMessage>? _messageController =
      StreamController.broadcast();
  Timer? _heartbeatTimer;

  bool get isConnected => _socket != null;
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
            print('SyncPlay: received message: $jsonStr');
            final message = _parseMessage(json.decode(jsonStr));
            _messageController?.add(message);
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
      return StateMessage.fromJson(json);
    } else if (json.containsKey('Set')) {
      return SetMessage.fromJson(json);
    } else {
      throw SyncplayProtocolException('SyncPlay: unknown message ty');
    }
  }

  Future<void> sendMessage(SyncplayMessage message) async {
    final json = message.toJson();
    final jsonStr = jsonEncode(json);
    print('SyncPlay: sending message: $jsonStr');
    _socket?.write('$jsonStr\r\n');
  }

  void _startHeartbeat() {
    _heartbeatTimer = Timer.periodic(
      const Duration(seconds: 1),
      (timer) => sendMessage(_createHeartbeat()),
    );
  }

  SyncplayMessage _createHeartbeat() {
    return StateMessage(position: 0.0, paused: true);
  }

  Future<void> disconnect() async {
    print('SyncPlay: disconnecting from Syncplay server: $_host:$_port');
    await _messageController?.close();
    _messageController = null;
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    await _socket?.close();
    _socket = null;
  }
}
