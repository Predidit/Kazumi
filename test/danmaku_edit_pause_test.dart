import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kazumi/pages/player/controller/danmaku_edit_pause.dart';
import 'package:kazumi/services/storage/settings_keys.dart';

/// The composer pauses playback while it is edited and resumes it on blur, but
/// it may only undo the pause it caused itself: a video the user paused manually
/// must stay paused, and a disabled setting must never touch playback.
///
/// Resuming on every blur is safe because the panel edits behind a barrier that
/// swallows the taps, so no other control toggles playback in the same gesture.
void main() {
  DanmakuEditPauseController controller() => DanmakuEditPauseController();

  test('pauses when the composer takes focus while playing', () {
    final pause = controller();

    expect(
      pause.onFocusChanged(hasFocus: true, enabled: true, playing: true),
      DanmakuEditPauseAction.pause,
    );
    expect(pause.pausedByEdit, isTrue);
  });

  test('resumes when the composer loses that focus', () {
    final pause = controller();

    pause.onFocusChanged(hasFocus: true, enabled: true, playing: true);
    expect(
      pause.onFocusChanged(hasFocus: false, enabled: true, playing: false),
      DanmakuEditPauseAction.resume,
    );
    expect(pause.pausedByEdit, isFalse);
  });

  test('leaves a video the user paused manually alone', () {
    final pause = controller();

    expect(
      pause.onFocusChanged(hasFocus: true, enabled: true, playing: false),
      DanmakuEditPauseAction.none,
    );
    expect(
      pause.onFocusChanged(hasFocus: false, enabled: true, playing: false),
      DanmakuEditPauseAction.none,
    );
  });

  test('does nothing while the setting is disabled', () {
    final pause = controller();

    expect(
      pause.onFocusChanged(hasFocus: true, enabled: false, playing: true),
      DanmakuEditPauseAction.none,
    );
    expect(
      pause.onFocusChanged(hasFocus: false, enabled: false, playing: false),
      DanmakuEditPauseAction.none,
    );
  });

  test('blur is idempotent', () {
    final pause = controller();

    pause.onFocusChanged(hasFocus: true, enabled: true, playing: true);
    expect(
      pause.onFocusChanged(hasFocus: false, enabled: true, playing: false),
      DanmakuEditPauseAction.resume,
    );
    expect(
      pause.onFocusChanged(hasFocus: false, enabled: true, playing: false),
      DanmakuEditPauseAction.none,
    );
  });

  test('repeated focus notifications do not pile up pauses', () {
    final pause = controller();

    expect(
      pause.onFocusChanged(hasFocus: true, enabled: true, playing: true),
      DanmakuEditPauseAction.pause,
    );
    expect(
      pause.onFocusChanged(hasFocus: true, enabled: true, playing: false),
      DanmakuEditPauseAction.none,
    );
  });

  test('supports repeated focus cycles', () {
    final pause = controller();

    for (var cycle = 0; cycle < 3; cycle++) {
      expect(
        pause.onFocusChanged(hasFocus: true, enabled: true, playing: true),
        DanmakuEditPauseAction.pause,
      );
      expect(
        pause.onFocusChanged(hasFocus: false, enabled: true, playing: false),
        DanmakuEditPauseAction.resume,
      );
    }
  });

  group('default value', () {
    tearDown(() => debugDefaultTargetPlatformOverride = null);

    test('is off on desktop and on on mobile, like the B 站 client', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      expect(
        SettingsKeys.pauseOnDanmakuEdit.resolveDefault(const SettingContext()),
        isFalse,
      );

      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      expect(
        SettingsKeys.pauseOnDanmakuEdit.resolveDefault(const SettingContext()),
        isTrue,
      );
    });

    test('is reset by 「恢复默认弹幕设置」', () {
      // SettingsKeys.byGroup feeds the danmaku settings reset button, so a key
      // missing from `all` would survive that reset.
      expect(SettingsKeys.all, contains(SettingsKeys.pauseOnDanmakuEdit));
      expect(
        SettingsKeys.byGroup(SettingGroup.danmaku),
        contains(SettingsKeys.pauseOnDanmakuEdit),
      );
    });
  });
}
