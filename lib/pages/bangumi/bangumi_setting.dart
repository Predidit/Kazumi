import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:kazumi/bean/appbar/sys_app_bar.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/bean/settings/settings_list.dart';
import 'package:kazumi/bean/settings/bangumi_sync_settings.dart';
import 'package:kazumi/bean/widget/loading_indicator.dart';
import 'package:kazumi/modules/bangumi/sync_priority.dart';
import 'package:kazumi/services/storage/storage.dart';
import 'package:kazumi/services/sync/bangumi_sync_service.dart';

class BangumiEditorPage extends StatefulWidget {
  const BangumiEditorPage({super.key});

  @override
  State<BangumiEditorPage> createState() => _BangumiEditorPageState();
}

class _BangumiEditorPageState extends State<BangumiEditorPage>
    with KazumiDialogOwner {
  final TextEditingController _tokenController = TextEditingController();
  bool _passwordVisible = false;
  bool _isVerifying = false;
  String? _tokenError;
  String? _tokenStatus;
  late bool _immediateSyncToastEnabled;
  late int _syncPriority;
  final MenuController _syncPriorityMenuController = MenuController();

  bool get _isBusy => _isVerifying || dialogs.isRunning;

  @override
  void initState() {
    super.initState();
    _tokenController.text =
        GStorage.getSetting(SettingsKeys.bangumiAccessToken);
    _immediateSyncToastEnabled =
        GStorage.getSetting(SettingsKeys.bangumiImmediateSyncToastEnable);
    _syncPriority = GStorage.getSetting(SettingsKeys.bangumiSyncPriority);
  }

  @override
  void dispose() {
    _tokenController.dispose();
    super.dispose();
  }

  Future<void> _updateSyncPriority(int value) async {
    await GStorage.putSetting(SettingsKeys.bangumiSyncPriority, value);
    if (!mounted) return;
    setState(() {
      _syncPriority = value;
    });
  }

  Future<void> _syncWithProgress() async {
    if (_isBusy) return;
    if (_tokenController.text.trim() !=
        GStorage.getSetting(SettingsKeys.bangumiAccessToken).trim()) {
      setState(() => _tokenError = 'Token 已修改，请先验证并保存，再同步');
      return;
    }
    final syncEnable = GStorage.getSetting(SettingsKeys.bangumiSyncEnable);
    if (!syncEnable) {
      KazumiDialog.showToast(message: '请先开启 Bangumi 同步');
      return;
    }

    final progressDialogKey = GlobalKey<_BangumiSyncProgressDialogState>();
    await dialogs.run((task) async {
      await task.loading(
        builder: (context) =>
            _BangumiSyncProgressDialog(key: progressDialogKey),
        action: () async {
          await BangumiSyncService().syncCollectibles(
            onProgress: (message, current, total) {
              progressDialogKey.currentState?.update(
                total > 0 ? '$message ($current/$total)' : message,
                total > 0 ? (current / total).clamp(0.0, 1.0).toDouble() : null,
              );
            },
          );
        },
      );
    }, onError: (e, _) {
      KazumiDialog.showToast(
          message: 'Bangumi 同步失败：${BangumiSyncService.describeError(e)}');
    });
  }

  Future<void> _saveToken() async {
    if (_isBusy) return;
    setState(() {
      _isVerifying = true;
      _tokenError = null;
      _tokenStatus = null;
    });
    try {
      final bangumi = BangumiSyncService();
      await bangumi.saveToken(_tokenController.text);
      if (mounted) {
        _tokenController.text =
            GStorage.getSetting(SettingsKeys.bangumiAccessToken);
        _tokenStatus = '已验证并保存，用户名：${bangumi.username}';
      }
    } catch (e) {
      if (mounted) {
        _tokenError = '${BangumiSyncService.describeError(e)}。本次修改未保存';
      }
    } finally {
      if (mounted) setState(() => _isVerifying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !dialogs.isRunning,
      child: Scaffold(
        appBar: const SysAppBar(title: Text('Bangumi 配置')),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Center(
            child: SizedBox(
              width: (MediaQuery.of(context).size.width > 1000) ? 1000 : null,
              child: Column(
                children: [
                  TextField(
                    controller: _tokenController,
                    enabled: !_isBusy,
                    onChanged: (_) => setState(() {
                      _tokenError = null;
                      _tokenStatus = null;
                    }),
                    obscureText: !_passwordVisible,
                    decoration: InputDecoration(
                      labelText: 'Bangumi Access Token',
                      errorText: _tokenError,
                      errorMaxLines: 4,
                      helperText: _isVerifying
                          ? '正在验证 Token，请稍候…'
                          : _tokenStatus ?? '填写后点击“验证并保存”，验证成功后生效',
                      helperMaxLines: 2,
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        onPressed: () {
                          setState(() {
                            _passwordVisible = !_passwordVisible;
                          });
                        },
                        icon: Icon(_passwordVisible
                            ? Icons.visibility_rounded
                            : Icons.visibility_off_rounded),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  BangumiSyncSettings(
                    enabled: !_isBusy,
                    margin: EdgeInsetsDirectional.zero,
                  ),
                  const SizedBox(height: 16),
                  SettingsSection(
                    title: Text('同步选项'),
                    margin: EdgeInsetsDirectional.zero,
                    tiles: [
                      SettingsTile.switchTile(
                        leading: Icons.notifications_active_rounded,
                        onToggle: (value) async {
                          _immediateSyncToastEnabled =
                              value ?? !_immediateSyncToastEnabled;
                          await GStorage.putSetting(
                            SettingsKeys.bangumiImmediateSyncToastEnable,
                            _immediateSyncToastEnabled,
                          );
                          if (mounted) {
                            setState(() {});
                          }
                        },
                        title: Text('即时同步提示'),
                        description: Text('点击追番按钮触发即时同步时显示提示框'),
                        initialValue: _immediateSyncToastEnabled,
                      ),
                      SettingsTile(
                        leading: Icons.rule_rounded,
                        onPressed: (_) async {
                          if (_syncPriorityMenuController.isOpen) {
                            _syncPriorityMenuController.close();
                          } else {
                            _syncPriorityMenuController.open();
                          }
                        },
                        title: Text('同步优先级'),
                        description: Text('当本地与 Bangumi 状态不一致时优先使用哪个状态'),
                        value: MenuAnchor(
                            consumeOutsideTap: true,
                            controller: _syncPriorityMenuController,
                            builder: (context, controller, child) => Text(
                                BangumiSyncPriority.fromValue(_syncPriority)
                                    .label),
                            menuChildren: [
                              for (final entry in BangumiSyncPriority.values)
                                MenuItemButton(
                                    requestFocusOnHover: false,
                                    onPressed: () =>
                                        _updateSyncPriority(entry.value),
                                    child: Container(
                                        height: 48,
                                        constraints:
                                            BoxConstraints(minWidth: 112),
                                        child: Align(
                                          alignment: Alignment.centerLeft,
                                          child: Text(
                                            entry.label,
                                            style: TextStyle(
                                              color:
                                                  entry.value == _syncPriority
                                                      ? Theme.of(context)
                                                          .colorScheme
                                                          .primary
                                                      : null,
                                            ),
                                          ),
                                        )))
                            ]),
                      ),
                      SettingsTile(
                        leading: Icons.cloud_sync_rounded,
                        enabled: !_isBusy,
                        trailing: dialogs.isRunning
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: LoadingIndicator(),
                              )
                            : const Icon(Icons.sync_rounded),
                        onPressed: (_) async {
                          await _syncWithProgress();
                        },
                        title: Text("立即同步状态"),
                        description: Text('同步状态不一致或仅存在于本地/远端的条目'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  GestureDetector(
                    onTap: () async {
                      final url =
                          Uri.parse('https://next.bgm.tv/demo/access-token');
                      if (await canLaunchUrl(url)) {
                        await launchUrl(url,
                            mode: LaunchMode.externalApplication);
                      } else {
                        KazumiDialog.showToast(message: '无法打开链接');
                      }
                    },
                    child: Text(
                      '你可以点击此处前往 Bangumi 生成 Access Token',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.primary,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _isBusy ? null : _saveToken,
          icon: _isVerifying
              ? const SizedBox(width: 20, height: 20, child: LoadingIndicator())
              : const Icon(Icons.save),
          label: Text(_isVerifying ? '正在验证…' : '验证并保存'),
        ),
      ),
    );
  }
}

class _BangumiSyncProgressDialog extends StatefulWidget {
  const _BangumiSyncProgressDialog({super.key});

  @override
  State<_BangumiSyncProgressDialog> createState() =>
      _BangumiSyncProgressDialogState();
}

class _BangumiSyncProgressDialogState
    extends State<_BangumiSyncProgressDialog> {
  String _progressText = '准备同步 Bangumi 状态...';
  double? _progressValue;

  void update(String text, double? value) {
    if (!mounted) return;
    setState(() {
      _progressText = text;
      _progressValue = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Dialog(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: SizedBox(
            width: 340,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Bangumi 同步进行中',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                Text(_progressText),
                const SizedBox(height: 12),
                LinearProgressIndicator(value: _progressValue),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
