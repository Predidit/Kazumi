import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kazumi/modules/skip/skip_segment.dart';
import 'package:kazumi/utils/audio_extractor.dart';
import 'package:kazumi/utils/audio_feature_matcher.dart';
import 'package:kazumi/utils/skip_segment_audio_resolver.dart';

void main() {
  group('SkipSegmentAudioResolver', () {
    test('resolves opening segment in the opening search window', () async {
      const sampleRate = 8000;
      const insertSeconds = 4.2;
      final templateSamples = _buildTemplate(sampleRate, seconds: 4);
      final targetSamples = _buildSearch(sampleRate, seconds: 14);
      _insert(targetSamples, templateSamples, insertSeconds, sampleRate);

      final tempDir = await Directory.systemTemp.createTemp('kazumi_skip_');
      addTearDown(() async {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });

      final extractor = _SlicingFakeAudioExtractor(
        sampleRate: sampleRate,
        pcmByInput: {
          'template': _toPcm16Bytes(templateSamples),
          'target': _toPcm16Bytes(targetSamples),
        },
      );
      final resolver = _buildResolver(extractor, sampleRate);
      final template = SkipSegmentTemplate(
        bangumiId: 1,
        pluginName: 'test',
        road: 0,
        sourceEpisode: 2,
        type: SkipSegmentType.opening,
        start: Duration.zero,
        end: const Duration(seconds: 4),
        createdAt: DateTime(2026),
      );

      final result = await resolver.resolve(
        SkipSegmentAudioResolveRequest(
          template: template,
          templateSource: const SkipSegmentAudioSource(input: 'template'),
          targetSource: const SkipSegmentAudioSource(input: 'target'),
          workingDirectory: tempDir.path,
          options: const SkipSegmentAudioResolverOptions(
            sampleRate: sampleRate,
            openingSearchDuration: Duration(seconds: 10),
            scoreThreshold: 0.8,
          ),
        ),
      );

      expect(result, isNotNull);
      expect(
        result!.start.inMilliseconds,
        closeTo((insertSeconds * 1000).round(), 160),
      );
      expect(result.end - result.start, template.duration);
      expect(result.type, SkipSegmentType.opening);
    });

    test('searches ending chunks backward and stops after first match',
        () async {
      const sampleRate = 8000;
      const insertSeconds = 12.3;
      const targetSeconds = 24;
      final templateSamples = _buildTemplate(sampleRate, seconds: 4);
      final targetSamples = _buildSearch(sampleRate, seconds: targetSeconds);
      _insert(targetSamples, templateSamples, insertSeconds, sampleRate);

      final tempDir = await Directory.systemTemp.createTemp('kazumi_skip_');
      addTearDown(() async {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });

      final extractor = _SlicingFakeAudioExtractor(
        sampleRate: sampleRate,
        pcmByInput: {
          'template': _toPcm16Bytes(templateSamples),
          'target': _toPcm16Bytes(targetSamples),
        },
      );
      final resolver = _buildResolver(extractor, sampleRate);
      final template = SkipSegmentTemplate(
        bangumiId: 1,
        pluginName: 'test',
        road: 0,
        sourceEpisode: 2,
        type: SkipSegmentType.ending,
        start: const Duration(seconds: 20),
        end: const Duration(seconds: 24),
        createdAt: DateTime(2026),
      );

      final result = await resolver.resolve(
        SkipSegmentAudioResolveRequest(
          template: template,
          templateSource: const SkipSegmentAudioSource(input: 'template'),
          targetSource: const SkipSegmentAudioSource(input: 'target'),
          targetDuration: const Duration(seconds: targetSeconds),
          workingDirectory: tempDir.path,
          options: const SkipSegmentAudioResolverOptions(
            sampleRate: sampleRate,
            endingChunkDuration: Duration(seconds: 8),
            endingChunkOverlap: Duration(seconds: 2),
            endingMaxLookback: Duration(seconds: 18),
            scoreThreshold: 0.8,
          ),
        ),
      );

      expect(result, isNotNull);
      expect(
        result!.start.inMilliseconds,
        closeTo((insertSeconds * 1000).round(), 160),
      );
      expect(result.end - result.start, template.duration);
      expect(extractor.targetStarts, [
        const Duration(seconds: 16),
        const Duration(seconds: 10),
      ]);
    });

    test('round-trips skip segment template JSON', () {
      final template = SkipSegmentTemplate(
        bangumiId: 123,
        pluginName: 'AGE',
        road: 1,
        sourceEpisode: 3,
        type: SkipSegmentType.ending,
        start: const Duration(minutes: 21, seconds: 30),
        end: const Duration(minutes: 23),
        createdAt: DateTime(2026, 4, 25, 12),
      );

      final restored = SkipSegmentTemplate.fromJson(template.toJson());

      expect(restored.key, template.key);
      expect(restored.start, template.start);
      expect(restored.end, template.end);
      expect(restored.duration, const Duration(seconds: 90));
    });
  });
}

