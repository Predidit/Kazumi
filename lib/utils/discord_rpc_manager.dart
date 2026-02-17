import 'package:discord_rpc/discord_rpc.dart';

class DiscordRpcManager {
  static DiscordRPC? _rpc;
  static bool _isNativeInitialized = false; // 防止重複加載原生庫導致崩潰

  // 🔴🔴🔴【重要】請在此填入你的 Application ID (純數字字符串) 🔴🔴🔴
  static const String _appId = "1473047818498216028"; 

  /// 初始化 RPC 服務
  static void init() {
    try {
      if (_rpc != null) return;

      // 1. 安全加載原生庫 (整個 App 生命周期只能執行一次)
      if (!_isNativeInitialized) {
        try {
          DiscordRPC.initialize();
          _isNativeInitialized = true;
        } catch (_) {
          // 如果報錯"Already initialized"，說明已經加載過了，忽略即可
          _isNativeInitialized = true;
        }
      }

      // 2. 創建實例並啟動
      _rpc = DiscordRPC(applicationId: _appId);
      _rpc?.start(autoRegister: true);
      
      print('🔥🔥🔥 [RPC] 服務已啟動');
    } catch (e) {
      print('🔥🔥🔥 [RPC] 初始化失敗: $e');
      _rpc = null; 
    }
  }

  /// 更新狀態核心方法
  static void updatePresence({
    required String title,      // 第一行：視頻源標題
    required String subTitle,   // 第二行：集數
    required bool isPlaying,    // 播放狀態
    int? startTimeEpoch,        // 開始播放的時間戳 (用於顯示 "已播放 xx:xx")
  }) {
    // 如果服務未啟動，嘗試啟動
    if (_rpc == null) init();
    
    // 如果還是空，說明初始化徹底失敗，直接返回防止報錯
    if (_rpc == null) return;

    try {
      // Discord 規則保護：字段長度必須 >= 2 字符
      String safeTitle = title.length < 2 ? "$title  " : title;
      String safeSub = subTitle.length < 2 ? "$subTitle " : subTitle;

      _rpc!.updatePresence(
        DiscordPresence(
          details: safeTitle,
          state: safeSub,
          
          // 🔥 核心時間邏輯：
          // 傳入 "開始播放的時間點"，Discord 會自動計算 "CurrentTime - StartTime"
          // 這樣無論怎麼拖動進度條，顯示的 "已播放時長" 都是平滑準確的
          startTimeStamp: isPlaying && startTimeEpoch != null
              ? startTimeEpoch
              : null,
          
          // 圖片資源 (必須與 Developer Portal 上傳的一致)
          largeImageKey: 'logo',
          largeImageText: "Kazumi Player",
          smallImageKey: isPlaying ? 'play' : 'pause',
          smallImageText: isPlaying ? 'Playing' : 'Paused',
        ),
      );
    } catch (e) {
      print('❌ [RPC] 發送異常: $e');
    }
  }

  /// 清理資源
  static void clear() {
    try {
      _rpc?.clearPresence();
      _rpc?.shutDown();
    } catch (_) {}
    _rpc = null;
    // 注意：不要把 _isNativeInitialized 設為 false，原生庫加載一次就夠了
  }
}