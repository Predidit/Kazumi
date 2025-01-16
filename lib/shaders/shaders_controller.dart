import 'dart:io';
import 'dart:convert';
import 'package:kazumi/utils/constants.dart';
import 'package:mobx/mobx.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:logger/logger.dart';
import 'package:path/path.dart' as path;
import 'package:kazumi/utils/logger.dart';

part 'shaders_controller.g.dart';

class ShadersController = _ShadersController with _$ShadersController;

abstract class _ShadersController with Store {
  late Directory shadersDirectory;

  Future<void> copyShadersToExternalDirectory() async {
    final manifestContent = await rootBundle.loadString('AssetManifest.json');
    final Map<String, dynamic> manifestMap = json.decode(manifestContent);
    final directory = await getApplicationSupportDirectory();
    shadersDirectory = Directory(path.join(directory.path, 'anime_shaders'));

    if (!await shadersDirectory.exists()) {
      await shadersDirectory.create(recursive: true);
      KazumiLogger().log(Level.info, 'Create GLSL Shader: ${shadersDirectory.path}');
    }

    final shaderFiles = manifestMap.keys.where((String key) =>
        key.startsWith('assets/shaders/') && key.endsWith('.glsl'));

    int copiedFilesCount = 0;

    for (var filePath in shaderFiles) {
      final fileName = filePath.split('/').last;
      final targetFile = File(path.join(shadersDirectory.path, fileName));
      if (await targetFile.exists()) {
        KazumiLogger().log(Level.info, 'GLSL Shader exists, skip: ${targetFile.path}');
        continue;
      }

      try {
        final data = await rootBundle.load(filePath);
        final List<int> bytes = data.buffer.asUint8List();
        await targetFile.writeAsBytes(bytes);
        copiedFilesCount++;
        KazumiLogger().log(Level.info, 'Copy: ${targetFile.path}');
      } catch (e) {
        KazumiLogger().log(Level.fatal, 'Copy: ($filePath): $e');
      }
    }

    KazumiLogger().log(
        Level.info, '$copiedFilesCount GLSL files copied to ${shadersDirectory.path}');
  }

  String getShadersAbsolutePath(SuperResolutionType type) {
    final shaders = typeToShaders[type];
    List<String> absolutePaths = shaders!.map((shader) {
      return path.join(shadersDirectory.path, shader);
    }).toList();
    if (Platform.isWindows) {
      return absolutePaths.join(';');
    }
    return absolutePaths.join(':');
  }
}
