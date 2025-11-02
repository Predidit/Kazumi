import 'dart:io';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;

/// 测试用例：《弹珠汽水瓶里的千岁同学》
/// [kazumi webview parser]:  (7sefun) => 可工作
///   Loading video source: https://v16-tiktokcdn-com.akamaized.net/1a4e3d45db24b04b9792187b64763d9a/69084faf/video/tos/alisg/tos-alisg-ve-0051c001-sg/oIu0QFDTNDBfbIPDIlEQTuBA2lSgglEY8ofwI3/?a=1233&bti=Nzg3NWYzLTQ6&ch=0&cr=0&dr=0&er=0&lr=default&cd=0%7C0%7C0%7C0&br=1870&bt=935&cs=0&ds=4&ft=.bvrXInz7ThFo_pPXq8Zmo&mime_type=video_mp4&qs=0&rc=ZztlODhoZjxoaDc0aDc6OkBpMzdqNWw5cjNoNjMzODYzNEAzLzJjXmFfNl4xYjVgY2MyYSNgZmFxMmRza21hLS1kMC1zcw%3D%3D&vvpl=1&l=20251102142227CD49B547C5785EB959BB&btag=e000a8000&vid=v10033g50000d3pen0vog65it2dgi4c0
/// [kazumi webview parser]:  (DM84)
///   Loading m3u8 source: https://vip.dytt-cinema.com/20251029/38765_b0889565/index.m3u8
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

  Future<bool> downloadM3u8(String url) async {
    // TODO: m3u8 可能需要额外写个解析插件，先支持 mp4 吧
    return true;
  }

  /// 下载 MP4，album 可以是番剧名（用于做下载合集），fileName 是文件名
  Future<void> downloadMP4(String url,
      {String album='', required String fileName}) async {
    if (_isDownloadingMP4) {
      print("[kazumi downloader]: 正在下载中，请稍后");
    }
    _isDownloadingMP4 = true;

    String? savePath = await FilePicker.platform.getDirectoryPath();
    final suggestedName =
        fileName.contains(RegExp(r'\.\w+$')) ? fileName : '$fileName.mp4';

    if (savePath == null) {
      print("[kazumi downloader]: 保存动作已取消");
      return;
    }
    savePath = path.join(savePath, album, suggestedName);
    print("[kazumi downloader]: 保存路径为: $savePath");
    try {
      await dio.download(url, savePath, onReceiveProgress: (received, total) {
        if (total != -1) {
          print(
              "[kazumi downloader]: 已下载 ${((received / total) * 100).toStringAsFixed(1)}%");
        } else {
          print("[kazumi downloader]: 下载完成");
        }
      },
          options: Options(
            responseType: ResponseType.bytes,
          ));
    } catch (e) {
      print("[kazumi downloader]: 无法获取视频字节流，错误为: $e");
      // 删除不完整文件
      if (await File(savePath).exists()) {
        await File(savePath).delete();
      }
    } finally {
      _isDownloadingMP4 = false;
    }
  }
}
// 测试用例
// void test() async {
//   await Downloads().downloadMP4(
//     "https://v16-tiktokcdn-com.akamaized.net/1a4e3d45db24b04b9792187b64763d9a/69084faf/video/tos/alisg/tos-alisg-ve-0051c001-sg/oIu0QFDTNDBfbIPDIlEQTuBA2lSgglEY8ofwI3/?a=1233&bti=Nzg3NWYzLTQ6&ch=0&cr=0&dr=0&er=0&lr=default&cd=0%7C0%7C0%7C0&br=1870&bt=935&cs=0&ds=4&ft=.bvrXInz7ThFo_pPXq8Zmo&mime_type=video_mp4&qs=0&rc=ZztlODhoZjxoaDc0aDc6OkBpMzdqNWw5cjNoNjMzODYzNEAzLzJjXmFfNl4xYjVgY2MyYSNgZmFxMmRza21hLS1kMC1zcw%3D%3D&vvpl=1&l=20251102142227CD49B547C5785EB959BB&btag=e000a8000&vid=v10033g50000d3pen0vog65it2dgi4c0",
//     fileName: "test.mp4",
//   );
// }
