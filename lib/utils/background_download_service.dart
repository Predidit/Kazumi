import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:kazumi/utils/logger.dart';

/// Android 后台下载服务
///
/// 使用 Foreground Service 保持 app 进程存活，防止系统在后台时杀死下载进程。
/// 下载逻辑仍在主 Isolate 运行，此服务仅负责：
/// 1. 显示通知栏进度
/// 2. 保持进程存活
/// 3. 提供通知栏交互（暂停/取消）
class BackgroundDownloadService {
  static final BackgroundDownloadService _instance = BackgroundDownloadService._internal();
  factory BackgroundDownloadService() => _instance;
  BackgroundDownloadService._internal();

  bool _isInitialized = false;
  bool _isRunning = false;

  /// 通知栏按钮回调
  void Function()? onPauseAll;
  void Function()? onCancelAll;

  /// 点击通知栏时的导航回调（由 UI 层设置）
  void Function()? onNavigateToDownloadRequested;

  /// 需要通知权限时的回调（由 UI 层设置，用于显示解释对话框）
  /// 返回 true 表示用户同意请求权限，false 表示用户拒绝
  Future<bool> Function()? onNotificationPermissionRequired;

  /// 是否支持后台下载（仅 Android）
  bool get isSupported => Platform.isAndroid;

  /// 服务是否正在运行
  bool get isRunning => _isRunning;

  /// 初始化服务配置
  Future<void> init() async {
    if (!isSupported || _isInitialized) return;

    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'kazumi_download_channel',
        channelName: '下载服务',
        channelDescription: '视频下载后台服务',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
        onlyAlertOnce: true,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.nothing(),
        autoRunOnBoot: false,
        autoRunOnMyPackageReplaced: false,
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );

    // Initialize communication port for receiving data from task handler
    FlutterForegroundTask.initCommunicationPort();

    _isInitialized = true;
    KazumiLogger().i('BackgroundDownloadService: initialized');
  }

  /// 检查是否需要请求通知权限
  Future<bool> needsNotificationPermission() async {
    if (!isSupported) return false;
    final permission = await FlutterForegroundTask.checkNotificationPermission();
    return permission != NotificationPermission.granted;
  }

  /// 请求通知权限（由 UI 层在用户确认后调用）
  Future<bool> requestNotificationPermission() async {
    if (!isSupported) return true;
    final result = await FlutterForegroundTask.requestNotificationPermission();
    return result == NotificationPermission.granted;
  }

  /// 启动后台下载服务
  Future<bool> startService() async {
    if (!isSupported) return false;
    if (_isRunning) return true;

    if (!_isInitialized) {
      await init();
    }

    final needsPermission = await needsNotificationPermission();
    if (needsPermission) {
      if (onNotificationPermissionRequired != null) {
        final userAgreed = await onNotificationPermissionRequired!();
        if (userAgreed) {
          final granted = await requestNotificationPermission();
          if (!granted) {
            KazumiLogger().w('BackgroundDownloadService: notification permission denied by user');
          }
        } else {
          KazumiLogger().i('BackgroundDownloadService: user declined permission dialog');
        }
      } else {
        // 没有设置回调，直接请求权限（兼容旧行为）
        final granted = await requestNotificationPermission();
        if (!granted) {
          KazumiLogger().w('BackgroundDownloadService: notification permission denied');
        }
      }
    }

    try {
      final result = await FlutterForegroundTask.startService(
        notificationTitle: '正在下载',
        notificationText: '准备中...',
        notificationButtons: [
          const NotificationButton(id: 'pause_all', text: '暂停全部'),
        ],
        callback: _backgroundCallback,
      );

      _isRunning = result is ServiceRequestSuccess;

      if (_isRunning) {
        KazumiLogger().i('BackgroundDownloadService: service started');
      } else {
        KazumiLogger().w('BackgroundDownloadService: service start returned non-success: $result');
      }
      return _isRunning;
    } catch (e) {
      KazumiLogger().e('BackgroundDownloadService: failed to start service', error: e);
      return false;
    }
  }

  /// 停止后台下载服务
  Future<void> stopService() async {
    if (!isSupported || !_isRunning) return;

    try {
      await FlutterForegroundTask.stopService();
      _isRunning = false;
      KazumiLogger().i('BackgroundDownloadService: service stopped');
    } catch (e) {
      KazumiLogger().e('BackgroundDownloadService: failed to stop service', error: e);
    }
  }

  /// 更新通知栏内容
  Future<void> updateNotification({
    required String title,
    required String text,
  }) async {
    if (!isSupported || !_isRunning) return;

    try {
      await FlutterForegroundTask.updateService(
        notificationTitle: title,
        notificationText: text,
      );
    } catch (e) {
      // 忽略更新失败，不影响下载
    }
  }

  /// 更新下载进度通知
  Future<void> updateProgress({
    required int activeCount,
    required int totalCount,
    required double overallProgress,
    required String speedText,
  }) async {
    if (!isSupported || !_isRunning) return;

    String title;
    String text;

    if (activeCount == 0) {
      title = '下载已暂停';
      text = '共 $totalCount 个任务';
    } else {
      final percent = (overallProgress * 100).toInt();
      title = '正在下载 ($activeCount/$totalCount)';
      text = '$percent% · $speedText';
    }

    await updateNotification(title: title, text: text);
  }

  /// 显示下载完成通知
  Future<void> showCompletedNotification({
    required int completedCount,
  }) async {
    if (!isSupported) return;
    await stopService();
    // TODO: 显示普通通知告知用户下载完成（需要额外的通知插件）
  }

  /// 处理通知栏按钮点击
  void handleNotificationAction(String buttonId) {
    switch (buttonId) {
      case 'pause_all':
        onPauseAll?.call();
        break;
      case 'cancel_all':
        onCancelAll?.call();
        break;
    }
  }

  /// 处理点击通知栏请求导航到下载页
  void handleNavigateToDownload() {
    onNavigateToDownloadRequested?.call();
  }

  /// 添加任务数据回调（用于接收来自 TaskHandler 的消息）
  void addTaskDataCallback(void Function(Object) callback) {
    FlutterForegroundTask.addTaskDataCallback(callback);
  }

  /// 移除任务数据回调
  void removeTaskDataCallback(void Function(Object) callback) {
    FlutterForegroundTask.removeTaskDataCallback(callback);
  }
}

/// 后台任务回调（在独立 Isolate 中运行）
///
/// 注意：此回调主要用于保持服务存活和处理通知交互。
/// 实际下载逻辑在主 Isolate 中运行。
@pragma('vm:entry-point')
void _backgroundCallback() {
  FlutterForegroundTask.setTaskHandler(_DownloadTaskHandler());
}

class _DownloadTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    debugPrint('BackgroundDownloadService: task handler started');
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    // eventAction 配置为 nothing，不会触发
  }

  @override
  void onNotificationButtonPressed(String id) {
    debugPrint('BackgroundDownloadService: notification button pressed: $id');
    FlutterForegroundTask.sendDataToMain({'action': 'button_pressed', 'id': id});
  }

  @override
  void onNotificationPressed() {
    FlutterForegroundTask.sendDataToMain({'action': 'navigate_to_download'});
    FlutterForegroundTask.launchApp();
  }

  @override
  void onNotificationDismissed() {
    // 前台服务通知通常不可划掉
  }

  @override
  Future<void> onDestroy(DateTime timestamp) async {
    debugPrint('BackgroundDownloadService: task handler destroyed');
  }

  @override
  void onReceiveData(Object data) {
    debugPrint('BackgroundDownloadService: received data: $data');
  }
}
