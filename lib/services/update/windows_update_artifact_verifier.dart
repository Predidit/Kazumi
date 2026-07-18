import 'dart:convert';
import 'dart:io';

import 'package:kazumi/services/update/update_asset_policy.dart';

const expectedWindowsUpdatePublisher =
    'CN=SignPath Foundation, O=SignPath Foundation, L=Lewes, '
    'S=Delaware, C=US';

/// Verifies both Windows release formats against the publisher configured in
/// the MSIX manifest and SignPath release workflow.
///
/// Portable ZIP files are not themselves Authenticode containers. The release
/// workflow signs the root `kazumi.exe` before packaging, so the verifier
/// extracts only that bounded entry into a fresh private temp directory and
/// validates its signature without expanding any other archive content.
class WindowsUpdateArtifactVerifier implements UpdateArtifactVerifier {
  const WindowsUpdateArtifactVerifier();

  @override
  bool supports(InstallationType installationType) {
    return installationType == InstallationType.windowsMsix ||
        installationType == InstallationType.windowsPortable;
  }

  @override
  Future<void> verify({
    required String filePath,
    required InstallationType installationType,
  }) async {
    if (!Platform.isWindows || !supports(installationType)) {
      throw const UpdateArtifactVerificationException(
        'This update type has no trusted Windows artifact verifier',
      );
    }

    final expectedExtension = switch (installationType) {
      InstallationType.windowsMsix => '.msix',
      InstallationType.windowsPortable => '.zip',
      _ => throw const UpdateArtifactVerificationException(
          'Unsupported Windows update artifact type',
        ),
    };
    if (!filePath.toLowerCase().endsWith(expectedExtension)) {
      throw UpdateArtifactVerificationException(
        'The Windows verifier only accepts $expectedExtension files for '
        'this update type',
      );
    }

    final entityType =
        await FileSystemEntity.type(filePath, followLinks: false);
    if (entityType != FileSystemEntityType.file) {
      throw const UpdateArtifactVerificationException(
        'The Windows update artifact is not a regular file',
      );
    }

    final result = await _runPowerShellVerifier(
      filePath,
      installationType == InstallationType.windowsPortable,
    );
    _validateVerifierResult(result);
  }

  Future<ProcessResult> _runPowerShellVerifier(
    String filePath,
    bool portable,
  ) async {
    const script = r'''
$ErrorActionPreference = 'Stop'
$artifactPath = [string]$args[0]
$isPortable = [string]$args[1] -eq 'portable'
$archive = $null
$verificationRoot = $null

try {
  $signaturePath = $artifactPath
  if ($isPortable) {
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $verificationRoot = Join-Path ([System.IO.Path]::GetTempPath()) `
      ('KazumiUpdateVerifier-' + [Guid]::NewGuid().ToString('N'))
    [System.IO.Directory]::CreateDirectory($verificationRoot) | Out-Null
    $archive = [System.IO.Compression.ZipFile]::OpenRead($artifactPath)
    $entries = @($archive.Entries | Where-Object {
      [string]::Equals($_.FullName, 'kazumi.exe', `
        [System.StringComparison]::OrdinalIgnoreCase)
    })
    if ($entries.Count -ne 1) {
      throw 'Portable archive must contain exactly one root kazumi.exe'
    }
    $entry = $entries[0]
    if ($entry.Length -le 0 -or $entry.Length -gt 134217728) {
      throw 'Portable kazumi.exe has an invalid uncompressed size'
    }
    $signaturePath = Join-Path $verificationRoot 'kazumi.exe'
    [System.IO.Compression.ZipFileExtensions]::ExtractToFile(
      $entry, $signaturePath, $false)
  }

  $signature = Get-AuthenticodeSignature -LiteralPath $signaturePath
  $subject = ''
  if ($null -ne $signature.SignerCertificate) {
    $subject = [string]$signature.SignerCertificate.Subject
  }
  @{
    status = [string]$signature.Status
    subject = $subject
  } | ConvertTo-Json -Compress
} finally {
  if ($null -ne $archive) {
    $archive.Dispose()
  }
  if ($null -ne $verificationRoot -and
      [System.IO.Directory]::Exists($verificationRoot)) {
    [System.IO.Directory]::Delete($verificationRoot, $true)
  }
}
''';

    try {
      return await Process.run(
        'powershell.exe',
        [
          '-NoLogo',
          '-NoProfile',
          '-NonInteractive',
          '-Command',
          script,
          filePath,
          portable ? 'portable' : 'msix',
        ],
        runInShell: false,
      );
    } on Object catch (error) {
      throw UpdateArtifactVerificationException(
        'Unable to run the Windows package signature verifier: $error',
      );
    }
  }

  void _validateVerifierResult(ProcessResult result) {
    if (result.exitCode != 0) {
      throw UpdateArtifactVerificationException(
        'Windows package signature verification failed with exit code '
        '${result.exitCode}',
      );
    }

    try {
      final output = result.stdout.toString().trim().replaceFirst('\ufeff', '');
      final value = json.decode(output);
      if (value is! Map) {
        throw const FormatException('Unexpected verifier output');
      }
      final status = value['status']?.toString() ?? '';
      final subject = value['subject']?.toString() ?? '';
      if (status.toLowerCase() != 'valid') {
        throw UpdateArtifactVerificationException(
          'The Windows Authenticode status is $status',
        );
      }
      if (_normalizeDistinguishedName(subject) !=
          _normalizeDistinguishedName(expectedWindowsUpdatePublisher)) {
        throw const UpdateArtifactVerificationException(
          'The Windows artifact publisher does not match the trusted Kazumi '
          'publisher',
        );
      }
    } on UpdateArtifactVerificationException {
      rethrow;
    } on Object catch (error) {
      throw UpdateArtifactVerificationException(
        'Unable to parse the Windows package verifier result: $error',
      );
    }
  }
}

String _normalizeDistinguishedName(String value) {
  final components = value
      .split(',')
      .map((component) => component.trim().toLowerCase())
      .where((component) => component.isNotEmpty)
      .toList()
    ..sort();
  return components.join(',');
}
