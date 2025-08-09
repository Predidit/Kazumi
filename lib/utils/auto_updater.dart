import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/request/api.dart';
import 'package:kazumi/utils/logger.dart';
import 'package:kazumi/utils/storage.dart';
import 'package:logger/logger.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

class AutoUpdater {
  static final AutoUpdater _instance = AutoUpdater._internal();
  factory AutoUpdater() => _instance;
  AutoUpdater._internal();

  final Dio _dio = Dio();
  Box get setting => GStorage.setting;

  /// 检查是否有新版本可用
  Future<UpdateInfo?> checkForUpdates() async {
    try {
      final response = await _dio.get(Api.latestApp);
      final data = response.data;

      if (data == null || !data.containsKey('tag_name')) {
        throw Exception('无效的响应数据');
      }

      final remoteVersion = data['tag_name'] as String;
      final currentVersion = Api.version;

      if (_shouldUpdate(currentVersion, remoteVersion)) {
        return UpdateInfo(
          version: remoteVersion,
          description: data['body'] ?? '发现新版本',
          downloadUrl: _getDownloadUrl(data['assets'] ?? []),
          releaseNotes: data['html_url'] ?? '',
          publishedAt: data['published_at'] ?? '',
        );
      }

      return null;
    } catch (e) {
      KazumiLogger().log(Level.error, '检查更新失败: ${e.toString()}');
      rethrow;
    }
  }

  /// 自动检查更新（仅在启用自动更新时）
  Future<void> autoCheckForUpdates() async {
    final autoUpdate =
        setting.get(SettingBoxKey.autoUpdate, defaultValue: true);
    if (!autoUpdate) return;

    try {
      final updateInfo = await checkForUpdates();
      if (updateInfo != null) {
        _showUpdateDialog(updateInfo, isAutoCheck: true);
      }
    } catch (e) {
      // 自动检查失败时不显示错误
      KazumiLogger().log(Level.warning, '自动检查更新失败: ${e.toString()}');
    }
  }

  /// 手动检查更新
  Future<void> manualCheckForUpdates() async {
    try {
      final updateInfo = await checkForUpdates();
      if (updateInfo != null) {
        _showUpdateDialog(updateInfo, isAutoCheck: false);
      } else {
        KazumiDialog.showToast(message: '当前已经是最新版本！');
      }
    } catch (e) {
      KazumiDialog.showToast(message: '检查更新失败');
    }
  }

