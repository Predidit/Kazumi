import 'package:flutter/services.dart';
import 'package:kazumi/services/download/directory/download_directory_service.dart';

/// Android shared storage needs direct filesystem access for segments, range
/// resume and local playback. A SAF URI grant alone does not grant File access.
class AndroidDownloadDirectoryService extends DownloadDirectoryService {
  static const _channel = MethodChannel(
    'com.predidit.kazumi/download_directory',
  );

  @override
  bool get supportsCustomDirectory => true;

  @override
  String get selectionHint => '选择本地文件夹前需要授予存储访问权限，Android 11 及以上需允许管理所有文件';

  @override
  Future<String?> pickDirectory(String? initialDirectory) async {
    final granted =
        await _channel.invokeMethod<bool>('requestStorageAccess') ?? false;
    if (!granted) {
      throw const DownloadDirectoryException('未授予存储访问权限，下载位置未修改');
    }
    return _channel.invokeMethod<String>('pickDirectory', {
      'initialDirectory': initialDirectory,
    });
  }

  @override
  Future<String?> restoreAccess(String directory) async {
    final accessible =
        await _channel.invokeMethod<bool>('hasDirectoryAccess', {
          'path': directory,
        }) ??
        false;
    return accessible ? directory : null;
  }
}
