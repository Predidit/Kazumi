class RuleMode {
  static const String xpath = 'xpath';
  static const String api = 'api';

  static String normalize(Object? value) {
    return value == api ? api : xpath;
  }
}

class ApiBodyType {
  static const String none = 'none';
  static const String json = 'json';
  static const String form = 'form';

  static String normalize(Object? value) {
    return switch (value) {
      json => json,
      form => form,
      _ => none,
    };
  }
}

class ApiChapterFormat {
  static const String nested = 'nested';
  static const String delimited = 'delimited';

  static String normalize(Object? value) {
    return value == delimited ? delimited : nested;
  }
}

class ApiRequestConfig {
  String method;
  String url;
  Map<String, dynamic> headers;
  Map<String, dynamic> query;
  String bodyType;
  dynamic body;

  ApiRequestConfig({
    this.method = 'GET',
    this.url = '',
    Map<String, dynamic>? headers,
    Map<String, dynamic>? query,
    this.bodyType = ApiBodyType.none,
    this.body,
  })  : headers = headers ?? <String, dynamic>{},
        query = query ?? <String, dynamic>{};

  factory ApiRequestConfig.fromJson(Map<String, dynamic> json) {
    return ApiRequestConfig(
      method: (json['method'] as String? ?? 'GET').toUpperCase(),
      url: json['url'] as String? ?? '',
      headers: _asStringMap(json['headers']),
      query: _asStringMap(json['query']),
      bodyType: ApiBodyType.normalize(json['bodyType']),
      body: json['body'],
    );
  }

  Map<String, dynamic> toJson() => {
        'method': method.toUpperCase(),
        'url': url,
        'headers': headers,
        'query': query,
        'bodyType': bodyType,
        if (bodyType != ApiBodyType.none && body != null) 'body': body,
      };
}

class ApiSearchConfig {
  ApiRequestConfig request;
  String listPath;
  String namePath;
  String sourcePath;

  ApiSearchConfig({
    ApiRequestConfig? request,
    this.listPath = r'$.data[*]',
    this.namePath = r'$.name',
    this.sourcePath = r'$.url',
  }) : request = request ?? ApiRequestConfig();

  factory ApiSearchConfig.fromJson(Map<String, dynamic> json) {
    return ApiSearchConfig(
      request: ApiRequestConfig.fromJson(_asStringMap(json['request'])),
      listPath: json['listPath'] as String? ?? r'$.data[*]',
      namePath: json['namePath'] as String? ?? r'$.name',
      sourcePath: json['sourcePath'] as String? ?? r'$.url',
    );
  }

  Map<String, dynamic> toJson() => {
        'request': request.toJson(),
        'listPath': listPath,
        'namePath': namePath,
        'sourcePath': sourcePath,
      };
}

class ApiEpisodePageConfig {
  /// Template for the final playback page URL.
  String url;

  /// Query parameters rendered with response and episode index variables.
  Map<String, dynamic> query;

  ApiEpisodePageConfig({
    this.url = '',
    Map<String, dynamic>? query,
  }) : query = query ?? <String, dynamic>{};

  factory ApiEpisodePageConfig.fromJson(Map<String, dynamic> json) {
    return ApiEpisodePageConfig(
      url: json['url'] as String? ?? '',
      query: _asStringMap(json['query']),
    );
  }

  Map<String, dynamic> toJson() => {
        'url': url,
        'query': query,
      };
}

class ApiChapterConfig {
  ApiRequestConfig request;
  String format;

  // Nested JSON response mapping.
  String roadsPath;
  String roadNamePath;
  String episodesPath;
  String episodeNamePath;

  /// JSONPath for a playback entry URL (page URL or direct media URL).
  /// May be empty when [episodePage] constructs the final playback page URL.
  String episodeUrlPath;

  // Delimited string response mapping.
  String roadNamesPath;
  String roadEpisodesPath;
  String roadSeparator;
  String episodeSeparator;
  String fieldSeparator;

  String defaultRoadName;
  Map<String, String> variables;

  /// Optional final playback page template used instead of a response URL.
  ApiEpisodePageConfig? episodePage;

  ApiChapterConfig({
    ApiRequestConfig? request,
    this.format = ApiChapterFormat.nested,
    this.roadsPath = r'$.data.roads[*]',
    this.roadNamePath = r'$.name',
    this.episodesPath = r'$.episodes[*]',
    this.episodeNamePath = r'$.name',
    this.episodeUrlPath = r'$.url',
    this.roadNamesPath = '',
    this.roadEpisodesPath = '',
    this.roadSeparator = r'$$$',
    this.episodeSeparator = '#',
    this.fieldSeparator = r'$',
    this.defaultRoadName = '播放线路',
    Map<String, String>? variables,
    this.episodePage,
  })  : request = request ?? ApiRequestConfig(),
        variables = variables ?? <String, String>{};

  factory ApiChapterConfig.fromJson(Map<String, dynamic> json) {
    final rawVariables = _asStringMap(json['variables']);
    return ApiChapterConfig(
      request: ApiRequestConfig.fromJson(_asStringMap(json['request'])),
      format: ApiChapterFormat.normalize(json['format']),
      roadsPath: json['roadsPath'] as String? ?? r'$.data.roads[*]',
      roadNamePath: json['roadNamePath'] as String? ?? r'$.name',
      episodesPath: json['episodesPath'] as String? ?? r'$.episodes[*]',
      episodeNamePath: json['episodeNamePath'] as String? ?? r'$.name',
      episodeUrlPath: json['episodeUrlPath'] as String? ?? r'$.url',
      roadNamesPath: json['roadNamesPath'] as String? ?? '',
      roadEpisodesPath: json['roadEpisodesPath'] as String? ?? '',
      roadSeparator: json['roadSeparator'] as String? ?? r'$$$',
      episodeSeparator: json['episodeSeparator'] as String? ?? '#',
      fieldSeparator: json['fieldSeparator'] as String? ?? r'$',
      defaultRoadName: json['defaultRoadName'] as String? ?? '播放线路',
      variables: rawVariables.map(
        (key, value) => MapEntry(key, value.toString()),
      ),
      episodePage: json['episodePage'] is Map
          ? ApiEpisodePageConfig.fromJson(_asStringMap(json['episodePage']))
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'request': request.toJson(),
        'format': format,
        'roadsPath': roadsPath,
        'roadNamePath': roadNamePath,
        'episodesPath': episodesPath,
        'episodeNamePath': episodeNamePath,
        'episodeUrlPath': episodeUrlPath,
        'roadNamesPath': roadNamesPath,
        'roadEpisodesPath': roadEpisodesPath,
        'roadSeparator': roadSeparator,
        'episodeSeparator': episodeSeparator,
        'fieldSeparator': fieldSeparator,
        'defaultRoadName': defaultRoadName,
        'variables': variables,
        if (episodePage != null) 'episodePage': episodePage!.toJson(),
      };
}

Map<String, dynamic> _asStringMap(Object? value) {
  if (value is! Map) return <String, dynamic>{};
  return value.map((key, value) => MapEntry(key.toString(), value));
}
