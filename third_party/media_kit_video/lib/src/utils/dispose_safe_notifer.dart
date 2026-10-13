import 'package:flutter/widgets.dart';

class DisposeSafeNotifier<T> extends ValueNotifier<T> {
  bool disposed = false;
  DisposeSafeNotifier(super.value);

  @override
  void dispose() {
    disposed = true;
    super.dispose();
  }
}
