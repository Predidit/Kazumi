import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/bean/card/network_img_layer.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/modules/my/recent_watch_item.dart';
import 'package:kazumi/services/player/history_playback_service.dart';
import 'package:kazumi/services/plugin/rule_engine_models.dart'
    show RuleCancelToken;
import 'package:kazumi/utils/date_time.dart';
import 'package:kazumi/utils/device.dart';

/// Continue-watching card: opens playback, nothing else.
class RecentWatchCard extends StatefulWidget {
  const RecentWatchCard({super.key, required this.item});

  final RecentWatchItem item;

  @override
  State<RecentWatchCard> createState() => _RecentWatchCardState();
}

class _RecentWatchCardState extends State<RecentWatchCard> {
  static const double _coverWidth = 78;
  static const double _coverHeight = 104;

  final HistoryPlaybackService _playbackService =
      inject<HistoryPlaybackService>();

  RuleCancelToken? _cancelToken;

  @override
  void dispose() {
    _cancelToken?.cancel();
    super.dispose();
  }

  Future<void> _play() async {
    _cancelToken?.cancel();
    final cancelToken = RuleCancelToken();
    _cancelToken = cancelToken;
    KazumiDialog.showLoading(
      msg: '获取中',
      barrierDismissible: isDesktop(),
      onDismiss: cancelToken.cancel,
    );
    final result = await _playbackService.open(
      widget.item.history,
      cancelToken: cancelToken,
    );
    KazumiDialog.dismiss();
    if (!mounted) return;
    switch (result) {
      case HistoryPlaybackReady(:final args):
        context.pushNamed('/video/', arguments: args);
      case HistoryPlaybackUnavailable(:final reason):
        KazumiDialog.showToast(message: reason);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final item = widget.item;

    return Material(
      color: colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: _play,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _cover(colorScheme),
              const SizedBox(width: 14),
              Expanded(
                child: SizedBox(
                  height: _coverHeight,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    // Titles run one or two lines; splitting the slack keeps
                    // both cases balanced against the cover height.
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        item.title,
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: colorScheme.onSurface,
                          fontWeight: FontWeight.w600,
                          height: 1.25,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '看到 ${item.episodeLabel}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Row(
                        children: [
                          _pill(
                            label: item.sourceLabel,
                            background: colorScheme.secondaryContainer,
                            foreground: colorScheme.onSecondaryContainer,
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: _pill(
                              label: item.adapterName,
                              background: colorScheme.surfaceContainerHighest,
                              foreground: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            formatTimestampToRelativeTime(
                              item.lastWatchTime.millisecondsSinceEpoch ~/ 1000,
                            ),
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: colorScheme.outline,
                            ),
                            maxLines: 1,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _cover(ColorScheme colorScheme) {
    return SizedBox(
      width: _coverWidth,
      height: _coverHeight,
      child: Stack(
        alignment: Alignment.center,
        children: [
          NetworkImgLayer(
            src: widget.item.coverUrl,
            width: _coverWidth,
            height: _coverHeight,
          ),
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: 0.92),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.play_arrow_rounded,
              size: 22,
              color: colorScheme.onPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _pill({
    required String label,
    required Color background,
    required Color foreground,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: Theme.of(context)
            .textTheme
            .labelSmall
            ?.copyWith(color: foreground),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
