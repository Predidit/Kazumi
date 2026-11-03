import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/navigation.dart';

Future<void> mountApp(WidgetTester tester, {Widget? home}) async {
  await tester.pumpWidget(MaterialApp(
    navigatorKey: rootNavigatorKey,
    scaffoldMessengerKey: rootScaffoldMessengerKey,
    navigatorObservers: [KazumiDialog.observer],
    home: home ?? const Scaffold(body: Text('home')),
  ));
  await tester.pumpAndSettle();
}

Widget progress(BuildContext context) =>
    const AlertDialog(title: Text('loading'));

void main() {
  testWidgets('loading returns its value and preserves a newer dialog',
      (tester) async {
    await mountApp(tester);
    final dialogs = KazumiDialogController();
    addTearDown(dialogs.dispose);
    final response = Completer<int>();
    int? result;
    var cancelled = false;
    final run = dialogs.run((task) async {
      result = await task.loading(
        action: () => response.future,
        onCancel: () => cancelled = true,
        builder: progress,
      );
    });
    await tester.pumpAndSettle();
    final other = KazumiDialogHandle<void>();
    unawaited(KazumiDialog.show<void>(
      handle: other,
      builder: (_) => const AlertDialog(title: Text('other')),
    ));
    await tester.pumpAndSettle();
    response.complete(42);
    await tester.pumpAndSettle();
    await run;
    expect(result, 42);
    expect(cancelled, isFalse);
    expect(dialogs.isRunning, isFalse);
    expect(other.isActive, isTrue);
    expect(find.text('loading'), findsNothing);
    other.dismiss();
    await tester.pumpAndSettle();
  });

  testWidgets(
      'loading can complete before its first frame and continue to a choice',
      (tester) async {
    await mountApp(tester);
    final dialogs = KazumiDialogController();
    addTearDown(dialogs.dispose);
    bool? choice;
    final run = dialogs.run((task) async {
      expectSync(await task.loading(action: () async => 7), 7);
      choice = await task.show<bool>(
          builder: (context) => AlertDialog(
                title: const Text('choice'),
                actions: [
                  TextButton(
                    onPressed: () =>
                        KazumiDialog.dismiss(context: context, popWith: false),
                    child: const Text('no'),
                  )
                ],
              ));
      expectSync(await task.loading(action: () async => 8), 8);
    });
    await tester.pumpAndSettle();
    expect(find.text('choice'), findsOneWidget);
    await tester.tap(find.text('no'));
    await tester.pumpAndSettle();
    await run;
    expect(choice, isFalse);
    expectSync(KazumiDialog.observer.hasKazumiDialog, isFalse);
  });

  testWidgets('dismissing a choice stops the remaining workflow',
      (tester) async {
    await mountApp(tester);
    final dialogs = KazumiDialogController();
    addTearDown(dialogs.dispose);
    var continued = false;
    var cancellations = 0;
    final run = dialogs.run((task) async {
      await task.show<int>(
          builder: (_) => const AlertDialog(title: Text('choice')));
      continued = true;
    }, onCancelled: () => cancellations++);
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await run;
    expect(continued, isFalse);
    expect(cancellations, 1);
  });

  for (final lateFailure in [false, true]) {
    testWidgets(
        'back ends an uncooperative request and ignores late ${lateFailure ? 'failure' : 'success'}',
        (tester) async {
      await mountApp(tester);
      final dialogs = KazumiDialogController();
      addTearDown(dialogs.dispose);
      final response = Completer<int>();
      var continued = false;
      var cancellations = 0;
      var errors = 0;
      final run = dialogs.run((task) async {
        await task.loading(
          action: () => response.future,
          onCancel: () => cancellations++,
          builder: progress,
        );
        continued = true;
      }, onError: (error, stackTrace) => errors++);
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await run;
      dialogs.cancel();
      expect(dialogs.isRunning, isFalse);
      expect(response.isCompleted, isFalse);
      expect(cancellations, 1);
      if (lateFailure) {
        response.completeError(StateError('late response'));
      } else {
        response.complete(42);
      }
      await tester.pumpAndSettle();
      expect(continued, isFalse);
      expect(errors, 0);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('back wins when a response completes in the same turn',
      (tester) async {
    await mountApp(tester);
    final dialogs = KazumiDialogController();
    addTearDown(dialogs.dispose);
    final response = Completer<int>();
    var continued = false;
    final run = dialogs.run((task) async {
      await task.loading(action: () => response.future, builder: progress);
      continued = true;
    });
    await tester.pumpAndSettle();
    rootNavigatorKey.currentState!.pop();
    response.complete(42);
    await tester.pumpAndSettle();
    await run;
    expect(continued, isFalse);
  });

  testWidgets(
      'cancellation awaits resource cleanup before fallback or disposal',
      (tester) async {
    await mountApp(tester);
    final dialogs = KazumiDialogController();
    addTearDown(dialogs.dispose);
    final response = Completer<int>();
    final cleanup = Completer<void>();
    final events = <String>[];
    final run = dialogs.run((task) async {
      try {
        await task.loading(
          action: () => response.future,
          builder: progress,
          onCancel: () async {
            events.add('save');
            await cleanup.future;
            events.add('saved');
          },
        );
        events.add('continued');
      } finally {
        events.add('dispose');
      }
    }, onCancelled: () => events.add('fallback'));
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(events, ['save']);
    dialogs.cancel();
    cleanup.complete();
    await tester.pumpAndSettle();
    await run;
    expect(events, ['save', 'saved', 'dispose', 'fallback']);
    response.complete(0);
    await tester.pumpAndSettle();
  });

  testWidgets('replacement ignores old cleanup and keeps the new workflow open',
      (tester) async {
    await mountApp(tester);
    final dialogs = KazumiDialogController();
    addTearDown(dialogs.dispose);
    final response = Completer<int>();
    final cleanup = Completer<void>();
    var oldFallback = false;
    late KazumiDialogTask oldTask;
    final first = dialogs.run((task) async {
      oldTask = task;
      await task.loading(
        action: () => response.future,
        onCancel: () => cleanup.future,
        builder: progress,
      );
      fail('replaced workflow continued');
    }, onCancelled: () => oldFallback = true);
    await tester.pumpAndSettle();
    final second = dialogs.run((task) async {
      await task.show<bool>(
          builder: (_) => const AlertDialog(title: Text('new choice')));
    });
    await tester.pumpAndSettle();
    cleanup.complete();
    response.completeError(StateError('old failure'));
    await tester.pumpAndSettle();
    await first;
    oldTask.cancel();
    expect(oldFallback, isFalse);
    expect(dialogs.isRunning, isTrue);
    expect(find.text('new choice'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await second;
  });

  testWidgets('real failures reach the error handler after loading is closed',
      (tester) async {
    await mountApp(tester);
    final dialogs = KazumiDialogController();
    addTearDown(dialogs.dispose);
    final response = Completer<int>();
    final failure = StateError('request failed');
    Object? reported;
    var cancelled = false;
    final run = dialogs.run((task) async {
      await task.loading(
        action: () => response.future,
        onCancel: () => cancelled = true,
        builder: progress,
      );
      fail('failed request continued');
    }, onError: (error, _) {
      reported = error;
      expectSync(KazumiDialog.observer.hasKazumiDialog, isFalse);
    });
    await tester.pumpAndSettle();
    response.completeError(failure);
    await tester.pumpAndSettle();
    await run;
    expect(reported, same(failure));
    expect(cancelled, isFalse);
  });

  testWidgets('a synchronous request error uses the configured toast',
      (tester) async {
    await mountApp(tester);
    final dialogs = KazumiDialogController();
    addTearDown(dialogs.dispose);
    final run = dialogs.run((task) async {
      await task.loading<int>(action: () => throw StateError('failed'));
    }, errorMessage: 'request failed');
    await tester.pumpAndSettle();
    await run;
    expect(find.text('request failed'), findsOneWidget);
    expectSync(KazumiDialog.observer.hasKazumiDialog, isFalse);
  });

  testWidgets('owner disposal closes its workflow and preserves another dialog',
      (tester) async {
    final present = ValueNotifier(true);
    addTearDown(present.dispose);
    final response = Completer<int>();
    var cancelled = false;
    var continued = false;
    var fallback = false;
    await mountApp(tester,
        home: ValueListenableBuilder<bool>(
          valueListenable: present,
          builder: (context, visible, child) => visible
              ? _Owner(
                  operation: response.future,
                  onCancel: () => cancelled = true,
                  onResult: () => continued = true,
                  onFallback: () => fallback = true,
                )
              : const Scaffold(body: Text('replacement')),
        ));
    await tester.tap(find.text('start'));
    await tester.pumpAndSettle();
    final other = KazumiDialogHandle<void>();
    unawaited(KazumiDialog.show<void>(
      handle: other,
      builder: (_) => const AlertDialog(title: Text('other')),
    ));
    await tester.pumpAndSettle();
    present.value = false;
    await tester.pumpAndSettle();
    expect(cancelled, isTrue);
    expect(other.isActive, isTrue);
    response.complete(42);
    await tester.pumpAndSettle();
    expect(continued, isFalse);
    expect(fallback, isFalse);
    expect(tester.takeException(), isNull);
    other.dismiss();
    await tester.pumpAndSettle();
    expect(find.text('loading'), findsNothing);
    expect(find.text('replacement'), findsOneWidget);
  });

  testWidgets('owner rebuilds busy state and applies a result with its context',
      (tester) async {
    final response = Completer<int>();
    var continued = false;
    await mountApp(tester,
        home: _Owner(
          operation: response.future,
          onCancel: () {},
          onResult: () => continued = true,
          onFallback: () {},
        ));
    await tester.tap(find.text('start'));
    await tester.pumpAndSettle();
    expect(find.text('busy', skipOffstage: false), findsOneWidget);
    response.complete(42);
    await tester.pumpAndSettle();
    expect(continued, isTrue);
    expect(find.text('start'), findsOneWidget);
    expect(find.text('busy'), findsNothing);
  });
}

class _Owner extends StatefulWidget {
  const _Owner(
      {required this.operation,
      required this.onCancel,
      required this.onResult,
      required this.onFallback});
  final Future<int> operation;
  final VoidCallback onCancel;
  final VoidCallback onResult;
  final VoidCallback onFallback;

  @override
  State<_Owner> createState() => _OwnerState();
}

class _OwnerState extends State<_Owner> with KazumiDialogOwner {
  @override
  Widget build(BuildContext context) => Scaffold(
          body: TextButton(
        onPressed: () => dialogs.run((task) async {
          await task.loading(
              action: () => widget.operation,
              onCancel: widget.onCancel,
              builder: progress);
          task.withContext((context) {
            expectSync(context.mounted, isTrue);
            widget.onResult();
          });
        }, onCancelled: widget.onFallback),
        child: Text(dialogs.isRunning ? 'busy' : 'start'),
      ));
}
