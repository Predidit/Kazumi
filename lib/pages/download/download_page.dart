import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/bean/appbar/sys_app_bar.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/bean/widget/error_widget.dart';
import 'package:path_provider/path_provider.dart';
import 'package:logger/logger.dart';
import 'package:kazumi/utils/logger.dart';
import 'package:kazumi/pages/player/player_controller.dart'; // Import PlayerController
import 'dart:io' show Platform; // Import Platform
import 'package:path/path.dart' as p; // Import path package

class DownloadPage extends StatefulWidget {
  const DownloadPage({super.key});

  @override
  State<DownloadPage> createState() => _DownloadPageState();
}

class _DownloadPageState extends State<DownloadPage> {
  // Removed PlayerController instance variable from here
  List<Map<String, dynamic>> _downloadedFilesWithStats = []; // Stores file and its stats
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // Restore automatic loading on init
    _loadDownloadedFiles();
    // Ensure isLoading is true initially (it should be by default, but explicit doesn't hurt)
    _isLoading = true;
    _errorMessage = null;
  }

  Future<void> _loadDownloadedFiles() async {
    // Ensure widget is still mounted before calling setState
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Get platform-specific base directory
      final Directory? baseDir = await _getBaseDownloadDirectory();
       if (baseDir == null) {
        KazumiLogger().log(Level.error, 'Could not determine base download directory for listing.');
        if (!mounted) return;
        setState(() {
          _isLoading = false;
          _errorMessage = '无法获取应用存储目录';
        });
        return;
      }

      // Find or create Kazumi download directory
      final Directory kazumiDownloadsDir = Directory(p.join(baseDir.path, 'Kazumi'));
      if (!await kazumiDownloadsDir.exists()) {
        // Use try-catch specifically for directory creation
        try {
           await kazumiDownloadsDir.create(recursive: true);
        } catch (e) {
           KazumiLogger().log(Level.error, 'Failed to create Kazumi directory: $e');
            if (!mounted) return;
           setState(() {
             _isLoading = false;
             _errorMessage = '无法创建存储目录: ${e.toString()}';
           });
           return;
        }
      }

      // List files, handle potential errors during listing
      List<FileSystemEntity> files = [];
      try {
        files = await kazumiDownloadsDir.list().toList();
      } catch (e) {
         KazumiLogger().log(Level.error, 'Failed to list files in directory: $e');
         if (!mounted) return;
         setState(() {
           _isLoading = false;
           _errorMessage = '无法读取存储目录: ${e.toString()}';
         });
         return;
      }

      // Filter video files
      final List<FileSystemEntity> videoFiles = files.where((file) {
         // Ensure it's a file before checking extension
         if (file is! File) return false;
         final String path = file.path.toLowerCase();
         return path.endsWith('.mp4') ||
                path.endsWith('.mkv') ||
                path.endsWith('.avi') ||
                path.endsWith('.mov') ||
                path.endsWith('.flv') ||
                path.endsWith('.wmv');
      }).toList();

      // Asynchronously get stats and sort
      List<Map<String, dynamic>> filesWithStats = [];
      for (var file in videoFiles) {
        try {
          // Double-check it's a File before stating (though filter should handle this)
          if (file is File) {
             final stat = await file.stat();
             filesWithStats.add({'file': file, 'modified': stat.modified, 'size': stat.size});
          } else {
             KazumiLogger().log(Level.warning, 'Skipping non-file entity during stat: ${file.path}');
          }
        } catch (e) {
           // Log error if stat fails for a specific file, and crucially, skip adding it
           KazumiLogger().log(Level.error, 'Failed to get stats for file ${file.path}, skipping: $e');
           // Continue to the next file
        }
      }

      filesWithStats.sort((a, b) {
        final DateTime modifiedA = a['modified'];
        final DateTime modifiedB = b['modified'];
        return modifiedB.compareTo(modifiedA); // Newest first
      });

      // Update state only if mounted
      if (mounted) {
        setState(() {
          _downloadedFilesWithStats = filesWithStats;
          _isLoading = false;
        });
      }
    } catch (e) {
      // Catch any other unexpected errors during the process
      KazumiLogger().log(Level.error, '加载下载文件时发生未知错误: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = '加载下载文件时发生未知错误: ${e.toString()}';
        });
      }
    }
  }

  // Helper to get the platform-specific base directory for downloads
  Future<Directory?> _getBaseDownloadDirectory() async {
    try {
       if (Platform.isIOS || Platform.isMacOS) {
         return await getApplicationSupportDirectory();
       } else {
         return await getDownloadsDirectory();
       }
    } catch (e) {
       KazumiLogger().log(Level.error, 'Error getting directory: $e');
       return null; // Return null if path_provider fails
    }
  }

  Future<void> _deleteFile(FileSystemEntity file) async {
    try {
      await file.delete();
      KazumiDialog.showToast(message: '删除成功');
      _loadDownloadedFiles(); // Reload file list
    } catch (e) {
      KazumiLogger().log(Level.error, '删除文件失败: $e');
      KazumiDialog.showToast(message: '删除失败: ${e.toString()}');
    }
  }

  Future<void> _playVideo(String filePath) async {
    KazumiLogger().log(Level.info, 'Attempting to play local video from Downloads page: $filePath');
    try {
      // Revert to original navigation logic
      // This assumes the '/player/local/' route handles PlayerController setup
      Modular.to.pushNamed('/player/local/', arguments: {'filePath': filePath});
    } catch (e) {
      KazumiLogger().log(Level.error, '播放视频失败: $e');
      KazumiDialog.showToast(message: '播放失败: ${e.toString()}');
    }
  }

  String _getFileName(String path) {
    // Use path package for robust path manipulation
    return p.basename(path);
  }

  // Formats file size from bytes
  String _formatFileSize(int sizeInBytes) {
    try {
       if (sizeInBytes < 0) return '未知大小'; // Handle potential negative size if stat fails weirdly
       if (sizeInBytes < 1024) {
        return '$sizeInBytes B';
      } else if (sizeInBytes < 1024 * 1024) {
        return '${(sizeInBytes / 1024).toStringAsFixed(2)} KB';
      } else if (sizeInBytes < 1024 * 1024 * 1024) {
        return '${(sizeInBytes / (1024 * 1024)).toStringAsFixed(2)} MB';
      } else {
        return '${(sizeInBytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
      }
    } catch (e) {
      return '未知大小';
    }
  }

  // Formats DateTime
  String _formatDateTime(DateTime dateTime) {
    try {
       return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } catch (e) {
       return '未知日期';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const SysAppBar(title: Text('已下载剧集')),
      body: _buildBody(), // Use helper method for body
    );
  }

  // Helper method to build the body content
  Widget _buildBody() {
     if (_isLoading) {
       return const Center(child: CircularProgressIndicator());
     }
     if (_errorMessage != null) {
       return GeneralErrorWidget(
         errMsg: _errorMessage!,
         actions: [GeneralErrorButton(onPressed: _loadDownloadedFiles, text: '重试')],
       );
     }
     if (_downloadedFilesWithStats.isEmpty) {
       return Center(
         child: Column(
           mainAxisAlignment: MainAxisAlignment.center,
           children: [
             const Icon(
               Icons.download_done_rounded,
               size: 64,
               color: Colors.grey,
             ),
             const SizedBox(height: 16),
             const Text(
               '暂无下载的视频',
               style: TextStyle(fontSize: 16, color: Colors.grey),
             ),
             const SizedBox(height: 8),
             TextButton(
               onPressed: _loadDownloadedFiles,
               child: const Text('刷新'), // Revert button text
             ),
           ],
         ),
       );
     }

     // Display the list if loaded and not empty
     return RefreshIndicator(
       onRefresh: _loadDownloadedFiles,
       child: ListView.builder(
         itemCount: _downloadedFilesWithStats.length,
         itemBuilder: (context, index) {
           try {
              // Extract data safely
              final itemData = _downloadedFilesWithStats[index];
              final FileSystemEntity file = itemData['file'];
              final DateTime modifiedDate = itemData['modified'];
              final int fileSizeInBytes = itemData['size'];

              final fileName = _getFileName(file.path);
              final fileSize = _formatFileSize(fileSizeInBytes);
              final modifiedDateString = _formatDateTime(modifiedDate);

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  leading: const Icon(Icons.video_file_rounded),
                  title: Text(fileName),
                  subtitle: Text('$fileSize • $modifiedDateString'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.delete_rounded),
                        tooltip: '删除',
                        onPressed: () => _showDeleteConfirmation(context, file, fileName), // Use helper
                      ),
                    ],
                  ),
                  onTap: () => _playVideo(file.path),
                ),
              );
           } catch (e) {
              // Handle potential errors during item build (e.g., accessing map keys)
              KazumiLogger().log(Level.error, 'Error building list item at index $index: $e');
              return ListTile(title: Text('加载项目 $index 时出错')); // Placeholder for error
           }
         },
       ),
     );
  }

  // Helper method for showing delete confirmation dialog
  void _showDeleteConfirmation(BuildContext context, FileSystemEntity file, String fileName) {
     showDialog(
       context: context,
       builder: (context) => AlertDialog(
         title: const Text('确认删除'),
         content: Text('确定要删除 $fileName 吗？'),
         actions: [
           TextButton(
             onPressed: () => Navigator.of(context).pop(),
             child: const Text('取消'),
           ),
           TextButton(
             onPressed: () {
               Navigator.of(context).pop();
               _deleteFile(file);
             },
             child: const Text('删除'),
           ),
         ],
       ),
     );
  }
}
