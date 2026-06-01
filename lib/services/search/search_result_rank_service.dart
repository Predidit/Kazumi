import 'dart:math';

import 'package:kazumi/utils/string_similarity.dart';

/// 根据搜索词条与别名对检索结果进行权重排序。
class SearchResultRankService {
  SearchResultRankService({
    required String searchTerm,
    List<String> aliases = const [],
  }) : _weightedTerms = _buildWeightedTerms(searchTerm, aliases);

  final List<_WeightedTerm> _weightedTerms;

  static const _searchTermWeight = 100.0;
  static const _aliasWeight = 100.0;

  /// 按相关度降序排列 [items]，相关度相同时保持原顺序。
  List<T> sort<T>(
      List<T> items,
      String Function(T item) titleSelector,
      ) {
    if (_weightedTerms.isEmpty || items.length <= 1) {
      return items;
    }

    final indexed = items.asMap().entries.toList();
    final scores = {
      for (final entry in indexed)
        entry.key: computeScore(titleSelector(entry.value)),
    };

    indexed.sort((a, b) {
      final scoreCompare = scores[b.key]!.compareTo(scores[a.key]!);
      if (scoreCompare != 0) {
        return scoreCompare;
      }
      return a.key.compareTo(b.key);
    });
    return indexed.map((entry) => entry.value).toList();
  }

  /// 返回 0~1 的匹配度
  double computeMatchRatio(String itemName) {
    if (_weightedTerms.isEmpty || itemName.isEmpty) {
      return 0;
    }

    final normalizedItem = _normalize(itemName);
    final itemProfile = _TitleSeasonProfile.parse(itemName);
    var maxRatio = 0.0;

    for (final term in _weightedTerms) {
      final score = _pairScore(
        normalizedItem,
        term.normalized,
        term.weight,
        itemProfile: itemProfile,
        termProfile: term.profile,
      );
      maxRatio = max(maxRatio, score / term.weight);
    }

    return maxRatio.clamp(0.0, 1.0);
  }

  /// 计算单条结果与所有词条的最高匹配得分。
  double computeScore(String itemName) {
    if (_weightedTerms.isEmpty || itemName.isEmpty) {
      return 0;
    }

    final normalizedItem = _normalize(itemName);
    final itemProfile = _TitleSeasonProfile.parse(itemName);
    var maxScore = 0.0;

    for (final term in _weightedTerms) {
      maxScore = max(
        maxScore,
        _pairScore(
          normalizedItem,
          term.normalized,
          term.weight,
          itemProfile: itemProfile,
          termProfile: term.profile,
        ),
      );
    }

    return maxScore;
  }

  double _pairScore(
      String item,
      String term,
      double weight, {
        required _TitleSeasonProfile itemProfile,
        required _TitleSeasonProfile termProfile,
      }) {
    final seasonFactor =
    _TitleSeasonProfile.alignmentFactor(termProfile, itemProfile);

    late final double rawScore;
    if (item == term) {
      rawScore = weight;
    } else if (item.contains(term)) {
      rawScore = weight *
          (0.85 + 0.13 * (term.length / item.length).clamp(0.0, 1.0));
    } else if (term.contains(item)) {
      rawScore =
          weight * 0.7 * (item.length / term.length).clamp(0.5, 1.0);
    } else if (itemProfile.baseTitle.isNotEmpty &&
        termProfile.baseTitle.isNotEmpty &&
        itemProfile.baseTitle == termProfile.baseTitle) {
      rawScore = weight * 0.92;
    } else {
      final windowSimilarity = _bestWindowSimilarity(item, term);
      if (windowSimilarity >= 0.75) {
        rawScore = weight * windowSimilarity * 0.9;
      } else {
        final charCoverage = _orderedCharCoverage(item, term);
        rawScore = charCoverage >= 0.8
            ? weight * charCoverage * 0.82
            : weight * calculateSimilarity(item, term);
      }
    }

    return rawScore * seasonFactor;
  }

