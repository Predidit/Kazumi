import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kazumi/utils/audio_extractor.dart';
import 'package:kazumi/utils/audio_feature_matcher.dart';
import 'package:kazumi/utils/audio_match_service.dart';

void main() {
  group('AudioMatchService', () {
    test('extracts clips and finds template inside search audio', () async {
      const sampleRate = 8000;
      const insertSeconds = 6.4;
      final template = _buildTemplate(sampleRate, seconds: 7);
      final search = _buildSearch(sampleRate, seconds: 20);
      final insertSample = (insertSeconds * sampleRate).round();

      for (var i = 0; i < template.length; i++) {
        search[insertSample + i] += template[i] * 0.75;
      }

      final tempDir = await Directory.systemTemp.createTemp('kazumi_match_');
      addTearDown(() async {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });

      final service = AudioMatchService(
        extractor: _FakeAudioExtractor({
          'template': _toPcm16Bytes(template),
          'search': _toPcm16Bytes(search),
        }),
        featureOptions: const AudioFeatureExtractorOptions(
          sampleRate: sampleRate,
          frameSize: 1024,
          hopSize: 400,
          bandCount: 20,
          minFrequency: 80,
          maxFrequency: 3600,
        ),
      );

      final result = await service.match(
        AudioMatchRequest(
          template: const AudioSourceClip(
            input: 'template',
            duration: Duration(seconds: 7),
          ),
          search: const AudioSourceClip(
            input: 'search',
            start: Duration(seconds: 30),
            duration: Duration(seconds: 20),
          ),
          workingDirectory: tempDir.path,
          sampleRate: sampleRate,
        ),
      );

      expect(
        result.match.offset.inMilliseconds,
        closeTo((insertSeconds * 1000).round(), 120),
      );
      expect(
        result.absoluteSearchOffset.inMilliseconds,
        closeTo((30 + insertSeconds) * 1000, 120),
      );
      expect(result.match.score, greaterThan(0.8));
      expect(await File(result.templatePcmPath).exists(), isFalse);
      expect(await File(result.searchPcmPath).exists(), isFalse);
    });

    test('can keep temporary PCM files for debugging', () async {
      final tempDir = await Directory.systemTemp.createTemp('kazumi_match_');
      addTearDown(() async {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });

      final samples = _buildTemplate(8000, seconds: 3);
      final service = AudioMatchService(
        extractor: _FakeAudioExtractor({
          'template': _toPcm16Bytes(samples),
          'search': _toPcm16Bytes(samples),
        }),
        featureOptions: const AudioFeatureExtractorOptions(
          sampleRate: 8000,
          frameSize: 1024,
          hopSize: 400,
          bandCount: 20,
          minFrequency: 80,
          maxFrequency: 3600,
        ),
      );

      final result = await service.match(
        AudioMatchRequest(
          template: const AudioSourceClip(
            input: 'template',
            duration: Duration(seconds: 3),
          ),
          search: const AudioSourceClip(
            input: 'search',
            duration: Duration(seconds: 3),
          ),
          workingDirectory: tempDir.path,
          sampleRate: 8000,
          deleteTemporaryFiles: false,
        ),
      );

      expect(await File(result.templatePcmPath).exists(), isTrue);
      expect(await File(result.searchPcmPath).exists(), isTrue);
    });
  });
}

class _FakeAudioExtractor implements IAudioExtractor {
  final Map<String, Uint8List> pcmByInput;

  const _FakeAudioExtractor(this.pcmByInput);

  @override
  Future<AudioExtractResult> extractPcm16(AudioExtractRequest request) async {
    final bytes = pcmByInput[request.input];
    if (bytes == null) {
      throw AudioExtractException('missing fake PCM for ${request.input}');
    }
    final file = File(request.outputPath);
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes);
    return AudioExtractResult(
      outputPath: request.outputPath,
      outputBytes: bytes.length,
      start: request.start,
      duration: request.duration,
      sampleRate: request.sampleRate,
      channels: request.channels,
    );
  }
}

Uint8List _toPcm16Bytes(List<double> samples) {
  final bytes = Uint8List(samples.length * Int16List.bytesPerElement);
  final data = ByteData.sublistView(bytes);
  for (var i = 0; i < samples.length; i++) {
    final value = (samples[i].clamp(-1.0, 1.0) * 32767).round();
    data.setInt16(i * Int16List.bytesPerElement, value, Endian.little);
  }
  return bytes;
}

List<double> _buildTemplate(int sampleRate, {required int seconds}) {
  final samples = List<double>.filled(sampleRate * seconds, 0);
  final random = Random(13);
  final segmentSamples = sampleRate ~/ 5;
  final frequencies = List<double>.generate(
    (samples.length / segmentSamples).ceil(),
    (_) => 200 + random.nextInt(1300).toDouble(),
  );

  for (var i = 0; i < samples.length; i++) {
    final t = i / sampleRate;
    final segment = i ~/ segmentSamples;
    final f1 = frequencies[segment];
    final f2 = frequencies[(segment + 5) % frequencies.length] * 1.21;
    final envelope = 0.5 + 0.5 * sin(2 * pi * t / 1.3).abs();
    samples[i] =
        envelope * (0.42 * sin(2 * pi * f1 * t) + 0.22 * sin(2 * pi * f2 * t));
  }
  return samples;
}

List<double> _buildSearch(int sampleRate, {required int seconds}) {
  final samples = List<double>.filled(sampleRate * seconds, 0);
  final random = Random(23);
  for (var i = 0; i < samples.length; i++) {
    final t = i / sampleRate;
    samples[i] = 0.035 * sin(2 * pi * 113 * t) +
        0.018 * sin(2 * pi * 499 * t) +
        (random.nextDouble() - 0.5) * 0.02;
  }
  return samples;
}
