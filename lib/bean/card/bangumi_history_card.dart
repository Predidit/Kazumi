import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/bean/card/network_img_layer.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/bean/widget/collect_button.dart';
import 'package:kazumi/modules/history/history_module.dart';
import 'package:kazumi/modules/bangumi/bangumi_item.dart';
import 'package:kazumi/pages/collect/collect_controller.dart';
import 'package:kazumi/services/player/history_playback_service.dart';
import 'package:kazumi/services/plugin/rule_engine_models.dart'
    show RuleCancelToken;
import 'package:kazumi/utils/device.dart';
import 'package:kazumi/utils/date_time.dart';
import 'package:kazumi/bean/widget/tv_focusable_surface.dart';
import 'package:kazumi/services/platform/tv_mode.dart';

String _historySourceText(String entryKind) {
  return HistoryEntryKind.normalize(entryKind) == HistoryEntryKind.offline
      ? '缓存'
      : '在线';
}

// Material's automatic touch highlight mode can suppress the normal focus
// tint on Android TV. These new remote actions always expose focused state.
ButtonStyle _historyActionStyle(BuildContext context) => ButtonStyle(
      side: WidgetStateProperty.resolveWith((states) => BorderSide(
          width: 3,
          color: states.contains(WidgetState.focused)
              ? Theme.of(context).colorScheme.primary
              : Colors.transparent)),
    );

class _HistoryActionsDialog extends StatefulWidget {
  const _HistoryActionsDialog({required this.item, required this.canDelete});
  final BangumiItem item;
  final bool canDelete;
  @override
  State<_HistoryActionsDialog> createState() => _HistoryActionsDialogState();
}

class _HistoryActionsDialogState extends State<_HistoryActionsDialog> {
  final _collectionFocus = FocusNode(debugLabel: 'TV history collection');
  @override
  void dispose() {
    _collectionFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SimpleDialog(
        title: const Text('历史操作'),
        children: [
          TextButton(
              style: _historyActionStyle(context),
              autofocus: true,
              onPressed: () => Navigator.of(context).pop('resume'),
              child: const Text('继续观看')),
          TextButton(
              style: _historyActionStyle(context),
              onPressed: () => Navigator.of(context).pop('detail'),
              child: const Text('番剧详情')),
          Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: FilledButtonTheme(
                data:
                    FilledButtonThemeData(style: _historyActionStyle(context)),
                child: CollectButton.extend(
                    bangumiItem: widget.item, focusNode: _collectionFocus),
              )),
          if (widget.canDelete)
            TextButton(
                style: _historyActionStyle(context),
                onPressed: () => Navigator.of(context).pop('delete'),
                child: const Text('删除记录')),
          TextButton(
              style: _historyActionStyle(context),
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('关闭')),
        ],
      );
}

class BangumiHistoryCardV extends StatefulWidget {
  const BangumiHistoryCardV({
    super.key,
    required this.historyItem,
    this.showDelete = false,
    this.onDeleted,
    this.focusNode,
    this.onKeyEvent,
    this.onNavigationInput,
  });

  final History historyItem;
  final bool showDelete;
  final FutureOr<void> Function()? onDeleted;
  final FocusNode? focusNode;
  final FocusOnKeyEventCallback? onKeyEvent;

  /// Invalidates pending page navigation before local controls consume input.
  final VoidCallback? onNavigationInput;

  @override
  State<BangumiHistoryCardV> createState() => _BangumiHistoryCardVState();
}