  /// 在较长标题中寻找与词条最相似的片段，避免季数/标签稀释整串相似度。
  static double _bestWindowSimilarity(String item, String term) {
    if (term.isEmpty || item.isEmpty) {
      return 0;
    }
    if (term.length >= item.length) {
      return calculateSimilarity(item, term);
    }

    var best = 0.0;
    final maxWindow = min(item.length, term.length + 6);
    for (var windowSize = term.length; windowSize <= maxWindow; windowSize++) {
      for (var start = 0; start <= item.length - windowSize; start++) {
        final window = item.substring(start, start + windowSize);
        best = max(best, calculateSimilarity(window, term));
      }
    }
    return best;
  }

  /// 词条字符按顺序出现在结果标题中的比例。
  static double _orderedCharCoverage(String item, String term) {
    if (term.isEmpty) {
      return 0;
    }

    var termIndex = 0;
    for (var i = 0; i < item.length && termIndex < term.length; i++) {
      if (item[i] == term[termIndex]) {
        termIndex++;
      }
    }
    return termIndex / term.length;
  }

  static List<_WeightedTerm> _buildWeightedTerms(
      String searchTerm,
      List<String> aliases,
      ) {
    final terms = <_WeightedTerm>[];
    final seen = <String>{};

    void addTerm(String text, double weight) {
      final normalized = _normalize(text);
      if (normalized.isEmpty || seen.contains(normalized)) {
        return;
      }
      seen.add(normalized);
      terms.add(_WeightedTerm(text: text, weight: weight));
    }

    addTerm(searchTerm, _searchTermWeight);
    for (final alias in aliases) {
      addTerm(alias, _aliasWeight);
    }

    return terms;
  }

  static String _normalize(String text) {
    final s = text.toLowerCase().replaceAll(RegExp(r'\s+'), '');
    return s.replaceAll(RegExp(r'[^0-9a-z\u4E00-\u9FFF\u3040-\u309F\u30A0-\u30FF]+'), '');
  }
}

enum _SeasonMarkerKind {
  none,
  numbered,
  finalSeason,
  oad,
  movie,
  special,
  spinoff,
}

class _TitleSeasonProfile {
  const _TitleSeasonProfile({
    required this.baseTitle,
    required this.markerKind,
    this.seasonNumber,
  });

  static final _leadingNoisePattern = RegExp(
    r'^(?:\d{4}年)?(?:\d{1,2}月)?(?:新番|动画|动漫|tv)',
  );
  static final _numberedSeasonPattern =
  RegExp(r'第([一二三四五六七八九十\d]+)[季部]');
  static final _latinSeasonPattern = RegExp(r'(?:season|part)([1-9]\d*)');
  static final _qualityNoisePattern = RegExp(
    r'完整版|无修正|中文字幕|高清|超清|抢先版|同步播出|独家|连载|1080[pP]|720[pP]',
  );

  static const _markerPatterns = <(_SeasonMarkerKind, String)>[
    (_SeasonMarkerKind.finalSeason, r'最终季|完结季|thefinalseason|finalseason'),
    (_SeasonMarkerKind.oad, r'oad|ova'),
    (_SeasonMarkerKind.movie, r'剧场版|劇場版|movie'),
    (_SeasonMarkerKind.spinoff, r'编年史|外传|前传|续篇|回忆录|无悔的选择'),
    (_SeasonMarkerKind.special, r'特别篇|总集篇|合集|sp|special'),
  ];

  final String baseTitle;
  final _SeasonMarkerKind markerKind;
  final int? seasonNumber;

  bool get hasSeasonMarker => markerKind != _SeasonMarkerKind.none;

