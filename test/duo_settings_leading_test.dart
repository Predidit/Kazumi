import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kazumi/bean/settings/settings_detail_scaffold.dart';
import 'package:kazumi/services/platform/duo_navigation.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'embedded Duo settings preserve the custom selection close button',
    (tester) async {
      final calls = <MethodCall>[];
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      DuoNavigation.resetForTesting();
      messenger.setMockMethodCallHandler(DuoNavigation.channel, (call) async {
        calls.add(call);
        return call.method == 'enable' ? true : null;
      });
      addTearDown(() {
        debugDefaultTargetPlatformOverride = null;
        DuoNavigation.resetForTesting();
        messenger.setMockMethodCallHandler(DuoNavigation.channel, null);
      });
      await DuoNavigation.initialize();
      var backs = 0;
      var closes = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: SettingsPaneScope(
            embedded: true,
            showBackButton: true,
            onBack: () => backs++,
            child: SettingsDetailScaffold(
              title: const Text('规则管理'),
              leading: IconButton(
                tooltip: '退出多选',
                onPressed: () => closes++,
                icon: const Icon(Icons.close_rounded),
              ),
              body: const SizedBox(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byTooltip('退出多选').hitTestable(), findsOneWidget);
      final chrome =
          calls.lastWhere((call) => call.method == 'chrome').arguments as Map;
      expect(chrome['leading'], isNull);
      await tester.tap(find.byTooltip('退出多选'));
      expect(closes, 1);
      expect(backs, 0);
      await tester.pumpWidget(const SizedBox());
      debugDefaultTargetPlatformOverride = null;
    },
  );
}
