import 'package:flutter/services.dart';
import 'package:kazumi/services/logging/logger.dart';

enum IosPipEntryResult { entered, unsupported, notReady, failed }

class IosPipPlaybackState {
  const IosPipPlaybackState({
    required this.textureId,
    required this.playing,
    required this.position,
    required this.duration,
    required this.rate,
    required this.sourceRect,
  });

  final int? textureId;
  final bool playing;
  final Duration position;
  final Duration duration;
  final double rate;
  // UIKit uses logical points, rather than Android's physical pixels.
  final Rect? sourceRect;

  Map<String, Object> toArguments() => {
    'textureId': ?textureId,
    'playing': playing,
    'positionMillis': position.inMilliseconds,
    'durationMillis': duration.inMilliseconds,
    'rate': rate,
    if (sourceRect != null)
      'sourceRect': {
        'left': sourceRect!.left,
        'top': sourceRect!.top,
        'width': sourceRect!.width,
        'height': sourceRect!.height,
      },
  };
}

/// Owns one player page's native PiP session. The page retains its existing
/// media-kit player; native code only displays its frames and forwards controls.
class IosPipController {
  static Future<bool> isSupported({
    MethodChannel channel = const MethodChannel('com.predidit.kazumi/ios_pip'),
  }) async {
    try {
      return await channel.invokeMethod<bool>('isSupported') ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  IosPipController({
    required this.playbackState,
    required this.playerHandle,
    required this.suspendVideo,
    required this.resumeVideo,
    required this.onPlay,
    required this.onPause,
    required this.onSeek,
    required this.onModeChanged,
    required this.canRestore,
    MethodChannel channel = const MethodChannel('com.predidit.kazumi/ios_pip'),
  }) : _channel = channel {
    _bridge = _IosPipChannelBridge.attach(this, channel);
  }

  final IosPipPlaybackState Function() playbackState;
  final Future<int?> Function() playerHandle;
  final Future<bool> Function(int handle) suspendVideo;
  final Future<bool> Function(int handle) resumeVideo;
  final Future<void> Function() onPlay;
  final Future<void> Function() onPause;
  final Future<void> Function(Duration position) onSeek;
  final void Function(bool active, bool restored) onModeChanged;
  final bool Function() canRestore;
  final MethodChannel _channel;
  late final _IosPipChannelBridge _bridge;
  Future<void>? _disposeFuture;
  bool _active = false;
  bool _entering = false;
  bool _disposed = false;

  bool get _ownsPage => !_disposed && _bridge.isCurrent(this);
  bool get isActive => _ownsPage && _active;
  bool get keepPlaybackInBackground => _ownsPage && (_active || _entering);

  Future<IosPipEntryResult> enter() async {
    if (!_ownsPage) return IosPipEntryResult.failed;
    if (_active) return IosPipEntryResult.entered;
    if (_entering) return IosPipEntryResult.notReady;
    final state = playbackState();
    if (state.textureId == null || state.sourceRect?.isEmpty != false) {
      return IosPipEntryResult.notReady;
    }
    _entering = true;
    try {
      final supported = await _channel.invokeMethod<bool>('isSupported');
      if (!_ownsPage) return IosPipEntryResult.failed;
      if (supported != true) return IosPipEntryResult.unsupported;
      final handle = await playerHandle();
      if (!_ownsPage) return IosPipEntryResult.failed;
      if (handle == null) return IosPipEntryResult.notReady;
      if (!await _bridge.acquireNative(this) || !_ownsPage) {
        return IosPipEntryResult.failed;
      }
      final prepared = await _channel.invokeMethod<bool>('prepare', {
        ...state.toArguments(),
        'handle': handle,
      });
      if (!_ownsPage) return IosPipEntryResult.failed;
      if (prepared != true) return IosPipEntryResult.notReady;
      // Preparing can recreate the native output and replace its texture. Send
      // the latest state before entry instead of waiting for the periodic sync.
      await _channel.invokeMethod<void>(
        'updatePlaybackState',
        playbackState().toArguments(),
      );
      if (!_ownsPage) return IosPipEntryResult.failed;
      final entered = await _channel.invokeMethod<bool>('enter');
      if (!_ownsPage) return IosPipEntryResult.failed;
      _active = entered == true;
      return _active ? IosPipEntryResult.entered : IosPipEntryResult.failed;
    } on PlatformException catch (error) {
      KazumiLogger().w('iOS PiP: entry failed', error: error);
      return error.code == 'pip_not_ready'
          ? IosPipEntryResult.notReady
          : IosPipEntryResult.failed;
    } on MissingPluginException {
      return IosPipEntryResult.unsupported;
    } finally {
      _entering = false;
    }
  }

  Future<void> synchronize() async {
    if (!keepPlaybackInBackground || !_bridge.ownsNative(this)) return;
    try {
      await _channel.invokeMethod<void>(
        'updatePlaybackState',
        playbackState().toArguments(),
      );
    } on PlatformException catch (error) {
      KazumiLogger().w('iOS PiP: state synchronization failed', error: error);
    } on MissingPluginException {
      // A session cannot be established when the native bridge is unavailable.
    }
  }

  Future<Object?> _handleMethodCall(MethodCall call) async {
    final args = call.arguments is Map ? call.arguments as Map : const {};
    switch (call.method) {
      case 'onVideoOutputWillChange':
        final handle = args['handle'];
        return handle is int ? await suspendVideo(handle) : false;
      case 'onVideoOutputDidChange':
        final handle = args['handle'];
        return handle is int ? await resumeVideo(handle) : false;
      case 'onModeChanged':
        if (!_ownsPage) return null;
        if (args['isInPipMode'] == true && !keepPlaybackInBackground) {
          return null;
        }
        _active = args['isInPipMode'] == true;
        onModeChanged(_active, args['restored'] == true);
      case 'onRestore':
        return _ownsPage && canRestore();
      case 'onAction':
        if (!keepPlaybackInBackground) return null;
        switch (args['action']) {
          case 'play':
            await onPlay();
          case 'pause':
            await onPause();
          case 'seek':
            final position = args['positionMillis'];
            if (position is num && position.isFinite) {
              final duration = playbackState().duration.inMilliseconds;
              final target = position.toInt();
              await onSeek(
                Duration(
                  milliseconds: duration > 0
                      ? target.clamp(0, duration)
                      : target < 0
                      ? 0
                      : target,
                ),
              );
            }
        }
        await synchronize();
    }
    return null;
  }

  Future<void> dispose() => _disposeFuture ??= _dispose();

  Future<void> _dispose() async {
    _disposed = true;
    _active = false;
    _entering = false;
    try {
      if (_bridge.shouldDisposeNative(this)) {
        // Native acknowledges only after in-flight output changes are drained.
        // Their Will/Did callbacks must still reach this page's captured player.
        await _channel.invokeMethod<void>('dispose');
      }
    } on PlatformException catch (error) {
      KazumiLogger().w('iOS PiP: disposal failed', error: error);
    } on MissingPluginException {
      // iOS versions without sample-buffer PiP have no active native session.
    } finally {
      _bridge.detach(this);
    }
  }
}

/// A method-channel handler is shared by name, even across MethodChannel
/// instances. Keep it stable while an old page drains and a new page attaches.
class _IosPipChannelBridge {
  _IosPipChannelBridge(this.channel);

  static final _bridges = <(BinaryMessenger, String), _IosPipChannelBridge>{};

  static _IosPipChannelBridge attach(
    IosPipController owner,
    MethodChannel channel,
  ) {
    final key = (channel.binaryMessenger, channel.name);
    final bridge = _bridges.putIfAbsent(key, () {
      final value = _IosPipChannelBridge(channel);
      channel.setMethodCallHandler(value.handleMethodCall);
      return value;
    });
    bridge._owners.add(owner);
    return bridge;
  }

  final MethodChannel channel;
  final List<IosPipController> _owners = [];
  IosPipController? _nativeOwner;

  IosPipController? get _current => _owners.isEmpty ? null : _owners.last;
  bool isCurrent(IosPipController owner) => identical(_current, owner);
  bool ownsNative(IosPipController owner) => identical(_nativeOwner, owner);

  Future<bool> acquireNative(IosPipController owner) async {
    final previous = _nativeOwner;
    if (previous != null && !identical(previous, owner)) {
      await previous.dispose();
    }
    if (!owner._ownsPage) return false;
    _nativeOwner = owner;
    return true;
  }

  bool shouldDisposeNative(IosPipController owner) =>
      identical(_nativeOwner, owner) ||
      (_nativeOwner == null && isCurrent(owner));

  Future<Object?> handleMethodCall(MethodCall call) async {
    final outputChange =
        call.method == 'onVideoOutputWillChange' ||
        call.method == 'onVideoOutputDidChange';
    final owner = outputChange ? (_nativeOwner ?? _current) : _current;
    if (owner == null) return false;
    // Playback commands from a draining native session must not reach a newer
    // page while it waits to acquire that session.
    if (!outputChange &&
        (_nativeOwner != null && !identical(_nativeOwner, owner))) {
      return false;
    }
    return owner._handleMethodCall(call);
  }

  void detach(IosPipController owner) {
    _owners.remove(owner);
    if (identical(_nativeOwner, owner)) _nativeOwner = null;
    if (_owners.isEmpty) {
      channel.setMethodCallHandler(null);
      _bridges.remove((channel.binaryMessenger, channel.name));
    }
  }
}
