import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kazumi/navigation.dart';

void main() {
  testWidgets('closes the player and routes above it like back', (
    tester,
  ) async {
    final navigatorKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(navigatorKey: navigatorKey, home: const Text('home')),
    );
    final navigator = navigatorKey.currentState!;

    unawaited(
      navigator.push(
        MaterialPageRoute<void>(builder: (_) => const Text('info')),
      ),
    );
    await tester.pumpAndSettle();

    var popInvoked = false;
    final player = MaterialPageRoute<void>(
      builder: (_) => PopScope(
        onPopInvokedWithResult: (didPop, _) => popInvoked = didPop,
        child: const Text('player'),
      ),
    );
    unawaited(navigator.push(player));
    await tester.pumpAndSettle();
    var pipExited = false;
    player.addLocalHistoryEntry(
      LocalHistoryEntry(onRemove: () => pipExited = true),
    );
    unawaited(
      showDialog<void>(
        context: navigatorKey.currentContext!,
        builder: (_) => const Text('dialog'),
      ),
    );
    await tester.pumpAndSettle();

    popThroughRoute(navigator, player);
    await tester.pumpAndSettle();

    expect(pipExited, isTrue);
    expect(popInvoked, isTrue);
    expect(player.isActive, isFalse);
    expect(find.text('info'), findsOneWidget);
    expect(find.text('player'), findsNothing);
    expect(find.text('dialog'), findsNothing);

    popThroughRoute(navigator, player);
    await tester.pumpAndSettle();
    expect(find.text('info'), findsOneWidget);
  });

  testWidgets('closes a page-based player like the app router does', (
    tester,
  ) async {
    final navigatorKey = GlobalKey<NavigatorState>();
    var popInvoked = false;
    final pages = <Page<void>>[
      const MaterialPage(key: ValueKey('home'), child: Text('home')),
      const MaterialPage(key: ValueKey('info'), child: Text('info')),
      MaterialPage(
        key: const ValueKey('player'),
        child: PopScope(
          onPopInvokedWithResult: (didPop, _) => popInvoked = didPop,
          child: const Text('player'),
        ),
      ),
    ];
    late StateSetter setPages;
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            setPages = setState;
            return Navigator(
              key: navigatorKey,
              pages: List.of(pages),
              // Mirrors ModularRouterDelegate's synchronous page removal.
              // ignore: deprecated_member_use
              onPopPage: (route, result) {
                if (!route.didPop(result)) return false;
                setPages(() => pages.remove(route.settings));
                return true;
              },
            );
          },
        ),
      ),
    );
    final navigator = navigatorKey.currentState!;
    final player = ModalRoute.of(tester.element(find.text('player')))!;

    popThroughRoute(navigator, player);
    await tester.pumpAndSettle();

    expect(popInvoked, isTrue);
    expect(pages.map((page) => page.key), [
      const ValueKey('home'),
      const ValueKey('info'),
    ]);
    expect(find.text('info'), findsOneWidget);
  });

  testWidgets('leaves the player open while a route above it vetoes pop', (
    tester,
  ) async {
    final navigatorKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(navigatorKey: navigatorKey, home: const Text('home')),
    );
    final navigator = navigatorKey.currentState!;
    final player = MaterialPageRoute<void>(
      builder: (_) => const Text('player'),
    );
    unawaited(navigator.push(player));
    await tester.pumpAndSettle();

    final saving = ValueNotifier(true);
    addTearDown(saving.dispose);
    unawaited(
      showModalBottomSheet<void>(
        context: navigatorKey.currentContext!,
        builder: (_) => ValueListenableBuilder(
          valueListenable: saving,
          builder: (_, saving, _) =>
              PopScope(canPop: !saving, child: const Text('export')),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(popThroughRoute(navigator, player), isFalse);
    await tester.pumpAndSettle();
    expect(player.isActive, isTrue);
    expect(find.text('export'), findsOneWidget);

    saving.value = false;
    await tester.pump();
    expect(popThroughRoute(navigator, player), isTrue);
    await tester.pumpAndSettle();
    expect(player.isActive, isFalse);
    expect(find.text('home'), findsOneWidget);
  });
}
