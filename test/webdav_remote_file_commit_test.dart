import 'package:flutter_test/flutter_test.dart';
import 'package:kazumi/services/sync/webdav_remote_file_commit.dart';

void main() {
  test('uses a unique temporary path for every remote replacement', () async {
    final remoteFiles = <String, String>{};
    final uploadedPaths = <String>[];
    const sourcePath = 'local-file';
    const destinationPath = '/kazumiSync/collectibles.tmp';

    Future<void> replace() {
      return const WebDavRemoteFileCommitter().replaceFile(
        sourceFilePath: sourcePath,
        destinationPath: destinationPath,
        remove: (path) async {
          remoteFiles.remove(path);
        },
        uploadFromFile: (localPath, remotePath) async {
          uploadedPaths.add(remotePath);
          remoteFiles[remotePath] = 'new-content';
        },
        rename: (source, destination) async {
          remoteFiles[destination] = remoteFiles.remove(source)!;
        },
        exists: (path) async => remoteFiles.containsKey(path),
        moveApplied: (source, destination) async =>
            !remoteFiles.containsKey(source) &&
            remoteFiles.containsKey(destination),
      );
    }

    await replace();
    await replace();

    expect(uploadedPaths, hasLength(2));
    expect(uploadedPaths.toSet(), hasLength(2));
    expect(
      uploadedPaths,
      everyElement(
        allOf(
          startsWith('$destinationPath.'),
          endsWith('.cache'),
        ),
      ),
    );
  });

  test('retries compatible replace when MOVE falsely reports success',
      () async {
    final remoteFiles = <String, String>{
      '/kazumiSync/collectibles.tmp': 'old-content',
    };
    var renameCalls = 0;

    await const WebDavRemoteFileCommitter().replaceFile(
      sourceFilePath: 'local-file',
      destinationPath: '/kazumiSync/collectibles.tmp',
      remove: (path) async {
        remoteFiles.remove(path);
      },
      uploadFromFile: (localPath, remotePath) async {
        remoteFiles[remotePath] = 'new-content';
      },
      rename: (source, destination) async {
        renameCalls++;
        if (renameCalls == 1) {
          // Simulates webdav_client accepting a 207 response whose body
          // reports that the MOVE failed.
          return;
        }
        remoteFiles[destination] = remoteFiles.remove(source)!;
      },
      exists: (path) async => remoteFiles.containsKey(path),
      moveApplied: (source, destination) async =>
          !remoteFiles.containsKey(source) &&
          remoteFiles.containsKey(destination),
    );

    expect(renameCalls, 2);
    expect(
      remoteFiles['/kazumiSync/collectibles.tmp'],
      'new-content',
    );
  });

  test('reports failure when the retried MOVE still changes nothing', () async {
    final remoteFiles = <String, String>{
      '/kazumiSync/collectibles.tmp': 'old-content',
    };

    await expectLater(
      const WebDavRemoteFileCommitter().replaceFile(
        sourceFilePath: 'local-file',
        destinationPath: '/kazumiSync/collectibles.tmp',
        remove: (path) async {
          remoteFiles.remove(path);
        },
        uploadFromFile: (localPath, remotePath) async {
          remoteFiles[remotePath] = 'new-content';
        },
        rename: (source, destination) async {
          // Simulates repeated false-success MOVE responses.
        },
        exists: (path) async => remoteFiles.containsKey(path),
        moveApplied: (source, destination) async =>
            !remoteFiles.containsKey(source) &&
            remoteFiles.containsKey(destination),
      ),
      throwsA(isA<StateError>()),
    );
  });
}
