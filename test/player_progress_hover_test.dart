import 'package:audio_video_progress_bar/audio_video_progress_bar.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kazumi/pages/player/player_progress_hover.dart';
import 'package:kazumi/utils/format.dart';

void main() {
  void testDesktop(String description, WidgetTesterCallback callback) {
    testWidgets(description, (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      try {
        await callback(tester);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });
  }

  PlayerProgressTrackGeometry geometry({
    double width = 300,
    Duration progress = const Duration(minutes: 1),
    Duration total = const Duration(hours: 2),
    TimeLabelLocation location = TimeLabelLocation.none,
    TextScaler scaler = TextScaler.noScaling,
  }) => PlayerProgressTrackGeometry(
    size: Size(width, 24),
    progress: progress,
    total: total,
    timeLabelLocation: location,
    labelStyle: PlayerProgressHover.labelStyle,
    textScaler: scaler,
  );

  test('track uses cap insets and clamps first/last painted pixels', () {
    final track = geometry();
    const total = Duration(hours: 2);
    expect(track.start, 2.5);
    expect(track.end, 297.5);
    expect(track.timeAt(const Offset(0, 12), total), Duration.zero);
    expect(
      track.timeAt(const Offset(150, 12), total),
      const Duration(hours: 1),
    );
    expect(track.timeAt(const Offset(299, 12), total), total);
    expect(track.timeAt(const Offset(-1, 12), total), isNull);
    expect(track.timeAt(const Offset(300, 12), total), isNull);
    expect(track.timeAt(const Offset(150, 1), total), isNull);
    expect(track.timeAt(const Offset(150, 12), Duration.zero), isNull);
    expect(
      track.timeAt(const Offset(150, 12), const Duration(seconds: -1)),
      isNull,
    );
    expect(geometry(width: 4).timeAt(const Offset(2, 12), total), isNull);
    expect(
      durationToString(const Duration(hours: 2, minutes: 3, seconds: 4)),
      '02:03:04',
    );
  });

  testDesktop(
    'hover and library seek agree in wide, narrow and scaled side layouts',
    (tester) async {
      for (final width in [180.0, 640.0]) {
        for (final location in [
          TimeLabelLocation.none,
          TimeLabelLocation.sides,
        ]) {
          for (final scale in [1.0, 2.0]) {
            Duration? sought;
            var starts = 0;
            var updates = 0;
            final host = _Host(
              width: width,
              location: location,
              scale: scale,
              progress: const Duration(minutes: 12),
              onSeek: (time) => sought = time,
              onStart: () => starts++,
              onUpdate: (_) => updates++,
            );
            await tester.pumpWidget(host);
            await tester.pump();
            final rect = tester.getRect(find.byType(ProgressBar));
            final track = PlayerProgressTrackGeometry(
              size: rect.size,
              progress: host.progress,
              total: host.total,
              timeLabelLocation: location,
              labelStyle: PlayerProgressHover.labelStyle,
              textScaler: TextScaler.linear(scale),
            );
            if (track.end <= track.start) continue;
            for (final fraction in [0.0, 0.5, 1.0]) {
              final local = Offset(
                track.start + (track.end - track.start) * fraction,
                rect.height / 2,
              );
              final mouse = await tester.createGesture(
                kind: PointerDeviceKind.mouse,
              );
              await mouse.addPointer(location: rect.topLeft + local);
              await mouse.moveTo(rect.topLeft + local);
              await tester.pump();
              final expected = track.timeAt(local, host.total)!;
              expect(
                find.descendant(
                  of: find.byKey(PlayerProgressHover.previewKey),
                  matching: find.text(durationToString(expected)),
                ),
                findsOneWidget,
              );
              expect(sought, isNull);
              expect(starts, 0);
              expect(updates, 0);
              await mouse.down(rect.topLeft + local);
              await tester.pump();
              expect(
                find.descendant(
                  of: find.byKey(PlayerProgressHover.previewKey),
                  matching: find.text(durationToString(expected)),
                ),
                findsOneWidget,
              );
              await mouse.up();
              await tester.pump();
              expect(sought, expected);
              expect(starts, 1);
              expect(updates, 0);
              await mouse.removePointer();
              sought = null;
              starts = 0;
            }
            if (location == TimeLabelLocation.sides) {
              final mouse = await tester.createGesture(
                kind: PointerDeviceKind.mouse,
              );
              await mouse.addPointer(
                location: rect.centerLeft + const Offset(2, 0),
              );
              await tester.pump();
              expect(find.byKey(PlayerProgressHover.previewKey), findsNothing);
              await mouse.removePointer();
            }
            await tester.pumpWidget(const SizedBox.shrink());
          }
        }
      }
    },
  );

  testDesktop(
    'overlay escapes ClipRect, clamps at edge and ignores hit testing',
    (tester) async {
      var seeks = 0;
      await tester.pumpWidget(_Host(width: 200, onSeek: (_) => seeks++));
      final rect = tester.getRect(find.byType(ProgressBar));
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: rect.topLeft + const Offset(3, 8));
      await tester.pump();
      final previewRect = tester.getRect(
        find.byKey(PlayerProgressHover.previewKey),
      );
      expect(previewRect.bottom, lessThan(rect.top));
      expect(previewRect.left, greaterThanOrEqualTo(rect.left));
      expect(
        find.ancestor(
          of: find.byKey(PlayerProgressHover.previewKey),
          matching: find.byType(IgnorePointer),
        ),
        findsWidgets,
      );
      await mouse.down(rect.topLeft + const Offset(3, 8));
      await mouse.up();
      await tester.pump();
      expect(seeks, 1);
      expect(find.byKey(PlayerProgressHover.previewKey), findsNothing);
      await mouse.removePointer();
    },
  );

  testDesktop('mouse drag previews time and cancel preserves callbacks', (
    tester,
  ) async {
    var starts = 0;
    var updates = 0;
    ThumbDragDetails? lastUpdate;
    var cancels = 0;
    final seeks = <Duration>[];
    await tester.pumpWidget(
      _Host(
        onStart: () => starts++,
        onUpdate: (details) {
          updates++;
          lastUpdate = details;
        },
        onCancel: () => cancels++,
        onSeek: seeks.add,
      ),
    );
    final rect = tester.getRect(find.byType(ProgressBar));
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: rect.center);
    await tester.pump();
    expect(find.byKey(PlayerProgressHover.previewKey), findsOneWidget);
    await mouse.down(rect.center);
    await tester.pump();
    expect(find.text('01:00:00'), findsOneWidget);
    expect(starts, 1);
    expect(updates, 0);
    for (final position in [
      rect.center + const Offset(25, -50),
      rect.centerRight + const Offset(60, 40),
      rect.centerLeft - const Offset(60, 40),
    ]) {
      await mouse.moveTo(position);
      await tester.pump();
      expect(updates, greaterThan(0));
      expect(
        find.descendant(
          of: find.byKey(PlayerProgressHover.previewKey),
          matching: find.text(durationToString(lastUpdate!.timeStamp)),
        ),
        findsOneWidget,
      );
      final preview = tester.getRect(
        find.byKey(PlayerProgressHover.previewKey),
      );
      expect(preview.bottom, lessThan(rect.top));
      expect(preview.left, greaterThanOrEqualTo(rect.left));
      expect(preview.right, lessThanOrEqualTo(rect.right));
    }
    await mouse.cancel();
    await tester.pump();
    expect(cancels, 1);
    expect(seeks, isEmpty);
    expect(find.byKey(PlayerProgressHover.previewKey), findsNothing);
    await mouse.removePointer();
    final next = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await next.addPointer(location: rect.center);
    await tester.pump();
    expect(find.byKey(PlayerProgressHover.previewKey), findsOneWidget);
    await next.down(rect.center);
    await next.moveBy(const Offset(20, 0));
    await tester.pump();
    final target = lastUpdate!.timeStamp;
    await next.up();
    await tester.pump();
    expect(seeks, [target]);
    expect(find.byKey(PlayerProgressHover.previewKey), findsNothing);
    await next.moveBy(const Offset(1, 0));
    await tester.pump();
    expect(find.byKey(PlayerProgressHover.previewKey), findsOneWidget);
    await next.removePointer();
  });

  testDesktop('side-label playback updates preserve the last drag timestamp', (
    tester,
  ) async {
    var progress = const Duration(minutes: 9, seconds: 59);
    ThumbDragDetails? lastUpdate;
    Duration? sought;
    Widget host() => _Host(
      location: TimeLabelLocation.sides,
      progress: progress,
      onUpdate: (details) => lastUpdate = details,
      onSeek: (time) => sought = time,
    );
    await tester.pumpWidget(host());
    final rect = tester.getRect(find.byType(ProgressBar));
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: rect.center);
    await tester.pump();
    // Queue the old hover's post-frame recompute before starting the drag.
    progress = const Duration(minutes: 10);
    await tester.pumpWidget(host());
    await mouse.down(rect.center);
    await mouse.moveBy(const Offset(30, 30));
    await tester.pump();
    final target = lastUpdate!.timeStamp;
    expect(target, greaterThan(const Duration(hours: 1)));
    for (final nextProgress in [target, const Duration(minutes: 1)]) {
      progress = nextProgress;
      await tester.pumpWidget(host());
      await tester.pump();
      expect(
        find.descendant(
          of: find.byKey(PlayerProgressHover.previewKey),
          matching: find.text(durationToString(target)),
        ),
        findsOneWidget,
      );
    }
    await mouse.moveBy(const Offset(1, 0));
    await tester.pump();
    expect(
      find.descendant(
        of: find.byKey(PlayerProgressHover.previewKey),
        matching: find.text(durationToString(lastUpdate!.timeStamp)),
      ),
      findsOneWidget,
    );
    await mouse.up();
    await tester.pump();
    expect(sought, lastUpdate!.timeStamp);
    expect(find.byKey(PlayerProgressHover.previewKey), findsNothing);
    await mouse.removePointer();
  });

  testDesktop('duration changes cancel a held drag before release', (
    tester,
  ) async {
    var seeks = 0;
    var cancels = 0;
    Widget host(Duration total) =>
        _Host(total: total, onSeek: (_) => seeks++, onCancel: () => cancels++);
    await tester.pumpWidget(host(const Duration(hours: 2)));
    final rect = tester.getRect(find.byType(ProgressBar));
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: rect.center);
    await mouse.down(rect.center);
    await tester.pump();
    expect(find.text('01:00:00'), findsOneWidget);
    await tester.pumpWidget(host(const Duration(hours: 3)));
    await tester.pump();
    expect(cancels, 1);
    expect(find.byKey(PlayerProgressHover.previewKey), findsNothing);
    await mouse.up();
    await tester.pump();
    expect(seeks, 0);
    await mouse.removePointer();
  });

  testDesktop(
    'invalid total, media, visibility, layout and disposal clear overlay',
    (tester) async {
      final key = GlobalKey<_MutableHostState>();
      await tester.pumpWidget(_MutableHost(key: key));
      var rect = tester.getRect(find.byType(ProgressBar));
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: rect.center);
      await tester.pump();
      expect(find.byKey(PlayerProgressHover.previewKey), findsOneWidget);
      for (final change in [
        () => key.currentState!.enabled = false,
        () => key.currentState!.identity++,
        () => key.currentState!.layout++,
        () => key.currentState!.total = Duration.zero,
        () => key.currentState!.width = 220,
      ]) {
        key.currentState!.update(change);
        await tester.pump();
        await tester.pump();
        expect(find.byKey(PlayerProgressHover.previewKey), findsNothing);
        expect(tester.takeException(), isNull);
        key.currentState!.update(() {
          key.currentState!.enabled = true;
          key.currentState!.total = const Duration(hours: 2);
        });
        await tester.pump();
        rect = tester.getRect(find.byType(ProgressBar));
        await mouse.moveTo(
          rect.center + Offset(key.currentState!.identity.toDouble(), 0),
        );
        await tester.pump();
        expect(find.byKey(PlayerProgressHover.previewKey), findsOneWidget);
      }
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      expect(find.byKey(PlayerProgressHover.previewKey), findsNothing);
      await mouse.removePointer();
      expect(tester.takeException(), isNull);
    },
  );

  testDesktop(
    'duration updates recompute active preview and stale frames stay hidden',
    (tester) async {
      final key = GlobalKey<_MutableHostState>();
      await tester.pumpWidget(_MutableHost(key: key));
      final rect = tester.getRect(find.byType(ProgressBar));
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: rect.center);
      await tester.pump();
      expect(find.text('01:00:00'), findsOneWidget);
      key.currentState!.update(
        () => key.currentState!.total = const Duration(hours: 4),
      );
      await tester.pump();
      await tester.pump();
      expect(find.text('02:00:00'), findsOneWidget);
      await mouse.removePointer();
      await tester.pump();
      expect(find.byKey(PlayerProgressHover.previewKey), findsNothing);
    },
  );

  testDesktop('window blur hides preview until focused and next movement', (
    tester,
  ) async {
    var cancels = 0;
    await tester.pumpWidget(_Host(onCancel: () => cancels++));
    final rect = tester.getRect(find.byType(ProgressBar));
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: rect.center);
    await tester.pump();
    final dynamic state = tester.state(find.byType(PlayerProgressHover));
    state.onWindowBlur();
    await tester.pump();
    expect(find.byKey(PlayerProgressHover.previewKey), findsNothing);
    await mouse.moveBy(const Offset(1, 0));
    await tester.pump();
    expect(find.byKey(PlayerProgressHover.previewKey), findsNothing);
    state.onWindowFocus();
    await mouse.moveBy(const Offset(1, 0));
    await tester.pump();
    expect(find.byKey(PlayerProgressHover.previewKey), findsOneWidget);
    await mouse.down(rect.center);
    await tester.pump();
    expect(find.byKey(PlayerProgressHover.previewKey), findsOneWidget);
    state.onWindowBlur();
    await tester.pump();
    expect(cancels, 1);
    state.onWindowFocus();
    await mouse.moveBy(const Offset(10, 0));
    await tester.pump();
    expect(find.byKey(PlayerProgressHover.previewKey), findsNothing);
    await mouse.cancel();
    expect(cancels, 1);
    await mouse.removePointer();
  });

  testDesktop(
    'media, layout, visibility and invalid duration cancel the active drag',
    (tester) async {
      var cancels = 0;
      var seeks = 0;
      for (final change in [
        'media',
        'layout',
        'hidden',
        'duration',
        'width',
        'scale',
      ]) {
        Widget host({bool changed = false}) => _Host(
          identity: change == 'media' && changed ? 2 : 1,
          layout: change == 'layout' && changed ? 2 : 1,
          enabled: change != 'hidden' || !changed,
          total: change == 'duration' && changed
              ? Duration.zero
              : const Duration(hours: 2),
          width: change == 'width' && changed ? 220 : 300,
          scale: change == 'scale' && changed ? 2 : 1,
          onCancel: () => cancels++,
          onSeek: (_) => seeks++,
        );
        await tester.pumpWidget(host());
        final rect = tester.getRect(find.byType(ProgressBar));
        final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
        await mouse.addPointer(location: rect.center);
        await mouse.down(rect.center);
        await mouse.moveBy(const Offset(20, 0));
        final before = cancels;
        await tester.pumpWidget(host(changed: true));
        await tester.pump();
        expect(cancels, before + 1);
        expect(find.byKey(PlayerProgressHover.previewKey), findsNothing);
        await mouse.moveBy(const Offset(10, 0));
        await tester.pump();
        expect(find.byKey(PlayerProgressHover.previewKey), findsNothing);
        await mouse.up();
        await tester.pump();
        expect(seeks, 0);
        await tester.pumpWidget(host());
        await mouse.moveBy(const Offset(1, 0));
        await tester.pump();
        expect(find.byKey(PlayerProgressHover.previewKey), findsOneWidget);
        await mouse.removePointer();
        await tester.pumpWidget(const SizedBox.shrink());
        expect(tester.takeException(), isNull);
      }
    },
  );

  testDesktop('mixed pointers do not turn touch into a mouse preview', (
    tester,
  ) async {
    await tester.pumpWidget(const _Host());
    final rect = tester.getRect(find.byType(ProgressBar));
    final first = await tester.startGesture(rect.center, pointer: 1);
    final second = await tester.startGesture(rect.center, pointer: 2);
    await first.up();
    final mouse = await tester.createGesture(
      pointer: 3,
      kind: PointerDeviceKind.mouse,
    );
    await mouse.addPointer(location: rect.center);
    await mouse.down(rect.center);
    await second.moveBy(const Offset(30, 0));
    await tester.pump();
    expect(find.byKey(PlayerProgressHover.previewKey), findsNothing);
    await second.up();
    await mouse.up();
    await mouse.removePointer();
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testDesktop('touch remains a normal drag and never displays hover', (
    tester,
  ) async {
    for (final platform in [
      TargetPlatform.windows,
      TargetPlatform.android,
      TargetPlatform.iOS,
    ]) {
      debugDefaultTargetPlatformOverride = platform;
      var starts = 0;
      var seeks = 0;
      await tester.pumpWidget(
        _Host(onStart: () => starts++, onSeek: (_) => seeks++),
      );
      final rect = tester.getRect(find.byType(ProgressBar));
      final touch = await tester.startGesture(
        rect.center,
        kind: PointerDeviceKind.touch,
      );
      await tester.pump();
      expect(find.byKey(PlayerProgressHover.previewKey), findsNothing);
      await touch.moveBy(const Offset(30, 0));
      await tester.pump();
      expect(find.byKey(PlayerProgressHover.previewKey), findsNothing);
      await touch.up();
      await tester.pump();
      expect(starts, 1);
      expect(seeks, 1);
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });
}

class _Host extends StatelessWidget {
  const _Host({
    this.width = 300,
    this.location = TimeLabelLocation.none,
    this.scale = 1,
    this.total = const Duration(hours: 2),
    this.progress = const Duration(minutes: 1),
    this.identity = 1,
    this.layout = 1,
    this.enabled = true,
    this.onSeek,
    this.onStart,
    this.onUpdate,
    this.onCancel,
  });
  final double width;
  final TimeLabelLocation location;
  final double scale;
  final Duration total;
  final Duration progress;
  final int identity;
  final int layout;
  final bool enabled;
  final ValueChanged<Duration>? onSeek;
  final VoidCallback? onStart;
  final ValueChanged<ThumbDragDetails>? onUpdate;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) => MaterialApp(
    home: Scaffold(
      body: MediaQuery(
        data: MediaQueryData(
          size: const Size(800, 600),
          textScaler: TextScaler.linear(scale),
        ),
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: Align(
            alignment: Alignment.centerLeft,
            child: ClipRect(
              child: SizedBox(
                width: width,
                child: PlayerProgressHover(
                  progress: progress,
                  buffered: Duration.zero,
                  total: total,
                  timeLabelLocation: location,
                  mediaIdentity: identity,
                  layoutIdentity: layout,
                  enabled: enabled,
                  onSeek: onSeek ?? (_) {},
                  onDragStart: onStart ?? () {},
                  onDragUpdate: onUpdate ?? (_) {},
                  onDragCancel: onCancel ?? () {},
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _MutableHost extends StatefulWidget {
  const _MutableHost({super.key});
  @override
  State<_MutableHost> createState() => _MutableHostState();
}

class _MutableHostState extends State<_MutableHost> {
  bool enabled = true;
  int identity = 1;
  int layout = 1;
  double width = 300;
  Duration total = const Duration(hours: 2);

  void update(VoidCallback update) => setState(update);

  @override
  Widget build(BuildContext context) => _Host(
    enabled: enabled,
    identity: identity,
    layout: layout,
    width: width,
    total: total,
  );
}
