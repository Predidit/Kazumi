# Android TV 适配

TV 使用独立构建入口，复用现有主题、设置分组、弹窗、番剧数据和播放器。
普通 Android 构建不会启用 TV 适配；手机和桌面保留原有布局与默认值。

## 构建

普通 Android 构建命令保持不变：

```sh
flutter build apk --release
```

TV 显式启用独立 Gradle 配置：

```sh
flutter build apk --release --flavor tv --android-project-arg=kazumiTv=true --target-platform android-arm64
```

TV 包使用 `.tv` applicationId 后缀和独立的 Leanback manifest/resource
overlay，可与普通版共存。未指定 `kazumiTv` 时不创建 flavor，不改变普通版输出名称。
`TvMode` 同时检查 Android 平台、Flutter flavor 与原生 TV 构建标记。

## 模块边界

- `services/platform/tv_*` 管理 TV 模式、遥控输入与导航请求。
- `bean/widget/tv_*` 提供焦点外框、遍历、侧栏、搜索入口和播放器侧面板。
- `TvPopularController` 在原有控制器上添加分类结果缓存；普通版仍注入原控制器。
- 历史网格、详情操作和播放器诊断分别放在各自组件中。
- 共享页面仅在 TV 模式下接入这些组件或改变布局；继续使用现有
  `ContentSection`、`SettingsDetailScaffold`、`KazumiDialog` 和主题颜色。
- TV 的播放进度回调按播放器实例保存；普通版保留原来的记录路径。

低内存模式保留“自动 / 始终 / 从不”三态。TV 只将未设置时的默认值设为开启，
不会覆盖用户已保存的选择。分类缓存是进程内 LRU，最多 8 个分类、每类 240 条，
10 分钟过期；不添加图片磁盘队列或持久化数据库。

TV 暂停应用内更新，避免下载普通版安装包。此改动不包含 fork 的品牌、发布工作流、
私有服务凭据提示、网络代理或超分实验。

## 回归验证

```sh
flutter test
flutter analyze --no-fatal-infos --fatal-warnings
```

| 范围 | 自动回归内容 |
| --- | --- |
| 首页 | 两行完整海报与标题、半透明编号、分类左右跟随和循环 |
| 遥控 | 连续按键、快速反向、滚动期间离开/返回、数字选台、末行循环 |
| 设置 | 左右面板往返、真实遥控说明页签退出、三态低内存设置和已保存选择 |
| 选集 | 线路菜单上下选择、关闭后恢复焦点、长列表回收、两行标题 |
| 缓存 | 分类返回不重复请求、分页恢复、LRU 淘汰、普通版请求不变 |
| 播放器 | 遥控快捷键、进度记录、输出选择、弹幕时间线、诊断解析 |
| 普通版 | 构建边界、原有默认值/菜单/缓存策略、选集页浅色/深色对照图 |

`test/goldens/upstream_episode_*.png` 从未修改的上游选集组件生成，基准版本为
`1b395a50`，Flutter 3.47.3；覆盖菜单打开和关闭。修改 TV 代码时应比较这些基准，
不要直接更新图像来掩盖普通版变化。这些对照图只覆盖选集页，不代表整个应用的视觉验证。

自动测试和模拟器不能替代真机播放验收。解码、声音、音画同步、温度与长时间运行
需要另行在目标电视上检查。
