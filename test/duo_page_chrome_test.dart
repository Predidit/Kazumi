import 'package:kazumi/bean/duo/duo_menu_owner.dart';
import 'package:kazumi/bean/settings/settings_detail_scaffold.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kazumi/bean/appbar/sys_app_bar.dart';
import 'package:kazumi/bean/appbar/duo_page_chrome.dart';
import 'package:kazumi/navigation.dart';
import 'package:kazumi/pages/video/video_page_layout.dart';
import 'package:kazumi/pages/popular/popular_page.dart';
import 'package:kazumi/pages/popular/popular_controller.dart';
import 'package:kazumi/utils/constants.dart';
import 'package:kazumi/bean/widget/kazumi_menu.dart';
import 'package:kazumi/services/platform/duo_navigation.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final calls = <MethodCall>[];

  Map<dynamic, dynamic> chrome() =>
      calls.lastWhere((call) => call.method == 'chrome').arguments as Map;

  Future<void> action(
    Map<dynamic, dynamic> page,
    Map<dynamic, dynamic> button,
  ) async {
    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(
          DuoNavigation.channel.name,
          const StandardMethodCodec().encodeMethodCall(
            MethodCall('chromeAction', {
              'owner': page['owner'],
              'id': button['id'],
            }),
          ),
          (_) {},
        );
  }

  setUp(() async {
    DuoNavigation.resetForTesting();
    calls.clear();
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(DuoNavigation.channel, (call) async {
          calls.add(call);
          return call.method == 'enable' ? true : null;
        });
    await DuoNavigation.initialize();
  });

  tearDown(() {
    DuoNavigation.resetForTesting();
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(DuoNavigation.channel, null);
  });

  Future<void> finish(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    debugDefaultTargetPlatformOverride = null;
  }

  Widget nativeAction(String label) => DuoActionBinding(
    action: DuoAction(
      label: label,
      symbol: 'magnifyingglass',
      onPressed: () {},
    ),
    child: const SizedBox.shrink(),
  );

  PreferredSizeWidget namedHeader(String label) =>
      SysAppBar(title: Text(label), actions: [nativeAction(label)]);

  testWidgets('unbound actions stay visible and usable in Flutter', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          appBar: SysAppBar(
            title: const Text('Settings'),
            leading: BackButton(onPressed: () {}),
            actions: [
              IconButton(
                tooltip: 'New action',
                icon: const Icon(Icons.add),
                onPressed: () => taps++,
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Settings').hitTestable(), findsOneWidget);
    expect(chrome()['actions'], isEmpty);
    expect((chrome()['leading'] as Map)['label'], '返回');
    await tester.tap(find.byTooltip('New action'));
    expect(taps, 1);
    await finish(tester);
  });

  testWidgets('embedded settings keep pane back navigation', (tester) async {
    var backs = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: SettingsPaneScope(
          embedded: true,
          showBackButton: false,
          onBack: () => backs++,
          child: const SettingsDetailScaffold(
            title: Text('设置项目'),
            body: SizedBox(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('设置项目').hitTestable(), findsOneWidget);
    expect(chrome()['visible'], true);
    await action(chrome(), chrome()['leading'] as Map);
    expect(backs, 1);
    await finish(tester);
  });

  testWidgets('custom page content never exports inline actions', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: DuoPageChrome(
          leading: DuoAction(label: '返回', onPressed: () {}),
          child: Scaffold(
            body: DuoActionBinding(
              action: DuoAction(label: 'inline', onPressed: () => taps++),
              child: TextButton(
                onPressed: () => taps++,
                child: const Text('inline'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(chrome()['actions'], isEmpty);
    await tester.tap(find.text('inline'));
    expect(taps, 1);
    await finish(tester);
  });

  testWidgets(
    'action bindings preserve their original control without a native header',
    (tester) async {
      var taps = 0;
      DuoNavigation.enabled.value = false;
      calls.clear();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DuoActionBinding(
              action: DuoAction(label: 'native', onPressed: () => taps += 10),
              child: TextButton(
                onPressed: () => taps++,
                child: const Text('original'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('original'));
      expect(taps, 1);
      expect(calls.where((call) => call.method == 'chrome'), isEmpty);
      await finish(tester);
    },
  );

  testWidgets('tab headers keep their original Flutter title', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          appBar: SysAppBar(
            toolbarHeight: 72,
            title: const Text('时间表'),
            actions: [
              DuoActionBinding(
                action: DuoAction(
                  label: '筛选',
                  symbol: 'slider.horizontal.3',
                  onPressed: () {},
                ),
                child: IconButton(
                  onPressed: () {},
                  icon: const Icon(Icons.tune),
                ),
              ),
            ],
          ),
          body: const SizedBox.expand(),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('时间表').hitTestable(), findsOneWidget);
    expect(tester.getSize(find.byType(AppBar)).height, 72);
    expect(chrome().containsKey('title'), false);
    expect(chrome()['actions'], hasLength(1));
    await finish(tester);
  });

  testWidgets(
    'original landscape player works without a Duo wrapper through popups',
    (tester) async {
      tester.view.physicalSize = const Size(900, 600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final root = GlobalKey<NavigatorState>();
      final controls = ValueNotifier(true);
      var fillsWindow = false;
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: root,
          navigatorObservers: [rootRouteObserver],
          home: Scaffold(
            appBar: SysAppBar(
              title: const Text('Home'),
              actions: [nativeAction('搜索')],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(chrome()['visible'], true);
      root.currentState!.push(
        MaterialPageRoute<void>(
          builder: (_) => VideoPageLayout(
            fullscreen: false,
            isPip: false,
            tabs: const SizedBox(),
            playerBuilder: (context, layout) {
              fillsWindow = layout.fillsWindow;
              return ValueListenableBuilder<bool>(
                valueListenable: controls,
                builder: (_, visible, _) => Stack(
                  children: [
                    const Positioned.fill(
                      child: ColoredBox(color: Colors.black),
                    ),
                    if (visible)
                      BackButton(
                        key: const ValueKey('original-back'),
                        onPressed: () => Navigator.of(context).maybePop(),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        fillsWindow,
        true,
      ); // Landscape fills the window without isFullscreen.
      expect(chrome()['visible'], false);
      expect(chrome()['immersive'], false);
      expect(find.byKey(const ValueKey('original-back')), findsOneWidget);
      controls.value = false;
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('original-back')), findsNothing);
      expect(chrome()['visible'], false);
      final dialog = showDialog<void>(
        context: root.currentContext!,
        builder: (_) => const AlertDialog(title: Text('Player dialog')),
      );
      await tester.pumpAndSettle();
      expect(chrome()['visible'], false);
      expect(chrome()['immersive'], false);
      root.currentState!.pop();
      await dialog;
      await tester.pumpAndSettle();
      root.currentState!.push(
        MaterialPageRoute<void>(
          builder: (_) => Scaffold(
            appBar: SysAppBar(
              title: const Text('Settings'),
              leading: BackButton(onPressed: () => root.currentState!.pop()),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(chrome()['visible'], true);
      expect(chrome()['immersive'], false);
      root.currentState!.pop();
      await tester.pumpAndSettle();
      expect(chrome()['visible'], false);
      expect(chrome()['immersive'], false);
      controls.value = true;
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('original-back')));
      await tester.pumpAndSettle();
      expect(chrome()['visible'], true);
      expect(chrome()['immersive'], false);
      await finish(tester);
      controls.dispose();
    },
  );

  testWidgets(
    'explicit immersive chrome hides native actions and restores them on exit',
    (tester) async {
      final fullscreen = ValueNotifier(false);
      var nativeTaps = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: ValueListenableBuilder<bool>(
            valueListenable: fullscreen,
            builder: (_, value, _) => DuoPageChrome(
              hidden: value,
              immersive: value,
              leading: DuoAction(
                label: '返回',
                symbol: 'chevron.backward',
                onPressed: () => nativeTaps++,
              ),
              child: const Center(child: Text('Original player surface')),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final windowed = Map.of(chrome());
      expect(windowed['visible'], true);
      expect(windowed['immersive'], false);
      fullscreen.value = true;
      await tester.pumpAndSettle();
      expect(chrome()['visible'], false);
      expect(chrome()['immersive'], true);
      expect(find.text('Original player surface'), findsOneWidget);
      await action(windowed, windowed['leading'] as Map);
      expect(nativeTaps, 0);
      fullscreen.value = false;
      await tester.pumpAndSettle();
      expect(chrome()['visible'], true);
      expect(chrome()['immersive'], false);
      await action(chrome(), chrome()['leading'] as Map);
      expect(nativeTaps, 1);
      await finish(tester);
      fullscreen.dispose();
    },
  );

  testWidgets(
    'home category dropdown stays in Flutter and opens the original menu',
    (tester) async {
      final controller = _NoNetworkPopularController();
      await tester.pumpWidget(
        MaterialApp(home: PopularPage(controller: controller)),
      );
      await tester.pumpAndSettle();
      expect(find.text('热门番组'), findsOneWidget);
      final actions = chrome()['actions'] as List;
      expect(
        actions.any((dynamic action) => (action as Map).containsKey('menu')),
        false,
      );
      expect(
        actions.any((dynamic action) => (action as Map)['label'] == '番组分类'),
        false,
      );
      await tester.tap(find.text('热门番组'));
      await tester.pumpAndSettle();
      expect(find.text(defaultAnimeTags.first), findsOneWidget);
      await tester.tap(find.text(defaultAnimeTags.first));
      await tester.pumpAndSettle();
      expect(controller.currentTag, defaultAnimeTags.first);
      expect(find.text(defaultAnimeTags.first), findsOneWidget);
      await finish(tester);
    },
  );

  testWidgets('mirrors reactive controls and rejects a stale disabled action', (
    tester,
  ) async {
    final enabled = ValueNotifier(true);
    var count = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          appBar: SysAppBar(
            title: const Text('页面'),
            actions: [
              ValueListenableBuilder<bool>(
                valueListenable: enabled,
                builder: (_, value, _) => Padding(
                  padding: const EdgeInsets.all(4),
                  child: DuoActionBinding(
                    action: DuoAction(
                      label: '执行',
                      symbol: 'arrow.clockwise',
                      onPressed: value
                          ? () {
                              count++;
                              enabled.value = false;
                            }
                          : null,
                    ),
                    child: const Text('Original action'),
                  ),
                ),
              ),
            ],
          ),
          body: const Text('正文'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('页面'),
      findsOneWidget,
    ); // Ordinary Flutter titles remain visible.
    expect(find.text('正文'), findsOneWidget);
    final original = Map.of(chrome());
    final button = (original['actions'] as List).single as Map;
    expect(button['enabled'], true);
    await action(original, button);
    await tester.pumpAndSettle();
    expect(count, 1);
    expect(((chrome()['actions'] as List).single as Map)['enabled'], false);
    await action(original, button);
    expect(count, 1);
    await finish(tester);
    enabled.dispose();
  });

  testWidgets(
    'native menus preserve callbacks, selection, and destructive state',
    (tester) async {
      var selected = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: SysAppBar(
              title: const Text('菜单'),
              actions: [
                StatefulBuilder(
                  builder: (_, setState) {
                    final items = [
                      KazumiMenuItem(
                        label: '第一项',
                        selected: selected == 0,
                        onPressed: () => setState(() => selected = 0),
                      ),
                      KazumiMenuItem(
                        label: '第二项',
                        selected: selected == 1,
                        destructive: true,
                        onPressed: () => setState(() => selected = 1),
                      ),
                    ];
                    return DuoMenuOwner(
                      label: '更多操作',
                      symbol: 'ellipsis',
                      child: KazumiMenuButton(
                        builder: (_, toggle) => IconButton(
                          onPressed: toggle,
                          icon: const Icon(Icons.more_horiz),
                        ),
                        menuChildren: items,
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final before = Map.of(chrome());
      final menu = ((before['actions'] as List).single as Map)['menu'] as List;
      expect((menu[0] as Map)['selected'], true);
      expect((menu[1] as Map)['destructive'], true);
      await action(before, menu[1] as Map);
      await tester.pumpAndSettle();
      final after =
          (((chrome()['actions'] as List).single as Map)['menu'] as List);
      expect((after[1] as Map)['selected'], true);
      expect(
        find.byType(MenuAnchor),
        findsNothing,
      ); // No offscreen Flutter menu is opened.
      await finish(tester);
    },
  );

  testWidgets(
    'nested headers restore after guarded back navigation and popups block stale actions',
    (tester) async {
      final root = GlobalKey<NavigatorState>();
      var allowPop = false;
      var attempts = 0;
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: root,
          home: Scaffold(
            appBar: namedHeader('根页面'),
            body: Navigator(
              onGenerateRoute: (_) => MaterialPageRoute<void>(
                builder: (_) => Scaffold(appBar: namedHeader('嵌套页面')),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect((chrome()['actions'] as List).first['label'], '嵌套页面');
      root.currentState!.push(
        MaterialPageRoute<void>(
          builder: (context) => StatefulBuilder(
            builder: (context, setState) => PopScope(
              canPop: allowPop,
              onPopInvokedWithResult: (didPop, _) {
                attempts++;
                if (!didPop) setState(() => allowPop = true);
              },
              child: Scaffold(
                appBar: SysAppBar(
                  title: const Text('详情'),
                  actions: [nativeAction('详情')],
                  leading: BackButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                ),
                body: const Text('详情正文'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect((chrome()['actions'] as List).first['label'], '详情');
      final detail = Map.of(chrome());
      final back = detail['leading'] as Map;
      expect(back['symbol'], 'chevron.backward');
      final dialog = showDialog<void>(
        context: root.currentContext!,
        builder: (_) => const AlertDialog(title: Text('确认')),
      );
      await tester.pumpAndSettle();
      expect(chrome()['visible'], false);
      await action(detail, back);
      expect(attempts, 0);
      root.currentState!.pop();
      await dialog;
      await tester.pumpAndSettle();
      await action(chrome(), chrome()['leading'] as Map);
      await tester.pumpAndSettle();
      expect(attempts, 1);
      expect((chrome()['actions'] as List).first['label'], '详情');
      await action(chrome(), chrome()['leading'] as Map);
      await tester.pumpAndSettle();
      expect((chrome()['actions'] as List).first['label'], '嵌套页面');
      await action(detail, back);
      expect((chrome()['actions'] as List).first['label'], '嵌套页面');
      await finish(tester);
    },
  );
}

class _NoNetworkPopularController extends PopularController {
  @override
  Future<void> queryBangumiByTrend({String type = 'add'}) async {}

  @override
  Future<void> queryBangumiByTag({String type = 'add'}) async {}
}
