import 'dart:io';

import 'package:flutter/material.dart';

import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/bean/settings/settings_detail_scaffold.dart';
import 'package:kazumi/bean/settings/settings_list.dart';
import 'package:kazumi/bean/widget/loading_indicator.dart';
import 'package:kazumi/services/download/download_directory_service.dart';
import 'package:kazumi/services/storage/storage.dart';
import 'package:kazumi/utils/file_system.dart';

class DownloadSettingsPage extends StatefulWidget {
  const DownloadSettingsPage({super.key});

  @override
  State<DownloadSettingsPage> createState() => _DownloadSettingsPageState();
}

class _DownloadSettingsPageState extends State<DownloadSettingsPage> {
  final _directoryService = DownloadDirectoryService();
  late int parallelEpisodes;
  late int parallelSegments;
  late bool downloadDanmaku;
  String downloadDirectory = '';
  String defaultDownloadDirectory = '';
  bool isSelectingDirectory = false;

  @override
  void initState() {
    super.initState();
    parallelEpisodes =
        GStorage.getSetting(SettingsKeys.downloadParallelEpisodes);
    parallelSegments =
        GStorage.getSetting(SettingsKeys.downloadParallelSegments);
    downloadDanmaku = GStorage.getSetting(SettingsKeys.downloadDanmaku);
    downloadDirectory = _directoryService.customDirectory;
    _loadDefaultDownloadDirectory();
  }

  bool get _hasCustomDirectory => downloadDirectory.isNotEmpty;

  String get _effectiveDownloadDirectory =>
      _hasCustomDirectory ? downloadDirectory : defaultDownloadDirectory;

  Future<void> _loadDefaultDownloadDirectory() async {
    final directory = await getDefaultDownloadDirectory();
    if (!mounted) return;
    setState(() {
      defaultDownloadDirectory = directory;
    });
  }

  Future<void> _selectDownloadDirectory() async {
    if (isSelectingDirectory) return;

    setState(() => isSelectingDirectory = true);
    try {
      final selectedPath = await _directoryService.selectDirectory();
      if (selectedPath == null) return;
      if (mounted) {
        setState(() => downloadDirectory = selectedPath);
      }
      KazumiDialog.showToast(message: '下载位置已更新，仅对新下载生效');
    } on DownloadDirectoryException catch (e) {
      KazumiDialog.showToast(message: e.message);
    } on FileSystemException catch (e) {
      KazumiDialog.showToast(message: '无法写入该目录: ${e.message}');
    } catch (e) {
      KazumiDialog.showToast(message: '选择下载位置失败: $e');
    } finally {
      if (mounted) {
        setState(() => isSelectingDirectory = false);
      }
    }
  }

  Future<void> _resetDownloadDirectory() async {
    await _directoryService.resetDirectory();
    if (mounted) {
      setState(() => downloadDirectory = '');
    }
    KazumiDialog.showToast(message: '已恢复默认下载位置，仅对新下载生效');
  }

  @override
  Widget build(BuildContext context) {
    return SettingsDetailScaffold(
      title: const Text('下载设置'),
      body: SettingsList(
        sections: [
          SettingsSection(
            title: Text('并发设置'),
            tiles: [
              SettingsSliderTile(
                leading: Icons.video_library_rounded,
                title: Text('同时下载集数'),
                description: Text('并行下载的剧集数量'),
                value: parallelEpisodes.toDouble(),
                min: 1,
                max: 5,
                divisions: 4,
                valueLabel: '$parallelEpisodes 集',
                onChanged: (value) {
                  setState(() => parallelEpisodes = value.toInt());
                  GStorage.putSetting(
                    SettingsKeys.downloadParallelEpisodes,
                    parallelEpisodes,
                  );
                },
              ),
              SettingsSliderTile(
                leading: Icons.call_split_rounded,
                title: Text('分片并发数'),
                description: Text('每集同时下载的分片数量'),
                value: parallelSegments.toDouble(),
                min: 1,
                max: 10,
                divisions: 9,
                valueLabel: '$parallelSegments 个',
                onChanged: (value) {
                  setState(() => parallelSegments = value.toInt());
                  GStorage.putSetting(
                    SettingsKeys.downloadParallelSegments,
                    parallelSegments,
                  );
                },
              ),
            ],
          ),
          SettingsSection(
            title: Text('缓存设置'),
            tiles: [
              SettingsTile(
                leading: Icons.folder_rounded,
                title: Text('下载位置'),
                description: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _effectiveDownloadDirectory.isEmpty
                          ? '正在读取默认位置...'
                          : _effectiveDownloadDirectory,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _hasCustomDirectory
                          ? '当前使用自定义下载位置，修改后仅对新下载生效'
                          : '当前使用默认下载位置，修改后仅对新下载生效',
                      style: TextStyle(
                        color: Theme.of(context).textTheme.bodySmall?.color,
                      ),
                    ),
                  ],
                ),
                trailing: isSelectingDirectory
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: LoadingIndicator(),
                      )
                    : _hasCustomDirectory
                        ? IconButton(
                            tooltip: '恢复默认',
                            icon: const Icon(Icons.restore_rounded),
                            onPressed: _resetDownloadDirectory,
                          )
                        : null,
                onPressed: (_) => _selectDownloadDirectory(),
              ),
              SettingsTile.switchTile(
                leading: Icons.subtitles_rounded,
                onToggle: (value) {
                  setState(() => downloadDanmaku = value ?? !downloadDanmaku);
                  GStorage.putSetting(
                      SettingsKeys.downloadDanmaku, downloadDanmaku);
                },
                title: Text('缓存弹幕'),
                description: Text(
                  '下载视频时同时缓存弹幕数据',
                ),
                initialValue: downloadDanmaku,
              ),
            ],
          ),
          SettingsSection(
            title: Text('说明'),
            tiles: [
              SettingsTile(
                leading: Icons.info_outline_rounded,
                title: Text('关于并发设置'),
                description: Text(
                  '• 集数并发：同时下载多少集视频\n'
                  '• 分片并发：每集内同时下载多少个视频片段\n'
                  '• 较高的并发可提升速度，但可能被服务器限制\n'
                  '• 修改后对新开始的下载生效',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
