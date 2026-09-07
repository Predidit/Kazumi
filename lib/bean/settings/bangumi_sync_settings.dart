import 'package:flutter/material.dart';
import 'package:kazumi/bean/settings/settings_list.dart';
import 'package:kazumi/bean/widget/loading_indicator.dart';
import 'package:kazumi/services/storage/storage.dart';
import 'package:kazumi/services/sync/bangumi_sync_service.dart';

class BangumiSyncSettings extends StatefulWidget {
  const BangumiSyncSettings({
    super.key,
    this.onConfigure,
    this.enabled = true,
    this.margin,
  });

  final Future<void> Function()? onConfigure;
  final bool enabled;
  final EdgeInsetsGeometry? margin;

  @override
  State<BangumiSyncSettings> createState() => _BangumiSyncSettingsState();
}

class _BangumiSyncSettingsState extends State<BangumiSyncSettings> {
  final _bangumi = BangumiSyncService();
  bool _isUpdating = false;
  String? _actionError;

  Future<void> _run(Future<void> Function() action) async {
    if (_isUpdating || _bangumi.isConnecting || !widget.enabled) return;
    setState(() {
      _isUpdating = true;
      _actionError = null;
    });
    try {
      await action();
    } catch (e) {
      if (mounted) {
        _actionError = _bangumi.lastError == null
            ? BangumiSyncService.describeError(e)
            : null;
      }
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _bangumi,
      builder: (context, _) {
        final syncEnabled = GStorage.getSetting(SettingsKeys.bangumiSyncEnable);
        final busy = _isUpdating || _bangumi.isConnecting;
        final error = _actionError ?? _bangumi.lastError;
        final canInteract = widget.enabled && !busy;
        final description = busy
            ? '正在等待或验证连接，请稍候'
            : error != null
                ? '$error${syncEnabled ? '\n同步开关已保留，下次同步时会重新尝试连接' : ''}'
                : syncEnabled
                    ? '同步已开启'
                    : '同步已关闭，开启后自动同步追番状态';
        return SettingsSection(
          title: const Text('Bangumi'),
          margin: widget.margin,
          tiles: [
            SettingsTile.switchTile(
              leading: Icons.sync_rounded,
              title: const Text('Bangumi 同步'),
              description: const Text('与 Bangumi 自动同步追番状态'),
              initialValue: syncEnabled,
              enabled: canInteract,
              onToggle: (value) =>
                  _run(() => _bangumi.setEnabled(value ?? !syncEnabled)),
            ),
            SettingsTile(
              leading: error == null
                  ? Icons.cloud_outlined
                  : Icons.error_outline_rounded,
              title: Text(
                busy
                    ? '正在连接 Bangumi…'
                    : error != null
                        ? '连接失败'
                        : _bangumi.initialized
                            ? '已连接：${_bangumi.username}'
                            : '尚未连接',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              description: Tooltip(
                message: description,
                excludeFromSemantics: true,
                child: SizedBox(
                  width: double.infinity,
                  child: Stack(
                    children: [
                      // Reserve three lines while respecting text scaling.
                      const ExcludeSemantics(child: Text('\n\n')),
                      Positioned.fill(
                        child: Text(
                          description,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              trailing: Stack(
                alignment: Alignment.center,
                children: [
                  Visibility(
                    visible: !busy,
                    maintainSize: true,
                    maintainState: true,
                    maintainAnimation: true,
                    child: TextButton(
                      onPressed: canInteract ? () => _run(_bangumi.ping) : null,
                      child: Text(error != null ? '重试连接' : '测试连接'),
                    ),
                  ),
                  if (busy)
                    const SizedBox(
                        width: 20, height: 20, child: LoadingIndicator()),
                ],
              ),
            ),
            if (widget.onConfigure != null)
              SettingsTile(
                leading: Icons.tune_rounded,
                title: const Text('Bangumi 配置'),
                enabled: canInteract,
                onPressed: (_) async {
                  await widget.onConfigure!();
                  if (mounted) setState(() => _actionError = null);
                },
              ),
          ],
        );
      },
    );
  }
}
