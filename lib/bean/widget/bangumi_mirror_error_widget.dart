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
    final mirrorEnabled = GStorage.setting
        .get(SettingBoxKey.enableBangumiProxy, defaultValue: false);

    return GeneralErrorWidget(
      errMsg:
          'Oh no (⊙.⊙) Failed to load data\nBangumi mirror ${mirrorEnabled ? 'enabled' : 'disabled'}',
      actions: [
        GeneralErrorButton(
          onPressed: () async {
            await Modular.to.pushNamed('/settings/webdav/');
            onSettingsReturned?.call();
          },
          text: 'Mirror toggle',
        ),
        GeneralErrorButton(
          onPressed: onRetry,
          text: 'Tap to retry',
        ),
      ],
    );
  }
}
