import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:go_router/go_router.dart';
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
import 'package:kazumi/pages/settings/settings_navigation.dart';
import 'package:kazumi/routing/media_location.dart';
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

  Future<void> _changeType(BangumiItem item, CollectType type) async {
    if (_syncDialogOpen || collectController.activity.blocks(item.id)) return;
    await collectController.addCollect(item, type: type.value);
  }

  Future<void> _sync() async {
    if (_syncDialogOpen || collectController.activity.hasPending) return;
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
          onSync: (onUpdate) =>
              collectController.syncAll(plan, onUpdate: onUpdate),
        ),
      );
      task.withContext((context) => openSettings(
          context,
          switch (destination) {
            CollectSyncDestination.webDavSettings => '/settings/webdav',
            CollectSyncDestination.bangumiSettings => '/settings/bangumi',
          }));
    }, errorMessage: '同步未完成，请稍后重试');
  }

  @override
  Widget build(BuildContext context) => Observer(builder: (context) {
        final activity = collectController.activity;
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
                        _syncDialogOpen || activity.hasPending ? null : _sync,
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
                    !_syncDialogOpen && !activity.blocks(item.id),
                onOpen: (item) =>
                    context.push(infoLocation(item.id), extra: item),
                onChangeType: (item, type) =>
                    unawaited(_changeType(item, type)),
              ),
            ),
          ),
        );
      });
}
