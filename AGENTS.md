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
- 个人文档/规则变更只提交到 fork：从 `origin/main` 创建独立分支，不要混入 upstream PR。

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
