import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kazumi/services/platform/fullscreen_transition_coordinator.dart';

void main() {
  group('FullscreenTransitionCoordinator', () {
    test('ignores a rapid duplicate request while a transition is pending',
        () async {
      final coordinator = FullscreenTransitionCoordinator();
      final allowTransition = Completer<void>();
      var fullscreen = false;
      var transitionCalls = 0;

      final first = coordinator.run(
        readCurrentState: () => fullscreen,
        targetState: true,
        transition: (_) async {
          transitionCalls += 1;
          await allowTransition.future;
        },
        commitState: (value) => fullscreen = value,
      );

      await Future<void>.delayed(Duration.zero);
      final second = await coordinator.run(
        readCurrentState: () => fullscreen,
        targetState: true,
        transition: (_) async {
          transitionCalls += 1;
        },
        commitState: (value) => fullscreen = value,
      );

      expect(second, isFalse);
      expect(transitionCalls, 1);
      expect(fullscreen, isFalse);
      expect(coordinator.transitionInProgress, isTrue);

      allowTransition.complete();
      expect(await first, isTrue);
      expect(fullscreen, isTrue);
      expect(coordinator.transitionInProgress, isFalse);
    });

    test('does not commit optimistic state when the platform call fails',
        () async {
      final coordinator = FullscreenTransitionCoordinator();
      var fullscreen = false;

      await expectLater(
        coordinator.run(
          readCurrentState: () => fullscreen,
          targetState: true,
          transition: (_) async => throw StateError('fullscreen failed'),
          commitState: (value) => fullscreen = value,
        ),
        throwsStateError,
      );

      expect(fullscreen, isFalse);
      expect(coordinator.transitionInProgress, isFalse);

      final retried = await coordinator.run(
        readCurrentState: () => fullscreen,
        targetState: true,
        transition: (_) async {},
        commitState: (value) => fullscreen = value,
      );
      expect(retried, isTrue);
      expect(fullscreen, isTrue);
    });

    test('does nothing when platform and requested state already match',
        () async {
      final coordinator = FullscreenTransitionCoordinator();
      var transitionCalls = 0;

      final changed = await coordinator.run(
        readCurrentState: () => true,
        targetState: true,
        transition: (_) async {
          transitionCalls += 1;
        },
        commitState: (_) {},
      );

      expect(changed, isFalse);
      expect(transitionCalls, 0);
    });

    test('drains a rapid opposite request after the active transition',
        () async {
      final coordinator = FullscreenTransitionCoordinator();
      final allowEnter = Completer<void>();
      var fullscreen = false;
      final transitions = <bool>[];

      final enter = coordinator.run(
        readCurrentState: () => fullscreen,
        targetState: true,
        transition: (target) async {
          transitions.add(target);
          if (target) {
            await allowEnter.future;
          }
        },
        commitState: (value) => fullscreen = value,
      );

      await Future<void>.delayed(Duration.zero);
      expect(coordinator.targetForToggle(fullscreen), isFalse);
      final exit = coordinator.run(
        readCurrentState: () => fullscreen,
        targetState: false,
        transition: (target) async => transitions.add(target),
        commitState: (value) => fullscreen = value,
      );

      allowEnter.complete();
      expect(await enter, isTrue);
      expect(await exit, isTrue);
      expect(transitions, [true, false]);
      expect(fullscreen, isFalse);
      expect(coordinator.transitionInProgress, isFalse);
    });

    test('native state events do not replace a newer queued target', () async {
      final coordinator = FullscreenTransitionCoordinator();
      final allowEnter = Completer<void>();
      var fullscreen = false;

      final transition = coordinator.run(
        readCurrentState: () => fullscreen,
        targetState: true,
        transition: (target) async {
          if (target) {
            await allowEnter.future;
          }
        },
        commitState: (value) => fullscreen = value,
      );
      await Future<void>.delayed(Duration.zero);
      coordinator.run(
        readCurrentState: () => fullscreen,
        targetState: false,
        transition: (_) async {},
        commitState: (value) => fullscreen = value,
      );

      coordinator.synchronize(true);
      allowEnter.complete();
      await transition;

      expect(fullscreen, isFalse);
      expect(coordinator.desiredState, isFalse);
    });
  });
}
