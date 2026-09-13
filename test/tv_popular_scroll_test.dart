import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:kazumi/bean/card/bangumi_card.dart';
import 'package:kazumi/bean/widget/tv_focusable_surface.dart';
import 'package:kazumi/services/player/low_memory_mode.dart';
import 'package:kazumi/pages/popular/popular_page.dart';
import 'package:kazumi/services/platform/tv_channel_input.dart';
import 'package:kazumi/services/platform/tv_mode.dart';
import 'package:kazumi/services/storage/storage.dart';
import 'package:kazumi/navigation.dart';
import 'support/tv_focus_fixtures.dart';

class _TempPaths extends PathProviderPlatform {
  _TempPaths(this.path);
  final String path;
  @override
  Future<String?> getApplicationSupportPath() async => path;
}

Finder _poster(int number) => find
    .byWidgetPredicate((w) => w is BangumiCardV && w.channelNumber == number);

void _expectVisibleFocus(WidgetTester tester, int number) {
  final finder = _poster(number);
  expect(finder, findsOneWidget, reason: 'poster $number must be laid out');
  expect(tester.widget<BangumiCardV>(finder).focusNode!.hasPrimaryFocus, isTrue,
      reason: 'poster $number owns focus');
  final rect = tester.getRect(finder);
  final viewport = tester.getRect(find.descendant(
      of: find.byType(PopularPage), matching: find.byType(CustomScrollView)));
  final header = tester.getRect(find.descendant(
      of: find.byType(PopularPage), matching: find.byType(AppBar)));
  expect(rect.top, greaterThanOrEqualTo(header.bottom - 0.5),
      reason: 'poster $number must not hide behind the pinned categories');
  expect(rect.bottom, lessThanOrEqualTo(viewport.bottom + 0.5),
      reason: 'poster $number must remain fully visible');
  expect(tester.takeException(), isNull);
}

Future<void> _press(WidgetTester tester, LogicalKeyboardKey key) async {
  await tester.sendKeyEvent(key);
  await tester.pumpAndSettle();
}

