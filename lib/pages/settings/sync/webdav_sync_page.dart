import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kazumi/bean/settings/settings_detail_scaffold.dart';
import 'package:kazumi/bean/settings/settings_list.dart';
import 'package:kazumi/bean/widget/state_presentation.dart';
import 'package:kazumi/pages/settings/sync/sync_settings_widgets.dart';
import 'package:kazumi/services/logging/logger.dart';
import 'package:kazumi/services/storage/storage.dart';
import 'package:kazumi/services/sync/webdav.dart';

class WebDavSyncPage extends StatefulWidget {
  const WebDavSyncPage({super.key});

  @override
  State<WebDavSyncPage> createState() => _WebDavSyncPageState();
}

class _WebDavSyncPageState extends State<WebDavSyncPage> {
  bool _busy = false;
  bool _failed = false;
  String? _message;

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _failed = false;
      _message = '正在连接 WebDAV…';
    });
    try {
      await action();
    } catch (e) {
      KazumiLogger().w('WebDAV settings operation failed', error: e);
      if (mounted) {
        _failed = true;
        _message = '未能完成，请检查网络或服务器配置后重试。';
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _setEnabled(bool enabled) => _run(() async {
        await WebDav().setEnabled(enabled);
        _message = null;
      });

  Future<void> _syncHistory() => _run(() async {
        final webDav = WebDav();
        if (!webDav.initialized) {
          await webDav.init();
        } else if (!webDav.isHistorySyncing) {
          await webDav.ping();
        }
        if (mounted) setState(() => _message = '正在同步观看记录…');
        await webDav.syncHistory();
        _message = '观看记录已同步';
      });

  Future<void> _configure() async {
    await context.push('/settings/webdav/editor');
    if (mounted) {
      setState(() {
        _message = null;
        _failed = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final enabled = GStorage.getSetting(SettingsKeys.webDavEnable);
    final history = GStorage.getSetting(SettingsKeys.webDavEnableHistory);
    final collect = GStorage.getSetting(SettingsKeys.webDavEnableCollect);
    final url = GStorage.getSetting(SettingsKeys.webDavURL).trim();
    final configured = url.isNotEmpty;
    final host = Uri.tryParse(url)?.host;
    return PopScope(
      canPop: !_busy,
      child: SettingsDetailScaffold(
        title: const Text('多设备同步'),
        body: SyncPageBody(
          maxWidth: 720,
          children: [
            const SyncPageIntro(
              icon: Icons.devices_rounded,
              title: 'WebDAV',
              description: '连接自己的云盘，同步观看记录与收藏。',
            ),
            SettingsSection(
              margin: EdgeInsets.zero,
              tiles: [
                SettingsTile(
                  leading: Icons.dns_rounded,
                  title: Text(configured ? '同步服务器' : '连接你的云盘'),
                  description: Text(configured
                      ? (host == null || host.isEmpty ? '已保存服务器地址' : host)
                      : '需要支持 WebDAV 的云盘或服务器'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  enabled: !_busy,
                  onPressed: (_) => _configure(),
                ),
                SettingsTile.switchTile(
                  leading: Icons.cloud_sync_rounded,
                  title: const Text('启用 WebDAV'),
                  description: Text(configured
                      ? (enabled ? '已开启，选择下方要同步的内容' : '开启后选择要同步的内容')
                      : '请先配置服务器'),
                  initialValue: enabled,
                  enabled: configured && !_busy,
                  onToggle: (value) => _setEnabled(value ?? !enabled),
                ),
              ],
            ),
            SettingsSection(
              title: const Text('同步内容'),
              margin: EdgeInsets.zero,
              tiles: [
                SettingsTile.switchTile(
                  leading: Icons.history_rounded,
                  title: const Text('观看记录'),
                  description: const Text('自动同步播放进度与历史记录'),
                  initialValue: history,
                  enabled: enabled && !_busy,
                  onToggle: (value) async {
                    await GStorage.putSetting(
                        SettingsKeys.webDavEnableHistory, value ?? !history);
                    if (mounted) setState(() {});
                  },
                ),
                SettingsTile.switchTile(
                  leading: Icons.favorite_rounded,
                  title: const Text('收藏'),
                  description: const Text('在收藏页同步所有追番分类'),
                  initialValue: collect,
                  enabled: enabled && !_busy,
                  onToggle: (value) async {
                    await GStorage.putSetting(
                        SettingsKeys.webDavEnableCollect, value ?? !collect);
                    if (mounted) setState(() {});
                  },
                ),
              ],
            ),
            StateActionButton(
              onPressed: enabled && !_busy ? _syncHistory : null,
              text: _busy ? '请稍候…' : '立即同步观看记录',
              icon: Icons.sync_rounded,
            ),
            if (_message != null)
              SyncFeedback(message: _message!, error: _failed, busy: _busy),
          ],
        ),
      ),
    );
  }
}
