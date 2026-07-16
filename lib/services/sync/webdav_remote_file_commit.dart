import 'dart:math';

typedef WebDavRemoveRemoteFile = Future<void> Function(String path);
typedef WebDavUploadRemoteFile = Future<void> Function(
  String sourceFilePath,
  String remotePath,
);
typedef WebDavRenameRemoteFile = Future<void> Function(
  String sourcePath,
  String destinationPath,
);
typedef WebDavRemoteEntryExists = Future<bool> Function(String path);
typedef WebDavVerifyRemoteFile = Future<void> Function(
  String sourceFilePath,
  String destinationPath,
);

class WebDavRemoteFileCommitter {
  const WebDavRemoteFileCommitter();

  static final Random _random = Random.secure();

  Future<void> replaceFile({
    required String sourceFilePath,
    required String destinationPath,
    required WebDavRemoveRemoteFile remove,
    required WebDavUploadRemoteFile uploadFromFile,
    required WebDavRenameRemoteFile rename,
    required WebDavRemoteEntryExists exists,
    required WebDavVerifyRemoteFile verify,
  }) async {
    final temporaryPath = '$destinationPath.${_createTemporaryToken()}.cache';
    try {
      await uploadFromFile(sourceFilePath, temporaryPath);
      try {
        await rename(temporaryPath, destinationPath);
        await verify(sourceFilePath, destinationPath);
        return;
      } catch (_) {
        // Some WebDAV implementations reject overwrite MOVE. Others return a
        // 207 response containing a per-resource failure which webdav_client
        // currently treats as success. Retry the compatible replace flow only
        // when the uploaded temporary file is still present.
        if (!await exists(temporaryPath)) {
          rethrow;
        }
      }

      await _removeIfExists(
        destinationPath,
        remove: remove,
        exists: exists,
      );
      await rename(temporaryPath, destinationPath);
      await verify(sourceFilePath, destinationPath);
    } catch (_) {
      await _removeIfExists(
        temporaryPath,
        remove: remove,
        exists: exists,
      );
      rethrow;
    }
  }

  Future<void> _removeIfExists(
    String path, {
    required WebDavRemoveRemoteFile remove,
    required WebDavRemoteEntryExists exists,
  }) async {
    try {
      await remove(path);
    } catch (_) {
      if (await exists(path)) {
        rethrow;
      }
    }
  }

  static String _createTemporaryToken() {
    return List<int>.generate(16, (_) => _random.nextInt(256))
        .map((value) => value.toRadixString(16).padLeft(2, '0'))
        .join();
  }
}
