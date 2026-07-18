import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:kazumi/bean/widget/custom_dropdown_menu.dart';
import 'package:kazumi/bean/dialog/adaptive_bottom_sheet.dart';
import 'package:kazumi/bean/widget/play_pause_icon.dart';
import 'package:kazumi/design_system/kazumi_design_tokens.dart';
import 'package:kazumi/design_system/kazumi_settings.dart';
import 'package:kazumi/design_system/kazumi_surfaces.dart';
import 'package:kazumi/design_system/kazumi_theme.dart';
import 'package:kazumi/pages/onboarding/onboarding_step_layout.dart';
import 'package:kazumi/pages/onboarding/steps/update_source_step.dart';
import 'package:kazumi/pages/info/rating_review_dialog.dart';
import 'package:kazumi/modules/bangumi/bangumi_item.dart';

ThemeData _theme(Brightness brightness) {
  return applyKazumiDesignSystem(
    ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorSchemeSeed: Colors.green,
    ),
  );
}

BangumiItem _reviewItem() {
  return BangumiItem(
    id: 1,
    type: 2,
    name: 'Test title',
    nameCn: 'Test title',
    summary: '',
    airDate: '',
    airWeekday: 1,
    rank: 0,
    images: const {},
    tags: const [],
    alias: const [],
    ratingScore: 0,
    votes: 0,
    votesCount: const [],
    info: '',
  );
}

