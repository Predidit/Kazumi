import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const iconName = 'ic_media_notification';
  const iconReference = 'drawable/$iconName';

  test('audio service uses a dedicated drawable as its Android small icon',
      () async {
    final source =
        await File('lib/services/player/audio_controller.dart').readAsString();

    expect(
      source,
      contains("androidNotificationIcon: '$iconReference'"),
    );
  });

  test('Android media notification icon is a white monochrome vector',
      () async {
    final icon = File('android/app/src/main/res/drawable/$iconName.xml');

    expect(await icon.exists(), isTrue);
    final source = await icon.readAsString();
    expect(source, contains('<vector'));
    expect(source, isNot(contains('<adaptive-icon')));

    final fillColors = RegExp(r'android:fillColor="([^"]+)"')
        .allMatches(source)
        .map((match) => match.group(1))
        .toList();
    expect(fillColors, isNotEmpty);
    expect(fillColors, everyElement('#FFFFFFFF'));
  });
}
