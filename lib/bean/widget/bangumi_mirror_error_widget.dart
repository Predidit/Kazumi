import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/bean/widget/error_widget.dart';
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
      errMsg: '啊咧（⊙.⊙） 无法加载数据\nBangumi 镜像${mirrorEnabled ? '已启用' : '已禁用'}',
      actions: [
        GeneralErrorButton(
          onPressed: () async {
            await context.pushNamed('/settings/webdav/');
            onSettingsReturned?.call();
          },
          text: '镜像开关',
        ),
        GeneralErrorButton(
          onPressed: onRetry,
          text: '点击重试',
        ),
      ],
    );
  }
}
