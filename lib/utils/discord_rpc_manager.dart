import 'package:discord_rpc/discord_rpc.dart';

class DiscordRpcManager {
  static DiscordRPC? _rpc;
  static bool _isNativeInitialized = false;

  // 🔴 必填：Application ID
  static const String _appId = "1473047818498216028"; 

  static void init() {
    try {
      if (_rpc != null) return;
      
      if (!_isNativeInitialized) {
        try {
          DiscordRPC.initialize();
          _isNativeInitialized = true;
        } catch (_) {
          _isNativeInitialized = true;
        }
      }

      _rpc = DiscordRPC(applicationId: _appId);
      _rpc?.start(autoRegister: true);
      print('🔥🔥🔥 [RPC] 服务启动');
    } catch (e) {
      print('🔥🔥🔥 [RPC] 初始化失败: $e');
      _rpc = null;
    }
  }

  static void updatePresence({
    required String title,
    required String subTitle,
    required bool isPlaying,
    int? startTimeEpoch,
  }) {
    if (_rpc == null) init();
    if (_rpc == null) return;

    try {
      String safeTitle = title.length < 2 ? "$title  " : title;
      String safeSub = subTitle.length < 2 ? "$subTitle " : subTitle;

      _rpc!.updatePresence(
        DiscordPresence(
          details: safeTitle,
          state: safeSub,
          // 🔥🔥🔥 修正：必须是 startTimeStamp (注意大写 S)
          startTimeStamp: isPlaying && startTimeEpoch != null
              ? startTimeEpoch
              : null,
          largeImageKey: 'logo',
          largeImageText: "Kazumi Player",
          smallImageKey: isPlaying ? 'play' : 'pause',
          smallImageText: isPlaying ? 'Playing' : 'Paused',
        ),
      );
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
  }
}