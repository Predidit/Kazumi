import 'dart:async';

/// Browser builds have no native application menu channel.
class PlayerMenuService {
  PlayerMenuService._();

  static Future<void> initialize(
    Map<String, FutureOr<void> Function()> actions,
  ) async {}

  static Future<void> dispose() async {}
}
