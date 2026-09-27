import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kazumi/services/local_video/local_video_access.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const bookmarks = MethodChannel('codeux.design/macos_secure_bookmarks');
  late Directory directory;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('kazumi_drop_test_');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(bookmarks, (call) async {
          if (call.method == 'bookmarkData') return 'saved-bookmark';
          throw MissingPluginException();
        });
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(bookmarks, null);
    await directory.delete(recursive: true);
  });

  test('accepts a video path with spaces and an uppercase extension', () async {
    final file = await File(
      '${directory.path}/本地 video.MKV',
    ).writeAsBytes([1, 2, 3]);
    final reference = await LocalVideoAccess.fromPath(file.path);
    expect(reference.source, await file.resolveSymbolicLinks());
    expect(reference.name, '本地 video.MKV');
    expect(reference.size, 3);
    expect(
      reference.modifiedMs,
      (await file.stat()).modified.millisecondsSinceEpoch,
    );
    if (Platform.isMacOS) expect(reference.bookmark, 'saved-bookmark');
  });

  test(
    'rejects unsupported files, directories, empty and missing videos',
    () async {
      final unsupported = await File(
        '${directory.path}/notes.txt',
      ).writeAsString('text');
      final folder = await Directory('${directory.path}/folder.mp4').create();
      final empty = await File('${directory.path}/empty.mp4').create();
      for (final path in [
        unsupported.path,
        folder.path,
        empty.path,
        '${directory.path}/missing.mp4',
      ]) {
        await expectLater(
          LocalVideoAccess.fromPath(path),
          throwsA(isA<FileSystemException>()),
        );
      }
    },
  );

  test(
    'retains dropped bookmarks and releases access after validation',
    () async {
      final file = await File('${directory.path}/video.mp4').writeAsBytes([1]);
      final calls = <String>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(bookmarks, (call) async {
            calls.add(call.method);
            if (call.method == 'URLByResolvingBookmarkData') return file.path;
            return true;
          });
      final reference = await LocalVideoAccess.fromPath(
        file.path,
        bookmark: 'dropped-bookmark',
      );
      expect(reference.bookmark, 'dropped-bookmark');
      await file.writeAsBytes([]);
      await expectLater(
        LocalVideoAccess.fromPath(file.path, bookmark: 'dropped-bookmark'),
        throwsA(isA<FileSystemException>()),
      );
      expect(calls, [
        'URLByResolvingBookmarkData',
        'startAccessingSecurityScopedResource',
        'stopAccessingSecurityScopedResource',
        'URLByResolvingBookmarkData',
        'startAccessingSecurityScopedResource',
        'stopAccessingSecurityScopedResource',
      ]);
    },
    skip: !Platform.isMacOS,
  );
}
