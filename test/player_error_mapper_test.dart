import 'package:flutter_test/flutter_test.dart';
import 'package:kazumi/services/player/player_error_mapper.dart';

void main() {
  group('PlayerErrorMapper', () {
    test('maps source open failures while buffering', () {
      expect(
        PlayerErrorMapper.toActionableMessage(
          'Failed to open https://example.com/video.mp4',
          isBuffering: true,
        ),
        '加载失败, 请尝试更换其他视频来源',
      );
    });

    test('maps unrecognized upstream payloads while buffering', () {
      expect(
        PlayerErrorMapper.toActionableMessage(
          'Failed to recognize file format.',
          isBuffering: true,
        ),
        '加载失败, 请尝试更换其他视频来源',
      );
    });

    test('leaves unrelated player errors unmapped', () {
      expect(
        PlayerErrorMapper.toActionableMessage(
          'Could not initialize audio device',
          isBuffering: true,
        ),
        isNull,
      );
    });

    test('maps unrecognized payloads after buffering ends', () {
      expect(
        PlayerErrorMapper.toActionableMessage(
          'Failed to recognize file format.',
          isBuffering: false,
        ),
        '加载失败, 请尝试更换其他视频来源',
      );
    });

    test('preserves open failure behavior after buffering ends', () {
      expect(
        PlayerErrorMapper.toActionableMessage(
          'Failed to open https://example.com/video.mp4',
          isBuffering: false,
        ),
        isNull,
      );
    });
  });
}
