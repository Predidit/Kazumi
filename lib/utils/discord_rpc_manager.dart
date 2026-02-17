import 'package:discord_rpc/discord_rpc.dart';
import 'package:kazumi/utils/storage.dart'; // 引入存储库

class DiscordRpcManager {
  static DiscordRPC? _rpc;
  static bool _isNativeInitialized = false;
  static String? _currentAppId; // 用于记录当前正在使用的 ID

  // 缓存最后一次发送的 Presence，用于重连后补发
  static DiscordPresence? _pendingPresence;

  /// 初始化 RPC 服务
  static void init() {
    try {
      // 1. 从设置中读取 Application ID
      final String? userAppId = GStorage.setting.get(SettingBoxKey.discordClientId);
      // 也可以顺便读取一下开关，如果用户关了 RPC，直接退出
      final bool enable = GStorage.setting.get(SettingBoxKey.discordRpcEnable, defaultValue: false);

      // 如果未开启，或者 ID 为空，直接清理并退出
      if (!enable || userAppId == null || userAppId.trim().isEmpty) {
        if (_rpc != null) clear(); // 如果之前连着，现在关了，要断开
        return;
      }

      final String targetId = userAppId.trim();

      // 2. 智能判断：如果 RPC 已经启动，且 ID 没变，就不用重启了
      if (_rpc != null && _currentAppId == targetId) {
        return;
      }

      // 3. 如果 ID 变了（或者第一次启动），先清理旧的
      if (_rpc != null) {
        print('🔥🔥🔥 [RPC] 检测到 ID 变更，正在重启服务...');
        clear();
      }

      // 4. 初始化原生库 (只做一次)
      if (!_isNativeInitialized) {
        try {
          DiscordRPC.initialize();
          _isNativeInitialized = true;
        } catch (_) {
          _isNativeInitialized = true;
        }
      }

      // 5. 启动新连接
      _rpc = DiscordRPC(applicationId: targetId);
      _rpc?.start(autoRegister: true);
      _currentAppId = targetId; // 记录当前 ID
      
      print('🔥🔥🔥 [RPC] 服务已启动，ID: $targetId');
    } catch (e) {
      print('🔥🔥🔥 [RPC] 初始化失败: $e');
      _rpc = null;
      _currentAppId = null;
    }
  }

  /// 更新状态
  static void updatePresence({
    required String title,
    required String subTitle,
    required bool isPlaying,
    int? startTimeEpoch,
  }) {
    // 每次更新前都尝试 init，确保能响应设置的变化
    init(); 

    if (_rpc == null) return;

    try {
      // 字段长度保护
      String safeTitle = title.length < 2 ? "$title  " : title;
      String safeSub = subTitle.length < 2 ? "$subTitle " : subTitle;

      final presence = DiscordPresence(
        details: safeTitle,
        state: safeSub,
        startTimeStamp: isPlaying && startTimeEpoch != null ? startTimeEpoch : null,
        largeImageKey: 'logo',
        largeImageText: "Kazumi Player",
        smallImageKey: isPlaying ? 'play' : 'pause',
        smallImageText: isPlaying ? 'Playing' : 'Paused',
      );

      _pendingPresence = presence; // 缓存

      _rpc!.updatePresence(presence);

      // 暴力补刀机制 (应对刚启动时的连接延迟)
      if (isPlaying) {
        Future.delayed(const Duration(seconds: 2), () {
          if (_rpc != null && _pendingPresence != null) {
            try { _rpc!.updatePresence(_pendingPresence!); } catch (_) {}
          }
        });
      }

    } catch (e) {
      print('❌ [RPC] 发送异常: $e');
    }
  }

  /// 清理资源
  static void clear() {
    try {
      _rpc?.clearPresence();
      _rpc?.shutDown();
    } catch (_) {}
    _rpc = null;
    _currentAppId = null; // 清空当前 ID 记录
    _pendingPresence = null;
  }
}