import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:kazumi/bean/settings/settings_detail_scaffold.dart';
import 'package:kazumi/pages/settings/update_settings.dart';
import 'package:kazumi/services/storage/storage.dart';
import 'package:kazumi/services/update/update_download_source.dart';
import 'package:kazumi/services/update/update_downloader.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

void main() {
  const mirror = 'https://mirror.example/update.zip';
  const github = 'https://github.com/example/releases/update.zip';
  const asset = {'mirror_download_url': mirror, 'browser_download_url': github};
  late Directory directory;
  late PathProviderPlatform originalPaths;

  setUpAll(() async {
    directory = await Directory.systemTemp.createTemp('kazumi_update_source_');
    originalPaths = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _TestPaths(directory.path);
    Hive.init(directory.path);
    await Hive.openBox<dynamic>('setting', bytes: Uint8List(0));
    await GStorage.init();
  });

  tearDownAll(() async {
    await Hive.close();
    PathProviderPlatform.instance = originalPaths;
    await directory.delete(recursive: true);
  });

  test('default and unrecognized source select mirror', () {
    expect(SettingsKeys.updateDownloadSource.defaultValue, 'mirror');
    expect(UpdateDownloadSource.fromSetting(''), UpdateDownloadSource.mirror);
    expect(
      UpdateDownloadSource.fromSetting('invalid'),
      UpdateDownloadSource.mirror,
    );
    expect(
      SettingsKeys.byGroup(SettingGroup.update),
      contains(SettingsKeys.updateDownloadSource),
    );
    expect(getUpdateDownloadUrlFromAsset(asset), mirror);
  });

  test('GitHub selection skips the mirror for the same asset', () async {
    await GStorage.putSetting(SettingsKeys.updateDownloadSource, 'github');
    final source = UpdateDownloadSource.fromSetting(
      GStorage.getSetting(SettingsKeys.updateDownloadSource),
    );
    expect(getUpdateDownloadUrlFromAsset(asset, source: source), github);
    expect(
      getUpdateDownloadUrlFromAsset(const {
        'mirror_download_url': mirror,
      }, source: source),
      isEmpty,
    );
  });

  test('mirror selection never uses official when mirror is unavailable', () {
    expect(
      getUpdateDownloadUrlFromAsset(asset, source: UpdateDownloadSource.mirror),
      mirror,
    );
    expect(
      getUpdateDownloadUrlFromAsset(const {
        'browser_download_url': github,
      }, source: UpdateDownloadSource.mirror),
      isEmpty,
    );
  });

  Future<void> mountPage(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SettingsPaneScope(
          embedded: true,
          showBackButton: false,
          onBack: () {},
          child: const UpdateSettingsPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'source selector saves both choices and restores after reopening',
    (tester) async {
      await tester.runAsync(() async {
        await GStorage.putSetting(SettingsKeys.updateDownloadSource, 'mirror');
        await GStorage.putSetting(SettingsKeys.autoUpdate, false);
      });
      await mountPage(tester);
      expect(find.text('镜像源'), findsOneWidget);
      expect(find.text('从镜像源下载应用更新'), findsOneWidget);

      await tester.tap(find.text('更新下载源'));
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        await tester.tap(find.text('GitHub 官方源').last);
        await Hive.box('setting').flush();
      });
      await tester.pumpAndSettle();
      expect(GStorage.getSetting(SettingsKeys.updateDownloadSource), 'github');
      expect(GStorage.getSetting(SettingsKeys.autoUpdate), isFalse);
      expect(find.text('直接从 GitHub 下载应用更新'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await mountPage(tester);
      expect(find.text('GitHub 官方源'), findsOneWidget);
      await tester.tap(find.text('更新下载源'));
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        await tester.tap(find.text('镜像源').last);
        await Hive.box('setting').flush();
      });
      await tester.pumpAndSettle();
      expect(GStorage.getSetting(SettingsKeys.updateDownloadSource), 'mirror');
      expect(find.text('从镜像源下载应用更新'), findsOneWidget);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  for (final platform in TargetPlatform.values) {
    testWidgets('download source visibility matches $platform update support', (
      tester,
    ) async {
      final supportsDownload = const {
        TargetPlatform.android,
        TargetPlatform.windows,
        TargetPlatform.macOS,
      }.contains(platform);
      final savedSource = GStorage.getSetting(
        SettingsKeys.updateDownloadSource,
      );

      await mountPage(tester);

      expect(
        find.text('更新下载源'),
        supportsDownload ? findsOneWidget : findsNothing,
      );
      expect(
        find.text('应用更新下载'),
        supportsDownload ? findsOneWidget : findsNothing,
      );
      expect(find.text('启动时检查更新'), findsOneWidget);
      expect(find.text('应用更新'), findsOneWidget);
      expect(find.text('规则更新'), findsOneWidget);
      expect(
        GStorage.getSetting(SettingsKeys.updateDownloadSource),
        savedSource,
      );
    }, variant: TargetPlatformVariant.only(platform));
  }
}

class _TestPaths extends PathProviderPlatform {
  _TestPaths(this.path);
  final String path;

  @override
  Future<String?> getApplicationSupportPath() async => path;
}
