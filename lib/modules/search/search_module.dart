class SearchResponse {
  String name;
  String src;

  SearchResponse({
    required this.name,
    required this.src,
  });

  factory SearchResponse.fromJson(Map<String, dynamic> json) {
    return SearchResponse(name: json['name'], src: json['src']);
  }
}