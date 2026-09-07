import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';

import 'package:kazumi/bean/settings/settings_detail_scaffold.dart';
import 'package:kazumi/bean/widget/state_presentation.dart';
import 'package:kazumi/pages/settings/sync/sync_settings_widgets.dart';
import 'package:kazumi/services/storage/storage.dart';
import 'package:kazumi/services/sync/bangumi_sync_service.dart';

enum _SyncStatus {
  unconnected('未连接', Icons.link_off_rounded),
  unconfigured('未配置', Icons.settings_outlined),
  connecting('正在连接', Icons.sync_rounded),
  connectionError('连接异常', Icons.error_outline_rounded),
  enabled('已开启', Icons.check_circle_outline_rounded),
  disabled('已关闭', Icons.pause_circle_outline_rounded),
  contentRequired('待选择内容', Icons.tune_rounded);

  const _SyncStatus(this.label, this.icon);

  final String label;
  final IconData icon;
}

class SyncSettingsPage extends StatefulWidget {
  const SyncSettingsPage({super.key});

  @override
  State<SyncSettingsPage> createState() => _SyncSettingsPageState();
}

class _SyncSettingsPageState extends State<SyncSettingsPage> {
  Future<void> _open(String route) async {
    await context.pushNamed(route);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) => SettingsDetailScaffold(
        title: const Text('同步设置'),
        body: ListenableBuilder(
          listenable: BangumiSyncService(),
          builder: (context, _) {
            final bangumi = BangumiSyncService();
            final hasToken =
                GStorage.getSetting(SettingsKeys.bangumiAccessToken)
                    .trim()
                    .isNotEmpty;
            final bangumiEnabled =
                GStorage.getSetting(SettingsKeys.bangumiSyncEnable);
            final hasServer =
                GStorage.getSetting(SettingsKeys.webDavURL).trim().isNotEmpty;
            final webDavEnabled =
                GStorage.getSetting(SettingsKeys.webDavEnable);
            final hasSyncContent =
                GStorage.getSetting(SettingsKeys.webDavEnableHistory) ||
                    GStorage.getSetting(SettingsKeys.webDavEnableCollect);
            final colors = Theme.of(context).colorScheme;
            final cards = [
              _SyncServiceCard(
                title: '追番同步',
                service: 'Bangumi',
                description: '与 Bangumi 保持相同的追番状态。',
                content: '想看 · 在看 · 看过 · 搁置 · 抛弃',
                icon: Icons.bookmarks_rounded,
                color: colors.secondaryContainer,
                onColor: colors.onSecondaryContainer,
                status: bangumi.isConnecting
                    ? _SyncStatus.connecting
                    : bangumi.lastError != null
                        ? _SyncStatus.connectionError
                        : !hasToken
                            ? _SyncStatus.unconnected
                            : bangumiEnabled
                                ? _SyncStatus.enabled
                                : _SyncStatus.disabled,
                action: hasToken ? '管理追番同步' : '连接 Bangumi',
                onPressed: () => _open('/settings/bangumi/'),
              ),
              _SyncServiceCard(
                title: '多设备同步',
                service: 'WebDAV',
                description: '通过自己的云盘，在其他设备接着看。',
                content: '观看记录 · 收藏',
                icon: Icons.devices_rounded,
                color: colors.tertiaryContainer,
                onColor: colors.onTertiaryContainer,
                status: !hasServer
                    ? _SyncStatus.unconfigured
                    : webDavEnabled
                        ? hasSyncContent
                            ? _SyncStatus.enabled
                            : _SyncStatus.contentRequired
                        : _SyncStatus.disabled,
                action: hasServer ? '管理多设备同步' : '设置 WebDAV',
                onPressed: () => _open('/settings/webdav/'),
              ),
            ];
            return SyncPageBody(
              children: [
                const SyncPageIntro(
                  icon: Icons.sync_rounded,
                  title: '让追番保持同步',
                  description: '选择需要的服务，也可以同时使用。',
                ),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final largeText =
                        MediaQuery.textScalerOf(context).scale(16) > 22;
                    if (constraints.maxWidth >= 680 && !largeText) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: cards[0]),
                          const SizedBox(width: 16),
                          Expanded(child: cards[1]),
                        ],
                      );
                    }
                    return Column(spacing: 16, children: cards);
                  },
                ),
              ],
            );
          },
        ),
      );
}

class _SyncServiceCard extends StatelessWidget {
  const _SyncServiceCard({
    required this.title,
    required this.service,
    required this.description,
    required this.content,
    required this.icon,
    required this.color,
    required this.onColor,
    required this.status,
    required this.action,
    required this.onPressed,
  });

  final String title;
  final String service;
  final String description;
  final String content;
  final IconData icon;
  final Color color;
  final Color onColor;
  final _SyncStatus status;
  final String action;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              StateIconBadge(
                icon: icon,
                size: 56,
                iconSize: 26,
                backgroundColor: color,
                foregroundColor: onColor,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: _SyncStatusChip(status: status),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(service,
              style: theme.textTheme.labelLarge
                  ?.copyWith(color: theme.colorScheme.primary)),
          const SizedBox(height: 6),
          Semantics(
            header: true,
            child: Text(title,
                style: theme.textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w600)),
          ),
          const SizedBox(height: 8),
          Text(description, style: theme.textTheme.bodyMedium),
          const SizedBox(height: 16),
          Text(content,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 24),
          StateActionButton.tonal(
            onPressed: onPressed,
            text: action,
            icon: Icons.arrow_forward_rounded,
          ),
        ],
      ),
    );
  }
}

class _SyncStatusChip extends StatelessWidget {
  const _SyncStatusChip({required this.status});

  final _SyncStatus status;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final (background, foreground) = switch (status) {
      _SyncStatus.connectionError => (
          colors.errorContainer,
          colors.onErrorContainer
        ),
      _SyncStatus.enabled => (
          colors.primaryContainer,
          colors.onPrimaryContainer
        ),
      _ => (colors.surfaceContainerHighest, colors.onSurfaceVariant),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(status.icon, size: 16, color: foreground),
          const SizedBox(width: 6),
          Flexible(
            child: Text(status.label,
                style: Theme.of(context)
                    .textTheme
                    .labelMedium
                    ?.copyWith(color: foreground)),
          ),
        ],
      ),
    );
  }
}
