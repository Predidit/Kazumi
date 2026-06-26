# Upstream PR 推送规则

这份规则用于从个人 fork 向主仓库 `Predidit/Kazumi` 提交修改，同时保留个人
fork 中的 `AGENTS.md` 和 `docs/` 文档。

## 目标区分

日常默认工作目标是个人 fork 的 `origin/main`。只有在需要向主仓库提交 PR 时，
才使用本文件的上游 PR 流程。

主仓库 PR 目标是：

- 远程：`upstream`
- 仓库：`Predidit/Kazumi`
- 基准分支：`main`

## 核心原则

给主仓库提交 PR 的分支必须从 `upstream/main` 创建。不要从包含个人文档、
本地规则或实验性文件的 fork 分支直接发起 PR。

主仓库 PR 只应包含实际 bug 修复或功能变更需要的文件。`AGENTS.md` 和
`docs/` 是个人 fork 的工作流文件，默认不进入主仓库 PR。

个人文档、规则或 agent 流程更新必须单独提交到 fork 分支，并以 `origin/main`
为基准。不要把这些文件和准备提交到主仓库的代码变更放在同一个 PR 分支里。



PR 必须是 草稿

PR 使用中文描述

## 推荐流程

先同步主仓库：

```powershell
git fetch upstream
git switch -c fix/your-change upstream/main
```

然后只把真正需要提交给主仓库的文件拿到干净分支里：

```powershell
git restore --source your-personal-branch -- lib/path/file.dart
git restore --source your-personal-branch -- test/path/file_test.dart
```

检查分支内容：

```powershell
git status --short
git diff --name-status upstream/main...HEAD
```

确认没有个人文档后再提交：

```powershell
git add lib/path/file.dart test/path/file_test.dart
git diff --cached --check
git commit -m "### Fix：简要说明修复内容"
git push origin fix/your-change
```

创建 PR：

```powershell
gh pr create --repo Predidit/Kazumi --base main --head liangyuR:fix/your-change
```

## 个人文档进入 fork 的流程

当需要固化 `AGENTS.md`、`docs/` 或其它只属于个人 fork 的说明时，使用单独分支：

```powershell
git fetch origin main
git switch -c docs/your-rule origin/main
```

只暂存文档路径：

```powershell
git add AGENTS.md docs/upstream-pr-rules.md
git diff --cached --name-status
git commit -m "docs: update fork workflow rules"
git push origin docs/your-rule
```

创建到个人 fork `main` 的 PR。不要把这个分支作为 `Predidit/Kazumi` 的 upstream
PR head。

## 已在脏分支上开发时

如果代码已经写在一个包含 `AGENTS.md`、`docs/` 或其它个人文件的分支上，不要
直接推这个分支。重新从 `upstream/main` 创建干净分支，并按文件选择性恢复：

```powershell
git fetch upstream
git switch -c fix/clean-pr upstream/main
git restore --source old-branch-name -- lib/path/file.dart
git restore --source old-branch-name -- test/path/file_test.dart
```

然后重新检查、提交和推送。

## 禁止做法

不要用 `git add .` 准备 upstream PR，除非已经明确检查过所有新增和修改文件。

不要依赖 `.gitignore` 或 `.git/info/exclude` 隐藏已经提交到 PR 分支里的个人
文档。PR 展示的是分支相对 `upstream/main` 的提交差异，只要这些文件存在于
PR 分支历史中，就会进入 PR。

不要把错误日志、临时调试输出、IDE 配置或无关 lockfile 变更带入 PR。

## 推送前检查清单

运行：

```powershell
git diff --name-status upstream/main...HEAD
```

确认输出中没有：

- `AGENTS.md`
- `docs/`
- 错误日志或临时文件
- 无关的 `pubspec.lock` 变更

如果需要包含 `pubspec.lock`，PR 描述里必须说明它和本次代码变更的关系。

如果是个人文档 PR，改用：

```powershell
git diff --name-status origin/main...HEAD
```

确认输出只包含 `AGENTS.md`、`docs/` 或其它明确属于 fork 工作流的文档。