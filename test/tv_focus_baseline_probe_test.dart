// These probes use only pre-existing public widgets/APIs so they can also be
// run against f699c80 to reproduce UI-03/UI-04 before testing the fix.
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:kazumi/bean/card/bangumi_history_card.dart';
import 'package:kazumi/services/platform/tv_mode.dart';
import 'package:kazumi/services/storage/storage.dart';
import 'support/tv_focus_fixtures.dart';

class _Paths extends PathProviderPlatform {
  _Paths(this.path);
  final String path;
  @override
  Future<String?> getApplicationSupportPath() async => path;
}

List<FocusNode> targetsInside(WidgetTester tester, Finder finder) {
  final rect = tester.getRect(finder);
  return FocusManager.instance.rootScope.descendants
      .where((node) =>
          node.context != null &&
          node.canRequestFocus &&
          !node.skipTraversal &&
          rect.contains(node.rect.center))
      .toList();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory temp;
  setUpAll(() async {
    temp = await Directory.systemTemp.createTemp('kazumi_focus_probe_');
    PathProviderPlatform.instance = _Paths(temp.path);
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
  tearDown(() => TvMode.setEnabledForTesting(false));
  Future<void> mount(WidgetTester tester, String route) async {
    tester.view.physicalSize = const Size(960, 540);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(FocusFixtureApp(initialRoute: route));
    await tester.pumpAndSettle();
  }

  testWidgets(
      'UI03 baseline probe: remote can activate a search-bar target to edit',
      (tester) async {
    await mount(tester, '/search/');
    final targets = targetsInside(tester, find.byType(SearchBar));
    expect(targets, isNotEmpty,
        reason: 'Search bar has no remote-focusable target');
    targets.first.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pumpAndSettle();
    expect(tester.testTextInput.isVisible, isTrue,
        reason: 'OK must enter text input');
  });
  testWidgets(
      'UI04 baseline probe: edit-mode card OK opens delete confirmation',
      (tester) async {
    await mount(tester, '/tab/history/');
    await tester.tap(find.byTooltip('管理历史记录'));
    await tester.pumpAndSettle();
    final targets =
        targetsInside(tester, find.byType(BangumiHistoryCardV).first);
    expect(targets, isNotEmpty);
    targets.first.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget,
        reason:
            'Edit-mode OK must offer confirmation, not only an editing-mode toast');
  });
}
