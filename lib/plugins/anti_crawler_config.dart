/// 反反爬虫验证类型
///
/// - [imageCaptcha] (1): WebView 抓取验证码图片，引导用户手动输入后提交
/// - [autoClickButton] (2): WebView 检测到验证按钮后自动点击，无需用户交互
///
/// 保留整数表示以便将来新增第三种及更多验证方式时向后兼容。
class CaptchaType {
  static const int imageCaptcha = 1;
  static const int autoClickButton = 2;
}

/// 反反爬虫配置
///
/// 当网站对搜索请求返回验证码时，使用 WebView 加载搜索页，
/// 根据 [captchaType] 采用不同策略完成验证，之后保存 Cookie 用于后续请求。
class AntiCrawlerConfig {
  /// 是否启用反反爬虫功能
  bool enabled;

  /// 验证类型，见 [CaptchaType] 中的常量
  ///
  /// - [CaptchaType.imageCaptcha] (1)：图片验证码，需要用户手动输入
  /// - [CaptchaType.autoClickButton] (2)：自动点击验证按钮，无需用户交互
  int captchaType;

  /// 验证码图片元素的 XPath 选择器（仅 captchaType == 1 时使用）
  /// 用于在 WebView 页面中定位验证码图片，通过 Canvas 抓取其像素
  String captchaImage;

  /// 验证码输入框元素的 XPath 选择器（仅 captchaType == 1 时使用）
  /// 用于在 WebView 页面中定位供用户输入验证码的 input 元素
  String captchaInput;

  /// 验证按钮元素的 XPath 选择器
  ///
  /// - captchaType == 1：提交验证码的按钮，模拟点击提交
  /// - captchaType == 2：目标验证按钮（如"我不是机器人"），检测到后自动点击
  String captchaButton;

  AntiCrawlerConfig({
    required this.enabled,
    required this.captchaType,
    required this.captchaImage,
    required this.captchaInput,
    required this.captchaButton,
  });

  factory AntiCrawlerConfig.fromJson(Map<String, dynamic> json) {
    return AntiCrawlerConfig(
      enabled: json['enabled'] ?? false,
      captchaType: json['captchaType'] ?? CaptchaType.imageCaptcha,
      captchaImage: json['captchaImage'] ?? '',
      captchaInput: json['captchaInput'] ?? '',
      captchaButton: json['captchaButton'] ?? '',
    );
  }

  factory AntiCrawlerConfig.empty() {
    return AntiCrawlerConfig(
      enabled: false,
      captchaType: CaptchaType.imageCaptcha,
      captchaImage: '',
      captchaInput: '',
      captchaButton: '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'enabled': enabled,
      'captchaType': captchaType,
      'captchaImage': captchaImage,
      'captchaInput': captchaInput,
      'captchaButton': captchaButton,
    };
  }

  AntiCrawlerConfig copyWith({
    bool? enabled,
    int? captchaType,
    String? captchaImage,
    String? captchaInput,
    String? captchaButton,
  }) {
    return AntiCrawlerConfig(
      enabled: enabled ?? this.enabled,
      captchaType: captchaType ?? this.captchaType,
      captchaImage: captchaImage ?? this.captchaImage,
      captchaInput: captchaInput ?? this.captchaInput,
      captchaButton: captchaButton ?? this.captchaButton,
    );
  }
}
