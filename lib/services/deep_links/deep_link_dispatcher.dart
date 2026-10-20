import 'dart:async';

import 'kazumi_deep_link.dart';

/// Retains the latest link until startup/onboarding finishes. A newer request
/// invalidates an older asynchronous lookup before it can change navigation.
class DeepLinkDispatcher {
  DeepLinkDispatcher({required this.onOpen, required this.onError});

  final Future<void> Function(KazumiDeepLink, bool Function()) onOpen;
  final void Function(Object, StackTrace) onError;
  KazumiDeepLink? _pending;
  bool _ready = false;
  int _generation = 0;

  void receive(Uri uri) {
    KazumiDeepLink? link;
    try {
      link = KazumiDeepLink.parse(uri);
    } on FormatException {
      return;
    }
    if (link == null) return;
    _pending = link;
    _generation++;
    _dispatch();
  }

  void markReady() {
    _ready = true;
    _dispatch();
  }

  void _dispatch() {
    final link = _pending;
    if (!_ready || link == null) return;
    _pending = null;
    final generation = _generation;
    bool isCurrent() => generation == _generation;
    unawaited(() async {
      try {
        await onOpen(link, isCurrent);
      } catch (error, stackTrace) {
        if (isCurrent()) onError(error, stackTrace);
      }
    }());
  }
}
