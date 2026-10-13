import 'package:flutter/material.dart';
import 'package:kazumi/bean/dialog/dialog.dart';
import 'package:kazumi/bean/settings/settings_dropdown_tile.dart';
import 'package:kazumi/bean/settings/settings_list.dart';
import 'package:kazumi/bean/widget/state_presentation.dart';
import 'package:kazumi/bean/widget/tonal_card.dart';
import 'package:kazumi/services/update/auto_updater.dart';
import 'package:kazumi/services/update/update_download_source.dart';
import 'package:kazumi/utils/date_time.dart';
import 'package:url_launcher/url_launcher.dart';

typedef UpdateDialogChoice = ({
  InstallationType type,
  UpdateDownloadSource source,
});

/// Pops with an [UpdateDialogChoice] when the user starts the update.
class UpdateAvailableDialog extends StatefulWidget {
  const UpdateAvailableDialog({
    super.key,
    required this.updateInfo,
    this.onDisableAutoUpdateChanged,
  });

  final UpdateInfo updateInfo;

  /// Shows the auto-update opt-out when non-null.
  final ValueChanged<bool>? onDisableAutoUpdateChanged;

  @override
  State<UpdateAvailableDialog> createState() => _UpdateAvailableDialogState();
}

class _UpdateAvailableDialogState extends State<UpdateAvailableDialog> {
  final _notesController = ScrollController();
  var _source = UpdateDownloadSource.mirror;
  late var _type = widget.updateInfo.recommendedInstallationType;
  var _disableAutoUpdate = false;

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final downloadInApp = _type.downloadsInApp;

    return AlertDialog(
      constraints: const BoxConstraints(minWidth: 280, maxWidth: 440),
      insetPadding: const EdgeInsets.all(24),
      backgroundColor: colors.surfaceContainerHigh,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      clipBehavior: Clip.antiAlias,
      scrollable: true,
      titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      title: _buildHeader(context, downloadInApp),
      contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
      content: SizedBox(
        width: 392,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildReleaseNotes(context),
            if (downloadInApp) ...[
              const SizedBox(height: 20),
              _buildDownloadOptions(),
            ],
            if (widget.onDisableAutoUpdateChanged != null) ...[
              const SizedBox(height: 8),
              CheckboxListTile(
                value: _disableAutoUpdate,
                onChanged: (value) {
                  setState(() => _disableAutoUpdate = value ?? false);
                  widget.onDisableAutoUpdateChanged!(_disableAutoUpdate);
                },
                dense: true,
                visualDensity: VisualDensity.compact,
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                title: Text('不再自动检查', style: theme.textTheme.bodyMedium),
              ),
            ],
          ],
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      actionsOverflowButtonSpacing: 8,
      actions: [
        TextButton(
          style: TextButton.styleFrom(minimumSize: const Size(64, 48)),
          onPressed: () => KazumiDialog.dismiss(context: context),
          child: const Text('稍后'),
        ),
        StateActionButton(
          onPressed: () => KazumiDialog.dismiss(
            context: context,
            popWith: (type: _type, source: _source),
          ),
          icon: downloadInApp
              ? Icons.download_rounded
              : Icons.open_in_new_rounded,
          text: downloadInApp ? '更新' : '前往下载',
        ),
      ],
    );
  }

  Widget _buildHeader(BuildContext context, bool downloadInApp) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final info = widget.updateInfo;
    // The fallback action already opens the release page.
    final showReleasePage = downloadInApp && info.releaseNotes.isNotEmpty;

    return Row(
      children: [
        StateIconBadge(
          icon: Icons.system_update_alt_rounded,
          size: 48,
          iconSize: 24,
          backgroundColor: colors.primaryContainer,
          foregroundColor: colors.onPrimaryContainer,
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '发现新版本',
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: colors.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 4,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                    decoration: BoxDecoration(
                      color: colors.secondaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      info.version,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: colors.onSecondaryContainer,
                      ),
                    ),
                  ),
                  if (info.publishedAt.isNotEmpty)
                    Text(
                      formatDate(info.publishedAt),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  if (showReleasePage)
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                      onPressed: () => launchUrl(
                        Uri.parse(info.releaseNotes),
                        mode: LaunchMode.externalApplication,
                      ),
                      iconAlignment: IconAlignment.end,
                      icon: const Icon(Icons.open_in_new_rounded, size: 16),
                      label: const Text('更新日志'),
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildReleaseNotes(BuildContext context) {
    final theme = Theme.of(context);
    final maxHeight =
        (MediaQuery.sizeOf(context).height * 0.22).clamp(96.0, 180.0);

    return TonalCard(
      padding: const EdgeInsets.fromLTRB(16, 12, 4, 12),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Scrollbar(
          controller: _notesController,
          child: SingleChildScrollView(
            controller: _notesController,
            padding: const EdgeInsets.only(right: 12),
            child: Text(
              widget.updateInfo.description.trim(),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDownloadOptions() {
    final types = widget.updateInfo.availableInstallationTypes;
    return SettingsSection(
      margin: EdgeInsets.zero,
      tiles: [
        SettingsDropdownTile<UpdateDownloadSource>(
          leading: Icons.cloud_download_rounded,
          title: const Text('下载源'),
          value: _source,
          options: {
            for (final source in UpdateDownloadSource.values)
              source: source.label,
          },
          onChanged: (source) => setState(() => _source = source),
        ),
        if (types.length > 1)
          SettingsDropdownTile<InstallationType>(
            leading: Icons.inventory_2_rounded,
            title: const Text('安装类型'),
            value: _type,
            options: {for (final type in types) type: type.label},
            onChanged: (type) => setState(() => _type = type),
          ),
      ],
    );
  }
}