SkipSegmentAudioResolver _buildResolver(
  IAudioExtractor extractor,
  int sampleRate,
) {
  return SkipSegmentAudioResolver(
    extractor: extractor,
    featureOptions: AudioFeatureExtractorOptions(
      sampleRate: sampleRate,
      frameSize: 1024,
      hopSize: 400,
      bandCount: 20,
      minFrequency: 80,
      maxFrequency: 3600,
    ),
  );
}

class _SlicingFakeAudioExtractor implements IAudioExtractor {
  final int sampleRate;
  final Map<String, Uint8List> pcmByInput;
  final List<Duration> targetStarts = [];

  _SlicingFakeAudioExtractor({
    required this.sampleRate,
    required this.pcmByInput,
  });

  @override
  Future<AudioExtractResult> extractPcm16(AudioExtractRequest request) async {
    final bytes = pcmByInput[request.input];
    if (bytes == null) {
      throw AudioExtractException('missing fake PCM for ${request.input}');
    }
    if (request.input == 'target') {
      targetStarts.add(request.start);
    }

    final start = request.input == 'template' ? Duration.zero : request.start;
    final startSample =
        start.inMicroseconds * sampleRate ~/ Duration.microsecondsPerSecond;
    final sampleCount = request.duration.inMicroseconds *
        sampleRate ~/
        Duration.microsecondsPerSecond;
    final startByte = startSample * Int16List.bytesPerElement;
    final endByte =
        min(bytes.length, startByte + sampleCount * Int16List.bytesPerElement);
    final slice = bytes.sublist(startByte, endByte);

    final file = File(request.outputPath);
    await file.parent.create(recursive: true);
    await file.writeAsBytes(slice);
    return AudioExtractResult(
      outputPath: request.outputPath,
      outputBytes: slice.length,
      start: request.start,
      duration: request.duration,
      sampleRate: request.sampleRate,
      channels: request.channels,
    );
  }
}

void _insert(
  List<double> target,
  List<double> template,
  double insertSeconds,
  int sampleRate,
) {
  final insertSample = (insertSeconds * sampleRate).round();
  for (var i = 0; i < template.length; i++) {
    target[insertSample + i] += template[i] * 0.75;
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
  final random = Random(31);
  final segmentSamples = sampleRate ~/ 5;
  final frequencies = List<double>.generate(
    (samples.length / segmentSamples).ceil(),
    (_) => 180 + random.nextInt(1300).toDouble(),
  );

  for (var i = 0; i < samples.length; i++) {
    final t = i / sampleRate;
    final segment = i ~/ segmentSamples;
    final f1 = frequencies[segment];
    final f2 = frequencies[(segment + 4) % frequencies.length] * 1.29;
    final envelope = 0.5 + 0.5 * sin(2 * pi * t / 1.4).abs();
    samples[i] =
        envelope * (0.44 * sin(2 * pi * f1 * t) + 0.24 * sin(2 * pi * f2 * t));
  }
  return samples;
}

List<double> _buildSearch(int sampleRate, {required int seconds}) {
  final samples = List<double>.filled(sampleRate * seconds, 0);
  final random = Random(37);
  for (var i = 0; i < samples.length; i++) {
    final t = i / sampleRate;
    samples[i] = 0.035 * sin(2 * pi * 101 * t) +
        0.018 * sin(2 * pi * 557 * t) +
        (random.nextDouble() - 0.5) * 0.02;
  }
  return samples;
}
