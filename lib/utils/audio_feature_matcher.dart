import 'dart:math';
import 'dart:typed_data';

class AudioFeatureExtractorOptions {
  final int sampleRate;
  final int frameSize;
  final int hopSize;
  final int bandCount;
  final double minFrequency;
  final double maxFrequency;

  const AudioFeatureExtractorOptions({
    this.sampleRate = 16000,
    this.frameSize = 2048,
    this.hopSize = 800,
    this.bandCount = 24,
    this.minFrequency = 80,
    this.maxFrequency = 7600,
  });

  void validate() {
    if (sampleRate <= 0) {
      throw ArgumentError.value(sampleRate, 'sampleRate');
    }
    if (frameSize <= 0 || (frameSize & (frameSize - 1)) != 0) {
      throw ArgumentError.value(frameSize, 'frameSize', 'must be a power of 2');
    }
    if (hopSize <= 0 || hopSize > frameSize) {
      throw ArgumentError.value(hopSize, 'hopSize');
    }
    if (bandCount <= 0) {
      throw ArgumentError.value(bandCount, 'bandCount');
    }
    if (minFrequency <= 0 || maxFrequency <= minFrequency) {
      throw ArgumentError.value(maxFrequency, 'maxFrequency');
    }
    if (maxFrequency > sampleRate / 2) {
      throw ArgumentError.value(maxFrequency, 'maxFrequency');
    }
  }
}

class AudioFeatureSequence {
  final List<Float64List> frames;
  final AudioFeatureExtractorOptions options;

  const AudioFeatureSequence({
    required this.frames,
    required this.options,
  });

  int get length => frames.length;

  Duration timeOfFrame(int frameIndex) {
    final seconds = frameIndex * options.hopSize / options.sampleRate;
    return Duration(
        microseconds: (seconds * Duration.microsecondsPerSecond).round());
  }
}

class AudioSlidingMatchOptions {
  final int stepFrames;

  const AudioSlidingMatchOptions({
    this.stepFrames = 1,
  });

  void validate() {
    if (stepFrames <= 0) {
      throw ArgumentError.value(stepFrames, 'stepFrames');
    }
  }
}

class AudioSlidingMatchResult {
  final int offsetFrames;
  final Duration offset;
  final double score;
  final double secondBestScore;
  final int comparedFrames;

  const AudioSlidingMatchResult({
    required this.offsetFrames,
    required this.offset,
    required this.score,
    required this.secondBestScore,
    required this.comparedFrames,
  });

  double get margin => score - secondBestScore;

  double get confidence {
    final clampedScore = score.clamp(0.0, 1.0);
    final clampedMargin = margin.clamp(0.0, 1.0);
    return (clampedScore * 0.7 + clampedMargin * 3.0).clamp(0.0, 1.0);
  }

  @override
  String toString() {
    return 'AudioSlidingMatchResult(offset: $offset, score: $score, '
        'secondBestScore: $secondBestScore, comparedFrames: $comparedFrames)';
  }
}

class AudioFeatureExtractor {
  final AudioFeatureExtractorOptions options;
  late final Float64List _window;
  late final List<_BandRange> _bands;

  AudioFeatureExtractor({
    this.options = const AudioFeatureExtractorOptions(),
  }) {
    options.validate();
    _window = _buildHannWindow(options.frameSize);
    _bands = _buildBands(options);
  }

  AudioFeatureSequence extractFromPcm16Bytes(
    Uint8List bytes, {
    Endian endian = Endian.little,
  }) {
    final sampleCount = bytes.length ~/ Int16List.bytesPerElement;
    final data = ByteData.sublistView(bytes);
    final samples = Float64List(sampleCount);
    for (var i = 0; i < sampleCount; i++) {
      samples[i] =
          data.getInt16(i * Int16List.bytesPerElement, endian) / 32768.0;
    }
    return extractFromSamples(samples);
  }

  AudioFeatureSequence extractFromPcm16Samples(Int16List pcm) {
    final samples = Float64List(pcm.length);
    for (var i = 0; i < pcm.length; i++) {
      samples[i] = pcm[i] / 32768.0;
    }
    return extractFromSamples(samples);
  }

  AudioFeatureSequence extractFromSamples(List<double> samples) {
    if (samples.length < options.frameSize) {
      return AudioFeatureSequence(frames: const [], options: options);
    }

    final frames = <Float64List>[];
    final real = Float64List(options.frameSize);
    final imag = Float64List(options.frameSize);

    for (var start = 0;
        start + options.frameSize <= samples.length;
        start += options.hopSize) {
      for (var i = 0; i < options.frameSize; i++) {
        real[i] = samples[start + i] * _window[i];
        imag[i] = 0;
      }

      _fft(real, imag);
      final features = Float64List(options.bandCount);
      for (var bandIndex = 0; bandIndex < _bands.length; bandIndex++) {
        final band = _bands[bandIndex];
        var sum = 0.0;
        var count = 0;
        for (var bin = band.startBin; bin <= band.endBin; bin++) {
          final power = real[bin] * real[bin] + imag[bin] * imag[bin];
          sum += power;
          count++;
        }
        features[bandIndex] = log(1 + sum / max(count, 1));
      }
      _normalizeInPlace(features);
      frames.add(features);
    }

    return AudioFeatureSequence(frames: frames, options: options);
  }

  static Float64List _buildHannWindow(int size) {
    final window = Float64List(size);
    for (var i = 0; i < size; i++) {
      window[i] = 0.5 - 0.5 * cos(2 * pi * i / (size - 1));
    }
    return window;
  }

