import 'package:flutter/material.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/bean/settings/settings_list.dart';
import 'package:kazumi/services/network/acceleration_mode.dart';
import 'package:kazumi/services/network/bangumi_acceleration.dart';
import 'package:kazumi/services/network/image_acceleration.dart';
import 'package:kazumi/services/network/rules_mirror.dart';
import 'package:kazumi/services/storage/storage.dart';

class NetworkMirrorSettings extends StatefulWidget {
  const NetworkMirrorSettings({super.key, this.margin});

  final EdgeInsetsGeometry? margin;

  @override
  State<NetworkMirrorSettings> createState() => _NetworkMirrorSettingsState();
}

class _NetworkMirrorSettingsState extends State<NetworkMirrorSettings> {
  @override
  Widget build(BuildContext context) => SettingsSection(
    title: const Text('访问加速'),
    margin: widget.margin,
    tiles: [
      _tile(
        icon: Icons.travel_explore_rounded,
        title: '番剧条目加速',
        description: '番剧信息与评论',
        current: BangumiAcceleration.current,
        modes: BangumiAcceleration.values,
        setting: SettingsKeys.bangumiAcceleration,
      ),
      _tile(
        icon: Icons.extension_rounded,
        title: '规则仓库加速',
        description: '规则下载与更新',
        current: RulesMirror.current,
        modes: RulesMirror.values,
        setting: SettingsKeys.rulesMirror,
      ),
      _tile(
        icon: Icons.image_rounded,
        title: '图片加速',
        description: '封面与头像',
        current: ImageAcceleration.current,
        modes: ImageAcceleration.values,
        setting: SettingsKeys.imageAcceleration,
      ),
    ],
  );

  SettingsTile _tile<T extends AccelerationMode>({
    required IconData icon,
    required String title,
    required String description,
    required T current,
    required List<T> modes,
    required SettingKey<String> setting,
  }) => SettingsTile(
    leading: icon,
    title: Text(title),
    description: Text(
      description,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    ),
    value: SizedBox(
      width: 72,
      child: Text(current.label, textAlign: TextAlign.center),
    ),
    onPressed: (context) async {
      final changed = await selectAccelerationMode(
        context,
        title: title,
        current: current,
        modes: modes,
        setting: setting,
      );
      if (changed && mounted) setState(() {});
    },
  );
}

/// Shows a picker for [modes] and saves the choice; returns whether it changed.
Future<bool> selectAccelerationMode<T extends AccelerationMode>(
  BuildContext context, {
  required String title,
  required T current,
  required List<T> modes,
  required SettingKey<String> setting,
}) async {
  final selected = await KazumiDialog.show<T>(
    context: context,
    builder: (context) => SimpleDialog(
      title: Text(title),
      children: [
        RadioGroup<T>(
          groupValue: current,
          onChanged: (value) => Navigator.of(context).pop(value),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final mode in modes)
                RadioListTile<T>(
                  value: mode,
                  title: Text(mode.label),
                  subtitle: Text(
                    mode.description,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
          ),
        ),
      ],
    ),
  );
  if (selected == null || selected == current) return false;
  await GStorage.putSetting(setting, selected.name);
  return true;
}
