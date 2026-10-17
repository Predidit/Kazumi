import 'package:audio_video_progress_bar/audio_video_progress_bar.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kazumi/pages/player/player_progress_hover.dart';
import 'package:kazumi/pages/player/player_transport_bar.dart';
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

  PlayerProgressTrackGeometry geometry({double width = 300}) =>
      PlayerProgressTrackGeometry(
        size: Size(width, 24),
        progress: const Duration(minutes: 1),
        total: const Duration(hours: 2),
        timeLabelLocation: TimeLabelLocation.none,
        labelStyle: PlayerProgressHover.labelStyle,
        textScaler: TextScaler.noScaling,
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

  testDesktop('hover matches seek across layouts and scales', (tester) async {
    for (final width in [180.0, 640.0]) {
      for (final location in [
        TimeLabelLocation.none,
        TimeLabelLocation.sides,
      ]) {
        for (final scale in [1.0, 2.0]) {
          final events = _Events();
          final host = _Host(
            width: width,
            location: location,
            scale: scale,
            progress: const Duration(minutes: 12),
            events: events,
          );
          await tester.pumpWidget(host);
          await tester.pump();
          final rect = tester.progressRect;
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
            final mouse = await tester.mouseAt(rect.topLeft + local);
            await tester.pumpAfter(mouse.moveTo(rect.topLeft + local));
            final expected = track.timeAt(local, host.total)!;
            _expectPreview(time: expected);
            expect(events.seeks, isEmpty);
            expect(events.starts, 0);
            expect(events.updates, 0);
            await tester.pumpAfter(mouse.down(rect.topLeft + local));
            _expectPreview(time: expected);
            await tester.pumpAfter(mouse.up());
            expect(events.seeks, [expected]);
            expect(events.starts, 1);
            expect(events.updates, 0);
            await mouse.removePointer();
            events.seeks.clear();
            events.starts = 0;
          }
          if (location == TimeLabelLocation.sides) {
            final mouse = await tester.mouseAt(
              rect.centerLeft + const Offset(2, 0),
            );
            await tester.pump();
            _expectPreview(visible: false);
            await mouse.removePointer();
          }
          await tester.pumpWidget(const SizedBox.shrink());
        }
      }
    }
  });

  testDesktop('overlay escapes clipping and ignores hit tests', (tester) async {
    final events = _Events();
    await tester.pumpWidget(_Host(width: 200, events: events));
    final rect = tester.progressRect;
    final mouse = await tester.mouseAt(rect.topLeft + const Offset(3, 8));
    await tester.pump();
    final previewRect = tester.getRect(_preview);
    expect(previewRect.bottom, lessThan(rect.top));
    expect(previewRect.left, greaterThanOrEqualTo(rect.left));
    expect(
      find.ancestor(of: _preview, matching: find.byType(IgnorePointer)),
      findsWidgets,
    );
    await mouse.down(rect.topLeft + const Offset(3, 8));
    await tester.pumpAfter(mouse.up());
    expect(events.seeks, hasLength(1));
    _expectPreview(visible: false);
    await mouse.removePointer();
  });

  testDesktop('mouse drag previews preserve all callbacks', (tester) async {
    final events = _Events();
    await tester.pumpWidget(_Host(events: events));
    final rect = tester.progressRect;
    final mouse = await tester.mouseAt(rect.center);
    await tester.pump();
    _expectPreview();
    await tester.pumpAfter(mouse.down(rect.center));
    _expectPreview(time: const Duration(hours: 1));
    expect(events.starts, 1);
    expect(events.updates, 0);
    for (final position in [
      rect.center + const Offset(25, -50),
      rect.centerRight + const Offset(60, 40),
      rect.centerLeft - const Offset(60, 40),
    ]) {
      await tester.pumpAfter(mouse.moveTo(position));
      expect(events.updates, greaterThan(0));
      _expectPreview(time: events.lastUpdate!.timeStamp);
      final preview = tester.getRect(_preview);
      expect(preview.bottom, lessThan(rect.top));
      expect(preview.left, greaterThanOrEqualTo(rect.left));
      expect(preview.right, lessThanOrEqualTo(rect.right));
    }
    await tester.pumpAfter(mouse.cancel());
    expect(events.cancels, 1);
    expect(events.seeks, isEmpty);
    _expectPreview(visible: false);
    await mouse.removePointer();
    final next = await tester.mouseAt(rect.center);
    await tester.pump();
    _expectPreview();
    await next.down(rect.center);
    await tester.pumpAfter(next.moveBy(const Offset(20, 0)));
    final target = events.lastUpdate!.timeStamp;
    await tester.pumpAfter(next.up());
    expect(events.seeks, [target]);
    _expectPreview(visible: false);
    await tester.pumpAfter(next.moveBy(const Offset(1, 0)));
    _expectPreview();
    await next.removePointer();
  });

  testDesktop('side labels retain the last drag timestamp', (tester) async {
    var progress = const Duration(minutes: 9, seconds: 59);
    final events = _Events();
    Widget host() => _Host(
      location: TimeLabelLocation.sides,
      progress: progress,
      events: events,
    );
    await tester.pumpWidget(host());
    final rect = tester.progressRect;
    final mouse = await tester.mouseAt(rect.center);
    await tester.pump();
    // Queue the old hover's post-frame recompute before starting the drag.
    progress = const Duration(minutes: 10);
    await tester.pumpWidget(host());
    await mouse.down(rect.center);
    await tester.pumpAfter(mouse.moveBy(const Offset(30, 30)));
    final target = events.lastUpdate!.timeStamp;
    expect(target, greaterThan(const Duration(hours: 1)));
    for (final nextProgress in [target, const Duration(minutes: 1)]) {
      progress = nextProgress;
      await tester.pumpWidget(host());
      await tester.pump();
      _expectPreview(time: target);
    }
    await tester.pumpAfter(mouse.moveBy(const Offset(1, 0)));
    _expectPreview(time: events.lastUpdate!.timeStamp);
    await tester.pumpAfter(mouse.up());
    expect(events.seeks, [events.lastUpdate!.timeStamp]);
    _expectPreview(visible: false);
    await mouse.removePointer();
  });

  testDesktop('duration changes cancel a held drag', (tester) async {
    final events = _Events();
    Widget host(Duration total) => _Host(total: total, events: events);
    await tester.pumpWidget(host(const Duration(hours: 2)));
    final rect = tester.progressRect;
    final mouse = await tester.mouseAt(rect.center);
    await tester.pumpAfter(mouse.down(rect.center));
    _expectPreview(time: const Duration(hours: 1));
    await tester.pumpWidget(host(const Duration(hours: 3)));
    await tester.pump();
    expect(events.cancels, 1);
    _expectPreview(visible: false);
    await tester.pumpAfter(mouse.up());
    expect(events.seeks, isEmpty);
    await mouse.removePointer();
  });

  testDesktop('compact time label resizing preserves drag', (tester) async {
    for (final kind in [PointerDeviceKind.mouse, PointerDeviceKind.touch]) {
      for (final forward in [true, false]) {
        final events = _Events();
        var progress = forward
            ? const Duration(minutes: 59, seconds: 59)
            : const Duration(hours: 1, seconds: 1);
        await tester.pumpWidget(
          _Host(
            width: 500,
            child: StatefulBuilder(
              builder: (context, setState) => Directionality(
                textDirection: TextDirection.ltr,
                child: PlayerTransportBar(
                  compact: true,
                  playPause: const SizedBox(width: 48),
                  nextEpisode: const SizedBox.shrink(),
                  fullscreen: const SizedBox(width: 48),
                  controls: const SizedBox.shrink(),
                  timePlacement: PlayerTimeLabelPlacement.afterPlaybackButtons,
                  timeLabel: Text(
                    '    ${durationToString(progress)} / 02:00:00',
                    style: PlayerProgressHover.labelStyle,
                  ),
                  progressBuilder: (location) => PlayerProgressHover(
                    progress: progress,
                    buffered: Duration.zero,
                    total: const Duration(hours: 2),
                    timeLabelLocation: location,
                    mediaIdentity: 1,
                    layoutIdentity: 1,
                    enabled: true,
                    onSeek: events.seeks.add,
                    onDragStart: events.start,
                    onDragCancel: events.cancel,
                    onDragUpdate: (details) {
                      events.update(details);
                      setState(() => progress = details.timeStamp);
                    },
                  ),
                ),
              ),
            ),
          ),
        );
        final rect = tester.progressRect;
        final direction = forward ? 1.0 : -1.0;
        final pointer = await tester.startGesture(
          Offset(
            rect.left + rect.width * (forward ? 0.4 : 0.6),
            rect.center.dy,
          ),
          kind: kind,
        );
        await tester.pumpAfter(
          pointer.moveBy(Offset(direction * rect.width * 0.3, 0)),
        );
        expect(
          progress,
          forward
              ? greaterThan(const Duration(hours: 1))
              : lessThan(const Duration(hours: 1)),
        );
        expect(
          tester.progressRect.width,
          forward ? lessThan(rect.width) : greaterThan(rect.width),
        );
        expect(events.cancels, 0);
        _expectPreview(
          visible: kind == PointerDeviceKind.mouse,
          time: kind == PointerDeviceKind.mouse
              ? events.lastUpdate!.timeStamp
              : null,
        );
        final updates = events.updates;
        await tester.pumpAfter(pointer.moveBy(Offset(direction * 10, 0)));
        expect(events.updates, greaterThan(updates));
        _expectPreview(
          visible: kind == PointerDeviceKind.mouse,
          time: kind == PointerDeviceKind.mouse
              ? events.lastUpdate!.timeStamp
              : null,
        );
        final target = events.lastUpdate!.timeStamp;
        await tester.pumpAfter(pointer.up());
        expect(events.seeks, [target]);
        expect(events.starts, 1);
        expect(events.cancels, 0);
        _expectPreview(visible: false);
        await pointer.removePointer();
        await tester.pumpWidget(const SizedBox.shrink());
        expect(tester.takeException(), isNull);
      }
    }
  });

  testDesktop('state changes and disposal clear the preview', (tester) async {
    var enabled = true;
    var identity = 1;
    var layout = 1;
    var total = const Duration(hours: 2);
    var width = 300.0;
    Widget host() => _Host(
      enabled: enabled,
      identity: identity,
      layout: layout,
      total: total,
      width: width,
    );
    await tester.pumpWidget(host());
    var rect = tester.progressRect;
    final mouse = await tester.mouseAt(rect.center);
    await tester.pump();
    _expectPreview();
    for (final change in [
      () => enabled = false,
      () => identity++,
      () => layout++,
      () => total = Duration.zero,
      () => width = 220,
    ]) {
      change();
      await tester.pumpWidget(host());
      await tester.pump();
      _expectPreview(visible: false);
      expect(tester.takeException(), isNull);
      enabled = true;
      total = const Duration(hours: 2);
      await tester.pumpWidget(host());
      rect = tester.progressRect;
      await tester.pumpAfter(
        mouse.moveTo(rect.center + Offset(identity.toDouble(), 0)),
      );
      _expectPreview();
    }
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    _expectPreview(visible: false);
    await mouse.removePointer();
    expect(tester.takeException(), isNull);
  });

  testDesktop('duration updates cannot revive stale previews', (tester) async {
    var total = const Duration(hours: 2);
    Widget host() => _Host(total: total);
    await tester.pumpWidget(host());
    final rect = tester.progressRect;
    final mouse = await tester.mouseAt(rect.center);
    await tester.pump();
    _expectPreview(time: const Duration(hours: 1));
    total = const Duration(hours: 4);
    await tester.pumpWidget(host());
    await tester.pump();
    _expectPreview(time: const Duration(hours: 2));
    await tester.pumpAfter(mouse.removePointer());
    _expectPreview(visible: false);
  });

  testDesktop('blur hides the preview until new focused input', (tester) async {
    final events = _Events();
    await tester.pumpWidget(_Host(events: events));
    final rect = tester.progressRect;
    final mouse = await tester.mouseAt(rect.center);
    await tester.pump();
    final dynamic state = tester.state(find.byType(PlayerProgressHover));
    state.onWindowBlur();
    await tester.pump();
    _expectPreview(visible: false);
    await tester.pumpAfter(mouse.moveBy(const Offset(1, 0)));
    _expectPreview(visible: false);
    state.onWindowFocus();
    await tester.pumpAfter(mouse.moveBy(const Offset(1, 0)));
    _expectPreview();
    await tester.pumpAfter(mouse.down(rect.center));
    _expectPreview();
    state.onWindowBlur();
    await tester.pump();
    expect(events.cancels, 1);
    state.onWindowFocus();
    await tester.pumpAfter(mouse.moveBy(const Offset(10, 0)));
    _expectPreview(visible: false);
    await mouse.cancel();
    expect(events.cancels, 1);
    await mouse.removePointer();
  });

  testDesktop('state changes cancel the active drag', (tester) async {
    final events = _Events();
    for (final change in [
      'media',
      'layout',
      'hidden',
      'duration',
      'metrics',
      'scale',
    ]) {
      Widget host({bool changed = false}) => _Host(
        identity: change == 'media' && changed ? 2 : 1,
        layout: change == 'layout' && changed ? 2 : 1,
        enabled: change != 'hidden' || !changed,
        total: change == 'duration' && changed
            ? Duration.zero
            : const Duration(hours: 2),
        scale: change == 'scale' && changed ? 2 : 1,
        events: events,
      );
      await tester.pumpWidget(host());
      final rect = tester.progressRect;
      final mouse = await tester.mouseAt(rect.center);
      await mouse.down(rect.center);
      await mouse.moveBy(const Offset(20, 0));
      final before = events.cancels;
      await tester.pumpWidget(host(changed: true));
      if (change == 'metrics') {
        final dynamic state = tester.state(find.byType(PlayerProgressHover));
        state.didChangeMetrics();
      }
      await tester.pump();
      expect(events.cancels, before + 1);
      _expectPreview(visible: false);
      await tester.pumpAfter(mouse.moveBy(const Offset(10, 0)));
      _expectPreview(visible: false);
      await tester.pumpAfter(mouse.up());
      expect(events.seeks, isEmpty);
      await tester.pumpWidget(host());
      await tester.pumpAfter(mouse.moveBy(const Offset(1, 0)));
      _expectPreview();
      await mouse.removePointer();
      await tester.pumpWidget(const SizedBox.shrink());
      expect(tester.takeException(), isNull);
    }
  });

  testDesktop('mixed pointers never turn touch into hover', (tester) async {
    await tester.pumpWidget(const _Host());
    final rect = tester.progressRect;
    final first = await tester.startGesture(rect.center, pointer: 1);
    final second = await tester.startGesture(rect.center, pointer: 2);
    await first.up();
    final mouse = await tester.mouseAt(rect.center, pointer: 3);
    await mouse.down(rect.center);
    await tester.pumpAfter(second.moveBy(const Offset(30, 0)));
    _expectPreview(visible: false);
    await second.up();
    await mouse.up();
    await tester.pumpAfter(mouse.removePointer());
    expect(tester.takeException(), isNull);
  });

  testDesktop('touch drag keeps callbacks without preview', (tester) async {
    for (final platform in [
      TargetPlatform.windows,
      TargetPlatform.android,
      TargetPlatform.iOS,
    ]) {
      debugDefaultTargetPlatformOverride = platform;
      final events = _Events();
      await tester.pumpWidget(_Host(events: events));
      final rect = tester.progressRect;
      final touch = await tester.startGesture(
        rect.center,
        kind: PointerDeviceKind.touch,
      );
      await tester.pump();
      _expectPreview(visible: false);
      await tester.pumpAfter(touch.moveBy(const Offset(30, 0)));
      _expectPreview(visible: false);
      await tester.pumpAfter(touch.up());
      expect(events.starts, 1);
      expect(events.seeks, hasLength(1));
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
    this.events,
    this.child,
  });
  final double width;
  final TimeLabelLocation location;
  final double scale;
  final Duration total;
  final Duration progress;
  final int identity;
  final int layout;
  final bool enabled;
  final _Events? events;
  final Widget? child;

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
                child:
                    child ??
                    PlayerProgressHover(
                      progress: progress,
                      buffered: Duration.zero,
                      total: total,
                      timeLabelLocation: location,
                      mediaIdentity: identity,
                      layoutIdentity: layout,
                      enabled: enabled,
                      onSeek: events?.seeks.add ?? (_) {},
                      onDragStart: events?.start ?? () {},
                      onDragUpdate: events?.update ?? (_) {},
                      onDragCancel: events?.cancel ?? () {},
                    ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

Finder get _preview => find.byKey(PlayerProgressHover.previewKey);

void _expectPreview({bool visible = true, Duration? time}) {
  expect(_preview, visible ? findsOneWidget : findsNothing);
  if (time != null) {
    expect(
      find.descendant(
        of: _preview,
        matching: find.text(durationToString(time)),
      ),
      findsOneWidget,
    );
  }
}

extension on WidgetTester {
  Rect get progressRect => getRect(find.byType(ProgressBar));

  Future<TestGesture> mouseAt(Offset location, {int? pointer}) async {
    final mouse = await createGesture(
      pointer: pointer,
      kind: PointerDeviceKind.mouse,
    );
    await mouse.addPointer(location: location);
    return mouse;
  }

  Future<void> pumpAfter(Future<void> event) async {
    await event;
    await pump();
  }
}

class _Events {
  final seeks = <Duration>[];
  var starts = 0;
  var updates = 0;
  var cancels = 0;
  ThumbDragDetails? lastUpdate;

  void start() => starts++;
  void cancel() => cancels++;
  void update(ThumbDragDetails details) {
    updates++;
    lastUpdate = details;
  }
}
