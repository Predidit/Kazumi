import 'dart:io';
import 'package:flutter/material.dart';
import 'package:kazumi/modules/bangumi/bangumi_item.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/pages/video/video_controller.dart';
import 'package:kazumi/pages/player/player_controller.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:logger/logger.dart';
import 'package:kazumi/utils/logger.dart';
import 'package:path/path.dart' as p; // Import path package
import 'dart:io' show Platform; // Import Platform

class DownloadButton extends StatefulWidget {
  DownloadButton({
    super.key,
    required this.bangumiItem,
    required this.episodeIndex,
    required this.roadIndex,
    this.color = Colors.white,
    this.onOpen,
    this.onClose,
  }) {
    isExtended = false;
  }

  DownloadButton.extend({
    super.key,
    required this.bangumiItem,
    required this.episodeIndex,
    required this.roadIndex,
    this.color = Colors.white,
    this.onOpen,
    this.onClose,
  }) {
    isExtended = true;
  }

  final BangumiItem bangumiItem;
  final int episodeIndex; // 当前选集索引
  final int roadIndex; // 当前播放列表索引
  final Color color;
  late final bool isExtended;
  final void Function()? onOpen;
  final void Function()? onClose;

  @override
  State<DownloadButton> createState() => _DownloadButtonState();
}

class _DownloadButtonState extends State<DownloadButton> {
  final VideoPageController videoPageController = Modular.get<VideoPageController>();
  final PlayerController playerController = Modular.get<PlayerController>();
  bool _isDownloading = false;
  bool _isDownloaded = false; // Add state for downloaded status
  String _localFilePath = ''; // Store the local file path if downloaded
  double _downloadProgress = 0.0;
  CancelToken? _cancelToken;

  @override
  void initState() {
    super.initState();
    _checkIfDownloaded(); // Check download status on init
  }

  // Helper to get the platform-specific base directory for downloads
  Future<Directory?> _getBaseDownloadDirectory() async {
    if (Platform.isIOS || Platform.isMacOS) {
      // Use Application Support directory for iOS/macOS
      return await getApplicationSupportDirectory();
    } else {
      // Use Downloads directory for other platforms (Android, Windows, Linux)
      // Note: getDownloadsDirectory() might still require specific permissions on some platforms/versions.
      return await getDownloadsDirectory();
    }
  }

  Future<String?> _getExpectedFilePath() async {
    try {
      final Directory? baseDir = await _getBaseDownloadDirectory();
      if (baseDir == null) {
         KazumiLogger().log(Level.error, 'Could not determine base download directory.');
         return null;
      }

      final Directory kazumiDownloadsDir = Directory(p.join(baseDir.path, 'Kazumi')); // Use path.join

      // Replicate filename generation logic
      String fileName = '';
      final bangumiName = widget.bangumiItem.name;
      // Ensure roadList and identifier are accessible and valid
      if (videoPageController.roadList.isNotEmpty &&
          widget.roadIndex < videoPageController.roadList.length &&
          widget.episodeIndex < videoPageController.roadList[widget.roadIndex].identifier.length) {
            final episodeName = videoPageController.roadList[widget.roadIndex].identifier[widget.episodeIndex];
            fileName = '${bangumiName}_${episodeName}.mp4';
            fileName = fileName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_'); // Sanitize filename
      } else {
        // Fallback or error handling if names are not available
        // For now, we assume it won't be considered downloaded if we can't generate the name
        return null;
      }


      return p.join(kazumiDownloadsDir.path, fileName); // Use path.join
    } catch (e) {
      KazumiLogger().log(Level.warning, 'Error generating expected file path: $e');
      return null;
    }
  }

  Future<void> _checkIfDownloaded() async {
    final expectedPath = await _getExpectedFilePath();
    if (expectedPath != null) {
      final file = File(expectedPath);
      if (await file.exists()) {
        if (mounted) {
          setState(() {
            _isDownloaded = true;
            _localFilePath = expectedPath; // Store the path
          });
        }
      } else {
         if (mounted) {
          setState(() {
            _isDownloaded = false;
            _localFilePath = '';
          });
        }
      }
    } else {
       if (mounted) {
          setState(() {
            _isDownloaded = false;
            _localFilePath = '';
          });
       }
    }
  }

