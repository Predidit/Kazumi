import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kazumi/utils/audio_feature_matcher.dart';

void main() {
  group('AudioFeatureMatcher', () {
    test('finds an inserted audio template offset', () {
      const sampleRate = 8000;
      const insertSeconds = 9.2;
      final template = _buildTemplate(sampleRate, seconds: 8);
      final search = _buildSearch(sampleRate, seconds: 28);
      final insertSample = (insertSeconds * sampleRate).round();

      for (var i = 0; i < template.length; i++) {
        search[insertSample + i] += template[i] * 0.75;
      }

      final extractor = AudioFeatureExtractor(
        options: const AudioFeatureExtractorOptions(
          sampleRate: sampleRate,
          frameSize: 1024,
          hopSize: 400,
          bandCount: 20,
          minFrequency: 80,
          maxFrequency: 3600,
        ),
      );
      final templateFeatures = extractor.extractFromSamples(template);
      final searchFeatures = extractor.extractFromSamples(search);

      final result = const AudioSlidingMatcher().findBestMatch(
        templateFeatures,
        searchFeatures,
      );

      expect(
        result.offset.inMilliseconds,
        closeTo((insertSeconds * 1000).round(), 120),
      );
      expect(result.score, greaterThan(0.85));
    });

    test('extracts features from little-endian PCM16 bytes', () {
      final bytes = Uint8List(4096);
      final data = ByteData.sublistView(bytes);
      for (var i = 0; i < bytes.length ~/ Int16List.bytesPerElement; i++) {
        final sample = (sin(2 * pi * 440 * i / 16000) * 28000).round();
        data.setInt16(i * Int16List.bytesPerElement, sample, Endian.little);
      }

      final extractor = AudioFeatureExtractor();
      final features = extractor.extractFromPcm16Bytes(bytes);

      expect(features.frames, isNotEmpty);
    });
  });
}

List<double> _buildTemplate(int sampleRate, {required int seconds}) {
  final samples = List<double>.filled(sampleRate * seconds, 0);
  final random = Random(42);
  final segmentSamples = sampleRate ~/ 4;
  final frequencies = List<double>.generate(
    (samples.length / segmentSamples).ceil(),
    (_) => 180 + random.nextInt(1200).toDouble(),
  );

  for (var i = 0; i < samples.length; i++) {
    final t = i / sampleRate;
    final segment = i ~/ segmentSamples;
    final f1 = frequencies[segment];
    final f2 = frequencies[(segment + 3) % frequencies.length] * 1.37;
    final envelope = 0.55 + 0.45 * sin(2 * pi * t / 1.7).abs();
    samples[i] =
        envelope * (0.45 * sin(2 * pi * f1 * t) + 0.25 * sin(2 * pi * f2 * t));
  }
  return samples;
}

List<double> _buildSearch(int sampleRate, {required int seconds}) {
  final samples = List<double>.filled(sampleRate * seconds, 0);
  final random = Random(7);
  for (var i = 0; i < samples.length; i++) {
    final t = i / sampleRate;
    samples[i] = 0.04 * sin(2 * pi * 97 * t) +
        0.02 * sin(2 * pi * 611 * t) +
        (random.nextDouble() - 0.5) * 0.025;
  }
  return samples;
}
