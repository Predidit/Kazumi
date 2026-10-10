import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kazumi/services/player/ios_pip_controller.dart';
import 'package:kazumi/services/player/ios_pip_video_output_transition.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('test/ios_pip');
  const codec = StandardMethodCodec();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late IosPipController controller;
  late List<MethodCall> calls;
  late List<String> actions;
  late List<(bool, bool)> modes;
  late bool restore;
  late Future<int?> Function() handle;
  late Future<bool> Function(int handle) suspendVideo;
  late Future<bool> Function(int handle) resumeVideo;
  late IosPipPlaybackState state;

  Future<Object?> emit(String method, [Object? args]) async {
    final result = Completer<Object?>();
    await messenger.handlePlatformMessage(
      channel.name,
      codec.encodeMethodCall(MethodCall(method, args)),
      (data) {
        result.complete(data == null ? null : codec.decodeEnvelope(data));
      },
    );
    return result.future;
  }

  setUp(() {
    calls = [];
    actions = [];
    modes = [];
    restore = true;
    handle = () async => 7;
    suspendVideo = (handle) async {
      actions.add('suspend:$handle');
      return true;
    };
    resumeVideo = (handle) async {
      actions.add('resume:$handle');
      return true;
    };
    state = const IosPipPlaybackState(
      textureId: 42,
      playing: true,
      position: Duration(seconds: 30),
      duration: Duration(minutes: 20),
      rate: 1.5,
      sourceRect: Rect.fromLTWH(12, 80, 360, 202.5),
    );
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return switch (call.method) {
        'isSupported' || 'prepare' || 'enter' => true,
        _ => null,
      };
    });
    controller = IosPipController(
      channel: channel,
      playbackState: () => state,
      playerHandle: () => handle(),
      suspendVideo: (handle) => suspendVideo(handle),
      resumeVideo: (handle) => resumeVideo(handle),
      onPlay: () async {
        actions.add('play');
      },
      onPause: () async {
        actions.add('pause');
      },
      onSeek: (position) async {
        actions.add('seek:${position.inMilliseconds}');
      },
      onModeChanged: (active, restored) => modes.add((active, restored)),
      canRestore: () => restore,
    );
  });

  IosPipController replacementController(List<String> replacementActions) {
    final replacement = IosPipController(
      channel: const MethodChannel('test/ios_pip'),
      playbackState: () => state,
      playerHandle: () async => 8,
      suspendVideo: (handle) async {
        replacementActions.add('suspend:$handle');
        return true;
      },
      resumeVideo: (handle) async {
        replacementActions.add('resume:$handle');
        return true;
      },
      onPlay: () async {
        replacementActions.add('play');
      },
      onPause: () async {
        replacementActions.add('pause');
      },
      onSeek: (_) async {},
      onModeChanged: (_, _) {},
      canRestore: () => true,
    );
    addTearDown(replacement.dispose);
    return replacement;
  }

  tearDown(() async {
    await controller.dispose();
    messenger.setMockMethodCallHandler(channel, null);
  });

  test(
    'prepares current texture, logical bounds and playback before entering',
    () async {
      expect(await controller.enter(), IosPipEntryResult.entered);
      expect(calls.map((call) => call.method), [
        'isSupported',
        'prepare',
        'updatePlaybackState',
        'enter',
      ]);
      expect(calls[1].arguments, {
        'handle': 7,
        'textureId': 42,
        'playing': true,
        'positionMillis': 30000,
        'durationMillis': 1200000,
        'rate': 1.5,
        'sourceRect': {
          'left': 12.0,
          'top': 80.0,
          'width': 360.0,
          'height': 202.5,
        },
      });
      expect(controller.keepPlaybackInBackground, isTrue);
      expect(await controller.enter(), IosPipEntryResult.entered);
      expect(calls, hasLength(4));
    },
  );

  test(
    'waits for the replacement texture state to synchronize before entering',
    () async {
      final prepared = Completer<bool>();
      final preparing = Completer<void>();
      final synchronized = Completer<void>();
      final synchronizing = Completer<void>();
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        if (call.method == 'prepare') {
          preparing.complete();
          return prepared.future;
        }
        if (call.method == 'updatePlaybackState') {
          synchronizing.complete();
          await synchronized.future;
          return null;
        }
        return true;
      });
      final pending = controller.enter();
      await preparing.future;
      state = const IosPipPlaybackState(
        textureId: 77,
        playing: false,
        position: Duration(seconds: 50),
        duration: Duration(minutes: 10),
        rate: 1,
        sourceRect: Rect.fromLTWH(0, 0, 800, 450),
      );
      prepared.complete(true);
      await synchronizing.future;
      expect(calls[1].arguments['textureId'], 42);
      expect(calls.last.method, 'updatePlaybackState');
      expect(calls.last.arguments, state.toArguments());
      expect(controller.keepPlaybackInBackground, isTrue);
      synchronized.complete();
      expect(await pending, IosPipEntryResult.entered);
      expect(calls.map((call) => call.method), [
        'isSupported',
        'prepare',
        'updatePlaybackState',
        'enter',
      ]);
    },
  );

  test(
    'unsupported device never prepares or changes background policy',
    () async {
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        return false;
      });
      expect(await controller.enter(), IosPipEntryResult.unsupported);
      expect(calls.map((call) => call.method), ['isSupported']);
      expect(controller.keepPlaybackInBackground, isFalse);
    },
  );

  test('missing native bridge is treated as unsupported', () async {
    messenger.setMockMethodCallHandler(channel, null);
    expect(await IosPipController.isSupported(channel: channel), isFalse);
    expect(await controller.enter(), IosPipEntryResult.unsupported);
    expect(controller.keepPlaybackInBackground, isFalse);
  });

  test('does not enter before a video frame and source bounds exist', () async {
    state = const IosPipPlaybackState(
      textureId: null,
      playing: true,
      position: Duration.zero,
      duration: Duration.zero,
      rate: 1,
      sourceRect: null,
    );
    expect(await controller.enter(), IosPipEntryResult.notReady);
    expect(calls, isEmpty);
  });

  test(
    'keeps playback during entry, releases policy on failed entry',
    () async {
      final entered = Completer<bool>();
      final entering = Completer<void>();
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        if (call.method == 'enter') {
          entering.complete();
          return entered.future;
        }
        return true;
      });
      final pending = controller.enter();
      await entering.future;
      expect(controller.keepPlaybackInBackground, isTrue);
      expect(await controller.enter(), IosPipEntryResult.notReady);
      entered.complete(false);
      expect(await pending, IosPipEntryResult.failed);
      expect(controller.keepPlaybackInBackground, isFalse);
    },
  );

  test('native readiness timeout releases the background policy', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      if (call.method == 'enter') {
        throw PlatformException(code: 'pip_not_ready');
      }
      return true;
    });
    expect(await controller.enter(), IosPipEntryResult.notReady);
    expect(controller.keepPlaybackInBackground, isFalse);
    expect(controller.isActive, isFalse);
  });

  test(
    'other native errors remain failed and release the background policy',
    () async {
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        if (call.method == 'enter') {
          throw PlatformException(code: 'pip_start_failed');
        }
        return true;
      });
      expect(await controller.enter(), IosPipEntryResult.failed);
      expect(controller.keepPlaybackInBackground, isFalse);
      expect(controller.isActive, isFalse);
    },
  );

  test(
    'forwards play and pause, clamps native seeks to the current video',
    () async {
      await controller.enter();
      await emit('onAction', {'action': 'play'});
      await emit('onAction', {'action': 'pause'});
      await emit('onAction', {'action': 'seek', 'positionMillis': -15000});
      await emit('onAction', {'action': 'seek', 'positionMillis': 2000000});
      expect(actions, ['play', 'pause', 'seek:0', 'seek:1200000']);
      expect(
        calls.where((call) => call.method == 'updatePlaybackState'),
        hasLength(5),
      );
    },
  );

  test('distinguishes restoration from closing the small window', () async {
    await controller.enter();
    expect(await emit('onRestore'), isTrue);
    await emit('onModeChanged', {'isInPipMode': false, 'restored': true});
    expect(modes, [(false, true)]);
    expect(controller.keepPlaybackInBackground, isFalse);
    restore = false;
    expect(await emit('onRestore'), isFalse);
    await controller.enter();
    await emit('onModeChanged', {'isInPipMode': false});
    expect(modes.last, (false, false));
  });

  test(
    'synchronizes replacement texture and suppresses idle updates',
    () async {
      await controller.synchronize();
      expect(calls, isEmpty);
      await controller.enter();
      state = const IosPipPlaybackState(
        textureId: 77,
        playing: false,
        position: Duration(seconds: 50),
        duration: Duration(minutes: 10),
        rate: 1,
        sourceRect: Rect.fromLTWH(0, 0, 800, 450),
      );
      await controller.synchronize();
      expect(calls.last.arguments['textureId'], 77);
      expect(calls.last.arguments['playing'], false);
    },
  );

  test(
    'dispose while support is pending cannot create a late session',
    () async {
      final support = Completer<bool>();
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        return call.method == 'isSupported' ? support.future : null;
      });
      final pending = controller.enter();
      await controller.dispose();
      support.complete(true);
      expect(await pending, IosPipEntryResult.failed);
      expect(controller.keepPlaybackInBackground, isFalse);
      expect(calls.map((call) => call.method), ['isSupported', 'dispose']);
      await controller.dispose();
      expect(calls, hasLength(2));
    },
  );

  test('dispose while preparing cannot synchronize or enter', () async {
    final prepared = Completer<bool>();
    final preparing = Completer<void>();
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      if (call.method == 'prepare') {
        preparing.complete();
        return prepared.future;
      }
      return true;
    });
    final pending = controller.enter();
    await preparing.future;
    await controller.dispose();
    prepared.complete(true);
    expect(await pending, IosPipEntryResult.failed);
    expect(controller.keepPlaybackInBackground, isFalse);
    expect(calls.map((call) => call.method), [
      'isSupported',
      'prepare',
      'dispose',
    ]);
  });

  test('dispose while synchronizing before entry cannot enter', () async {
    final synchronized = Completer<void>();
    final synchronizing = Completer<void>();
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      if (call.method == 'updatePlaybackState') {
        synchronizing.complete();
        await synchronized.future;
        return null;
      }
      return true;
    });
    final pending = controller.enter();
    await synchronizing.future;
    await controller.dispose();
    synchronized.complete();
    expect(await pending, IosPipEntryResult.failed);
    expect(controller.keepPlaybackInBackground, isFalse);
    expect(calls.map((call) => call.method), [
      'isSupported',
      'prepare',
      'updatePlaybackState',
      'dispose',
    ]);
  });

  test('output transitions are forwarded while PiP is idle', () async {
    expect(controller.keepPlaybackInBackground, isFalse);
    expect(await emit('onVideoOutputWillChange', {'handle': 7}), isTrue);
    expect(await emit('onVideoOutputDidChange', {'handle': 7}), isTrue);
    expect(actions, ['suspend:7', 'resume:7']);
    expect(controller.keepPlaybackInBackground, isFalse);
    expect(await emit('onVideoOutputWillChange', {'handle': '7'}), isFalse);
    expect(await emit('onVideoOutputDidChange'), isFalse);
    expect(actions, ['suspend:7', 'resume:7']);
  });

  test('output transition callback failures reach native code', () async {
    suspendVideo = (_) async => false;
    resumeVideo = (_) async => false;
    expect(await emit('onVideoOutputWillChange', {'handle': 7}), isFalse);
    expect(await emit('onVideoOutputDidChange', {'handle': 7}), isFalse);
  });

  test('ignores stale native playback commands after leaving PiP', () async {
    await emit('onAction', {'action': 'play'});
    await emit('onModeChanged', {'isInPipMode': true});
    expect(actions, isEmpty);
    expect(controller.isActive, isFalse);
    expect(modes, isEmpty);
  });

  test(
    'does not reconfigure video output after the player was replaced',
    () async {
      handle = () async => null;
      expect(await controller.enter(), IosPipEntryResult.notReady);
      expect(calls.map((call) => call.method), ['isSupported']);
      expect(controller.keepPlaybackInBackground, isFalse);
    },
  );

  test('dispose while fetching the handle cannot recreate an output', () async {
    final handleReady = Completer<int?>();
    final handleRequested = Completer<void>();
    handle = () {
      handleRequested.complete();
      return handleReady.future;
    };
    final pending = controller.enter();
    await handleRequested.future;
    await controller.dispose();
    handleReady.complete(7);
    expect(await pending, IosPipEntryResult.failed);
    expect(calls.map((call) => call.method), ['isSupported', 'dispose']);
  });

  test('disposal drains native context changes before restoring vid', () async {
    final texture = ValueNotifier<int?>(42);
    final events = <String>[];
    var vid = '3';
    final transition = IosPipVideoOutputTransition(
      resolveBinding: (handle) async => IosPipVideoOutputBinding(
        handle: handle,
        textureId: texture,
        isCurrent: () => true,
        readVid: () async => vid,
        writeVid: (value) async {
          events.add('vid:$value');
          vid = value;
        },
      ),
    );
    addTearDown(() async {
      await transition.dispose();
      texture.dispose();
    });
    suspendVideo = transition.suspendVideo;
    resumeVideo = transition.resumeVideo;
    await controller.enter();
    expect(await emit('onVideoOutputWillChange', {'handle': 7}), isTrue);
    final disposalStarted = Completer<void>();
    final nativeDrained = Completer<void>();
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      if (call.method == 'dispose') {
        disposalStarted.complete();
        await nativeDrained.future;
      }
      return null;
    });
    final disposed = controller.dispose().then((_) => transition.dispose());
    await disposalStarted.future;
    expect(vid, 'no');
    events.add('free-context:$vid');
    texture.value = 43;
    // The page is disposed, but its native render transition still owns vid.
    expect(await emit('onVideoOutputDidChange', {'handle': 7}), isTrue);
    expect(events, ['vid:no', 'free-context:no', 'vid:3']);
    nativeDrained.complete();
    await disposed;
    expect(await controller.enter(), IosPipEntryResult.failed);
  });

  test(
    'new page waits for the old native owner and retains its handler',
    () async {
      await controller.enter();
      expect(await emit('onVideoOutputWillChange', {'handle': 7}), isTrue);
      final disposalStarted = Completer<void>();
      final nativeDrained = Completer<void>();
      var disposals = 0;
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        if (call.method == 'dispose') {
          disposals++;
          if (disposals == 1) {
            disposalStarted.complete();
            await nativeDrained.future;
          }
          return null;
        }
        return true;
      });
      final replacementActions = <String>[];
      final replacement = replacementController(replacementActions);
      final replaced = replacement.enter();
      await disposalStarted.future;
      expect(calls.where((call) => call.method == 'prepare'), hasLength(1));
      expect(await emit('onVideoOutputDidChange', {'handle': 7}), isTrue);
      await emit('onAction', {'action': 'play'});
      expect(actions, ['suspend:7', 'resume:7']);
      expect(replacementActions, isEmpty);
      nativeDrained.complete();
      expect(await replaced, IosPipEntryResult.entered);
      await controller.dispose();
      expect(disposals, 1);
      expect(await emit('onVideoOutputWillChange', {'handle': 8}), isTrue);
      await emit('onAction', {'action': 'play'});
      expect(replacementActions, ['suspend:8', 'play']);
    },
  );

  test('an idle old page cannot dispose a newer native session', () async {
    final replacementActions = <String>[];
    final replacement = replacementController(replacementActions);
    expect(await replacement.enter(), IosPipEntryResult.entered);
    await controller.dispose();
    expect(calls.where((call) => call.method == 'dispose'), isEmpty);
    expect(await emit('onVideoOutputDidChange', {'handle': 8}), isTrue);
    expect(replacementActions, ['resume:8']);
  });

  test(
    'a superseded support request cannot prepare a native session',
    () async {
      final supportStarted = Completer<void>();
      final supported = Completer<bool>();
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        if (call.method == 'isSupported') {
          supportStarted.complete();
          return supported.future;
        }
        return null;
      });
      final entering = controller.enter();
      await supportStarted.future;
      replacementController([]);
      supported.complete(true);
      expect(await entering, IosPipEntryResult.failed);
      expect(calls.map((call) => call.method), ['isSupported']);
    },
  );

  test(
    'disposal during Will keeps vid suspended until the context is freed',
    () async {
      final texture = ValueNotifier<int?>(42);
      final events = <String>[];
      var vid = '3';
      final writing = Completer<void>();
      final written = Completer<void>();
      final transition = IosPipVideoOutputTransition(
        resolveBinding: (handle) async => IosPipVideoOutputBinding(
          handle: handle,
          textureId: texture,
          isCurrent: () => true,
          readVid: () async => vid,
          writeVid: (value) async {
            events.add('vid:$value');
            vid = value;
            if (value == 'no') {
              writing.complete();
              await written.future;
            }
          },
        ),
      );
      addTearDown(() async {
        await transition.dispose();
        texture.dispose();
      });
      suspendVideo = transition.suspendVideo;
      resumeVideo = transition.resumeVideo;
      await controller.enter();
      final suspended = emit('onVideoOutputWillChange', {'handle': 7});
      await writing.future;
      final disposalStarted = Completer<void>();
      final nativeDrained = Completer<void>();
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'dispose') {
          disposalStarted.complete();
          await nativeDrained.future;
        }
        return null;
      });
      final disposed = controller.dispose().then((_) => transition.dispose());
      await disposalStarted.future;
      expect(vid, 'no');
      written.complete();
      expect(await suspended, isTrue);
      events.add('free-context:$vid');
      texture.value = 43;
      expect(await emit('onVideoOutputDidChange', {'handle': 7}), isTrue);
      nativeDrained.complete();
      await disposed;
      expect(events, ['vid:no', 'free-context:no', 'vid:3']);
    },
  );
}
