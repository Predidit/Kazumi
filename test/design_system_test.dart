import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kazumi/bean/widget/custom_dropdown_menu.dart';
import 'package:kazumi/bean/widget/play_pause_icon.dart';
import 'package:kazumi/design_system/kazumi_design_tokens.dart';
import 'package:kazumi/design_system/kazumi_surfaces.dart';
import 'package:kazumi/design_system/kazumi_theme.dart';

ThemeData _theme(Brightness brightness) {
  return applyKazumiDesignSystem(
    ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorSchemeSeed: Colors.green,
    ),
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
}
