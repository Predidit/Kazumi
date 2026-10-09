import 'package:file_picker/file_picker.dart';
import 'package:kazumi/services/download/directory/download_directory_service.dart';

/// Filesystem access on Windows; also the common desktop picker for macOS.
class LocalDownloadDirectoryService extends DownloadDirectoryService {
  @override
  bool get supportsCustomDirectory => true;

  @override
  Future<String?> pickDirectory(String? initialDirectory) =>
      FilePicker.platform.getDirectoryPath(
        dialogTitle: '选择下载位置',
        initialDirectory: initialDirectory,
      );

  @override
  Future<String?> restoreAccess(String directory) async => directory;
}

/// iOS/Linux retain the app-owned default directory.
class DefaultDownloadDirectoryService extends DownloadDirectoryService {
  @override
  bool get supportsCustomDirectory => false;

  @override
  Future<String?> pickDirectory(String? initialDirectory) async => null;

  @override
  Future<String?> restoreAccess(String directory) async => directory;
}
