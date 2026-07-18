import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kazumi/services/update/update_asset_policy.dart';
import 'package:kazumi/services/update/windows_update_artifact_verifier.dart';

void main() {
  const verifier = WindowsUpdateArtifactVerifier();

  test('Windows verifier supports both published Windows formats', () {
    expect(verifier.supports(InstallationType.windowsMsix), isTrue);
    expect(verifier.supports(InstallationType.windowsPortable), isTrue);
    expect(verifier.supports(InstallationType.androidApk), isFalse);
  });

  test('Windows verifier fails closed for an unsigned portable archive',
      () async {
    if (!Platform.isWindows) {
      return;
    }
    final directory = await Directory.systemTemp.createTemp(
      'kazumi-update-verifier-test-',
    );
    addTearDown(() async {
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    });
    final archive = File('${directory.path}${Platform.pathSeparator}fake.zip');
    await archive.writeAsBytes(const [0x50, 0x4b, 0x05, 0x06]);

    await expectLater(
      verifier.verify(
        filePath: archive.path,
        installationType: InstallationType.windowsPortable,
      ),
      throwsA(isA<UpdateArtifactVerificationException>()),
    );
  });
}
