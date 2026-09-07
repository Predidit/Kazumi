import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/bean/widget/error_widget.dart';
import 'package:kazumi/bean/widget/state_presentation.dart';
import 'package:kazumi/services/storage/storage.dart';

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
    final mirrorEnabled = GStorage.getSetting(SettingsKeys.enableBangumiProxy);

    return GeneralErrorWidget(
      title: '暂时无法加载番剧',
      errMsg: '请检查网络连接，或调整镜像设置后重试。\nBangumi 镜像${mirrorEnabled ? '已启用' : '已禁用'}',
      icon: Icons.cloud_off_rounded,
      onRetry: onRetry,
      actions: [
        StateActionButton.tonal(
          onPressed: () async {
            await context.pushNamed('/settings/proxy/');
            onSettingsReturned?.call();
          },
          icon: Icons.tune_rounded,
          text: '镜像设置',
        ),
      ],
    );
  }
}
