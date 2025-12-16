import 'dart:async';
import 'package:window_manager/window_manager.dart';
import 'package:kazumi/utils/storage.dart';

class WindowState with WindowListener {
  Timer? _resizeWait;
  Timer? _moveWait;

  static const _waitDuration = Duration(milliseconds: 300);

  Future<void> _saveSize() async {
    final size = await windowManager.getSize();
    final last = Map<String, double>.from(
      GStorage.setting.get('lastWindowState', defaultValue: {}),
    );

    GStorage.setting.put('lastWindowState', {
      ...last,
      'width': size.width,
      'height': size.height,
    });
  }

  Future<void> _savePosition() async {
    final pos = await windowManager.getPosition();
    final last = Map<String, double>.from(
      GStorage.setting.get('lastWindowState', defaultValue: {}),
    );

    GStorage.setting.put('lastWindowState', {
      ...last,
      'x': pos.dx,
      'y': pos.dy,
    });
  }

  @override
  void onWindowResized() {
    _resizeWait?.cancel();
    _resizeWait = Timer(_waitDuration, _saveSize);
  }

  @override
  void onWindowMoved() {
    _moveWait?.cancel();
    _moveWait = Timer(_waitDuration, _savePosition);
  }

  void dispose() {
    _resizeWait?.cancel();
    _moveWait?.cancel();
  }
}
