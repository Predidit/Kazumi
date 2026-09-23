import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

void registerEchHttpLicenses() {
  LicenseRegistry.addLicense(() async* {
    const notices = {
      'libcurl': 'CURL_LICENSE',
      'BoringSSL': 'BORINGSSL_LICENSE',
      'Mozilla CA certificate data': 'CA_BUNDLE_LICENSE',
      'LLVM libc++': 'LIBCXX_LICENSE',
      'ech_http native dependencies': 'THIRD_PARTY_NOTICES.md',
    };
    for (final entry in notices.entries) {
      yield LicenseEntryWithLineBreaks([
        entry.key,
      ], await rootBundle.loadString('licenses/ech_http/${entry.value}'));
    }
  });
}
