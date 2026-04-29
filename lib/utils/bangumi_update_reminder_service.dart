import 'dart:io';

import 'package:flutter/services.dart';
import 'package:kazumi/modules/bangumi/bangumi_item.dart';
import 'package:kazumi/modules/collect/collect_module.dart';
import 'package:kazumi/modules/collect/collect_type.dart';
import 'package:kazumi/utils/background_download_service.dart';
import 'package:kazumi/utils/logger.dart';
import 'package:kazumi/utils/storage.dart';

class BangumiUpdateReminderService {
  static const MethodChannel _notificationChannel =
      MethodChannel('com.predidit.kazumi/notification');

  static const int defaultReminderHour = 9;
  static const int defaultReminderMinute = 0;

  static bool isEnabled() {
    final value = GStorage.setting.get(
      SettingBoxKey.bangumiUpdateReminderEnabled,
      defaultValue: false,
    );
    return value is bool ? value : false;
  }

  static int reminderHour() {
    final value = GStorage.setting.get(
      SettingBoxKey.bangumiUpdateReminderHour,
      defaultValue: defaultReminderHour,
    );
    return value is int ? value.clamp(0, 23).toInt() : defaultReminderHour;
  }

  static int reminderMinute() {
    final value = GStorage.setting.get(
      SettingBoxKey.bangumiUpdateReminderMinute,
      defaultValue: defaultReminderMinute,
    );
    return value is int ? value.clamp(0, 59).toInt() : defaultReminderMinute;
  }

  static Future<void> setEnabled(bool value) async {
    await GStorage.setting.put(
      SettingBoxKey.bangumiUpdateReminderEnabled,
      value,
    );
  }

  static Future<void> setReminderTime({
    required int hour,
    required int minute,
  }) async {
    await GStorage.setting.put(
      SettingBoxKey.bangumiUpdateReminderHour,
      hour.clamp(0, 23).toInt(),
    );
    await GStorage.setting.put(
      SettingBoxKey.bangumiUpdateReminderMinute,
      minute.clamp(0, 59).toInt(),
    );
  }

  static List<BangumiItem> getTodayUpdates({DateTime? now}) {
    return filterTodayUpdates(
      GStorage.collectibles.values.cast<CollectedBangumi>(),
      now ?? DateTime.now(),
    );
  }

  static List<BangumiItem> filterTodayUpdates(
    Iterable<CollectedBangumi> collectibles,
    DateTime now,
  ) {
    final weekday = now.weekday;
    final seenIds = <int>{};
    final result = <BangumiItem>[];

    for (final collectible in collectibles) {
      if (collectible.type != CollectType.watching.value) {
        continue;
      }
      final bangumiItem = collectible.bangumiItem;
      if (bangumiItem.airWeekday != weekday) {
        continue;
      }
      if (seenIds.add(bangumiItem.id)) {
        result.add(bangumiItem);
      }
    }

    result.sort((a, b) {
      final aTitle = a.nameCn.isNotEmpty ? a.nameCn : a.name;
      final bTitle = b.nameCn.isNotEmpty ? b.nameCn : b.name;
      return aTitle.compareTo(bTitle);
    });
    return result;
  }

  static bool isReminderTimeReached(DateTime now) {
    final reminder = DateTime(
      now.year,
      now.month,
      now.day,
      reminderHour(),
      reminderMinute(),
    );
    return !now.isBefore(reminder);
  }

  static String dateKey(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  static bool wasNotifiedToday(DateTime now) {
    final value = GStorage.setting.get(
      SettingBoxKey.bangumiUpdateReminderSeenDate,
      defaultValue: '',
    );
    return value == dateKey(now);
  }

  static Future<void> markNotifiedToday(DateTime now) async {
    await GStorage.setting.put(
      SettingBoxKey.bangumiUpdateReminderSeenDate,
      dateKey(now),
    );
  }

  static Future<bool> ensureSystemNotificationPermission({
    bool requestIfNeeded = false,
  }) async {
    if (!Platform.isAndroid) {
      return false;
    }
    try {
      final backgroundService = BackgroundDownloadService();
      if (await backgroundService.needsNotificationPermission()) {
        if (!requestIfNeeded) {
          return false;
        }
        return await backgroundService.requestNotificationPermission();
      }
      return true;
    } catch (e) {
      KazumiLogger()
          .w('BangumiUpdateReminder: notification permission check failed', error: e);
      return false;
    }
  }

  static Future<void> notifyTodayUpdatesIfNeeded({DateTime? now}) async {
    final current = now ?? DateTime.now();
    if (!isEnabled() ||
        !isReminderTimeReached(current) ||
        wasNotifiedToday(current)) {
      return;
    }

    final updates = getTodayUpdates(now: current);
    if (updates.isEmpty) {
      return;
    }

    final shown = await showSystemNotification(updates);
    if (shown) {
      await markNotifiedToday(current);
    }
  }

  static Future<bool> showSystemNotification(List<BangumiItem> updates) async {
    if (!Platform.isAndroid || updates.isEmpty) {
      return false;
    }
    final granted = await ensureSystemNotificationPermission();
    if (!granted) {
      return false;
    }

    final names = updates
        .take(3)
        .map((item) => item.nameCn.isNotEmpty ? item.nameCn : item.name)
        .join('、');
    final title = '今日有 ${updates.length} 部番剧更新';
    final text = updates.length > 3 ? '$names 等' : names;

    try {
      final shown = await _notificationChannel.invokeMethod<bool>(
        'showBangumiUpdateReminder',
        {
          'title': title,
          'text': text,
        },
      );
      return shown ?? false;
    } catch (e) {
      KazumiLogger()
          .w('BangumiUpdateReminder: show system notification failed', error: e);
      return false;
    }
  }
}