  static _TitleSeasonProfile parse(String text) {
    var work = SearchResultRankService._normalize(text);
    var markerKind = _SeasonMarkerKind.none;
    int? seasonNumber;

    work = work.replaceAll(_leadingNoisePattern, '');

    final numberedMatch = _numberedSeasonPattern.firstMatch(work);
    if (numberedMatch != null) {
      markerKind = _SeasonMarkerKind.numbered;
      seasonNumber = _parseNumberToken(numberedMatch.group(1)!);
      work = work.replaceAll(numberedMatch.group(0)!, '');
    } else {
      for (final (kind, pattern) in _markerPatterns) {
        final regex = RegExp(pattern, caseSensitive: false);
        if (regex.hasMatch(work)) {
          markerKind = kind;
          work = work.replaceAll(regex, '');
          break;
        }
      }

      if (markerKind == _SeasonMarkerKind.none) {
        final latinSeasonMatch = _latinSeasonPattern.firstMatch(work);
        if (latinSeasonMatch != null) {
          markerKind = _SeasonMarkerKind.numbered;
          seasonNumber = int.tryParse(latinSeasonMatch.group(1)!);
          work = work.replaceAll(latinSeasonMatch.group(0)!, '');
        }
      }
    }

    work = work.replaceAll(_qualityNoisePattern, '');

    return _TitleSeasonProfile(
      baseTitle: work,
      markerKind: markerKind,
      seasonNumber: seasonNumber,
    );
  }

  /// 搜索词与结果季数/类型对齐系数。
  static double alignmentFactor(
      _TitleSeasonProfile search,
      _TitleSeasonProfile result,
      ) {
    if (!search.hasSeasonMarker && !result.hasSeasonMarker) {
      return 1;
    }

    if (!search.hasSeasonMarker && result.hasSeasonMarker) {
      return switch (result.markerKind) {
        _SeasonMarkerKind.numbered => 0.88,
        _SeasonMarkerKind.finalSeason => 0.86,
        _SeasonMarkerKind.oad => 0.8,
        _SeasonMarkerKind.movie => 0.78,
        _SeasonMarkerKind.special => 0.76,
        _SeasonMarkerKind.spinoff => 0.72,
        _ => 0.85,
      };
    }

    if (search.hasSeasonMarker && !result.hasSeasonMarker) {
      return 0.8;
    }

    if (search.markerKind == result.markerKind) {
      if (search.markerKind == _SeasonMarkerKind.numbered) {
        return search.seasonNumber == result.seasonNumber ? 1 : 0.52;
      }
      return 1;
    }

    if (search.markerKind == _SeasonMarkerKind.numbered &&
        result.markerKind == _SeasonMarkerKind.finalSeason) {
      return 0.62;
    }

    if (search.markerKind == _SeasonMarkerKind.finalSeason &&
        result.markerKind == _SeasonMarkerKind.numbered) {
      return 0.58;
    }

    return 0.5;
  }

  static int? _parseNumberToken(String token) {
    if (RegExp(r'^\d+$').hasMatch(token)) {
      return int.tryParse(token);
    }

    const digitMap = {
      '一': 1,
      '二': 2,
      '三': 3,
      '四': 4,
      '五': 5,
      '六': 6,
      '七': 7,
      '八': 8,
      '九': 9,
    };

    if (token.length == 1) {
      if (token == '十') {
        return 10;
      }
      return digitMap[token];
    }

    if (token.startsWith('十') && token.length == 2) {
      return 10 + (digitMap[token[1]] ?? 0);
    }

    if (token.endsWith('十') && token.length == 2) {
      return (digitMap[token[0]] ?? 0) * 10;
    }

    if (token.length == 3 && token[1] == '十') {
      final tens = digitMap[token[0]] ?? 0;
      final ones = digitMap[token[2]] ?? 0;
      return tens * 10 + ones;
    }

    return null;
  }
}

class _WeightedTerm {
  _WeightedTerm({
    required this.text,
    required this.weight,
  })  : normalized = SearchResultRankService._normalize(text),
        profile = _TitleSeasonProfile.parse(text);

  final String text;
  final String normalized;
  final _TitleSeasonProfile profile;
  final double weight;
}
