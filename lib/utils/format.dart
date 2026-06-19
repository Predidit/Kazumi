String formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  if (bytes < 1024 * 1024 * 1024) {
    return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
  }
  return '${(bytes / 1024 / 1024 / 1024).toStringAsFixed(1)} GB';
}

String formatSpeed(double bytesPerSec) {
  if (bytesPerSec < 1024) return '${bytesPerSec.toStringAsFixed(0)} B/s';
  if (bytesPerSec < 1024 * 1024) {
    return '${(bytesPerSec / 1024).toStringAsFixed(1)} KB/s';
  }
  return '${(bytesPerSec / 1024 / 1024).toStringAsFixed(1)} MB/s';
}

String durationToString(Duration duration) {
  String pad(int n) => n.toString().padLeft(2, '0');
  final hours = pad(duration.inHours % 24);
  final minutes = pad(duration.inMinutes % 60);
  final seconds = pad(duration.inSeconds % 60);
  if (hours == '00') {
    return '$minutes:$seconds';
  }
  return '$hours:$minutes:$seconds';
}

String formatTraceSimilarity(
  double? similarity, {
  int fractionDigits = 1,
  String empty = '--',
}) {
  if (similarity == null) {
    return empty;
  }
  return '${(similarity * 100).toStringAsFixed(fractionDigits)}%';
}
