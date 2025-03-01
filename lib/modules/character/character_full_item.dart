class CharacterFullItem {
  final int id;
  final String name;
  final String nameCN;
  final String info;
  final String summary;
  final String image;

  CharacterFullItem({
    required this.id,
    required this.name,
    required this.nameCN,
    required this.info,
    required this.summary,
    required this.image,
  });

  factory CharacterFullItem.fromJson(Map<String, dynamic> json) {
    return CharacterFullItem(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      nameCN: json['nameCN'] ?? '',
      info: json['info'] ?? '',
      summary: json['summary'] ?? '',
      image: json['images']['large'] ?? '',
    );
  }

  factory CharacterFullItem.fromTemplate() {
    return CharacterFullItem(
      id: 0,
      name: '',
      nameCN: '',
      info: '',
      summary: '',
      image: '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'nameCN': nameCN,
      'info': info,
      'summary': summary,
    };
  }
}
