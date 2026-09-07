import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:kazumi/bean/settings/settings_detail_scaffold.dart';
import 'package:kazumi/bean/settings/settings_list.dart';
import 'package:kazumi/bean/widget/state_presentation.dart';
import 'package:kazumi/bean/widget/tonal_card.dart';
import 'package:kazumi/modules/bangumi/sync_priority.dart';
import 'package:kazumi/pages/settings/sync/sync_settings_widgets.dart';
import 'package:kazumi/services/storage/storage.dart';
import 'package:kazumi/services/sync/bangumi_sync_service.dart';

enum _BangumiAction { verify, connect, sync }

class BangumiSyncPage extends StatefulWidget {
  const BangumiSyncPage({super.key});

  @override
  State<BangumiSyncPage> createState() => _BangumiSyncPageState();
}

class _BangumiSyncPageState extends State<BangumiSyncPage> {
  final _tokenController = TextEditingController();
  final _bangumi = BangumiSyncService();
  bool _passwordVisible = false;
  _BangumiAction? _action;
  String? _tokenError;
  String? _tokenStatus;
  String? _message;
  bool _failed = false;
  double? _progress;

  bool get _busy => _action != null || _bangumi.isConnecting;

  @override
  void initState() {
    super.initState();
    _tokenController.text =
        GStorage.getSetting(SettingsKeys.bangumiAccessToken);
  }

  @override
  void dispose() {
    _tokenController.dispose();
    super.dispose();
  }

