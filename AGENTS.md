# Agent 指令

## 项目范围
- 此检出目录是 Kazumi 的个人 fork。
- `AGENTS.md` 和本地 `docs/` 文件只保留在这个 fork 中。
- 除非上游明确要求，不要把 `AGENTS.md` 或本地 `docs/` 文件放进 upstream PR。

## 远程与 PR 目标
- 默认目标：个人 fork 的 `origin/main`。
- 上游 PR 目标：通过 `upstream` 提交到 `Predidit/Kazumi` 的 `main` 分支。
- 准备 upstream PR 前，先阅读并遵循 `docs/upstream-pr-rules.md`。
- upstream PR 分支必须从 `upstream/main` 创建，并且只暂存明确路径。
- upstream PR 中排除 `AGENTS.md`、`docs/`、日志、临时文件和无关的 `pubspec.lock` 变更。

## 命令
使用 PATH 中的本机 `flutter`；版本必须满足 `pubspec.yaml` 的 `environment.flutter`。

| 任务 | PowerShell 命令 |
|------|-----------------|
| 安装依赖 | `flutter pub get` |
| 静态分析 | `flutter analyze --no-fatal-infos --fatal-warnings` |
| 运行全部测试 | `flutter test` |
| 运行单个测试文件 | `flutter test test/search_parser_test.dart` |
| 运行 Windows 应用 | `flutter run -d windows` |
| 重新生成 Dart 文件 | `dart run build_runner build --delete-conflicting-outputs` |

## 外部引用
| 需求 | 文件 |
|------|------|
| 上游 PR 流程 | `docs/upstream-pr-rules.md` |
| 测试规则 | `docs/test-rule.md` |
| CI 命令 | `.github/workflows/pr.yaml` |
| BBCode 语法流程 | `lib/bbcode/README.md` |

## 关键约定
- 优先使用可直接在 PowerShell 中运行的命令。
- 暂存前运行 `git status --short`。
- 只读取与当前任务相关的文档。
- 新增或修改测试前，阅读 `docs/test-rule.md`；除非该规则变化，不要新增 widget 测试。
- 通过 `build_runner` 更新 MobX/Hive 生成的 `.g.dart` 文件；不要手动编辑它们。
- 修改 BBCode 语法时，按 `lib/bbcode/README.md` 更新 `assets/bbcode/BBCode.g4` 和生成的 parser 文件。

## Cursor Cloud specific instructions

云端 VM 已预装 Flutter `3.44.3` SDK（位于 `~/flutter`，已加入 `~/.bashrc` 的 `PATH`）。启动时的 update script 仅运行 `flutter pub get`。命令（lint / test / run）与上文“命令”表一致，只是直接在 bash 中执行（不是 PowerShell）。

运行的产品就是 Kazumi 桌面 GUI 应用本身，没有需要单独启动的后端服务；所有番剧数据来自远程 API（Bangumi `api.bgm.tv`、KazumiRules 等），需要联网。

在本无显示器 VM 中运行桌面应用的注意事项（非显而易见）：

- 用 `DISPLAY=:1 flutter run -d linux` 在 VNC 桌面上运行（`:1` 是 TigerVNC 提供的显示器）。
- 必须配置 XDG 用户目录，否则启动失败：`Hive.initFlutter()` 会调用 `getApplicationDocumentsDirectory()`，在 Linux 上依赖 `xdg-user-dir`。若缺失，存储初始化抛 `MissingPlatformDirectoryException`，应用只显示 `StorageErrorPage`（见 `lib/main.dart`）。修复：安装 `xdg-user-dirs` 并运行 `xdg-user-dirs-update`（快照已包含；若再次出现存储错误页，先跑 `xdg-user-dirs-update`）。
- 启动时会弹出 “X11环境检测” 对话框（因为运行在 X11/VNC 下），点 “继续”；随后的免责声明点 “已阅读并同意” 即可进入主界面。
- 以下日志为无害噪音，可忽略：ALSA `cannot find card`（VM 无声卡）、`libEGL ... DRI3`（软件渲染回退）、`flutter_volume_controller ... Can't attach card to mixer`。
- 桌面构建所需系统库（GTK/mpv/webkit/clang/ninja 等）已装入快照；clang 链接还需要 `libstdc++-14-dev`（clang 默认选 GCC 14 工具链）。
- 自动化测试与静态分析（`flutter test` / `flutter analyze`）无需上述桌面系统库，只需 `flutter pub get`。
