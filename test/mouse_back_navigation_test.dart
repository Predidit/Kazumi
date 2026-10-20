import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kazumi/bean/dialog/adaptive_bottom_sheet.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/bean/widget/kazumi_menu.dart';
import 'package:kazumi/navigation.dart';
import 'package:kazumi/pages/menu/menu.dart';

final _desktopVariant = TargetPlatformVariant.only(TargetPlatform.windows);

Future<void> mountApp(
  WidgetTester tester, {
  Widget? home,
}) async {
  await tester.pumpWidget(MaterialApp(
    navigatorKey: rootNavigatorKey,
    scaffoldMessengerKey: rootScaffoldMessengerKey,
    navigatorObservers: [KazumiDialog.observer, rootRouteObserver],
    builder: (context, child) => DesktopMouseBackNavigation(
      child: child ?? const SizedBox.shrink(),
    ),
    home: home ?? const Scaffold(body: Text('home')),
  ));
  await tester.pumpAndSettle();
}

Future<void> mountModularApp(
  WidgetTester tester, {
  required Module module,
}) async {
  await tester.pumpWidget(
    ModularApp(
      module: module,
      navigatorKey: rootNavigatorKey,
      navigatorObservers: [KazumiDialog.observer, rootRouteObserver],
      defaultTransition: TransitionType.material,
      child: Builder(
        builder: (context) => MaterialApp.router(
          scaffoldMessengerKey: rootScaffoldMessengerKey,
          routerConfig: ModularApp.routerConfigOf(context),
          builder: (context, child) => DesktopMouseBackNavigation(
            child: child ?? const SizedBox.shrink(),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> pushPage(
  WidgetTester tester, {
  required String label,
  Widget? child,
}) async {
  unawaited(rootNavigatorKey.currentState!.push<void>(MaterialPageRoute(
    builder: (_) => Scaffold(body: child ?? Text(label)),
  )));
  await tester.pumpAndSettle();
}

Future<void> clickMouseBack(
  WidgetTester tester, {
  Offset position = const Offset(100, 100),
}) async {
  final gesture = await tester.createGesture(
    kind: PointerDeviceKind.mouse,
    buttons: kBackMouseButton,
  );
  await gesture.down(position);
  await tester.pump();
  await gesture.up();
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'pops secondary page on mouse back button release, not on press',
    variant: _desktopVariant,
    (tester) async {
      await mountApp(tester);
      await pushPage(tester, label: 'info page');
      expect(find.text('info page'), findsOneWidget);

      final gesture = await tester.createGesture(
        kind: PointerDeviceKind.mouse,
        buttons: kBackMouseButton,
      );
      await gesture.down(const Offset(100, 100));
      await tester.pumpAndSettle();
      expect(find.text('info page'), findsOneWidget);

      await gesture.up();
      await tester.pumpAndSettle();
      expect(find.text('info page'), findsNothing);
      expect(find.text('home'), findsOneWidget);
    },
  );

  testWidgets(
    'ignores chorded click, pointer cancel, and forward mouse side button',
    variant: _desktopVariant,
    (tester) async {
      await mountApp(tester);
      await pushPage(tester, label: 'info page');

      const pos = Offset(100, 100);
      tester.binding.handlePointerEvent(const PointerDownEvent(
        pointer: 11,
        kind: PointerDeviceKind.mouse,
        position: pos,
        buttons: kBackMouseButton,
      ));
      tester.binding.handlePointerEvent(const PointerMoveEvent(
        pointer: 11,
        kind: PointerDeviceKind.mouse,
        position: pos,
        buttons: kBackMouseButton | kPrimaryMouseButton,
      ));
      tester.binding.handlePointerEvent(const PointerUpEvent(
        pointer: 11,
        kind: PointerDeviceKind.mouse,
        position: pos,
      ));
      await tester.pumpAndSettle();
      expect(find.text('info page'), findsOneWidget);

      tester.binding.handlePointerEvent(const PointerDownEvent(
        pointer: 12,
        kind: PointerDeviceKind.mouse,
        position: pos,
        buttons: kBackMouseButton,
      ));
      tester.binding.handlePointerEvent(const PointerCancelEvent(
        pointer: 12,
        kind: PointerDeviceKind.mouse,
        position: pos,
      ));
      tester.binding.handlePointerEvent(const PointerUpEvent(
        pointer: 12,
        kind: PointerDeviceKind.mouse,
        position: pos,
      ));
      await tester.pumpAndSettle();
      expect(find.text('info page'), findsOneWidget);

      final forwardGesture = await tester.createGesture(
        kind: PointerDeviceKind.mouse,
        buttons: kForwardMouseButton,
      );
      await forwardGesture.down(pos);
      await tester.pump();
      await forwardGesture.up();
      await tester.pumpAndSettle();
      expect(find.text('info page'), findsOneWidget);
    },
  );

  testWidgets(
    'ignores mouse back button when a KazumiDialog is open',
    variant: _desktopVariant,
    (tester) async {
      await mountApp(tester);
      await pushPage(tester, label: 'info page');

      final dialog = KazumiDialogHandle<void>();
      unawaited(KazumiDialog.show<void>(
        handle: dialog,
        builder: (_) => const AlertDialog(title: Text('confirm dialog')),
      ));
      await tester.pumpAndSettle();
      expect(find.text('confirm dialog'), findsOneWidget);

      await clickMouseBack(tester, position: const Offset(10, 10));
      expect(find.text('confirm dialog'), findsOneWidget);
      expect(dialog.isActive, isTrue);

      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      expect(find.text('confirm dialog'), findsNothing);
      expect(find.text('info page'), findsOneWidget);
    },
  );

  testWidgets(
    'ignores mouse back button when an adaptive bottom sheet is open',
    variant: _desktopVariant,
    (tester) async {
      await mountApp(tester);
      await pushPage(tester, label: 'info page');

      unawaited(showAdaptiveBottomSheet<void>(
        context: rootNavigatorKey.currentContext!,
        builder: (_) =>
            const SizedBox(height: 120, child: Text('episode sheet')),
      ));
      await tester.pumpAndSettle();
      expect(find.text('episode sheet'), findsOneWidget);

      await clickMouseBack(tester, position: const Offset(10, 10));
      expect(find.text('episode sheet'), findsOneWidget);

      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      expect(find.text('episode sheet'), findsNothing);
      expect(find.text('info page'), findsOneWidget);
    },
  );

  testWidgets(
    'ignores mouse back when KazumiMenuButton is open and restores after close or dispose',
    variant: _desktopVariant,
    (tester) async {
      final showMenuButton = ValueNotifier<bool>(true);
      addTearDown(showMenuButton.dispose);
      final menuController = MenuController();

      await mountApp(tester);
      await pushPage(
        tester,
        label: 'player settings',
        child: ValueListenableBuilder<bool>(
          valueListenable: showMenuButton,
          builder: (context, visible, _) => visible
              ? KazumiMenuButton(
                  controller: menuController,
                  builder: (_, toggle) => TextButton(
                    onPressed: toggle,
                    child: const Text('open menu'),
                  ),
                  menuChildren: [
                    KazumiMenuItem(
                      label: 'option 1',
                      requestFocusOnHover: false,
                      onPressed: () {},
                    ),
                  ],
                )
              : const Text('menu removed'),
        ),
      );

      await tester.tap(find.text('open menu'));
      await tester.pumpAndSettle();
      expect(find.text('option 1'), findsOneWidget);
      expect(KazumiMenuButton.hasOpenMenu, isTrue);

      await clickMouseBack(tester, position: const Offset(300, 300));
      expect(find.text('open menu'), findsOneWidget);
      expect(find.text('option 1'), findsOneWidget);
      expect(KazumiMenuButton.hasOpenMenu, isTrue);

      await tester.tapAt(const Offset(300, 300));
      await tester.pumpAndSettle();
      expect(find.text('option 1'), findsNothing);
      expect(KazumiMenuButton.hasOpenMenu, isFalse);

      await tester.tap(find.text('open menu'));
      await tester.pumpAndSettle();
      expect(KazumiMenuButton.hasOpenMenu, isTrue);

      showMenuButton.value = false;
      await tester.pumpAndSettle();
      expect(KazumiMenuButton.hasOpenMenu, isFalse);

      await clickMouseBack(tester);
      expect(find.text('menu removed'), findsNothing);
      expect(find.text('home'), findsOneWidget);
    },
  );

  testWidgets(
    'ignores mouse back on Modular video route without RouteSettings.name and pops image preview',
    variant: _desktopVariant,
    (tester) async {
      var videoPopInvoked = false;
      final module = createModule(
        register: (c) {
          c
            ..route(
              '/',
              child: (context, state) =>
                  const Scaffold(body: Text('root page')),
            )
            ..route(
              '/info',
              child: (context, state) =>
                  const Scaffold(body: Text('info page')),
            )
            ..route(
              '/image-preview',
              child: (context, state) =>
                  const Scaffold(body: Text('image viewer')),
            )
            ..route(
              '/video',
              child: (context, state) => MouseBackNavigationBlocker(
                child: PopScope(
                  onPopInvokedWithResult: (didPop, _) {
                    if (didPop) {
                      videoPopInvoked = true;
                    }
                  },
                  child: const Scaffold(body: Text('video player')),
                ),
              ),
            );
        },
      );

      await mountModularApp(tester, module: module);
      final rootContext = find.text('root page').evaluate().single;
      unawaited(rootContext.pushNamed('/info'));
      await tester.pumpAndSettle();
      expect(find.text('info page'), findsOneWidget);

      final infoContext = find.text('info page').evaluate().single;
      unawaited(infoContext.pushNamed('/image-preview'));
      await tester.pumpAndSettle();
      expect(find.text('image viewer'), findsOneWidget);

      await clickMouseBack(tester);
      expect(find.text('image viewer'), findsNothing);
      expect(find.text('info page'), findsOneWidget);

      final currentInfoContext = find.text('info page').evaluate().single;
      unawaited(currentInfoContext.pushNamed('/video'));
      await tester.pumpAndSettle();
      expect(find.text('video player'), findsOneWidget);

      await clickMouseBack(tester);
      expect(find.text('video player'), findsOneWidget);
      expect(videoPopInvoked, isFalse);

      // A page pushed above the player (e.g. image preview) can still pop via mouse back.
      final videoContext = find.text('video player').evaluate().single;
      unawaited(videoContext.pushNamed('/image-preview'));
      await tester.pumpAndSettle();
      expect(find.text('image viewer'), findsOneWidget);

      await clickMouseBack(tester);
      expect(find.text('image viewer'), findsNothing);
      expect(find.text('video player'), findsOneWidget);
      expect(videoPopInvoked, isFalse);

      // Back on the player route, mouse back remains blocked.
      await clickMouseBack(tester);
      expect(find.text('video player'), findsOneWidget);
      expect(videoPopInvoked, isFalse);

      await rootNavigatorKey.currentState!.maybePop();
      await tester.pumpAndSettle();
      expect(videoPopInvoked, isTrue);
      expect(find.text('info page'), findsOneWidget);

      await clickMouseBack(tester);
      expect(find.text('info page'), findsNothing);
      expect(find.text('root page'), findsOneWidget);
    },
  );

  testWidgets(
    'supports ScaffoldMenu tab fallback, nested RouterOutlet, and nested bottom sheet without SystemNavigator.pop',
    variant: _desktopVariant,
    (tester) async {
    tester.view.physicalSize = const Size(500, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    var systemNavigatorPopCount = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'SystemNavigator.pop') {
        systemNavigatorPopCount++;
      }
      return null;
    });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });

    final settingsOutletKey = GlobalKey<RouterOutletState>();
    final module = createModule(
      register: (c) {
        c
          ..route(
            '/',
            child: (context, state) =>
                const Scaffold(body: Text('init loading')),
          )
          ..route(
            '/tab',
            child: (context, state) => ScaffoldMenu(location: state.uri.path),
            children: (sub) {
              sub
                ..route(
                  '/popular',
                  child: (context, state) =>
                      const Scaffold(body: Text('popular tab')),
                )
                ..route(
                  '/timeline',
                  child: (context, state) =>
                      const Scaffold(body: Text('timeline tab')),
                )
                ..route(
                  '/collect',
                  child: (context, state) =>
                      const Scaffold(body: Text('collect tab')),
                )
                ..route(
                  '/my',
                  child: (context, state) =>
                      const Scaffold(body: Text('my tab')),
                );
            },
          )
          ..route(
            '/image-preview',
            child: (context, state) =>
                const Scaffold(body: Text('image viewer')),
          )
          ..route(
            '/settings',
            child: (context, state) => NavigatorPopHandler<Object?>(
              onPopWithResult: (_) {
                if (settingsOutletKey.currentState?.maybePop() ?? false) {
                  return;
                }
                context.maybePop();
              },
              child: Scaffold(
                body: RouterOutlet(key: settingsOutletKey),
              ),
            ),
            children: (sub) {
              sub
                ..route(
                  '/',
                  child: (context, state) =>
                      const Scaffold(body: Text('settings index')),
                )
                ..route(
                  '/decoder',
                  child: (context, state) =>
                      const Scaffold(body: Text('decoder settings')),
                );
            },
          );
      },
    );

    await mountModularApp(tester, module: module);
    expect(find.text('init loading'), findsOneWidget);

    // Single-page root route (InitPage) ignores mouse back without exiting app.
    await clickMouseBack(tester);
    expect(find.text('init loading'), findsOneWidget);
    expect(systemNavigatorPopCount, 0);

    final initContext = find.text('init loading').evaluate().single;
    initContext.navigate('/tab/my/');
    await tester.pumpAndSettle();
    expect(find.text('my tab'), findsOneWidget);

    // Push nested settings shell and a child route inside its RouterOutlet.
    final myContext = find.text('my tab').evaluate().single;
    unawaited(myContext.pushNamed('/settings/'));
    await tester.pumpAndSettle();
    expect(find.text('settings index'), findsOneWidget);

    unawaited(settingsOutletKey.currentState!.push<void>('/settings/decoder'));
    await tester.pumpAndSettle();
    expect(find.text('decoder settings'), findsOneWidget);

    // Open a bottom sheet on the nested RouterOutlet navigator (useRootNavigator: false).
    final decoderContext = find.text('decoder settings').evaluate().single;
    unawaited(showAdaptiveBottomSheet<void>(
      context: decoderContext,
      useRootNavigator: false,
      builder: (_) => const SizedBox(height: 120, child: Text('nested sheet')),
    ));
    await tester.pumpAndSettle();
    expect(find.text('nested sheet'), findsOneWidget);

    await clickMouseBack(tester);
    expect(find.text('nested sheet'), findsOneWidget);

    // A root page pushed over the nested sheet is not blocked by the background sheet.
    unawaited(decoderContext.pushNamed('/image-preview'));
    await tester.pumpAndSettle();
    expect(find.text('image viewer'), findsOneWidget);

    await clickMouseBack(tester);
    expect(find.text('image viewer'), findsNothing);
    expect(find.text('nested sheet'), findsOneWidget);

    // Back on the settings route, the still-open nested sheet blocks mouse back again.
    await clickMouseBack(tester);
    expect(find.text('nested sheet'), findsOneWidget);

    Navigator.of(decoderContext).pop();
    await tester.pumpAndSettle();
    expect(find.text('nested sheet'), findsNothing);

    // First mouse back pops nested '/settings/decoder' back to '/settings/'.
    await clickMouseBack(tester);
    expect(find.text('settings index'), findsOneWidget);

    // Second mouse back exits '/settings/' back to '/tab/my/'.
    await clickMouseBack(tester);
    expect(find.text('my tab'), findsOneWidget);

    // Mouse back on non-home tab ('/tab/my/') returns to home tab ('/tab/popular/').
    await clickMouseBack(tester);
    expect(find.text('popular tab'), findsOneWidget);

    // Mouse back on home tab ('/tab/popular/') is a no-op without toast or exit.
    await clickMouseBack(tester);
    expect(find.text('popular tab'), findsOneWidget);
    expect(find.text('再按一次退出应用'), findsNothing);
    expect(systemNavigatorPopCount, 0);
  });
}
