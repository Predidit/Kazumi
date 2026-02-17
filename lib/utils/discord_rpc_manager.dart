import 'package:discord_rpc/discord_rpc.dart';

class DiscordRpcManager {
  static DiscordRPC? _rpc;
  static bool _isNativeInitialized = false; // 🔥 新增：防止重复初始化导致崩溃

  // 🔴🔴🔴 致命关键点 🔴🔴🔴
  // 请立刻删除下面这串数字，填入你 Discord Developer Portal 里的真实 Application ID
  // 如果这里是 "123456789012345678"，你永远看不见状态！
  static const String _appId = "1473047818498216028"; 

  static void init() {
    try {
      if (_rpc != null) return;

      // 🔥 修复崩溃的核心逻辑：检查是否已经加载过原生库
      if (!_isNativeInitialized) {
        try {
          DiscordRPC.initialize();
          _isNativeInitialized = true; // 标记为已加载
        } catch (e) {
          // 如果它抱怨"Already initialized"，说明已经是 true 了，忽略这个错误
          _isNativeInitialized = true;
        }
      }

      // 创建实例
      _rpc = DiscordRPC(applicationId: _appId);
      
      // 启动服务
      _rpc?.start(autoRegister: true);
      
      print('🔥🔥🔥 [RPC] 服务已启动，ID: $_appId');
    } catch (e) {
      print('🔥🔥🔥 [RPC] 初始化失败: $e');
      _rpc = null; 
    }
  }

  static void updatePresence({
    required String animeTitle,
    required int episode,
    required bool isPlaying,
    int? remainingSeconds,
  }) {
    if (_rpc == null) init();

    if (_rpc == null) {
      // 如果 init 还是失败，不再打印骚扰日志，静默返回
      return;
    }

    try {
      String safeTitle = animeTitle.length < 2 ? "$animeTitle  " : animeTitle;

      _rpc!.updatePresence(
        DiscordPresence(
          details: safeTitle,
          state: "第 $episode 集",
          endTimeStamp: isPlaying && remainingSeconds != null
              ? DateTime.now().millisecondsSinceEpoch + (remainingSeconds * 1000)
              : null,
          largeImageKey: 'logo',
          largeImageText: "Kazumi Player",
          smallImageKey: isPlaying ? 'play' : 'pause',
          smallImageText: isPlaying ? 'Playing' : 'Paused',
        ),
      );
      print('✅ [RPC] 状态包发送成功');
    } catch (e) {
      print('❌ [RPC] 发送异常: $e');
    }
  }

  static void clear() {
    try {
      _rpc?.clearPresence();
      _rpc?.shutDown();
    } catch (_) {}
    _rpc = null;
    // 注意：不要把 _isNativeInitialized 设为 false，原生库加载一次就够了
  }
}