void main() {
  test('design system installs semantic tokens in light and dark themes', () {
    for (final brightness in Brightness.values) {
      final theme = _theme(brightness);
      final tokens = theme.extension<KazumiDesignTokens>();

      expect(tokens, isNotNull);
      expect(tokens!.radiusControl, 12);
      expect(tokens.radiusDialog, 28);
      expect(theme.dialogTheme.elevation, 0);
      expect(theme.navigationRailTheme.useIndicator, isTrue);
      expect(theme.inputDecorationTheme.filled, isTrue);
      expect(
        theme.pageTransitionsTheme.builders[TargetPlatform.windows],
        isA<KazumiWindowsPageTransitionsBuilder>(),
      );
    }
  });

  testWidgets('glass falls back to an opaque surface in high contrast',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: _theme(Brightness.light),
        home: const MediaQuery(
          data: MediaQueryData(highContrast: true),
          child: Scaffold(
            body: KazumiGlassSurface(child: Text('navigation')),
          ),
        ),
      ),
    );

    expect(find.byType(BackdropFilter), findsNothing);
    expect(find.text('navigation'), findsOneWidget);
  });

  testWidgets('reduced motion disables interactive surface animation',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: _theme(Brightness.light),
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Scaffold(
            body: KazumiInteractiveSurface(
              onTap: () {},
              child: const Text('interactive'),
            ),
          ),
        ),
      ),
    );

    final animated = tester.widget<AnimatedContainer>(
      find.byType(AnimatedContainer),
    );
    expect(animated.duration, Duration.zero);
  });

  testWidgets('interactive surface supports keyboard activation',
      (tester) async {
    var activations = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: _theme(Brightness.dark),
        home: Scaffold(
          body: KazumiInteractiveSurface(
            semanticLabel: 'Open item',
            onTap: () => activations++,
            child: const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Open'),
            ),
          ),
        ),
      ),
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();

    expect(activations, 1);
  });

  testWidgets('custom dropdown remains inside a narrow window', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: _theme(Brightness.light),
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 320,
              height: 240,
              child: CustomDropdownMenu(
                offset: const Offset(300, 220),
                buttonSize: const Size(40, 40),
                animation: const AlwaysStoppedAnimation(1),
                items: const ['热门', '动画', '音乐'],
                itemBuilder: (item) => item,
              ),
            ),
          ),
        ),
      ),
    );

    final rect = tester.getRect(find.byType(KazumiGlassSurface));
    expect(rect.left, greaterThanOrEqualTo(0));
    expect(rect.top, greaterThanOrEqualTo(0));
    expect(rect.right, lessThanOrEqualTo(320));
    expect(rect.bottom, lessThanOrEqualTo(240));
    expect(tester.takeException(), isNull);
  });

  testWidgets('custom dropdown anchor stays stable during reveal',
      (tester) async {
    Widget buildMenu(double progress) {
      return MaterialApp(
        theme: _theme(Brightness.light),
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 320,
              height: 240,
              child: CustomDropdownMenu(
                offset: const Offset(300, 220),
                buttonSize: const Size(40, 40),
                animation: AlwaysStoppedAnimation(progress),
                items: const ['Popular', 'Animation', 'Music'],
                itemBuilder: (item) => item,
              ),
            ),
          ),
        ),
      );
    }

    await tester.pumpWidget(buildMenu(0));
    final hiddenRect = tester.getRect(find.byType(KazumiGlassSurface));
    await tester.pumpWidget(buildMenu(1));
    final visibleRect = tester.getRect(find.byType(KazumiGlassSurface));

    expect(visibleRect.topLeft, hiddenRect.topLeft);
    expect(visibleRect.size, hiddenRect.size);
    expect(tester.takeException(), isNull);
  });

  testWidgets('custom dropdown exposes its selected item without color alone',
      (tester) async {
    final semanticsHandle = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        theme: _theme(Brightness.light),
        home: Scaffold(
          body: SizedBox(
            width: 320,
            height: 240,
            child: CustomDropdownMenu(
              offset: const Offset(20, 20),
              buttonSize: const Size(40, 40),
              animation: const AlwaysStoppedAnimation(1),
              items: const ['Popular', 'Animation', 'Music'],
              selectedItem: 'Animation',
              itemBuilder: (item) => item,
            ),
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    expect(
      tester.getSemantics(find.text('Animation')),
      isSemantics(label: 'Animation', isSelected: true, hasTapAction: true),
    );
    semanticsHandle.dispose();
  });

  testWidgets('state panel supports narrow 150 percent text scaling',
      (tester) async {
    tester.view.physicalSize = const Size(480, 360);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: _theme(Brightness.light),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: const TextScaler.linear(1.5),
          ),
          child: child!,
        ),
        home: Scaffold(
          body: KazumiStatePanel(
            kind: KazumiStateKind.error,
            title: 'Unable to load this page',
            message: 'Check the network connection and retry the request.',
            actions: [
              FilledButton(onPressed: () {}, child: const Text('Retry')),
            ],
          ),
        ),
      ),
    );

    expect(find.text('Retry'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('play pause icon snaps when motion is disabled', (tester) async {
    Widget buildIcon({required bool playing}) {
      return MaterialApp(
        home: Scaffold(
          body: PlayPauseIcon(
            playing: playing,
            disableAnimations: true,
          ),
        ),
      );
    }

    await tester.pumpWidget(buildIcon(playing: false));
    await tester.pumpWidget(buildIcon(playing: true));
    await tester.pump();

    final icon = tester.widget<AnimatedIcon>(find.byType(AnimatedIcon));
    expect(icon.progress.value, 1);
    expect(tester.takeException(), isNull);
  });

  test('theme installs smooth shapes for primary component families', () {
    final theme = _theme(Brightness.light);

    expect(kazumiSmoothShape(12), isA<RoundedSuperellipseBorder>());
    expect(theme.cardTheme.shape, isA<RoundedSuperellipseBorder>());
    expect(theme.dialogTheme.shape, isA<RoundedSuperellipseBorder>());
    expect(theme.bottomSheetTheme.shape, isA<RoundedSuperellipseBorder>());
    expect(
      theme.filledButtonTheme.style?.shape?.resolve(<WidgetState>{}),
      isA<RoundedSuperellipseBorder>(),
    );
    expect(
      theme.navigationBarTheme.indicatorShape,
      isA<RoundedSuperellipseBorder>(),
    );
  });

  testWidgets('glass uses smooth clipping and bounded blur', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: _theme(Brightness.light),
        home: const Scaffold(
          body: KazumiGlassSurface(child: Text('glass')),
        ),
      ),
    );

    expect(find.byType(ClipRSuperellipse), findsOneWidget);
    expect(find.byType(BackdropFilter), findsOneWidget);
    expect(find.text('glass'), findsOneWidget);
  });

  testWidgets('player chrome never samples the video backdrop', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: _theme(Brightness.dark),
        home: const Scaffold(
          body: KazumiPlayerChrome(child: Text('controls')),
        ),
      ),
    );

    expect(find.byType(ClipRSuperellipse), findsOneWidget);
    expect(find.byType(BackdropFilter), findsNothing);
    expect(find.text('controls'), findsOneWidget);
  });

  testWidgets('settings switch has one keyboard action and merged semantics',
      (tester) async {
    final semanticsHandle = tester.ensureSemantics();
    var enabled = false;

    await tester.pumpWidget(
      MaterialApp(
        theme: _theme(Brightness.light),
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => SettingsTile.switchTile(
              title: const Text('Liquid glass'),
              initialValue: enabled,
              onToggle: (value) {
                setState(() => enabled = value ?? !enabled);
              },
            ),
          ),
        ),
      ),
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();

    expect(enabled, isTrue);
    expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);
    expect(
      tester.getSemantics(find.text('Liquid glass')),
      isSemantics(
        label: 'Liquid glass',
        hasToggledState: true,
        isToggled: true,
        hasEnabledState: true,
        isEnabled: true,
        hasTapAction: true,
      ),
    );
    semanticsHandle.dispose();
  });

  testWidgets('disabled settings switch cannot activate', (tester) async {
    final semanticsHandle = tester.ensureSemantics();
    var activations = 0;

    await tester.pumpWidget(
      MaterialApp(
        theme: _theme(Brightness.light),
        home: Scaffold(
          body: SettingsTile.switchTile(
            title: const Text('Unavailable'),
            initialValue: false,
            enabled: false,
            onToggle: (_) => activations++,
          ),
        ),
      ),
    );

    await tester.tap(find.text('Unavailable'));
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();

    expect(activations, 0);
    expect(
      tester.getSemantics(find.text('Unavailable')),
      isSemantics(
        label: 'Unavailable',
        hasToggledState: true,
        isToggled: false,
        hasEnabledState: true,
        isEnabled: false,
        hasTapAction: false,
      ),
    );
    semanticsHandle.dispose();
  });

  testWidgets('settings remain bounded and overflow-free with large text',
      (tester) async {
    tester.view.physicalSize = const Size(480, 360);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    Widget buildSettings(double scale) {
      return MaterialApp(
        theme: _theme(Brightness.light),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(scale),
          ),
          child: child!,
        ),
        home: Scaffold(
          body: SettingsList(
            sections: [
              SettingsSection(
                title: const Text('Appearance and interaction'),
                tiles: [
                  SettingsTile.navigation(
                    title: const Text(
                      'A deliberately long settings title for desktop scaling',
                    ),
                    description: const Text(
                      'A long supporting description that must wrap cleanly.',
                    ),
                    onPressed: (_) {},
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    await tester.pumpWidget(buildSettings(2));
    expect(tester.takeException(), isNull);

    tester.view.physicalSize = const Size(1600, 900);
    await tester.pumpWidget(buildSettings(1));
    final sectionRect = tester.getRect(find.byType(SettingsSection));
    expect(
      sectionRect.width,
      lessThanOrEqualTo(KazumiDesignTokens.readableContentWidth),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('adaptive player sheet can disable backdrop sampling',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: _theme(Brightness.dark),
        home: Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              onPressed: () {
                showAdaptiveBottomSheet<void>(
                  context: context,
                  enableBlur: false,
                  builder: (_) => const SizedBox(
                    height: 180,
                    child: Center(child: Text('Player options')),
                  ),
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.text('Player options'), findsOneWidget);
    expect(find.byType(BackdropFilter), findsNothing);
    expect(find.byType(ClipRSuperellipse), findsOneWidget);
    expect(find.byType(IconButton), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('motion preference zeroes all themed button animations', () {
    final theme = _theme(Brightness.light);
    final reduced = applyKazumiMotionPreference(theme, reduceMotion: true);

    expect(reduced.filledButtonTheme.style?.animationDuration, Duration.zero);
    expect(reduced.elevatedButtonTheme.style?.animationDuration, Duration.zero);
    expect(reduced.outlinedButtonTheme.style?.animationDuration, Duration.zero);
    expect(reduced.textButtonTheme.style?.animationDuration, Duration.zero);
    expect(reduced.iconButtonTheme.style?.animationDuration, Duration.zero);
    expect(
      identical(
        applyKazumiMotionPreference(theme, reduceMotion: false),
        theme,
      ),
      isTrue,
    );
  });

  testWidgets('app backdrop removes ambient glow in high contrast',
      (tester) async {
    int radialGradientCount() {
      return tester
          .widgetList<DecoratedBox>(find.byType(DecoratedBox))
          .where((box) {
        final decoration = box.decoration;
        return decoration is BoxDecoration &&
            decoration.gradient is RadialGradient;
      }).length;
    }

    Widget buildBackdrop({required bool highContrast}) {
      return MaterialApp(
        theme: _theme(Brightness.light),
        home: MediaQuery(
          data: MediaQueryData(highContrast: highContrast),
          child: const KazumiAppBackdrop(child: Text('content')),
        ),
      );
    }

    await tester.pumpWidget(buildBackdrop(highContrast: false));
    expect(radialGradientCount(), 2);

    await tester.pumpWidget(buildBackdrop(highContrast: true));
    expect(radialGradientCount(), 0);
  });

  testWidgets('onboarding remains scrollable at minimum desktop size',
      (tester) async {
    tester.view.physicalSize = const Size(480, 360);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: _theme(Brightness.light),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: const TextScaler.linear(2.25),
          ),
          child: child!,
        ),
        home: Scaffold(
          body: OnboardingStepLayout(
            leading: const OnboardingStepIcon(icon: Icons.palette_rounded),
            title: 'Choose your visual experience',
            subtitle:
                'Configure the catalogue and appearance before continuing.',
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: const [
                Text('First option with a deliberately long explanation.'),
                SizedBox(height: 180),
                Text('Second option'),
              ],
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    final before = tester
        .stateList<ScrollableState>(find.byType(Scrollable))
        .map((state) => state.position.pixels)
        .toList();
    await tester.drag(find.byType(NestedScrollView), const Offset(0, -180));
    await tester.pump();
    final after = tester
        .stateList<ScrollableState>(find.byType(Scrollable))
        .map((state) => state.position.pixels)
        .toList();
    expect(
      List<int>.generate(after.length, (index) => index)
          .any((index) => after[index] > before[index]),
      isTrue,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('real update step handles a short 225 percent text viewport',
      (tester) async {
    tester.view.physicalSize = const Size(480, 360);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: _theme(Brightness.light),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: const TextScaler.linear(2.25),
          ),
          child: child!,
        ),
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 432,
              height: 196,
              child: UpdateSourceStep(
                useGithubUpdate: true,
                onChanged: (_) {},
              ),
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    await tester.drag(find.byType(NestedScrollView), const Offset(0, -180));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('rating dialog is responsive and keyboard adjustable',
      (tester) async {
    tester.view.physicalSize = const Size(720, 560);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: _theme(Brightness.light),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: const TextScaler.linear(1.5),
          ),
          child: child!,
        ),
        home: Scaffold(
          body: RatingReviewDialog(bangumiItem: _reviewItem()),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.byType(RatingBar));
    await tester.pump();
    await tester.tap(find.byType(RatingBar));
    await tester.sendKeyEvent(LogicalKeyboardKey.end);
    await tester.pump();
    expect(find.textContaining('10 / 10'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();
    expect(find.textContaining('9 / 10'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('rating side panel starts only at the exact wide breakpoint',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    Future<void> pumpAtWidth(double width) async {
      tester.view.physicalSize = Size(width, 720);
      await tester.pumpWidget(
        MaterialApp(
          theme: _theme(Brightness.light),
          home: Scaffold(
            body: RatingReviewDialog(bangumiItem: _reviewItem()),
          ),
        ),
      );
      await tester.tap(find.byIcon(Icons.edit_rounded));
      await tester.pumpAndSettle();
    }

    await pumpAtWidth(887);
    expect(find.byKey(const ValueKey('side-tag-panel')), findsNothing);
    expect(tester.takeException(), isNull);

    await pumpAtWidth(888);
    expect(find.byKey(const ValueKey('side-tag-panel')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
