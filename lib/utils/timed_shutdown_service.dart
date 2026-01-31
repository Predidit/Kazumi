import 'dart:async';
import 'package:flutter/material.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/utils/utils.dart';

/// Global service to manage timed app shutdown
class TimedShutdownService {
  static final TimedShutdownService _instance = TimedShutdownService._internal();
  factory TimedShutdownService() => _instance;
  TimedShutdownService._internal();

  Timer? _shutdownTimer;
  Timer? _warningCountdownTimer;
  int _remainingSeconds = 0;
  bool _isWarningDialogShowing = false;
  
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
  void start(int minutes) {
    cancel();
    if (minutes <= 0) return;

    _remainingSeconds = minutes * 60;
    remainingSecondsNotifier.value = _remainingSeconds;
    setMinutesNotifier.value = minutes;
    
    // Update remaining time every second
    _shutdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        _remainingSeconds--;
        remainingSecondsNotifier.value = _remainingSeconds;
      }
      
      if (_remainingSeconds <= 0) {
        cancel(); // Use standard cancel for cleanup
        _showWarningDialog();
      }
    });
  }

  /// Cancel the current shutdown timer
  void cancel() {
    _shutdownTimer?.cancel();
    _shutdownTimer = null;
    _warningCountdownTimer?.cancel();
    _warningCountdownTimer = null;
    _remainingSeconds = 0;
    if (remainingSecondsNotifier.value != 0) {
      remainingSecondsNotifier.value = 0;
    }
    if (setMinutesNotifier.value != 0) {
      setMinutesNotifier.value = 0;
    }
    
    // If warning dialog is showing, dismiss it
    if (_isWarningDialogShowing) {
      KazumiDialog.dismiss();
      _isWarningDialogShowing = false;
    }
  }

  /// Show the 30-second warning dialog before shutdown
  void _showWarningDialog() {
    if (_isWarningDialogShowing) return;
    _isWarningDialogShowing = true;
    
    int warningCountdown = 30;

    KazumiDialog.show(
      clickMaskDismiss: false,
      onDismiss: () {
        _isWarningDialogShowing = false;
        _warningCountdownTimer?.cancel();
        _warningCountdownTimer = null;
      },
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            // Start countdown timer if not already started
            _warningCountdownTimer ??= Timer.periodic(const Duration(seconds: 1), (timer) {
              warningCountdown--;
              if (warningCountdown <= 0) {
                timer.cancel();
                KazumiDialog.dismiss();
                Utils.safeExit();
              } else {
                setState(() {});
              }
            });

            return AlertDialog(
              title: const Text('定时关闭'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.timer_off_rounded,
                    size: 48,
                    color: Colors.orange,
                  ),
                  const SizedBox(height: 16),
                  const Text('应用即将关闭'),
                  const SizedBox(height: 8),
                  Text(
                    '$warningCountdown 秒后自动关闭',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    _warningCountdownTimer?.cancel();
                    _warningCountdownTimer = null;
                    _isWarningDialogShowing = false;
                    KazumiDialog.dismiss();
                    KazumiDialog.showToast(message: '已取消本次定时关闭');
                  },
                  child: const Text('取消关闭'),
                ),
                TextButton(
                  onPressed: () {
                    _warningCountdownTimer?.cancel();
                    KazumiDialog.dismiss();
                    Utils.safeExit();
                  },
                  child: Text(
                    '立即关闭',
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ),
              ],
            );
          },
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

}
