class PluginHTTPItem {
  String name;
  String version;
  String author;

  PluginHTTPItem({
    required this.name,
    required this.version,
    required this.author,
  });

  factory PluginHTTPItem.fromJson(Map<String, dynamic> json) {
    return PluginHTTPItem(
      name: json['name'],
      version: json['version'],
      author: json['author'],
    );
  }
}