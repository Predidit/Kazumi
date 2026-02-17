import 'package:discord_rpc/discord_rpc.dart';
import 'package:kazumi/utils/storage.dart';

class DiscordRpcManager {
  static DiscordRPC? _rpc;
  static String? _currentAppId;

  // 初始化
  static void init() {
    try {
      final setting = GStorage.setting;
      // 默認關閉，你需要去設置裡開啟或者在這裡改成 true 進行測試
      final bool enable = setting.get(SettingBoxKey.discordRpcEnable, defaultValue: false);
      final String? clientId = setting.get(SettingBoxKey.discordClientId);

      if (!enable || clientId == null || clientId.isEmpty) {
        clear();
        return;
      }

      // 如果 Client ID 變更，重啟服務
      if (_rpc != null && _currentAppId != clientId) {
        _rpc!.shutDown();
        _rpc = null;
      }

      if (_rpc == null) {
        _rpc = DiscordRPC(applicationId: clientId);
        _rpc!.start(autoRegister: true);
        _currentAppId = clientId;
      }
    } catch (_) {}
  }

  // 更新狀態 (支持 int 類型的集數)
  static void updatePresence({
    required String animeTitle,
    required int episode,
    required bool isPlaying,
    int? remainingSeconds,
  }) {
    // 二次檢查開關
    if (!GStorage.setting.get(SettingBoxKey.discordRpcEnable, defaultValue: false)) return;
    
    if (_rpc == null) init();

    if (_rpc != null) {
      _rpc!.updatePresence(
        DiscordPresence(
          details: animeTitle,
          state: "第 $episode 集", // 自動將 int 轉為 String
          // 如果正在播放，顯示剩餘時間倒計時
          endTimeStamp: isPlaying && remainingSeconds != null
              ? DateTime.now().millisecondsSinceEpoch + (remainingSeconds * 1000)
              : null,
          largeImageKey: 'logo', // 需在 Discord 開發者後台配置
          largeImageText: "Kazumi Player",
          smallImageKey: isPlaying ? 'play' : 'pause',
          smallImageText: isPlaying ? 'Playing' : 'Paused',
        ),
      );
    }
  }

  // 清理
  static void clear() {
    try {
      _rpc?.clearPresence();
      _rpc?.shutDown();
    } catch (_) {}
    _rpc = null;
    _currentAppId = null;
  }
}