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
    subtitle: '番剧信息、规则仓库与图片默认已开启加速，可按网络情况调整。',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        NetworkMirrorSettings(margin: EdgeInsets.zero),
        OnboardingHint(text: '可在「设置 → 网络设置」中调整。'),
      ],
    ),
  );
}
