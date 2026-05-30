import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:kazumi/request/config/api_endpoints.dart';

class StyleString {
  static const double cardSpace = 8;
  static const double safeSpace = 12;
  static BorderRadius mdRadius = BorderRadius.circular(10);
  static const Radius imgRadius = Radius.circular(12);
  static const double aspectRatio = 16 / 10;
}

const String customAppFontFamily = "MI_Sans_Regular";

/// Opts into the newer Material progress indicator appearance while Flutter
/// still exposes the compatibility flag.
/// ignore: deprecated_member_use
const ProgressIndicatorThemeData progressIndicatorTheme2024 =
    ProgressIndicatorThemeData(year2023: false);

/// Opts into the newer Material slider appearance while Flutter still exposes
/// the compatibility flag.
/// ignore: deprecated_member_use
const SliderThemeData sliderTheme2024 = SliderThemeData(
  year2023: false,
  showValueIndicator: ShowValueIndicator.onDrag,
);

/// Flutter-managed platform transitions. Route-level Modular transitions should
/// avoid overriding these unless the native page transition is intentionally bypassed.
const PageTransitionsTheme pageTransitionsTheme2024 = PageTransitionsTheme(
  builders: {
    TargetPlatform.android: CupertinoPageTransitionsBuilder(),
    TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
    TargetPlatform.linux: FadeUpwardsPageTransitionsBuilder(),
    TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
    TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
  },
);

/// Layout breakpoint according to google:
/// https://developer.android.com/develop/ui/compose/layouts/adaptive/use-window-size-classes.
///
/// **It's only a suggestion since not every device meet the breakpoint requirement.
/// You need to build layout with some more judgements.**
///
/// Some example device(portrait) width x height:
///
/// * iPhone SE3: 375 x 667
/// * iPhone 16: 393 x 852
/// * iPad Pro 11-inch: 834 x 1210
/// * HW MATE60 Pro: 387.7 x 836.9
/// * OHOS in floating window: 387.7 x 631.7 or 218.1
class LayoutBreakpoint {
  static const Map<String, double> compact = {'width': 600, 'height': 480};
  static const Map<String, double> medium = {'width': 840, 'height': 900};
}

/// 随机UA列表
const List<String> userAgentsList = [
  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/141.0.0.0 Safari/537.36',
  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/136.0.0.0 Safari/537.36',
  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/134.0.0.0 Safari/537.36',
  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/141.0.0.0 Safari/537.36 Edg/141.0.0.0',
  'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:125.0) Gecko/20100101 Firefox/125.0',
  'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Safari/605.1.1',
  'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.1 Safari/605.1.15',
  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/134.0.0.0 Safari/537.36 Edg/134.0.0.0',
  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/136.0.0.0 Safari/537.36 Edg/136.0.0.0',
];

/// 默认 SyncPlay 服务器列表
const List<String> defaultSyncPlayEndPoints = [
  'syncplay.pl:8995',
  'syncplay.pl:8996',
  'syncplay.pl:8997',
  'syncplay.pl:8998',
  'syncplay.pl:8999',
];

const String defaultSyncPlayEndPoint = 'syncplay.pl:8996';

/// 随机HTTP请求头accept-language字段列表
const List<String> acceptLanguageList = [
  'zh-CN,zh;q=0.9',
  'zh-CN,zh;q=0.9,en;q=0.8,en-GB;q=0.7,en-US;q=0.6',
  'zh-CN,zh-TW;q=0.9,zh;q=0.8,en-US;q=0.7,en;q=0.6',
];

/// Bangumi API 文档要求的UA格式
Map<String, String> bangumiHTTPHeader = {
  'user-agent':
      'Predidit/Kazumi/${ApiEndpoints.version} (Android) (https://github.com/Predidit/Kazumi)',
  'referer': '',
  'content-type': 'application/json'
};

