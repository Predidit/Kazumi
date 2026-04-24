import 'dart:io';

import 'package:kazumi/modules/skip/skip_segment.dart';
import 'package:kazumi/utils/audio_extractor.dart';
import 'package:kazumi/utils/audio_feature_matcher.dart';
import 'package:path/path.dart' as p;

class SkipSegmentAudioSource {
  final String input;
  final Map<String, String> httpHeaders;

  const SkipSegmentAudioSource({
    required this.input,
    this.httpHeaders = const {},
  });

  void validate(String name) {
    if (input.isEmpty) {
      throw ArgumentError.value(input, '$name.input');
    }
  }
}

class SkipSegmentAudioResolverOptions {
  final int sampleRate;
  final Duration openingSearchDuration;
  final Duration endingChunkDuration;
  final Duration endingChunkOverlap;
  final Duration endingMaxLookback;
  final double scoreThreshold;
  final Duration extractTimeout;
  final bool deleteTemporaryFiles;

  const SkipSegmentAudioResolverOptions({
    this.sampleRate = 16000,
    this.openingSearchDuration = const Duration(minutes: 5),
    this.endingChunkDuration = const Duration(minutes: 3),
    this.endingChunkOverlap = const Duration(seconds: 45),
    this.endingMaxLookback = const Duration(minutes: 15),
    this.scoreThreshold = 0.8,
    this.extractTimeout = const Duration(seconds: 90),
    this.deleteTemporaryFiles = true,
  });

  void validate() {
    if (sampleRate <= 0) {
      throw ArgumentError.value(sampleRate, 'sampleRate');
    }
    if (openingSearchDuration <= Duration.zero) {
      throw ArgumentError.value(openingSearchDuration, 'openingSearchDuration');
    }
    if (endingChunkDuration <= Duration.zero) {
      throw ArgumentError.value(endingChunkDuration, 'endingChunkDuration');
    }
    if (endingChunkOverlap < Duration.zero ||
        endingChunkOverlap >= endingChunkDuration) {
      throw ArgumentError.value(endingChunkOverlap, 'endingChunkOverlap');
    }
    if (endingMaxLookback <= Duration.zero) {
      throw ArgumentError.value(endingMaxLookback, 'endingMaxLookback');
    }
    if (scoreThreshold < -1 || scoreThreshold > 1) {
      throw ArgumentError.value(scoreThreshold, 'scoreThreshold');
    }
    if (extractTimeout <= Duration.zero) {
      throw ArgumentError.value(extractTimeout, 'extractTimeout');
    }
  }
}

class SkipSegmentAudioResolveRequest {
  final SkipSegmentTemplate template;
  final SkipSegmentAudioSource templateSource;
  final SkipSegmentAudioSource targetSource;
  final String workingDirectory;
  final Duration? targetDuration;
  final SkipSegmentAudioResolverOptions options;

  const SkipSegmentAudioResolveRequest({
    required this.template,
    required this.templateSource,
    required this.targetSource,
    required this.workingDirectory,
    this.targetDuration,
    this.options = const SkipSegmentAudioResolverOptions(),
  });

  void validate() {
    template.validate();
    templateSource.validate('templateSource');
    targetSource.validate('targetSource');
    if (workingDirectory.isEmpty) {
      throw ArgumentError.value(workingDirectory, 'workingDirectory');
    }
    if (targetDuration != null && targetDuration! <= Duration.zero) {
      throw ArgumentError.value(targetDuration, 'targetDuration');
    }
    if (template.type == SkipSegmentType.ending && targetDuration == null) {
      throw ArgumentError.notNull('targetDuration');
    }
    options.validate();
  }
}

class SkipSegmentAudioResolver {
  final IAudioExtractor extractor;
  final AudioFeatureExtractorOptions? featureOptions;
  final AudioSlidingMatcher matcher;

  const SkipSegmentAudioResolver({
    required this.extractor,
    this.featureOptions,
    this.matcher = const AudioSlidingMatcher(),
  });

  Future<ResolvedSkipSegment?> resolve(
    SkipSegmentAudioResolveRequest request,
  ) async {
    request.validate();

    final workingDirectory = Directory(request.workingDirectory);
    await workingDirectory.create(recursive: true);
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    final templatePath = p.join(workingDirectory.path, 'skip_template_$id.pcm');

    try {
      final templateFeatures = await _extractFeatures(
        input: request.templateSource.input,
        outputPath: templatePath,
        httpHeaders: request.templateSource.httpHeaders,
        start: request.template.start,
        duration: request.template.duration,
        sampleRate: request.options.sampleRate,
        timeout: request.options.extractTimeout,
        options: _featureOptionsFor(request),
      );

      return switch (request.template.type) {
        SkipSegmentType.opening => _resolveOpening(
            request,
            templateFeatures,
            id,
          ),
        SkipSegmentType.ending => _resolveEnding(
            request,
            templateFeatures,
            id,
          ),
      };
    } finally {
      if (request.options.deleteTemporaryFiles) {
        await _deleteIfExists(templatePath);
      }
    }
  }

