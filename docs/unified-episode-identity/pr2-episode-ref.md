# PR2 — 统一身份对象 EpisodeRef（统一集数身份模型 2/5）

> 所属规划：全链路统一集数身份模型（增量 / pageUrl 主键）。
> 系列文档：PR1 · PR2（本篇）· PR3 · PR4 · PR5。

## 总体背景（系列共享）

把"集"的四个正交维度显式分离，永不再用一个 `int` 兼任多职：

- 位置维度 `listIndex`（1-based，仅 UI 排序）
- 来源维度 `pageUrl`（**稳定主键**，归一化后的源站 URL）
- 语义维度 `sortNumber`（真实集号，优先 Bangumi `EpisodeInfo.sort`，回退标题正则，可空）
- 展示维度 `displayTitle`

## 当前基线

`split/playback-episode-identity` 已引入：
- `ResolvedEpisode`（`lib/pages/video/video_controller.dart`）：在播放那一刻把选择解析为多语义（`listIndex / historyEpisodeNumber / danmakuEpisodeNumber / episodePageUrl / originalRoadIndex`）。
- `PlaybackHistoryIdentity` + `HistoryEntryKind`（`lib/modules/history/history_module.dart`）。
- `PlaybackInitParams` 已带 `danmakuEpisodeNumber`（`lib/pages/player/controller/player_models.dart`）。

问题：`ResolvedEpisode` 只是"播放时临时解析对象"，并未成为贯穿全链路的统一货币；很多调用点仍直接基于 `selection.episode` 臆测语义。

## 前置依赖

- 建议在 PR1（URL 归一化）之后，使 `episodePageUrl` 取自统一归一化结果。
- 不依赖 PR3~5。

## 本 PR 范围

把 `ResolvedEpisode` 泛化为贯穿全链路的统一身份对象 `EpisodeRef`，作为传给播放、历史、SyncPlay 的唯一货币对象；消除调用点对 `selection.episode` 的语义臆测。

本 PR 以**重构为主、行为不变**。主键真正落到持久层是 PR3 的事。

## 目标结构

```dart
class EpisodeRef {
  final int listIndex;        // 1-based 列表位置（UI）
  final int roadIndex;        // 当前展示线路
  final int originalRoadIndex;// 原始线路（离线分组用）
  final String displayTitle;  // 展示标题
  final String pageUrl;       // 归一化源站 URL（稳定主键）
  final int? sortNumber;      // 真实集号（PR5 锚定 Bangumi sort，可空）
  // online/offline 工厂保留现有 ResolvedEpisode 行为
}
```

兼容策略：保留 `historyEpisodeNumber` / `danmakuEpisodeNumber` 现有派生语义（PR3/PR5 再逐步迁移到 `pageUrl` / `sortNumber`），确保本 PR 不改变运行时行为。

## 涉及文件

- `lib/pages/video/video_controller.dart`（`ResolvedEpisode` → `EpisodeRef` 泛化/重命名，解析逻辑保留）
- `lib/pages/player/controller/player_models.dart`（`PlaybackInitParams` 接收/透传 `EpisodeRef` 关键字段）
- `lib/pages/player/player_item.dart`、`lib/pages/player/controller/player_syncplay_controller.dart`（调用点改用 `EpisodeRef`）
- `test/resolved_episode_test.dart`（迁移为 `EpisodeRef` 断言）

## 实现步骤

1. 将 `ResolvedEpisode` 重命名/泛化为 `EpisodeRef`，保留 `.online` / `.offline` 工厂与现有派生字段。
2. 在播放入口统一构造 `EpisodeRef` 并作为唯一对象向下传递，替换零散的 `selection.episode ± 1`、`identifier[...]`、`data[...]` 直接取值。
3. 让 `PlaybackInitParams` 从 `EpisodeRef` 取值，保证播放层不再自行换算语义。
4. 迁移 `test/resolved_episode_test.dart` 断言（在线保 `listIndex`、离线用下载集号、`danmaku` 解析标题等行为不变）。

## 测试

- `test/resolved_episode_test.dart` 全绿（迁移后语义不变）。
- 手动回归：在线/离线播放、上一集/下一集、自动连播、SyncPlay 连接态切集。

## 验收标准

- 全链路播放路径以单一 `EpisodeRef` 传参，调用点不再各自臆测集数语义。
- 行为与基线一致（无功能变化），`dart analyze` 无新增告警。
