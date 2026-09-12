import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kazumi/pages/player/controller/interactive_seek_lifecycle.dart';

void main() {
  late Duration position;
  late bool playing;
  late List<String> actions;
  late InteractiveSeekLifecycle lifecycle;

  InteractiveSeekLifecycle createLifecycle() {
    return InteractiveSeekLifecycle(
      readPosition: () => position,
      isPlaying: () => playing,
      writePreview: (value) => position = value,
      normalize: (value) {
        final milliseconds = value.inMilliseconds.clamp(0, 60000).toInt();
        return Duration(milliseconds: milliseconds);
      },
      pause: () async {
        actions.add('pause');
        playing = false;
      },
      seek: (target) async {
        actions.add('seek:${target.inSeconds}');
        position = target;
      },
      play: () async {
        actions.add('play');
        playing = true;
      },
    );
  }

  setUp(() {
    position = const Duration(seconds: 10);
    playing = true;
    actions = <String>[];
    lifecycle = createLifecycle();
  });

  test('playing session pauses, seeks once, then resumes on commit', () async {
    lifecycle.begin();
    expect(lifecycle.update(const Duration(seconds: 35)), isTrue);
    expect(position, const Duration(seconds: 35));

    expect(await lifecycle.commit(), isTrue);

    expect(actions, <String>['pause', 'seek:35', 'play']);
    expect(position, const Duration(seconds: 35));
    expect(playing, isTrue);
    expect(lifecycle.hasActiveSession, isFalse);
  });

  test('paused session stays paused after commit', () async {
    playing = false;
    lifecycle.begin();
    lifecycle.update(const Duration(seconds: 20));

    expect(await lifecycle.commit(), isTrue);

    expect(actions, <String>['seek:20']);
    expect(playing, isFalse);
  });

  test('cancel restores position and the original playing state', () async {
    lifecycle.begin();
    lifecycle.update(const Duration(seconds: 40));

    expect(await lifecycle.cancel(), isTrue);

    expect(actions, <String>['pause', 'play']);
    expect(position, const Duration(seconds: 10));
    expect(playing, isTrue);
    expect(lifecycle.hasActiveSession, isFalse);
  });

  test('cancelled paused session neither seeks nor starts playback', () async {
    playing = false;
    lifecycle.begin();
    lifecycle.update(const Duration(seconds: 50));

    expect(await lifecycle.cancel(), isTrue);

    expect(actions, isEmpty);
    expect(position, const Duration(seconds: 10));
    expect(playing, isFalse);
  });

  test(
    'commit is idempotent while an asynchronous seek is in flight',
    () async {
      final seekGate = Completer<void>();
      var seekCount = 0;
      lifecycle = InteractiveSeekLifecycle(
        readPosition: () => position,
        isPlaying: () => false,
        writePreview: (value) => position = value,
        normalize: (value) => value,
        pause: () async {},
        seek: (_) async {
          seekCount += 1;
          await seekGate.future;
        },
        play: () async {},
      );
      lifecycle.begin();
      lifecycle.update(const Duration(seconds: 30));

      final first = lifecycle.commit();
      final second = lifecycle.commit();
      await Future<void>.delayed(Duration.zero);
      expect(seekCount, 1);

      seekGate.complete();
      expect(await first, isTrue);
      expect(await second, isTrue);
    },
  );

  test('a stalled media operation releases the interactive session', () async {
    final stalled = Completer<void>();
    lifecycle = InteractiveSeekLifecycle(
      readPosition: () => position,
      isPlaying: () => false,
      writePreview: (value) => position = value,
      normalize: (value) => value,
      pause: () async {},
      seek: (_) => stalled.future,
      play: () async {},
      operationTimeout: const Duration(milliseconds: 1),
    );
    lifecycle.begin();
    lifecycle.update(const Duration(seconds: 30));

    await expectLater(lifecycle.commit(), throwsA(isA<TimeoutException>()));
    expect(lifecycle.hasActiveSession, isFalse);
  });

  test('invalidating a pending pause prevents stale seek and play', () async {
    final pauseGate = Completer<void>();
    lifecycle = InteractiveSeekLifecycle(
      readPosition: () => position,
      isPlaying: () => true,
      writePreview: (value) => position = value,
      normalize: (value) => value,
      pause: () => pauseGate.future,
      seek: (_) async => actions.add('seek'),
      play: () async => actions.add('play'),
    );
    lifecycle.begin();
    lifecycle.update(const Duration(seconds: 30));
    final completion = lifecycle.commit();
    lifecycle.invalidate();
    pauseGate.complete();
    expect(await completion, isFalse);
    expect(actions, isEmpty);
    expect(lifecycle.hasActiveSession, isFalse);
  });

  test('failed seek releases the session and permits a new gesture', () async {
    lifecycle = InteractiveSeekLifecycle(
      readPosition: () => position,
      isPlaying: () => false,
      writePreview: (value) => position = value,
      normalize: (value) => value,
      pause: () async {},
      seek: (_) async => throw StateError('backend failure'),
      play: () async {},
    );
    lifecycle.begin();
    await expectLater(lifecycle.commit(), throwsStateError);
    expect(lifecycle.hasActiveSession, isFalse);
    lifecycle.begin();
    expect(lifecycle.update(const Duration(seconds: 25)), isTrue);
    expect(await lifecycle.cancel(), isTrue);
  });
}
