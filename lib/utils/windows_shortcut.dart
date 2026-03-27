import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

/// Windows desktop shortcut utility
/// Creates desktop shortcut on Windows platforms
class WindowsShortcut {
  /// Flag to indicate if shortcut was just created (for showing toast)
  static bool justCreated = false;

  /// Create a desktop shortcut for the application
  /// Returns true if successful, false otherwise
  static Future<bool> createDesktopShortcut({
    String shortcutName = 'Kazumi',
    String description = 'Kazumi - Anime Player',
  }) async {
    if (!Platform.isWindows) {
      debugPrint('Not Windows platform, skipping shortcut creation');
      return false;
    }

    try {
      // Get desktop path
      final userProfile = Platform.environment['USERPROFILE'];
      debugPrint('USERPROFILE: $userProfile');
      if (userProfile == null) {
        debugPrint('Failed to get USERPROFILE environment variable');
        return false;
      }

      final shortcutPath = p.join(userProfile, 'Desktop', '$shortcutName.lnk');
      debugPrint('Shortcut path: $shortcutPath');

      // Check if shortcut already exists
      final shortcutFile = File(shortcutPath);
      if (await shortcutFile.exists()) {
        debugPrint('Desktop shortcut already exists at: $shortcutPath');
        return true;
      }

      // Get the executable path
      final exePath = Platform.resolvedExecutable;
      debugPrint('Executable path: $exePath');

      // Escape paths for PowerShell
      final escapedShortcutPath = shortcutPath.replaceAll("'", "''");
      final escapedExePath = exePath.replaceAll("'", "''");

      // Create shortcut using PowerShell
      final psScript = '''
\$WshShell = New-Object -ComObject WScript.Shell
\$Shortcut = \$WshShell.CreateShortcut('$escapedShortcutPath')
\$Shortcut.TargetPath = '$escapedExePath'
\$Shortcut.Description = '$description'
\$Shortcut.Save()
''';
      debugPrint('Running PowerShell script...');

      final result = await Process.run(
        'powershell',
        ['-ExecutionPolicy', 'Bypass', '-Command', psScript],
      );

      debugPrint('PowerShell exit code: ${result.exitCode}');
      if (result.stdout.toString().isNotEmpty) {
        debugPrint('PowerShell stdout: ${result.stdout}');
      }
      if (result.stderr.toString().isNotEmpty) {
        debugPrint('PowerShell stderr: ${result.stderr}');
      }

      if (result.exitCode == 0) {
        debugPrint('Desktop shortcut created successfully at: $shortcutPath');
        justCreated = true;
        return true;
      } else {
        debugPrint('Failed to create desktop shortcut');
        return false;
      }
    } catch (e, stackTrace) {
      debugPrint('Exception while creating desktop shortcut: $e');
      debugPrint('StackTrace: $stackTrace');
      return false;
    }
  }

  /// Check if desktop shortcut exists
  static Future<bool> shortcutExists({String shortcutName = 'Kazumi'}) async {
    if (!Platform.isWindows) return false;

    final userProfile = Platform.environment['USERPROFILE'];
    if (userProfile == null) return false;

    final shortcutFile = File(p.join(userProfile, 'Desktop', '$shortcutName.lnk'));
    return await shortcutFile.exists();
  }

  /// Remove desktop shortcut
  static Future<bool> removeDesktopShortcut({String shortcutName = 'Kazumi'}) async {
    if (!Platform.isWindows) return false;

    try {
      final userProfile = Platform.environment['USERPROFILE'];
      if (userProfile == null) return false;

      final shortcutFile = File(p.join(userProfile, 'Desktop', '$shortcutName.lnk'));

      if (await shortcutFile.exists()) {
        await shortcutFile.delete();
        print('Desktop shortcut removed');
      }
      return true;
    } catch (e) {
      print('Failed to remove desktop shortcut: $e');
      return false;
    }
  }
}