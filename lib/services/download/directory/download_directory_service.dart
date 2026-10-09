import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:kazumi/services/logging/logger.dart';
import 'package:kazumi/services/storage/storage.dart';
import 'package:kazumi/utils/file_system.dart';
import 'package:macos_secure_bookmarks/macos_secure_bookmarks.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

class DownloadDirectoryException implements Exception {
  const DownloadDirectoryException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Downloads use filesystem paths for downloading, resuming and local playback.
class DownloadDirectoryService {
  static final DownloadDirectoryService _instance =
      DownloadDirectoryService._internal();
  factory DownloadDirectoryService() => _instance;
  DownloadDirectoryService._internal();

  static const _androidChannel = MethodChannel(
    'com.predidit.kazumi/download_directory',
  );
  final _bookmarks = SecureBookmarks();
  String _accessedPath = '';

  bool get supportsCustomDirectory =>
      Platform.isAndroid || Platform.isMacOS || Platform.isWindows;

  String get customDirectory =>
      GStorage.getSetting(SettingsKeys.downloadDirectory).trim();

  Future<void> saveCustomDirectory(String directory) =>
      GStorage.putSetting(SettingsKeys.downloadDirectory, directory);

  Future<String> getDefaultDirectory() async {
    final support = await getApplicationSupportDirectory();
    return path.join(support.path, 'downloads');
  }

  Future<String?> pickDirectory(String? initialDirectory) async {
    if (Platform.isAndroid) {
      // A SAF URI grant alone does not grant direct filesystem access.
      final granted =
          await _androidChannel.invokeMethod<bool>('requestStorageAccess') ??
          false;
      if (!granted) {
        throw const DownloadDirectoryException('未授予存储访问权限，下载位置未修改');
      }
      return _androidChannel.invokeMethod<String>('pickDirectory', {
        'initialDirectory': initialDirectory,
      });
    }
    if (Platform.isMacOS || Platform.isWindows) {
      return FilePicker.platform.getDirectoryPath(
        dialogTitle: '选择下载位置',
        initialDirectory: initialDirectory,
      );
    }
    return null;
  }

  /// Also called for recorded episode directories before resuming a download.
  /// Never opens a permission dialog during a background download.
  Future<String?> restoreAccess(String directory) async {
    if (Platform.isAndroid) {
      final accessible =
          await _androidChannel.invokeMethod<bool>('hasDirectoryAccess', {
            'path': directory,
          }) ??
          false;
      return accessible ? directory : null;
    }
    if (Platform.isMacOS) return _restoreMacOSAccess(directory);
    return directory;
  }

  Future<void> persistAccess(String directory) async {
    if (!Platform.isMacOS) return;
    try {
      final bookmark = await _bookmarks.bookmark(Directory(directory));
      await GStorage.putSetting(
        SettingsKeys.downloadDirectoryBookmark,
        bookmark,
      );
      // The picker grant already covers this session.
      _accessedPath = directory;
    } catch (_) {
      throw const DownloadDirectoryException('无法获得该目录的持久访问权限，请更换目录');
    }
  }

  Future<void> clearCustomAccess() async {
    if (Platform.isMacOS) {
      await GStorage.putSetting(SettingsKeys.downloadDirectoryBookmark, '');
      _accessedPath = '';
    }
  }

  Future<String?> _restoreMacOSAccess(String directory) async {
    if (_accessedPath.isNotEmpty && _contains(_accessedPath, directory)) {
      return directory;
    }
    final defaultDirectory = await getDefaultDirectory();
    if (_contains(defaultDirectory, directory)) return directory;
    final configured = customDirectory;
    if (configured.isEmpty || !_contains(configured, directory)) {
      return directory;
    }
    final bookmark = GStorage.getSetting(
      SettingsKeys.downloadDirectoryBookmark,
    );
    if (bookmark.isEmpty) return null;
    try {
      final entity = await _bookmarks.resolveBookmark(bookmark);
      if (!await _bookmarks.startAccessingSecurityScopedResource(entity)) {
        return null;
      }
      _accessedPath = entity.path;
      // Preserve bookmark resolution for the configured root. Recorded episode
      // paths stay unchanged and must be covered by the restored grant.
      if (path.equals(directory, configured)) return entity.path;
      return _contains(entity.path, directory) ? directory : null;
    } catch (e) {
      KazumiLogger().e(
        'DownloadDirectoryService: failed to restore access to $directory',
        error: e,
      );
      return null;
    }
  }

  bool _contains(String root, String directory) =>
      path.equals(root, directory) || path.isWithin(root, directory);

  Future<String> getDownloadDirectory() async {
    final configured = customDirectory;
    if (!supportsCustomDirectory || configured.isEmpty) {
      return getDefaultDirectory();
    }
    if (Platform.isMacOS) {
      final usable = await restoreAccess(configured);
      if (usable != null) return usable;
      KazumiLogger().w(
        'DownloadDirectoryService: custom download directory unavailable, falling back to default',
      );
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
    if (!path.isAbsolute(selected)) {
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
