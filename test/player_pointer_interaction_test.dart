import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kazumi/pages/player/player_pointer_interaction.dart';

void main() {
  group('player surface pointer filtering', () {
    test('Linux accepts touch and stylus but not mouse', () {
      final devices = playerSurfaceDragDevices(isLinux: true)!;

      expect(devices, contains(PointerDeviceKind.touch));
      expect(devices, contains(PointerDeviceKind.stylus));
      expect(devices, contains(PointerDeviceKind.invertedStylus));
      expect(devices, isNot(contains(PointerDeviceKind.mouse)));
      expect(devices, isNot(contains(PointerDeviceKind.trackpad)));
    });

    test('non-Linux keeps the existing unrestricted device behavior', () {
      expect(playerSurfaceDragDevices(isLinux: false), isNull);
    });

    test('Linux desktop seek requires unlocked panel and valid duration', () {
      expect(
        shouldEnablePlayerSurfaceSeek(
          isDesktop: true,
          isLinux: true,
          panelLocked: false,
          videoDuration: const Duration(minutes: 1),
        ),
        isTrue,
      );
      expect(
        shouldEnablePlayerSurfaceSeek(
          isDesktop: true,
          isLinux: true,
          panelLocked: true,
          videoDuration: const Duration(minutes: 1),
        ),
        isFalse,
      );
      expect(
        shouldEnablePlayerSurfaceSeek(
          isDesktop: true,
          isLinux: true,
          panelLocked: false,
          videoDuration: Duration.zero,
        ),
        isFalse,
      );
      expect(
        shouldEnablePlayerSurfaceSeek(
          isDesktop: true,
          isLinux: false,
          panelLocked: false,
          videoDuration: const Duration(minutes: 1),
        ),
        isFalse,
      );
    });

    test('vertical surface adjustment remains disabled on desktop', () {
      expect(shouldEnablePlayerSurfaceVerticalDrag(isDesktop: true), isFalse);
      expect(shouldEnablePlayerSurfaceVerticalDrag(isDesktop: false), isTrue);
    });
  });

  group('horizontal drag seek mapping', () {
    test('one full width maps to at most 120 seconds', () {
      expect(
        horizontalDragSeekTarget(
          initialPosition: const Duration(minutes: 5),
          videoDuration: const Duration(minutes: 20),
          cumulativeDeltaX: 1280,
          surfaceWidth: 1280,
        ),
        const Duration(minutes: 7),
      );
    });

    test('short videos use their duration as the full-width span', () {
      expect(
        horizontalDragSeekTarget(
          initialPosition: const Duration(seconds: 45),
          videoDuration: const Duration(seconds: 90),
          cumulativeDeltaX: -640,
          surfaceWidth: 1280,
        ),
        Duration.zero,
      );
    });

    test('target clamps to media bounds and reports net direction', () {
      final target = horizontalDragSeekTarget(
        initialPosition: const Duration(seconds: 50),
        videoDuration: const Duration(seconds: 60),
        cumulativeDeltaX: 2000,
        surfaceWidth: 1000,
      );

      expect(target, const Duration(seconds: 60));
      expect(
        interactiveSeekDirection(
          initialPosition: const Duration(seconds: 50),
          target: target,
        ),
        1,
      );
    });

    test('invalid dimensions do not change the preview position', () {
      expect(
        horizontalDragSeekTarget(
          initialPosition: const Duration(seconds: 12),
          videoDuration: Duration.zero,
          cumulativeDeltaX: 100,
          surfaceWidth: 0,
        ),
        const Duration(seconds: 12),
      );
    });
  });
}
