import 'dart:convert';

class ImageSearchItem {
  final int? frameCount;
  final String? error;
  final List<ResultItem>? result;

  ImageSearchItem({this.frameCount, this.error, this.result});

  factory ImageSearchItem.fromJson(Map<String, dynamic> json) {
    return ImageSearchItem(
      frameCount: json['frameCount'] as int?,
      error: json['error'] as String?,
      result: json['result'] == null
          ? null
          : (json['result'] as List)
              .map((e) => ResultItem.fromJson(e as Map<String, dynamic>))
              .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'frameCount': frameCount,
        'error': error,
        'result': result?.map((e) => e.toJson()).toList(),
      };

  @override
  String toString() => jsonEncode(toJson());
}

class ResultItem {
  final Anilist? anilist;
  final String? filename;
  final dynamic episode; // num, List<num> or null
  final double? from;
  final double? at;
  final double? to;
  final double? duration;
  final double? similarity;
  final String? video;
  final String? image;

  ResultItem({
    this.anilist,
    this.filename,
    this.episode,
    this.from,
    this.at,
    this.to,
    this.duration,
    this.similarity,
    this.video,
    this.image,
  });

  factory ResultItem.fromJson(Map<String, dynamic> json) {
    dynamic ep = json['episode'];
    if (ep is List) {
      ep = ep.whereType<num>().toList();
    } else if (ep is! num) {
      ep = null;
    }

    return ResultItem(
      anilist: json['anilist'] == null
          ? null
          : Anilist.fromJson(json['anilist'] as Map<String, dynamic>),
      filename: json['filename'] as String?,
      episode: ep,
      from: (json['from'] as num?)?.toDouble(),
      at: (json['at'] as num?)?.toDouble(),
      to: (json['to'] as num?)?.toDouble(),
      duration: (json['duration'] as num?)?.toDouble(),
      similarity: (json['similarity'] as num?)?.toDouble(),
      video: json['video'] as String?,
      image: json['image'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'anilist': anilist?.toJson(),
        'filename': filename,
        'episode': episode,
        'from': from,
        'at': at,
        'to': to,
        'duration': duration,
        'similarity': similarity,
        'video': video,
        'image': image,
      };
}

class Anilist {
  final int? id;
  final String? type;
  final int? idMal;
  final AnilistTitle? title;
  final String? format;
  final List<String>? genres;
  final String? season;
  final String? source;
  final String? status;
  final DateInfo? endDate;
  final DateInfo? startDate;
  final bool? isAdult;
  final String? siteUrl;
  final Studios? studios;
  final int? duration;
  final int? episodes;
  final List<String>? synonyms;
  final Relations? relations;
  final int? seasonInt;
  final CoverImage? coverImage;
  final int? popularity;
  final int? seasonYear;
  final String? bannerImage;
  final List<ExternalLink>? externalLinks;
  final String? countryOfOrigin;
  final List<String>? synonymsChinese;

  Anilist({
    this.id,
    this.type,
    this.idMal,
    this.title,
    this.format,
    this.genres,
    this.season,
    this.source,
    this.status,
    this.endDate,
    this.startDate,
    this.isAdult,
    this.siteUrl,
    this.studios,
    this.duration,
    this.episodes,
    this.synonyms,
    this.relations,
    this.seasonInt,
    this.coverImage,
    this.popularity,
    this.seasonYear,
    this.bannerImage,
    this.externalLinks,
    this.countryOfOrigin,
    this.synonymsChinese,
  });

  factory Anilist.fromJson(Map<String, dynamic> json) {
    return Anilist(
      id: json['id'] as int?,
      type: json['type'] as String?,
      idMal: json['idMal'] as int?,
      title: json['title'] == null
          ? null
          : AnilistTitle.fromJson(json['title'] as Map<String, dynamic>),
      format: json['format'] as String?,
      genres: json['genres'] == null
          ? null
          : List<String>.from(json['genres'] as List),
      season: json['season'] as String?,
      source: json['source'] as String?,
      status: json['status'] as String?,
      endDate: json['endDate'] == null
          ? null
          : DateInfo.fromJson(json['endDate'] as Map<String, dynamic>),
      startDate: json['startDate'] == null
          ? null
          : DateInfo.fromJson(json['startDate'] as Map<String, dynamic>),
      isAdult: json['isAdult'] as bool?,
      siteUrl: json['siteUrl'] as String?,
      studios: json['studios'] == null
          ? null
          : Studios.fromJson(json['studios'] as Map<String, dynamic>),
      duration: json['duration'] as int?,
      episodes: json['episodes'] as int?,
      synonyms: json['synonyms'] == null
          ? null
          : List<String>.from(json['synonyms'] as List),
      relations: json['relations'] == null
          ? null
          : Relations.fromJson(json['relations'] as Map<String, dynamic>),
      seasonInt: json['seasonInt'] as int?,
      coverImage: json['coverImage'] == null
          ? null
          : CoverImage.fromJson(json['coverImage'] as Map<String, dynamic>),
      popularity: json['popularity'] as int?,
      seasonYear: json['seasonYear'] as int?,
      bannerImage: json['bannerImage'] as String?,
      externalLinks: json['externalLinks'] == null
          ? null
          : (json['externalLinks'] as List)
              .map((e) => ExternalLink.fromJson(e as Map<String, dynamic>))
              .toList(),
      countryOfOrigin: json['countryOfOrigin'] as String?,
      synonymsChinese: json['synonyms_chinese'] == null
          ? null
          : List<String>.from(json['synonyms_chinese'] as List),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'idMal': idMal,
        'title': title?.toJson(),
        'format': format,
        'genres': genres,
        'season': season,
        'source': source,
        'status': status,
        'endDate': endDate?.toJson(),
        'startDate': startDate?.toJson(),
        'isAdult': isAdult,
        'siteUrl': siteUrl,
        'studios': studios?.toJson(),
        'duration': duration,
        'episodes': episodes,
        'synonyms': synonyms,
        'relations': relations?.toJson(),
        'seasonInt': seasonInt,
        'coverImage': coverImage?.toJson(),
        'popularity': popularity,
        'seasonYear': seasonYear,
        'bannerImage': bannerImage,
        'externalLinks': externalLinks?.map((e) => e.toJson()).toList(),
        'countryOfOrigin': countryOfOrigin,
        'synonyms_chinese': synonymsChinese,
      };
}

class AnilistTitle {
  final String? native;
  final String? romaji;
  final String? chinese;
  final String? english;

  AnilistTitle({this.native, this.romaji, this.chinese, this.english});

  factory AnilistTitle.fromJson(Map<String, dynamic> json) => AnilistTitle(
        native: json['native'] as String?,
        romaji: json['romaji'] as String?,
        chinese: json['chinese'] as String?,
        english: json['english'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'native': native,
        'romaji': romaji,
        'chinese': chinese,
        'english': english,
      };
}

class DateInfo {
  final int? day;
  final int? year;
  final int? month;

  DateInfo({this.day, this.year, this.month});

  factory DateInfo.fromJson(Map<String, dynamic> json) => DateInfo(
        day: json['day'] as int?,
        year: json['year'] as int?,
        month: json['month'] as int?,
      );

  Map<String, dynamic> toJson() => {'day': day, 'year': year, 'month': month};
}

class CoverImage {
  final String? color;
  final String? large;
  final String? medium;
  final String? extraLarge;

  CoverImage({this.color, this.large, this.medium, this.extraLarge});

  factory CoverImage.fromJson(Map<String, dynamic> json) => CoverImage(
        color: json['color'] as String?,
        large: json['large'] as String?,
        medium: json['medium'] as String?,
        extraLarge: json['extraLarge'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'color': color,
        'large': large,
        'medium': medium,
        'extraLarge': extraLarge
      };
}

class Studios {
  final List<StudioEdge>? edges;

  Studios({this.edges});

  factory Studios.fromJson(Map<String, dynamic> json) => Studios(
        edges: json['edges'] == null
            ? null
            : (json['edges'] as List)
                .map((e) => StudioEdge.fromJson(e as Map<String, dynamic>))
                .toList(),
      );

  Map<String, dynamic> toJson() =>
      {'edges': edges?.map((e) => e.toJson()).toList()};
}

class StudioEdge {
  final StudioNode? node;
  final bool? isMain;

  StudioEdge({this.node, this.isMain});

  factory StudioEdge.fromJson(Map<String, dynamic> json) => StudioEdge(
        node: json['node'] == null
            ? null
            : StudioNode.fromJson(json['node'] as Map<String, dynamic>),
        isMain: json['isMain'] as bool?,
      );

  Map<String, dynamic> toJson() => {'node': node?.toJson(), 'isMain': isMain};
}

class StudioNode {
  final int? id;
  final String? name;
  final String? siteUrl;

  StudioNode({this.id, this.name, this.siteUrl});

  factory StudioNode.fromJson(Map<String, dynamic> json) => StudioNode(
        id: json['id'] as int?,
        name: json['name'] as String?,
        siteUrl: json['siteUrl'] as String?,
      );

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'siteUrl': siteUrl};
}

class Relations {
  final List<RelationEdge>? edges;

  Relations({this.edges});

  factory Relations.fromJson(Map<String, dynamic> json) => Relations(
        edges: json['edges'] == null
            ? null
            : (json['edges'] as List)
                .map((e) => RelationEdge.fromJson(e as Map<String, dynamic>))
                .toList(),
      );

  Map<String, dynamic> toJson() =>
      {'edges': edges?.map((e) => e.toJson()).toList()};
}

class RelationEdge {
  final RelationNode? node;
  final String? relationType;

  RelationEdge({this.node, this.relationType});

  factory RelationEdge.fromJson(Map<String, dynamic> json) => RelationEdge(
        node: json['node'] == null
            ? null
            : RelationNode.fromJson(json['node'] as Map<String, dynamic>),
        relationType: json['relationType'] as String?,
      );

  Map<String, dynamic> toJson() =>
      {'node': node?.toJson(), 'relationType': relationType};
}

class RelationNode {
  final int? id;
  final AnilistTitle? title;

  RelationNode({this.id, this.title});

  factory RelationNode.fromJson(Map<String, dynamic> json) => RelationNode(
        id: json['id'] as int?,
        title: json['title'] == null
            ? null
            : AnilistTitle.fromJson(json['title'] as Map<String, dynamic>),
      );

  Map<String, dynamic> toJson() => {'id': id, 'title': title?.toJson()};
}

class ExternalLink {
  final int? id;
  final String? url;
  final String? site;

  ExternalLink({this.id, this.url, this.site});

  factory ExternalLink.fromJson(Map<String, dynamic> json) => ExternalLink(
        id: json['id'] as int?,
        url: json['url'] as String?,
        site: json['site'] as String?,
      );

  Map<String, dynamic> toJson() => {'id': id, 'url': url, 'site': site};
}
