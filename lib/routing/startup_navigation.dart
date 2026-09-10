class StartupNavigation {
  StartupNavigation({bool initialized = false}) : _initialized = initialized;

  bool _initialized;
  bool _onboarding = false;
  Uri? _destination;

  String? redirect(Uri uri) {
    if (_initialized || uri.path == '/') return null;
    if (_onboarding && uri.path == '/onboarding') return null;
    if (uri.path != '/onboarding') _destination = uri;
    return _onboarding ? '/onboarding' : '/';
  }

  void beginOnboarding() => _onboarding = true;

  String complete(String fallback) {
    _initialized = true;
    final destination = _destination;
    _destination = null;
    return destination?.toString() ?? fallback;
  }
}
