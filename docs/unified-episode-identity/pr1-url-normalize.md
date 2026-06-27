# PR1 — URL 归一化（统一集数身份模型 1/5）

> 所属规划：全链路统一集数身份模型（增量 / pageUrl 主键）。
> 系列文档：PR1（本篇）· PR2 · PR3 · PR4 · PR5。

## 总体背景（系列共享）

把"集"的四个正交维度显式分离，永不再用一个 `int` 兼任多职：

- 位置维度 `listIndex`（1-based，仅 UI 排序）
- 来源维度 `pageUrl`（**稳定主键**，归一化后的源站 URL）
- 语义维度 `sortNumber`（真实集号，优先 Bangumi `EpisodeInfo.sort`，回退标题正则，可空）
- 展示维度 `displayTitle`

收敛策略：历史复刻下载已有的 URL 优先匹配模式，最终全链路统一到同一个身份对象 + 同一套匹配器。本 PR 是整个系列的地基：先保证"同一集的 URL 始终是同一个字符串"，否则后续以 `pageUrl` 为主键的匹配都不可靠。

## 前置依赖

- 系列整体构建在 `split/playback-episode-identity` 分支之上（已含 `ResolvedEpisode` / `PlaybackHistoryIdentity` / 在线离线分桶）。
- 本 PR 本身是纯函数工具 + 接入，**不依赖** PR2~5，可最先合入。

## 本 PR 范围

新增一个 URL 归一化纯函数，并在"生产 URL"和"消费 URL"两端接入，使任何一集的源站地址在全应用内得到稳定一致的归一化结果。

不在本 PR 范围：历史/下载的主键改造（PR3/PR4）、身份对象重构（PR2）。

## 现状问题

- `Road.data[i]` 存的是插件抓取的原始 `href`（可能是相对路径，可能缺协议）。
- `lib/pages/video/video_controller.dart` 在播放时才临时拼接 `baseUrl`，判断逻辑分散且不统一（同时处理 `https`/`http` 两种前缀）。
- 同一集在不同入口（播放、下载、历史回填）可能得到不同形态的 URL 串，导致后续以 URL 为 key 的匹配失配。

## 涉及文件

- 新增 `lib/utils/episode_url.dart`
- 修改 `lib/plugins/plugins.dart`（`Plugin.querychapterRoads`）
- 修改 `lib/pages/video/video_controller.dart`（替换现有 baseUrl 临时拼接逻辑）
- 新增 `test/episode_url_test.dart`

## 实现步骤

1. 在 `lib/utils/episode_url.dart` 实现：

   ```dart
   String normalizeEpisodeUrl(String baseUrl, String raw);
   ```

   归一化规则（建议）：
   - 去首尾空白。
   - 相对路径补全为绝对（基于 `baseUrl`）。
   - 统一协议比较口径（避免 `http`/`https` 造成的失配；保留可访问性的前提下统一一种用于"作为 key 的归一形态"）。
   - 去除多余尾斜杠、空 query 等噪声。
   - 输入为空时返回空串（调用方据此判断"无 URL"）。

2. 生产端：`Plugin.querychapterRoads` 在写入 `chapterUrlList`（即 `Road.data`）前调用 `normalizeEpisodeUrl(baseUrl, itemUrl)`。

3. 消费端：`video_controller.dart` 中现有"判断是否包含 `baseUrl` 再拼接"的临时逻辑替换为 `normalizeEpisodeUrl`，保证与生产端口径一致。

4. 评估是否影响 `WebViewVideoSourceService.resolve` 的可访问 URL：归一化用于"身份 key"，若解析仍需原始可访问 URL，需明确区分"key 形态"与"请求形态"，避免破坏真实播放请求。

## 测试

`test/episode_url_test.dart` 覆盖：
- 相对路径 + baseUrl → 绝对 URL。
- 绝对路径原样（幂等）。
- `http` 与 `https` 同站归一到同一 key。
- 尾斜杠 / 空白 / 空输入。
- 幂等性：`normalize(normalize(x)) == normalize(x)`。

## 验收标准

- 新工具有单测且通过；`dart analyze` 无新增告警。
- 生产端与消费端使用同一函数，去除分散的临时拼接逻辑。
- 在线播放与下载行为不变（回归：能正常进入播放、能正常解析源）。
