import 'package:flutter/material.dart';

import 'package:kazumi/bean/widget/loading_indicator.dart';
import 'package:kazumi/bean/widget/state_presentation.dart';
import 'package:kazumi/modules/bangumi/sync_priority.dart';
import 'package:kazumi/modules/collect/collect_sync_plan.dart';

enum CollectSyncDestination { webDavSettings, bangumiSettings }

enum CollectSyncStep {
  webDav('WebDAV 收藏', '合并本地与云端收藏', Icons.cloud_sync_rounded),
  bangumi('Bangumi 状态', '同步追番状态', Icons.bookmarks_rounded),
  upload('回传 WebDAV', '上传合并后的收藏', Icons.cloud_upload_rounded);

  const CollectSyncStep(this._title, this._description, this._icon);

  final String _title;
  final String _description;
  final IconData _icon;

  CollectSyncDestination get _settings => switch (this) {
        bangumi => CollectSyncDestination.bangumiSettings,
        webDav || upload => CollectSyncDestination.webDavSettings,
      };
}

typedef CollectSyncOperation = Future<bool> Function(
  CollectSyncStep step, {
  required ValueChanged<String> onError,
  required void Function(String message, int current, int total) onProgress,
});

enum _StepStatus { waiting, running, succeeded, failed, skipped }

enum _SyncPhase { ready, running, finished }

class _StepState {
  _StepState(this.step);

  final CollectSyncStep step;
  _StepStatus status = _StepStatus.waiting;
  String? message;
  double? progress;
}

class CollectSyncDialog extends StatefulWidget {
  const CollectSyncDialog({
    super.key,
    required this.plan,
    required this.priority,
    required this.onSync,
  });

  final CollectSyncPlan plan;
  final BangumiSyncPriority priority;
  final CollectSyncOperation onSync;

  @override
  State<CollectSyncDialog> createState() => _CollectSyncDialogState();
}

class _CollectSyncDialogState extends State<CollectSyncDialog> {
  late List<_StepState> _steps = _createSteps();
  _SyncPhase _phase = _SyncPhase.ready;

  bool get _running => _phase == _SyncPhase.running;
  bool get _finished => _phase == _SyncPhase.finished;

  List<_StepState> _createSteps() => [
        if (widget.plan.shouldSyncWebDavCollectibles)
          _StepState(CollectSyncStep.webDav),
        if (widget.plan.shouldSyncBangumi) _StepState(CollectSyncStep.bangumi),
        if (widget.plan.shouldSyncWebDavCollectibles &&
            widget.plan.shouldSyncBangumi)
          _StepState(CollectSyncStep.upload),
      ];

  // Removed routes can stay mounted until their exit animation ends.
  bool get _active => mounted && (ModalRoute.of(context)?.isActive ?? false);
  bool get _hasFailure =>
      _steps.any((step) => step.status == _StepStatus.failed);
  bool get _hasSuccess =>
      _steps.any((step) => step.status == _StepStatus.succeeded);

  Future<void> _start() async {
    if (_running || !widget.plan.canSync) return;
    setState(() {
      _steps = _createSteps();
      _phase = _SyncPhase.running;
    });
    for (final state in _steps) {
      if (!_active) return;
      if (state.step == CollectSyncStep.upload &&
          !widget.plan.shouldUploadWebDavAfterBangumi(
            webDavSynced: _steps.any((s) =>
                s.step == CollectSyncStep.webDav &&
                s.status == _StepStatus.succeeded),
            bangumiSynced: _steps.any((s) =>
                s.step == CollectSyncStep.bangumi &&
                s.status == _StepStatus.succeeded),
          )) {
        setState(() {
          state.status = _StepStatus.skipped;
          state.message = '前两步未全部完成';
        });
        continue;
      }
      setState(() {
        state.status = _StepStatus.running;
        state.message = '正在连接…';
      });
      bool succeeded = false;
      String? failure;
      try {
        succeeded = await widget.onSync(
          state.step,
          onError: (message) => failure = message,
          onProgress: (message, current, total) {
            if (!_active || state.status != _StepStatus.running) return;
            setState(() {
              state.message =
                  total > 0 ? '$message · $current / $total' : message;
              state.progress = total > 0
                  ? (current / total).clamp(0.0, 1.0).toDouble()
                  : null;
            });
          },
        );
      } catch (_) {
        failure ??= '连接中断，请检查网络或设置';
      }
      if (!_active) return;
      setState(() {
        state.status = succeeded ? _StepStatus.succeeded : _StepStatus.failed;
        state.message = succeeded ? null : failure ?? '请检查网络或同步设置';
        state.progress = null;
      });
    }
    if (!_active) return;
    setState(() => _phase = _SyncPhase.finished);
  }

