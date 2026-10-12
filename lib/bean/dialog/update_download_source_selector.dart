import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:kazumi/services/update/update_download_source.dart';

class UpdateDownloadSourceSelector extends StatelessWidget {
  const UpdateDownloadSourceSelector({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final UpdateDownloadSource value;
  final ValueChanged<UpdateDownloadSource> onChanged;

  @override
  Widget build(BuildContext context) {
    if (kIsWeb ||
        !const {
          TargetPlatform.android,
          TargetPlatform.windows,
          TargetPlatform.macOS,
        }.contains(defaultTargetPlatform)) {
      return const SizedBox.shrink();
    }
    return DropdownButtonFormField<UpdateDownloadSource>(
      initialValue: value,
      decoration: const InputDecoration(labelText: '下载源'),
      items: [
        for (final source in UpdateDownloadSource.values)
          DropdownMenuItem(value: source, child: Text(source.label)),
      ],
      onChanged: (source) {
        if (source != null) onChanged(source);
      },
    );
  }
}
