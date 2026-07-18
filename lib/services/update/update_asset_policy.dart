import 'package:path/path.dart' as path;

enum InstallationType {
  windowsMsix,
  windowsPortable,
  linuxDeb,
  linuxTar,
  macosDmg,
  androidApk,
  ios,
  unknown,
}

class UpdateAssetPolicyException implements Exception {
  const UpdateAssetPolicyException(this.message);

  final String message;

  @override
  String toString() => 'UpdateAssetPolicyException: $message';
}

class UpdateArtifactVerificationException implements Exception {
  const UpdateArtifactVerificationException(this.message);

  final String message;

  @override
  String toString() => 'UpdateArtifactVerificationException: $message';
}

class ValidatedUpdateAsset {
  const ValidatedUpdateAsset({
    required this.installationType,
    required this.metadataName,
    required this.downloadUris,
    required this.sha256,
    required this.sizeBytes,
  });

  final InstallationType installationType;
  final String metadataName;
  final List<Uri> downloadUris;
  final String sha256;
  final int sizeBytes;

  Uri get downloadUri => downloadUris.first;
}

const int maxWindowsUpdateArtifactBytes = 512 * 1024 * 1024;

abstract interface class UpdateArtifactVerifier {
  bool supports(InstallationType installationType);

  Future<void> verify({
    required String filePath,
    required InstallationType installationType,
  });
}

class FailClosedUpdateArtifactVerifier implements UpdateArtifactVerifier {
  const FailClosedUpdateArtifactVerifier([
    this.reason = 'No trusted artifact verifier is configured',
  ]);

  final String reason;

  @override
  bool supports(InstallationType installationType) => false;

  @override
  Future<void> verify({
    required String filePath,
    required InstallationType installationType,
  }) {
    return Future<void>.error(UpdateArtifactVerificationException(reason));
  }
}

String expectedUpdateExtension(InstallationType installationType) {
  switch (installationType) {
    case InstallationType.windowsMsix:
      return '.msix';
    case InstallationType.windowsPortable:
      return '.zip';
    case InstallationType.macosDmg:
      return '.dmg';
    case InstallationType.androidApk:
      return '.apk';
    case InstallationType.linuxDeb:
      return '.deb';
    case InstallationType.linuxTar:
      return '.tar.gz';
    case InstallationType.ios:
    case InstallationType.unknown:
      throw const UpdateAssetPolicyException(
        'The selected installation type has no downloadable artifact',
      );
  }
}

String normalizeSha256Digest(String digest) {
  final match = RegExp(r'^sha256:([0-9a-fA-F]{64})$').firstMatch(digest.trim());
  if (match == null) {
    throw const UpdateAssetPolicyException(
      'The update digest must be sha256 followed by exactly 64 hex digits',
    );
  }
  return match.group(1)!.toLowerCase();
}

String validateExpectedSha256(String digest) {
  final normalized = digest.trim().toLowerCase();
  if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(normalized)) {
    throw const UpdateAssetPolicyException(
      'The expected SHA-256 must contain exactly 64 hex digits',
    );
  }
  return normalized;
}

ValidatedUpdateAsset validateUpdateAsset(
  Map<String, dynamic> asset,
  InstallationType installationType,
) {
  final expectedExtension = expectedUpdateExtension(installationType);
  final metadataName = asset['name'];
  if (metadataName is! String || metadataName.isEmpty) {
    throw const UpdateAssetPolicyException(
      'The update asset has no metadata filename',
    );
  }

  _validateSafeFilename(
    metadataName,
    expectedExtension: expectedExtension,
    requireWindowsMarker: installationType == InstallationType.windowsMsix ||
        installationType == InstallationType.windowsPortable,
  );

  final digestValue = asset['digest'];
  if (digestValue is! String) {
    throw const UpdateAssetPolicyException(
      'The update asset has no SHA-256 digest',
    );
  }
  final sha256 = normalizeSha256Digest(digestValue);

  final sizeValue = asset['size'];
  if (sizeValue is! int ||
      sizeValue <= 0 ||
      sizeValue > maxWindowsUpdateArtifactBytes) {
    throw const UpdateAssetPolicyException(
      'The update asset size is missing or outside the allowed range',
    );
  }

  final candidates = <String>[
    if (asset['mirror_download_url'] case final String mirrorUrl)
      if (mirrorUrl.trim().isNotEmpty) mirrorUrl.trim(),
    if (asset['browser_download_url'] case final String browserUrl)
      if (browserUrl.trim().isNotEmpty) browserUrl.trim(),
  ];
  if (candidates.isEmpty) {
    throw const UpdateAssetPolicyException(
      'The update asset has no download URL',
    );
  }

  final downloadUris = <Uri>[];
  UpdateAssetPolicyException? lastError;
  for (final candidate in candidates) {
    try {
      final uri = validateUpdateDownloadUri(candidate, installationType);
      if (!downloadUris.contains(uri)) {
        downloadUris.add(uri);
      }
    } on UpdateAssetPolicyException catch (error) {
      lastError = error;
    }
  }
  if (downloadUris.isEmpty) {
    throw lastError ??
        const UpdateAssetPolicyException('The update asset URL is invalid');
  }
  return ValidatedUpdateAsset(
    installationType: installationType,
    metadataName: metadataName,
    downloadUris: List.unmodifiable(downloadUris),
    sha256: sha256,
    sizeBytes: sizeValue,
  );
}

