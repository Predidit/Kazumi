import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';

import 'package:kazumi/bean/appbar/sys_app_bar.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/bean/widget/loading_indicator.dart';
import 'package:kazumi/modules/bangumi/bangumi_item.dart';
import 'package:kazumi/modules/collect/collect_sync_plan.dart';
import 'package:kazumi/modules/collect/collect_type.dart';
import 'package:kazumi/pages/collect/collect_controller.dart';
import 'package:kazumi/services/storage/storage.dart';
import 'package:kazumi/modules/history/history_module.dart';
import 'package:kazumi/pages/collect/collect_library.dart';
import 'package:kazumi/repositories/history_repository.dart';
import 'package:kazumi/services/player/history_playback_service.dart';
import 'package:kazumi/services/plugin/rule_engine_models.dart'
    show RuleCancelToken;

class CollectPage extends StatefulWidget {
  const CollectPage({
    super.key,
    required this.controller,
    required this.historyRepository,
  });

  final CollectController controller;
  final IHistoryRepository historyRepository;

  @override
  State<CollectPage> createState() => _CollectPageState();
}

class _CollectPageState extends State<CollectPage> {
  CollectController get collectController => widget.controller;
  bool _managing = false;
  bool _syncing = false;
  bool _updating = false;
  bool _openingPlayback = false;
  List<History> _histories = [];
  StreamSubscription<void>? _historySubscription;
  RuleCancelToken? _playbackCancelToken;

  Future<bool> _syncBangumiWithProgress({
    required GlobalKey<_FullSyncProgressDialogState> progressDialogKey,
  }) async {
    progressDialogKey.currentState?.update('准备同步 Bangumi 收藏...', null);

    await Future<void>.delayed(const Duration(milliseconds: 80));

    return collectController.syncCollectiblesBangumi(
      showSuccessToast: false,
      onProgress: (message, current, total) {
        progressDialogKey.currentState?.update(
          total > 0 ? '$message ($current/$total)' : message,
          total > 0 ? (current / total).clamp(0.0, 1.0).toDouble() : null,
        );
      },
    );
  }

  void _showFullSyncProgressDialog({
    required GlobalKey<_FullSyncProgressDialogState> progressDialogKey,
  }) {
    unawaited(KazumiDialog.show(
      clickMaskDismiss: false,
      builder: (context) => _FullSyncProgressDialog(key: progressDialogKey),
    ));
  }

  String _buildFullSyncSummary({
    required CollectSyncPlan plan,
    required bool webDavSynced,
    required bool bangumiSynced,
    required bool webDavUploaded,
  }) {
    final List<String> states = [];
    if (plan.shouldSyncWebDavCollectibles) {
      states.add(webDavSynced ? 'WebDav 已同步' : 'WebDav 未完成');
    }
    if (plan.shouldSyncBangumi) {
      states.add(bangumiSynced ? 'Bangumi 已同步' : 'Bangumi 未完成');
    }
    if (plan.shouldSyncWebDavCollectibles &&
        plan.shouldSyncBangumi &&
        webDavSynced &&
        bangumiSynced) {
      states.add(webDavUploaded ? 'WebDav 已回传最新数据' : 'WebDav 未回传最新数据');
    }
    return states.join('，');
  }

  Future<void> _runFullSync({
    required CollectSyncPlan plan,
  }) async {
    final progressDialogKey = GlobalKey<_FullSyncProgressDialogState>();

    _showFullSyncProgressDialog(
      progressDialogKey: progressDialogKey,
    );

    await Future<void>.delayed(const Duration(milliseconds: 80));

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
        bangumiSynced = await _syncBangumiWithProgress(
          progressDialogKey: progressDialogKey,
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
      if (KazumiDialog.observer.hasKazumiDialog) {
        KazumiDialog.dismiss();
      }
    }

    KazumiDialog.showToast(
      message: _buildFullSyncSummary(
        plan: plan,
        webDavSynced: webDavSynced,
        bangumiSynced: bangumiSynced,
        webDavUploaded: webDavUploaded,
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    collectController.loadCollectibles();
    _histories = widget.historyRepository.getAllHistories();
    _historySubscription = widget.historyRepository.changes.listen((_) {
      if (!mounted) return;
      setState(() => _histories = widget.historyRepository.getAllHistories());
    });
  }

  @override
  void dispose() {
    _historySubscription?.cancel();
    _playbackCancelToken?.cancel();
    super.dispose();
  }

  Future<void> _sync() async {
    if (_syncing || _updating || _managing || _openingPlayback) return;
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
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  Future<void> _changeStatus(BangumiItem item, CollectType type) async {
    if (_updating || _syncing) return;
    setState(() => _updating = true);
    try {
      await collectController.addCollect(item, type: type.value);
    } catch (_) {
      KazumiDialog.showToast(message: '更新追番状态失败，请稍后重试');
    } finally {
      if (mounted) setState(() => _updating = false);
    }
  }

  Future<void> _resume(History history) async {
    if (_openingPlayback) return;
    setState(() => _openingPlayback = true);
    final cancelToken = RuleCancelToken();
    _playbackCancelToken = cancelToken;
    try {
      final result = await inject<HistoryPlaybackService>().open(
        history,
        cancelToken: cancelToken,
      );
      if (!mounted || !(ModalRoute.of(context)?.isCurrent ?? true)) return;
      switch (result) {
        case HistoryPlaybackReady(:final args):
          context.pushNamed('/video/', arguments: args);
        case HistoryPlaybackUnavailable(:final reason):
          KazumiDialog.showToast(message: reason);
      }
    } catch (_) {
      if (mounted) KazumiDialog.showToast(message: '暂时无法播放，请在详情中重新选择播放源');
    } finally {
      if (mounted) setState(() => _openingPlayback = false);
      if (identical(_playbackCancelToken, cancelToken)) {
        _playbackCancelToken = null;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: SysAppBar(
        needTopOffset: false,
        toolbarHeight: 88,
        title: Text('我的追番',
            style: theme.textTheme.headlineMedium
                ?.copyWith(fontWeight: FontWeight.w700)),
        actions: [
          IconButton(
            tooltip: _syncing ? '正在同步收藏' : '同步收藏',
            onPressed: _syncing || _managing || _updating || _openingPlayback
                ? null
                : _sync,
            icon: _syncing
                ? const LoadingIndicator(size: 24)
                : const Icon(Icons.sync_rounded),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 4, right: 8),
            child: IconButton.filledTonal(
              tooltip: _managing ? '完成管理' : '管理追番',
              isSelected: _managing,
              onPressed: _syncing || _updating || _openingPlayback
                  ? null
                  : () => setState(() => _managing = !_managing),
              icon: const Icon(Icons.tune_rounded),
              selectedIcon: const Icon(Icons.check_rounded),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_openingPlayback || _updating)
            LinearProgressIndicator(
              semanticsLabel: _openingPlayback ? '正在准备播放' : '正在更新追番状态',
            ),
          Expanded(
            child: Observer(builder: (context) {
              return CollectLibrary(
                collectibles: collectController.collectibles.toList(),
                histories: _histories,
                showCounts: GStorage.getSetting(SettingsKeys.showAnimeCounter),
                managing: _managing,
                busy: _syncing || _updating || _openingPlayback,
                onOpen: (item) => context.pushNamed('/info/', arguments: item),
                onResume: _resume,
                onStatusChanged: _changeStatus,
                onDiscover: () => context.pushNamed('/search/'),
              );
            }),
          ),
        ],
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
