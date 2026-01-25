import 'package:antlr4/antlr4.dart';
import 'package:dio/dio.dart' show Dio;

// TODO: M3U8 有点暗坑，主要在于主 m3u8 和从 m3u8 的区别
/// 主 m3u8 文件会带有 #EXT-X-STREAM-INF 这种标签头，此时这个文件会指向另一个 m3u8 文件
/// 此时从 m3u8 文件中会带有 #EXTINF 这种标签头，此时它就指向了 ts 文件
/// 为了简化判断，个人认为可以在读到 #EXTINF 这种标签头时
/// 就直接下载 ts 文件，否则则需要解析 m3u8 文件

// TODO: 也许可能要大规模重构了
// 爬取类型
enum M3u8ParseType {
  master, // 主 M3U8 （指向子 M3U8 文件）
  media, // 直接指向媒体资源
  other, // 暂时未知，有了再加
}

class M3u8ParseResult {
  final M3u8ParseType type;
  final String baseUrl;
  // 不太确定是否会有多个子 m3u8 的情况
  final List<String>? subM3u8Urls; // 指向子 m3u8 url 地址
  final List<String>? segmentUrls; // 指向媒体切片地址

  M3u8ParseResult({
    required this.type,
    required this.baseUrl,
    this.subM3u8Urls,
    this.segmentUrls,
  });
}

class M3u8Parser {
  static Future<M3u8ParseResult?> parse(Dio dio, String url) async {
    try {
      // 由于依赖 `resolve` 方法，必须要把 `/` 也包括进来
      final baseUrl = url.substring(0, url.lastIndexOf("/") + 1).trim();
      print("[DEBUG]: URL: ${url}");

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
          "[DEBUG]:\n\tBASE: ${baseUrl}\n\tSUB: ${subM3u8Urls}\n\tSEG: ${segmentUrls}");
      return M3u8ParseResult(
          type: parseType,
          baseUrl: baseUrl,
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
