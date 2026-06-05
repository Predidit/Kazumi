# Kazumi 自定义功能修改方案 / Changelog

## 分支结构
- `main` — 官方最新代码（当前同步至 1d63c93）
- `pr1` — 基于官方 v2.1.3 的新功能分支（原 pr2，已重命名）
- `pr1.1` — pr1 的变体，构建配置与上游 main 一致（原 pr2.2，已重命名）

---

## 新增功能

### 功能一：番剧卡片长按/右键收藏菜单

#### 目标
在热门、时间线、搜索、收藏页面上，长按或右键点击番剧卡片时弹出「添加到分类」菜单，允许用户快速将番剧加入已创建的自定义收藏分类。

#### 改动文件

| 文件 | 改动 |
|------|------|
| `lib/bean/widget/collect_button.dart` | 新增可选 `menuController` / `iconSize` / `constraints` / `padding` 参数；switch→map 重构 |
| `lib/bean/widget/collectable_card_wrapper.dart` (新) | 共享 `StatefulWidget`，包裹任意卡片，提供 `MenuController` + `GestureDetector` + `CollectButton` 叠加层 |
| `lib/bean/card/bangumi_card.dart` | 新增 `onLongPress` / `onSecondaryTap` 回调 |
| `lib/bean/card/bangumi_timeline_card.dart` | 新增 `onLongPress` / `onSecondaryTap` 回调 |
| `lib/pages/collect/collect_page.dart` | 始终渲染 `CollectButton`；编辑模式 = 40px 圆形，普通模式 = 32px 半透明圆形 |
| `lib/pages/popular/popular_page.dart` | 用 `CollectableCardWrapper` 包裹 `BangumiCardV` |
| `lib/pages/timeline/timeline_page.dart` | 用 `CollectableCardWrapper` 包裹 `BangumiTimelineCard` |
| `lib/pages/search/search_page.dart` | 用 `CollectableCardWrapper` 包裹 `BangumiCardV` |

#### 设计要点
- `CollectableCardWrapper` 始终渲染 `GestureDetector` + `CollectButton` 在 `Stack` 中
- 按钮位置：`right: 4, bottom: 8`（32×32 半透明圆形）
- 无 `BackdropFilter`（Windows 渲染兼容性）
- 长按/右键触发 `MenuController.open()`，复用原有的分类菜单逻辑

---

### 功能二：收藏页更新角标

#### 目标
在收藏页（追踪中）的番剧卡片上显示红色角标，提示该番剧有未观看的新剧集。

#### 改动文件

| 文件 | 改动 |
|------|------|
| `lib/utils/update_check_service.dart` (新) | `UpdateCheckService` — 遍历「在看」列表，调用 Bangumi API 获取最新集数，与已记录集数比较 |
| `lib/pages/collect/collect_controller.dart` | `ObservableSet<int> bangumiIdsWithUpdate`；`@action checkForUpdates()` 含 20s 超时；`loadCollectibles()` 中延迟调用 |
| `lib/pages/collect/collect_page.dart` | 卡片右上角红点角标 |
| `lib/modules/collect/collect_module.dart` | `CollectedBangumi` 新增 `eps` 字段 (`@HiveField(3)`)，记录总集数 |
| `lib/repositories/collect_crud_repository.dart` | 新增 `updateCollectibleEps(id, eps)` 方法，更新收藏番剧的集数信息 |

#### 设计要点
- 使用 `BangumiApi.getBangumiEpisodesByID()`（type=0 的剧集数）而非每插件查询
- 懒加载 `_crudRepo` 避免 DI 死锁
- 15s（Service 层）+ 20s（Controller 层）超时，防止启动卡死

---

### 功能三：时间线卡片显示播出集数

#### 目标
在时间线页面的每张番剧卡片上显示最新已播集数（更新至第X话），并支持按播出日期排序。

#### 改动文件

| 文件 | 改动 |
|------|------|
| `lib/bean/card/bangumi_timeline_card.dart` | 新增 `episodeCount` / `onLongPress` / `onSecondaryTap` 参数；底部显示 ▶ 更新至第X话；`GestureDetector` 包裹 `InkWell` 支持长按/右键 |
| `lib/pages/timeline/timeline_controller.dart` | 新增 `ObservableMap<int, int> episodeCounts` + `isLoadingEpisodes` + `fetchEpisodeCounts()` 异步并行加载；`changeSortType()` 新增第 4 种排序（按 airDate） |
| `lib/pages/timeline/timeline_controller.g.dart` | MobX 代码生成（自动生成） |
| `lib/pages/timeline/timeline_page.dart` | 将 `episodeCounts[item.id]` 传入 `BangumiTimelineCard` |
| `lib/modules/bangumi/bangumi_item.dart` | 新增 `airTime` 字段 (`@HiveField(15)`)；`fromJson` 中解析 `airtime.time` |
| `lib/modules/bangumi/bangumi_item.g.dart` | Hive 适配器自动更新 |
| `lib/modules/bangumi/episode_item.dart` | 新增 `airdate` / `status` 字段 + `isAired` 计算属性，判断剧集是否已播出 |

#### 调用时机
- `getSchedules()`（当前季度）/ `getSchedulesBySeason()`（历史季度）完成后自动触发 `fetchEpisodeCounts()`
- 遍历日历中所有番剧 ID，**并行批量请求**（每批10个）调用 `BangumiApi.getBangumiEpisodesByID()`
- 统计 **type=0 且已播出** 的集数（即 `isAired == true`），取最大集数

#### 性能优化
- **并行批量加载**：原来串行加载70个番剧需约70秒，现在并行批量加载（每批10个）只需约7秒（提升10倍）
- **分批控制**：每批10个并发请求，避免过多并发导致 Bangumi API 限流
- **智能过滤**：只统计 type=0（正片）且 `isAired == true` 的集数，排除未播出和特别篇

---

## 功能回退

以下功能已在开发过程中被移除或简化：

### 回退一：移除时间线卡片中的星期和具体时间显示

#### 原因
- Bangumi 网站本身不显示具体的更新时间
- 保持界面简洁，只显示最核心的集数信息

#### 移除内容
- ❌ 星期显示（周一~周日）
- ❌ 具体播出时间（如 20:00）
- ✅ 保留：集数显示（更新至第X话）

#### 当前时间线卡片底部显示
```
▶ 更新至第12话  ⭐ 8.5  #123  👍 456
```

---

## Bug 修复


---

## 构建与部署

- **Windows 构建**: `flutter build windows` → `build\windows\x64\runner\Release\kazumi.exe`
- **Android 构建**: `flutter build apk --debug` → `build\app\outputs\flutter-apk\app-debug.apk`
  - 需 Android SDK 36 + BuildTools 28.0.3
  - Gradle 代理配置在 `android/gradle.properties`（`systemProp.http[s].proxyHost/Port`）

