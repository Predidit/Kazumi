import 'dart:io';

import 'package:kazumi/services/download/directory/download_directory_service.dart';
import 'package:kazumi/services/download/directory/local_download_directory_service.dart';
import 'package:kazumi/services/storage/storage.dart';
import 'package:macos_secure_bookmarks/macos_secure_bookmarks.dart';
import 'package:path/path.dart' as path;

class MacOSDownloadDirectoryService extends LocalDownloadDirectoryService {
  final _bookmarks = SecureBookmarks();
  final Set<String> _accessedRoots = {};
  final Map<String, String> _restoredRoots = {};

  @override
  Future<void> persistAccess(String directory) async {
    try {
      final bookmark = await _bookmarks.bookmark(Directory(directory));
      await GStorage.putSetting(
        SettingsKeys.downloadDirectoryBookmark,
        bookmark,
      );
      // Keep earlier picker grants alive for existing downloads this session.
      _accessedRoots.add(directory);
      _restoredRoots.remove(directory);
    } catch (_) {
      throw const DownloadDirectoryException('无法获得该目录的持久访问权限，请更换目录');
    }
  }

  @override
  Future<String?> restoreAccess(String directory) async {
    for (final entry in _restoredRoots.entries) {
      if (_contains(entry.key, directory)) {
        return path.normalize(
          path.join(entry.value, path.relative(directory, from: entry.key)),
        );
      }
    }
    final defaultDirectory = await getDefaultDirectory();
    if (_contains(defaultDirectory, directory) ||
        _accessedRoots.any((root) => _contains(root, directory))) {
      return directory;
    }
    final configured = customDirectory;
    if (configured.isEmpty) return directory;
    final withinConfiguredRoot = _contains(configured, directory);
    final bookmark = GStorage.getSetting(
      SettingsKeys.downloadDirectoryBookmark,
    );
    if (bookmark.isEmpty) return withinConfiguredRoot ? null : directory;
    final FileSystemEntity entity;
    try {
      entity = await _bookmarks.resolveBookmark(bookmark, isDirectory: true);
    } catch (_) {
      return withinConfiguredRoot ? null : directory;
    }
    // A previous session may have recorded the moved path while settings still
    // contain the original root. Resolve the bookmark before checking ownership.
    final withinResolvedRoot = _contains(entity.path, directory);
    if (!withinConfiguredRoot && !withinResolvedRoot) {
      // Episodes under unrelated roots must never be redirected to this root.
      return directory;
    }
    try {
      if (!await _bookmarks.startAccessingSecurityScopedResource(entity)) {
        return null;
      }
      _accessedRoots.add(entity.path);
      _restoredRoots[configured] = entity.path;
      if (withinResolvedRoot) return directory;
      return path.normalize(
        path.join(entity.path, path.relative(directory, from: configured)),
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> clearCustomAccess() =>
      GStorage.putSetting(SettingsKeys.downloadDirectoryBookmark, '');

  bool _contains(String root, String directory) =>
      path.equals(root, directory) || path.isWithin(root, directory);
}
