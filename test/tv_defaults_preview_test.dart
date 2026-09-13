
import 'package:flutter_test/flutter_test.dart';
import 'package:kazumi/pages/router.dart';
import 'package:kazumi/services/platform/tv_mode.dart';
import 'package:kazumi/services/player/playback_cache_policy.dart';
import 'package:kazumi/services/storage/settings_keys.dart';
import 'package:kazumi/services/update/auto_updater.dart';

void main() {
  const tv = SettingContext(isTelevision: true, compactLayout: true);
  const mobile = SettingContext(compactLayout: true);
  const mib = 1024 * 1024;
  tearDown(() => TvMode.setEnabledForTesting(false));

  test('TV defaults differ without changing mobile or saved preferences', () {
    expect(SettingsKeys.lowMemoryMode.resolveStored(null, tv), isTrue);
    expect(SettingsKeys.lowMemoryMode.resolveStored(false, tv), isFalse);
    expect(SettingsKeys.lowMemoryMode.resolveDefault(mobile), isFalse);
    expect(SettingsKeys.playerControllerLayerDisappearTime.resolveDefault(tv),
        7000);
    expect(
        SettingsKeys.playerControllerLayerDisappearTime.resolveStored(2500, tv),
        2500);
    expect(
        SettingsKeys.playerControllerLayerDisappearTime.resolveDefault(mobile),
        4000);
    expect(SettingsKeys.danmakuFontSize.resolveDefault(tv), 24.0);
    expect(SettingsKeys.danmakuFontSize.resolveDefault(mobile), 16.0);
    expect(SettingsKeys.danmakuArea.resolveDefault(tv), 0.5);
    expect(SettingsKeys.danmakuArea.resolveDefault(mobile), 1.0);
    expect(SettingsKeys.downloadParallelEpisodes.resolveDefault(tv), 1);
    expect(SettingsKeys.downloadParallelSegments.resolveDefault(tv), 2);
    expect(SettingsKeys.brightnessVolumeGesture.resolveDefault(tv), false);
    expect(SettingsKeys.playerDisableAnimations.resolveDefault(tv), true);
    expect(SettingsKeys.autoUpdate.resolveDefault(tv), false);
    expect(SettingsKeys.hAenable.resolveDefault(tv), true);
    expect(SettingsKeys.hardwareDecoder.resolveDefault(tv), 'auto-safe');
    expect(SettingsKeys.defaultSuperResolutionMode.resolveDefault(tv), 1);
  });

  test('TV cache is bounded; metered network and mobile semantics remain', () {
    int size(bool tv, bool low, bool metered, [bool back = false]) =>
        PlaybackCachePolicy.cacheBytes(
            television: tv, lowMemory: low, metered: metered, backward: back) ~/
        mib;
    expect(size(true, true, false), 64);
    expect(size(true, true, false, true), 16);
    expect(size(true, false, false), 256);
    expect(size(true, false, false, true), 64);
    expect(size(true, true, true), 2);
    expect(size(true, false, true, true), 2);
    expect(size(false, true, false), 2);
    expect(size(false, false, false), 1500);
  });

  test('history has a TV-only rail slot and mobile indices stay unchanged', () {
    TvMode.setEnabledForTesting(true);
    expect(menu.indexForPath('/tab/history/'), 1);
    expect(menu.getPath(2), '/timeline');
    expect(menu.getPath(5), '/remote-help');
    TvMode.setEnabledForTesting(false);
    expect(menu.menuList.length, 4);
    expect(menu.getPath(1), '/timeline');
    expect(menu.getPath(3), '/my');
  });

  test('TV never queries upstream mobile updater', () async {
    TvMode.setEnabledForTesting(true);
    expect(await AutoUpdater().checkForUpdates(), isNull);
    await AutoUpdater().autoCheckForUpdates();
  });
}
