import 'package:kazumi/services/logging/logger.dart';

typedef WebDavRemoveRemoteFile = Future<void> Function(String path);
typedef WebDavUploadRemoteFile = Future<void> Function(
  String sourceFilePath,
  String remotePath,
);
typedef WebDavRenameRemoteFile = Future<void> Function(
  String sourcePath,
  String destinationPath,
);

class WebDavRemoteFileCommitter {
  const WebDavRemoteFileCommitter();

  Future<void> replaceFile({
    required String sourceFilePath,
    required String temporaryPath,
    required String destinationPath,
    required WebDavRemoveRemoteFile remove,
    required WebDavUploadRemoteFile uploadFromFile,
    required WebDavRenameRemoteFile rename,
  }) async {
    await remove(temporaryPath);
    try {
      await uploadFromFile(sourceFilePath, temporaryPath);
      await remove(destinationPath);
      await rename(temporaryPath, destinationPath);
    } catch (_) {
      try {
        await remove(temporaryPath);
      } catch (error, stackTrace) {
        KazumiLogger().w(
          'WebDav: failed to clean temporary remote file',
          error: error,
          stackTrace: stackTrace,
        );
      }
      rethrow;
    }
  }
}
