# CLAUDE.md

本文件为 Claude Code (claude.ai/code) 在此仓库中工作时提供指导。

## 项目概述

Kazumi 是一个基于 Flutter 的动漫（番剧）聚合与在线观看应用。它使用社区编写的 XPath 规则（每条规则最多 5 个选择器）从各种网站抓取动漫内容。跨平台：Android 10+、Windows 10+、macOS 10.15+、iOS 13+、Linux（实验性）。

- **语言**：中文（UI、注释、文档）。许可证：GPL-3.0。
- **Flutter SDK**：3.44.1 stable。**Dart SDK**：`>=3.3.4 <4.0.0`。

## 构建与开发命令

```bash
# 获取依赖
flutter pub get

# 开发模式运行
flutter run

# 代码生成（修改 MobX store 或 Hive 模型后必须执行）
dart run build_runner build --delete-conflicting-outputs

# 静态分析（info 不致命，warning 致命）
flutter analyze --no-fatal-infos --fatal-warnings

# 运行全部测试
flutter test

# 运行单个测试文件
flutter test test/m3u8_parser_test.dart

# 生产构建（需要通过 --dart-define 传入 API 密钥）
flutter build apk --split-per-abi \
  --dart-define=DANDANAPI_APPID=... \
  --dart-define=DANDANAPI_KEY=... \
  --dart-define=KAZUMI_APPID=... \
  --dart-define=KAZUMI_KEY=...
```

`--dart-define` 变量 `DANDANAPI_APPID`、`DANDANAPI_KEY`、`KAZUMI_APPID`、`KAZUMI_KEY` 是生产构建所必需的。

`analysis_options.yaml` 启用了 `avoid_print: true`——所有调试输出必须通过 `KazumiLogger`。

## 架构

### 分层结构

```
Pages（UI + MobX 控制器）
  → Services（业务逻辑）
    → Repositories（数据访问抽象）
      → Request 层（Dio HTTP 客户端） + Storage 层（GStorage）
```

### 路由与依赖注入

**flutter_modular** 同时提供路由和 DI：

- `AppModule`（顶层）→ `IndexModule`（`lib/pages/index_module.dart`）注册所有单例。
- 4 个 Tab 的底部导航：`/popular`、`/timeline`、`/collect`、`/my`。
- 其他页面注册为子路由（`/video`、`/info`、`/settings`、`/search`、`/player` 等）。

**注意**：当前 DI 实际是 Service Locator 模式——Controller 内部通过 `Modular.get<T>()` 抓取依赖，而非构造注入。这导致 Controller 难以单元测试。逐步迁移到构造注入是已知改进方向。

### 状态管理

- **MobX**（`flutter_mobx` + `mobx_codegen`）：页面级响应式状态。`@observable` + `@action`，生成 `.g.dart`。
- **Provider**：仅用于 `ThemeProvider`。
- **Hive CE**：所有持久化数据。通过 `GStorage`（`lib/services/storage/storage.dart`）统一读写。

### 存储层（GStorage）

`GStorage` 是静态 facade，提供 `getSetting<T>(key)` / `putSetting<T>(key, value)`。设置类型定义和 key 常量在 `lib/services/storage/settings_keys.dart`。

`storage.dart` 通过 `export` 将 `settings_keys.dart` 的符号转发给调用方——文件只需 `import 'package:kazumi/services/storage/storage.dart'` 即可同时访问 `GStorage`、`SettingsKeys`、`SettingGroup`。

**敏感数据**：`bangumiAccessToken` 和 `webDavPassword` 在 `GStorage` 内部路由到 `FlutterSecureStorage`（平台加密存储），并在 `init()` 中执行一次性明文 Hive → 安全存储迁移。其他 key 继续走 Hive。新增敏感 key 只需将 key name 加入 `_secureKeys` 集合。

### API 层与 Result 模式

`lib/request/apis/bangumi_api.dart` 中有 11 个方法返回 `Result<T>`（定义在 `lib/request/apis/bangumi_result.dart`，通过 `bangumi_api.dart` 的 `export` 转发）：

```dart
sealed class Result<T> {}
final class Success<T> extends Result<T> { final T value; }
final class Failure<T> extends Result<T> { final Object error; }
```

