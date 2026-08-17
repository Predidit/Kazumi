import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/navigation.dart';
import 'package:kazumi/pages/plugin_editor/plugin_update_actions.dart';
import 'package:kazumi/plugins/plugins_controller.dart';

void main() {
  testWidgets('batch update replaces progress toast with result toast',
      (tester) async {
    final catalogGate = Completer<void>();
    final controller = PluginsController(
      catalogLoader: () async {
        await catalogGate.future;
        return const [];
      },
    );
    await tester.pumpWidget(_buildTestApp());

    final update = updateAllPluginsWithFeedback(
      controller,
      ensureCatalog: true,
    );
    await tester.pump();

    expect(find.text('更新中'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    catalogGate.complete();
    await update;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('更新中'), findsNothing);
    expect(find.text('没有可更新的规则'), findsOneWidget);
  });

  testWidgets('batch update replaces progress toast with failure toast',
      (tester) async {
    final catalogGate = Completer<void>();
    final controller = PluginsController(
      catalogLoader: () async {
        await catalogGate.future;
        throw StateError('catalog unavailable');
      },
      errorReporter: (_, __, ___) {},
    );
    await tester.pumpWidget(_buildTestApp());

    final update = updateAllPluginsWithFeedback(
      controller,
      ensureCatalog: true,
    );
    await tester.pump();
    expect(find.text('更新中'), findsOneWidget);

    catalogGate.complete();
    await update;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('更新中'), findsNothing);
    expect(find.text('更新规则失败'), findsOneWidget);
  });
}

Widget _buildTestApp() {
  return MaterialApp(
    navigatorKey: rootNavigatorKey,
    scaffoldMessengerKey: rootScaffoldMessengerKey,
    navigatorObservers: [KazumiDialog.observer],
    home: const Scaffold(body: SizedBox()),
  );
}
