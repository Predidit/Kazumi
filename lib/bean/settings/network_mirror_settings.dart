import 'package:flutter/material.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/bean/settings/settings_list.dart';
import 'package:kazumi/services/network/image_acceleration.dart';
import 'package:kazumi/services/storage/storage.dart';

class NetworkMirrorSettings extends StatefulWidget {
  const NetworkMirrorSettings({super.key, this.margin});

  final EdgeInsetsGeometry? margin;

  @override
  State<NetworkMirrorSettings> createState() => _NetworkMirrorSettingsState();
}

class _NetworkMirrorSettingsState extends State<NetworkMirrorSettings> {
  Future<void> _save<T>(SettingKey<T> key, T value) async {
    await GStorage.putSetting(key, value);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final bangumiProxy = GStorage.getSetting(SettingsKeys.enableBangumiProxy);
    final gitProxy = GStorage.getSetting(SettingsKeys.enableGitProxy);
    final imageAcceleration = ImageAcceleration.fromSetting(
      GStorage.getSetting(SettingsKeys.imageAcceleration),
    );
    return SettingsSection(
      title: const Text('访问加速'),
      margin: widget.margin,
      tiles: [
        SettingsTile.switchTile(
          leading: Icons.travel_explore_rounded,
          title: const Text('番剧条目镜像'),
          description: const Text('加速番剧信息、热门与时间表加载'),
          initialValue: bangumiProxy,
          onToggle: (value) =>
              _save(SettingsKeys.enableBangumiProxy, value ?? !bangumiProxy),
        ),
        SettingsTile.switchTile(
          leading: Icons.extension_rounded,
          title: const Text('规则仓库镜像'),
          description: const Text('加速规则的下载与更新'),
          initialValue: gitProxy,
          onToggle: (value) =>
              _save(SettingsKeys.enableGitProxy, value ?? !gitProxy),
        ),
        SettingsTile(
          leading: Icons.image_rounded,
          title: const Text('图片加速'),
          description: const Text('加速封面与头像加载'),
          value: SizedBox(
            // Match the trailing Material 3 switch width.
            width: 60,
            child: Text(imageAcceleration.label, textAlign: TextAlign.center),
          ),
          onPressed: (context) =>
              _selectImageAcceleration(context, imageAcceleration),
        ),
      ],
    );
  }

  Future<void> _selectImageAcceleration(
    BuildContext context,
    ImageAcceleration current,
  ) async {
    final selected = await KazumiDialog.show<ImageAcceleration>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('图片加速'),
        children: [
          RadioGroup<ImageAcceleration>(
            groupValue: current,
            onChanged: (value) => Navigator.of(context).pop(value),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final mode in ImageAcceleration.values)
                  RadioListTile<ImageAcceleration>(
                    value: mode,
                    title: Text(mode.label),
                    subtitle: Text(mode.description),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
    if (mounted && selected != null && selected != current) {
      await _save(SettingsKeys.imageAcceleration, selected.name);
    }
  }
}

extension on ImageAcceleration {
  String get label => switch (this) {
    ImageAcceleration.direct => '直连',
    ImageAcceleration.ech => 'ECH',
    ImageAcceleration.mirror => '镜像',
  };

  String get description => switch (this) {
    ImageAcceleration.direct => '直接从 Bangumi 加载图片',
    ImageAcceleration.ech => '通过 ECH 加载 Bangumi 图片，推荐使用',
    ImageAcceleration.mirror => '通过图片镜像服务加载 Bangumi 图片',
  };
}