class _BangumiHistoryCardVState extends State<BangumiHistoryCardV>
    with KazumiDialogOwner {
  final CollectController collectController = inject<CollectController>();
  final HistoryPlaybackService _playbackService =
      inject<HistoryPlaybackService>();

  final _cardFocus = FocusNode(debugLabel: 'TV history resume');
  final _moreFocus = FocusNode(debugLabel: 'TV history more');
  bool _menuOpen = false;
  bool _deleting = false;

  FocusNode get _resumeFocus => widget.focusNode ?? _cardFocus;

  void _notifyNavigationInput(KeyEvent event) {
    if ((event is KeyDownEvent || event is KeyRepeatEvent) &&
        event.logicalKey != LogicalKeyboardKey.arrowDown) {
      widget.onNavigationInput?.call();
    }
  }

  @override
  void dispose() {
    _cardFocus.dispose();
    _moreFocus.dispose();
    super.dispose();
  }

  Future<void> _onTap({bool resumeFromMenu = false}) async {
    widget.onNavigationInput?.call();
    if (widget.showDelete && !resumeFromMenu) {
      if (TvMode.enabled) {
        await _confirmDelete(_resumeFocus);
        return;
      }
      KazumiDialog.showToast(message: '编辑模式');
      return;
    }
    if (dialogs.isRunning) return;
    await dialogs.run((task) async {
      final cancelToken = RuleCancelToken();
      final result = await task.loading(
        message: '获取中',
        barrierDismissible: isDesktop(),
        onCancel: cancelToken.cancel,
        action: () =>
            _playbackService.open(widget.historyItem, cancelToken: cancelToken),
      );
      switch (result) {
        case HistoryPlaybackReady(:final args):
          task.withContext((ctx) => ctx.pushNamed('/video/', arguments: args));
        case HistoryPlaybackUnavailable(:final reason):
          KazumiDialog.showToast(message: reason);
      }
    }, errorMessage: '打开历史记录失败，请稍后重试');
  }

  Future<void> _confirmDelete(FocusNode returnFocus) async {
    if (_deleting || widget.onDeleted == null) return;
    _deleting = true;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除记录'),
        content: const Text('只删除这条观看历史，不删除缓存或追番。'),
        actions: [
          TextButton(
              style: _historyActionStyle(context),
              autofocus: true,
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消')),
          TextButton(
              style: _historyActionStyle(context),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('删除')),
        ],
      ),
    );
    if (!mounted) return;
    try {
      if (confirmed == true) await widget.onDeleted?.call();
    } catch (_) {
      if (mounted) {
        KazumiDialog.showToast(context: context, message: '删除失败，请重试');
      }
    } finally {
      _deleting = false;
      if (mounted) returnFocus.requestFocus();
    }
  }

  Future<void> _showMore() async {
    widget.onNavigationInput?.call();
    if (_menuOpen) return;
    _menuOpen = true;
    final action = await showDialog<String>(
      context: context,
      builder: (_) => _HistoryActionsDialog(
        item: widget.historyItem.bangumiItem,
        canDelete: widget.onDeleted != null,
      ),
    );
    _menuOpen = false;
    if (!mounted) return;
    _moreFocus.requestFocus();
    switch (action) {
      case 'resume':
        await _onTap(resumeFromMenu: true);
      case 'detail':
        await context.pushNamed('/info/',
            arguments: widget.historyItem.bangumiItem);
        if (mounted) _moreFocus.requestFocus();
      case 'delete':
        await _confirmDelete(_moreFocus);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final double imageWidth = 80;
    final double imageHeight = 108;
    final String title = widget.historyItem.bangumiItem.nameCn == ''
        ? widget.historyItem.bangumiItem.name
        : widget.historyItem.bangumiItem.nameCn;
    final String episodeText = widget.historyItem.lastWatchEpisodeName.isEmpty
        ? '第${widget.historyItem.lastWatchEpisode}话'
        : widget.historyItem.lastWatchEpisodeName;
    final String sourceText = _historySourceText(widget.historyItem.entryKind);

    return Dismissible(
      key: ValueKey(widget.historyItem.key),
      direction:
          TvMode.enabled ? DismissDirection.none : DismissDirection.endToStart,
      onDismissed: (_) {
        widget.onDeleted?.call();
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        decoration: BoxDecoration(
          color: colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Icon(
          Icons.delete_outline,
          color: colorScheme.onErrorContainer,
        ),
      ),
      child: Row(children: [
        Expanded(
            child: TvFocusableSurface(
          focusScale: 1,
          focusNode: _resumeFocus,
          onKeyEvent: (node, event) {
            _notifyNavigationInput(event);
            if (TvMode.enabled &&
                (event is KeyDownEvent || event is KeyRepeatEvent) &&
                event.logicalKey == LogicalKeyboardKey.arrowRight) {
              _moreFocus.requestFocus();
              return KeyEventResult.handled;
            }
            return widget.onKeyEvent?.call(node, event) ??
                KeyEventResult.ignored;
          },
          onPressed: _onTap,
          child: Card(
            elevation: 0,
            margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            clipBehavior: Clip.antiAlias,
            color: colorScheme.surfaceContainerLow,
            child: InkWell(
              canRequestFocus: !TvMode.enabled,
              onTap: _onTap,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: NetworkImgLayer(
                        src: widget.historyItem.bangumiItem.images['large'] ??
                            '',
                        width: imageWidth,
                        height: imageHeight,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SizedBox(
                        height: imageHeight,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: theme.textTheme.titleSmall?.copyWith(
                                color: colorScheme.onSurface,
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Icon(
                                  Icons.play_circle_outline,
                                  size: 14,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    episodeText,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(
                                  Icons.extension_outlined,
                                  size: 14,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    '$sourceText · ${widget.historyItem.adapterName}',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                  ),
                                ),
                              ],
                            ),
                            const Spacer(),
                            Row(
                              children: [
                                Icon(
                                  Icons.access_time,
                                  size: 12,
                                  color: colorScheme.outline,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  formatTimestampToRelativeTime(widget
                                          .historyItem
                                          .lastWatchTime
                                          .millisecondsSinceEpoch ~/
                                      1000),
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: colorScheme.outline,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (!TvMode.enabled)
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (!widget.showDelete) ...[
                            Observer(
                              builder: (context) {
                                collectController.collectibles.length;
                                return CollectButton(
                                  onClose: () {
                                    FocusScope.of(context).unfocus();
                                  },
                                  bangumiItem: widget.historyItem.bangumiItem,
                                  color: colorScheme.onSurfaceVariant,
                                );
                              },
                            ),
                            IconButton(
                              icon: Icon(
                                Icons.open_in_new,
                                size: 20,
                                color: colorScheme.onSurfaceVariant,
                              ),
                              tooltip: '番剧详情',
                              onPressed: () {
                                context.pushNamed(
                                  '/info/',
                                  arguments: widget.historyItem.bangumiItem,
                                );
                              },
                            ),
                          ],
                          if (widget.showDelete)
                            IconButton(
                              icon: Icon(
                                Icons.delete_outline,
                                color: colorScheme.error,
                              ),
                              tooltip: '删除记录',
                              onPressed: () {
                                widget.onDeleted?.call();
                              },
                            ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ),
        )),
        if (TvMode.enabled)
          Padding(
              padding: const EdgeInsets.only(right: 8),
              child: TvFocusableSurface(
                focusNode: _moreFocus,
                borderRadius: 24,
                onPressed: _showMore,
                onKeyEvent: (node, event) {
                  _notifyNavigationInput(event);
                  if ((event is KeyDownEvent || event is KeyRepeatEvent) &&
                      event.logicalKey == LogicalKeyboardKey.arrowLeft) {
                    _resumeFocus.requestFocus();
                    return KeyEventResult.handled;
                  }
                  return widget.onKeyEvent?.call(node, event) ??
                      KeyEventResult.ignored;
                },
                child: IconButton(
                    tooltip: '更多历史操作',
                    onPressed: _showMore,
                    icon: const Icon(Icons.more_horiz)),
              )),
      ]),
    );
  }
}
