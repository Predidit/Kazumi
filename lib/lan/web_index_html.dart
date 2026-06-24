/// HTML 主壳。CSS / app JS / player JS 作为独立静态资源文件存放在
/// `assets/lan_web/`，由 `_handleAsset` 通过 `/assets/<file>` 路由 serve。
///
/// 这里只生成 HTML 骨架，通过 `<link>` 和 `<script src>` 引用外部文件，
/// 让 JS/CSS 能享受编辑器的原生 LSP 支持（语法高亮、错误检查、自动补全）。
const String lanWebIndexHtml = '''
<!DOCTYPE html>
<html lang="zh" data-theme="auto">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
  <meta name="apple-mobile-web-app-capable" content="yes">
  <meta name="format-detection" content="telephone=no">
  <title>Kazumi</title>
  <link rel="stylesheet" href="/assets/styles.css">
</head>
<body>
  <div class="layout">
    <nav class="nav-rail" id="nav-rail"></nav>
    <main class="content" id="app"></main>
  </div>
  <script src="/assets/app.js"></script>
  <script src="/assets/player.js"></script>
</body>
</html>
''';
