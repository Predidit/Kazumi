class ApplicationLifecycleService {
  ApplicationLifecycleService._();

  static Future<void> flushBeforeExit() async {
    // Browsers do not allow awaiting network work during tab teardown.
  }
}