  Future<void> _saveToken() async {
    if (_busy) return;
    if (_tokenController.text.trim().isEmpty) {
      setState(() => _tokenError = '请填写 Access Token');
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _action = _BangumiAction.verify;
      _tokenError = null;
      _tokenStatus = null;
      _message = null;
      _failed = false;
    });
    try {
      await _bangumi.saveToken(_tokenController.text);
      if (mounted) {
        _tokenController.text =
            GStorage.getSetting(SettingsKeys.bangumiAccessToken);
        _tokenStatus = '已连接 ${_bangumi.username}';
      }
    } catch (e) {
      if (mounted) {
        _tokenError = '${BangumiSyncService.describeError(e)}。修改未保存';
      }
    } finally {
      if (mounted) setState(() => _action = null);
    }
  }

  Future<void> _connect(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _action = _BangumiAction.connect;
      _message = null;
      _failed = false;
    });
    try {
      await action();
    } catch (e) {
      _message = BangumiSyncService.describeError(e);
      _failed = true;
    } finally {
      if (mounted) setState(() => _action = null);
    }
  }

  Future<void> _getToken() async {
    bool opened;
    try {
      opened = await launchUrl(
        Uri.parse('https://next.bgm.tv/demo/access-token'),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      opened = false;
    }
    if (!opened && mounted) {
      setState(() => _tokenError = '无法打开浏览器，请稍后重试');
    }
  }

  Future<void> _sync() async {
    if (_busy) return;
    if (_tokenController.text.trim() !=
        GStorage.getSetting(SettingsKeys.bangumiAccessToken).trim()) {
      setState(() {
        _failed = true;
        _message = '账号信息已修改，请先验证并保存。';
      });
      return;
    }
    setState(() {
      _action = _BangumiAction.sync;
      _failed = false;
      _progress = null;
      _message = '正在连接 Bangumi…';
    });
    try {
      await _bangumi.syncCollectibles(
        onProgress: (message, current, total) {
          if (!mounted) return;
          setState(() {
            _message = total > 0 ? '$message · $current / $total' : message;
            _progress =
                total > 0 ? (current / total).clamp(0.0, 1.0).toDouble() : null;
          });
        },
      );
      _message = '追番状态已同步';
    } catch (e) {
      _failed = true;
      _message = BangumiSyncService.describeError(e);
    } finally {
      if (mounted) setState(() => _action = null);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: _bangumi,
        builder: (context, _) {
          final configured =
              GStorage.getSetting(SettingsKeys.bangumiAccessToken)
                  .trim()
                  .isNotEmpty;
          final enabled = GStorage.getSetting(SettingsKeys.bangumiSyncEnable);
          final priority = BangumiSyncPriority.fromValue(
              GStorage.getSetting(SettingsKeys.bangumiSyncPriority));
          final showToast =
              GStorage.getSetting(SettingsKeys.bangumiImmediateSyncToastEnable);
          final message =
              _message ?? (_tokenError == null ? _bangumi.lastError : null);
          return PopScope(
            canPop: !_busy,
            child: SettingsDetailScaffold(
              title: const Text('追番同步'),
              body: SyncPageBody(
                maxWidth: 720,
                children: [
                  const SyncPageIntro(
                    icon: Icons.bookmarks_rounded,
                    title: 'Bangumi',
                    description: '同步想看、在看、看过等追番状态。',
                  ),
                  _accountCard(configured),
                  _syncControls(configured, enabled),
                  StateActionButton(
                    onPressed: enabled && configured && !_busy ? _sync : null,
                    text: _action == _BangumiAction.sync ? '正在同步追番…' : '立即同步追番',
                    icon: Icons.sync_rounded,
                  ),
                  if (message != null)
                    SyncFeedback(
                      message: message,
                      error: _failed || _bangumi.lastError != null,
                      busy: _action == _BangumiAction.sync,
                      progress: _progress,
                    ),
                  TonalCard(
                    child: ExpansionTile(
                      shape: const Border(),
                      collapsedShape: const Border(),
                      leading: const Icon(Icons.tune_rounded),
                      title: const Text('同步偏好'),
                      subtitle: Text('状态冲突时：${priority.label}'),
                      tilePadding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 4),
                      childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                      children: [
                        RadioGroup<BangumiSyncPriority>(
                          groupValue: priority,
                          onChanged: (value) async {
                            if (value == null || _busy) return;
                            await GStorage.putSetting(
                                SettingsKeys.bangumiSyncPriority, value.value);
                            if (mounted) setState(() {});
                          },
                          child: Column(
                            children: [
                              for (final option in BangumiSyncPriority.values)
                                RadioListTile<BangumiSyncPriority>(
                                  value: option,
                                  enabled: !_busy,
                                  title: Text(switch (option) {
                                    BangumiSyncPriority.localFirst => '以本机为准',
                                    BangumiSyncPriority.bangumiFirst =>
                                      '以 Bangumi 为准',
                                    BangumiSyncPriority.timeFirst => '保留最近更新',
                                  }),
                                  subtitle: Text(switch (option) {
                                    BangumiSyncPriority.localFirst =>
                                      '用本机状态更新 Bangumi',
                                    BangumiSyncPriority.bangumiFirst =>
                                      '用 Bangumi 状态更新本机',
                                    BangumiSyncPriority.timeFirst =>
                                      '比较两边的更新时间',
                                  }),
                                ),
                            ],
                          ),
                        ),
                        const Divider(indent: 16, endIndent: 16),
                        SwitchListTile(
                          title: const Text('同步结果提示'),
                          subtitle: const Text('修改追番状态后显示同步结果'),
                          value: showToast,
                          onChanged: _busy
                              ? null
                              : (value) async {
                                  await GStorage.putSetting(
                                    SettingsKeys
                                        .bangumiImmediateSyncToastEnable,
                                    value,
                                  );
                                  if (mounted) setState(() {});
                                },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );

  Widget _syncControls(bool configured, bool enabled) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SettingsSection(
            margin: EdgeInsets.zero,
            tiles: [
              SettingsTile.switchTile(
                leading: Icons.sync_rounded,
                title: const Text('自动同步追番'),
                description:
                    Text(configured ? '修改追番状态时同步到 Bangumi' : '请先连接 Bangumi 账号'),
                initialValue: enabled,
                enabled: configured && !_busy,
                onToggle: (value) =>
                    _connect(() => _bangumi.setEnabled(value ?? !enabled)),
              ),
            ],
          ),
          if (configured)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 8, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _action == _BangumiAction.connect || _bangumi.isConnecting
                          ? '正在连接…'
                          : _bangumi.initialized
                              ? '已连接 · ${_bangumi.username}'
                              : '尚未验证连接',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: _busy ? null : () => _connect(_bangumi.ping),
                    child: Text(_bangumi.lastError != null ? '重试连接' : '测试连接'),
                  ),
                ],
              ),
            ),
        ],
      );

  Widget _accountCard(bool configured) => TonalCard(
        child: ExpansionTile(
          initiallyExpanded: !configured,
          maintainState: true,
          shape: const Border(),
          collapsedShape: const Border(),
          tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          leading: const Icon(Icons.account_circle_outlined),
          title: Text(configured ? 'Bangumi 账号' : '连接 Bangumi 账号'),
          subtitle: Text(_bangumi.initialized
              ? _bangumi.username
              : configured
                  ? '已保存授权信息'
                  : '使用 Access Token 授权'),
          children: [
            const SizedBox(height: 12),
            TextField(
              controller: _tokenController,
              enabled: !_busy,
              obscureText: !_passwordVisible,
              autocorrect: false,
              enableSuggestions: false,
              onChanged: (_) => setState(() {
                _tokenError = null;
                _tokenStatus = null;
              }),
              onSubmitted: (_) => _saveToken(),
              decoration: InputDecoration(
                labelText: 'Access Token',
                errorText: _tokenError,
                errorMaxLines: 5,
                helperText:
                    _action == _BangumiAction.verify ? '正在验证…' : _tokenStatus,
                helperMaxLines: 3,
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  tooltip: _passwordVisible ? '隐藏授权码' : '显示授权码',
                  onPressed: () =>
                      setState(() => _passwordVisible = !_passwordVisible),
                  icon: Icon(_passwordVisible
                      ? Icons.visibility_off_rounded
                      : Icons.visibility_rounded),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 12,
              runSpacing: 8,
              children: [
                TextButton.icon(
                  onPressed: _busy ? null : _getToken,
                  icon: const Icon(Icons.open_in_new_rounded, size: 18),
                  label: const Text('获取授权码'),
                ),
                StateActionButton.tonal(
                  onPressed: _busy ? null : _saveToken,
                  text: _action == _BangumiAction.verify ? '正在验证…' : '验证并保存',
                  icon: Icons.check_rounded,
                ),
              ],
            ),
          ],
        ),
      );
}
