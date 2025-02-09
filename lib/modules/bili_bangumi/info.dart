class BangumiInfoModel {
  BangumiInfoModel({
    this.episodes,
  });

  List<EpisodeItem>? episodes;

  BangumiInfoModel.fromJson(Map<String, dynamic> json) {
    episodes = (json['episodes'] as List?)
        ?.map<EpisodeItem>((e) => EpisodeItem.fromJson(e))
        .toList();
  }
}

class EpisodeItem {
  EpisodeItem({
    this.cid,
    this.showTitle,
  });

  int? cid;
  String? showTitle;

  EpisodeItem.fromJson(Map<String, dynamic> json) {
    cid = json['cid'];
    showTitle = json['show_title'];
  }
}
