import 'dart:io';
import 'package:mobx/mobx.dart';
import 'package:flutter/services.dart' show rootBundle, AssetManifest;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:kazumi/utils/logger.dart';

part 'shaders_controller.g.dart';

class ShadersController = _ShadersController with _$ShadersController;

abstract class _ShadersController with Store {
  late Directory shadersDirectory;

  Future<void> copyShadersToExternalDirectory() async {
    final assetManifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    final assets = assetManifest.listAssets();
    final directory = await getApplicationSupportDirectory();
    shadersDirectory = Directory(path.join(directory.path, 'anime_shaders'));

    if (!await shadersDirectory.exists()) {
      await shadersDirectory.create(recursive: true);
      KazumiLogger()
          .i('ShaderManager: Create GLSL Shader: ${shadersDirectory.path}');
    }

    final shaderFiles = assets.where((String asset) =>
        asset.startsWith('assets/shaders/') && asset.endsWith('.glsl'));

    int copiedFilesCount = 0;

    for (var filePath in shaderFiles) {
      final fileName = filePath.split('/').last;
      final targetFile = File(path.join(shadersDirectory.path, fileName));
      if (await targetFile.exists()) {
        KazumiLogger()
            .i('ShaderManager: GLSL Shader exists, skip: ${targetFile.path}');
        continue;
      }

      try {
        final data = await rootBundle.load(filePath);
        final List<int> bytes = data.buffer.asUint8List();
        await targetFile.writeAsBytes(bytes);
        copiedFilesCount++;
        KazumiLogger().i('ShaderManager: Copy: ${targetFile.path}');
      } catch (e) {
        KazumiLogger().e('ShaderManager: Copy: ($filePath)', error: e);
      }
    }

    KazumiLogger().i(
        'ShaderManager: $copiedFilesCount GLSL files copied to ${shadersDirectory.path}');
  }
}
