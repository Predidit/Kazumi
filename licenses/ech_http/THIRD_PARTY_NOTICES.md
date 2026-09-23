# Third-Party Notices and Licenses

The `ech_http` native library statically links and bundles the following open-source dependencies. When distributing applications built with `ech_http`, you must preserve and include these notices in your application's license documentation. The [MIT License](LICENSE) of this project does not supersede or replace these third-party licenses.

---

## 1. Bundled Native Components

| Component | Pinned Version / Source | License Type | License File in Repository |
| :--- | :--- | :--- | :--- |
| **libcurl** | 8.22.0<br>[Source Archive](https://curl.se/download/curl-8.22.0.tar.xz) | curl License (MIT/X-style) | [`src/CURL_LICENSE`](src/CURL_LICENSE) |
| **BoringSSL** | Git Commit: [`cff1385e`](https://github.com/google/boringssl/tree/cff1385e77b9b2095558fa625b3c35d589ffe09b) | OpenSSL / ISC / BSD / Apache-2.0 | [`src/BORINGSSL_LICENSE`](src/BORINGSSL_LICENSE) |
| **Mozilla Root CA Bundle** | Mozilla Snapshot: `2026-08-13`<br>[curl CA Extract](https://curl.se/docs/caextract.html) | Mozilla Public License 2.0 (MPL-2.0) | [`src/CA_BUNDLE_LICENSE`](src/CA_BUNDLE_LICENSE) |
| **Android NDK libc++** | Statically linked on Android target ABIs | Apache-2.0 with LLVM Exceptions | [`src/LIBCXX_LICENSE`](src/LIBCXX_LICENSE) |

---

## 2. Mozilla Root CA Bundle Details

The unmodified root certificate bundle is embedded directly within the library sources:
- **Location**: `src/cacert.pem`
- **SHA-256 Digest**:
  ```text
  f66dff1bdf8f96060b8177976f8b7d9254bc89bc4db933d769f7384d28480bc9
  ```
- **License Compliance**: In compliance with section 3.2 of MPL-2.0, the source code of the covered CA bundle is distributed unmodified at `src/cacert.pem`.

---

## 3. Application Distribution Guidelines

- **Flutter Applications**: You can expose Dart dependencies automatically using Flutter's built-in `showLicensePage()`. In addition, native notices (libcurl, BoringSSL, Mozilla CA bundle, and NDK libc++) should be registered via Flutter's `LicenseRegistry`:
  ```dart
  import 'package:flutter/foundation.dart';
  import 'package:flutter/services.dart';

  void registerNativeLicenses() {
    LicenseRegistry.addLicense(() async* {
      final curlLicense = await rootBundle.loadString('licenses/CURL_LICENSE');
      yield LicenseEntryWithLineBreaks(['ech_http (libcurl)'], curlLicense);
      
      final bsslLicense = await rootBundle.loadString('licenses/BORINGSSL_LICENSE');
      yield LicenseEntryWithLineBreaks(['ech_http (BoringSSL)'], bsslLicense);
    });
  }
  ```
- **Standalone Dart Programs**: Distribute copies of the license files alongside your executable or package installer.
