import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
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
  late final FixedExtentScrollController _hoursController;
  late final FixedExtentScrollController _minutesController;
  int _selectedHours = 0;
  int _selectedMinutes = 0;

  @override
  void initState() {
    super.initState();
    _hoursController = FixedExtentScrollController(initialItem: _selectedHours);
    _minutesController =
        FixedExtentScrollController(initialItem: _selectedMinutes);
  }

  @override
  void dispose() {
    _hoursController.dispose();
    _minutesController.dispose();
    super.dispose();
  }

  void _confirm() {
    final totalMinutes = _selectedHours * 60 + _selectedMinutes;
    if (totalMinutes <= 0) {
      KazumiDialog.showToast(message: '请选择有效的时间');
      return;
    }
    KazumiDialog.dismiss(context: context);
    TimedShutdownService().start(totalMinutes, onExpired: widget.onExpired);
    KazumiDialog.showToast(
      message:
          '已设置 ${TimedShutdownService().formatMinutesToDisplay(totalMinutes)} 后定时关闭',
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('自定义定时'),
      content: SizedBox(
        height: 200,
        child: Row(
          children: [
            Expanded(
              child: Column(
                children: [
                  const Text('时', style: TextStyle(fontSize: 14)),
                  const SizedBox(height: 8),
                  Expanded(
                    child: CupertinoPicker(
                      scrollController: _hoursController,
                      itemExtent: 40,
                      onSelectedItemChanged: (index) {
                        setState(() => _selectedHours = index);
                      },
                      children: List.generate(
                        25,
                        (index) => Center(
                          child: Text(
                            index.toString().padLeft(2, '0'),
                            style: const TextStyle(fontSize: 20),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Text(
              ':',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            Expanded(
              child: Column(
                children: [
                  const Text('分', style: TextStyle(fontSize: 14)),
                  const SizedBox(height: 8),
                  Expanded(
                    child: CupertinoPicker(
                      scrollController: _minutesController,
                      itemExtent: 40,
                      onSelectedItemChanged: (index) {
                        setState(() => _selectedMinutes = index);
                      },
                      children: List.generate(
                        60,
                        (index) => Center(
                          child: Text(
                            index.toString().padLeft(2, '0'),
                            style: const TextStyle(fontSize: 20),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => KazumiDialog.dismiss(context: context),
          child: Text(
            '取消',
            style: TextStyle(color: Theme.of(context).colorScheme.outline),
          ),
        ),
        TextButton(
          onPressed: _confirm,
          child: const Text('确定'),
        ),
      ],
    );
  }
}
