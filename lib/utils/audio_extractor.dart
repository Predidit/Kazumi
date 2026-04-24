import 'dart:async';
import 'dart:io';

class AudioExtractRequest {
  final String input;
  final String outputPath;
  final Map<String, String> httpHeaders;
  final Duration start;
  final Duration duration;
  final int sampleRate;
  final int channels;
  final Duration timeout;

  const AudioExtractRequest({
    required this.input,
    required this.outputPath,
    this.httpHeaders = const {},
    this.start = Duration.zero,
    this.duration = const Duration(seconds: 45),
    this.sampleRate = 16000,
    this.channels = 1,
    this.timeout = const Duration(seconds: 90),
  });

  void validate() {
    if (input.isEmpty) {
      throw ArgumentError.value(input, 'input');
    }
    if (outputPath.isEmpty) {
      throw ArgumentError.value(outputPath, 'outputPath');
    }
    if (start.isNegative) {
      throw ArgumentError.value(start, 'start');
    }
    if (duration <= Duration.zero) {
      throw ArgumentError.value(duration, 'duration');
    }
    if (sampleRate <= 0) {
      throw ArgumentError.value(sampleRate, 'sampleRate');
    }
    if (channels <= 0) {
      throw ArgumentError.value(channels, 'channels');
    }
    if (timeout <= Duration.zero) {
      throw ArgumentError.value(timeout, 'timeout');
    }
  }
}

class AudioExtractResult {
  final String outputPath;
  final int outputBytes;
  final Duration start;
  final Duration duration;
  final int sampleRate;
  final int channels;

  const AudioExtractResult({
    required this.outputPath,
    required this.outputBytes,
    required this.start,
    required this.duration,
    required this.sampleRate,
    required this.channels,
  });
}

class AudioExtractException implements Exception {
  final String message;
  final Object? cause;

  const AudioExtractException(this.message, {this.cause});

  @override
  String toString() {
    if (cause == null) return 'AudioExtractException: $message';
    return 'AudioExtractException: $message ($cause)';
  }
}

abstract class IAudioExtractor {
  Future<AudioExtractResult> extractPcm16(AudioExtractRequest request);
}

typedef FfmpegProcessRunner = Future<ProcessResult> Function(
  String executable,
  List<String> arguments,
);

class FfmpegAudioExtractor implements IAudioExtractor {
  final String executable;
  final FfmpegProcessRunner _processRunner;

  FfmpegAudioExtractor({
    this.executable = 'ffmpeg',
    FfmpegProcessRunner? processRunner,
  }) : _processRunner = processRunner ?? Process.run;

  @override
  Future<AudioExtractResult> extractPcm16(AudioExtractRequest request) async {
    request.validate();

    final outputFile = File(request.outputPath);
    await outputFile.parent.create(recursive: true);
    if (await outputFile.exists()) {
      await outputFile.delete();
    }

    final args = buildArguments(request);
    ProcessResult result;
    try {
      result = await _processRunner(executable, args).timeout(request.timeout);
    } on TimeoutException catch (e) {
      await _deletePartialOutput(outputFile);
      throw AudioExtractException('音频抽取超时', cause: e);
    } on ProcessException catch (e) {
      await _deletePartialOutput(outputFile);
      throw AudioExtractException('无法启动 ffmpeg，请确认 ffmpeg 已安装或已随应用打包',
          cause: e);
    }

    if (result.exitCode != 0) {
      await _deletePartialOutput(outputFile);
      final stderr = result.stderr.toString().trim();
      throw AudioExtractException(
        stderr.isEmpty ? 'ffmpeg 音频抽取失败' : stderr,
      );
    }

    if (!await outputFile.exists()) {
      throw const AudioExtractException('ffmpeg 未生成音频输出文件');
    }

    final outputBytes = await outputFile.length();
    if (outputBytes == 0) {
      await _deletePartialOutput(outputFile);
      throw const AudioExtractException('ffmpeg 生成了空音频文件');
    }

    return AudioExtractResult(
      outputPath: request.outputPath,
      outputBytes: outputBytes,
      start: request.start,
      duration: request.duration,
      sampleRate: request.sampleRate,
      channels: request.channels,
    );
  }

  List<String> buildArguments(AudioExtractRequest request) {
    request.validate();

    return [
      '-hide_banner',
      '-nostdin',
      '-loglevel',
      'error',
      '-y',
      '-ss',
      _formatDuration(request.start),
      '-t',
      _formatDuration(request.duration),
      if (_shouldAttachHeaders(request.input, request.httpHeaders)) ...[
        '-headers',
        _formatHeaders(request.httpHeaders),
      ],
      '-i',
      request.input,
      '-map',
      '0:a:0',
      '-vn',
      '-sn',
      '-dn',
      '-ac',
      request.channels.toString(),
      '-ar',
      request.sampleRate.toString(),
      '-f',
      's16le',
      request.outputPath,
    ];
  }

  static String _formatHeaders(Map<String, String> headers) {
    final buffer = StringBuffer();
    for (final entry in headers.entries) {
      if (entry.key.isEmpty || entry.value.isEmpty) continue;
      buffer.write(entry.key);
      buffer.write(': ');
      buffer.write(entry.value);
      buffer.write('\r\n');
    }
    return buffer.toString();
  }

  static String _formatDuration(Duration duration) {
    final microseconds = duration.inMicroseconds;
    final seconds = microseconds / Duration.microsecondsPerSecond;
    return seconds.toStringAsFixed(3);
  }

  static bool _shouldAttachHeaders(
    String input,
    Map<String, String> headers,
  ) {
    if (headers.isEmpty) return false;
    final uri = Uri.tryParse(input);
    return uri != null && (uri.scheme == 'http' || uri.scheme == 'https');
  }

  static Future<void> _deletePartialOutput(File file) async {
    try {
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {}
  }
}