/// 可选硬件解码器
const Map<String, String> hardwareDecodersList = {
  'auto': 'Enable any available decoder',
  'auto-safe': 'Enable the best decoder',
  'auto-copy': 'Enable the best decoder with copy support',
  'd3d11va': 'DirectX11 (Windows 8 and above)',
  'd3d11va-copy': 'DirectX11 (Windows 8 and above) (non-passthrough)',
  'videotoolbox': 'VideoToolbox (macOS / iOS)',
  'videotoolbox-copy': 'VideoToolbox (macOS / iOS) (non-passthrough)',
  'vaapi': 'VAAPI (Linux)',
  'vaapi-copy': 'VAAPI (Linux) (non-passthrough)',
  'nvdec': 'NVDEC (NVIDIA only)',
  'nvdec-copy': 'NVDEC (NVIDIA only) (non-passthrough)',
  'drm': 'DRM (Linux)',
  'drm-copy': 'DRM (Linux) (non-passthrough)',
  'vulkan': 'Vulkan (all platforms) (experimental)',
  'vulkan-copy': 'Vulkan (all platforms) (experimental) (non-passthrough)',
  'dxva2': 'DXVA2 (Windows 7 and above)',
  'dxva2-copy': 'DXVA2 (Windows 7 and above) (non-passthrough)',
  'vdpau': 'VDPAU (Linux)',
  'vdpau-copy': 'VDPAU (Linux) (non-passthrough)',
  'mediacodec': 'MediaCodec (Android)',
  'mediacodec-copy': 'MediaCodec (Android) (non-passthrough)',
  'cuda': 'CUDA (NVIDIA only) (deprecated)',
  'cuda-copy': 'CUDA (NVIDIA only) (deprecated) (non-passthrough)',
  'crystalhd': 'CrystalHD (all platforms) (deprecated)',
  'rkmpp': 'Rockchip MPP (only some Rockchip chips)',
};

/// Android 可选视频渲染器
const Map<String, String> androidVideoRenderersList = {
  'auto': 'Auto select',
  'gpu': 'OpenGL-based, a general and robust option',
  'gpu-next': 'Vulkan-based, performs best on newer devices',
  'mediacodec_embed': 'Lowest power usage, does not support super resolution',
};

/// 超分辨率滤镜
const List<String> mpvAnime4KShaders = [
  'Anime4K_Clamp_Highlights.glsl',
  'Anime4K_Restore_CNN_VL.glsl',
  'Anime4K_Upscale_CNN_x2_VL.glsl',
  'Anime4K_AutoDownscalePre_x2.glsl',
  'Anime4K_AutoDownscalePre_x4.glsl',
  'Anime4K_Upscale_CNN_x2_M.glsl'
];

/// 超分辨率滤镜 (轻量)
const List<String> mpvAnime4KShadersLite = [
  'Anime4K_Clamp_Highlights.glsl',
  'Anime4K_Restore_CNN_M.glsl',
  'Anime4K_Restore_CNN_S.glsl',
  'Anime4K_Upscale_CNN_x2_M.glsl',
  'Anime4K_AutoDownscalePre_x2.glsl',
  'Anime4K_AutoDownscalePre_x4.glsl',
  'Anime4K_Upscale_CNN_x2_S.glsl'
];

/// 可选播放倍速
const List<double> defaultPlaySpeedList = [
  0.25,
  0.5,
  0.75,
  1.0,
  1.25,
  1.5,
  1.75,
  2.0,
  2.25,
  2.5,
  2.75,
  3.0,
];

const String danmakuOnSvg = '''
    <svg xmlns="http://www.w3.org/2000/svg" data-pointer="none" viewBox="0 0 24 24">
      <path fill="#FFFFFF" fill-rule="evenodd" d="M11.989 4.828c-.47 0-.975.004-1.515.012l-1.71-2.566a1.008 1.008 0 0 0-1.678 1.118l.999 1.5c-.681.018-1.403.04-2.164.068a4.013 4.013 0 0 0-3.83 3.44c-.165 1.15-.245 2.545-.245 4.185 0 1.965.115 3.67.35 5.116a4.012 4.012 0 0 0 3.763 3.363l.906.046c1.205.063 1.808.095 3.607.095a.988.988 0 0 0 0-1.975c-1.758 0-2.339-.03-3.501-.092l-.915-.047a2.037 2.037 0 0 1-1.91-1.708c-.216-1.324-.325-2.924-.325-4.798 0-1.563.076-2.864.225-3.904.14-.977.96-1.713 1.945-1.747 2.444-.087 4.465-.13 6.063-.131 1.598 0 3.62.044 6.064.13.96.034 1.71.81 1.855 1.814.075.524.113 1.962.141 3.065v.002c.01.342.017.65.025.88a.987.987 0 1 0 1.974-.068c-.008-.226-.016-.523-.025-.856v-.027c-.03-1.118-.073-2.663-.16-3.276-.273-1.906-1.783-3.438-3.74-3.507-.9-.032-1.743-.058-2.531-.078l1.05-1.46a1.008 1.008 0 0 0-1.638-1.177l-1.862 2.59c-.38-.004-.744-.007-1.088-.007h-.13Zm.521 4.775h-1.32v4.631h2.222v.847h-2.618v1.078h2.618l.003.678c.36.026.714.163 1.01.407h.11v-1.085h2.694v-1.078h-2.695v-.847H16.8v-4.63h-1.276a8.59 8.59 0 0 0 .748-1.42L15.183 7.8a14.232 14.232 0 0 1-.814 1.804h-1.518l.693-.308a8.862 8.862 0 0 0-.814-1.408l-1.045.352c.297.396.572.847.825 1.364Zm-4.18 3.564.154-1.485h1.98V8.294h-3.2v.98H9.33v1.43H7.472l-.308 3.453h2.277c0 1.166-.044 1.925-.12 2.277-.078.352-.386.528-.936.528-.308 0-.616-.022-.902-.055l.297 1.067.062.005c.285.02.551.04.818.04 1.001-.067 1.562-.419 1.694-1.057.11-.638.176-1.903.176-3.795h-2.2Zm7.458.11v-.858h-1.254v.858h1.254Zm-2.376-.858v.858h-1.199v-.858h1.2Zm-1.199-.946h1.2v-.902h-1.2v.902Zm2.321 0v-.902h1.254v.902h-1.254Z" clip-rule="evenodd"/>
      <path fill="#00AEEC" fill-rule="evenodd" d="M22.846 14.627a1 1 0 0 0-1.412.075l-5.091 5.703-2.216-2.275-.097-.086-.008-.005a1 1 0 0 0-1.322 1.493l2.963 3.041.093.083.007.005a1 1 0 0 0 1.354-.124l5.81-6.505.08-.102.005-.008a1 1 0 0 0-.166-1.295Z" clip-rule="evenodd"/>
    </svg>
    ''';

