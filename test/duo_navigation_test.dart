import 'package:kazumi/services/platform/duo_navigation.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kazumi/pages/menu/menu.dart';

const _channel = MethodChannel('com.predidit.kazumi/duo_navigation');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final calls = <MethodCall>[];
  var enabled = true;

  setUp(() {
    DuoNavigation.resetForTesting();
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    calls.clear();
    enabled = true;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, (call) async {
          calls.add(call);
          return call.method == 'enable' ? enabled : null;
        });
  });

  tearDown(() {
    DuoNavigation.resetForTesting();
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null);
  });

  Future<void> mount(WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final module = createModule(
      register: (c) {
        c.route(
          '/',
          child: (context, state) => ScaffoldMenu(location: state.uri.path),
          children: (sub) {
            sub.route(
              '/',
              child: (context, state) => const Text('Tab content'),
            );
            sub.route(
              '/tab/timeline/',
              child: (context, state) => const Text('Timeline'),
            );
          },
        );
      },
    );
    await tester.pumpWidget(
      ModularApp(
        module: module,
        child: Builder(
          builder: (context) => MaterialApp.router(
            routerConfig: ModularApp.routerConfigOf(context),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'native tabs replace Flutter navigation only after native opt-in',
    (tester) async {
      await mount(tester);
      expect(find.text('Tab content'), findsOneWidget);
      expect(find.byType(NavigationRail), findsNothing);
      expect(find.byType(NavigationBar), findsNothing);
      expect(calls.first.method, 'enable');
      final update = Map.of(
        calls.lastWhere((call) => call.method == 'update').arguments as Map,
      );
      final icons = update.remove('icons') as List;
      final colors = update.remove('theme') as Map;
      final scheme = ThemeData().colorScheme;
      expect(colors['selected'], scheme.onSecondaryContainer.toARGB32());
      expect(colors['indicator'], scheme.secondaryContainer.toARGB32());
      expect(
        (icons[1]['icon'] as Map)['codePoint'],
        Icons.timeline_outlined.codePoint,
      );
      expect(
        (icons[1]['selectedIcon'] as Map)['codePoint'],
        Icons.timeline.codePoint,
      );
      expect(
        (icons[0]['icon'] as Map)['codePoint'],
        Icons.home_outlined.codePoint,
      );
      expect(update, {'index': 0, 'visible': true, 'dark': false});

      // A popup covers the shell without a PageRoute notification.
      final context = tester.element(find.text('Tab content'));
      final dialog = showDialog<void>(
        context: context,
        builder: (_) => const AlertDialog(content: Text('Dialog')),
      );
      await tester.pumpAndSettle();
      expect(
        (calls.lastWhere((call) => call.method == 'update').arguments
            as Map)['visible'],
        false,
      );
      Navigator.of(context, rootNavigator: true).pop();
      await dialog;
      await tester.pumpAndSettle();
      expect(
        (calls.lastWhere((call) => call.method == 'update').arguments
            as Map)['visible'],
        true,
      );
      await tester.pumpWidget(const SizedBox());
      debugDefaultTargetPlatformOverride = null;
    },
  );

  testWidgets('native tab taps navigate through the existing outlet', (
    tester,
  ) async {
    await mount(tester);
    await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
      _channel.name,
      const StandardMethodCodec().encodeMethodCall(
        const MethodCall('select', 1),
      ),
      (_) {},
    );
    await tester.pumpAndSettle();
    expect(find.text('Timeline'), findsOneWidget);
    expect(
      (calls.lastWhere((call) => call.method == 'update').arguments
          as Map)['index'],
      1,
    );
    expect(calls.where((call) => call.method == 'enable'), hasLength(1));
    await tester.pumpWidget(const SizedBox());
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('missing native bridge falls back to Flutter navigation', (
    tester,
  ) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null);
    await mount(tester);
    expect(find.byType(NavigationBar), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('other iOS models retain Flutter navigation', (tester) async {
    enabled = false;
    await mount(tester);
    expect(find.text('Tab content'), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(calls.map((call) => call.method), ['enable']);
    await tester.pumpWidget(const SizedBox());
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('non-iOS navigation never calls the native bridge', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    await mount(tester);
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(calls, isEmpty);
    await tester.pumpWidget(const SizedBox());
    debugDefaultTargetPlatformOverride = null;
  });
}
