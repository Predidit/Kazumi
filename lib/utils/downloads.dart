import 'dart:io';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:kazumi/utils/m3u8_parser.dart';
import 'package:path/path.dart' as path;

/// 测试用例：
/// mp4 文件："https://v16.toutiao50.com/aab47935d4a24f11001d394a660fb58b/6979ab77/video/tos/alisg/tos-alisg-v-0051c001-sg/oMJvDJeGgEoTbUPGCtpfPleWKCLA9IlXLXtlEA/",
/// [kazumi webview parser]:  (7sefun)
///   Loading video source: https://v16-tiktokcdn-com.akamaized.net/1a4e3d45db24b04b9792187b64763d9a/69084faf/video/tos/alisg/tos-alisg-ve-0051c001-sg/oIu0QFDTNDBfbIPDIlEQTuBA2lSgglEY8ofwI3/?a=1233&bti=Nzg3NWYzLTQ6&ch=0&cr=0&dr=0&er=0&lr=default&cd=0%7C0%7C0%7C0&br=1870&bt=935&cs=0&ds=4&ft=.bvrXInz7ThFo_pPXq8Zmo&mime_type=video_mp4&qs=0&rc=ZztlODhoZjxoaDc0aDc6OkBpMzdqNWw5cjNoNjMzODYzNEAzLzJjXmFfNl4xYjVgY2MyYSNgZmFxMmRza21hLS1kMC1zcw%3D%3D&vvpl=1&l=20251102142227CD49B547C5785EB959BB&btag=e000a8000&vid=v10033g50000d3pen0vog65it2dgi4c0
/// [kazumi webview parser]:  (DM84)
///   Loading m3u8 source: https://vip.dytt-cinema.com/20251106/39808_a9a80dd4/index.m3u8
/// xfdm 暂时没找到合适的

class Downloads {
  late final Dio dio;
  static final Downloads _instance = Downloads._internal();
  bool _isDownloadingM3u8 = false;
  bool _isDownloadingMP4 = false;
  factory Downloads() => _instance;

  Downloads._internal() {
    dio = Dio();
  }

  bool get isDownloadingM3u8 => _isDownloadingM3u8;
  bool get isDownloadingMP4 => _isDownloadingMP4;

  Future<bool> downloadTs(String url, {String? album, String? fileName}) async {
    if (_isDownloadingM3u8) {
      print("[kazumi downloader]: 正在下载中，请稍后");
    }

    M3u8ParseResult? parseResult = await M3u8Parser.parse(dio, url);

    if (parseResult == null) {
      print("[kazumi downloader]: 解析错误，无法下载视频");
      return false;
    }

    switch (parseResult.type) {
      case M3u8ParseType.master:
        if (parseResult.subM3u8Urls == null) {
          print("[kazumi downloader]: 不存在子 m3u8 文件，无法下载视频");
          return false;
        }
        final subM3u8Url = parseResult.subM3u8Urls?.first;
        parseResult = await M3u8Parser.parse(dio, subM3u8Url);
        break;
      case M3u8ParseType.media:
        // 这种情况下没必要在这里进行预处理，直接就是媒体文件
        break;
      case M3u8ParseType.other:
        print("[kazumi downloader]: 暂未支持的 m3u8 类型");
        return false;
    }
    final segmentUrls = parseResult?.segmentUrls;
    if (segmentUrls == null) {
      print("[kazumi downloader]: 不存在视频分片源，无法下载视频");
      return false;
    }

    // 此处只是需要一个存储 m3u8 文件的目录
    final savePath = await _getSavePath(album: album);
    if (savePath == null) {
      return false;
    }

    _isDownloadingM3u8 = true;

    final indexFileName = parseResult?.selfName;
    final indexUrl = "${parseResult?.baseUrl}/$indexFileName";
    segmentUrls.add(indexUrl);

    final suffix = ".ts"; // 文件后缀名建议加上 `.`，查找会更准

    print("[kazumi downloader]: 下载视频中");
    for (final url in segmentUrls) {
      String fileName = _justifyMediaFileName(url.split("/").last, suffix);

      final file = File(path.join(savePath, fileName));
      print("[kazumi downloader]: 正在下载 ${file.path}");

      if (file.existsSync()) {
        print("[kazumi downloader]: 文件已存在，跳过");
        continue;
      }
      await _downloadFile(url: url, savePath: file.path);
    }

    await _justifyIndexFile(File(path.join(savePath, indexFileName)), suffix);
    _isDownloadingM3u8 = false;

    return true;
  }

