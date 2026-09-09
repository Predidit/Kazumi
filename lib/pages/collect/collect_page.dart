import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:flutter_modular/flutter_modular.dart';

import 'package:kazumi/bean/appbar/sys_app_bar.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/bean/widget/state_presentation.dart';
import 'package:kazumi/modules/bangumi/bangumi_item.dart';
import 'package:kazumi/modules/bangumi/sync_priority.dart';
import 'package:kazumi/modules/collect/collect_sync_plan.dart';
import 'package:kazumi/modules/collect/collect_type.dart';
import 'package:kazumi/pages/collect/collect_controller.dart';
import 'package:kazumi/pages/collect/collect_library_view.dart';
import 'package:kazumi/pages/collect/collect_sync_dialog.dart';
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

class _CollectPageState extends State<CollectPage> with KazumiDialogOwner {
  CollectController get collectController => widget.controller;
  bool get _syncDialogOpen => dialogs.isRunning;
  final Set<int> _pendingIds = {};

  Future<bool> _syncStep(
    CollectSyncStep step, {
    required ValueChanged<String> onError,
    required void Function(String message, int current, int total) onProgress,
  }) =>
      switch (step) {
        CollectSyncStep.webDav => collectController.syncCollectibles(
            onError: onError,
          ),
        CollectSyncStep.bangumi => collectController.syncCollectiblesBangumi(
            onError: onError,
            onProgress: onProgress,
          ),
        CollectSyncStep.upload => collectController.uploadCollectiblesToWebDav(
            onError: onError,
          ),
      };

  @override
  void initState() {
    super.initState();
    collectController.loadCollectibles();
  }

  Future<void> _changeType(BangumiItem item, CollectType type) async {
    if (_syncDialogOpen || _pendingIds.contains(item.id)) return;
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
    if (_syncDialogOpen || _pendingIds.isNotEmpty) return;
    final plan = CollectSyncPlan(
      webDavEnabled: GStorage.getSetting(SettingsKeys.webDavEnable),
      webDavCollectiblesEnabled:
          GStorage.getSetting(SettingsKeys.webDavEnableCollect),
      bangumiEnabled: GStorage.getSetting(SettingsKeys.bangumiSyncEnable),
    );
    await dialogs.run((task) async {
      final destination = await task.show<CollectSyncDestination>(
        builder: (_) => CollectSyncDialog(
          plan: plan,
          priority: BangumiSyncPriority.fromValue(
            GStorage.getSetting(SettingsKeys.bangumiSyncPriority),
          ),
          onSync: _syncStep,
        ),
      );
      task.withContext((context) => context.pushNamed(switch (destination) {
            CollectSyncDestination.webDavSettings => '/settings/webdav/',
            CollectSyncDestination.bangumiSettings => '/settings/bangumi/',
          }));
    }, errorMessage: '同步未完成，请稍后重试');
  }

  @override
  Widget build(BuildContext context) {
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
            child: Tooltip(
              message: '同步收藏',
              child: StateActionButton.tonal(
                text: '同步',
                onPressed:
                    _syncDialogOpen || _pendingIds.isNotEmpty ? null : _sync,
                icon: Icons.sync_rounded,
              ),
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
            showRating: GStorage.getSetting(SettingsKeys.showRating),
            canEdit: (item) =>
                !_syncDialogOpen && !_pendingIds.contains(item.id),
            onOpen: (item) => context.pushNamed('/info/', arguments: item),
            onChangeType: (item, type) => unawaited(_changeType(item, type)),
          ),
        ),
      ),
    );
  }
}
