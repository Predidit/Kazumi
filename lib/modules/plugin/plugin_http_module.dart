class PluginHTTPItem {
  String name;
  String version;
  bool useNativePlayer;
  String author;
  int lastUpdate;
  bool antiCrawlerEnabled;

  PluginHTTPItem({
    required this.name,
    required this.version,
    required this.useNativePlayer,
    required this.author,
    required this.lastUpdate,
    this.antiCrawlerEnabled = false,
  });

  factory PluginHTTPItem.fromJson(Map<String, dynamic> json) {
    final dynamic rawConfig = json['antiCrawlerConfig'];
    final bool antiCrawlerEnabled = rawConfig is Map<String, dynamic>
        ? (rawConfig['enabled'] as bool? ?? false)
        : (json['antiCrawlerEnabled'] as bool? ?? false);
    return PluginHTTPItem(
      name: json['name'],
      version: json['version'],
      useNativePlayer: json['useNativePlayer'],
      author: json['author'],
      lastUpdate: json['lastUpdate'] ?? 0,
      antiCrawlerEnabled: antiCrawlerEnabled,
    );
  }
}
