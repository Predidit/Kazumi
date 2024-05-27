class PluginHTTPItem {
  String name;
  String version;
  bool useNativePlayer;
  String author;

  PluginHTTPItem({
    required this.name,
    required this.version,
    required this.useNativePlayer,
    required this.author,
  });

  factory PluginHTTPItem.fromJson(Map<String, dynamic> json) {
    return PluginHTTPItem(
      name: json['name'],
      version: json['version'],
      useNativePlayer: json['useNativePlayer'],
      author: json['author'],
    );
  }
}