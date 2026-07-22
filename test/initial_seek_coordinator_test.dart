import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kazumi/services/player/initial_seek_coordinator.dart';

void main() {
  test('waits for metadata before applying a Web resume offset', () async {
    final durations = StreamController<Duration>();
    addTearDown(durations.close);
    final seeks = <Duration>[];

    final result = applyInitialSeekAfterOpen(
      enabled: true,
      offset: const Duration(seconds: 42),
      currentDuration: Duration.zero,
      durationChanges: durations.stream,
      seek: (position) async => seeks.add(position),
      isCurrent: () => true,
    );

    expect(seeks, isEmpty);
    durations.add(const Duration(minutes: 24));

    expect(await result, isTrue);
    expect(seeks, <Duration>[const Duration(seconds: 42)]);
  });

  test('does not seek native, zero-offset, or stale playback', () async {
    final seeks = <Duration>[];
    Future<void> seek(Duration position) async => seeks.add(position);

    expect(
      await applyInitialSeekAfterOpen(
        enabled: false,
        offset: const Duration(seconds: 10),
        currentDuration: const Duration(minutes: 1),
        durationChanges: const Stream<Duration>.empty(),
        seek: seek,
        isCurrent: () => true,
      ),
      isFalse,
    );
    expect(
      await applyInitialSeekAfterOpen(
        enabled: true,
        offset: Duration.zero,
        currentDuration: const Duration(minutes: 1),
        durationChanges: const Stream<Duration>.empty(),
        seek: seek,
        isCurrent: () => true,
      ),
      isFalse,
    );
    expect(
      await applyInitialSeekAfterOpen(
        enabled: true,
        offset: const Duration(seconds: 10),
        currentDuration: const Duration(minutes: 1),
        durationChanges: const Stream<Duration>.empty(),
        seek: seek,
        isCurrent: () => false,
      ),
      isFalse,
    );
    expect(seeks, isEmpty);
  });

  test('drops a pending seek when playback ownership changes', () async {
    final durations = StreamController<Duration>();
    addTearDown(durations.close);
    var current = true;
    var seekCalls = 0;

    final result = applyInitialSeekAfterOpen(
      enabled: true,
      offset: const Duration(seconds: 10),
      currentDuration: Duration.zero,
      durationChanges: durations.stream,
      seek: (_) async => seekCalls++,
      isCurrent: () => current,
    );
    current = false;
    durations.add(const Duration(minutes: 1));

    expect(await result, isFalse);
    expect(seekCalls, 0);
  });
}