void main() {
  late Directory temp;
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    temp = await Directory.systemTemp.createTemp('kazumi_popular_scroll_');
    PathProviderPlatform.instance = _TempPaths(temp.path);
    Hive.init(temp.path);
    await GStorage.init();
  });
  tearDownAll(() async {
    await Hive.close();
    await temp.delete(recursive: true);
  });
  setUp(() {
    TvMode.setEnabledForTesting(true);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('com.predidit.kazumi/tv_navigation'),
            (_) async => null);
  });
  tearDown(() {
    tvChannelInputController.cancel();
    TvMode.setEnabledForTesting(false);
  });

  Future<FocusFixtureApp> mount(WidgetTester tester,
      {Size size = const Size(960, 540),
      int count = 120,
      double textScale = 1}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final app = FocusFixtureApp(count: count, textScale: textScale);
    await tester.pumpWidget(app);
    await tester.pumpAndSettle();
    tester.widget<BangumiCardV>(_poster(1)).focusNode!.requestFocus();
    await tester.pumpAndSettle();
    return app;
  }

  testWidgets('TV home fits two complete rows including titles',
      (tester) async {
    await mount(tester);
    final viewport = tester.getRect(find.byType(CustomScrollView).first);
    final last = tester.getRect(_poster(12));
    expect(last.bottom, lessThanOrEqualTo(viewport.bottom - 3));
    final image =
        find.descendant(of: _poster(12), matching: find.byType(AspectRatio));
    expect(tester.widget<AspectRatio>(image.first).aspectRatio, 0.65);
    final badge = find.descendant(
      of: _poster(12),
      matching: find.byWidgetPredicate((widget) =>
          widget is DecoratedBox &&
          widget.decoration is BoxDecoration &&
          (widget.decoration as BoxDecoration).color ==
              Colors.black.withValues(alpha: 0.45)),
    );
    expect(badge, findsOneWidget,
        reason: 'The channel badge must leave the poster visible beneath it');
    expect(tester.takeException(), isNull);
  });

  testWidgets('TV categories stay fully visible in both directions and wrap',
      (tester) async {
    await mount(tester, size: const Size(854, 480));
    final tabs = find.byWidgetPredicate((w) =>
        w is TvFocusableSurface &&
        (w.focusNode?.debugLabel?.startsWith('TV category ') ?? false));
    final first = tester.widget<TvFocusableSurface>(tabs.first).focusNode!;
    first.requestFocus();
    await tester.pumpAndSettle();
    final viewport = tester.getRect(find.byType(SingleChildScrollView).first);
    for (final key in [
      LogicalKeyboardKey.arrowRight,
      LogicalKeyboardKey.arrowLeft
    ]) {
      for (var i = 0; i < tabs.evaluate().length + 1; i++) {
        await _press(tester, key);
        final focused = find.byWidgetPredicate((w) =>
            w is TvFocusableSurface &&
            (w.focusNode?.debugLabel?.startsWith('TV category ') ?? false) &&
            w.focusNode!.hasPrimaryFocus);
        expect(focused, findsOneWidget);
        final rect = tester.getRect(focused);
        expect(rect.left, greaterThanOrEqualTo(viewport.left + 3));
        expect(rect.right, lessThanOrEqualTo(viewport.right - 3));
      }
    }
  });

  test('TV memory defaults on and preserves all explicit modes like mobile',
      () async {
    await GStorage.putSetting(SettingsKeys.lowMemoryPolicy, null);
    expect(LowMemoryMode.current, LowMemoryMode.always);
    await LowMemoryMode.auto.save();
    expect(LowMemoryMode.current, LowMemoryMode.auto);
    await LowMemoryMode.never.save();
    expect(LowMemoryMode.current, LowMemoryMode.never);
    TvMode.setEnabledForTesting(false);
    await LowMemoryMode.auto.save();
    expect(LowMemoryMode.current, LowMemoryMode.auto);
  });

  for (final size in [
    const Size(854, 480),
    const Size(960, 540),
    const Size(1280, 720)
  ]) {
    for (final textScale in [1.0, 1.25]) {
      testWidgets('offline home reveals every row both ways: $size/$textScale',
          (tester) async {
        final app = await mount(tester, size: size, textScale: textScale);
        // Real homepage, pinned categories and virtualized grid; no network.
        for (var row = 1; row <= 9; row++) {
          await _press(tester, LogicalKeyboardKey.arrowDown);
          _expectVisibleFocus(tester, row * 6 + 1);
        }
        for (var row = 8; row >= 0; row--) {
          await _press(tester, LogicalKeyboardKey.arrowUp);
          _expectVisibleFocus(tester, row * 6 + 1);
        }
        expect(app.popular.scrollOffset, lessThan(10));
      });
    }
  }

  testWidgets('horizontal movement does not recenter an already visible row',
      (tester) async {
    final app = await mount(tester);
    for (var i = 0; i < 3; i++) {
      await _press(tester, LogicalKeyboardKey.arrowDown);
    }
    await _press(tester, LogicalKeyboardKey.arrowUp);
    final offset = app.popular.scrollOffset;
    await _press(tester, LogicalKeyboardKey.arrowRight);
    _expectVisibleFocus(tester, 14);
    expect(app.popular.scrollOffset, closeTo(offset, 0.5));
    await _press(tester, LogicalKeyboardKey.arrowLeft);
    _expectVisibleFocus(tester, 13);
    expect(app.popular.scrollOffset, closeTo(offset, 0.5));
  });

  testWidgets('10ms DOWN then UP cancels old motion and returns to first row',
      (tester) async {
    final app = await mount(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump(const Duration(milliseconds: 10));
    await _press(tester, LogicalKeyboardKey.arrowUp);
    _expectVisibleFocus(tester, 1);
    expect(app.popular.scrollOffset, lessThan(10));
    await tester.pump(const Duration(seconds: 1));
    _expectVisibleFocus(tester, 1);
  });

  testWidgets('held DOWN accumulates pending rows; latest RIGHT wins',
      (tester) async {
    await mount(tester);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump(const Duration(milliseconds: 10));
    for (var i = 0; i < 8; i++) {
      await tester.sendKeyRepeatEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump(const Duration(milliseconds: 10));
    }
    await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowDown);
    await _press(tester, LogicalKeyboardKey.arrowRight);
    _expectVisibleFocus(tester, 56);
    await tester.pump(const Duration(seconds: 1));
    _expectVisibleFocus(tester, 56);
  });

  testWidgets('leaving pending scroll for rail cancels it and restores content',
      (tester) async {
    final app = await mount(tester);
    await _press(tester, LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump(const Duration(milliseconds: 10));
    await _press(tester, LogicalKeyboardKey.arrowLeft);
    expect(
        FocusManager.instance.primaryFocus!.ancestors
            .any((n) => n.debugLabel == 'TV navigation rail'),
        isTrue);
    final offset = app.popular.scrollOffset;
    await tester.pump(const Duration(seconds: 1));
    expect(app.popular.scrollOffset, closeTo(offset, 0.5));
    await _press(tester, LogicalKeyboardKey.arrowRight);
    _expectVisibleFocus(tester, 7);
  });

  testWidgets(
      'OK during scroll keeps detail focus, native return restores card',
      (tester) async {
    await mount(tester);
    await _press(tester, LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump(const Duration(milliseconds: 10));
    await _press(tester, LogicalKeyboardKey.select);
    expect(find.text('详情路由：本地测试'), findsOneWidget);
    final detailFocus = FocusManager.instance.primaryFocus;
    await tester.pump(const Duration(seconds: 1));
    expect(FocusManager.instance.primaryFocus, same(detailFocus));
    await rootNavigatorKey.currentState!.maybePop();
    await tester.pumpAndSettle();
    _expectVisibleFocus(tester, 7);
  });

  testWidgets('numeric preview supersedes pending directional scroll',
      (tester) async {
    await mount(tester);
    await _press(tester, LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump(const Duration(milliseconds: 10));
    tvChannelInputController.addDigit(2);
    await tester.pumpAndSettle();
    _expectVisibleFocus(tester, 2);
    tvChannelInputController.cancel();
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 2));
    _expectVisibleFocus(tester, 2);
  });

  testWidgets('ragged final row wraps visibly and retains category/rail exits',
      (tester) async {
    final app = await mount(tester, count: 25);
    for (var i = 0; i < 4; i++) {
      await _press(tester, LogicalKeyboardKey.arrowDown);
    }
    _expectVisibleFocus(tester, 25);
    await _press(tester, LogicalKeyboardKey.arrowRight);
    _expectVisibleFocus(tester, 25);
    await _press(tester, LogicalKeyboardKey.arrowDown);
    _expectVisibleFocus(tester, 1);
    await _press(tester, LogicalKeyboardKey.arrowUp);
    expect(FocusManager.instance.primaryFocus!.debugLabel, 'TV category 热门番组');
    await _press(tester, LogicalKeyboardKey.arrowDown);
    _expectVisibleFocus(tester, 1);
    // This fixture returns no new items on pagination, just as the API's
    // current catch-and-return-empty path does on a failed request.
    expect(app.popular.queries, greaterThan(0));
    expect(app.popular.trendList.length, 25);
    expect(app.popular.isTimeOut, isFalse);
  });

  testWidgets('long end-to-start wrap survives recycling the original card',
      (tester) async {
    await mount(tester);
    for (var row = 1; row <= 19; row++) {
      await _press(tester, LogicalKeyboardKey.arrowDown);
    }
    _expectVisibleFocus(tester, 115);
    await _press(tester, LogicalKeyboardKey.arrowDown);
    _expectVisibleFocus(tester, 1);
    await _press(tester, LogicalKeyboardKey.arrowRight);
    _expectVisibleFocus(tester, 2);
    await tester.pump(const Duration(seconds: 1));
    _expectVisibleFocus(tester, 2);
  });
}
