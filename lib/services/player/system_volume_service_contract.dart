typedef SystemVolumeChanged = void Function(double volume);

/// Platform-neutral access to the device's system volume.
///
/// Desktop and Web playback must use media_kit volume instead. Implementations
/// therefore report [isSupported] only on native mobile platforms.
abstract interface class SystemVolumeService {
  bool get isSupported;

  /// Returns the normalized system volume in the range 0.0 to 1.0.
  Future<double?> getVolume();

  /// Sets the normalized system volume in the range 0.0 to 1.0.
  Future<void> setVolume(double volume);

  Future<void> setSystemUiVisible(bool visible);

  void addListener(SystemVolumeChanged listener);

  void removeListener();
}
