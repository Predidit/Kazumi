import 'dart:async';

const startupUpdateCheckDelay = Duration(milliseconds: 500);

/// Runs the startup update check independently from the page that scheduled it.
///
/// Startup pages are normally disposed as soon as they navigate to the app
/// shell, so this work must not depend on their [State.mounted] value.
Future<void> runStartupUpdateCheck({
  required bool Function() isEnabled,
  required Future<void> Function() checkForUpdate,
  Duration delay = startupUpdateCheckDelay,
}) async {
  await Future<void>.delayed(delay);
  if (!isEnabled()) {
    return;
  }
  await checkForUpdate();
}
