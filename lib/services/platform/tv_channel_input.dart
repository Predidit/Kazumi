import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

@immutable
class TvChannelDigitEvent {
  const TvChannelDigitEvent({
    required this.digit,
    required this.sequence,
  });

  final int digit;
  final int sequence;
}

/// Bridges number keys caught by the TV shell to the home recommendation grid.
///
/// The shell owns the remote event because focus may still be on the navigation
/// rail. The home page owns buffering, preview and navigation because it knows
/// the current card order.
class TvChannelInputController extends ValueNotifier<TvChannelDigitEvent?> {
  TvChannelInputController() : super(null);

  int _sequence = 0;

  void addDigit(int digit) {
    assert(digit >= 0 && digit <= 9);
    value = TvChannelDigitEvent(digit: digit, sequence: ++_sequence);
  }

  void cancel() {
    value = null;
  }
}

final tvChannelInputController = TvChannelInputController();

int? tvDigitForLogicalKey(LogicalKeyboardKey key) {
  final digits = <LogicalKeyboardKey, int>{
    LogicalKeyboardKey.digit0: 0,
    LogicalKeyboardKey.digit1: 1,
    LogicalKeyboardKey.digit2: 2,
    LogicalKeyboardKey.digit3: 3,
    LogicalKeyboardKey.digit4: 4,
    LogicalKeyboardKey.digit5: 5,
    LogicalKeyboardKey.digit6: 6,
    LogicalKeyboardKey.digit7: 7,
    LogicalKeyboardKey.digit8: 8,
    LogicalKeyboardKey.digit9: 9,
    LogicalKeyboardKey.numpad0: 0,
    LogicalKeyboardKey.numpad1: 1,
    LogicalKeyboardKey.numpad2: 2,
    LogicalKeyboardKey.numpad3: 3,
    LogicalKeyboardKey.numpad4: 4,
    LogicalKeyboardKey.numpad5: 5,
    LogicalKeyboardKey.numpad6: 6,
    LogicalKeyboardKey.numpad7: 7,
    LogicalKeyboardKey.numpad8: 8,
    LogicalKeyboardKey.numpad9: 9,
  };
  return digits[key];
}
