# PR3 — 历史以 pageUrl 为主键（统一集数身份模型 3/5）

> 所属规划：全链路统一集数身份模型（增量 / pageUrl 主键）。
> 系列文档：PR1 · PR2 · PR3（本篇）· PR4 · PR5。

## 总体背景（系列共享）

把"集"的四个正交维度显式分离：`listIndex`（UI 排序）/ `pageUrl`（稳定主键）/ `sortNumber`（真实集号）/ `displayTitle`（展示）。收敛策略是让历史复刻下载已有的 URL 优先匹配模式。

本 PR 是整个系列的**核心收敛点**。

## 现状缺口

- 下载侧 `DownloadEpisodeMatcher`（`lib/repositories/download_repository.dart`）已是 `归一化 pageUrl → episodeNumber → 唯一 episodeName` 三级匹配。
- 历史侧仍以 `int episode` 为 key：`HistoryRepository.findProgress / getLastWatchingProgress` 用 `history.progresses[episode]`；在线场景该 `episode` 实为列表位置。
- 恢复路径 `lib/pages/video/video_page.dart` 的 `_initOnlineMode` 直接把 `progress.episode` 当作 `roadList` 下标 → **源站集数重排即历史错位**。

`split/playback-episode-identity` 已添加 `History.episodePageUrl`（记录级"最后一次 URL"）与在线/离线分桶 key，但**尚未把 per-episode 进度按 URL 索引**。本 PR 补上这一步。

## 前置依赖

- PR1（URL 归一化）：进度的 URL key 必须来自统一归一化结果。
- PR2（EpisodeRef）：写入/查询身份统一来自 `EpisodeRef` / `PlaybackHistoryIdentity`。

## 本 PR 范围

让历史进度以归一化 `pageUrl` 为主键，配套 Hive 字段、匹配器、仓储查询、恢复路径、旧数据回填与同步载荷扩展，保持向后兼容。

## 涉及文件

- `lib/modules/history/history_module.dart` + 重生成 `history_module.g.dart`
- 新增 `HistoryEpisodeMatcher`（镜像 `DownloadEpisodeMatcher`，可暂置于 `lib/repositories/history_repository.dart` 或独立文件）
- `lib/repositories/history_repository.dart`
- `lib/pages/video/video_page.dart`（`_initOnlineMode` 恢复路径）
- `lib/modules/history/history_sync.dart`、`lib/services/sync/history_sync_service.dart`（同步载荷扩展）
- `test/history_repository_test.dart`（扩展）

## 实现步骤

1. **Hive 字段**：`Progress` 新增 `@HiveField(4, defaultValue: '') String episodePageUrl`，重生成 `history_module.g.dart`。保持 `Map<int, Progress>` 存储结构不变（增量、不破坏旧库）。

2. **匹配器**：新增 `HistoryEpisodeMatcher`，三级匹配：
   - 归一化 `pageUrl` 命中（遍历 `progresses` 比对 `Progress.episodePageUrl`）。
   - 回退 `int episode`（`progresses[episode]`）。
   - 命中后**写穿回填** `episodePageUrl`（旧记录补全）。

3. **仓储**：`updateHistory / findProgress / getLastWatchingProgress / clearProgress` 改为经 `PlaybackHistoryIdentity.episodePageUrl` + 匹配器查找；写入时落 `episodePageUrl`。

4. **恢复路径**：`video_page.dart` 的 `_initOnlineMode` 改为按 `pageUrl` 在当前 `roadList` 定位列表位置，替代 `progress.episode` 直接当下标 → 根治源站重排错位；URL 缺失时回退原 `int` 逻辑。

5. **回填/迁移**：首次加载/恢复时，按 `listIndex` 从当前 `roadList` 回填旧 `Progress.episodePageUrl`（best-effort，幂等）。

6. **同步**：WebDAV 历史同步事件载荷扩展携带 `episodePageUrl`（`history_sync.dart` / `history_sync_service.dart`），默认空，向后兼容旧端。

## 测试（扩展 `test/history_repository_test.dart`）

- URL 优先：URL 命中时即便 `int episode` 不同也返回正确进度。
- int 回退：旧记录无 URL 时按 `episode` 命中。
- 回填：URL 缺失记录在一次命中后被写入 `episodePageUrl`。
- 重排稳定：模拟 `roadList` 重排后，按 URL 仍能恢复到正确集。
- 同步：载荷含 `episodePageUrl`，旧载荷（缺字段）仍可解析。

## 验收标准

- 进度查询/写入/清除以归一化 `pageUrl` 为主键，`int` 仅作回退。
- 源站集数重排后历史恢复不再错位。
- 旧 Hive 库与旧同步端兼容（无字段时默认空、可回填）。
- 新增/扩展测试通过，`dart analyze` 无新增告警。
