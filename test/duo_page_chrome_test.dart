import 'package:mobx/mobx.dart' show ObservableList;
import 'package:kazumi/pages/download/download_page.dart';
import 'package:kazumi/pages/download/download_controller.dart';
import 'package:kazumi/modules/download/download_module.dart';
import 'dart:async';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/pages/history/history_page.dart';
import 'package:kazumi/pages/history/history_controller.dart';
import 'package:kazumi/pages/collect/collect_controller.dart';
import 'package:kazumi/repositories/history_repository.dart';
import 'package:kazumi/repositories/collect_crud_repository.dart';
import 'package:kazumi/services/player/history_playback_service.dart';
import 'package:kazumi/modules/history/history_module.dart';
import 'package:kazumi/bean/duo/duo_tab_shell.dart';
import 'package:kazumi/modules/bangumi/bangumi_item.dart';
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
    action: DuoAction(label: label, icon: Icons.search, onPressed: () {}),
    child: const SizedBox.shrink(),
  );

  PreferredSizeWidget namedHeader(String label) =>
      SysAppBar(title: Text(label), actions: [nativeAction(label)]);

  test('native actions retain the original font glyph and mirroring', () {
    final callbacks = <String, VoidCallback>{};
    final normal = const DuoAction(
      label: 'Back',
      icon: Icons.arrow_back,
    ).encode(callbacks);
    expect(normal['icon'], {
      'codePoint': Icons.arrow_back.codePoint,
      'family': Icons.arrow_back.fontFamily,
      'rtl': false,
    });
    final mirrored = const DuoAction(
      label: 'Back',
      icon: Icons.arrow_back,
    ).encode(callbacks, direction: TextDirection.rtl);
    expect((mirrored['icon'] as Map)['rtl'], true);
    expect(normal.containsKey('symbol'), false);
  });

  testWidgets('download controls clear the Duo sidebar and remain tappable', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(466, 678);
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(right: 84);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPadding);
    final controller = _DownloadFixture();
    await tester.pumpWidget(
      MaterialApp(home: DownloadPage(controller: controller)),
    );
    await tester.pumpAndSettle();
    expect(tester.getRect(find.byType(ListView)).right, 382);
    for (final label in ['更多操作', '继续', '删除']) {
      final control = find.byTooltip(label);
      expect(control.hitTestable(), findsOneWidget);
      expect(tester.getRect(control).right, lessThanOrEqualTo(382));
    }
    await tester.tap(find.byTooltip('继续'));
    await tester.pumpAndSettle();
    expect(controller.resumes, 1);
    await finish(tester);
  });

  testWidgets('native badge tracks count changes and disappears at zero', (
    tester,
  ) async {
    final count = ValueNotifier(0);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          appBar: SysAppBar(
            actions: [
              ValueListenableBuilder<int>(
                valueListenable: count,
                builder: (_, value, _) => DuoActionBinding(
                  action: DuoAction(
                    label: 'Filters',
                    icon: Icons.tune_rounded,
                    badgeCount: value,
                    onPressed: () {},
                  ),
                  child: const SizedBox(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    Map button() => (chrome()['actions'] as List).single as Map;
    await tester.pumpAndSettle();
    expect(button().containsKey('badgeCount'), false);
    count.value = 2;
    await tester.pumpAndSettle();
    expect(button()['badgeCount'], 2);
    final colors = chrome()['theme'] as Map;
    expect(colors['badgeBackground'], ThemeData().colorScheme.error.toARGB32());
    expect(
      colors['badgeForeground'],
      ThemeData().colorScheme.onError.toARGB32(),
    );
    count.value = 1;
    await tester.pumpAndSettle();
    expect(button()['badgeCount'], 1);
    count.value = 0;
    await tester.pumpAndSettle();
    expect(button().containsKey('badgeCount'), false);
    await finish(tester);
    count.dispose();
  });

  testWidgets(
    'history sidebar edits, cancels clearing and disables busy controls',
    (tester) async {
      final repository = _HistoryFixture();
      final controller = HistoryController(repository);
      final module = createModule(
        register: (c) {
          c
            ..addSingleton<CollectController>(
              () => CollectController(_EmptyCollects()),
            )
            ..addSingleton<HistoryPlaybackService>(() => _UnusedPlayback())
            ..route('/', child: (_, _) => HistoryPage(controller: controller));
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
      Map named(String label) => (chrome()['actions'] as List)
          .cast<Map>()
          .singleWhere((button) => button['label'] == label);
      final edit = named('管理历史记录');
      expect((edit['icon'] as Map)['codePoint'], Icons.edit_outlined.codePoint);
      await action(chrome(), edit);
      await tester.pumpAndSettle();
      expect(named('完成')['enabled'], true);
      expect((named('完成')['icon'] as Map)['codePoint'], Icons.done.codePoint);
      final clear = named('清空全部历史记录');
      expect(
        (clear['icon'] as Map)['codePoint'],
        Icons.delete_sweep_outlined.codePoint,
      );
      await action(chrome(), clear);
      await tester.pumpAndSettle();
      expect(find.text('清空历史记录？'), findsOneWidget);
      expect(chrome()['visible'], false);
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      expect(controller.histories, hasLength(1));
      await action(chrome(), named('完成'));
      await tester.pumpAndSettle();
      expect(named('管理历史记录')['enabled'], true);
      await action(chrome(), named('管理历史记录'));
      await tester.pumpAndSettle();
      await action(chrome(), named('清空全部历史记录'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('清空全部'));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();
      expect(named('完成')['enabled'], false);
      expect(named('清空全部历史记录')['enabled'], false);
      repository.cleared.complete();
      await tester.pumpAndSettle();
      expect(controller.histories, isEmpty);
      expect(chrome()['actions'], isEmpty);
      await finish(tester);
    },
  );

  testWidgets('native tabs and actions follow live theme changes', (
    tester,
  ) async {
    ThemeData themed(Color seed, Brightness brightness) => ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: seed,
        brightness: brightness,
      ),
    );
    final theme = ValueNotifier(themed(Colors.green, Brightness.light));
    await tester.pumpWidget(
      ValueListenableBuilder<ThemeData>(
        valueListenable: theme,
        builder: (_, value, _) => MaterialApp(
          theme: value,
          home: DuoTabShell(
            index: 0,
            isCovered: false,
            onSelected: (_) {},
            nativeBuilder: (_) => Scaffold(
              appBar: SysAppBar(
                title: const Text('Home'),
                actions: [nativeAction('Search')],
              ),
            ),
            child: const SizedBox(),
          ),
        ),
      ),
    );
    Future<void> check() async {
      await tester.pumpAndSettle();
      final tabs =
          calls.lastWhere((call) => call.method == 'update').arguments as Map;
      final colors = tabs['theme'] as Map;
      final scheme = theme.value.colorScheme;
      expect(colors['primary'], scheme.primary.toARGB32());
      expect(colors['selected'], scheme.onSecondaryContainer.toARGB32());
      expect(colors['unselected'], scheme.onSurfaceVariant.toARGB32());
      expect(colors['indicator'], scheme.secondaryContainer.toARGB32());
      expect((chrome()['theme'] as Map)['action'], scheme.onSurface.toARGB32());
      expect(chrome()['dark'], scheme.brightness == Brightness.dark);
    }

    await check();
    theme.value = themed(Colors.purple, Brightness.dark);
    await check();
    theme.value = themed(Colors.orange, Brightness.dark);
    await check();
    await finish(tester);
    theme.dispose();
  });

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
                  icon: Icons.tune_rounded,
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
                icon: Icons.arrow_back_ios_new_rounded,
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

  testWidgets('home content clears sidebar and native scroll-to-top works', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(466, 678);
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(right: 84);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPadding);
    final controller = _NoNetworkPopularController();
    controller.trendList.addAll(
      List.generate(
        24,
        (id) => BangumiItem(
          id: id,
          type: 2,
          name: 'Item $id',
          nameCn: 'Item $id',
          summary: '',
          airDate: '',
          airWeekday: 1,
          rank: 0,
          images: {},
          tags: [],
          alias: [],
          ratingScore: 0,
          votes: 0,
          votesCount: [],
          info: '',
        ),
      ),
    );
    await tester.pumpWidget(
      MaterialApp(home: PopularPage(controller: controller)),
    );
    await tester.pumpAndSettle();
    expect(tester.getRect(find.byType(CustomScrollView)).right, 382);
    expect(find.byType(FloatingActionButton), findsNothing);
    final scroll = tester
        .widget<CustomScrollView>(find.byType(CustomScrollView))
        .controller!;
    scroll.jumpTo(400);
    await tester.pumpAndSettle();
    expect(scroll.offset, greaterThan(0));
    final page = Map.of(chrome());
    final top = (page['actions'] as List).cast<Map>().singleWhere(
      (item) => item['label'] == '回到顶部',
    );
    expect((top['icon'] as Map)['codePoint'], Icons.arrow_upward.codePoint);
    await action(page, top);
    await tester.pumpAndSettle();
    expect(scroll.offset, 0);
    await finish(tester);
  });

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
                      icon: Icons.refresh,
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
                      icon: Icons.favorite_border,
                      selectionIcons: const [
                        Icons.favorite_border,
                        Icons.favorite,
                      ],
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
      expect(
        (((before['actions'] as List).single as Map)['icon']
            as Map)['codePoint'],
        Icons.favorite_border.codePoint,
      );
      final menu = ((before['actions'] as List).single as Map)['menu'] as List;
      expect((menu[0] as Map)['selected'], true);
      expect((menu[1] as Map)['destructive'], true);
      await action(before, menu[1] as Map);
      await tester.pumpAndSettle();
      final after =
          (((chrome()['actions'] as List).single as Map)['menu'] as List);
      expect((after[1] as Map)['selected'], true);
      expect(
        (((chrome()['actions'] as List).single as Map)['icon']
            as Map)['codePoint'],
        Icons.favorite.codePoint,
      );
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
      expect(
        (back['icon'] as Map)['codePoint'],
        Icons.arrow_back_ios_new_rounded.codePoint,
      );
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

class _HistoryFixture implements IHistoryRepository {
  final cleared = Completer<void>();
  @override
  List<History> getAllHistories() => [
    History(
      BangumiItem(
        id: 1,
        type: 2,
        name: 'History item',
        nameCn: 'History item',
        summary: '',
        airDate: '',
        airWeekday: 1,
        rank: 0,
        images: {},
        tags: [],
        alias: [],
        ratingScore: 0,
        votes: 0,
        votesCount: [],
        info: '',
      ),
      1,
      'Source',
      DateTime(2026, 1, 1),
      '',
      'Episode 1',
    ),
  ];
  @override
  Future<void> clearAllHistories() => cleared.future;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _EmptyCollects implements ICollectCrudRepository {
  @override
  int getCollectType(int id) => 0;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _UnusedPlayback implements HistoryPlaybackService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _DownloadFixture implements DownloadController {
  final record = DownloadRecord(1, 'Download item', '', 'Source', {
    1: DownloadEpisode(
      1,
      'Episode 1',
      0,
      DownloadStatus.paused,
      0,
      10,
      0,
      '',
      '',
      '',
      null,
      '',
      0,
      '',
    ),
  }, DateTime(2026, 1, 1));
  int resumes = 0;
  @override
  late final ObservableList<String> recordKeys = ObservableList.of([
    record.key,
  ]);
  @override
  void refreshRecords() {}
  @override
  DownloadRecord? getRecordSnapshot(String key) =>
      recordKeys.contains(key) ? record : null;
  @override
  Future<void> retryDownload({
    required int bangumiId,
    required String pluginName,
    required int episodeNumber,
  }) async {
    resumes++;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
