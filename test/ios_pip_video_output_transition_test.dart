import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kazumi/services/player/ios_pip_video_output_transition.dart';

void main() {
  late _Player current;
  late List<_Player> players;
  late IosPipVideoOutputTransition transition;

  IosPipVideoOutputTransition createTransition({
    Duration timeout = const Duration(seconds: 3),
  }) => IosPipVideoOutputTransition(
    registrationTimeout: timeout,
    resolveBinding: (handle) async {
      final player = current;
      if (player.handle != handle) return null;
      return IosPipVideoOutputBinding(
        handle: player.handle,
        textureId: player.textureId,
        isCurrent: () => identical(current, player),
        readVid: player.readVid,
        writeVid: player.writeVid,
      );
    },
  );

  setUp(() {
    current = _Player(7, 42);
    players = [current];
    transition = createTransition();
  });

  tearDown(() async {
    await transition.dispose();
    for (final player in players) {
      player.textureId.dispose();
    }
  });

  test(
    'disables vid before output change and restores only after new ID',
    () async {
      expect(await transition.suspendVideo(7), isTrue);
      expect(current.events, ['read:3', 'write:no', 'read:no']);
      expect(current.vid, 'no');

      final resumed = transition.resumeVideo(7);
      await Future<void>.delayed(Duration.zero);
      expect(current.vid, 'no');
      expect(current.textureId.hasRegisteredListeners, isTrue);
      current.textureId.value = 43;
      expect(await resumed, isTrue);
      expect(current.events, [
        'read:3',
        'write:no',
        'read:no',
        'write:3',
        'read:3',
      ]);
      expect(current.textureId.hasRegisteredListeners, isFalse);
    },
  );

  test('accepts a new ID registered before the did-change callback', () async {
    expect(await transition.suspendVideo(7), isTrue);
    current.textureId.value = 43;
    expect(await transition.resumeVideo(7), isTrue);
    expect(current.vid, '3');
    expect(current.textureId.hasRegisteredListeners, isFalse);
  });

  test(
    'both output changes preserve the track selected for that transition',
    () async {
      expect(await transition.suspendVideo(7), isTrue);
      current.textureId.value = 43;
      expect(await transition.resumeVideo(7), isTrue);
      current.vid = '5';
      expect(await transition.suspendVideo(7), isTrue);
      current.textureId.value = 44;
      expect(await transition.resumeVideo(7), isTrue);
      expect(current.events, [
        'read:3',
        'write:no',
        'read:no',
        'write:3',
        'read:3',
        'read:5',
        'write:no',
        'read:no',
        'write:5',
        'read:5',
      ]);
    },
  );

  test(
    'registration timeout still restores vid and removes its listener',
    () async {
      await transition.dispose();
      transition = createTransition(timeout: const Duration(milliseconds: 10));
      expect(await transition.suspendVideo(7), isTrue);
      expect(await transition.resumeVideo(7), isFalse);
      expect(current.vid, '3');
      expect(current.events, [
        'read:3',
        'write:no',
        'read:no',
        'write:3',
        'read:3',
      ]);
      expect(current.textureId.hasRegisteredListeners, isFalse);
    },
  );

  test('a failed suspension restores the captured track', () async {
    current.onWrite = (value) async {
      if (value == 'no') throw StateError('write failed after changing vid');
    };
    expect(await transition.suspendVideo(7), isFalse);
    expect(current.vid, '3');
    expect(current.events, ['read:3', 'write:no', 'write:3', 'read:3']);
    expect(current.textureId.hasRegisteredListeners, isFalse);
  });

  test(
    'an ignored vid=no write must not authorize destroying the output',
    () async {
      current.onWrite = (value) async {
        if (value == 'no') current.vid = '3';
      };
      expect(await transition.suspendVideo(7), isFalse);
      expect(current.vid, '3');
      expect(current.events, [
        'read:3',
        'write:no',
        'read:3',
        'write:3',
        'read:3',
      ]);
      expect(await transition.resumeVideo(7), isFalse);
    },
  );

  test('rejects mismatched handles without changing a player', () async {
    expect(await transition.suspendVideo(8), isFalse);
    expect(current.events, isEmpty);
    expect(await transition.suspendVideo(7), isTrue);
    expect(await transition.resumeVideo(8), isFalse);
    expect(current.events, ['read:3', 'write:no', 'read:no']);
    current.textureId.value = 43;
    expect(await transition.resumeVideo(7), isTrue);
  });

  test('replacement player cannot receive a late track restoration', () async {
    final old = current;
    expect(await transition.suspendVideo(7), isTrue);
    current = _Player(8, 100);
    players.add(current);
    expect(await transition.resumeVideo(7), isFalse);
    expect(current.vid, '3');
    expect(current.events, isEmpty);
    expect(old.events, ['read:3', 'write:no', 'read:no']);
    expect(old.textureId.hasRegisteredListeners, isFalse);
  });

  test('replacement during read prevents disabling either player', () async {
    final reading = Completer<void>();
    final read = Completer<String>();
    final old = current;
    old.onRead = () {
      reading.complete();
      return read.future;
    };
    final suspended = transition.suspendVideo(7);
    await reading.future;
    current = _Player(8, 100);
    players.add(current);
    read.complete('3');
    expect(await suspended, isFalse);
    expect(current.events, isEmpty);
    expect(old.events, ['read:3']);
  });

  test('dispose cancels registration and restores the same player', () async {
    expect(await transition.suspendVideo(7), isTrue);
    final resumed = transition.resumeVideo(7);
    await Future<void>.delayed(Duration.zero);
    expect(current.textureId.hasRegisteredListeners, isTrue);
    await transition.dispose();
    expect(await resumed, isFalse);
    expect(current.vid, '3');
    expect(current.events, [
      'read:3',
      'write:no',
      'read:no',
      'write:3',
      'read:3',
    ]);
    expect(current.textureId.hasRegisteredListeners, isFalse);
    expect(await transition.suspendVideo(7), isFalse);
    expect(await transition.resumeVideo(7), isFalse);
  });

  test('dispose waits for pending vid=no before restoring the track', () async {
    final writing = Completer<void>();
    final written = Completer<void>();
    current.onWrite = (value) async {
      if (value == 'no') {
        writing.complete();
        await written.future;
      }
    };
    final suspended = transition.suspendVideo(7);
    await writing.future;
    final disposed = transition.dispose();
    expect(current.vid, 'no');
    written.complete();
    expect(await suspended, isFalse);
    await disposed;
    expect(current.vid, '3');
    expect(current.events, [
      'read:3',
      'write:no',
      'read:no',
      'write:3',
      'read:3',
    ]);
  });

  test(
    'dispose after player replacement never writes to the new player',
    () async {
      final old = current;
      expect(await transition.suspendVideo(7), isTrue);
      current = _Player(8, 100);
      players.add(current);
      await transition.dispose();
      expect(current.events, isEmpty);
      expect(old.events, ['read:3', 'write:no', 'read:no']);
    },
  );
}

class _Player {
  _Player(this.handle, int id) : textureId = _TextureId(id);

  final int handle;
  final _TextureId textureId;
  final List<String> events = [];
  String vid = '3';
  Future<String> Function()? onRead;
  Future<void> Function(String)? onWrite;

  Future<String> readVid() async {
    events.add('read:$vid');
    return onRead == null ? vid : await onRead!();
  }

  Future<void> writeVid(String value) async {
    events.add('write:$value');
    vid = value;
    await onWrite?.call(value);
  }
}

class _TextureId extends ValueNotifier<int?> {
  _TextureId(super.value);

  bool get hasRegisteredListeners => hasListeners;
}
