import 'package:flutter_test/flutter_test.dart';
import 'package:kazumi/services/update/update_asset_policy.dart';

void main() {
  final validHash = List<String>.filled(64, 'a').join();

  Map<String, dynamic> asset({
    String name = 'Kazumi_windows_v2.2.1.msix',
    String url = 'https://downloads.example/Kazumi_windows_v2.2.1.msix',
    String? mirrorUrl,
    String? digest,
    int size = 42 * 1024 * 1024,
  }) {
    return <String, dynamic>{
      'name': name,
      'browser_download_url': url,
      if (mirrorUrl != null) 'mirror_download_url': mirrorUrl,
      'digest': digest ?? 'sha256:$validHash',
      'size': size,
    };
  }

  group('update asset validation', () {
    test('accepts a strict HTTPS MSIX asset and normalizes its digest', () {
      final validated = validateUpdateAsset(
        asset(digest: 'sha256:${validHash.toUpperCase()}'),
        InstallationType.windowsMsix,
      );

      expect(validated.metadataName, 'Kazumi_windows_v2.2.1.msix');
      expect(
        validated.downloadUri,
        Uri.parse(
          'https://downloads.example/Kazumi_windows_v2.2.1.msix',
        ),
      );
      expect(validated.sha256, validHash);
    });

    test('accepts a strict HTTPS portable ZIP asset', () {
      final validated = validateUpdateAsset(
        asset(
          name: 'Kazumi_windows_v2.2.1.zip',
          url: 'https://downloads.example/Kazumi_windows_v2.2.1.zip',
        ),
        InstallationType.windowsPortable,
      );

      expect(validated.installationType, InstallationType.windowsPortable);
      expect(validated.downloadUri.path, endsWith('.zip'));
    });

    test('falls back from an invalid mirror to a valid HTTPS source URL', () {
      final validated = validateUpdateAsset(
        asset(
          mirrorUrl: 'http://mirror.example/Kazumi_windows_v2.2.1.msix',
        ),
        InstallationType.windowsMsix,
      );

      expect(validated.downloadUri.host, 'downloads.example');
    });

    test('retains valid mirror and source URLs for runtime failover', () {
      final validated = validateUpdateAsset(
        asset(
          mirrorUrl: 'https://mirror.example/Kazumi_windows_v2.2.1.msix',
        ),
        InstallationType.windowsMsix,
      );

      expect(
        validated.downloadUris.map((uri) => uri.host),
        ['mirror.example', 'downloads.example'],
      );
      expect(validated.sizeBytes, 42 * 1024 * 1024);
    });

    test('rejects encoded traversal, separators, and device names', () {
      final unsafeUrls = <String>[
        r'https://downloads.example/%2e%2e%5cKazumi_windows.msix',
        r'https://downloads.example/%2e%2e/Kazumi_windows.msix',
        r'https://downloads.example/C%3a%5cKazumi_windows.msix',
        r'https://downloads.example/%43ON.msix',
      ];

      for (final url in unsafeUrls) {
        expect(
          () => validateUpdateAsset(
            asset(url: url),
            InstallationType.windowsMsix,
          ),
          throwsA(isA<UpdateAssetPolicyException>()),
          reason: url,
        );
      }

      expect(
        () => validateUpdateAsset(
          asset(name: r'..\Kazumi_windows.msix'),
          InstallationType.windowsMsix,
        ),
        throwsA(isA<UpdateAssetPolicyException>()),
      );
    });

    test('rejects HTTP and wrong metadata or URL suffixes', () {
      final invalidAssets = <Map<String, dynamic>>[
        asset(url: 'http://downloads.example/Kazumi_windows_v2.2.1.msix'),
        asset(name: 'Kazumi_windows_v2.2.1.msix.exe'),
        asset(url: 'https://downloads.example/Kazumi_windows_v2.2.1.zip'),
        asset(name: 'Kazumi_windows_v2.2.1.zip'),
      ];

      for (final invalid in invalidAssets) {
        expect(
          () => validateUpdateAsset(invalid, InstallationType.windowsMsix),
          throwsA(isA<UpdateAssetPolicyException>()),
        );
      }
    });

    test('rejects missing, malformed, short, and non-hex digests', () {
      final invalidDigests = <Object?>[
        null,
        '',
        'sha256:${List<String>.filled(63, 'a').join()}',
        'sha256:${List<String>.filled(64, 'g').join()}',
        validHash,
      ];

      for (final digest in invalidDigests) {
        final candidate = asset();
        if (digest == null) {
          candidate.remove('digest');
        } else {
          candidate['digest'] = digest;
        }
        expect(
          () => validateUpdateAsset(
            candidate,
            InstallationType.windowsMsix,
          ),
          throwsA(isA<UpdateAssetPolicyException>()),
        );
      }
    });

    test('rejects missing, empty, and excessive artifact sizes', () {
      final missing = asset()..remove('size');
      for (final candidate in [
        missing,
        asset(size: 0),
        asset(size: maxWindowsUpdateArtifactBytes + 1),
      ]) {
        expect(
          () => validateUpdateAsset(
            candidate,
            InstallationType.windowsMsix,
          ),
          throwsA(isA<UpdateAssetPolicyException>()),
        );
      }
    });
  });

  group('release notes URL validation', () {
    test('accepts only the Kazumi GitHub releases path', () {
      expect(
        validateUpdateReleaseNotesUrl(
          'https://github.com/Predidit/Kazumi/releases/tag/2.2.1',
        ),
        'https://github.com/Predidit/Kazumi/releases/tag/2.2.1',
      );
      expect(
        validateUpdateReleaseNotesUrl(
          'https://example.com/Predidit/Kazumi/releases/tag/2.2.1',
        ),
        isEmpty,
      );
      expect(
        validateUpdateReleaseNotesUrl(
          'https://github.com/attacker/repository/releases/tag/fake',
        ),
        isEmpty,
      );
    });
  });

  group('controlled local update paths', () {
    test('builds a local basename from type, sanitized version, and nonce', () {
      final filename = buildControlledUpdateFilename(
        installationType: InstallationType.windowsMsix,
        version: r'../../v2.2.1:preview',
        uniqueToken: '0011223344556677',
      );

      expect(
        filename,
        'kazumi-windows-msix-v2.2.1_preview-0011223344556677.msix',
      );
      expect(filename, isNot(contains(r'\')));
      expect(filename, isNot(contains('/')));
      expect(filename, isNot(contains('..')));
    });

    test('contains generated files and rejects injected basenames', () {
      final filename = buildControlledUpdateFilename(
        installationType: InstallationType.windowsPortable,
        version: '2.2.1',
        uniqueToken: '0011223344556677',
      );
      final resolved = resolveContainedUpdatePath(r'C:\Temp\Kazumi', filename);

      expect(resolved.toLowerCase(), contains('kazumi-windows-portable'));
      expect(
        () => resolveContainedUpdatePath(
          r'C:\Temp\Kazumi',
          r'..\outside.msix',
        ),
        throwsA(isA<UpdateAssetPolicyException>()),
      );
      expect(
        () => resolveContainedUpdatePath(
          r'C:\Temp\Kazumi',
          'CON.msix',
        ),
        throwsA(isA<UpdateAssetPolicyException>()),
      );
    });
  });

  test('the fallback verifier is explicitly fail closed', () async {
    const verifier = FailClosedUpdateArtifactVerifier('not configured');

    expect(verifier.supports(InstallationType.windowsMsix), isFalse);
    await expectLater(
      verifier.verify(
        filePath: r'C:\Temp\Kazumi\update.msix',
        installationType: InstallationType.windowsMsix,
      ),
      throwsA(isA<UpdateArtifactVerificationException>()),
    );
  });
}
