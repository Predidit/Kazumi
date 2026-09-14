import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:mobx/mobx.dart';

/// Explicit fullscreen owns a local history entry; rotation does not.
class VideoFullscreenController {
  VideoFullscreenController({
    required Future<void> Function(bool fullscreen) applyFullscreen,
  }) : _applyFullscreen = applyFullscreen;

  final Future<void> Function(bool fullscreen) _applyFullscreen;
  final Observable<LocalHistoryEntry?> _entry = Observable(null);
  ModalRoute<dynamic>? _route;
  int _revision = 0;
  int _pendingRequests = 0;
  Future<void> _lastRequest = Future.value();
  Future<void>? _closeFuture;

  bool get isFullscreen => _entry.value != null;

  void attach(ModalRoute<dynamic> route) {
    assert(_route == null || identical(_route, route));
    _route = route;
  }

  Future<void> toggle() => setFullscreen(!isFullscreen);

  Future<void> setFullscreen(bool fullscreen) =>
      _setFullscreen(fullscreen, updatePlatform: true);

  Future<void> _setFullscreen(bool fullscreen, {required bool updatePlatform}) {
    if (_closeFuture != null || fullscreen == isFullscreen) return _lastRequest;
    final route = _route;
    if (route == null) {
      throw StateError('Attach the video route before entering fullscreen.');
    }
    _revision++;
    if (fullscreen) {
      late final LocalHistoryEntry entry;
      entry = LocalHistoryEntry(
        impliesAppBarDismissal: false,
        onRemove: () {
          if (!identical(_entry.value, entry)) return;
          _revision++;
          _setEntry(null);
          unawaited(_requestFullscreen(false));
        },
      );
      route.addLocalHistoryEntry(entry);
      _setEntry(entry);
    } else {
      _removeEntry();
    }
    return updatePlatform ? _requestFullscreen(fullscreen) : Future.value();
  }

  void _setEntry(LocalHistoryEntry? entry) {
    runInAction(() => _entry.value = entry);
  }

  void _removeEntry() {
    final entry = _entry.value;
    _setEntry(null);
    entry?.remove();
  }

  void onDesktopFullscreenChanged(bool fullscreen) {
    // Ignore acknowledgements of commands still in flight.
    if (_pendingRequests != 0) return;
    unawaited(_setFullscreen(fullscreen, updatePlatform: false));
  }

  Future<void> initializeDesktop(Future<bool> Function() readFullscreen) async {
    final revision = _revision;
    final fullscreen = await readFullscreen();
    if (revision == _revision) onDesktopFullscreenChanged(fullscreen);
  }

  Future<void> _requestFullscreen(bool fullscreen) {
    _pendingRequests++;
    return _lastRequest = _applyFullscreen(fullscreen).whenComplete(() {
      _pendingRequests--;
    });
  }

  Future<void> close() {
    if (_closeFuture != null) return _closeFuture!;
    _revision++;
    _removeEntry();
    _route = null;
    return _closeFuture = _requestFullscreen(false);
  }
}
