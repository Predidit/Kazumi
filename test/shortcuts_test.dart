import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/app_widget.dart';
import 'package:kazumi/bean/settings/theme_provider.dart';
import 'package:provider/provider.dart';
import 'package:hive_ce/hive.dart';
import 'package:kazumi/utils/storage.dart';
import 'dart:io';

class MockGStorage {
  static Future<void> init() async {
    final tempDir = Directory.systemTemp.createTempSync();
    Hive.init(tempDir.path);
    GStorage.favorites = await Hive.openBox('favorites');
    GStorage.setting = await Hive.openBox('setting');
    GStorage.collectibles = await Hive.openBox('collectibles');
    GStorage.histories = await Hive.openBox('histories');
    GStorage.collectChanges = await Hive.openBox('collectChanges');
    GStorage.shieldList = await Hive.openBox('shieldList');
    GStorage.searchHistory = await Hive.openBox('searchHistory');
    GStorage.downloads = await Hive.openBox('downloads');
  }
}

// A simple module for testing navigation without heavy page dependencies
class TestPage extends StatelessWidget {
  final String title;
  const TestPage({super.key, required this.title});
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: Text(title)));
}

class TestModule extends Module {
  @override
  void routes(r) {
    r.child('/', child: (_) => const TestPage(title: 'Root'));
    r.child('/sub', child: (_) => const TestPage(title: 'Sub'));
  }
}

void main() {
  setUpAll(() async {
    await MockGStorage.init();
    await GStorage.setting.put(SettingBoxKey.themeColor, 'default');
    await GStorage.setting.put(SettingBoxKey.themeMode, 'system');
    await GStorage.setting.put(SettingBoxKey.oledEnhance, false);
    await GStorage.setting.put(SettingBoxKey.useSystemFont, false);
  });

  testWidgets('AppWidget shortcuts correctly trigger maybePop upon navigation', (WidgetTester tester) async {
    // We use a simplified AppModule setup to avoid heavy page dependencies (like CollectPage)
    // while still testing the AppWidget's shortcut logic.
    
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => ThemeProvider(),
        child: ModularApp(
          module: TestModule(),
          child: const AppWidget(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // 1. Navigate to a sub-page
    Modular.to.pushNamed('/sub');
    await tester.pumpAndSettle();
    expect(Modular.to.path, '/sub');

    // 2. Simulate Escape key to trigger maybePop
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    // 3. Verify that we popped back to root
    expect(Modular.to.path, '/');
  });

  testWidgets('AppWidget handles Back mouse button for navigation', (WidgetTester tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => ThemeProvider(),
        child: ModularApp(
          module: TestModule(),
          child: const AppWidget(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // 1. Navigate to a sub-page
    Modular.to.pushNamed('/sub');
    await tester.pumpAndSettle();
    expect(Modular.to.path, '/sub');

    // 2. Simulate back mouse button
    const int kBackMouseButton = 8;
    final Offset center = tester.getCenter(find.byType(AppWidget).first);
    final TestPointer pointer = TestPointer(1, PointerDeviceKind.mouse);
    await tester.sendEventToBinding(pointer.hover(center));
    await tester.sendEventToBinding(pointer.down(center, buttons: kBackMouseButton));
    await tester.sendEventToBinding(pointer.up());
    await tester.pumpAndSettle();

    // 3. Verify pop
    expect(Modular.to.path, '/');
  });
}




