import 'package:flutter/material.dart';
import 'package:kazumi/bean/settings/network_mirror_settings.dart';
import 'package:kazumi/pages/onboarding/onboarding_step_layout.dart';

class MirrorSettingsStep extends StatelessWidget {
  const MirrorSettingsStep({super.key});

  @override
  Widget build(BuildContext context) => const OnboardingStepLayout(
    leading: OnboardingStepIcon(
      icon: Icons.public_rounded,
      shape: OnboardingIconShape.clover,
    ),
    title: '让连接更顺畅',
    subtitle: '中国大陆用户推荐启用镜像，加快番剧信息与规则的访问。图片默认使用 ECH 加速。',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        NetworkMirrorSettings(margin: EdgeInsets.zero),
        OnboardingHint(text: '可在「设置 → 网络设置」中调整。'),
      ],
    ),
  );
}
