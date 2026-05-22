import 'package:kazumi/lan/web/web_app_script.dart';
import 'package:kazumi/lan/web/web_player_script.dart';
import 'package:kazumi/lan/web/web_styles.dart';

/// HTML 主壳。CSS / app JS / player JS 拆到 `lib/lan/web/*` 三个独立常量，
/// 在这里拼接。/api/theme 由 `applyTheme()`（app_script 内）消费，启动时拉
/// 一次 + visibilitychange 惰性刷新；初始 `:root` CSS 变量值在 web_styles.dart
/// 提供，仅作为远端拉取失败时的兜底。
final String lanWebIndexHtml = '''
<!DOCTYPE html>
<html lang="zh" data-theme="auto">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
  <meta name="apple-mobile-web-app-capable" content="yes">
  <meta name="format-detection" content="telephone=no">
  <title>Kazumi</title>
  <style>
$lanWebCss
  </style>
</head>
<body>
  <div class="layout">
    <nav class="nav-rail" id="nav-rail"></nav>
    <main class="content" id="app"></main>
  </div>
  <script>
$lanWebAppJs

$lanWebPlayerJs
  </script>
</body>
</html>
''';
