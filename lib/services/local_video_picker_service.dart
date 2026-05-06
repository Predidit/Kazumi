import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:kazumi/modules/playback/playback_source.dart';
import 'package:path/path.dart' as p;

class LocalVideoPickerService {
  Future<LocalVideoPlaybackContext?> pickVideo() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.video,
      allowMultiple: false,
      withData: false,
    );
    if (result == null || result.files.isEmpty) {
      return null;
    }

    final path = result.files.single.path;
    if (path == null || path.isEmpty) {
      return null;
    }

    return buildContext(path);
  }

  LocalVideoPlaybackContext buildContext(String path) {
    final file = File(path);
    final fileName = p.basename(path);
    final title = p.basenameWithoutExtension(path);
    FileStat? stat;
    try {
      stat = file.statSync();
    } catch (_) {
      stat = null;
    }

    return LocalVideoPlaybackContext(
      path: path,
      title: title.isEmpty ? '本地视频' : title,
      fileName: fileName,
      fileSize: stat?.size ?? 0,
      lastModified: stat?.modified,
    );
  }
}
