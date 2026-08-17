import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/navigation.dart';

void main() {
  testWidgets('toast remains visible after dismissing a dialog',
      (tester) async {
    await tester.pumpWidget(_buildTestApp());

    unawaited(KazumiDialog.showLoading(msg: '更新中'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('更新中'), findsOneWidget);

    KazumiDialog.dismiss();
    KazumiDialog.showToast(message: '没有可更新的规则');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('没有可更新的规则'), findsOneWidget);
  });

  testWidgets('toast is cleared after popping a page route', (tester) async {
    await tester.pumpWidget(_buildTestApp());

    unawaited(
      rootNavigatorKey.currentState!.push<void>(
        MaterialPageRoute(
          builder: (_) => const Scaffold(body: Text('详情页')),
        ),
      ),
    );
    await tester.pumpAndSettle();

    KazumiDialog.showToast(message: '旧页面提示');
    await tester.pump();
    expect(find.text('旧页面提示'), findsOneWidget);

    rootNavigatorKey.currentState!.pop();
    await tester.pumpAndSettle();

    expect(find.text('旧页面提示'), findsNothing);
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
