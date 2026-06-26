# PR4 — 抽出通用 EpisodeMatcher（统一集数身份模型 4/5）

> 所属规划：全链路统一集数身份模型（增量 / pageUrl 主键）。
> 系列文档：PR1 · PR2 · PR3 · PR4（本篇）· PR5。

## 总体背景（系列共享）

下载与历史两条链路最终都采用同一套"URL 优先"的三级匹配（`归一化 pageUrl → 数字 → 唯一名称`）。在 PR3 之后，下载侧 `DownloadEpisodeMatcher` 与历史侧 `HistoryEpisodeMatcher` 逻辑高度重复。本 PR 把它们收敛为同一份实现，保证两条链路语义永远一致。

## 现状

- `lib/repositories/download_repository.dart`：`DownloadEpisodeMatcher`（`pageUrl → episodeNumber → 唯一 episodeName`，含 `canFillEpisodePageUrl` 回填）。
- PR3 引入的 `HistoryEpisodeMatcher`：`pageUrl → int episode`，含回填。

两者匹配优先级、归一化、回填策略一致，仅作用对象不同。

## 前置依赖

- PR1（归一化函数，作为匹配器内部统一口径）。
- PR3（`HistoryEpisodeMatcher` 已存在，才有"两份去重"的目标）。

## 本 PR 范围

抽出泛型 `EpisodeMatcher`，下载与历史共用三级匹配与 URL 归一化；不改变各自对外行为，仅消除重复实现。

## 目标设计

```dart
// 以"可被匹配的条目"为抽象，下载/历史各自提供取值适配
abstract class EpisodeMatchable {
  String get episodePageUrl;
  int get episodeNumber;
  String get episodeName;
}

class EpisodeMatcher {
  static EpisodeMatch<T>? find<T extends EpisodeMatchable>(
    Iterable<MapEntry<int, T>> entries, {
    required int episodeNumber,
    required String episodePageUrl, // 内部统一 normalizeEpisodeUrl
    required String episodeName,
  });
}
```

- 优先级：归一化 `pageUrl` → `episodeNumber`（map key）→ 唯一 `episodeName`（多匹配则放弃）。
- 提供统一的 `canFillEpisodePageUrl` 回填判定。

## 涉及文件

- 新增 `lib/repositories/episode_matcher.dart`（或 `lib/utils/`）
- 重构 `lib/repositories/download_repository.dart`（`DownloadEpisodeMatcher` 委托/替换为通用实现）
- 重构 PR3 的 `HistoryEpisodeMatcher`（委托/替换）
- 调整/合并测试：`test/download_episode_matcher_test.dart`、`test/history_repository_test.dart`，新增 `test/episode_matcher_test.dart`

## 实现步骤

1. 定义泛型 `EpisodeMatcher` 与 `EpisodeMatchable` 适配接口，内部统一调用 `normalizeEpisodeUrl`。
2. 让 `DownloadEpisode` 与历史 `Progress`（或其包装）适配 `EpisodeMatchable`。
3. `DownloadEpisodeMatcher` 与 `HistoryEpisodeMatcher` 改为对通用实现的薄封装（保留对外 API，减小调用方改动）。
4. 用 `test/episode_matcher_test.dart` 固化通用语义；保留两侧原测试验证封装未改变行为。

## 验收标准

- 下载与历史共用同一份三级匹配与归一化实现，无重复逻辑。
- 两侧对外行为不变，原有测试与新增通用测试全部通过。
- `dart analyze` 无新增告警。
