import 'package:flutter_test/flutter_test.dart';
import 'package:kazumi/pages/player/controller/player_danmaku_controller.dart';

void main() {
  group('DanmakuTimeline', () {
    test('applies positive and negative offsets to source time', () {
      expect(
        DanmakuTimeline.resolveSourceSecond(
          const Duration(milliseconds: 5500),
          1.5,
        ),
        4,
      );
      expect(
        DanmakuTimeline.resolveSourceSecond(
          const Duration(milliseconds: 5500),
          -1.5,
        ),
        7,
      );
      expect(
        DanmakuTimeline.resolveSourceSecond(
          const Duration(milliseconds: 500),
          1,
        ),
        isNull,
      );
    });

    test('staggering distributes a burst within one second', () {
      expect(
        [
          for (var i = 0; i < 4; i++)
            DanmakuTimeline.staggerDelayMilliseconds(index: i, total: 4)
        ],
        [0, 250, 500, 750],
      );
    });
  });

  group('DanmakuTimelineCursor', () {
    test('does not duplicate a slow or paused media second', () {
      final cursor = DanmakuTimelineCursor();
      expect(cursor.advance(12), [12]);
      expect(cursor.advance(12), isEmpty);
      expect(cursor.advance(12), isEmpty);
      expect(cursor.advance(13), [13]);
    });

    test('catches up small gaps caused by faster playback', () {
      final cursor = DanmakuTimelineCursor();
      expect(cursor.advance(20), [20]);
      expect(cursor.advance(22), [21, 22]);
    });

    test('large seeks and backward seeks restart at current second only', () {
      final cursor = DanmakuTimelineCursor();
      expect(cursor.advance(20), [20]);
      expect(cursor.advance(90), [90]);
      expect(cursor.advance(8), [8]);
    });

    test('reset permits the current second after seek invalidation', () {
      final cursor = DanmakuTimelineCursor();
      expect(cursor.advance(33), [33]);
      expect(cursor.advance(33), isEmpty);
      cursor.reset();
      expect(cursor.advance(33), [33]);
    });
  });
}