  static List<_BandRange> _buildBands(AudioFeatureExtractorOptions options) {
    final bands = <_BandRange>[];
    final nyquist = options.sampleRate / 2;
    final maxBin = options.frameSize ~/ 2;
    final minLog = log(options.minFrequency);
    final maxLog = log(min(options.maxFrequency, nyquist));

    var previousEnd = 1;
    for (var i = 0; i < options.bandCount; i++) {
      final startFreq = exp(minLog + (maxLog - minLog) * i / options.bandCount);
      final endFreq =
          exp(minLog + (maxLog - minLog) * (i + 1) / options.bandCount);
      final startBin = max(previousEnd,
          (startFreq * options.frameSize / options.sampleRate).floor());
      final endBin = max(
          startBin,
          min(maxBin,
              (endFreq * options.frameSize / options.sampleRate).ceil()));
      bands.add(_BandRange(startBin, endBin));
      previousEnd = endBin + 1;
    }
    return bands;
  }

  static void _normalizeInPlace(Float64List values) {
    var mean = 0.0;
    for (final value in values) {
      mean += value;
    }
    mean /= values.length;

    var variance = 0.0;
    for (final value in values) {
      final centered = value - mean;
      variance += centered * centered;
    }
    final stdDev = sqrt(variance / values.length);
    if (stdDev < 1e-8) {
      for (var i = 0; i < values.length; i++) {
        values[i] = 0;
      }
      return;
    }

    var norm = 0.0;
    for (var i = 0; i < values.length; i++) {
      values[i] = (values[i] - mean) / stdDev;
      norm += values[i] * values[i];
    }
    norm = sqrt(norm);
    if (norm < 1e-8) return;
    for (var i = 0; i < values.length; i++) {
      values[i] /= norm;
    }
  }

  static void _fft(Float64List real, Float64List imag) {
    final n = real.length;
    var j = 0;
    for (var i = 1; i < n; i++) {
      var bit = n >> 1;
      while ((j & bit) != 0) {
        j ^= bit;
        bit >>= 1;
      }
      j ^= bit;
      if (i < j) {
        final tempReal = real[i];
        final tempImag = imag[i];
        real[i] = real[j];
        imag[i] = imag[j];
        real[j] = tempReal;
        imag[j] = tempImag;
      }
    }

    for (var len = 2; len <= n; len <<= 1) {
      final angle = -2 * pi / len;
      final wLenReal = cos(angle);
      final wLenImag = sin(angle);
      for (var i = 0; i < n; i += len) {
        var wReal = 1.0;
        var wImag = 0.0;
        for (var k = 0; k < len ~/ 2; k++) {
          final uReal = real[i + k];
          final uImag = imag[i + k];
          final vReal =
              real[i + k + len ~/ 2] * wReal - imag[i + k + len ~/ 2] * wImag;
          final vImag =
              real[i + k + len ~/ 2] * wImag + imag[i + k + len ~/ 2] * wReal;

          real[i + k] = uReal + vReal;
          imag[i + k] = uImag + vImag;
          real[i + k + len ~/ 2] = uReal - vReal;
          imag[i + k + len ~/ 2] = uImag - vImag;

          final nextWReal = wReal * wLenReal - wImag * wLenImag;
          wImag = wReal * wLenImag + wImag * wLenReal;
          wReal = nextWReal;
        }
      }
    }
  }
}

class AudioSlidingMatcher {
  final AudioSlidingMatchOptions options;

  const AudioSlidingMatcher({
    this.options = const AudioSlidingMatchOptions(),
  });

  AudioSlidingMatchResult findBestMatch(
    AudioFeatureSequence template,
    AudioFeatureSequence search,
  ) {
    options.validate();
    if (template.frames.isEmpty) {
      throw ArgumentError.value(
          template.frames.length, 'template', 'has no feature frames');
    }
    if (template.frames.length > search.frames.length) {
      throw ArgumentError.value(
          search.frames.length, 'search', 'shorter than template');
    }
    if (template.options.hopSize != search.options.hopSize ||
        template.options.sampleRate != search.options.sampleRate) {
      throw ArgumentError(
          'template and search must use the same sample rate and hop size');
    }

    var bestScore = double.negativeInfinity;
    var secondBestScore = double.negativeInfinity;
    var bestOffset = 0;
    final maxOffset = search.frames.length - template.frames.length;

    for (var offset = 0; offset <= maxOffset; offset += options.stepFrames) {
      final score = _scoreAtOffset(template.frames, search.frames, offset);
      if (score > bestScore) {
        if ((offset - bestOffset).abs() > template.frames.length ~/ 4) {
          secondBestScore = bestScore;
        }
        bestScore = score;
        bestOffset = offset;
      } else if ((offset - bestOffset).abs() > template.frames.length ~/ 4 &&
          score > secondBestScore) {
        secondBestScore = score;
      }
    }

    if (secondBestScore == double.negativeInfinity) {
      secondBestScore = bestScore;
    }

    return AudioSlidingMatchResult(
      offsetFrames: bestOffset,
      offset: search.timeOfFrame(bestOffset),
      score: bestScore,
      secondBestScore: secondBestScore,
      comparedFrames: template.frames.length,
    );
  }

  static double _scoreAtOffset(
    List<Float64List> template,
    List<Float64List> search,
    int offset,
  ) {
    var sum = 0.0;
    var count = 0;
    for (var i = 0; i < template.length; i++) {
      final a = template[i];
      final b = search[offset + i];
      var dot = 0.0;
      for (var j = 0; j < a.length; j++) {
        dot += a[j] * b[j];
      }
      sum += dot;
      count++;
    }
    return sum / count;
  }
}

class _BandRange {
  final int startBin;
  final int endBin;

  const _BandRange(this.startBin, this.endBin);
}
