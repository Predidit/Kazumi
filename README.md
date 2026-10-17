<div align=center>

<h1>Kazumi</h1>

<img src="assets/images/logo/logo_rounded.png" width=200></img>

<a href="https://t.me/kazumi_app"><img src="https://img.shields.io/badge/Telegram-2CA5E0?style=for-the-badge&logo=telegram&logoColor=white"></img></a>

<img src="https://img.shields.io/badge/Flutter-03A9F4?style=for-the-badge&logo=flutter&logoColor=white"></img>
<img src="https://img.shields.io/badge/Dart-00B4AB?style=for-the-badge&logo=Dart&logoColor=white"></img>

<a href="https://trendshift.io/repositories/11432"><img src="https://trendshift.io/api/badge/trendshift/repositories/11432/yearly?language=Dart"></img></a>
<a href="https://hellogithub.com/repository/Predidit/Kazumi" target="_blank"><img src="https://abroad.hellogithub.com/v1/widgets/recommend.svg?rid=68d824ea55ee4b07aba6fe1dd61ac939&claim_uid=J9Qu6aDd8LT1nU0"/></img></a>

<p>使用 Flutter 开发的基于自定义规则的番剧采集与在线观看程序。使用最多五行基于 <code>Xpath</code> 语法的选择器构建自己的规则。支持规则导入与规则分享。支持基于 <code>Anime4K</code> 的实时超分辨率。绝赞开发中 (～￣▽￣)～</p>
</div>

## 支持平台