  /// 显示更新对话框
  void _showUpdateDialog(UpdateInfo updateInfo, {bool isAutoCheck = false}) {
    KazumiDialog.show(
      builder: (context) {
        return AlertDialog(
          title: Text('发现新版本 ${updateInfo.version}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(updateInfo.description),
                if (updateInfo.publishedAt.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    '发布时间: ${_formatDate(updateInfo.publishedAt)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ),
          actions: [
            if (isAutoCheck)
              TextButton(
                onPressed: () {
                  setting.put(SettingBoxKey.autoUpdate, false);
                  KazumiDialog.dismiss();
                  KazumiDialog.showToast(message: '已关闭自动更新');
                },
                child: Text(
                  '关闭自动更新',
                  style:
                      TextStyle(color: Theme.of(context).colorScheme.outline),
                ),
              ),
            TextButton(
              onPressed: () => KazumiDialog.dismiss(),
              child: Text(
                '稍后提醒',
                style: TextStyle(color: Theme.of(context).colorScheme.outline),
              ),
            ),
            if (updateInfo.releaseNotes.isNotEmpty)
              TextButton(
                onPressed: () {
                  launchUrl(Uri.parse(updateInfo.releaseNotes),
                      mode: LaunchMode.externalApplication);
                },
                child: const Text('查看详情'),
              ),
            TextButton(
              onPressed: () {
                KazumiDialog.dismiss();
                if (updateInfo.downloadUrl.isNotEmpty) {
                  _downloadUpdate(updateInfo);
                } else {
                  launchUrl(Uri.parse(updateInfo.releaseNotes),
                      mode: LaunchMode.externalApplication);
                }
              },
              child: const Text('立即更新'),
            ),
          ],
        );
      },
    );
  }

  /// 下载更新
  Future<void> _downloadUpdate(UpdateInfo updateInfo) async {
    if (updateInfo.downloadUrl.isEmpty) {
      KazumiDialog.showToast(message: '没有找到合适的下载链接');
      return;
    }

    // 显示下载进度对话框
    KazumiDialog.show(
      builder: (context) {
        return AlertDialog(
          title: const Text('正在下载更新'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ValueListenableBuilder<double>(
                valueListenable: _downloadProgress,
                builder: (context, value, child) {
                  return Column(
                    children: [
                      LinearProgressIndicator(value: value),
                      const SizedBox(height: 8),
                      Text('${(value * 100).toStringAsFixed(1)}%'),
                    ],
                  );
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                _cancelDownload();
                KazumiDialog.dismiss();
              },
              child: const Text('取消'),
            ),
          ],
        );
      },
    );

    try {
      final downloadPath =
          await _downloadFile(updateInfo.downloadUrl, updateInfo.version);
      KazumiDialog.dismiss();

      // 下载完成，询问是否安装
      _showInstallDialog(downloadPath, updateInfo.version);
    } catch (e) {
      KazumiDialog.dismiss();

      // 显示详细的错误信息
      String errorMessage = '下载失败';
      if (e.toString().contains('Permission denied') ||
          e.toString().contains('Operation not permitted')) {
        errorMessage = '权限不足，文件已保存到应用临时目录';
      } else if (e.toString().contains('No space left')) {
        errorMessage = '磁盘空间不足';
      } else if (e.toString().contains('Network')) {
        errorMessage = '网络连接错误';
      }

      KazumiDialog.show(
        builder: (context) {
          return AlertDialog(
            title: const Text('下载失败'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(errorMessage),
                const SizedBox(height: 8),
                Text(
                  '错误详情: ${e.toString()}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => KazumiDialog.dismiss(),
                child: const Text('确定'),
              ),
              TextButton(
                onPressed: () {
                  KazumiDialog.dismiss();
                  // 重新尝试下载
                  _downloadUpdate(updateInfo);
                },
                child: const Text('重试'),
              ),
            ],
          );
        },
      );

      KazumiLogger().log(Level.error, '下载更新失败: ${e.toString()}');
    }
  }

  final ValueNotifier<double> _downloadProgress = ValueNotifier(0.0);
  CancelToken? _cancelToken;

  void _cancelDownload() {
    _cancelToken?.cancel();
  }

  /// 下载文件
  Future<String> _downloadFile(String url, String version) async {
    final fileName = _getFileNameFromUrl(url, version);
    String filePath;

    // 根据平台选择合适的下载目录
    if (Platform.isMacOS || Platform.isLinux) {
      // 使用临时目录，避免权限问题
      final tempDir = await getTemporaryDirectory();
      filePath = '${tempDir.path}/$fileName';
    } else if (Platform.isWindows) {
      // Windows 尝试使用下载目录，失败则使用临时目录
      try {
        final downloadDir = await getDownloadsDirectory();
        filePath =
            '${downloadDir?.path ?? (await getTemporaryDirectory()).path}/$fileName';
      } catch (e) {
        final tempDir = await getTemporaryDirectory();
        filePath = '${tempDir.path}/$fileName';
      }
    } else if (Platform.isAndroid) {
      // Android 使用应用文档目录
      try {
        final appDocDir = await getApplicationDocumentsDirectory();
        final downloadPath = '${appDocDir.path}/downloads';
        final downloadDir = Directory(downloadPath);
        if (!await downloadDir.exists()) {
          await downloadDir.create(recursive: true);
        }
        filePath = '$downloadPath/$fileName';
      } catch (e) {
        final tempDir = await getTemporaryDirectory();
        filePath = '${tempDir.path}/$fileName';
      }
    } else {
      // 其他平台使用临时目录
      final tempDir = await getTemporaryDirectory();
      filePath = '${tempDir.path}/$fileName';
    }

    _cancelToken = CancelToken();

    await _dio.download(
      url,
      filePath,
      cancelToken: _cancelToken,
      onReceiveProgress: (received, total) {
        if (total > 0) {
          _downloadProgress.value = received / total;
        }
      },
    );

    return filePath;
  }

  /// 显示安装对话框
  void _showInstallDialog(String filePath, String version) {
    KazumiDialog.show(
      builder: (context) {
        return AlertDialog(
          title: const Text('下载完成'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('新版本 $version 已下载完成，是否立即安装？'),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '文件位置:',
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                    const SizedBox(height: 4),
                    SelectableText(
                      filePath,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontFamily: 'monospace',
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => KazumiDialog.dismiss(),
              child: Text(
                '稍后安装',
                style: TextStyle(color: Theme.of(context).colorScheme.outline),
              ),
            ),
            TextButton(
              onPressed: () {
                // 在文件管理器中显示文件
                _revealInFileManager(filePath);
              },
              child: const Text('打开文件夹'),
            ),
            TextButton(
              onPressed: () {
                KazumiDialog.dismiss();
                _installUpdate(filePath);
              },
              child: const Text('立即安装'),
            ),
          ],
        );
      },
    );
  }

  /// 安装更新
  void _installUpdate(String filePath) async {
    try {
      if (Platform.isWindows) {
        await Process.start('explorer.exe', [filePath], runInShell: true);
      } else if (Platform.isMacOS) {
        await Process.start('open', [filePath]);
      } else if (Platform.isLinux) {
        if (filePath.endsWith('.AppImage')) {
          await Process.start('chmod', ['+x', filePath]);
          await Process.start(filePath, []);
        } else {
          await Process.start('xdg-open', [filePath]);
        }
      } else if (Platform.isAndroid) {
        await Process.start('am', [
          'start',
          '-t',
          'application/vnd.android.package-archive',
          '-d',
          'file://$filePath'
        ]);
      }

      KazumiDialog.showToast(message: '正在启动安装程序...');
    } catch (e) {
      KazumiDialog.showToast(message: '启动安装程序失败');
      KazumiLogger().log(Level.error, '启动安装程序失败: ${e.toString()}');
    }
  }

  /// 在文件管理器中显示文件
  void _revealInFileManager(String filePath) async {
    try {
      if (Platform.isWindows) {
        await Process.start('explorer.exe', ['/select,', filePath],
            runInShell: true);
      } else if (Platform.isMacOS) {
        await Process.start('open', ['-R', filePath]);
      } else if (Platform.isLinux) {
        // 尝试打开包含文件的文件夹
        final directory = Directory(filePath).parent.path;
        await Process.start('xdg-open', [directory]);
      }
      KazumiDialog.dismiss();
    } catch (e) {
      KazumiDialog.showToast(message: '无法打开文件管理器');
      KazumiLogger().log(Level.warning, '打开文件管理器失败: ${e.toString()}');
    }
  }

  /// 判断是否需要更新
  bool _shouldUpdate(String currentVersion, String remoteVersion) {
    // 移除版本号前的 'v' 前缀
    final current = currentVersion.replaceFirst('v', '');
    final remote = remoteVersion.replaceFirst('v', '');

    final currentParts = current.split('.').map(int.parse).toList();
    final remoteParts = remote.split('.').map(int.parse).toList();

    // 确保版本号格式一致
    while (currentParts.length < 3) {
      currentParts.add(0);
    }
    while (remoteParts.length < 3) {
      remoteParts.add(0);
    }

    for (int i = 0; i < 3; i++) {
      if (remoteParts[i] > currentParts[i]) {
        return true;
      } else if (remoteParts[i] < currentParts[i]) {
        return false;
      }
    }

    return false;
  }

  /// 获取合适的下载链接
  String _getDownloadUrl(List<dynamic> assets) {
    if (assets.isEmpty) return '';

    String platform = '';
    if (Platform.isWindows) {
      platform = 'windows';
    } else if (Platform.isMacOS) {
      platform = 'macos';
    } else if (Platform.isLinux) {
      platform = 'linux';
    } else if (Platform.isAndroid) {
      platform = 'android';
    }

    for (final asset in assets) {
      final name = asset['name'] as String? ?? '';
      final downloadUrl = asset['browser_download_url'] as String? ?? '';

      if (name.toLowerCase().contains(platform.toLowerCase()) &&
          downloadUrl.isNotEmpty) {
        return downloadUrl;
      }
    }

    // 如果没找到平台特定的文件，返回第一个下载链接
    if (assets.isNotEmpty) {
      return assets.first['browser_download_url'] as String? ?? '';
    }

    return '';
  }

  /// 从URL获取文件名
  String _getFileNameFromUrl(String url, String version) {
    final uri = Uri.parse(url);
    final fileName = uri.pathSegments.last;

    if (fileName.isNotEmpty) {
      return fileName;
    }

    // 回退方案
    String extension = '';
    if (Platform.isWindows) {
      extension = '.msix';
    } else if (Platform.isMacOS) {
      extension = '.dmg';
    } else if (Platform.isLinux) {
      extension = '.deb';
    } else if (Platform.isAndroid) {
      extension = '.apk';
    }
    return 'Kazumi-$version$extension';
  }

  /// 格式化日期
  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateString;
    }
  }
}

/// 更新信息类
class UpdateInfo {
  final String version;
  final String description;
  final String downloadUrl;
  final String releaseNotes;
  final String publishedAt;

  UpdateInfo({
    required this.version,
    required this.description,
    required this.downloadUrl,
    required this.releaseNotes,
    required this.publishedAt,
  });
}
