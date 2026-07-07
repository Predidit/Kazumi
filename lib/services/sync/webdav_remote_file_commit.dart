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

class WebDavRemoteFileCommitter {
  const WebDavRemoteFileCommitter();

  Future<void> replaceFile({
    required String sourceFilePath,
    required String temporaryPath,
    required String destinationPath,
    required WebDavRemoveRemoteFile remove,
    required WebDavUploadRemoteFile uploadFromFile,
    required WebDavRenameRemoteFile rename,
    required WebDavRemoteEntryExists exists,
  }) async {
    await _removeIfExists(
      temporaryPath,
      remove: remove,
      exists: exists,
    );
    try {
      await uploadFromFile(sourceFilePath, temporaryPath);
      await _removeIfExists(
        destinationPath,
        remove: remove,
        exists: exists,
      );
      await rename(temporaryPath, destinationPath);
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
}
