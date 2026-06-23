# AGENTS.md

## 项目背景

此检出目录是 Kazumi 的个人 fork。`AGENTS.md` 这类个人工作流文件，以及
`docs/` 下的本地文档，可以保留在这个 fork 中，但除非上游项目明确要求，
否则不得包含在发送给上游仓库的拉取请求中。

## 上游拉取请求规则

在为主仓库准备任何变更之前，阅读并遵循 `docs/upstream-pr-rules.md`。

默认上游目标是：

- 远程：`upstream`
- 仓库：`Predidit/Kazumi`
- 基准分支：`main`

对于上游拉取请求，请从 `upstream/main` 创建干净的 PR 分支，并且只暂存属于
实际 bug 修复或功能变更的文件。不要包含：

- `AGENTS.md`
- `docs/`
- 本地日志
- 偶然产生的 lockfile 或工具链变更，除非这些变更是修复所必需的

推送前使用 `git diff --name-status upstream/main...HEAD`。如果输出中出现
`AGENTS.md` 或 `docs/` 下的文件，说明该分支还不够干净，不能用于上游拉取请求。

## 本地工作流

优先使用可直接在 PowerShell 中运行的命令。暂存前用 `git status --short`
检查工作区；准备 PR 分支时，使用明确的路径暂存文件，而不是 `git add .`。

当变更影响 Flutter 依赖或生成的 lockfile 时，在将其纳入上游 PR 之前，
说明为什么该 lockfile 变更是必要的。
