class SearchItem {
  String name;
  String src;

  SearchItem({
    required this.name,
    required this.src,
  });

  factory SearchItem.fromJson(Map<String, dynamic> json) {
    return SearchItem(name: json['name'], src: json['src']);
  }
}

class SearchResponse {
  String pluginName;
  List<SearchItem> data;

  SearchResponse({
    required this.pluginName,
    required this.data,
  });

  factory SearchResponse.fromJson(Map<String, dynamic> json) {
    return SearchResponse(
      pluginName: json['pluginName'],
      data: (json['data'] as List)
          .map((itemJson) => SearchItem.fromJson(itemJson))
          .toList(),
    );
  }
}
