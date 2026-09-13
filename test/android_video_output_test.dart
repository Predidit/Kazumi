import 'package:flutter_test/flutter_test.dart';
import 'package:kazumi/services/player/android_video_output.dart';

void main() {
  test('TV auto uses the direct MediaCodec Surface path', () {
    expect(
      selectAndroidVideoOutput(
        configuredOutput: 'auto',
        isTv: true,
        androidSdkVersion: 28,
      ),
      'mediacodec_embed',
    );
  });

  test('mobile auto keeps the SDK-dependent GPU outputs', () {
    expect(
      selectAndroidVideoOutput(
        configuredOutput: 'auto',
        isTv: false,
        androidSdkVersion: 33,
      ),
      'gpu',
    );
    expect(
      selectAndroidVideoOutput(
        configuredOutput: 'auto',
        isTv: false,
        androidSdkVersion: 34,
      ),
      'gpu-next',
    );
  });

  test('explicit renderer choice is never overridden', () {
    expect(
      selectAndroidVideoOutput(
        configuredOutput: 'gpu',
        isTv: true,
        androidSdkVersion: 28,
      ),
      'gpu',
    );
  });

  test('direct output capability follows TV auto and explicit selection', () {
    expect(
      usesAndroidDirectMediaCodecOutput(
        configuredOutput: 'auto',
        isTv: true,
      ),
      isTrue,
    );
    expect(
      usesAndroidDirectMediaCodecOutput(
        configuredOutput: 'auto',
        isTv: false,
      ),
      isFalse,
    );
    expect(
      usesAndroidDirectMediaCodecOutput(
        configuredOutput: 'mediacodec_embed',
        isTv: false,
      ),
      isTrue,
    );
  });
}
