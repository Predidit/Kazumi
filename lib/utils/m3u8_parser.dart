class M3u8Key {
  final String method;
  final String uri;
  final String? iv;

  M3u8Key({required this.method, required this.uri, this.iv});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is M3u8Key &&
          method == other.method &&
          uri == other.uri &&
          iv == other.iv;

  @override
  int get hashCode => Object.hash(method, uri, iv);

  @override
  String toString() {
    final sb = StringBuffer('#EXT-X-KEY:METHOD=$method,URI="$uri"');
    if (iv != null) {
      sb.write(',IV=$iv');
    }
    return sb.toString();
  }
}

class M3u8Segment {
  final double duration;
  final String uri;
  final int discontinuityGroup;
  final M3u8Key? key;

  M3u8Segment({
    required this.duration,
    required this.uri,
    required this.discontinuityGroup,
    this.key,
  });
}

class M3u8Variant {
  final int bandwidth;
  final String? resolution;
  final String uri;

  M3u8Variant({required this.bandwidth, this.resolution, required this.uri});
}

class M3u8MasterPlaylist {
  final List<M3u8Variant> variants;

  M3u8MasterPlaylist({required this.variants});

  M3u8Variant get bestVariant {
    return variants.reduce((a, b) => a.bandwidth > b.bandwidth ? a : b);
  }
}

class M3u8MediaPlaylist {
  final List<M3u8Segment> segments;
  final double targetDuration;
  final bool isVod;

  M3u8MediaPlaylist({
    required this.segments,
    required this.targetDuration,
    required this.isVod,
  });
}

enum M3u8Type { master, media }

class M3u8Parser {
  static M3u8Type detectType(String content) {
    if (content.contains('#EXT-X-STREAM-INF')) {
      return M3u8Type.master;
    }
    return M3u8Type.media;
  }

  static String resolveUrl(String baseUrl, String relativeUrl) {
    if (relativeUrl.startsWith('http://') || relativeUrl.startsWith('https://')) {
      return relativeUrl;
    }
    final baseUri = Uri.parse(baseUrl);
    if (relativeUrl.startsWith('/')) {
      return '${baseUri.scheme}://${baseUri.host}${baseUri.hasPort ? ':${baseUri.port}' : ''}$relativeUrl';
    }
    final basePath = baseUrl.substring(0, baseUrl.lastIndexOf('/') + 1);
    return '$basePath$relativeUrl';
  }

  static M3u8MasterPlaylist parseMasterPlaylist(String content, String baseUrl) {
    final lines = content.split('\n').map((l) => l.trim()).toList();
    final variants = <M3u8Variant>[];

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (line.startsWith('#EXT-X-STREAM-INF:')) {
        final attrs = line.substring('#EXT-X-STREAM-INF:'.length);
        int bandwidth = 0;
        String? resolution;

        final bandwidthMatch = RegExp(r'BANDWIDTH=(\d+)').firstMatch(attrs);
        if (bandwidthMatch != null) {
          bandwidth = int.parse(bandwidthMatch.group(1)!);
        }

        final resolutionMatch = RegExp(r'RESOLUTION=([^\s,]+)').firstMatch(attrs);
        if (resolutionMatch != null) {
          resolution = resolutionMatch.group(1);
        }

        if (i + 1 < lines.length && !lines[i + 1].startsWith('#')) {
          final uri = resolveUrl(baseUrl, lines[i + 1]);
          variants.add(M3u8Variant(bandwidth: bandwidth, resolution: resolution, uri: uri));
        }
      }
    }