  /// 下载 MP4，album 可以是番剧名（用于做下载合集），fileName 是文件名
  Future<bool> downloadMP4(String url,
      {String? album, required String fileName}) async {
    if (_isDownloadingMP4) {
      print("[kazumi downloader]: 正在下载中，请稍后");
    }

    final String? savePath =
        await _getSavePath(album: album, fileName: fileName);
    if (savePath == null) {
      _isDownloadingMP4 = false;
      return false;
    }
    print("[kazumi downloader]: 保存路径为: $savePath");

    _isDownloadingMP4 = true;
    await _downloadFile(url: url, savePath: savePath);
    _isDownloadingMP4 = false;

    return true;
  }

  Future<String?> _getSavePath({String? album, String? fileName}) async {
    String? savePath = await FilePicker.getDirectoryPath();

    if (savePath == null) {
      print("[kazumi downloader]: 保存动作已取消");
      return null;
    }
    if (album != null) {
      savePath = path.join(savePath, album);
    }
    if (fileName != null) {
      savePath = path.join(savePath, fileName);
    }

    return savePath;
  }

  Future<void> _downloadFile({
    required String url,
    required String savePath,
  }) async {
    try {
      await dio.download(url, savePath,
          // `onReceiveProgress` 也许是个可选的功能，缺点是它会导致调试信息过多，我不太确定是否保留：
          onReceiveProgress: (received, total) {
        if (total != -1) {
          print(
              "[kazumi downloader]: 已下载 ${((received / total) * 100).toStringAsFixed(0)}%");
        } else {
          print("[kazumi downloader]: 下载完成");
        }
      },
          options: Options(
            responseType: ResponseType.bytes,
          ));
    } catch (e) {
      print("[kazumi downloader]: 无法获取文件字节流，错误为: $e");
      // 删除不完整文件
      if (await File(savePath).exists()) {
        await File(savePath).delete();
      }
    }
  }

  /// 在测试
  /// https:///vip.dytt-cinema.com/20251029/38765_b0889565/index.m3u8 时
  /// 发现 mixed.m3u8 文件内部指向的 ts 切片格式为：
  /// filename.ts?hash=hashValue
  /// 使用 VLC 和 Dragon 等 Linux 环境下的播放器无法正常播放
  /// 而在调整了文件名和 mixed.m3u8 后发现可以正常播放而加入的调整
  /// 此外 Windows 不支持 ? 作为文件名的一部分
  /// 此处将删去指定文件后缀后多余的内容
  String _justifyMediaFileName(String mediaFileName, String suffix) {
    if (!suffix.contains(".")) {
      suffix = ".$suffix";
    }

    if (mediaFileName.contains(suffix)) {
      final startToSuffix = mediaFileName.lastIndexOf(suffix) + suffix.length;

      // 此时说明文件后缀还有多余的字符，需要删掉
      if (startToSuffix < mediaFileName.length) {
        print("[kazumi downloader]: $mediaFileName 存在多余字符，已调整为：");
        mediaFileName = mediaFileName.substring(0, startToSuffix);
        print("[kazumi downloader]: $mediaFileName");
      }
    } else {
      print("[kazumi downloader]: 在 $mediaFileName 中不存在 $suffix 后缀，已原样返回");
    }
    return mediaFileName;
  }

  /// 此方法和 [_justifyMediaFileName] 方法是配套的
  /// 它负责检查 m3u8 索引文件内指向媒体切片的文件名
  /// 若存在多余字符则会进行调整
  Future<void> _justifyIndexFile(File indexFile, String suffix) async {
    List<String> contents = (await indexFile.readAsString()).split("\n");

    print("[kazumi downloader]: 调整 m3u8 索引文件中");
    if (!suffix.contains(".")) {
      suffix = ".$suffix";
    }

    for (int i = 0; i < contents.length; i++) {
      if (i + 1 >= contents.length) {
        break;
      }

      if (!contents[i].contains(M3u8Parser.tagForMediaSegments)) {
        continue;
      }

      final newFileName = _justifyMediaFileName(contents[i + 1], suffix);
      contents[i + 1] = newFileName;
    }
    indexFile.writeAsString(contents.join("\n"));
    print("[kazumi downloader]: 调整完成");
  }
}

// 测试用例
void test() async {
  final downloader = Downloads();
  await downloader.downloadMP4(
    "https://v16.toutiao50.com/aab47935d4a24f11001d394a660fb58b/6979ab77/video/tos/alisg/tos-alisg-v-0051c001-sg/oMJvDJeGgEoTbUPGCtpfPleWKCLA9IlXLXtlEA/",
    fileName: "test.mp4",
  );
  // await downloader.downloadTs(
  //     "https://vip.dytt-cinema.com/20251029/38765_b0889565/index.m3u8");
  // await downloader.downloadTs(
  // "https://ai.girigirilove.net/zijian/oldanime/2025/10/cht/GNOSIACHT/04/playlist.m3u8");
}
