import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kazumi/services/player/syncplay_playback_coordinator.dart';

void main() {
  test(
    'requires persistent same-direction drift and resamples after seek',
    () async {
      final player = _Player();
      addTearDown(player.coordinator.dispose);
      await player.update(102);
      player.time += const Duration(seconds: 1);
      await player.update(98);
      player.time += const Duration(seconds: 1);
      await player.update(102);
      player.time += const Duration(seconds: 1);
      await player.update(102);
      expect(player.seeks, isEmpty);
      player.time += const Duration(seconds: 1);
      await player.update(102);
      expect(player.seeks, [102]);
      expect(player.samples, [102]);
      await player.update(102);
      expect(player.seeks, hasLength(1));
    },
  );

  test(
    'waits for operations and observed position before correcting again',
    () async {
      final player = _Player();
      addTearDown(player.coordinator.dispose);
      final completed = Completer<void>();
      player.seekOperation = (_) => completed.future;
      player.coordinator.update(position: 200, paused: true, doSeek: true);
      await Future<void>.delayed(Duration.zero);
      for (var i = 0; i < 4; i++) {
        player.time += const Duration(seconds: 1);
        player.coordinator.update(position: 200, paused: true);
      }
      expect(player.seeks, [200]);
      completed.complete();
      await player.coordinator.idle;
      expect(player.samples, [100]);
      for (var i = 0; i < 4; i++) {
        player.time += const Duration(seconds: 1);
        await player.update(200);
      }
      expect(player.seeks, [200]);
      player.actualPosition = 200;
      await player.update(200);
      expect(player.samples.last, 200);
      expect(player.seeks, [200]);
      player.coordinator.update(position: 300, paused: true, doSeek: true);
      await player.coordinator.idle;
      player.time += const Duration(seconds: 5);
      await player.update(300);
      expect(player.seeks, [200, 300]);
      await player.update(300);
      player.time += const Duration(seconds: 2);
      await player.update(300);
      expect(player.seeks, [200, 300, 300]);
    },
  );

  test('keeps explicit controls while coalescing heartbeats', () async {
    final player = _Player();
    addTearDown(player.coordinator.dispose);
    final started = Completer<void>();
    player.playOperation = () => started.future;
    player.coordinator.update(position: 100, paused: false);
    await Future<void>.delayed(Duration.zero);
    player.coordinator.update(position: 300, paused: false, doSeek: true);
    player.coordinator.update(position: 301, paused: false);
    player.coordinator.update(position: 300, paused: true);
    expect(player.operations, ['play']);
    player.isPlaying = true;
    started.complete();
    await player.coordinator.idle;
    expect(player.operations, ['play', 'seek', 'pause']);
    expect(player.seeks, [300]);
    expect(player.isPlaying, isFalse);
  });

  test(
    'opposite controls execute even while observation still reports old state',
    () async {
      final player = _Player();
      addTearDown(player.coordinator.dispose);
      player.isPlaying = true;
      player.pauseOperation = () async {};
      player.coordinator.update(position: 100, paused: true);
      await player.coordinator.idle;
      expect(player.isPlaying, isTrue);
      player.coordinator.update(position: 100, paused: false);
      await player.coordinator.idle;
      expect(player.operations, ['pause', 'play']);
    },
  );

  test('disposal and failure discard queued work', () async {
    for (final fail in [false, true]) {
      final player = _Player();
      final started = Completer<void>();
      player.playOperation = () => started.future;
      player.coordinator.update(position: 100, paused: false);
      await Future<void>.delayed(Duration.zero);
      player.coordinator.update(position: 300, paused: false, doSeek: true);
      if (fail) {
        started.completeError(StateError('player failed'));
      } else {
        player.coordinator.dispose();
        started.complete();
      }
      await player.coordinator.idle;
      expect(player.seeks, isEmpty);
      expect(player.samples, isEmpty);
      expect(player.errors, fail ? hasLength(1) : isEmpty);
      player.coordinator.dispose();
    }
  });
}

class _Player {
  Duration time = Duration.zero;
  double actualPosition = 100;
  bool isPlaying = false;
  final seeks = <double>[];
  final samples = <double>[];
  final operations = <String>[];
  final errors = <Object>[];
  Future<void> Function(double)? seekOperation;
  Future<void> Function()? playOperation;
  Future<void> Function()? pauseOperation;

  late final coordinator = SyncplayPlaybackCoordinator(
    playing: () => isPlaying,
    position: () => actualPosition,
    duration: () => 1000,
    now: () => time,
    pause: () async {
      operations.add('pause');
      if (pauseOperation != null) {
        await pauseOperation!();
      } else {
        isPlaying = false;
      }
    },
    play: () async {
      operations.add('play');
      if (playOperation != null) {
        await playOperation!();
      } else {
        isPlaying = true;
      }
    },
    seek: (target) async {
      operations.add('seek');
      seeks.add(target);
      if (seekOperation != null) {
        await seekOperation!(target);
      } else {
        actualPosition = target;
      }
    },
    onPositionSample: samples.add,
    onError: (error, _) => errors.add(error),
  );

  Future<void> update(double target) async {
    coordinator.update(position: target, paused: true);
    await coordinator.idle;
  }
}
