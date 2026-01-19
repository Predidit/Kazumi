import 'package:dio/dio.dart' show Dio;

/// TODO: M3U8 有点暗坑，主要在于主 m3u8 和从 m3u8 的区别
/// 主 m3u8 文件会带有 #EXT-X-STREAM-INF 这种标签头，此时这个文件会指向另一个 m3u8 文件
/// 此时从 m3u8 文件中会带有 #EXTINF 这种标签头，此时它就指向了 ts 文件
/// 为了简化判断，个人认为可以在读到 #EXTINF 这种标签头时
/// 就直接下载 ts 文件，否则则需要解析 m3u8 文件


// 数据模型
class M3U8Data {
  final List<M3U8Segment> segments;
  final String? keyUrl; // 加密密钥 URL（AES-128）
  final String? iv; // 初始化向量

  M3U8Data({required this.segments, this.keyUrl, this.iv});
}

class M3U8Segment {
  final String url;
  final double duration;

  M3U8Segment({required this.url, required this.duration});
}

class M3U8Parser {
  static Future<M3U8Data?> parse(Dio dio, String url) async {
    final src = await _parseIndex(dio, url);

    if (src == null) {
      print("[kazumi downloader]: 无法获取 m3u8 数据");
      return null;
    }

    final baseUrl = src["baseUrl"];
    final hlsPath = src["hlsPath"];
    final segmentSrc = src["segmentSrc"];

    final m3u8Content = (await dio.get(segmentSrc!)).data;
    final List<String> lines = m3u8Content.split('\n');
    final segments = <M3U8Segment>[];
    String? keyUrl; // AES 密钥 URL
    String? iv; // 初始化向量

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.startsWith('#EXT-X-KEY')) {
        // 解析加密信息（如 AES-128）
        final keyParams = _parseKeyParams(line);
        keyUrl = keyParams['URI']?.replaceAll('"', '');
        iv = keyParams['IV']?.replaceAll('0x', '');
      } else if (line.startsWith('#EXTINF:')) {
        // 解析分片时长和 URL
        final duration = double.parse(line.split(':')[1].split(',')[0]);
        final tsUrl = lines[i + 1].trim();

        // 拼接完整 URL（处理相对路径）
        final fullUrl = _getFullUrl("${hlsPath!}/$tsUrl", baseUrl!);
        segments.add(M3U8Segment(url: fullUrl, duration: duration));
        i++; // 跳过下一行的 TS URL
      }
    }

    return M3U8Data(
      segments: segments,
      keyUrl: keyUrl != null ? _getFullUrl(keyUrl, baseUrl!) : null,
      iv: iv,
    );
  }

  static Future<Map<String, String>?> _parseIndex(
      Dio dio, String indexUrl) async {
        // 由于依赖 `resolve` 方法，必须要把 `/` 也包括进来
    String baseUrl = indexUrl.substring(0, indexUrl.lastIndexOf("/") + 1).trim();
    final index = (await dio.get(indexUrl)).data;

    final List<String> lines = index.split('\n');
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.endsWith('.m3u8')) {
        final res = {
          "baseUrl": baseUrl,
          "hlsPath": line.substring(0, line.lastIndexOf("/")),
          "segmentSrc": _getFullUrl(line, baseUrl)
        };
        print(res);
        return res;
      }
    }
    return null;
  }

  // 解析 #EXT-X-KEY 参数（如 URI、IV）
  static Map<String, String> _parseKeyParams(String line) {
    final params = <String, String>{};
    final parts = line.split(';');
    for (final part in parts) {
      if (part.contains('=')) {
        final keyValue = part.split('=');
        params[keyValue[0].trim()] = keyValue[1].trim();
      }
    }
    return params;
  }

  // 处理相对路径，拼接完整 URL
  static String _getFullUrl(String tsUrl, String baseUrl) {
    if (tsUrl.startsWith('http')) {
      return tsUrl;
    }
    return Uri.parse(baseUrl).resolve(tsUrl).toString();
  }
}
