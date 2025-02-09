import 'package:html/parser.dart';

class SearchMBangumiModel {
  SearchMBangumiModel({
    this.numResults,
    this.list = const <SearchMBangumiItemModel>[],
  });

  int? numResults;
  late List<SearchMBangumiItemModel> list;

  SearchMBangumiModel.fromJson(Map<String, dynamic> json) {
    numResults = (json['numResults'] as num?)?.toInt();
    list = (json['result'] as List?)
            ?.map((e) => SearchMBangumiItemModel.fromJson(e))
            .toList() ??
        <SearchMBangumiItemModel>[];
  }
}

class SearchMBangumiItemModel {
  SearchMBangumiItemModel({
    this.title,
    this.seasonId,
  });

  dynamic title;
  int? seasonId;

  SearchMBangumiItemModel.fromJson(Map<String, dynamic> json) {
    title = parse(json['title']).body?.text ?? json['title'];
    seasonId = json['season_id'];
  }
}
