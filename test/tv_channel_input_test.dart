import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kazumi/services/platform/tv_channel_input.dart';

void main() {
  test('TV channel input recognizes top-row and numpad digits', () {
    expect(tvDigitForLogicalKey(LogicalKeyboardKey.digit0), 0);
    expect(tvDigitForLogicalKey(LogicalKeyboardKey.digit2), 2);
    expect(tvDigitForLogicalKey(LogicalKeyboardKey.digit9), 9);
    expect(tvDigitForLogicalKey(LogicalKeyboardKey.numpad0), 0);
    expect(tvDigitForLogicalKey(LogicalKeyboardKey.numpad2), 2);
    expect(tvDigitForLogicalKey(LogicalKeyboardKey.numpad9), 9);
    expect(tvDigitForLogicalKey(LogicalKeyboardKey.arrowDown), isNull);
  });

  test('TV channel input emits every repeated digit as a new event', () {
    final controller = TvChannelInputController();
    addTearDown(controller.dispose);
    final events = <TvChannelDigitEvent?>[];
    controller.addListener(() => events.add(controller.value));

    controller.addDigit(2);
    controller.addDigit(2);
    controller.cancel();

    expect(events.map((event) => event?.digit), [2, 2, null]);
    expect(events[1]!.sequence, greaterThan(events[0]!.sequence));
  });
}
