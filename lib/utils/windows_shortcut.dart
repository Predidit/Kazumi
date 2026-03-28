import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:win32/win32.dart';

/// Windows desktop shortcut utility using native Win32 API
class WindowsShortcut {
  /// Create a desktop shortcut for the application using IShellLink COM API
  static Future<bool> createDesktopShortcut({
    String shortcutName = 'Kazumi',
    String description = 'Kazumi - Anime Player',
  }) async {
    if (!Platform.isWindows) return false;

    try {
      final userProfile = Platform.environment['USERPROFILE'];
      if (userProfile == null) return false;

      final shortcutPath = p.join(userProfile, 'Desktop', '$shortcutName.lnk');

      // Check if shortcut already exists
      if (await File(shortcutPath).exists()) return true;

      final exePath = Platform.resolvedExecutable;

      // Initialize COM library
      final hrInit = CoInitializeEx(
          nullptr, COINIT_APARTMENTTHREADED | COINIT_DISABLE_OLE1DDE);
      if (FAILED(hrInit)) {
        debugPrint('Failed to initialize COM library: $hrInit');
        return false;
      }

      try {
        // Create ShellLink COM object
        final shellLink = ShellLink.createInstance();

        // Set target path
        final targetPathPtr = exePath.toNativeUtf16();
        shellLink.setPath(targetPathPtr);
        free(targetPathPtr);

        // Set description
        final descriptionPtr = description.toNativeUtf16();
        shellLink.setDescription(descriptionPtr);
        free(descriptionPtr);

        // Get IPersistFile interface to save the shortcut
        final persistFile = IPersistFile.from(shellLink);

        // Save the shortcut
        final shortcutPathPtr = shortcutPath.toNativeUtf16();
        final hrSave = persistFile.save(shortcutPathPtr, TRUE);
        free(shortcutPathPtr);

        if (SUCCEEDED(hrSave)) {
          return true;
        } else {
          debugPrint('Failed to save shortcut: $hrSave');
          return false;
        }
      } finally {
        CoUninitialize();
      }
    } catch (e) {
      debugPrint('Failed to create desktop shortcut: $e');
      return false;
    }
  }
}