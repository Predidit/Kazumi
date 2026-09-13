import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kazumi/bean/widget/tv_focusable_surface.dart';

void main() {
  testWidgets('TV select key activates the focused surface', (tester) async {
    var activations = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TvFocusableSurface(
            enabled: true,
            autofocus: true,
            onPressed: () => activations += 1,
            child: const SizedBox(width: 120, height: 80),
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pump();

    expect(activations, 1);
  });

  testWidgets('disabled TV surface preserves the unwrapped mobile child',
      (tester) async {
    const childKey = Key('mobile-child');
    await tester.pumpWidget(
      MaterialApp(
        home: TvFocusableSurface(
          enabled: false,
          onPressed: () {},
          child: const SizedBox(key: childKey),
        ),
      ),
    );

    expect(find.byKey(childKey), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(TvFocusableSurface),
        matching: find.byType(Focus),
      ),
      findsNothing,
    );
  });

  testWidgets('number selection can highlight a TV surface before focus',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TvFocusableSurface(
            enabled: true,
            highlighted: true,
            onPressed: () {},
            child: const SizedBox(width: 120, height: 80),
          ),
        ),
      ),
    );

    final decoration = tester.widget<AnimatedContainer>(
      find.descendant(
        of: find.byType(TvFocusableSurface),
        matching: find.byType(AnimatedContainer),
      ),
    );
    final box = decoration.decoration! as BoxDecoration;
    expect((box.border! as Border).top.color, isNot(Colors.transparent));
  });

  testWidgets('TV surface reports focus changes for horizontal category tabs',
      (tester) async {
    final changes = <bool>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TvFocusableSurface(
            enabled: true,
            autofocus: true,
            onFocusChange: changes.add,
            onPressed: () {},
            child: const SizedBox(width: 120, height: 80),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(changes, contains(true));
  });

  testWidgets('one D-pad step skips nested pointer focus targets',
      (tester) async {
    final firstFocus = FocusNode();
    final secondFocus = FocusNode();
    addTearDown(firstFocus.dispose);
    addTearDown(secondFocus.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Row(
            children: [
              TvFocusableSurface(
                enabled: true,
                autofocus: true,
                focusNode: firstFocus,
                onPressed: () {},
                child: InkWell(
                  onTap: () {},
                  child: const SizedBox(width: 120, height: 80),
                ),
              ),
              TvFocusableSurface(
                enabled: true,
                focusNode: secondFocus,
                onPressed: () {},
                child: InkWell(
                  onTap: () {},
                  child: const SizedBox(width: 120, height: 80),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();
    expect(firstFocus.hasFocus, isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();

    expect(secondFocus.hasFocus, isTrue);
  });
}
