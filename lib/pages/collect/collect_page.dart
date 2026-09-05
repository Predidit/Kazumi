import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:flutter_modular/flutter_modular.dart';

import 'package:kazumi/bean/appbar/sys_app_bar.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/bean/widget/loading_indicator.dart';
import 'package:kazumi/modules/bangumi/bangumi_item.dart';
import 'package:kazumi/modules/collect/collect_sync_plan.dart';
import 'package:kazumi/modules/collect/collect_type.dart';
import 'package:kazumi/pages/collect/collect_controller.dart';
import 'package:kazumi/pages/collect/collect_library_view.dart';
import 'package:kazumi/services/storage/storage.dart';

class CollectPage extends StatefulWidget {
  const CollectPage({
    super.key,
    required this.controller,
  });

  final CollectController controller;

  @override
  State<CollectPage> createState() => _CollectPageState();
}

class _CollectPageState extends State<CollectPage> {
  CollectController get collectController => widget.controller;
  bool _syncing = false;
  final Set<int> _pendingIds = {};

  Future<void> _runFullSync({
    required CollectSyncPlan plan,
  }) async {
    final progressDialogKey = GlobalKey<_FullSyncProgressDialogState>();

    unawaited(KazumiDialog.show(
      context: context,
      clickMaskDismiss: false,
      builder: (context) => _FullSyncProgressDialog(key: progressDialogKey),
    ));
    await WidgetsBinding.instance.endOfFrame;
    bool webDavSynced = false;
    bool bangumiSynced = false;
    bool webDavUploaded = false;

    try {
      if (plan.shouldSyncWebDavCollectibles) {
        progressDialogKey.currentState?.update('正在同步 WebDav 收藏...', null);
        webDavSynced =
            await collectController.syncCollectibles(showSuccessToast: false);
      }

      if (plan.shouldSyncBangumi) {
        progressDialogKey.currentState?.update('准备同步 Bangumi 收藏...', null);
        bangumiSynced = await collectController.syncCollectiblesBangumi(
          showSuccessToast: false,
          onProgress: (message, current, total) {
            progressDialogKey.currentState?.update(
              total > 0 ? '$message ($current/$total)' : message,
              total > 0 ? (current / total).clamp(0.0, 1.0).toDouble() : null,
            );
          },
        );
      }

      if (plan.shouldUploadWebDavAfterBangumi(
        webDavSynced: webDavSynced,
        bangumiSynced: bangumiSynced,
      )) {
        progressDialogKey.currentState?.update('正在回传最新收藏到 WebDav...', null);
        webDavUploaded = await collectController.uploadCollectiblesToWebDav(
          showSuccessToast: false,
        );
      }
    } finally {
      final dialogContext = progressDialogKey.currentContext;
      if (dialogContext != null && dialogContext.mounted) {
        final route = ModalRoute.of(dialogContext);
        if (route != null) {
          final navigator = Navigator.of(dialogContext);
          if (route.isCurrent) {
            navigator.pop();
          } else {
            navigator.removeRoute(route);
          }
          // The route observer clears stale snackbars at the end of the frame.
          await WidgetsBinding.instance.endOfFrame;
        }
      }
    }

    final states = [
      if (plan.shouldSyncWebDavCollectibles)
        webDavSynced ? 'WebDav 已同步' : 'WebDav 未完成',
      if (plan.shouldSyncBangumi) bangumiSynced ? 'Bangumi 已同步' : 'Bangumi 未完成',
      if (plan.shouldUploadWebDavAfterBangumi(
        webDavSynced: webDavSynced,
        bangumiSynced: bangumiSynced,
      ))
        webDavUploaded ? 'WebDav 已回传最新数据' : 'WebDav 未回传最新数据',
    ];
    KazumiDialog.showToast(message: states.join('，'));
  }

  @override
  void initState() {
    super.initState();
    collectController.loadCollectibles();
  }

  Future<void> _changeType(BangumiItem item, CollectType type) async {
    if (_syncing || _pendingIds.contains(item.id)) return;
    setState(() => _pendingIds.add(item.id));
    try {
      await collectController.addCollect(item, type: type.value);
    } catch (_) {
      KazumiDialog.showToast(message: '修改收藏状态失败，请稍后重试');
    } finally {
      if (mounted) setState(() => _pendingIds.remove(item.id));
    }
  }

  Future<void> _sync() async {
    if (_syncing || _pendingIds.isNotEmpty) return;
    final plan = CollectSyncPlan(
      webDavEnabled: GStorage.getSetting(SettingsKeys.webDavEnable),
      webDavCollectiblesEnabled:
          GStorage.getSetting(SettingsKeys.webDavEnableCollect),
      bangumiEnabled: GStorage.getSetting(SettingsKeys.bangumiSyncEnable),
    );
    if (!plan.canSync) {
      KazumiDialog.showToast(message: '同步功能不可用，请至少开启一个同步功能');
      return;
    }
    setState(() => _syncing = true);
    try {
      await _runFullSync(plan: plan);
    } catch (_) {
      KazumiDialog.showToast(message: '同步未完成，请稍后重试');
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: SysAppBar(
        needTopOffset: false,
        toolbarHeight: 72,
        title: Text(
          '追番',
          style: Theme.of(context)
              .textTheme
              .headlineSmall
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: IconButton.filledTonal(
              tooltip: _syncing ? '正在同步收藏' : '同步收藏',
              onPressed: _syncing || _pendingIds.isNotEmpty ? null : _sync,
              icon: _syncing
                  ? LoadingIndicator(
                      size: 24,
                      color: colors.onSecondaryContainer,
                      semanticsLabel: '正在同步收藏',
                    )
                  : const Icon(Icons.sync_rounded),
            ),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        bottom: false,
        child: Observer(
          builder: (context) => CollectLibraryView(
            entries: collectController.collectibles.toList(),
            canEdit: (item) => !_syncing && !_pendingIds.contains(item.id),
            onOpen: (item) => context.pushNamed('/info/', arguments: item),
            onChangeType: (item, type) => unawaited(_changeType(item, type)),
          ),
        ),
      ),
    );
  }
}

class _FullSyncProgressDialog extends StatefulWidget {
  const _FullSyncProgressDialog({super.key});

  @override
  State<_FullSyncProgressDialog> createState() =>
      _FullSyncProgressDialogState();
}

class _FullSyncProgressDialogState extends State<_FullSyncProgressDialog> {
  String _progressText = '准备开始同步收藏...';
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
                  '收藏全量同步中',
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