String validateUpdateReleaseNotesUrl(Object? value) {
  if (value is! String) {
    return '';
  }
  final uri = Uri.tryParse(value.trim());
  if (uri == null ||
      uri.scheme.toLowerCase() != 'https' ||
      uri.host.toLowerCase() != 'github.com' ||
      uri.userInfo.isNotEmpty ||
      uri.hasFragment) {
    return '';
  }
  final segments = uri.pathSegments;
  if (segments.length < 3 ||
      segments[0].toLowerCase() != 'predidit' ||
      segments[1].toLowerCase() != 'kazumi' ||
      segments[2].toLowerCase() != 'releases') {
    return '';
  }
  return uri.toString();
}

Uri validateUpdateDownloadUri(
  String rawUrl,
  InstallationType installationType,
) {
  final expectedExtension = expectedUpdateExtension(installationType);
  final uri = Uri.tryParse(rawUrl);
  if (uri == null ||
      uri.scheme.toLowerCase() != 'https' ||
      !uri.hasAuthority ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty ||
      uri.hasFragment) {
    throw const UpdateAssetPolicyException(
      'The update URL must be an HTTPS URL without user info or a fragment',
    );
  }

  // Uri.pathSegments normalizes dot segments. Inspect the raw escaped path
  // first so percent-encoded traversal or Windows separators cannot disappear
  // before validation.
  final rawPath = _rawUrlPath(rawUrl);
  if (RegExp(r'%(?:2e|2f|5c)', caseSensitive: false).hasMatch(rawPath) ||
      rawPath.contains(r'\')) {
    throw const UpdateAssetPolicyException(
      'The update URL contains an encoded traversal or path separator',
    );
  }

  final segments = uri.pathSegments;
  if (segments.isEmpty || segments.last.isEmpty) {
    throw const UpdateAssetPolicyException(
      'The update URL has no artifact filename',
    );
  }
  for (final segment in segments) {
    if (segment.isEmpty) {
      continue;
    }
    _validatePathSegment(segment);
  }
  _validateSafeFilename(
    segments.last,
    expectedExtension: expectedExtension,
  );
  return uri;
}

String _rawUrlPath(String rawUrl) {
  final schemeEnd = rawUrl.indexOf('://');
  if (schemeEnd < 0) {
    return '';
  }
  final authorityStart = schemeEnd + 3;
  final pathStart = rawUrl.indexOf('/', authorityStart);
  if (pathStart < 0) {
    return '/';
  }
  final queryStart = rawUrl.indexOf('?', pathStart);
  final fragmentStart = rawUrl.indexOf('#', pathStart);
  var pathEnd = rawUrl.length;
  if (queryStart >= 0) {
    pathEnd = queryStart;
  }
  if (fragmentStart >= 0 && fragmentStart < pathEnd) {
    pathEnd = fragmentStart;
  }
  return rawUrl.substring(pathStart, pathEnd);
}

String buildControlledUpdateFilename({
  required InstallationType installationType,
  required String version,
  required String uniqueToken,
}) {
  final normalizedToken = uniqueToken.toLowerCase();
  if (!RegExp(r'^[0-9a-f]{16,64}$').hasMatch(normalizedToken)) {
    throw const UpdateAssetPolicyException(
      'The update filename token must contain 16 to 64 hex digits',
    );
  }

  final extension = expectedUpdateExtension(installationType);
  final typeName = switch (installationType) {
    InstallationType.windowsMsix => 'windows-msix',
    InstallationType.windowsPortable => 'windows-portable',
    InstallationType.macosDmg => 'macos-dmg',
    InstallationType.androidApk => 'android-apk',
    InstallationType.linuxDeb => 'linux-deb',
    InstallationType.linuxTar => 'linux-tar',
    InstallationType.ios ||
    InstallationType.unknown =>
      throw const UpdateAssetPolicyException(
        'The selected installation type has no local artifact filename',
      ),
  };
  final safeVersion = _sanitizeVersion(version);
  return 'kazumi-$typeName-$safeVersion-$normalizedToken$extension';
}

String resolveContainedUpdatePath(String rootDirectory, String basename) {
  if (rootDirectory.trim().isEmpty) {
    throw const UpdateAssetPolicyException(
      'The update directory cannot be empty',
    );
  }
  _validateLocalBasename(basename);

  final root = path.normalize(path.absolute(rootDirectory));
  final candidate = path.normalize(path.absolute(path.join(root, basename)));
  if (!path.isWithin(root, candidate)) {
    throw const UpdateAssetPolicyException(
      'The update artifact path escapes the update directory',
    );
  }
  return candidate;
}

String _sanitizeVersion(String version) {
  var safe = version.trim().replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
  safe = safe.replaceAll(RegExp(r'_+'), '_');
  safe = safe.replaceAll(RegExp(r'^[._-]+|[._-]+$'), '');
  if (safe.isEmpty) {
    safe = 'unknown';
  }
  if (safe.length > 48) {
    safe = safe.substring(0, 48);
    safe = safe.replaceAll(RegExp(r'[._-]+$'), '');
  }
  return safe.isEmpty ? 'unknown' : safe;
}

void _validatePathSegment(String segment) {
  if (segment == '.' || segment == '..') {
    throw const UpdateAssetPolicyException(
      'The update URL contains a traversal segment',
    );
  }
  if (segment.contains('/') || segment.contains(r'\')) {
    throw const UpdateAssetPolicyException(
      'The update URL contains an encoded path separator',
    );
  }
  if (segment.contains(':') || _containsControlCharacter(segment)) {
    throw const UpdateAssetPolicyException(
      'The update URL contains a Windows-unsafe path segment',
    );
  }
  _rejectReservedWindowsName(segment);
}

void _validateSafeFilename(
  String filename, {
  required String expectedExtension,
  bool requireWindowsMarker = false,
}) {
  if (filename.isEmpty ||
      filename == '.' ||
      filename == '..' ||
      filename.contains('/') ||
      filename.contains(r'\') ||
      filename.contains(':') ||
      filename.endsWith(' ') ||
      filename.endsWith('.') ||
      _containsControlCharacter(filename)) {
    throw const UpdateAssetPolicyException(
      'The update artifact filename is unsafe on Windows',
    );
  }
  if (!filename.toLowerCase().endsWith(expectedExtension)) {
    throw UpdateAssetPolicyException(
      'The update artifact must end with $expectedExtension',
    );
  }
  if (requireWindowsMarker && !filename.toLowerCase().contains('windows')) {
    throw const UpdateAssetPolicyException(
      'The Windows update metadata filename must identify Windows',
    );
  }
  _rejectReservedWindowsName(filename);
}

void _validateLocalBasename(String basename) {
  if (basename.isEmpty ||
      basename == '.' ||
      basename == '..' ||
      basename.contains('/') ||
      basename.contains(r'\') ||
      basename.contains(':') ||
      basename.endsWith(' ') ||
      basename.endsWith('.') ||
      _containsControlCharacter(basename) ||
      path.basename(basename) != basename) {
    throw const UpdateAssetPolicyException(
      'The local update filename must be a safe basename',
    );
  }
  _rejectReservedWindowsName(basename);
}

void _rejectReservedWindowsName(String value) {
  final firstComponent = value.split('.').first.toUpperCase();
  if (firstComponent == 'CON' ||
      firstComponent == 'PRN' ||
      firstComponent == 'AUX' ||
      firstComponent == 'NUL' ||
      firstComponent == r'CLOCK$' ||
      RegExp(r'^(COM|LPT)[1-9]$').hasMatch(firstComponent)) {
    throw const UpdateAssetPolicyException(
      'The update path contains a reserved Windows device name',
    );
  }
}

bool _containsControlCharacter(String value) {
  return value.codeUnits.any((unit) => unit < 0x20 || unit == 0x7f);
}
