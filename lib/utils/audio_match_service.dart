import 'dart:io';

import 'package:kazumi/utils/audio_extractor.dart';
import 'package:kazumi/utils/audio_feature_matcher.dart';
import 'package:path/path.dart' as p;

class AudioSourceClip {
  final String input;
  final Map<String, String> httpHeaders;
  final Duration start;
  final Duration duration;

  const AudioSourceClip({
    required this.input,
    this.httpHeaders = const {},
    this.start = Duration.zero,
    required this.duration,
  });

  void validate(String name) {
    if (input.isEmpty) {
      throw ArgumentError.value(input, '$name.input');
    }
    if (start.isNegative) {
      throw ArgumentError.value(start, '$name.start');
    }
    if (duration <= Duration.zero) {
      throw ArgumentError.value(duration, '$name.duration');
    }
  }
}

class AudioMatchRequest {
  final AudioSourceClip template;
  final AudioSourceClip search;
  final String workingDirectory;
  final int sampleRate;
  final Duration extractTimeout;
  final bool deleteTemporaryFiles;

  const AudioMatchRequest({
    required this.template,
    required this.search,
    required this.workingDirectory,
    this.sampleRate = 16000,
    this.extractTimeout = const Duration(seconds: 90),
    this.deleteTemporaryFiles = true,
  });

  void validate() {
    template.validate('template');
    search.validate('search');
    if (workingDirectory.isEmpty) {
      throw ArgumentError.value(workingDirectory, 'workingDirectory');
    }
    if (sampleRate <= 0) {
      throw ArgumentError.value(sampleRate, 'sampleRate');
    }
    if (extractTimeout <= Duration.zero) {
      throw ArgumentError.value(extractTimeout, 'extractTimeout');
    }
  }
}

class AudioMatchServiceResult {
  final AudioSlidingMatchResult match;
  final AudioExtractResult templateExtract;
  final AudioExtractResult searchExtract;
  final String templatePcmPath;
  final String searchPcmPath;

  const AudioMatchServiceResult({
    required this.match,
    required this.templateExtract,
    required this.searchExtract,
    required this.templatePcmPath,
    required this.searchPcmPath,
  });

  Duration get absoluteSearchOffset => searchExtract.start + match.offset;
}

class AudioMatchService {
  final IAudioExtractor extractor;
  final AudioSlidingMatcher matcher;
  final AudioFeatureExtractorOptions? featureOptions;

  const AudioMatchService({
    required this.extractor,
    this.matcher = const AudioSlidingMatcher(),
    this.featureOptions,
  });

  Future<AudioMatchServiceResult> match(AudioMatchRequest request) async {
    request.validate();

    final workingDirectory = Directory(request.workingDirectory);
    await workingDirectory.create(recursive: true);

    final id = DateTime.now().microsecondsSinceEpoch.toString();
    final templatePath = p.join(workingDirectory.path, 'template_$id.pcm');
    final searchPath = p.join(workingDirectory.path, 'search_$id.pcm');

    try {
      final templateExtract = await extractor.extractPcm16(
        AudioExtractRequest(
          input: request.template.input,
          outputPath: templatePath,
          httpHeaders: request.template.httpHeaders,
          start: request.template.start,
          duration: request.template.duration,
          sampleRate: request.sampleRate,
          channels: 1,
          timeout: request.extractTimeout,
        ),
      );
      final searchExtract = await extractor.extractPcm16(
        AudioExtractRequest(
          input: request.search.input,
          outputPath: searchPath,
          httpHeaders: request.search.httpHeaders,
          start: request.search.start,
          duration: request.search.duration,
          sampleRate: request.sampleRate,
          channels: 1,
          timeout: request.extractTimeout,
        ),
      );

      final options = featureOptions ??
          AudioFeatureExtractorOptions(sampleRate: request.sampleRate);
      if (options.sampleRate != request.sampleRate) {
        throw ArgumentError(
          'featureOptions.sampleRate must match request.sampleRate',
        );
      }

      final featureExtractor = AudioFeatureExtractor(options: options);
      final templateBytes = await File(templatePath).readAsBytes();
      final searchBytes = await File(searchPath).readAsBytes();
      final templateFeatures =
          featureExtractor.extractFromPcm16Bytes(templateBytes);
      final searchFeatures =
          featureExtractor.extractFromPcm16Bytes(searchBytes);
      final match = matcher.findBestMatch(templateFeatures, searchFeatures);

      return AudioMatchServiceResult(
        match: match,
        templateExtract: templateExtract,
        searchExtract: searchExtract,
        templatePcmPath: templatePath,
        searchPcmPath: searchPath,
      );
    } finally {
      if (request.deleteTemporaryFiles) {
        await _deleteIfExists(templatePath);
        await _deleteIfExists(searchPath);
      }
    }
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
