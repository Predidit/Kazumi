import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:kazumi/services/logging/logger.dart';
import 'package:kazumi/services/storage/storage.dart';
import 'package:kazumi/utils/async_single_flight.dart';
import 'package:kazumi/utils/file_system.dart';
import 'package:macos_secure_bookmarks/macos_secure_bookmarks.dart';
import 'package:path/path.dart' as path;

class DownloadDirectoryException implements Exception {
  const DownloadDirectoryException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Owns where downloads are stored and the platform access that location
/// needs. Downloads use plain filesystem paths for resume and playback.
class DownloadDirectoryService {
  static final DownloadDirectoryService _instance =
      DownloadDirectoryService._internal();
  factory DownloadDirectoryService() => _instance;
  DownloadDirectoryService._internal();

  static const _androidChannel = MethodChannel(
    'com.predidit.kazumi/download_directory',
  );
  final _bookmarks = SecureBookmarks();
  final _bookmarkRestore = AsyncSingleFlight<String?>();
  String? _grantedRoot;

  bool get supportsCustomDirectory =>
      Platform.isAndroid || Platform.isMacOS || Platform.isWindows;

  String get customDirectory =>
      GStorage.getSetting(SettingsKeys.downloadDirectory).trim();

  /// Root for new downloads. A custom directory that lost its access fails
  /// instead of silently redirecting downloads elsewhere.
  Future<String> getDownloadDirectory() async {
    final directory = supportsCustomDirectory ? customDirectory : '';
    if (directory.isEmpty) return getDefaultDownloadDirectory();
    await requireAccess(directory);
    return directory;
  }

  /// Never prompts, so it is safe to call from background downloads.
  Future<void> requireAccess(String directory) async {
    if (!await _hasAccess(directory)) {
      throw const DownloadDirectoryException('下载目录访问权限已失效，请在下载设置中重新选择该目录');
    }
  }

  /// Returns null when the user cancels. The directory is saved only after
  /// it proves writable and its access is persisted.
  Future<String?> selectDirectory() async {
    if (!supportsCustomDirectory) {
      throw const DownloadDirectoryException('当前平台不支持手动选择目录');
    }
    final current = customDirectory.isEmpty
        ? await getDefaultDownloadDirectory()
        : customDirectory;
    final selected = await _pickDirectory(
      await Directory(current).exists() ? current : null,
    );
    if (selected == null || selected.isEmpty) return null;
    await ensureDirectoryWritable(selected);
    await _persistAccess(selected);
    await GStorage.putSetting(SettingsKeys.downloadDirectory, selected);
    return selected;
  }

  Future<void> resetDirectory() async {
    await GStorage.putSetting(SettingsKeys.downloadDirectoryBookmark, '');
    await GStorage.putSetting(SettingsKeys.downloadDirectory, '');
  }

  Future<String?> _pickDirectory(String? initialDirectory) async {
    if (!Platform.isAndroid) {
      return FilePicker.platform.getDirectoryPath(
        dialogTitle: '选择下载位置',
        initialDirectory: initialDirectory,
      );
    }
    try {
      // A document tree grant alone does not allow direct file paths.
      final granted =
          await _androidChannel.invokeMethod<bool>('requestStorageAccess') ??
          false;
      if (!granted) {
        throw const DownloadDirectoryException('未授予存储访问权限，下载位置未修改');
      }
      return await _androidChannel.invokeMethod<String>('pickDirectory', {
        'initialDirectory': initialDirectory,
      });
    } on PlatformException catch (e) {
      throw DownloadDirectoryException(
        e.code == 'UNSUPPORTED_DIRECTORY'
            ? '请选择内部存储或 SD 卡中的本地文件夹'
            : '选择下载位置失败，请重试',
      );
    }
  }

  Future<void> _persistAccess(String directory) async {
    if (!Platform.isMacOS) return;
    final String bookmark;
    try {
      bookmark = await _bookmarks.bookmark(Directory(directory));
    } catch (e) {
      KazumiLogger().e(
        'DownloadDirectoryService: failed to bookmark $directory',
        error: e,
      );
      throw const DownloadDirectoryException('无法获得该目录的持久访问权限，请更换目录');
    }
    await GStorage.putSetting(SettingsKeys.downloadDirectoryBookmark, bookmark);
    // The picker grant covers the rest of this session.
    _grantedRoot = directory;
  }

  Future<bool> _hasAccess(String directory) async {
    // Only the macOS bookmark has to be restored on each launch. Elsewhere the
    // grant is obtained when the directory is picked, and losing it later
    // surfaces as an ordinary file system error.
    if (!Platform.isMacOS) return true;

    final custom = customDirectory;
    // Paths outside the custom directory are app-owned or left to the sandbox.
    if (custom.isEmpty || !_isWithin(custom, directory)) return true;
    _grantedRoot ??= await _bookmarkRestore.run(_restoreBookmark);
    final root = _grantedRoot;
    return root != null && _isWithin(root, directory);
  }

  Future<String?> _restoreBookmark() async {
    final bookmark = GStorage.getSetting(
      SettingsKeys.downloadDirectoryBookmark,
    );
    if (bookmark.isEmpty) return null;
    try {
      final entity = await _bookmarks.resolveBookmark(bookmark);
      return await _bookmarks.startAccessingSecurityScopedResource(entity)
          ? entity.path
          : null;
    } catch (e) {
      KazumiLogger().e(
        'DownloadDirectoryService: failed to restore bookmark access',
        error: e,
      );
      return null;
    }
  }

  bool _isWithin(String root, String directory) =>
      path.equals(root, directory) || path.isWithin(root, directory);
}
