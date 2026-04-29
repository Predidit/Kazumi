import 'package:card_settings_ui/card_settings_ui.dart';
import 'package:flutter/material.dart';
import 'package:kazumi/bean/appbar/sys_app_bar.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/utils/bangumi_update_reminder_service.dart';

class BangumiUpdateReminderSettingsPage extends StatefulWidget {
  const BangumiUpdateReminderSettingsPage({super.key});

  @override
  State<BangumiUpdateReminderSettingsPage> createState() =>
      _BangumiUpdateReminderSettingsPageState();
}

class _BangumiUpdateReminderSettingsPageState
    extends State<BangumiUpdateReminderSettingsPage> {
  late bool reminderEnabled;
  late int reminderHour;
  late int reminderMinute;

  @override
  void initState() {
    super.initState();
    reminderEnabled = BangumiUpdateReminderService.isEnabled();
    reminderHour = BangumiUpdateReminderService.reminderHour();
    reminderMinute = BangumiUpdateReminderService.reminderMinute();
  }

  String get reminderTimeText {
    final hour = reminderHour.toString().padLeft(2, '0');
    final minute = reminderMinute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  Future<void> updateReminderEnabled(bool value) async {
    setState(() => reminderEnabled = value);
    await BangumiUpdateReminderService.setEnabled(value);
    if (!value) {
      return;
    }

    final granted =
        await BangumiUpdateReminderService.ensureSystemNotificationPermission(
      requestIfNeeded: true,
    );
    if (!granted && mounted) {
      KazumiDialog.showToast(
        context: context,
        message: '未获得系统通知权限，将仅显示应用内提醒',
      );
    }
    await BangumiUpdateReminderService.notifyTodayUpdatesIfNeeded();
  }

  Future<void> updateReminderTime({
    int? hour,
    int? minute,
  }) async {
    setState(() {
      reminderHour = hour ?? reminderHour;
      reminderMinute = minute ?? reminderMinute;
    });
    await BangumiUpdateReminderService.setReminderTime(
      hour: reminderHour,
      minute: reminderMinute,
    );
  }

  @override
  Widget build(BuildContext context) {
    final fontFamily = Theme.of(context).textTheme.bodyMedium?.fontFamily;
    return Scaffold(
      appBar: const SysAppBar(title: Text('更新提醒')),
      body: SettingsList(
        maxWidth: 1000,
        sections: [
          SettingsSection(
            tiles: [
              SettingsTile.switchTile(
                onToggle: (value) {
                  updateReminderEnabled(value ?? !reminderEnabled);
                },
                title: Text('系统通知提醒', style: TextStyle(fontFamily: fontFamily)),
                description: Text(
                  '开启后，到设定时间再打开应用时发送系统通知；应用内今日更新入口始终可用',
                  style: TextStyle(fontFamily: fontFamily),
                ),
                initialValue: reminderEnabled,
              ),
              SettingsTile(
                title: Text('提醒时间', style: TextStyle(fontFamily: fontFamily)),
                description: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '当前时间 $reminderTimeText',
                      style: TextStyle(fontFamily: fontFamily),
                    ),
                    Slider(
                      value: reminderHour.toDouble(),
                      min: 0,
                      max: 23,
                      divisions: 23,
                      label: reminderHour.toString().padLeft(2, '0'),
                      onChanged: (value) {
                        updateReminderTime(hour: value.toInt());
                      },
                    ),
                    Slider(
                      value: reminderMinute.toDouble(),
                      min: 0,
                      max: 59,
                      divisions: 59,
                      label: reminderMinute.toString().padLeft(2, '0'),
                      onChanged: (value) {
                        updateReminderTime(minute: value.toInt());
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
          SettingsSection(
            title: Text('说明', style: TextStyle(fontFamily: fontFamily)),
            tiles: [
              SettingsTile(
                title: Text('提醒规则', style: TextStyle(fontFamily: fontFamily)),
                description: Text(
                  '提醒依据为 Bangumi 播出日，只提醒收藏状态为“在看”的番剧，不检测播放源是否已放出新集。',
                  style: TextStyle(fontFamily: fontFamily),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
