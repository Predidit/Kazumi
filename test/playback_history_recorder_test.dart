import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kazumi/services/player/playback_history_recorder.dart';

void main() {
  late List<int> writes;
  late PlaybackHistoryRecorder recorder;
  Future<void> sample(int milliseconds,
          {bool playing = false, int length = 90000}) =>
      recorder.record(
          position: Duration(milliseconds: milliseconds),
          duration: Duration(milliseconds: length),
          playing: playing);

  setUp(() {
    writes = [];
    recorder = PlaybackHistoryRecorder((position, duration) async {
      writes.add(position.inMilliseconds);
    });
  });

  test('prepared or paused media never played cannot create history', () async {
    await sample(12000);
    expect(writes, isEmpty);
  });

  test('paused seek saves newer native position and allows backward to zero',
      () async {
    await sample(21500, playing: true);
    await sample(41800);
    await sample(0);
    expect(writes, [21500, 41800, 0]);
  });

  test('native play then pause before first timer still permits final capture',
      () async {
    recorder.observePlaying(true);
    recorder.observePlaying(false);
    await sample(500);
    expect(writes, [500]);
  });

  test('unchanged paused snapshots are written once', () async {
    await sample(10000, playing: true);
    await sample(10000);
    await sample(10000);
    expect(writes, [10000]);
  });

  test('unknown duration and out-of-range positions cannot replace history',
      () async {
    await sample(10000, playing: true);
    await sample(-1);
    await sample(91000);
    await sample(0, length: 0);
    expect(writes, [10000]);
  });

  test('new media session does not inherit the previous playing state',
      () async {
    await sample(10000, playing: true);
    recorder = PlaybackHistoryRecorder((position, duration) async {
      writes.add(position.inMilliseconds);
    });
    await sample(20000);
    expect(writes, [10000]);
  });

  test('overlapping periodic and final captures preserve their order',
      () async {
    final gate = Completer<void>();
    recorder = PlaybackHistoryRecorder((position, duration) async {
      if (position.inMilliseconds == 10000) await gate.future;
      writes.add(position.inMilliseconds);
    });
    final periodic = sample(10000, playing: true);
    final finalCapture = sample(5000);
    gate.complete();
    await Future.wait([periodic, finalCapture]);
    expect(writes, [10000, 5000]);
  });

  test('failed write can be retried without poisoning subsequent captures',
      () async {
    var fail = true;
    recorder = PlaybackHistoryRecorder((position, duration) async {
      if (fail) {
        fail = false;
        throw StateError('storage unavailable');
      }
      writes.add(position.inMilliseconds);
    });
    await expectLater(sample(10000, playing: true), throwsStateError);
    await sample(10000);
    expect(writes, [10000]);
  });
}
