import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/bean/widget/error_widget.dart';
import 'package:kazumi/bean/widget/state_presentation.dart';
import 'package:kazumi/services/network/bangumi_acceleration.dart';

class BangumiMirrorErrorWidget extends StatelessWidget {
  const BangumiMirrorErrorWidget({
    super.key,
    required this.onRetry,
    this.onSettingsReturned,
  });

  final VoidCallback onRetry;
  final VoidCallback? onSettingsReturned;

  @override
  Widget build(BuildContext context) {
    final acceleration = BangumiAcceleration.current;

    return GeneralErrorWidget(
      title: '暂时无法加载番剧',
      errMsg: '请检查网络连接，或调整加速设置后重试。\n番剧条目加速：${acceleration.label}',
      icon: Icons.cloud_off_rounded,
      onRetry: onRetry,
      actions: [
        StateActionButton.tonal(
          onPressed: () async {
            await context.pushNamed('/settings/proxy/');
            onSettingsReturned?.call();
          },
          icon: Icons.tune_rounded,
          text: '加速设置',
        ),
      ],
    );
  }
}
