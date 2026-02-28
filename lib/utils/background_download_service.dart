import 'dart:io';
import 'package:flutter/services.dart';
import 'package:kazumi/utils/logger.dart';

/// Android 后台下载服务（原生前台服务 + 原生通知进度条 + 通知按钮回传）
///
/// 说明：
/// - 下载逻辑仍在 Flutter 主 Isolate 运行
/// - Android 侧通过 ForegroundService + NotificationCompat.setProgress 显示进度条通知
/// - Flutter 通过 MethodChannel 控制：start/update/stop
/// - 通知按钮（暂停全部）通过 BroadcastReceiver -> MainActivity -> MethodChannel 回传 Flutter
class BackgroundDownloadService {
  static final BackgroundDownloadService _instance =
  BackgroundDownloadService._internal();
  factory BackgroundDownloadService() => _instance;
  BackgroundDownloadService._internal();

  static const MethodChannel _downloadChannel =
  MethodChannel('kazumi/download_fg');

  static const MethodChannel _permissionChannel =
  MethodChannel('kazumi/notification_permission');

  static const MethodChannel _actionsChannel =
  MethodChannel('kazumi/download_actions');

  bool _isInitialized = false;
  bool _isRunning = false;

  void Function()? onPauseAll;
  void Function()? onNavigateToDownloadRequested;

  Future<bool> Function()? onNotificationPermissionRequired;

  bool get isSupported => Platform.isAndroid;
  bool get isRunning => _isRunning;

  Future<void> init() async {
    if (!isSupported || _isInitialized) return;

    // 监听原生通知按钮回传
    _actionsChannel.setMethodCallHandler((call) async {
      if (call.method == 'onAction') {
        final args = (call.arguments as Map?) ?? const {};
        final id = args['id'] as String?;

        if (id == null) return;

        handleNotificationAction(id);
      }
    });

    _isInitialized = true;
    KazumiLogger().i('BackgroundDownloadService(native): initialized');
  }

  Future<bool> needsNotificationPermission() async {
    if (!isSupported) return false;
    try {
      final granted = await _permissionChannel.invokeMethod<bool>('check');
      return granted != true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> requestNotificationPermission() async {
    if (!isSupported) return true;
    try {
      final granted = await _permissionChannel.invokeMethod<bool>('request');
      return granted == true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> startService() async {
    if (!isSupported) return false;
    if (_isRunning) return true;

    if (!_isInitialized) {
      await init();
    }

    // 通知权限
    final needsPermission = await needsNotificationPermission();
    if (needsPermission) {
      if (onNotificationPermissionRequired != null) {
        final userAgreed = await onNotificationPermissionRequired!();
        if (userAgreed) {
          final granted = await requestNotificationPermission();
          if (!granted) {
            KazumiLogger().w(
                'BackgroundDownloadService(native): notification permission denied by user');
          }
        } else {
          KazumiLogger().i(
              'BackgroundDownloadService(native): user declined permission dialog');
        }
      } else {
        final granted = await requestNotificationPermission();
        if (!granted) {
          KazumiLogger().w(
              'BackgroundDownloadService(native): notification permission denied');
        }
      }
    }

    try {
      // 启动原生前台服务：先用不确定进度（indeterminate=true）
      await _downloadChannel.invokeMethod('start', {
        'title': '正在下载',
        'text': '准备中...',
      });

      // 立即更新一次：显示 0% 的确定进度条
      await _downloadChannel.invokeMethod('update', {
        'title': '正在下载',
        'text': '0% · 准备中...',
        'progress': 0,
        'indeterminate': false,
      });

      _isRunning = true;
      KazumiLogger().i('BackgroundDownloadService(native): service started');
      return true;
    } catch (e) {
      _isRunning = false;
      KazumiLogger()
          .e('BackgroundDownloadService(native): failed to start', error: e);
      return false;
    }
  }

  Future<void> stopService() async {
    if (!isSupported || !_isRunning) return;
    try {
      await _downloadChannel.invokeMethod('stop');
      _isRunning = false;
      KazumiLogger().i('BackgroundDownloadService(native): service stopped');
    } catch (e) {
      KazumiLogger()
          .e('BackgroundDownloadService(native): failed to stop', error: e);
    }
  }

  Future<void> updateNotification({
    required String title,
    required String text,
    int? progress,
  }) async {
    if (!isSupported || !_isRunning) return;

    try {
      if (progress == null) {
        await _downloadChannel.invokeMethod('update', {
          'title': title,
          'text': text,
          'progress': 0,
          'indeterminate': true,
        });
      } else {
        final p = progress.clamp(0, 100);
        await _downloadChannel.invokeMethod('update', {
          'title': title,
          'text': text,
          'progress': p,
          'indeterminate': false,
        });
      }
    } catch (_) {
      // 忽略更新失败，不影响下载
    }
  }

  Future<void> updateProgress({
    required int activeCount,
    required int totalCount,
    required double overallProgress,
    required String speedText,
  }) async {
    if (!isSupported || !_isRunning) return;

    if (activeCount == 0) {
      final title = '下载已暂停';
      final text = '共 $totalCount 个任务';
      await updateNotification(title: title, text: text, progress: null);
      return;
    }

    final percent = (overallProgress * 100).clamp(0, 100).toInt();
    final title = '正在下载 ($activeCount/$totalCount)';
    final text = '$percent% · $speedText';

    await updateNotification(title: title, text: text, progress: percent);
  }

  Future<void> showCompletedNotification({
    required int completedCount,
  }) async {
    if (!isSupported) return;
    await stopService();
  }

  void handleNotificationAction(String buttonId) async {
    KazumiLogger().i('BackgroundDownloadService(native): action=$buttonId');

    switch (buttonId) {
      case 'pause_all':
        onPauseAll?.call();
        break;

      case 'kazumi.action.OPEN_DOWNLOAD_MANAGER':
        handleNavigateToDownload();
        break;

      default:
        break;
    }
  }


  void handleNavigateToDownload() {
    onNavigateToDownloadRequested?.call();
  }
}