  @override
  void dispose() {
    // 确保在组件销毁时取消下载
    if (_cancelToken != null && !_cancelToken!.isCancelled) {
      _cancelToken!.cancel('组件销毁');
    }
    super.dispose();
  }

  // 实际的视频下载逻辑
  Future<void> _startDownload() async {
    if (_isDownloading) return;
    
    setState(() {
      _isDownloading = true;
      _downloadProgress = 0.0;
    });

    // 获取当前视频URL
    String? videoUrl;
    try {
      // 优先使用PlayerController中的videoUrl，这是实际播放的视频地址
      if (playerController.videoUrl.isNotEmpty) {
        videoUrl = playerController.videoUrl;
      } else if (videoPageController.roadList.isNotEmpty &&
          widget.roadIndex < videoPageController.roadList.length &&
          widget.episodeIndex < videoPageController.roadList[widget.roadIndex].data.length) {
        // 如果PlayerController中没有地址，则使用roadList中的地址作为备选
        videoUrl = videoPageController.roadList[widget.roadIndex].data[widget.episodeIndex];
      }
    } catch (e) {
      KazumiDialog.showToast(message: '获取视频链接失败');
      setState(() {
        _isDownloading = false;
      });
      return;
    }

    if (videoUrl == null || videoUrl.isEmpty) {
      KazumiDialog.showToast(message: '视频链接无效');
      setState(() {
        _isDownloading = false;
      });
      return;
    }

    // 确保视频URL是完整的
    if (!videoUrl.startsWith('http')) {
      final currentPlugin = videoPageController.currentPlugin;
      if (videoUrl.contains(currentPlugin.baseUrl) ||
          videoUrl.contains(currentPlugin.baseUrl.replaceAll('https', 'http'))) {
        // URL已经是完整的
      } else {
        videoUrl = currentPlugin.baseUrl + videoUrl;
      }
      if (videoUrl.startsWith('http://')) {
        videoUrl = videoUrl.replaceFirst('http', 'https');
      }
    }

    try {
      // 获取平台特定的下载目录
      final Directory? baseDir = await _getBaseDownloadDirectory();
      if (baseDir == null) {
        KazumiDialog.showToast(message: '无法获取应用存储目录');
        setState(() {
          _isDownloading = false;
        });
        return;
      }

      // 在基础目录下创建Kazumi下载文件夹
      final Directory kazumiDownloadsDir = Directory(p.join(baseDir.path, 'Kazumi'));
      if (!await kazumiDownloadsDir.exists()) {
        await kazumiDownloadsDir.create(recursive: true);
      }

      // 生成文件名
      String fileName = '';
      try {
        // 尝试使用番剧名称和集数作为文件名
        final bangumiName = widget.bangumiItem.name;
        final episodeName = videoPageController.roadList[widget.roadIndex].identifier[widget.episodeIndex];
        fileName = '${bangumiName}_${episodeName}.mp4';
        // 替换文件名中的非法字符
        fileName = fileName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      } catch (e) {
        // 如果无法获取番剧信息，使用时间戳作为文件名
        fileName = 'video_${DateTime.now().millisecondsSinceEpoch}.mp4';
      }

      final String savePath = '${kazumiDownloadsDir.path}/$fileName';
      KazumiLogger().log(Level.info, '开始下载视频: $videoUrl 到 $savePath');
      // KazumiDialog.showToast(message: '开始下载视频'); // Maybe too frequent

      // 创建Dio实例
      final Dio dio = Dio();
      
      // 创建CancelToken用于取消下载
      _cancelToken = CancelToken();
      
      // 开始下载
      await dio.download(
        videoUrl,
        savePath,
        cancelToken: _cancelToken,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            // 更新下载进度
            if (mounted) {
              setState(() {
                _downloadProgress = received / total;
              });
            }
          }
        },
      );

      if (mounted) {
        setState(() {
          _downloadProgress = 1.0;
          _isDownloading = false;
          _isDownloaded = true; // Mark as downloaded
          _localFilePath = savePath; // Store the path
        });
        KazumiDialog.showToast(message: '视频下载完成'); // Simplified message
        KazumiLogger().log(Level.info, '视频下载完成: $savePath');
      }
    } catch (e) {
      KazumiLogger().log(Level.error, '下载视频失败: $e');
      if (mounted) {
        setState(() {
          _isDownloading = false;
        });
        KazumiDialog.showToast(message: '下载失败: ${e.toString()}');
      }
    }
  }

  // 取消下载的实例变量
