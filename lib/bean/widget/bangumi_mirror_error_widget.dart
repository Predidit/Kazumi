import 'package:flutter/material.dart';
import 'package:kazumi/bean/widget/error_widget.dart';
import 'package:kazumi/bean/widget/state_presentation.dart';
import 'package:kazumi/pages/settings/settings_navigation.dart';
import 'package:kazumi/services/storage/storage.dart';

class BangumiMirrorErrorWidget extends StatefulWidget {
  const BangumiMirrorErrorWidget({
    super.key,
    required this.onRetry,
  });

  final VoidCallback onRetry;

  @override
  State<BangumiMirrorErrorWidget> createState() =>
      _BangumiMirrorErrorWidgetState();
}

class _BangumiMirrorErrorWidgetState extends State<BangumiMirrorErrorWidget> {
  late final _changes =
      GStorage.watchSettings([SettingsKeys.enableBangumiProxy]);

  @override
  Widget build(BuildContext context) => StreamBuilder<void>(
      stream: _changes,
      builder: (context, _) {
        final mirrorEnabled =
            GStorage.getSetting(SettingsKeys.enableBangumiProxy);

        return GeneralErrorWidget(
          title: '暂时无法加载番剧',
          errMsg:
              '请检查网络连接，或调整镜像设置后重试。\nBangumi 镜像${mirrorEnabled ? '已启用' : '已禁用'}',
          icon: Icons.cloud_off_rounded,
          onRetry: widget.onRetry,
          actions: [
            StateActionButton.tonal(
              onPressed: () async {
                await openSettings(context, '/settings/proxy');
              },
              icon: Icons.tune_rounded,
              text: '镜像设置',
            ),
          ],
        );
      });
}
