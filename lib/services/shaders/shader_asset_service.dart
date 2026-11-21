import 'dart:io';

import 'package:flutter/services.dart' show rootBundle, AssetManifest;
import 'package:kazumi/services/logging/logger.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

class ShaderAssetService {
  late Directory shadersDirectory;

  Future<void> requireShaders(Iterable<String> names) async {
    for (final name in names) {
      final file = File(path.join(shadersDirectory.path, name));
      if (!await file.exists() || await file.length() == 0) {
        throw FileSystemException('Missing upscaler shader', file.path);
      }
    }
  }

  Future<void> copyShadersToExternalDirectory() async {
    final assetManifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    final assets = assetManifest.listAssets();
    final directory = await getApplicationSupportDirectory();
    shadersDirectory = Directory(path.join(directory.path, 'anime_shaders'));

    if (!await shadersDirectory.exists()) {
      await shadersDirectory.create(recursive: true);
      KazumiLogger().i(
        'ShaderManager: Create GLSL Shader: ${shadersDirectory.path}',
      );
    }

    final shaderFiles = assets.where(
      (String asset) =>
          asset.startsWith('assets/shaders/') && asset.endsWith('.glsl'),
    );

    int copiedFilesCount = 0;

    for (var filePath in shaderFiles) {
      final fileName = filePath.split('/').last;
      final targetFile = File(path.join(shadersDirectory.path, fileName));
      if (await targetFile.exists() && await targetFile.length() > 0) {
        KazumiLogger().i(
          'ShaderManager: GLSL Shader exists, skip: ${targetFile.path}',
        );
        continue;
      }

      try {
        final data = await rootBundle.load(filePath);
        final pending = File('${targetFile.path}.tmp');
        final bytes = data.buffer.asUint8List(
          data.offsetInBytes,
          data.lengthInBytes,
        );
        await pending.writeAsBytes(bytes);
        await pending.rename(targetFile.path);
        copiedFilesCount++;
        KazumiLogger().i('ShaderManager: Copy: ${targetFile.path}');
      } catch (e) {
        KazumiLogger().e('ShaderManager: Copy: ($filePath)', error: e);
      }
    }

    KazumiLogger().i(
      'ShaderManager: $copiedFilesCount GLSL files copied to ${shadersDirectory.path}',
    );
  }
}
