import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FilteringTextInputFormatter;
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/bean/appbar/sys_app_bar.dart';
import 'package:kazumi/utils/timed_shutdown_service.dart';
import 'package:card_settings_ui/card_settings_ui.dart';

class TimedShutdownSettingsPage extends StatefulWidget {
  const TimedShutdownSettingsPage({super.key});

  @override
  State<TimedShutdownSettingsPage> createState() =>
      _TimedShutdownSettingsPageState();
}

class _TimedShutdownSettingsPageState extends State<TimedShutdownSettingsPage> {
  final TimedShutdownService _shutdownService = TimedShutdownService();

  // Predefined options
  final List<Map<String, dynamic>> options = [
    {'label': '不开启', 'minutes': 0},
    {'label': '15分钟', 'minutes': 15},
    {'label': '30分钟', 'minutes': 30},
    {'label': '60分钟', 'minutes': 60},
    {'label': '自定义', 'minutes': -1}, // -1 indicates custom
  ];

  @override
  void onBackPressed(BuildContext context) {
    if (KazumiDialog.observer.hasKazumiDialog) {
      KazumiDialog.dismiss();
    }
  }

  void _selectOption(int minutes) {
    if (minutes == -1) {
      // Show custom input dialog
      _showCustomInputDialog();
    } else {
      _applySelection(minutes);
    }
  }

  void _applySelection(int minutes) {
    if (minutes > 0) {
      _shutdownService.start(minutes);
      KazumiDialog.showToast(message: '已设置 $minutes 分钟后关闭应用');
    } else {
      _shutdownService.cancel();
      KazumiDialog.showToast(message: '已取消定时关闭');
    }
  }

  Future<void> _showCustomInputDialog() async {
    final result = await KazumiDialog.show<int>(builder: (context) {
      String input = "";
      return AlertDialog(
        title: const Text('自定义时间'),
        content: TextField(
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
          ],
          decoration: const InputDecoration(
            labelText: '请输入分钟数',
            hintText: '例如: 45',
            suffixText: '分钟',
          ),
          onChanged: (value) {
            input = value;
          },
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => KazumiDialog.dismiss(),
            child: Text(
              '取消',
              style: TextStyle(color: Theme.of(context).colorScheme.outline),
            ),
          ),
          TextButton(
            onPressed: () {
              final int? newValue = int.tryParse(input.trim());
              if (newValue == null || newValue <= 0) {
                KazumiDialog.showToast(message: '请输入大于0的数字');
                return;
              }
              if (newValue > 1440) {
                KazumiDialog.showToast(message: '最长不能超过24小时（1440分钟）');
                return;
              }
              KazumiDialog.dismiss(popWith: newValue);
            },
            child: const Text('确定'),
          ),
        ],
      );
    });

    if (result != null) {
      _applySelection(result);
    }
  }

  bool _isOptionSelected(int optionMinutes, int selectedMinutes) {
    if (optionMinutes == -1) {
      if (selectedMinutes <= 0) return false;
      // If selectedMinutes is not one of the predefined times (excluding 0 and -1)
      return !options.any((o) => o['minutes'] == selectedMinutes && o['minutes'] > 0);
    }
    return selectedMinutes == optionMinutes;
  }

  String _getOptionSubtitle(int optionMinutes, int selectedMinutes) {
    if (optionMinutes == -1 && _isOptionSelected(-1, selectedMinutes)) {
      return '当前设置: $selectedMinutes 分钟';
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final fontFamily = Theme.of(context).textTheme.bodyMedium?.fontFamily;

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        onBackPressed(context);
      },
      child: Scaffold(
        appBar: const SysAppBar(title: Text('定时关闭')),
        body: ValueListenableBuilder<int>(
          valueListenable: _shutdownService.setMinutesNotifier,
          builder: (context, setMinutes, _) {
            final isTimerActive = setMinutes > 0;
            return ValueListenableBuilder<int>(
              valueListenable: _shutdownService.remainingSecondsNotifier,
              builder: (context, remainingSeconds, _) {
                return SettingsList(
                  maxWidth: 1000,
                  sections: [
                    // Show current timer status if active
                    if (isTimerActive)
                      SettingsSection(
                        title: Text('当前状态', style: TextStyle(fontFamily: fontFamily)),
                        tiles: [
                          SettingsTile(
                            leading: const Icon(Icons.timer_rounded, color: Colors.orange),
                            title: Text(
                              '剩余时间: ${_shutdownService.formatRemainingTime()}',
                              style: TextStyle(
                                fontFamily: fontFamily,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                            description: Text(
                              '点击可取消定时关闭',
                              style: TextStyle(fontFamily: fontFamily),
                            ),
                            onPressed: (_) {
                              _applySelection(0);
                            },
                          ),
                        ],
                      ),
                    SettingsSection(
                      title: Text('定时选项', style: TextStyle(fontFamily: fontFamily)),
                      tiles: [
                        for (final option in options)
                          SettingsTile(
                            onPressed: (_) => _selectOption(option['minutes']),
                            leading: Icon(
                              _isOptionSelected(option['minutes'], setMinutes)
                                  ? Icons.radio_button_checked
                                  : Icons.radio_button_unchecked,
                              color: _isOptionSelected(option['minutes'], setMinutes)
                                  ? Theme.of(context).colorScheme.primary
                                  : null,
                            ),
                            title: Text(
                              option['label'],
                              style: TextStyle(
                                fontFamily: fontFamily,
                                color: _isOptionSelected(option['minutes'], setMinutes)
                                    ? Theme.of(context).colorScheme.primary
                                    : null,
                                fontWeight: _isOptionSelected(option['minutes'], setMinutes)
                                    ? FontWeight.bold
                                    : null,
                              ),
                            ),
                            description: _getOptionSubtitle(option['minutes'], setMinutes).isNotEmpty
                                ? Text(
                                    _getOptionSubtitle(option['minutes'], setMinutes),
                                    style: TextStyle(fontFamily: fontFamily),
                                  )
                                : null,
                          ),
                      ],
                      bottomInfo: Text(
                        '选择定时关闭时间后，应用将在指定时间后自动关闭。关闭前会弹出30秒倒计时提醒。',
                        style: TextStyle(fontFamily: fontFamily),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}
