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
  bool _isDialogShowing = false;

  /// Last set minutes, used for repeat functionality
  int _lastSetMinutes = 0;

  /// Callback to invoke when timer expires (e.g., pause video)
  VoidCallback? _onExpiredCallback;

  /// Remaining time in seconds notifier
  final ValueNotifier<int> remainingSecondsNotifier = ValueNotifier<int>(0);

  /// Currently set minutes notifier (for UI display)
  final ValueNotifier<int> setMinutesNotifier = ValueNotifier<int>(0);

  /// Whether a shutdown timer is currently active
  bool get isActive => _shutdownTimer != null && _shutdownTimer!.isActive;

  /// Currently set minutes (0 = disabled)
  int get setMinutes => setMinutesNotifier.value;

  /// Remaining time in seconds
  int get remainingSeconds => remainingSecondsNotifier.value;

  /// Start the shutdown timer with the given duration in minutes
  /// [onExpired] callback is invoked when timer expires (before showing dialog)
  void start(int minutes, {VoidCallback? onExpired}) {
    cancel();
    if (minutes <= 0) return;

    _lastSetMinutes = minutes;
    _remainingSeconds = minutes * 60;
    remainingSecondsNotifier.value = _remainingSeconds;
    setMinutesNotifier.value = minutes;
    _onExpiredCallback = onExpired;

    // Update remaining time every second (runs globally, not tied to playback)
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

  /// Repeat the timer with the last set duration
  void repeat() {
    if (_lastSetMinutes > 0) {
      start(_lastSetMinutes, onExpired: _onExpiredCallback);
    }
  }

  /// Cancel the current shutdown timer
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

    // If dialog is showing, dismiss it
    if (_isDialogShowing) {
      KazumiDialog.dismiss();
      _isDialogShowing = false;
    }
  }

  /// Called when timer expires: invoke callback and show dialog
  void _onTimerExpired() {
    // Reset UI state so it doesn't show 00:00
    setMinutesNotifier.value = 0;

    // Invoke the callback if set (e.g., pause video)
    try {
      _onExpiredCallback?.call();
    } catch (e) {
      KazumiLogger()
          .e('TimedShutdownService: onExpired callback failed', error: e);
    }

    _showTimerExpiredDialog();
  }

  /// Show the timer expired dialog with repeat/close options
  void _showTimerExpiredDialog() {
    if (_isDialogShowing) return;
    _isDialogShowing = true;

    KazumiDialog.show(
      clickMaskDismiss: false,
      onDismiss: () {
        _isDialogShowing = false;
      },
      builder: (context) {
        return AlertDialog(
          title: const Text('Sleep timer'),
          content: const Text('The sleep timer has ended, the video has been paused'),
          actions: [
            TextButton(
              onPressed: () {
                _isDialogShowing = false;
                KazumiDialog.dismiss();
                repeat();
                KazumiDialog.showToast(message: 'Restarted the $_lastSetMinutes minute timer');
              },
              child: const Text('Repeat'),
            ),
            TextButton(
              onPressed: () {
                _isDialogShowing = false;
                KazumiDialog.dismiss();
              },
              child: Text(
                'Close',
                style: TextStyle(color: Theme.of(context).colorScheme.outline),
              ),
            ),
          ],
        );
      },
    );
  }

  /// Format remaining seconds to a readable string (e.g., "15:30")
  String formatRemainingTime() {
    int totalSeconds = remainingSecondsNotifier.value;
    if (totalSeconds <= 0) return '00:00';
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  /// Format minutes to readable display string (e.g., "1 小时 30 分钟")
  String formatMinutesToDisplay(int totalMinutes) {
    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;
    if (hours > 0 && minutes > 0) {
      return '$hours h $minutes min';
    } else if (hours > 0) {
      return '$hours h';
    } else {
      return '$minutes min';
    }
  }

  /// Show custom timer picker dialog and start timer if user confirms
  /// Uses KazumiDialog to avoid context-related resource leaks
  /// [onExpired] callback is invoked when timer expires (before showing dialog)
  static void showCustomTimerDialog({
    String title = 'Custom timer',
    bool autoStart = true,
    VoidCallback? onExpired,
    void Function(int)? onResult,
  }) {
    KazumiDialog.show(
      builder: (context) => _CustomTimerDialog(
        title: title,
        autoStart: autoStart,
        onExpired: onExpired,
        onResult: onResult,
      ),
    );
  }
}

class _CustomTimerDialog extends StatefulWidget {
  const _CustomTimerDialog({
    required this.title,
    required this.autoStart,
    required this.onExpired,
    required this.onResult,
  });

  final String title;
  final bool autoStart;
  final VoidCallback? onExpired;
  final void Function(int)? onResult;

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
      KazumiDialog.showToast(message: 'Please select a valid time');
      return;
    }
    KazumiDialog.dismiss();
    if (widget.autoStart) {
      TimedShutdownService().start(totalMinutes, onExpired: widget.onExpired);
      KazumiDialog.showToast(
        message:
            'Sleep timer set for ${TimedShutdownService().formatMinutesToDisplay(totalMinutes)}',
      );
    }
    widget.onResult?.call(totalMinutes);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        height: 200,
        child: Row(
          children: [
            Expanded(
              child: Column(
                children: [
                  const Text('h', style: TextStyle(fontSize: 14)),
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
                  const Text('min', style: TextStyle(fontSize: 14)),
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
          onPressed: () => KazumiDialog.dismiss(),
          child: Text(
            'Cancel',
            style: TextStyle(color: Theme.of(context).colorScheme.outline),
          ),
        ),
        TextButton(
          onPressed: _confirm,
          child: const Text('OK'),
        ),
      ],
    );
  }
}
