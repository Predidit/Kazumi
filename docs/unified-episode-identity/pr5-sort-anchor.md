# PR5 — sortNumber 锚定 Bangumi + 修 bug（统一集数身份模型 5/5）

> 所属规划：全链路统一集数身份模型（增量 / pageUrl 主键）。
> 系列文档：PR1 · PR2 · PR3 · PR4 · PR5（本篇）。

## 总体背景（系列共享）

四个正交维度中，`sortNumber`（真实集号）此前一直靠标题正则 `extractEpisodeNumber`（`lib/utils/media.dart`，`第?(\d+)[话集]?`）猜测，猜不到回退列表位置 —— 这是弹幕/评论对不齐的根因。本 PR 把 `sortNumber` 锚定到 Bangumi 权威 `EpisodeInfo.sort`，并清理一批已知集数语义缺陷，为整个系列收尾。

## 前置依赖

- PR2（`EpisodeRef`）：`sortNumber` 作为 `EpisodeRef` 字段统一供给。
- 与 PR3/PR4 无强耦合，但建议排在最后，基于已统一的身份对象改造。

## 本 PR 范围

1. `EpisodeRef.sortNumber` 锚定 Bangumi `EpisodeInfo.sort`；弹幕/评论改用 `sortNumber`。
2. 顺手修复已知集数相关缺陷。

## 现状

- Bangumi 集信息 `EpisodeInfo`（含 `episode`/`sort`）已通过 episodes API 获取（`BangumiApi.getBangumiEpisodeByID`，按 sort offset）。
- 弹幕：`_danmakuEpisodeForPlayback` 用标题正则，回退 `params.episode`（在线即列表位置）。
- 评论：`commentEpisodeForSelection` 用标题正则，回退列表位置。
- 已知缺陷：
  - 自动连播 toast 使用 `identifier[playingSelection.episode]` 缺 `-1`（`lib/pages/player/player_item.dart`）。
  - SyncPlay 文件 id `"$bangumiId[$currentEpisode]"` 中 `currentEpisode` 在线/离线语义不一致（`lib/pages/player/controller/player_syncplay_controller.dart`、`lib/pages/player/player_controller.dart`）。

## 涉及文件

- `lib/pages/video/video_controller.dart`（`EpisodeRef.sortNumber` 计算、弹幕/评论取值）
- `lib/request/apis/bangumi_api.dart`（如需暴露 listIndex→sort 映射）
- `lib/utils/media.dart`（`extractEpisodeNumber` 作为回退保留）
- `lib/pages/player/player_item.dart`（off-by-one 修复）
- `lib/pages/player/controller/player_syncplay_controller.dart`、`lib/pages/player/player_controller.dart`（SyncPlay id 语义统一）
- 测试：扩展 `test/resolved_episode_test.dart` 或新增 `test/episode_sort_anchor_test.dart`

## 实现步骤

1. **sortNumber 锚定**：当 Bangumi 集列表可用时，按顺序/偏移把 `listIndex` 映射到 `EpisodeInfo.sort`，写入 `EpisodeRef.sortNumber`；不可用时回退 `extractEpisodeNumber(displayTitle)`，再回退 `listIndex`。
2. **弹幕/评论改用 sortNumber**：`_danmakuEpisodeForPlayback`、`commentEpisodeForSelection` 优先读 `EpisodeRef.sortNumber`，移除分散的标题正则直调（正则仅作为锚定内部回退）。
3. **off-by-one 修复**：自动连播 toast 改为 `identifier[playingSelection.episode - 1]`（与其余取值口径一致），或直接复用 `EpisodeRef.displayTitle`。
4. **SyncPlay id 语义统一**：用统一身份（建议基于稳定 key 而非语义混用的 `currentEpisode`）构造文件 id，保证在线/离线一致；同步收发两端口径对齐。

## 测试

- sort 锚定：有 Bangumi 集列表时 `sortNumber` 等于权威 sort；缺列表时回退标题正则；再缺回退 listIndex。
- 弹幕/评论：返回的集号为 `sortNumber`。
- 回归：自动连播 toast 标题正确（无 off-by-one）；SyncPlay 在线/离线切集与文件 id 一致。

## 验收标准

- 弹幕/评论集号锚定 Bangumi sort（可用时），不再仅依赖标题正则。
- 已知 off-by-one 与 SyncPlay id 语义缺陷修复。
- 测试通过，`dart analyze` 无新增告警。

## 系列收尾：暂不做（后续单独立项）

- 将 `Road` 的 `data`/`identifier` 平行数组替换为 `List<EpisodeEntry>` 对象列表：最干净但改动面最大、迁移风险高，待本系列链路稳定后再单独推进。
