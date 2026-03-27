import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

/// Windows desktop shortcut utility
class WindowsShortcut {
  /// Flag to indicate if shortcut was just created (for showing toast)
  static bool justCreated = false;

  /// Create a desktop shortcut for the application
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

      // Create shortcut using PowerShell
      final psScript = '''
\$WshShell = New-Object -ComObject WScript.Shell
\$Shortcut = \$WshShell.CreateShortcut('$shortcutPath')
\$Shortcut.TargetPath = '$exePath'
\$Shortcut.Description = '$description'
\$Shortcut.Save()
''';

      final result = await Process.run(
        'powershell',
        ['-ExecutionPolicy', 'Bypass', '-Command', psScript],
      );

      if (result.exitCode == 0) {
        justCreated = true;
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Failed to create desktop shortcut: $e');
      return false;
    }
  }
}