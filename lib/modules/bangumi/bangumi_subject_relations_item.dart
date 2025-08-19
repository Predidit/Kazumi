class BangumiSubjectRelationItem {
  int id;

  int type;

  String name;

  String nameCn;

  String relation;

  Map<String, String> images;

  BangumiSubjectRelationItem({
    required this.id,
    required this.type,
    required this.name,
    required this.nameCn,
    required this.relation,
    required this.images,
  });

  factory BangumiSubjectRelationItem.fromJson(Map<String, dynamic> json) {
    return BangumiSubjectRelationItem(
      id: json['id'],
      type: json['type'] ?? '2',
      name: json['name'] ?? '',
      nameCn: json['name_cn'] ?? '',
      relation: json['relation'] ?? '',
      images: Map<String, String>.from(
        json['images'] ??
            {
              "large": json['image'] ?? '',
              "common": '',
              "medium": '',
              "small": '',
              "grid": ''
            },
      ),
    );
  }

  @override
  String toString() {
    return 'BangumiSubjectRelationItem{id: $id, type: $type, name: $name, nameCn: $nameCn,relation: $relation, images: $images}';
  }
}
