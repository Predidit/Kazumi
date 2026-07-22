import 'package:flutter_test/flutter_test.dart';
import 'package:kazumi/services/player/playback_configurator_native.dart';
import 'package:kazumi/services/player/playback_configurator_web.dart';
import 'package:kazumi/services/player/system_volume_service_web.dart';

void main() {
  group('WebPlaybackConfigurator', () {
    const configurator = WebPlaybackConfigurator();

    test('never forwards protected upstream headers to HTML media', () {
      final requestedHeaders = <String, String>{
        'user-agent': 'Kazumi test agent',
        'referer': 'https://source.example/episode/1',
        'cookie': 'session=secret',
      };

      final mediaHeaders = configurator.mediaHttpHeaders(requestedHeaders);

      expect(mediaHeaders, isEmpty);
      expect(requestedHeaders, hasLength(3));
    });

    test('requires a user gesture and uses HTML media volume', () {
      expect(configurator.resolveAutoPlay(true), isFalse);
      expect(configurator.resolveAutoPlay(false), isFalse);
      expect(configurator.usePlayerVolume, isTrue);
      expect(
        configurator.requiresExplicitInitialSeek(
          'https://app.example/media/session/master?kazumi-media=hls.m3u8',
        ),
        isTrue,
      );
      expect(
        configurator.requiresExplicitInitialSeek(
          'https://app.example/media/session/master.mp4',
        ),
        isFalse,
      );
    });
  });

  group('NativePlaybackConfigurator', () {
    final configurator = NativePlaybackConfigurator(
      shaderDirectoryPath: () => 'unused-in-this-test',
    );

    test('preserves requested playback headers without sharing mutation', () {
      final requestedHeaders = <String, String>{
        'user-agent': 'Kazumi native test agent',
        'referer': 'https://source.example/',
      };

      final mediaHeaders = configurator.mediaHttpHeaders(requestedHeaders);
      requestedHeaders.clear();

      expect(mediaHeaders, <String, String>{
        'user-agent': 'Kazumi native test agent',
        'referer': 'https://source.example/',
      });
      expect(
        () => mediaHeaders['cookie'] = 'not-allowed',
        throwsUnsupportedError,
      );
    });

    test('preserves the native autoplay preference', () {
      expect(configurator.resolveAutoPlay(true), isTrue);
      expect(configurator.resolveAutoPlay(false), isFalse);
      expect(
        configurator.requiresExplicitInitialSeek(
          'https://source.example/master.m3u8',
        ),
        isFalse,
      );
    });
  });

  group('WebSystemVolumeService', () {
    const service = WebSystemVolumeService();

    test('never touches the host system volume', () async {
      expect(service.isSupported, isFalse);
      expect(await service.getVolume(), isNull);
      await service.setVolume(0.5);
      await service.setSystemUiVisible(false);
      service.addListener((_) {});
      service.removeListener();
    });
  });
}
