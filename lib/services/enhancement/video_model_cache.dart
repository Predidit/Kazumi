import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

enum BundledVideoModel {
  drba(
    'distildrba-v2-lite',
    'flownet',
    (9306, 'e2a2409705f68e1efbf9ac34a016544751a78e0b9e2130ab0c716b5db817eda5'),
    (
      10641380,
      '01e8c2a39791635496328614f7d2e7a35e9858b8bcf943c6e48d19249383e2c9',
    ),
  );

  const BundledVideoModel(this.folder, this.stem, this.params, this.weights);
  final String folder, stem;
  final (int, String) params, weights;
}

class VideoModelCache {
  VideoModelCache._(this._loadModel);
  static final instance = VideoModelCache._(_stage);

  @visibleForTesting
  factory VideoModelCache.test(
    Future<Directory> Function(BundledVideoModel) loadModel,
  ) => VideoModelCache._(loadModel);

  final Future<Directory> Function(BundledVideoModel) _loadModel;
  final _pending = <BundledVideoModel, Future<Directory>>{};

  Future<Directory> require(BundledVideoModel model) => _pending.putIfAbsent(
    model,
    () => _loadModel(model).whenComplete(() {
      // Map.remove returns this same in-flight Future, so don't return it
      // from whenComplete or the request will wait on itself forever.
      _pending.remove(model);
    }),
  );

  static Future<Directory> _stage(BundledVideoModel model) async {
    final support = await getApplicationSupportDirectory();
    final out = Directory(
      path.join(support.path, 'video_models', model.folder),
    );
    await out.create(recursive: true);
    await _stageFile(out, model, '${model.stem}.param', model.params);
    await _stageFile(out, model, '${model.stem}.bin', model.weights);
    return out;
  }

  static Future<void> _stageFile(
    Directory out,
    BundledVideoModel model,
    String name,
    (int, String) expected,
  ) async {
    final (expectedBytes, digest) = expected;
    final file = File(path.join(out.path, name));
    Future<bool> valid(File candidate) async =>
        await candidate.exists() &&
        await candidate.length() == expectedBytes &&
        (await sha256.bind(candidate.openRead()).first).toString() == digest;
    if (await valid(file)) return;
    // Publish a complete, verified pair of files in the player's native cache.
    final scratch = await out.createTemp('.model-');
    final temp = File(path.join(scratch.path, name));
    try {
      final data = await rootBundle.load('assets/models/${model.folder}/$name');
      await temp.writeAsBytes(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      );
      if (!await valid(temp)) {
        throw FormatException('Invalid bundled model: ${model.folder}/$name');
      }
      if (!await valid(file)) {
        try {
          await temp.rename(file.path);
        } on FileSystemException {
          // A second Kazumi instance can win the same atomic publication.
          if (!await valid(file)) rethrow;
        }
      }
    } finally {
      if (await temp.exists()) await temp.delete();
      await scratch.delete();
    }
  }
}
