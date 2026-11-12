import 'dart:async';
import 'package:flutter/material.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/bean/widget/scroll_field.dart';
import 'package:kazumi/bean/widget/state_presentation.dart';
import 'package:kazumi/services/logging/logger.dart';

class TimedShutdownService {
  static final TimedShutdownService _instance =
      TimedShutdownService._internal();
  factory TimedShutdownService() => _instance;
  TimedShutdownService._internal();

  Timer? _shutdownTimer;
  int _remainingSeconds = 0;
  KazumiDialogHandle<void>? _expiryDialog;
  int _lastSetMinutes = 0;
  VoidCallback? _onExpiredCallback;

  final ValueNotifier<int> remainingSecondsNotifier = ValueNotifier<int>(0);

  /// Bumped every time the timer actually expires, so the mounted player panel
  /// can drop its resume ownership without the service holding a stale widget.
  final ValueNotifier<int> expiryTicks = ValueNotifier<int>(0);
  final ValueNotifier<int> setMinutesNotifier = ValueNotifier<int>(0);

  bool get isActive => _shutdownTimer != null && _shutdownTimer!.isActive;
  int get setMinutes => setMinutesNotifier.value;

  void start(int minutes, {VoidCallback? onExpired}) {
    cancel();
    if (minutes <= 0) return;

    _lastSetMinutes = minutes;
    _remainingSeconds = minutes * 60;
    remainingSecondsNotifier.value = _remainingSeconds;
    setMinutesNotifier.value = minutes;
    _onExpiredCallback = onExpired;
    _shutdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        _remainingSeconds--;
        remainingSecondsNotifier.value = _remainingSeconds;
      }

      if (_remainingSeconds <= 0) {
        timer.cancel();
        _shutdownTimer = null;
        _onTimerExpired();
      }
    });
  }

  void cancel() {
    _shutdownTimer?.cancel();
    _shutdownTimer = null;
    _remainingSeconds = 0;
    _onExpiredCallback = null;
    if (remainingSecondsNotifier.value != 0) {
      remainingSecondsNotifier.value = 0;
    }
    if (setMinutesNotifier.value != 0) {
      setMinutesNotifier.value = 0;
    }
    _expiryDialog?.dismiss();
    _expiryDialog = null;
  }

  void _onTimerExpired() {
    setMinutesNotifier.value = 0;
    expiryTicks.value++;
    try {
      _onExpiredCallback?.call();
    } catch (e) {
      KazumiLogger()
          .e('TimedShutdownService: onExpired callback failed', error: e);
    }

    _showTimerExpiredDialog();
  }

  void _showTimerExpiredDialog() {
    if (_expiryDialog?.isActive ?? false) return;
    final dialog = _expiryDialog = KazumiDialogHandle<void>();

    KazumiDialog.show<void>(
      handle: dialog,
      clickMaskDismiss: false,
      onDismiss: () {
        if (identical(_expiryDialog, dialog)) _expiryDialog = null;
      },
      builder: (context) {
        return AlertDialog(
          title: const Text('定时关闭'),
          content: const Text('定时时间已到，视频已暂停'),
          actions: [
            TextButton(
              onPressed: () {
                start(_lastSetMinutes, onExpired: _onExpiredCallback);
                KazumiDialog.showToast(message: '已重新开始 $_lastSetMinutes 分钟定时');
              },
              child: const Text('重复'),
            ),
            TextButton(
              onPressed: () {
                dialog.dismiss();
              },
              child: Text(
                '关闭',
                style: TextStyle(color: Theme.of(context).colorScheme.outline),
              ),
            ),
          ],
        );
      },
    );
  }

  String formatRemainingTime() {
    int totalSeconds = remainingSecondsNotifier.value;
    if (totalSeconds <= 0) return '00:00';
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  String formatMinutesToDisplay(int totalMinutes) {
    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;
    if (hours > 0 && minutes > 0) {
      return '$hours 小时 $minutes 分钟';
    } else if (hours > 0) {
      return '$hours 小时';
    } else {
      return '$minutes 分钟';
    }
  }

  static void showCustomTimerDialog({
    VoidCallback? onExpired,
  }) {
    KazumiDialog.show(
      builder: (context) => _CustomTimerDialog(
        onExpired: onExpired,
      ),
    );
  }
}

class _CustomTimerDialog extends StatefulWidget {
  const _CustomTimerDialog({
    required this.onExpired,
  });

  final VoidCallback? onExpired;

  @override
  State<_CustomTimerDialog> createState() => _CustomTimerDialogState();
}

class _CustomTimerDialogState extends State<_CustomTimerDialog> {
  int _hours = 0;
  int _minutes = 0;

  int get _totalMinutes => _hours * 60 + _minutes;

  void _confirm() {
    final totalMinutes = _totalMinutes;
    KazumiDialog.dismiss(context: context);
    TimedShutdownService().start(totalMinutes, onExpired: widget.onExpired);
    KazumiDialog.showToast(
      message:
          '已设置 ${TimedShutdownService().formatMinutesToDisplay(totalMinutes)} 后定时关闭',
    );
  }

  Widget _buildField({
    required String label,
    required int itemCount,
    required ValueChanged<int> onChanged,
  }) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ScrollField(
          itemCount: itemCount,
          semanticLabel: label,
          onChanged: onChanged,
        ),
        const SizedBox(height: 8),
        ExcludeSemantics(
          child: Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSeparator() {
    final theme = Theme.of(context);
    return SizedBox(
      width: 16,
      height: ScrollField.height,
      child: OverflowBox(
        minWidth: 0,
        minHeight: 0,
        maxWidth: double.infinity,
        maxHeight: double.infinity,
        child: Transform.translate(
          offset: const Offset(0, -4),
          child: ExcludeSemantics(
            child: Text(
              ':',
              textScaler: MediaQuery.textScalerOf(context).clamp(
                maxScaleFactor: ScrollField.maxTextScaleFactor,
              ),
              style: theme.textTheme.displayLarge?.copyWith(
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Follows the M3 Expressive vibrant time picker dialog: no headline, and a
  // 12dp inset that keeps the 16dp fields concentric with the 28dp container.
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Dialog(
      constraints: const BoxConstraints(),
      insetPadding: const EdgeInsets.all(24),
      backgroundColor: colors.surfaceContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      clipBehavior: Clip.antiAlias,
      child: Semantics(
        scopesRoute: true,
        namesRoute: true,
        explicitChildNodes: true,
        label: '自定义定时',
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(12),
          child: IntrinsicWidth(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildField(
                      label: '小时',
                      itemCount: 25,
                      onChanged: (index) => setState(() => _hours = index),
                    ),
                    _buildSeparator(),
                    _buildField(
                      label: '分钟',
                      itemCount: 60,
                      onChanged: (index) => setState(() => _minutes = index),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                OverflowBar(
                  alignment: MainAxisAlignment.end,
                  spacing: 8,
                  overflowAlignment: OverflowBarAlignment.end,
                  overflowSpacing: 8,
                  children: [
                    TextButton(
                      style: StateActionButton.styleOf(context),
                      onPressed: () => KazumiDialog.dismiss(context: context),
                      child: const Text('取消'),
                    ),
                    StateActionButton(
                      onPressed: _totalMinutes > 0 ? _confirm : null,
                      text: '开始',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
