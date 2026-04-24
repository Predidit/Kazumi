import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kazumi/utils/audio_extractor.dart';

void main() {
  group('FfmpegAudioExtractor', () {
    test('builds PCM16 extraction arguments for HTTP sources', () {
      final extractor = FfmpegAudioExtractor();
      final args = extractor.buildArguments(
        const AudioExtractRequest(
          input: 'https://example.com/video.m3u8',
          outputPath: 'out.pcm',
          httpHeaders: {
            'user-agent': 'KazumiTest',
            'referer': 'https://example.com',
          },
          start: Duration(seconds: 12, milliseconds: 345),
          duration: Duration(seconds: 30),
        ),
      );

      expect(args, containsAllInOrder(['-ss', '12.345']));
      expect(args, containsAllInOrder(['-t', '30.000']));
      expect(
          args,
          containsAllInOrder(
              ['-headers', contains('user-agent: KazumiTest\r\n')]));
      expect(
          args, containsAllInOrder(['-i', 'https://example.com/video.m3u8']));
      expect(args, containsAllInOrder(['-map', '0:a:0']));
      expect(args, containsAllInOrder(['-ac', '1']));
      expect(args, containsAllInOrder(['-ar', '16000']));
      expect(args, containsAllInOrder(['-f', 's16le', 'out.pcm']));
    });

    test('does not attach HTTP headers to local files', () {
      final extractor = FfmpegAudioExtractor();
      final args = extractor.buildArguments(
        const AudioExtractRequest(
          input: r'D:\video\playlist.m3u8',
          outputPath: 'out.pcm',
          httpHeaders: {'referer': 'https://example.com'},
        ),
      );

      expect(args, isNot(contains('-headers')));
    });

    test('returns output info when ffmpeg succeeds', () async {
      final tempDir = await Directory.systemTemp.createTemp('kazumi_audio_');
      addTearDown(() async {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });
      final outputPath = '${tempDir.path}${Platform.pathSeparator}sample.pcm';
      late List<String> capturedArgs;

      final extractor = FfmpegAudioExtractor(
        processRunner: (executable, arguments) async {
          capturedArgs = arguments;
          await File(arguments.last).writeAsBytes(List<int>.filled(128, 1));
          return ProcessResult(1, 0, '', '');
        },
      );

      final result = await extractor.extractPcm16(
        AudioExtractRequest(
          input: 'https://example.com/video.m3u8',
          outputPath: outputPath,
        ),
      );

      expect(capturedArgs.last, outputPath);
      expect(result.outputPath, outputPath);
      expect(result.outputBytes, 128);
      expect(result.sampleRate, 16000);
      expect(result.channels, 1);
    });

    test('deletes partial output when ffmpeg fails', () async {
      final tempDir = await Directory.systemTemp.createTemp('kazumi_audio_');
      addTearDown(() async {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });
      final outputPath = '${tempDir.path}${Platform.pathSeparator}partial.pcm';

      final extractor = FfmpegAudioExtractor(
        processRunner: (executable, arguments) async {
          await File(arguments.last).writeAsBytes(List<int>.filled(64, 1));
          return ProcessResult(2, 1, '', 'decode failed');
        },
      );

      await expectLater(
        extractor.extractPcm16(
          AudioExtractRequest(
            input: 'https://example.com/video.m3u8',
            outputPath: outputPath,
          ),
        ),
        throwsA(isA<AudioExtractException>()),
      );
      expect(await File(outputPath).exists(), isFalse);
    });
  });
}
