# AGENTS.md

## 项目背景

此检出目录是 Kazumi 的个人 fork。`AGENTS.md` 这类个人工作流文件，以及
`docs/` 下的本地文档，可以保留在这个 fork 中，但除非上游项目明确要求，
否则不得包含在发送给上游仓库的拉取请求中。

## 默认远程与上游拉取请求规则

默认工作目标是个人 fork：

- 远程：`origin`
- 仓库：个人 fork
- 基准分支：`main`

只有在需要向主仓库 `Predidit/Kazumi` 提交 PR 时，才切换到上游 PR 流程。
在为主仓库准备任何变更之前，阅读并遵循 `docs/upstream-pr-rules.md`。

## 本地工作流

优先使用可直接在 PowerShell 中运行的命令。暂存前用 `git status --short`
检查工作区；准备 PR 分支时，使用明确的路径暂存文件，而不是 `git add .`。

当变更影响 Flutter 依赖或生成的 lockfile 时，在将其纳入上游 PR 之前，
说明为什么该 lockfile 变更是必要的。
