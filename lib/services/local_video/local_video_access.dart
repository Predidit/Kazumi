import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:kazumi/services/logging/logger.dart';
import 'package:macos_secure_bookmarks/macos_secure_bookmarks.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'local_video_store.dart';

class LocalVideoAccess {
  static const channel = MethodChannel('com.predidit.kazumi/local_video');
  static Future<void>? _preparation;

  /// Finish recovery before any picker can create an unrecorded import.
  static Future<void> prepare() => _preparation ??= _cleanUnusedImports();

  static Future<void> _cleanUnusedImports() async {
    try {
      final store = await LocalVideoStore.open();
      final kept = store.records
          .map((record) => record.reference.ownedPath)
          .whereType<String>()
          .map(p.basename)
          .toSet();
      final directory = Directory(
        p.join((await getApplicationSupportDirectory()).path, 'local_videos'),
      );
      if (await FileSystemEntity.type(directory.path, followLinks: false) !=
          FileSystemEntityType.directory) {
        return;
      }
      await for (final entry in directory.list(followLinks: false)) {
        if (entry is File && !kept.contains(p.basename(entry.path))) {
          try {
            await entry.delete();
          } catch (error) {
            KazumiLogger().w(
              'LocalVideoAccess: unused import cleanup failed',
              error: error,
            );
          }
        }
      }
    } catch (error) {
      KazumiLogger().w(
        'LocalVideoAccess: import recovery failed',
        error: error,
      );
    }
    // Do not retry this process: a later import may be active but not saved yet.
  }

  static const extensions = [
    'mp4',
    'mkv',
    'mov',
    'avi',
    'webm',
    'm4v',
    'ts',
    'flv',
    'wmv',
    'mpeg',
    'mpg',
  ];
  bool cancelled = false;
  Future<void> cancel() async {
    cancelled = true;
    if (Platform.isAndroid || Platform.isIOS) {
      await channel.invokeMethod<void>('cancel');
    }
  }

  Future<LocalVideoReference?> pick() async {
    await prepare();
    if (cancelled) return null;
    LocalVideoReference? reference;
    if (Platform.isAndroid || Platform.isIOS) {
      final map = await channel.invokeMapMethod<String, dynamic>('pick');
      if (map != null) reference = LocalVideoReference.fromMap(map);
    } else {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: extensions,
        allowMultiple: false,
        withData: false,
      );
      final path = result?.files.single.path;
      if (path != null) reference = await fromPath(path);
    }
    if (reference == null) return null;
    if (cancelled) {
      await releaseUnused(reference);
      return null;
    }
    return reference;
  }

  static Future<LocalVideoReference> fromPath(
    String path, {
    String? bookmark,
  }) async {
    if (!extensions.contains(
      p.extension(path).toLowerCase().replaceFirst('.', ''),
    )) {
      throw const FileSystemException('请选择支持的视频文件');
    }
    File? scopedFile;
    final bookmarks = SecureBookmarks();
    if (Platform.isMacOS && bookmark != null) {
      final resolved = await bookmarks.resolveBookmark(bookmark) as File;
      if (!await bookmarks.startAccessingSecurityScopedResource(resolved)) {
        throw const FileSystemException('文件授权已失效');
      }
      scopedFile = resolved;
    }
    try {
      final file = File(
        await (scopedFile ?? File(path)).resolveSymbolicLinks(),
      );
      final stat = await file.stat();
      if (stat.type != FileSystemEntityType.file || stat.size <= 0) {
        throw const FileSystemException('视频文件为空或不可访问');
      }
      return LocalVideoReference(
        source: file.path,
        name: p.basename(file.path),
        location: p.basename(file.parent.path),
        size: stat.size,
        modifiedMs: stat.modified.millisecondsSinceEpoch,
        bookmark: Platform.isMacOS
            ? bookmark ?? await bookmarks.bookmark(file)
            : null,
      );
    } finally {
      if (scopedFile != null) {
        await bookmarks.stopAccessingSecurityScopedResource(scopedFile);
      }
    }
  }

  static Future<OpenedLocalVideo> open(LocalVideoReference reference) async {
    if (Platform.isAndroid) {
      final map = await channel.invokeMapMethod<String, dynamic>('inspect', {
        'source': reference.source,
      });
      if (map == null) throw const FileSystemException('文件不可访问');
      final current = LocalVideoReference.fromMap(map);
      return OpenedLocalVideo(current, reference.source, () async {});
    }
    File file;
    Future<void> Function() close = () async {};
    if (Platform.isMacOS) {
      if (reference.bookmark == null) {
        throw const FileSystemException('文件授权已失效');
      }
      final bookmarks = SecureBookmarks();
      file = await bookmarks.resolveBookmark(reference.bookmark!) as File;
      if (!await bookmarks.startAccessingSecurityScopedResource(file)) {
        throw const FileSystemException('文件授权已失效');
      }
      close = () async {
        await bookmarks.stopAccessingSecurityScopedResource(file);
      };
    } else if (reference.ownedPath != null) {
      file = File(
        p.join(
          (await getApplicationSupportDirectory()).path,
          'local_videos',
          p.basename(reference.ownedPath!),
        ),
      );
    } else {
      file = File(reference.source);
    }
    try {
      final stat = await file.stat();
      if (stat.type != FileSystemEntityType.file || stat.size <= 0) {
        throw const FileSystemException('视频文件为空或不可访问');
      }
      final handle = await file.open();
      try {
        if ((await handle.read(1)).isEmpty) {
          throw const FileSystemException('视频文件为空');
        }
      } finally {
        await handle.close();
      }
      final current = LocalVideoReference(
        source: reference.source,
        name: reference.name,
        location: reference.location,
        size: stat.size,
        modifiedMs: stat.modified.millisecondsSinceEpoch,
        bookmark: reference.bookmark,
        ownedPath: reference.ownedPath,
      );
      return OpenedLocalVideo(current, file.path, close);
    } catch (_) {
      await close();
      rethrow;
    }
  }

  static Future<void> releaseUnused(LocalVideoReference reference) async {
    final store = await LocalVideoStore.open();
    if (!store.records.any(
      (r) =>
          r.reference.source == reference.source &&
          r.reference.ownedPath == reference.ownedPath,
    )) {
      await release(reference);
    }
  }

  /// Only app-owned imports and our individual document grants are removed.
  static Future<void> release(LocalVideoReference reference) async {
    if (Platform.isAndroid) {
      await channel.invokeMethod<void>('release', {'source': reference.source});
    }
    if (Platform.isIOS && reference.ownedPath != null) {
      final file = File(
        p.join(
          (await getApplicationSupportDirectory()).path,
          'local_videos',
          p.basename(reference.ownedPath!),
        ),
      );
      if (await file.exists()) await file.delete();
    }
  }
}

class OpenedLocalVideo {
  OpenedLocalVideo(this.reference, this.url, this._close);
  final LocalVideoReference reference;
  final String url;
  final Future<void> Function() _close;
  bool _closed = false;
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await _close();
  }
}