/// 可选默认视频比例
const Map<int, String> aspectRatioTypeMap = {
  1: "Auto",
  2: "Crop to fill",
  3: "Stretch to fill",
};

/// 可选播放器日志等级
/// LogLevel 0: 错误 1: 警告 2: 简略 3: 详细 4: 调试（隐藏） 5: 全部（隐藏）
const Map<int, String> playerLogLevelMap = {
  0: "Error",
  1: "Warning",
  2: "Brief",
  3: "Verbose",
  // 以下两个级别被MPV官方支持，但是输出内容过于冗长，暂时隐藏
  // 4: "调试",
  // 5: "全部",
};

final List<String> defaultAnimeTags = const [
  'Slice of life',
  'Original',
  'School',
  'Comedy',
  'Fantasy',
  'Yuri',
  'Romance',
  'Mystery',
  'Hot-blooded',
  'Harem',
  'Mecha',
  'Light novel adaptation',
  'Idol',
  'Healing',
  'Isekai',
];

// 播放器默认快捷键
final Map<String, List<String>> defaultShortcuts = const {
  'playorpause': [' '],
  'forward': ['Arrow Right'],
  'rewind': ['Arrow Left'],
  'next': ['N'],
  'prev': ['P'],
  'volumeup': ['Arrow Up'],
  'volumedown': ['Arrow Down'],
  'togglemute': ['M'],
  'fullscreen': ['F'],
  'exitfullscreen': ['Escape'],
  'toggledanmaku': ['D'],
  'screenshot': ['S'],
  'skip': ['K'],
  'speed1': ['1'],
  'speed2': ['2'],
  'speed3': ['3'],
  'speedup': ['X'],
  'speeddown': ['Z'],
};

// 键位别名
final Map<String, String> keyAliases = {
  ' ': 'Space',
  'Arrow Up': '↑',
  'Arrow Down': '↓',
  'Arrow Left': '←',
  'Arrow Right': '→',
  'Enter': 'Enter',
  'Tab': 'Tab',
  'Escape': 'Esc',
  'Backspace': 'Backspace',
};

//功能中文名对应
final Map<String, String> shortcutsChineseName = {
  'playorpause': 'Play / Pause',
  'forward': 'Fast forward / long press for speed',
  'rewind': 'Rewind',
  'next': 'Next episode',
  'prev': 'Previous episode',
  'volumeup': 'Volume up',
  'volumedown': 'Volume down',
  'togglemute': 'Mute',
  'fullscreen': 'Fullscreen',
  'exitfullscreen': 'Exit fullscreen',
  'toggledanmaku': 'Toggle danmaku',
  'screenshot': 'Screenshot',
  'skip': 'Skip',
  'speed1': 'Speed: 1x',
  'speed2': 'Speed: 2x',
  'speed3': 'Speed: 3x',
  'speedup': 'Speed up',
  'speeddown': 'Speed down',
};
