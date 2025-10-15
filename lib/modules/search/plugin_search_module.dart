class SearchItem {
  String name;
  String img;
  String src;
  Map<String, String> tags;

  SearchItem({
    required this.name,
    this.img = '',
    required this.src,
    Map<String, String>? tags, // 改为可选参数
  }) : tags = tags ?? {}; // 如果 tags 为 null，则初始化为空 Map

  factory SearchItem.fromJson(Map<String, dynamic> json) {
    // 处理 tags 字段
    Map<String, String> tagsMap = {};
    if (json['tags'] != null && json['tags'] is Map) {
      // 遍历 tags Map，确保所有值都是 String 类型
      (json['tags'] as Map).forEach((key, value) {
        if (key != null && value != null) {
          tagsMap[key.toString()] = value.toString();
        }
      });
    }

    return SearchItem(
      name: json['name'] ?? '',
      img: json['img'] ?? '',
      src: json['src'] ?? '',
      tags: tagsMap, // 传递处理后的 tags Map
    );
  }

  // 添加 toJson 方法以便序列化
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'img': img,
      'src': src,
      'tags': tags,
    };
  }
}

class PluginSearchResponse {
  String pluginName;
  List<SearchItem> data;

  PluginSearchResponse({
    required this.pluginName,
    required this.data,
  });

  factory PluginSearchResponse.fromJson(Map<String, dynamic> json) {
    return PluginSearchResponse(
      pluginName: json['pluginName'],
      data: (json['data'] as List)
          .map((itemJson) => SearchItem.fromJson(itemJson))
          .toList(),
    );
  }
}