  String get _title {
    if (!widget.plan.canSync) return '开启收藏同步';
    if (_running) return '正在同步收藏';
    if (!_finished) return '同步收藏';
    if (!_hasFailure) return '收藏已同步';
    return _hasSuccess ? '部分同步完成' : '同步未完成';
  }

  String? get _description {
    if (!widget.plan.canSync) return '选择同步服务';
    if (_running) {
      final current = _steps.indexWhere((s) => s.status == _StepStatus.running);
      return '第 ${current + 1} / ${_steps.length} 步 · 请保持应用开启';
    }
    if (!_finished) return '同步全部收藏分类';
    if (_hasFailure && _hasSuccess) return '已完成的更改已保留';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 200);
    final failed = _finished && _hasFailure;
    final description = _description;
    return PopScope(
      canPop: !_running,
      child: AlertDialog(
        constraints: const BoxConstraints(minWidth: 280, maxWidth: 440),
        insetPadding: const EdgeInsets.all(24),
        backgroundColor: colors.surfaceContainerHigh,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        clipBehavior: Clip.antiAlias,
        scrollable: true,
        iconPadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
        icon: Center(
          child: AnimatedSwitcher(
            duration: duration,
            child: _running
                ? LoadingIndicator(
                    key: const ValueKey('syncing'),
                    size: 64,
                    color: colors.primary,
                    semanticsLabel: '正在同步收藏',
                  )
                : StateIconBadge(
                    key: ValueKey((_finished, failed)),
                    icon: failed
                        ? Icons.sync_problem_rounded
                        : _finished
                            ? Icons.done_all_rounded
                            : Icons.sync_rounded,
                    size: 64,
                    iconSize: 32,
                    backgroundColor: failed
                        ? colors.errorContainer
                        : colors.primaryContainer,
                    foregroundColor: failed
                        ? colors.onErrorContainer
                        : colors.onPrimaryContainer,
                  ),
          ),
        ),
        titlePadding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
        title: Semantics(
          liveRegion: true,
          child: Text(_title, textAlign: TextAlign.center),
        ),
        titleTextStyle: theme.textTheme.headlineSmall?.copyWith(
          color: colors.onSurface,
          fontWeight: FontWeight.w600,
        ),
        contentPadding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        content: SizedBox(
          width: 392,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (description != null) ...[
                Text(description,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: colors.onSurfaceVariant)),
                const SizedBox(height: 24),
              ],
              if (!widget.plan.canSync) ...[
                _setupRow(CollectSyncDestination.webDavSettings),
                const SizedBox(height: 4),
                _setupRow(CollectSyncDestination.bangumiSettings),
              ] else ...[
                for (var i = 0; i < _steps.length; i++) ...[
                  if (i > 0) const SizedBox(height: 4),
                  _stepRow(_steps[i], i),
                ],
                if (_phase == _SyncPhase.ready &&
                    widget.plan.shouldSyncBangumi) ...[
                  const SizedBox(height: 16),
                  Text(
                    '冲突处理：${widget.priority.label}',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: colors.onSurfaceVariant),
                  ),
                ],
              ],
            ],
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        actionsOverflowButtonSpacing: 8,
        actions: _running
            ? null
            : [
                if (!_finished || failed)
                  TextButton(
                    style: TextButton.styleFrom(
                      minimumSize: const Size(64, 48),
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                    child:
                        Text(widget.plan.canSync && !_finished ? '取消' : '关闭'),
                  ),
                if (widget.plan.canSync)
                  StateActionButton(
                    onPressed: _finished && !failed
                        ? () => Navigator.of(context).pop()
                        : _start,
                    icon: _finished
                        ? (failed ? Icons.refresh_rounded : Icons.check_rounded)
                        : Icons.sync_rounded,
                    text: _finished ? (failed ? '重新同步' : '完成') : '开始同步',
                  ),
              ],
      ),
    );
  }

  BorderRadius _rowRadius(int index, int length) => BorderRadius.vertical(
        top: Radius.circular(index == 0 ? 20 : 4),
        bottom: Radius.circular(index == length - 1 ? 20 : 4),
      );

  Widget _setupRow(CollectSyncDestination destination) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final (title, description, icon) = switch (destination) {
      CollectSyncDestination.webDavSettings => (
          'WebDAV',
          '设置服务器，开启收藏同步',
          Icons.cloud_sync_rounded
        ),
      CollectSyncDestination.bangumiSettings => (
          'Bangumi',
          '连接账号，开启状态同步',
          Icons.bookmarks_rounded
        ),
    };
    return Material(
      color: colors.surfaceContainerLow,
      borderRadius:
          _rowRadius(destination.index, CollectSyncDestination.values.length),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Icon(icon, color: colors.primary),
        title: Text(title, style: theme.textTheme.titleSmall),
        subtitle: Text(description),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: () => Navigator.of(context).pop(destination),
      ),
    );
  }

  Widget _stepRow(_StepState state, int index) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final active = state.status == _StepStatus.running;
    final failed = state.status == _StepStatus.failed;
    final detail = state.status == _StepStatus.waiting
        ? (_running ? null : state.step._description)
        : state.message;
    final foreground = failed
        ? colors.onErrorContainer
        : active
            ? colors.onSecondaryContainer
            : colors.onSurface;
    final statusLabel = switch (state.status) {
      _StepStatus.waiting => _running ? '等待中' : '第 ${index + 1} 步',
      _StepStatus.running => '同步中',
      _StepStatus.succeeded => '已完成',
      _StepStatus.failed => '未完成',
      _StepStatus.skipped => '已跳过',
    };
    final icon = switch (state.status) {
      _StepStatus.succeeded => Icons.check_circle_rounded,
      _StepStatus.failed => Icons.error_outline_rounded,
      _StepStatus.skipped => Icons.remove_circle_outline_rounded,
      _ => state.step._icon,
    };
    return Semantics(
      container: true,
      child: Material(
        color: failed
            ? colors.errorContainer
            : active
                ? colors.secondaryContainer
                : colors.surfaceContainerLow,
        borderRadius: _rowRadius(index, _steps.length),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Icon(icon, size: 24, color: foreground),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 12,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(state.step._title,
                            style: theme.textTheme.titleSmall
                                ?.copyWith(color: foreground)),
                        Text(statusLabel,
                            style: theme.textTheme.labelMedium?.copyWith(
                                color: active || failed
                                    ? foreground
                                    : colors.onSurfaceVariant)),
                      ],
                    ),
                    if (detail != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        detail,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: active || failed
                              ? foreground
                              : colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                    if (failed && _finished) ...[
                      const SizedBox(height: 4),
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          foregroundColor: colors.onErrorContainer,
                          minimumSize: const Size(48, 48),
                        ),
                        onPressed: () =>
                            Navigator.of(context).pop(state.step._settings),
                        icon: const Icon(Icons.settings_rounded, size: 18),
                        label: const Text('检查设置'),
                      ),
                    ],
                    if (active && state.progress != null) ...[
                      const SizedBox(height: 12),
                      LinearProgressIndicator(
                        value: state.progress,
                        color: colors.primary,
                        backgroundColor:
                            colors.onSecondaryContainer.withValues(alpha: 0.12),
                        minHeight: 4,
                        borderRadius: BorderRadius.circular(4),
                        trackGap: 4,
                        semanticsLabel: state.step._title,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