  Future<ResolvedSkipSegment?> _resolveOpening(
    SkipSegmentAudioResolveRequest request,
    AudioFeatureSequence templateFeatures,
    String id,
  ) async {
    final searchDuration = _maxDuration(
      request.template.duration,
      request.options.openingSearchDuration,
    );
    final searchPath =
        p.join(request.workingDirectory, 'skip_opening_search_$id.pcm');

    try {
      final searchFeatures = await _extractFeatures(
        input: request.targetSource.input,
        outputPath: searchPath,
        httpHeaders: request.targetSource.httpHeaders,
        start: Duration.zero,
        duration: searchDuration,
        sampleRate: request.options.sampleRate,
        timeout: request.options.extractTimeout,
        options: _featureOptionsFor(request),
      );
      final match = matcher.findBestMatch(templateFeatures, searchFeatures);
      if (match.score < request.options.scoreThreshold) {
        return null;
      }
      return _toResolvedSegment(request.template, match.offset, match);
    } finally {
      if (request.options.deleteTemporaryFiles) {
        await _deleteIfExists(searchPath);
      }
    }
  }

  Future<ResolvedSkipSegment?> _resolveEnding(
    SkipSegmentAudioResolveRequest request,
    AudioFeatureSequence templateFeatures,
    String id,
  ) async {
    final targetDuration = request.targetDuration!;
    final maxLookback =
        _minDuration(targetDuration, request.options.endingMaxLookback);
    var chunkEnd = targetDuration;
    var chunkIndex = 0;

    while (chunkEnd > targetDuration - maxLookback) {
      final lookbackStart = targetDuration - maxLookback;
      final chunkStart = _maxDuration(
          lookbackStart, chunkEnd - request.options.endingChunkDuration);
      final chunkDuration = chunkEnd - chunkStart;
      if (chunkDuration < request.template.duration) {
        break;
      }

      final searchPath = p.join(
          request.workingDirectory, 'skip_ending_search_${id}_$chunkIndex.pcm');
      try {
        final searchFeatures = await _extractFeatures(
          input: request.targetSource.input,
          outputPath: searchPath,
          httpHeaders: request.targetSource.httpHeaders,
          start: chunkStart,
          duration: chunkDuration,
          sampleRate: request.options.sampleRate,
          timeout: request.options.extractTimeout,
          options: _featureOptionsFor(request),
        );
        final match = matcher.findBestMatch(templateFeatures, searchFeatures);
        if (match.score >= request.options.scoreThreshold) {
          return _toResolvedSegment(
            request.template,
            chunkStart + match.offset,
            match,
          );
        }
      } finally {
        if (request.options.deleteTemporaryFiles) {
          await _deleteIfExists(searchPath);
        }
      }

      if (chunkStart <= lookbackStart) {
        break;
      }
      chunkEnd = chunkStart + request.options.endingChunkOverlap;
      chunkIndex++;
    }

    return null;
  }

  Future<AudioFeatureSequence> _extractFeatures({
    required String input,
    required String outputPath,
    required Map<String, String> httpHeaders,
    required Duration start,
    required Duration duration,
    required int sampleRate,
    required Duration timeout,
    required AudioFeatureExtractorOptions options,
  }) async {
    await extractor.extractPcm16(
      AudioExtractRequest(
        input: input,
        outputPath: outputPath,
        httpHeaders: httpHeaders,
        start: start,
        duration: duration,
        sampleRate: sampleRate,
        channels: 1,
        timeout: timeout,
      ),
    );

    final bytes = await File(outputPath).readAsBytes();
    return AudioFeatureExtractor(options: options).extractFromPcm16Bytes(bytes);
  }

  AudioFeatureExtractorOptions _featureOptionsFor(
    SkipSegmentAudioResolveRequest request,
  ) {
    final options = featureOptions ??
        AudioFeatureExtractorOptions(sampleRate: request.options.sampleRate);
    if (options.sampleRate != request.options.sampleRate) {
      throw ArgumentError(
        'featureOptions.sampleRate must match resolver options sampleRate',
      );
    }
    return options;
  }

  static ResolvedSkipSegment _toResolvedSegment(
    SkipSegmentTemplate template,
    Duration start,
    AudioSlidingMatchResult match,
  ) {
    return ResolvedSkipSegment(
      type: template.type,
      start: start,
      end: start + template.duration,
      score: match.score,
      confidence: match.confidence,
      sourceEpisode: template.sourceEpisode,
    );
  }

  static Duration _minDuration(Duration a, Duration b) {
    return a <= b ? a : b;
  }

  static Duration _maxDuration(Duration a, Duration b) {
    return a >= b ? a : b;
  }

  static Future<void> _deleteIfExists(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {}
  }
}