// 删除重复声明的_cancelToken变量，因为已在类开始处声明过

  void _cancelDownload() {
    // 取消下载
    if (_cancelToken != null && !_cancelToken!.isCancelled) {
      _cancelToken!.cancel('用户取消下载');
      KazumiLogger().log(Level.info, '用户取消下载');
    }
    
    setState(() {
      _isDownloading = false;
      _downloadProgress = 0.0;
    });
    KazumiDialog.showToast(message: '已取消下载');
  }

  // Function to handle playing local video
  void _playLocalVideo() {
    if (_localFilePath.isNotEmpty) {
      KazumiLogger().log(Level.info, 'Attempting to play local video: $_localFilePath');
      try {
        // Construct the file URI. Ensure proper encoding if needed, but usually direct path works.
        // On Windows, paths might need adjustment, but `file://` prefix is standard.
        final fileUri = Uri.file(_localFilePath).toString();
        KazumiLogger().log(Level.info, 'Playing local file URI: $fileUri');

        // Call playerController.init to load the local file.
        // We might need to reset other states or handle navigation depending on app structure.
        // Assuming init handles the player setup. Pass offset 0 for now.
        playerController.init(fileUri, offset: 0);

        // Optional: Show feedback or navigate if necessary
        // KazumiDialog.showToast(message: '正在加载本地视频...');

        // If the button is part of the player UI itself, init might be enough.
        // If it's on a different screen (like video details), navigation might be needed.
        // Example navigation (if needed):
        // Modular.to.pushNamed('/player'); // Adjust route as necessary

      } catch (e) {
        KazumiLogger().log(Level.error, 'Error playing local video: $e');
        KazumiDialog.showToast(message: '播放本地视频失败: $e');
      }
    } else {
      KazumiLogger().log(Level.warning, 'Local file path is empty, cannot play.');
      KazumiDialog.showToast(message: '本地文件路径无效');
    }
  }


  @override
  Widget build(BuildContext context) {
    // Check download status again in build in case state changed externally? Maybe not needed if initState handles it.
    // Consider adding a listener to download changes if downloads can happen elsewhere.

    if (_isDownloaded) {
      // --- UI for Already Downloaded ---
      if (widget.isExtended) {
        return FilledButton.icon(
          onPressed: _playLocalVideo, // Enable local video playback
          icon: Icon(Icons.play_circle_outline, color: widget.color.withOpacity(0.7)),
          label: Text('已下载', style: TextStyle(color: widget.color.withOpacity(0.7))),
          style: FilledButton.styleFrom(
            backgroundColor: Colors.grey.withOpacity(0.3), // Visually distinct
          ),

        );
      } else {
        return IconButton(
          onPressed: _playLocalVideo, // Enable local video playback
          icon: Icon(
            Icons.play_circle_outline, // Use a different icon, e.g., check or play
            color: widget.color.withOpacity(0.7), // Indicate downloaded state visually
          ),
          tooltip: '播放已下载视频',
        );
      }
    } else if (_isDownloading) {
      // --- UI for Downloading ---
      return SizedBox(
        width: widget.isExtended ? null : 40,
        height: widget.isExtended ? null : 40,
        child: Stack(
          alignment: Alignment.center,
          children: [
            CircularProgressIndicator(
              value: _downloadProgress,
              color: widget.color,
              strokeWidth: 2.0,
            ),
            IconButton(
              icon: Icon(
                Icons.close,
                color: widget.color,
                size: 16,
              ),
              onPressed: _cancelDownload,
              tooltip: '取消下载',
            ),
          ],
        ),
      );
    } else {
      // --- UI for Not Downloaded ---
      if (widget.isExtended) {
        return FilledButton.icon(
          onPressed: _startDownload,
          icon: const Icon(Icons.download),
          label: const Text('下载'),
        );
      } else {
        return IconButton(
          onPressed: _startDownload,
          icon: Icon(
            Icons.download,
            color: widget.color,
          ),
          tooltip: '下载视频',
        );
      }
    }
  }
}
