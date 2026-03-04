/// 反反爬虫配置
///
/// 当网站对搜索请求返回验证码时，使用 WebView 加载搜索页，
/// 检测验证码图片并引导用户完成验证，之后保存 Cookie 用于后续请求。
class AntiCrawlerConfig {
  /// 是否启用反反爬虫功能
  bool enabled;

  /// 验证码图片元素的 XPath 选择器
  /// 用于在 WebView 页面中定位验证码图片，通过 Canvas 抓取其像素
  String captchaImage;

  /// 验证码输入框元素的 XPath 选择器
  /// 用于在 WebView 页面中定位供用户输入验证码的 input 元素
  String captchaInput;

  /// 验证按钮元素的 XPath 选择器
  /// 用于在 WebView 页面中定位提交验证码的按钮元素，模拟点击
  String captchaButton;

  AntiCrawlerConfig({
    required this.enabled,
    required this.captchaImage,
    required this.captchaInput,
    required this.captchaButton,
  });

  factory AntiCrawlerConfig.fromJson(Map<String, dynamic> json) {
    return AntiCrawlerConfig(
      enabled: json['enabled'] ?? false,
      captchaImage: json['captchaImage'] ?? '',
      captchaInput: json['captchaInput'] ?? '',
      captchaButton: json['captchaButton'] ?? '',
    );
  }

  factory AntiCrawlerConfig.empty() {
    return AntiCrawlerConfig(
      enabled: false,
      captchaImage: '',
      captchaInput: '',
      captchaButton: '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'enabled': enabled,
      'captchaImage': captchaImage,
      'captchaInput': captchaInput,
      'captchaButton': captchaButton,
    };
  }

  AntiCrawlerConfig copyWith({
    bool? enabled,
    String? captchaImage,
    String? captchaInput,
    String? captchaButton,
  }) {
    return AntiCrawlerConfig(
      enabled: enabled ?? this.enabled,
      captchaImage: captchaImage ?? this.captchaImage,
      captchaInput: captchaInput ?? this.captchaInput,
      captchaButton: captchaButton ?? this.captchaButton,
    );
  }
}
