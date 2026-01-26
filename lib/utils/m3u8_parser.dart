import 'package:dio/dio.dart' show Dio;

// 爬取类型
enum M3u8ParseType {
  master, // 主 M3U8 （指向子 M3U8 文件）
  media, // 直接指向媒体资源
  other, // 暂时未知，有了再加
}

class M3u8ParseResult {
  final M3u8ParseType type;
  final String baseUrl;
  // 自身名称，对于 type == M3u8ParseType.media 的情况
  // 应当下载自身以用于索引媒体切片
  final String selfName;
  // 不太确定是否会有多个子 m3u8 的情况
  final List<String>? subM3u8Urls; // 指向子 m3u8 url 地址
  final List<String>? segmentUrls; // 指向媒体切片地址

  M3u8ParseResult({
    required this.type,
    required this.baseUrl,
    required this.selfName,
    this.subM3u8Urls,
    this.segmentUrls,
  });
}

class M3u8Parser {
  static Future<M3u8ParseResult?> parse(Dio dio, String? url) async {
    try {
      if (url == null || url.isEmpty) {
        print("[Kazumi M3U8Parser]: Invalid url detected: $url");
        return null;
      }

      final baseUrl = url.substring(0, url.lastIndexOf("/") + 1).trim();
      final selfName = url.substring(url.lastIndexOf("/") + 1).trim();
      final index = (await dio.get(url)).data;
      M3u8ParseType parseType = M3u8ParseType.other;
      final List<String> segmentUrls = [];
      final List<String> subM3u8Urls = [];

      final List<String> lines = index.split('\n');
      for (int i = 0; i < lines.length; i++) {
        final line = lines[i].trim();

        // 第一个标签会指向子 m3u8 文件
        // 第二个标签则是指向媒体切片文件
        // 相同的是它们都是一行标签一行值
        if (!(line.startsWith("#EXT-X-STREAM-INF") ||
            line.startsWith("#EXTINF"))) {
          continue;
        }

        if (i + 1 >= lines.length) {
          break;
        }
        i++; // 此时 line 包含标签信息，subPath 包含文件 url 信息
        final subPath = lines[i].trim();
        // 拼接完整 URL
        final fullUrl = _getFullUrl(subPath, baseUrl);

        if (line.startsWith('#EXTINF')) {
          parseType = M3u8ParseType.media;
          segmentUrls.add(fullUrl);
        } else if (line.startsWith("#EXT-X-STREAM-INF")) {
          parseType = M3u8ParseType.master;
          subM3u8Urls.add(fullUrl);
        }
      }
      print(
          "[DEBUG]:\n\tBASE: ${baseUrl}\n\tSELF: ${selfName}\n\tSUB: ${subM3u8Urls}\n\tSEG: ${segmentUrls}");
      return M3u8ParseResult(
          type: parseType,
          baseUrl: baseUrl,
          selfName: selfName,
          subM3u8Urls: subM3u8Urls,
          segmentUrls: segmentUrls);
    } catch (e) {
      print("[Kazumi M3U8Parser]: Can't parse the m3u8 file, error: $e");
      return null;
    }
  }

  // 处理相对路径，拼接完整 URL
  static String _getFullUrl(String subPath, String baseUrl) {
    if (subPath.startsWith('http')) {
      return subPath;
    }
    return Uri.parse(baseUrl).resolve(subPath).toString();
  }
}
