// Run from the repository root after Flutter dependencies are resolved:
// dart tools/generate_portable_manifest.dart --root PATH
//   --package-type windowsPortable|linuxPortable --architecture x64|arm64
// Direct script execution avoids unrelated package build hooks from dart run.

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

const manifestName = 'file-manifest.json';

void main(List<String> arguments) {
  try {
    final options = <String, String>{};
    for (var i = 0; i < arguments.length; i += 2) {
      if (i + 1 == arguments.length ||
          !const [
            '--root',
            '--package-type',
            '--architecture',
          ].contains(arguments[i]) ||
          options.containsKey(arguments[i])) {
        throw const FormatException(
          'Expected --root PATH --package-type '
          'windowsPortable|linuxPortable --architecture x64|arm64',
        );
      }
      options[arguments[i]] = arguments[i + 1];
    }
    final root = options['--root'];
    final packageType = options['--package-type'];
    final architecture = options['--architecture'];
    if (root == null ||
        root.isEmpty ||
        !const ['windowsPortable', 'linuxPortable'].contains(packageType) ||
        !const ['x64', 'arm64'].contains(architecture)) {
      throw const FormatException('Missing or invalid manifest arguments');
    }
    generateManifest(root, packageType!, architecture!);
  } catch (error) {
    // A failed build must not publish an old manifest left by an earlier run.
    stderr.writeln('Portable manifest generation failed: $error');
    exitCode = 1;
  }
}

String readVersion(File pubspec) {
  // Read the build input, never a tag or canary label. Only unquoted top-level
  // version keys are supported; the version value may still be quoted.
  final versionKey = RegExp(r'^version[ \t]*:');
  final declarations = pubspec
      .readAsLinesSync()
      .where(versionKey.hasMatch)
      .toList();
  if (declarations.length != 1) {
    throw const FormatException('Expected exactly one top-level version');
  }
  final match = RegExp(
    r'''^version[ \t]*:[ \t]*(['"]?)([0-9]+\.[0-9]+\.[0-9]+)(?:\+[0-9]+)?\1(?:[ \t]+#[^\r\n]*)?[ \t]*$''',
  ).firstMatch(declarations.single);
  if (match == null) {
    throw const FormatException('Unsupported pubspec version syntax');
  }
  return match.group(2)!;
}

void generateManifest(
  String rootPath,
  String packageType,
  String architecture,
) {
  final windows = packageType == 'windowsPortable';
  if (windows && !Platform.isWindows) {
    throw const FormatException('Windows packages require a Windows host');
  }
  var absoluteRootPath = p.absolute(rootPath);
  if (windows) {
    // Normalize before adding the extended-length prefix.
    absoluteRootPath = p.normalize(absoluteRootPath);
    if (!absoluteRootPath.startsWith(r'\\?\')) {
      absoluteRootPath = absoluteRootPath.startsWith(r'\\')
          ? r'\\?\UNC\' + absoluteRootPath.substring(2)
          : r'\\?\' + absoluteRootPath;
    }
  }
  final root = Directory(absoluteRootPath);
  if (FileSystemEntity.typeSync(root.path, followLinks: false) !=
      FileSystemEntityType.directory) {
    throw FileSystemException(
      'Package root must be a real directory',
      root.path,
    );
  }
  final version = readVersion(File('pubspec.yaml'));
  final files = <String>[];
  // Do not descend into links. Linux records the links themselves, including
  // broken links, leaving targets and permissions to tar rather than resolving
  // them. Windows packages accept only regular files and directories.
  for (final entry in root.listSync(recursive: true, followLinks: false)) {
    final relative = p.split(p.relative(entry.path, from: root.path)).join('/');
    if (RegExp(r'[\x00-\x1f\x7f-\x9f]').hasMatch(relative) ||
        (!windows &&
            (relative.contains('\\') ||
                RegExp(r'^[A-Za-z]:').hasMatch(relative)))) {
      throw FormatException('Invalid manifest path: $relative');
    }
    final isManifest = windows
        ? relative.toLowerCase() == manifestName
        : relative == manifestName;
    if (isManifest) {
      // Only overwrite a canonical regular file; excluding prior output makes
      // reruns identical and prevents writing through a link or directory.
      if (entry is! File || relative != manifestName) {
        throw const FormatException(
          'Manifest output must be a regular file with canonical spelling',
        );
      }
      continue;
    }
    if (entry is Directory) continue;
    if (entry is File || (!windows && entry is Link)) {
      files.add(relative);
    } else {
      throw FormatException('Unsupported file type: $relative');
    }
  }
  // UTF-16 string ordering differs from UTF-8 for supplementary characters.
  // Encode once and reject lossy replacement of malformed surrogate sequences.
  final encoded = <String, List<int>>{};
  for (final file in files) {
    final bytes = utf8.encode(file);
    if (utf8.decode(bytes) != file) {
      throw FormatException('Path is not valid UTF-8: $file');
    }
    encoded[file] = bytes;
  }
  files.sort((a, b) {
    final left = encoded[a]!;
    final right = encoded[b]!;
    for (var i = 0; i < left.length && i < right.length; i++) {
      final difference = left[i] - right[i];
      if (difference != 0) return difference;
    }
    return left.length - right.length;
  });
  final manifest = {
    'schemaVersion': 1,
    'appId': 'kazumi',
    'packageType': packageType,
    'version': version,
    'architecture': architecture,
    'files': files,
  };
  // Paths only: signing can change bytes. CI owns archiving and cleanup before
  // MSIX/DEB staging, including cleanup after signed ZIP extraction.
  File(p.join(root.path, manifestName)).writeAsStringSync(
    '${const JsonEncoder.withIndent('  ').convert(manifest)}\n',
    encoding: utf8,
  );
}
