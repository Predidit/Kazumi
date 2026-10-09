import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:kazumi/services/logging/logger.dart';

/// Captures one player and its texture notifier, so a late output transition
/// cannot write properties on a replacement player.
class IosPipVideoOutputBinding {
  const IosPipVideoOutputBinding({
    required this.handle,
    required this.textureId,
    required this.isCurrent,
    required this.readVid,
    required this.writeVid,
  });

  final int handle;
  final ValueListenable<int?> textureId;
  final bool Function() isCurrent;
  final Future<String> Function() readVid;
  final Future<void> Function(String value) writeVid;
}

/// mpv must release its active video output before its render context is freed.
/// Audio and the player remain active while native code replaces that context.
class IosPipVideoOutputTransition {
  IosPipVideoOutputTransition({
    required this.resolveBinding,
    this.registrationTimeout = const Duration(seconds: 3),
  });

  final Future<IosPipVideoOutputBinding?> Function(int handle) resolveBinding;
  final Duration registrationTimeout;
  bool _disposed = false;
  Object? _reservation;
  _VideoOutputChange? _change;

  Future<bool> suspendVideo(int handle) async {
    if (_disposed || _reservation != null || _change != null) return false;
    final reservation = Object();
    _reservation = reservation;
    _VideoOutputChange? change;
    try {
      final binding = await resolveBinding(handle);
      if (_disposed ||
          binding == null ||
          binding.handle != handle ||
          !binding.isCurrent()) {
        return false;
      }
      final vid = await binding.readVid();
      if (_disposed || !binding.isCurrent() || vid.isEmpty) return false;
      change = _VideoOutputChange(binding, vid, binding.textureId.value);
      _change = change;
      var activeVid = '';
      try {
        await binding.writeVid('no');
        if (binding.isCurrent()) activeVid = await binding.readVid();
      } finally {
        change.suspensionDone.complete();
      }
      if (_disposed || !binding.isCurrent() || activeVid != 'no') {
        await _restoreVid(change);
        _clear(change);
        return false;
      }
      return true;
    } catch (error) {
      KazumiLogger().w('iOS PiP: output suspension failed', error: error);
      if (change != null) {
        await _restoreVid(change);
        _clear(change);
      }
      return false;
    } finally {
      if (identical(_reservation, reservation)) _reservation = null;
    }
  }

  Future<bool> resumeVideo(int handle) async {
    final change = _change;
    if (_disposed || change == null || change.binding.handle != handle) {
      return false;
    }
    return change.resuming ??= _resume(change);
  }

  Future<bool> _resume(_VideoOutputChange change) async {
    var registered = false;
    var restored = false;
    try {
      registered = await _waitForRegistration(change);
    } catch (error) {
      KazumiLogger().w('iOS PiP: texture registration failed', error: error);
    } finally {
      // Restore even after a timeout or failed Create. Leaving vid=no would
      // otherwise make the original player stay black after PiP closes.
      restored = await _restoreVid(change);
      _clear(change);
    }
    return registered && restored && !_disposed && change.binding.isCurrent();
  }

  Future<bool> _waitForRegistration(_VideoOutputChange change) async {
    final binding = change.binding;
    bool registered() =>
        binding.textureId.value != null &&
        binding.textureId.value != change.oldTextureId;
    if (_disposed || !binding.isCurrent()) return false;
    if (registered()) return true;

    final result = Completer<bool>();
    void complete(bool value) {
      if (!result.isCompleted) result.complete(value);
    }

    void listener() {
      if (_disposed || !binding.isCurrent()) {
        complete(false);
      } else if (registered()) {
        complete(true);
      }
    }

    final timer = Timer(registrationTimeout, () => complete(false));
    change.cancelWait = () => complete(false);
    binding.textureId.addListener(listener);
    try {
      // The registration may have arrived immediately before addListener.
      listener();
      return await result.future;
    } finally {
      timer.cancel();
      binding.textureId.removeListener(listener);
      change.cancelWait = null;
    }
  }

  Future<bool> _restoreVid(_VideoOutputChange change) {
    return change.restoring ??= () async {
      await change.suspensionDone.future;
      if (!change.binding.isCurrent()) return false;
      try {
        await change.binding.writeVid(change.vid);
        if (!change.binding.isCurrent()) return false;
        final actual = await change.binding.readVid();
        final restored =
            change.binding.isCurrent() &&
            (actual == change.vid ||
                (change.vid == 'auto' && actual.isNotEmpty && actual != 'no'));
        return restored;
      } catch (error) {
        KazumiLogger().w(
          'iOS PiP: video track restoration failed',
          error: error,
        );
        return false;
      }
    }();
  }

  void _clear(_VideoOutputChange change) {
    if (identical(_change, change)) _change = null;
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    final change = _change;
    if (change == null) return;
    change.cancelWait?.call();
    await _restoreVid(change);
    _clear(change);
  }
}

class _VideoOutputChange {
  _VideoOutputChange(this.binding, this.vid, this.oldTextureId);

  final IosPipVideoOutputBinding binding;
  final String vid;
  final int? oldTextureId;
  final Completer<void> suspensionDone = Completer<void>();
  Future<bool>? resuming;
  Future<bool>? restoring;
  void Function()? cancelWait;
}
