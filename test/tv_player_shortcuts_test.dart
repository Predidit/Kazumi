import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kazumi/pages/player/player_keyboard_shortcuts.dart';

String _label(LogicalKeyboardKey key) =>
    key.keyLabel.isNotEmpty ? key.keyLabel : key.debugName!;

void main() {
  test('TV shortcuts reserve vertical D-pad keys for opening controls', () {
    final source = <String, List<String>>{
      'volumeup': [_label(LogicalKeyboardKey.arrowUp)],
      'volumedown': [_label(LogicalKeyboardKey.arrowDown)],
      'playorpause': [' '],
    };

    final result = withTvRemoteShortcuts(source);

    expect(result['volumeup'],
        isNot(contains(_label(LogicalKeyboardKey.arrowUp))));
    expect(
      result['volumedown'],
      isNot(contains(_label(LogicalKeyboardKey.arrowDown))),
    );
    expect(result['showcontrols'], contains(_label(LogicalKeyboardKey.select)));
    expect(
        result['showcontrols'], contains(_label(LogicalKeyboardKey.arrowUp)));
    expect(
        result['showcontrols'], contains(_label(LogicalKeyboardKey.arrowDown)));
    expect(
      result['playorpause'],
      contains(_label(LogicalKeyboardKey.mediaPlayPause)),
    );
    expect(result['showepisodes'], contains(_label(LogicalKeyboardKey.guide)));
    expect(
      result['toggledanmaku'],
      contains(_label(LogicalKeyboardKey.closedCaptionToggle)),
    );
    expect(
      result['togglefavorite'],
      contains(_label(LogicalKeyboardKey.browserFavorites)),
    );
    expect(
        result['volumeup'], contains(_label(LogicalKeyboardKey.audioVolumeUp)));
    expect(
      result['showremotehelp'],
      containsAll([
        _label(LogicalKeyboardKey.help),
        _label(LogicalKeyboardKey.contextMenu),
        _label(LogicalKeyboardKey.f1),
      ]),
    );
    expect(result['back'], contains(_label(LogicalKeyboardKey.goBack)));
    expect(result['exitplayer'], contains(_label(LogicalKeyboardKey.exit)));

    // The helper must not mutate the persisted user mapping it receives.
    expect(source['volumeup'], contains(_label(LogicalKeyboardKey.arrowUp)));
    expect(source.containsKey('showcontrols'), isFalse);
  });

  test('TV volume keys are left to Android and HDMI CEC', () {
    expect(
      shouldDeferTvKeyToPlatform(LogicalKeyboardKey.audioVolumeUp),
      isTrue,
    );
    expect(
      shouldDeferTvKeyToPlatform(LogicalKeyboardKey.audioVolumeMute),
      isTrue,
    );
    expect(
      shouldDeferTvKeyToPlatform(LogicalKeyboardKey.mediaPlayPause),
      isFalse,
    );
  });

  testWidgets('TV remote keys dispatch through the player shortcut handler', (
    tester,
  ) async {
    final focusScopeNode = FocusScopeNode();
    addTearDown(focusScopeNode.dispose);
    var showControlsCount = 0;
    var playPauseCount = 0;
    final shortcuts = withTvRemoteShortcuts(<String, List<String>>{
      'showcontrols': const <String>[],
      'playorpause': const <String>[],
    });

    await tester.pumpWidget(
      MaterialApp(
        home: FocusScope(
          node: focusScopeNode,
          child: Column(
            children: [
              PlayerKeyboardShortcuts(
                focusScopeNode: focusScopeNode,
                shortcuts: shortcuts,
                actions: {
                  'showcontrols': () => showControlsCount += 1,
                  'playorpause': () => playPauseCount += 1,
                },
              ),
              const Focus(autofocus: true, child: SizedBox()),
            ],
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.sendKeyEvent(LogicalKeyboardKey.mediaPlayPause);
    await tester.pump();

    expect(showControlsCount, 1);
    expect(playPauseCount, 1);
  });

  testWidgets('visible TV controls receive OK instead of shortcut capture', (
    tester,
  ) async {
    final focusScopeNode = FocusScopeNode();
    addTearDown(focusScopeNode.dispose);
    var shortcutCount = 0;
    var buttonCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: FocusScope(
          node: focusScopeNode,
          child: Column(
            children: [
              PlayerKeyboardShortcuts(
                focusScopeNode: focusScopeNode,
                shortcuts: withTvRemoteShortcuts({
                  'showcontrols': const <String>[],
                }),
                actions: {'showcontrols': () => shortcutCount += 1},
                shouldHandleAction: (action, key) => action != 'showcontrols',
              ),
              ElevatedButton(
                autofocus: true,
                onPressed: () => buttonCount += 1,
                child: const Text('播放'),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pump();

    expect(shortcutCount, 0);
    expect(buttonCount, 1);
  });

  testWidgets('visible control navigation wins over seek shortcuts', (
    tester,
  ) async {
    final focusScopeNode = FocusScopeNode();
    addTearDown(focusScopeNode.dispose);
    var navigationCount = 0;
    var seekCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: FocusScope(
          node: focusScopeNode,
          child: Column(
            children: [
              PlayerKeyboardShortcuts(
                focusScopeNode: focusScopeNode,
                shortcuts: {
                  'forward': [_label(LogicalKeyboardKey.arrowRight)],
                },
                actions: {'forward': () => seekCount += 1},
                onNavigationKey: (key) {
                  if (key != LogicalKeyboardKey.arrowRight) return false;
                  navigationCount += 1;
                  return true;
                },
              ),
              const Focus(autofocus: true, child: SizedBox()),
            ],
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();

    expect(navigationCount, 1);
    expect(seekCount, 0);
  });

  testWidgets('deferred TV D-pad navigation does not fall through to seek', (
    tester,
  ) async {
    final focusScopeNode = FocusScopeNode();
    addTearDown(focusScopeNode.dispose);
    var seekCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: FocusScope(
          node: focusScopeNode,
          child: Column(
            children: [
              PlayerKeyboardShortcuts(
                focusScopeNode: focusScopeNode,
                shortcuts: {
                  'forward': [_label(LogicalKeyboardKey.arrowRight)],
                },
                actions: {'forward': () => seekCount += 1},
                onNavigationKey: (_) => false,
                shouldHandleAction: (_, __) => false,
              ),
              const Focus(autofocus: true, child: SizedBox()),
            ],
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();

    expect(seekCount, 0);
  });

  testWidgets('an open TV overlay blocks player seek shortcuts', (
    tester,
  ) async {
    final focusScopeNode = FocusScopeNode();
    addTearDown(focusScopeNode.dispose);
    var seekCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: FocusScope(
          node: focusScopeNode,
          child: Column(
            children: [
              PlayerKeyboardShortcuts(
                focusScopeNode: focusScopeNode,
                shortcuts: {
                  'forward': [_label(LogicalKeyboardKey.arrowRight)],
                },
                actions: {'forward': () => seekCount += 1},
                isBlocked: () => true,
              ),
              const Focus(autofocus: true, child: SizedBox()),
            ],
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();

    expect(seekCount, 0);
  });
}