调用方必须用模式匹配处理两种结果——编译器穷尽性检查强制这一点：
```dart
switch (await BangumiApi.getCalendar()) {
  case Success(:final value): // 使用 value
  case Failure(:final error): // 处理错误
}
```

其余 API 方法（评论、staff、characters、收藏写入）保持抛异常或返回 `bool`，不需 `Result` 包装。

`bangumi_api.dart` 中的 `Result<T>` 通过 `export` 转发——调用方只需 `import 'bangumi_api.dart'`，不需要单独导入 `bangumi_result.dart`。

### 网络层

- **Dio** HTTP 客户端，支持 Cookie Jar、代理。
- `NetworkConfig.fromSettings()` 从 `GStorage` 读取代理和 TLS 设置。
- `allowBadCertificates` 默认 `false`（用户可在设置 → 代理中开启，用于自签名证书的代理服务器）。

### 日志

使用 `KazumiLogger`（`lib/services/logging/logger.dart`）——单例，六级（trace/debug/info/warning/error/fatal）。warning+ 级别写入文件 `kazumi_logs.log`。日志轮转：5MB 上限，保留 3 个轮转文件。

**禁止使用 `print()`**——`analysis_options.yaml` 已启用 `avoid_print: true`。

### 关键依赖

- **media-kit**（fork）：跨平台视频播放，所有平台库来自 `github.com/Predidit/media-kit`。
- **xpath_selector**：规则引擎核心，解析 JSON 规则文件中的 XPath 选择器。
- **canvas_danmaku**：弹幕渲染（弹弹 Play API）。
- **flutter_secure_storage**：平台加密存储（Keychain/DPAPI/EncryptedSharedPreferences）。
- **ANTLR4**：BBCode 解析（`assets/bbcode/`）。

### 目录用途

| 目录 | 用途 |
|------|------|
| `lib/pages/` | Flutter 页面，每个含 Module + MobX 控制器 + page widget |
| `lib/bean/` | 可复用 UI 组件（AppBar、卡片、对话框、ThemeProvider） |
| `lib/services/` | 业务逻辑：下载、播放器、同步、代理、存储、日志、更新 |
| `lib/repositories/` | 数据访问接口 + Hive 实现 |
| `lib/modules/` | 领域模型，Hive 注解（生成 `.g.dart`） |
| `lib/request/` | Dio 客户端、API 端点、`Result<T>` 类型 |
| `lib/plugins/` | XPath 规则引擎、反爬虫配置 |
| `lib/utils/` | 工具函数 |
| `assets/shaders/` | Anime4K GLSL 着色器 |
| `assets/plugins/` | 内置规则文件（JSON） |

### 代码生成

修改含 `@HiveType`、`@observable`、`@action`、`@computed` 的文件后必须运行：
```bash
dart run build_runner build --delete-conflicting-outputs
```

`*.g.dart`、`*.freezed.dart`、`lib/bbcode/generated/` 被 `analysis_options.yaml` 排除。

## 已知技术债

- **`lib/pages/player/player_item.dart`**：~2027 行，单体 Widget 混合了键盘、手势、弹幕、SyncPlay、画中画逻辑。是项目最大文件。拆分方案已设计（7 个 handler），需在 DI 改造和测试安全网铺好后执行。
- **DI**：`Modular.get<T>()` 在 50+ 文件中被调用，属于 Service Locator 而非构造注入，导致 Controller 不可测试。
- **测试覆盖**：仅 5 个测试文件，覆盖解析器和同步逻辑。Controller、Widget、API 层均无测试。
- **文件大小**：除 `player_item.dart` 外，`player_item_panel.dart`（~1370 行）、`video_page.dart`（~1258 行）也需要拆分。

## 已有测试

```
test/collect_sync_test.dart      — 收藏同步合并逻辑
test/history_sync_test.dart      — 观看历史同步合并逻辑
test/m3u8_parser_test.dart       — M3U8 播放列表解析（主播放列表、媒体播放列表、VOD 检测、嵌套）
test/search_parser_test.dart     — 搜索语法解析（标签、排序、ID）
test/widget_test.dart            — 基础冒烟测试
```
