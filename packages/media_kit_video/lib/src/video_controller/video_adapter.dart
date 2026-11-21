/// A graphics adapter reported by the OS API. IDs are opaque, platform-local,
/// and may change after a driver update, reboot or hardware change.
class VideoAdapter {
  const VideoAdapter({
    required this.id,
    required this.name,
    required this.vendorId,
    this.memoryMiB,
    this.apiVersion,
  });

  final String id;
  final String name;
  final int vendorId;
  final int? memoryMiB;
  final String? apiVersion;

  static VideoAdapter? tryParse(Object? value) {
    if (value is! Map<Object?, Object?>) return null;
    if (value case {
      'id': final String id,
      'name': final String name,
      'vendorId': final int vendorId,
    } when id.isNotEmpty && name.isNotEmpty) {
      return VideoAdapter(
        id: id,
        name: name,
        vendorId: vendorId,
        memoryMiB: value['memoryMiB'] is int ? value['memoryMiB'] as int : null,
        apiVersion:
            value['apiVersion'] is String ? value['apiVersion'] as String : null,
      );
    }
    return null;
  }
}

/// Notification associated with a particular player, not a global adapter.
class WindowsVideoRenderWarning {
  const WindowsVideoRenderWarning(this.handle, this.code);

  final int handle;
  final String code;
}
