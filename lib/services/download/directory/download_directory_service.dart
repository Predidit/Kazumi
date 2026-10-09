import 'dart:io';

import 'package:kazumi/services/download/directory/android_download_directory_service.dart';
import 'package:kazumi/services/download/directory/local_download_directory_service.dart';
import 'package:kazumi/services/download/directory/macos_download_directory_service.dart';
import 'package:kazumi/services/storage/storage.dart';
import 'package:kazumi/utils/file_system.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

class DownloadDirectoryException implements Exception {
  const DownloadDirectoryException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Shared directory policy. Platform implementations own picking and access;
/// downloads continue to use filesystem paths, including for resume/playback.
abstract class DownloadDirectoryService {
  static final DownloadDirectoryService instance = create();

  static DownloadDirectoryService create() {
    if (Platform.isAndroid) return AndroidDownloadDirectoryService();
    if (Platform.isMacOS) return MacOSDownloadDirectoryService();
    if (Platform.isWindows) return LocalDownloadDirectoryService();
    return DefaultDownloadDirectoryService();
  }

  bool get supportsCustomDirectory;
  String? get selectionHint => null;

  String get customDirectory =>
      GStorage.getSetting(SettingsKeys.downloadDirectory).trim();

  Future<void> saveCustomDirectory(String directory) =>
      GStorage.putSetting(SettingsKeys.downloadDirectory, directory);

  Future<String> getDefaultDirectory() async {
    final support = await getApplicationSupportDirectory();
    return path.join(support.path, 'downloads');
  }

  Future<String?> pickDirectory(String? initialDirectory);

  /// Also called for recorded episode directories before resuming a download.
  /// Never opens a permission dialog during a background download.
  Future<String?> restoreAccess(String directory);

  Future<void> persistAccess(String directory) async {}
  Future<void> clearCustomAccess() async {}

  Future<String> getDownloadDirectory() async {
    final configured = customDirectory;
    if (!supportsCustomDirectory || configured.isEmpty) {
      return getDefaultDirectory();
    }
    return requireAccess(configured);
  }

  Future<String> requireAccess(String directory) async {
    final usable = await restoreAccess(directory);
    if (usable == null) {
      throw const DownloadDirectoryException('下载位置访问权限失效，请在下载设置中重新选择目录或恢复默认位置');
    }
    return usable;
  }

  /// Save only after selection, write verification and persistent access succeed.
  Future<String?> selectAndSaveDirectory() async {
    if (!supportsCustomDirectory) {
      throw const DownloadDirectoryException('当前平台不支持手动选择目录');
    }
    final configured = customDirectory;
    final initial = configured.isEmpty
        ? await getDefaultDirectory()
        : configured;
    final selected = await pickDirectory(
      await Directory(initial).exists() ? initial : null,
    );
    if (selected == null || selected.isEmpty) return null;
    if (!path.isAbsolute(selected) || selected.startsWith('content://')) {
      throw const DownloadDirectoryException('请选择设备上的本地文件夹');
    }
    await ensureDirectoryWritable(selected);
    await persistAccess(selected);
    await saveCustomDirectory(selected);
    return selected;
  }

  Future<void> resetDirectory() async {
    await clearCustomAccess();
    await saveCustomDirectory('');
  }
}