- Android 10 及以上
- Windows 10 及以上
- MacOS 10.15 及以上
- Linux (实验性)
- iOS 13 及以上 (需要 [侧载](https://kazumi.app/docs/misc/how-to-install-in-ios))
- HarmonyOS 5.0 及以上 (位于 [分支仓库](https://github.com/ErBWs/Kazumi/releases/latest)，需要 [侧载](https://kazumi.app/docs/misc/how-to-install-in-ohos))

## 屏幕截图

<table>
  <tr>
    <td><img alt="homepage" src="static/screenshot/img_1.png"></td>
    <td><img alt="timetable" src="static/screenshot/img_2.png"></td>
    <td><img alt="details" src="static/screenshot/img_3.png"></td>
  <tr>
  <tr>
    <td><img alt="selection-page" src="static/screenshot/img_4.png"></td>
    <td><img alt="rules-mange" src="static/screenshot/img_5.png"></td>
    <td><img alt="rules-edit" src="static/screenshot/img_6.png"></td>
  <tr>
</table>

## 功能 / 开发计划

- [X]  规则编辑器
- [X]  番剧目录
- [X]  番剧搜索
- [X]  番剧时间表
- [X]  番剧字幕
- [X]  分集播放
- [X]  视频播放器
- [X]  多视频源支持
- [X]  规则分享
- [X]  硬件加速
- [X]  高刷适配
- [X]  追番列表
- [X]  番剧弹幕
- [X]  在线更新
- [X]  历史记录
- [X]  倍速播放
- [X]  配色方案
- [X]  跨设备同步
- [X]  无线投屏 (DLNA)
- [X]  外部播放器播放
- [X]  超分辨率
- [X]  一起看
- [X]  番剧下载
- [ ]  番剧更新提醒
- [ ]  还有更多 (/・ω・＼)

## 下载

通过本页面 [Releases](https://github.com/Predidit/Kazumi/releases/latest) 选项卡下载：

<a href="https://github.com/Predidit/Kazumi/releases">
  <img src="static/svg/get_it_on_github.svg" alt="Get it on Github" width="200"/>
</a>

### Android

<a href="https://f-droid.org/packages/com.predidit.kazumi">
  <img src="https://fdroid.gitlab.io/artwork/badge/get-it-on-zh-hans.svg"
  alt="Get it on F-Droid" width="200">
</a>

### GNU/Linux

<a href="https://flathub.org/apps/io.github.Predidit.Kazumi">
  <img src="https://flathub.org/api/badge?svg&locale=zh-Hans" alt="Get it on Flathub" width="175"/>
</a>

#### Arch Linux

可以从 [AUR](http://aur.archlinux.org) 安装。

##### AUR

```bash
[yay/paru] -S kazumi # 从源码构建
[yay/paru] -S kazumi-bin # 二进制包
```

## 贡献

欢迎向我们的 [规则仓库](https://github.com/Predidit/KazumiRules) 提交您的自定义规则。您可以自由选择是否在规则中留下您的ID。详细的规则编写教程可以参考 [规则开发文档](https://kazumi.app/docs/rules/develop-rules)

## Q&A

<details>
<summary>使用者 Q&A</summary>

#### Q: 为什么少数番剧中有广告？

A: 本项目未插入任何广告。广告来自视频源, 请不要相信广告中的任何内容, 并尽量选择没有广告的视频源观看。

#### Q: 为什么我启用超分辨率功能后播放卡顿？

A: 超分辨率功能对 GPU 性能要求较高, 如果没有在高性能独立显卡上运行 Kazumi, 尽量选择效率档而非质量档。对低分辨率视频源而非高分辨率视频源使用超分也可以降低性能消耗。

#### Q: 为什么播放视频时内存占用较高？

A: 本程序在视频播放时, 会尽可能多地缓存视频到内存, 以提供较好的观看体验。如果您的内存较为紧张, 可以在播放设置选项卡启用低内存模式, 这将限制缓存。

#### Q: 为什么少数番剧无法通过外部播放器观看？

A: 部分视频源的番剧使用了反盗链措施, 这可以被 Kazumi 解决, 但无法被外部播放器解决。

#### Q: 为什么下载的 Linux 版本缺少图标和托盘功能？

A: 使用 .deb 版本进行安装, tar.gz 版本仅为方便二次打包, 这一格式先天缺乏图标和托盘功能支持。

</details>

<details>
<summary>规则编写者 Q&A</summary>

#### Q: 为什么我的自定义规则无法实现检索？

A: 目前我们对 `Xpath` 语法的支持并不完整, 我们目前只支持以 `//` 开头的选择器。建议参照我们给出的示例规则构建自定义规则。

#### Q: 为什么我的自定义规则可以实现检索, 但不能实现观看？

A: 尝试关闭自定义规则的使用内置播放器选项, 这将尝试使用 `webview` 进行播放, 提高兼容性。但在内置播放器可用时, 建议启用内置播放器, 以获得更加流畅并带有弹幕的观看体验。

</details>

<details>
<summary>开发者 Q&A</summary>

#### Q: 我在尝试自行编译该项目, 但编译没有成功。

A: 本项目编译需要良好的网络环境, 除了由 Google 托管的 Flutter 相关依赖外, 本项目同样依赖托管在 MavenCentral/Github/SourceForge 上的资源。如果您位于中国大陆, 可能需要设置恰当的镜像地址。

</details>

## 开发

欢迎您提交 PR！在开始之前, 请阅读 [贡献指引](static/doc/CONTRIBUTING.md) 以了解我们对 PR 和 AI 参与辅助开发的规定。

## 项目架构

Kazumi 是一个使用 Flutter 构建的跨平台番剧搜索与播放应用。应用以 Flutter Modular 管理模块、路由和依赖注入，以 MobX 管理部分响应式状态，以 Hive 保存本地数据；内容源通过可导入和更新的 JSON 规则驱动，视频页面通过平台 WebView 解析媒体地址，并由 Media Kit 等播放能力完成播放。

### 技术与运行时

- **Flutter / Dart**：跨平台 UI 和应用逻辑。项目在 `pubspec.yaml` 中要求 Flutter 3.47.6；可通过仓库提供的 `run_fvm47.ps1` 在 Windows 上调用该版本。
- **Flutter Modular**：组合应用模块、配置路由，并在根模块或页面路由范围内提供依赖。
- **MobX**：管理部分页面和业务状态；`*.g.dart` 是由代码生成器产生的文件。
- **Hive CE**：在应用支持目录下保存设置、收藏、历史、搜索历史、下载记录及其他本地数据。
- **Dio 与专用客户端**：处理 Bangumi、内容源、规则仓库、弹幕和下载等网络请求，并按用途配置代理、请求头和传输适配器。
- **Media Kit / WebView**：分别承担媒体播放和网页视频源解析等职责。

### 源码目录

| 路径 | 职责 |
| --- | --- |
| `lib/main.dart` | 初始化 Flutter、存储和平台能力，配置桌面窗口及网络代理，并启动根应用。 |
| `lib/app_widget.dart` | 构建 `MaterialApp.router`，管理主题、应用生命周期、系统托盘和桌面窗口关闭行为。 |
| `lib/app_module.dart`、`lib/core_module.dart` | 组合路由模块，并注册全应用共享的 Repository、Service 和 Controller。 |
| `lib/pages/` | 按功能组织页面、页面级 Controller 和路由模块，例如搜索、详情、播放、设置、下载与历史。 |
| `lib/bean/` | 跨页面复用的 UI 组件、主题设置组件、弹窗、卡片和状态展示组件。 |
| `lib/modules/` | 领域模型和业务数据结构，例如番剧、收藏、历史、下载、评论和弹幕同步数据。 |
| `lib/repositories/` | 收藏、历史、下载、搜索历史和弹幕屏蔽等本地数据访问抽象与实现。 |
| `lib/services/` | 网络代理、存储协调、内容源解析、规则执行、播放器、下载、同步和平台集成等服务。 |
| `lib/request/` | API 封装、HTTP 客户端、端点配置和网络传输基础设施。 |
| `lib/plugins/` | 内容源规则模型、规则配置和规则列表状态管理。 |
| `lib/webview/` | 视频源解析和验证码场景使用的 WebView 接口及平台实现。 |
| `lib/utils/` | 跨业务复用的工具函数、常量和异步控制工具。 |
| `lib/bbcode/` | BBCode 解析实现及生成代码；语法定义位于 `assets/bbcode/`。 |
| `assets/`、`licenses/` | 图片、字体、着色器、内置规则、文本资源和第三方许可证等应用资源。 |
| `android/`、`ios/`、`linux/`、`macos/`、`windows/`、`web/` | Flutter 各目标平台的宿主工程、构建配置和原生集成。 |
| `test/` | Dart 单元及服务测试。 |

### 启动与依赖生命周期

启动入口位于 `lib/main.dart`，主要流程如下：

1. 初始化 Flutter binding、媒体运行时和平台特性；移动设备配置系统栏，Android 初始化 WebView 特性。
2. 初始化 Hive 和 `GStorage`。若本地存储初始化失败，应用会展示专门的存储错误页面，而不是继续进入正常业务流程。
3. 配置桌面窗口；Windows 初始化系统代理，其余网络配置刷新代理客户端和图片缓存客户端。
4. 创建 `ModularApp`，挂载根导航器、路由观察器和主题 Provider。
5. 通过根路由进入初始化页，完成插件加载、存储迁移、下载初始化，以及按用户设置运行的同步和更新检查。

`app_module.dart` 组合 `coreModule` 与页面入口模块。`core_module.dart` 中注册的服务和 Repository 按应用生命周期共享；页面或路由专属状态则通常由路由的 `provide` 回调创建。例如，播放路由创建自己的 `PlayerController` 和 `VideoPageController`，退出该路由后由页面模块生命周期管理其状态。

### 路由与页面结构

主要路由在 `lib/pages/index_module.dart` 中组合。`/tab` 是主界面外壳，包含推荐、时间表、追番和“我的”页面；搜索、番剧详情、播放、设置和图片预览等功能通过其他子模块挂载到根路由。

常见页面由以下部分组成：

- **Page**：负责布局、用户交互和展示状态。
- **Controller**：承载页面或业务流程状态；其中使用 MobX 的 Controller 通常配有生成的 `*.g.dart` 文件。
- **Module**：声明路由、路由参数校验和 Controller 的依赖范围。

页面和业务层并非处处严格隔离：部分 Controller 会直接调用 API 或 Service；理解具体功能时应从对应路由、Controller 和被调用服务共同追踪，而不能只依赖目录名称推断调用关系。

### 主要业务流程

#### 搜索与内容源规则

```text
搜索页面
  → PluginsController 读取已安装规则
  → RuleEngine 根据规则组装请求并调用内容源
  → XPath 或 API 策略解析响应
  → 展示番剧、线路与分集
```

规则模型位于 `lib/plugins/`，规则目录请求由 `lib/request/apis/plugin_catalog_api.dart` 处理，规则加载、安装和更新由 `PluginsController` 管理。规则执行核心位于 `lib/services/plugin/`，支持 XPath 和 API 两类搜索/章节解析策略，并包含请求、解析错误和验证码相关处理。内置示例规则放在 `assets/plugins/`；用户规则在应用支持目录内保存。

#### 番剧信息

Bangumi API 和数据转换集中在 `lib/request/apis/`、`lib/request/clients/` 与 `lib/modules/bangumi/`。页面按需组合 Bangumi 元数据、角色/制作人员/评论信息和本地收藏状态；`BangumiItem` 等领域模型同时供页面及本地存储使用。

#### 播放与视频源解析

```text
详情页或下载页
  → 构造播放路由参数
  → VideoPageController 选择集数和线路
  → WebViewVideoSourceService 加载播放页面并解析媒体 URL
  → PlayerController 使用 Media Kit 播放
  → 更新观看进度，并按需处理弹幕、评论、截图或同步播放
```

播放页面路由和参数处理位于 `lib/pages/video/`。`VideoPageController` 负责分集、线路、在线/离线播放等页面流程；`PlayerController` 将播放、弹幕、进度控制、同步播放、截图和播放器面板等职责委托给 `lib/pages/player/controller/` 下的子控制器。视频源服务接口位于 `lib/services/video_source/`，平台 WebView 实现在 `lib/webview/video/impl/` 中。下载完成的媒体也可以经播放流程作为离线内容使用。

#### 本地数据与同步

```text
页面 / 业务 Controller
  → Repository（数据读取与写入）
  → GStorage / Hive
  → 可选的 Bangumi 或 WebDAV 同步服务
```

`GStorage` 在启动时注册 Hive adapters 并打开数据 Box；Repository 为历史、收藏、下载、搜索历史及屏蔽规则等功能提供数据访问入口。领域数据结构主要位于 `lib/modules/`。同步服务位于 `lib/services/sync/`，覆盖 WebDAV、Bangumi 历史/收藏以及弹幕屏蔽等同步能力。部分数据写入和同步通过队列或协调器串行化，以减少并发写入冲突。

### 网络与平台服务

`lib/request/core/dio_factory.dart` 按请求用途创建并缓存不同 Dio 客户端，例如 Bangumi、插件站点、规则仓库和下载请求。网络配置由 `lib/request/core/` 与 `lib/services/network/` 协作提供；代理更新时会重建网络客户端，并刷新图片缓存使用的客户端。WebView 请求代理与普通 Dio 请求配置是不同路径，需要分别由各平台 WebView 实现处理。

平台差异尽可能封装在 `lib/services/platform/` 和 WebView 的平台实现中；桌面窗口、托盘、快捷方式、显示模式、后台下载及外部播放器还依赖对应平台的 Flutter 插件或原生宿主代码。仓库包含多个平台工程目录，但实际发行平台与最低版本以本 README 的“支持平台”说明为准。

### 测试与本地开发

测试位于 `test/`，覆盖规则引擎、搜索解析、存储 Repository、历史/收藏同步、播放相关解析及异步协调工具等。测试当前不代表所有原生平台集成都已通过端到端验证。

项目要求 Flutter 3.47.6。Windows 开发环境可在仓库根目录通过提供的脚本运行 Flutter 命令：

```powershell
.\run_fvm47.ps1 pub get --no-example
.\run_fvm47.ps1 analyze
.\run_fvm47.ps1 test
```

MobX、Hive 等生成文件应使用项目既有的代码生成工具更新，不要手动编辑生成文件。

## 美术资源

本项目图标来自 [Yuquanaaa](https://www.pixiv.net/users/66219277) 发表在 [Pixiv](https://www.pixiv.net/artworks/116666979) 上的作品。

此图标由其原作者 [Yuquanaaa](https://www.pixiv.net/users/66219277) 拥有版权。我们已获得原作者的授权和许可, 可以在本项目中使用这一图标。这一图标不是自由使用的, 未经原作者明确授权, 任何人不得擅自使用、复制、修改或分发这一图标。

本项目内嵌字体为 [Mi Sans](https://hyperos.mi.com/font/zh/details/sc/) 字体, 由 [Xiaomi](https://www.mi.com/index.html) 开发和拥有版权。

## 免责声明

本项目基于 GNU 通用公共许可证第 3 版（GPL-3.0）授权。我们不对其适用性、可靠性或准确性作出任何明示或暗示的保证。在法律允许的最大范围内, 作者和贡献者不承担任何因使用本软件而产生的直接、间接、偶然、特殊或后果性的损害赔偿责任。

使用本项目需遵守所在地法律法规, 不得进行任何侵犯第三方知识产权的行为。因使用本项目而产生的数据和缓存应在24小时内清除, 超出 24 小时的使用需获得相关权利人的授权。

## 隐私政策

我们不收集任何用户数据, 不使用任何遥测组件。

## 代码签名策略

提交者: [贡献者](https://github.com/Predidit/Kazumi/graphs/contributors)
审阅者: [所有者](https://github.com/Predidit)

## 赞助


| ![signpath](https://signpath.org/assets/favicon-50x50.png)                                                                                                                      | Free code signing on Windows provided by[SignPath.io](https://about.signpath.io/), certficate by [SignPath Foundation](https://signpath.org/) |
| ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------- |
| <img src="https://kilo.ai/favicon/favicon.svg" width="50">                                                                                                                      | **Automatic PR review provided by [Kilo Code](https://kilo.ai/), sponsored by the [Kilo OSS Program](https://kilo.ai/oss)**                   |
| <a href="https://m.do.co/c/0062035db3e4"><img src="https://opensource.nyc3.cdn.digitaloceanspaces.com/attribution/assets/SVG/DO_Logo_icon_blue.svg" width="50" height="50"></a> | **Cloud infrastructure is supported by [DigitalOcean](https://m.do.co/c/0062035db3e4)**                                                       |

## 致谢

特别感谢 [XpathSelector](https://github.com/simonkimi/xpath_selector) 这个优秀的项目是本项目的基石。

特别感谢 [弹弹play](https://www.dandanplay.com/) 本项目使用了 弹弹play开放平台 以提供弹幕交互。

特别感谢 [Bangumi](https://bangumi.tv/) 本项目使用了 Bangumi 开放 API 以提供番剧元数据。

特别感谢 [Anime4K](https://github.com/bloc97/Anime4K) 本项目使用 Anime4K 进行实时超分。

特别感谢 [SyncPlay](https://github.com/Syncplay/syncplay) 本项目使用 SyncPlay 协议并通过 SyncPlay 公共服务器实现一起看功能。

特别感谢 [所有贡献者](https://github.com/Predidit/Kazumi/graphs/contributors) 本项目因为你们变得更好。

特别感谢 [trace.moe](https://trace.moe) 本项目使用了 trace.moe 提供的图片识别番剧功能。

感谢 [media-kit](https://github.com/media-kit/media-kit) 本项目跨平台媒体播放能力来自 media-kit。

感谢 [avbuild](https://github.com/wang-bin/avbuild) 本项目使用了来自 avbuild 的树外补丁实现非标准视频流播放。

感谢 [hive](https://github.com/isar/hive) 本项目持久化储存能力来自 hive。
