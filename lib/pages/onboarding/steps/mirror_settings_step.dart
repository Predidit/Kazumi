import 'package:flutter/material.dart';
import 'package:kazumi/pages/onboarding/onboarding_step_layout.dart';
import 'package:kazumi/services/storage/storage.dart';

class MirrorSettingsStep extends StatefulWidget {
  const MirrorSettingsStep({super.key});

  @override
  State<MirrorSettingsStep> createState() => _MirrorSettingsStepState();
}

class _MirrorSettingsStepState extends State<MirrorSettingsStep> {
  late bool enableGitProxy;
  late bool enableBangumiProxy;

  @override
  void initState() {
    super.initState();
    enableGitProxy = GStorage.getSetting(SettingsKeys.enableGitProxy);
    enableBangumiProxy = GStorage.getSetting(SettingsKeys.enableBangumiProxy);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return OnboardingStepLayout(
      leading: const OnboardingStepIcon(icon: Icons.public_rounded),
      title: '网络镜像',
      subtitle: '中国大陆用户推荐启用，提升访问速度',
      child: Align(
        alignment: Alignment.topCenter,
        child: Card(
          elevation: 0,
          margin: EdgeInsets.zero,
          color: colorScheme.surfaceContainerLow,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SwitchListTile(
                secondary: const Icon(Icons.travel_explore_rounded),
                title: const Text('Bangumi 镜像'),
                subtitle: const Text('加速热门与时间表加载'),
                value: enableBangumiProxy,
                onChanged: (value) async {
                  enableBangumiProxy = value;
                  await GStorage.putSetting(
                      SettingsKeys.enableBangumiProxy, value);
                  if (mounted) {
                    setState(() {});
                  }
                },
              ),
              SwitchListTile(
                secondary: const Icon(Icons.extension_rounded),
                title: const Text('规则仓库镜像'),
                subtitle: const Text('加速规则的下载与更新'),
                value: enableGitProxy,
                onChanged: (value) async {
                  enableGitProxy = value;
                  await GStorage.putSetting(SettingsKeys.enableGitProxy, value);
                  if (mounted) {
                    setState(() {});
                  }
                },
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                child: Row(
                  children: [
                    Icon(Icons.info_outline_rounded,
                        size: 16, color: colorScheme.onSurfaceVariant),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '可稍后在 设置 → 同步设置 中修改',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: colorScheme.onSurfaceVariant),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
