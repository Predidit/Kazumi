import 'dart:typed_data';

class ScreenshotCandidate {
  const ScreenshotCandidate({
    required this.id,
    required this.bytes,
    required this.title,
    required this.episode,
    required this.position,
  });

  final String id;
  final Uint8List bytes;
  final String title;
  final String episode;
  final Duration position;

  String get timeLabel {
    String pad(int value) => value.toString().padLeft(2, '0');
    final hours = position.inHours;
    return '${hours > 0 ? '${pad(hours)}:' : ''}'
        '${pad(position.inMinutes % 60)}:${pad(position.inSeconds % 60)}';
  }
}
