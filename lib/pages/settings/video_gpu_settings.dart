import 'dart:io';

import 'package:flutter/material.dart';
import 'package:kazumi/bean/settings/settings_list.dart';
import 'package:kazumi/services/enhancement/video_gpu.dart';
import 'package:kazumi/services/storage/storage.dart';
import 'package:media_kit_video/media_kit_video.dart';

class VideoGpuSettingsTile extends StatefulWidget {
  const VideoGpuSettingsTile({super.key});

  @override
  State<VideoGpuSettingsTile> createState() => _VideoGpuSettingsTileState();
}

class _VideoGpuSettingsTileState extends State<VideoGpuSettingsTile> {
  late Future<List<VideoAdapter>> _adapters;
  late String _selected;
  String get _title => Platform.isAndroid ? 'Vulkan GPU' : '视频处理 GPU';

  @override
  void initState() {
    super.initState();
    _adapters = VideoGpu.enumerate();
    _selected = VideoGpu.selection;
  }

  Future<void> _choose(List<VideoAdapter> adapters) async {
    final value = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(_title),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.of(context).pop(''),
            child: const Text('自动（推荐）'),
          ),
          for (final adapter in adapters)
            SimpleDialogOption(
              onPressed: () => Navigator.of(context).pop(adapter.id),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(adapter.name),
                  Text(
                    [
                      if (adapter.apiVersion case final version?)
                        'Vulkan $version',
                      if ((adapter.memoryMiB ?? 0) > 0)
                        '${adapter.memoryMiB} MiB 显存',
                      if (adapters.where((a) => a.name == adapter.name).length >
                          1)
                        adapter.id,
                    ].join(' · '),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
    if (value == null || !mounted) return;
    await GStorage.putSetting(VideoGpu.setting, value);
    if (mounted) {
      setState(() => _selected = value);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<VideoAdapter>>(
      future: _adapters,
      builder: (context, snapshot) {
        final adapters = snapshot.data ?? const <VideoAdapter>[];
        final loading = snapshot.connectionState != ConnectionState.done;
        final configured = adapters.where((a) => a.id == _selected).firstOrNull;
        final description = loading
            ? '正在检测设备…'
            : configured?.name ??
                  (_selected.isEmpty ? '自动（推荐）' : '所选设备未找到 · 播放时使用自动');
        return SettingsSection(
          title: const Text('渲染设备'),
          bottomInfo: Text(
            Platform.isWindows
                ? '下次打开视频生效。使用与应用显示不同的 GPU 时需要跨卡复制，可能增加功耗和延迟。'
                : '可选择系统提供的 Vulkan 1.2 及以上硬件 GPU，使用「自动」或「gpu-next」渲染器时生效。',
          ),
          tiles: [
            SettingsTile(
              leading: Icons.memory_rounded,
              title: Text(_title),
              description: Text(snapshot.hasError ? '设备检测失败' : description),
              onPressed: loading ? null : (_) => _choose(adapters),
            ),
            if (!loading && adapters.isEmpty)
              SettingsTile(
                title: Text(
                  snapshot.hasError
                      ? '重试检测'
                      : Platform.isAndroid
                      ? '未检测到可选的 Vulkan GPU'
                      : '未检测到可选设备',
                ),
                description: const Text('自动模式仍可使用系统推荐的渲染路径'),
                onPressed: (_) =>
                    setState(() => _adapters = VideoGpu.enumerate()),
              ),
          ],
        );
      },
    );
  }
}