    return M3u8MasterPlaylist(variants: variants);
  }

  static M3u8MediaPlaylist parseMediaPlaylist(String content, String baseUrl) {
    final lines = content.split('\n').map((l) => l.trim()).toList();
    final segments = <M3u8Segment>[];
    double targetDuration = 0;
    bool hasEndList = false;
    bool isExplicitVod = false;
    bool isLiveEvent = false;
    int currentDiscontinuityGroup = 0;
    M3u8Key? currentKey;
    double currentDuration = 0;

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];

      if (line.startsWith('#EXT-X-TARGETDURATION:')) {
        targetDuration = double.parse(line.substring('#EXT-X-TARGETDURATION:'.length));
      } else if (line == '#EXT-X-ENDLIST') {
        hasEndList = true;
      } else if (line == '#EXT-X-PLAYLIST-TYPE:VOD') {
        isExplicitVod = true;
      } else if (line == '#EXT-X-PLAYLIST-TYPE:EVENT') {
        isLiveEvent = true;
      } else if (line == '#EXT-X-DISCONTINUITY') {
        currentDiscontinuityGroup++;
      } else if (line.startsWith('#EXT-X-KEY:')) {
        currentKey = _parseKey(line, baseUrl);
      } else if (line.startsWith('#EXTINF:')) {
        final durationStr = line.substring('#EXTINF:'.length).split(',')[0];
        currentDuration = double.parse(durationStr);
      } else if (line.isNotEmpty && !line.startsWith('#')) {
        final uri = resolveUrl(baseUrl, line);
        segments.add(M3u8Segment(
          duration: currentDuration,
          uri: uri,
          discontinuityGroup: currentDiscontinuityGroup,
          key: currentKey,
        ));
        currentDuration = 0;
      }
    }

    // Consider it VOD if:
    // 1. Has #EXT-X-ENDLIST, or
    // 2. Has #EXT-X-PLAYLIST-TYPE:VOD, or
    // 3. Has finite segments and is not explicitly a live EVENT stream.
    // Many third-party video sources omit #EXT-X-ENDLIST for VOD content.
    final bool isVod = hasEndList || isExplicitVod || (!isLiveEvent && segments.isNotEmpty);

    return M3u8MediaPlaylist(
      segments: segments,
      targetDuration: targetDuration,
      isVod: isVod,
    );
  }

  static M3u8Key? _parseKey(String line, String baseUrl) {
    final attrs = line.substring('#EXT-X-KEY:'.length);

    final methodMatch = RegExp(r'METHOD=([^,]+)').firstMatch(attrs);
    final method = methodMatch?.group(1) ?? 'NONE';

    if (method == 'NONE') return null;

    final uriMatch = RegExp(r'URI="([^"]+)"').firstMatch(attrs);
    final uri = uriMatch != null ? resolveUrl(baseUrl, uriMatch.group(1)!) : '';

    final ivMatch = RegExp(r'IV=(0x[0-9a-fA-F]+)').firstMatch(attrs);
    final iv = ivMatch?.group(1);

    return M3u8Key(method: method, uri: uri, iv: iv);
  }

  static List<M3u8Key> extractUniqueKeys(M3u8MediaPlaylist playlist) {
    final seen = <String>{};
    final keys = <M3u8Key>[];
    for (final seg in playlist.segments) {
      if (seg.key != null && !seen.contains(seg.key!.uri)) {
        seen.add(seg.key!.uri);
        keys.add(seg.key!);
      }
    }
    return keys;
  }

  static String buildLocalM3u8(
    List<M3u8Segment> segments, {
    required double targetDuration,
    Map<String, String> keyUriToLocal = const {},
  }) {
    final sb = StringBuffer();
    sb.writeln('#EXTM3U');
    sb.writeln('#EXT-X-VERSION:3');
    sb.writeln('#EXT-X-TARGETDURATION:${targetDuration.ceil()}');
    sb.writeln('#EXT-X-MEDIA-SEQUENCE:0');

    int lastDiscontinuityGroup = 0;
    M3u8Key? lastKey;

    for (int i = 0; i < segments.length; i++) {
      final seg = segments[i];

      if (seg.discontinuityGroup != lastDiscontinuityGroup && i > 0) {
        sb.writeln('#EXT-X-DISCONTINUITY');
        lastDiscontinuityGroup = seg.discontinuityGroup;
      }

      if (seg.key != lastKey) {
        if (seg.key == null) {
          sb.writeln('#EXT-X-KEY:METHOD=NONE');
        } else {
          final localUri = keyUriToLocal[seg.key!.uri] ?? seg.key!.uri;
          final keySb = StringBuffer('#EXT-X-KEY:METHOD=${seg.key!.method},URI="$localUri"');
          if (seg.key!.iv != null) {
            keySb.write(',IV=${seg.key!.iv}');
          }
          sb.writeln(keySb.toString());
        }
        lastKey = seg.key;
      }

      sb.writeln('#EXTINF:${seg.duration.toStringAsFixed(6)},');
      sb.writeln('seg_${i.toString().padLeft(5, '0')}.ts');
    }

    sb.writeln('#EXT-X-ENDLIST');
    return sb.toString();
  }

  static bool _isM3u8Url(String url) {
    final path = Uri.parse(url).path.toLowerCase();
    return path.endsWith('.m3u8');
  }

  /// 展开嵌套 M3U8 片段。
  /// [fetcher] 异步回调，给定 URL 返回 M3U8 文本内容。
  /// [maxDepth] 递归深度上限，防止无限嵌套。
  static Future<List<M3u8Segment>> resolveNestedSegments(
    List<M3u8Segment> segments,
    Future<String> Function(String url) fetcher, {
    int maxDepth = 3,
  }) async {
    if (maxDepth <= 0) return segments;
    if (!segments.any((s) => _isM3u8Url(s.uri))) return segments;

    final result = <M3u8Segment>[];
    int groupOffset = 0;

    for (final seg in segments) {
      if (!_isM3u8Url(seg.uri)) {
        result.add(M3u8Segment(
          duration: seg.duration,
          uri: seg.uri,
          discontinuityGroup: seg.discontinuityGroup + groupOffset,
          key: seg.key,
        ));
        continue;
      }

      // 该 segment 的 URI 指向嵌套 m3u8，展开
      try {
        final content = await fetcher(seg.uri);
        final nested = parseMediaPlaylist(content, seg.uri);
        final resolved = await resolveNestedSegments(
          nested.segments, fetcher, maxDepth: maxDepth - 1,
        );

        if (resolved.isEmpty) continue;

        final nestedBase = seg.discontinuityGroup + groupOffset;
        int maxNestedGroup = 0;
        for (final ns in resolved) {
          if (ns.discontinuityGroup > maxNestedGroup) {
            maxNestedGroup = ns.discontinuityGroup;
          }
        }

        for (final ns in resolved) {
          result.add(M3u8Segment(
            duration: ns.duration,
            uri: ns.uri,
            discontinuityGroup: ns.discontinuityGroup + nestedBase,
            key: ns.key,
          ));
        }

        // 后续 segment 的 group 需要额外偏移，避免碰撞
        groupOffset += maxNestedGroup;
      } catch (e) {
        // 获取/解析失败，保留原始 segment
        result.add(M3u8Segment(
          duration: seg.duration,
          uri: seg.uri,
          discontinuityGroup: seg.discontinuityGroup + groupOffset,
          key: seg.key,
        ));
      }
    }

    return result;
  }
}
