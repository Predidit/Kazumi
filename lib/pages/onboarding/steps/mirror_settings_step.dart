import 'package:flutter/material.dart';
import 'package:kazumi/bean/settings/network_mirror_settings.dart';
import 'package:kazumi/pages/onboarding/onboarding_step_layout.dart';
import 'package:kazumi/services/storage/storage.dart';

class MirrorSettingsStep extends StatefulWidget {
  const MirrorSettingsStep({super.key});

  @override
  State<MirrorSettingsStep> createState() => _MirrorSettingsStepState();
}

class _MirrorSettingsStepState extends State<MirrorSettingsStep> {
  late bool _enableGitProxy;
  late bool _enableBangumiProxy;

  @override
  void initState() {
    super.initState();
    _enableGitProxy = GStorage.getSetting(SettingsKeys.enableGitProxy);
    _enableBangumiProxy = GStorage.getSetting(SettingsKeys.enableBangumiProxy);
  }

  @override
  Widget build(BuildContext context) => OnboardingStepLayout(
        leading: const OnboardingStepIcon(
          icon: Icons.public_rounded,
          shape: OnboardingIconShape.clover,
        ),
        title: '让连接更顺畅',
        subtitle: '中国大陆用户推荐启用镜像，加快番剧信息与规则的访问。',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            NetworkMirrorSettings(
              margin: EdgeInsets.zero,
              enableBangumiProxy: _enableBangumiProxy,
              enableGitProxy: _enableGitProxy,
              onBangumiChanged: (value) async {
                setState(() => _enableBangumiProxy = value);
                await GStorage.putSetting(
                    SettingsKeys.enableBangumiProxy, value);
              },
              onGitChanged: (value) async {
                setState(() => _enableGitProxy = value);
                await GStorage.putSetting(SettingsKeys.enableGitProxy, value);
              },
            ),
            const OnboardingHint(text: '可在「设置 → 网络设置」中调整。'),
          ],
        ),
      );
}
