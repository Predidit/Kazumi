import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:kazumi/services/player/screenshot_candidate.dart';
import 'package:path/path.dart' as path;
import 'package:saver_gallery/saver_gallery.dart';

enum _ScreenshotDestination {
  gallery('相册'),
  directory('所选位置');

  const _ScreenshotDestination(this.label);
  final String label;
}

class ScreenshotExportService {
  const ScreenshotExportService();

  _ScreenshotDestination get _destination =>
      Platform.isAndroid || Platform.isIOS || Platform.operatingSystem == 'ohos'
      ? _ScreenshotDestination.gallery
      : _ScreenshotDestination.directory;

  String get destinationLabel => _destination.label;

  Future<String?> chooseDestination() async {
    if (_destination == _ScreenshotDestination.directory) {
      return FilePicker.platform.getDirectoryPath(
        dialogTitle: '选择截图保存文件夹',
        lockParentWindow: true,
      );
    }
    return _destination.name;
  }

  Future<void> write(ScreenshotCandidate item, String location) async {
    final name = _fileName(item);
    switch (_destination) {
      case _ScreenshotDestination.gallery:
        final result = await SaverGallery.saveImage(
          item.bytes,
          fileName: name,
          extension: 'png',
          androidRelativePath: 'Pictures/Kazumi',
          skipIfExists: false,
        );
        if (!result.isSuccess) {
          throw StateError(result.errorMessage ?? 'Gallery save failed');
        }
        return;
      case _ScreenshotDestination.directory:
        var file = File(path.join(location, name));
        var suffix = 1;
        while (await file.exists()) {
          file = File(
            path.join(
              location,
              '${path.basenameWithoutExtension(name)}_${suffix++}.png',
            ),
          );
        }
        await file.writeAsBytes(item.bytes, flush: true);
    }
  }

  static String _fileName(ScreenshotCandidate item) {
    String clean(String value) {
      final safe = value
          .replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1f]'), '_')
          .trim()
          .replaceAll(RegExp(r'[. ]+$'), '');
      // Leave room for the ID within common 255-byte filename limits.
      return String.fromCharCodes(safe.runes.take(24));
    }

    return 'Kazumi_${clean(item.title)}_${clean(item.episode)}_'
        '${item.timeLabel.replaceAll(':', '-')}_${item.id}.png';
  }
}
