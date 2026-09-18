import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:kazumi/bean/widget/gamepad_navigation.dart';
import 'package:kazumi/navigation.dart';
import 'package:kazumi/pages/settings/settings_page.dart';
import 'package:kazumi/services/platform/gamepad_input_service.dart';
import 'package:kazumi/services/storage/storage.dart';
import 'package:logger/logger.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:universal_gamepad/universal_gamepad.dart';

const categories = [
  'player',
  'danmaku',
  'keyboard',
  'plugin',
  'download-settings',
  'theme',
  'interface',
  'sync',
  'proxy',
  'update',
  'storage',
  'about'
];

class _Paths extends PathProviderPlatform {
  _Paths(this.path);
  final String path;
  @override
  Future<String?> getApplicationSupportPath() async => path;
}

void main() {
  late Directory temp;
  late PathProviderPlatform original;
  late GamepadInputService service;
  setUpAll(() async {
    Logger.level = Level.off;
    temp = await Directory.systemTemp.createTemp('kazumi_settings_gamepad_');
    original = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _Paths(temp.path);
    Hive.init(temp.path);
    await GStorage.init();
  });
  tearDownAll(() async {
    await Hive.close();
    PathProviderPlatform.instance = original;
    await temp.delete(recursive: true);
  });
  setUp(() {
    service = GamepadInputService(
        events: const Stream.empty(), duplicateWindow: Duration.zero);
  });

  Future<void> openSettings(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1100, 620);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final module = createModule(register: (c) {
      c.route('/settings',
          child: (context, state) => SettingsPage(location: state.uri.path),
          children: (sub) {
            for (final category in categories) {
              sub.route('/$category',
                  child: (context, state) => Scaffold(
                          body: Column(children: [
                        Text('detail:$category'),
                        TextButton(
                            onPressed: () =>
                                context.pushNamed('/settings/$category/child'),
                            child: Text('open:$category')),
                        TextButton(
                            onPressed: () {}, child: Text('action:$category')),
                      ])));
              sub.route('/$category/child',
                  child: (context, state) => Scaffold(
                      body: TextButton(
                          onPressed: () => context.maybePop(),
                          child: Text('child:$category'))));
            }
          });
    });
    await tester.pumpWidget(ModularApp(
      module: module,
      initialRoute: '/settings/player',
      navigatorKey: rootNavigatorKey,
      navigatorObservers: [topRouteObserver],
      child: Builder(
          builder: (context) => MaterialApp.router(
                routerConfig: ModularApp.routerConfigOf(context),
                builder: (context, child) =>
                    GamepadNavigationScope(service: service, child: child!),
              )),
    ));
    await tester.pumpAndSettle();
  }

  Future<void> press(WidgetTester tester, GamepadButton button) async {
    service.handleEvent(GamepadButtonEvent(
        gamepadId: 1, timestamp: 0, button: button, pressed: true, value: 1));
    service.handleEvent(GamepadButtonEvent(
        gamepadId: 1, timestamp: 0, button: button, pressed: false, value: 0));
    await tester.pumpAndSettle();
  }

  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    service.reset();
    unawaited(service.dispose());
    await tester.pump();
  }

  testWidgets(
      'all sidebar categories preview on focus and remain reachable after scrolling',
      (tester) async {
    await openSettings(tester);
    expect(FocusManager.instance.primaryFocus?.debugLabel, '/settings/player');
    for (final category in categories.skip(1)) {
      await press(tester, GamepadButton.dpadDown);
      expect(FocusManager.instance.primaryFocus?.debugLabel,
          '/settings/$category');
      expect(find.text('detail:$category'), findsOneWidget);
      final rect = FocusManager.instance.primaryFocus!.rect;
      expect(rect.top, greaterThanOrEqualTo(0));
      expect(rect.bottom, lessThanOrEqualTo(620));
    }
    await press(tester, GamepadButton.dpadDown);
    expect(FocusManager.instance.primaryFocus?.debugLabel, '/settings/about');
    await press(tester, GamepadButton.dpadRight);
    expect(FocusManager.instance.primaryFocus?.debugLabel,
        isNot('/settings/about'));
    await press(tester, GamepadButton.dpadLeft);
    expect(FocusManager.instance.primaryFocus?.debugLabel, '/settings/about');
    await press(tester, GamepadButton.a);
    await press(tester, GamepadButton.b);
    expect(FocusManager.instance.primaryFocus?.debugLabel, '/settings/about');
    await close(tester);
  });

  testWidgets(
      'held stick traverses replaced category routes and neutral stops immediately',
      (tester) async {
    await openSettings(tester);
    void axis(double value) => service.handleEvent(GamepadAxisEvent(
        gamepadId: 1,
        timestamp: 0,
        axis: GamepadAxis.leftStickY,
        value: value));
    axis(1);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    axis(0);
    await tester.pumpAndSettle();
    final stopped = FocusManager.instance.primaryFocus?.debugLabel;
    expect(stopped, isNot('/settings/player'));
    expect(stopped, isNot('/settings/danmaku'));
    expect(stopped, startsWith('/settings/'));
    await tester.pump(const Duration(seconds: 2));
    expect(FocusManager.instance.primaryFocus?.debugLabel, stopped);
    await close(tester);
  });

  testWidgets('B pops a nested detail before returning to the sidebar',
      (tester) async {
    await openSettings(tester);
    await press(tester, GamepadButton.dpadRight);
    await press(tester, GamepadButton.a);
    expect(find.text('child:player'), findsOneWidget);
    await press(tester, GamepadButton.b);
    expect(find.text('child:player'), findsNothing);
    expect(find.text('detail:player'), findsOneWidget);
    await press(tester, GamepadButton.b);
    expect(FocusManager.instance.primaryFocus?.debugLabel, '/settings/player');
    await close(tester);
  });

  testWidgets('hidden sidebar cannot retain focus after narrowing the window',
      (tester) async {
    await openSettings(tester);
    await press(tester, GamepadButton.dpadDown);
    tester.view.physicalSize = const Size(500, 800);
    await tester.pumpAndSettle();
    expect(FocusManager.instance.primaryFocus?.debugLabel,
        isNot('/settings/danmaku'));
    expect(isGamepadFocusUsable(FocusManager.instance.primaryFocus!), isTrue);
    tester.view.physicalSize = const Size(1100, 620);
    await tester.pumpAndSettle();
    expect(FocusManager.instance.primaryFocus?.debugLabel, '/settings/danmaku');
    await close(tester);
  });
}
