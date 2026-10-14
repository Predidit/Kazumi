import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:kazumi/services/logging/logger.dart';
import 'package:kazumi/services/storage/storage.dart';
import 'package:kazumi/utils/file_system.dart';
import 'package:macos_secure_bookmarks/macos_secure_bookmarks.dart';
import 'package:path/path.dart' as path;

class DownloadDirectoryException implements Exception {
  const DownloadDirectoryException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Owns where downloads are stored. Access is settled when the directory is
/// picked and, on macOS, restored once per launch, so downloads, playback and
/// deletion all work with plain filesystem paths.
class DownloadDirectoryService {
  static final DownloadDirectoryService _instance =
      DownloadDirectoryService._internal();
  factory DownloadDirectoryService() => _instance;
  DownloadDirectoryService._internal();

  static const _androidChannel = MethodChannel(
    'com.predidit.kazumi/download_directory',
  );
  final _bookmarks = SecureBookmarks();
  bool _accessLost = false;

  bool get supportsCustomDirectory =>
      Platform.isAndroid || Platform.isMacOS || Platform.isWindows;

  /// Empty while the default directory is in use.
  String get customDirectory => supportsCustomDirectory
      ? GStorage.getSetting(SettingsKeys.downloadDirectory).trim()
      : '';

  /// Restores sandbox access to the custom directory before anything reads or
  /// writes downloads. Other platforms keep the access granted when picking.
  Future<void> restoreAccess() async {
    final directory = customDirectory;
    if (!Platform.isMacOS || directory.isEmpty) return;
    try {
      final restored = await _bookmarks.resolveBookmark(
        GStorage.getSetting(SettingsKeys.downloadDirectoryBookmark),
        isDirectory: true,
      );
      _accessLost =
          !await _bookmarks.startAccessingSecurityScopedResource(restored);
      // The bookmark follows the directory when the user moves it.
      if (!_accessLost && !path.equals(restored.path, directory)) {
        await GStorage.putSetting(
          SettingsKeys.downloadDirectory,
          restored.path,
        );
      }
    } catch (e) {
      _accessLost = true;
      KazumiLogger().e(
        'DownloadDirectoryService: failed to restore access to $directory',
        error: e,
      );
    }
  }

  /// Root for new downloads. A custom directory whose access could not be
  /// restored fails instead of silently redirecting downloads elsewhere.
  Future<String> getDownloadDirectory() async {
    final directory = customDirectory;
    if (directory.isEmpty) return getDefaultDownloadDirectory();
    if (_accessLost) {
      throw const DownloadDirectoryException('下载目录访问权限已失效，请在下载设置中重新选择该目录');
    }
    return directory;
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
    // The picker grant covers the rest of this session.
    _accessLost = false;
    return selected;
  }

  Future<void> resetDirectory() async {
    await GStorage.putSetting(SettingsKeys.downloadDirectoryBookmark, '');
    await GStorage.putSetting(SettingsKeys.downloadDirectory, '');
    _accessLost = false;
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
  }
}
