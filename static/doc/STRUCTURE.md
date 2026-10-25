# Kazumi/

```
Kazumi/
├── lib/                        # Dart 源码
├── test/                       # 测试用例
├── assets/                     # 静态资源（字体、图标与图片、Anime4K 着色器、BBCode 语法、免责声明等）
├── licenses/                   # 第三方依赖许可证与内置 CA 证书（ech_http、m3e_core）
├── static/                     # 贡献文档（doc/）、应用截图（screenshot/）与静态素材（svg/）
├── android/  ios/  linux/  macos/  windows/  web/   # 各平台宿主工程与原生桥接代码
├── fastlane/                   # 商店元数据与构建依赖子模块
├── .github/                    # CI/CD 工作流与 Issue / PR 模板
├── pubspec.yaml                # 依赖、版本与资源配置
├── analysis_options.yaml       # 静态分析与 Lint 规则
├── devtools_options.yaml       # Flutter DevTools 配置
├── LICENSE                     # GPL-3.0 开源许可证
└── README.md                   # 项目说明文档
```

## lib/

```
lib/
├── main.dart                   # 应用入口（环境初始化、存储与网络启动、桌面窗口初始化）
├── app_module.dart             # 根模块（组合 coreModule 与 indexModule）
├── core_module.dart            # 全局单例注册（Repository、跨模块 Service 与全局 Controller）
├── app_widget.dart             # 应用外壳（主题、系统托盘、生命周期与窗口关闭拦截）
├── navigation.dart             # 全局 navigatorKey、routeObserver 与外部导航栈管理
├── hive_registrar.g.dart       # Hive CE Adapter 自动生成注册表
│
├── bbcode/                     # BBCode 解析与渲染
│   ├── bbcode_base_listener.dart
│   ├── bbcode_elements.dart
│   ├── bbcode_widget.dart
│   ├── README.md
│   └── generated/              # ANTLR 生成的词法与语法分析器
│
├── bean/                       # 通用 UI 组件
│   ├── appbar/                 # 桌面拖拽顶栏与自适应系统 AppBar
│   ├── card/                   # 番剧、时间线、角色、评论、Staff、规则与调色板卡片
│   ├── dialog/                 # 统一弹窗封装（KazumiDialog）、自适应底栏与弹窗任务队列
│   ├── settings/               # 设置页通用脚手架、列表组件、镜像设置与 ThemeProvider
│   └── widget/                 # 基础通用组件（收藏按钮、状态占位、菜单、图片预览、侧栏动画等）
│
├── modules/                    # 数据模型与业务实体（含 Hive 持久化模型）
│   ├── bangumi/                # 番剧条目、剧集、标签、短评、关联作品与同步优先级
│   ├── character/  characters/ # 角色详情、角色列表与声优数据模型
│   ├── collect/                # 本地收藏、收藏变更记录、布局枚举与同步合并策略
│   ├── comments/  staff/       # 评论与制作人员响应模型
│   ├── danmaku/                # 弹幕模型、搜索/剧集响应、简繁转换、屏蔽规则与同步快照
│   ├── download/               # 离线下载任务与分集状态模型
│   ├── history/                # 观看历史记录、播放进度与历史同步模型
│   ├── my/                     # 个人空间观看统计模型
│   ├── plugin/                 # 规则商店远程规则条目模型
│   ├── roads/                  # 播放线路与剧集列表模型
│   └── search/                 # 规则搜索结果、以图搜番结果与搜索历史模型
│
├── pages/                      # 页面与视图层
│   ├── index_module.dart / index_page.dart / init_page.dart   # 顶层路由、主框架与启动初始化页
│   ├── router.dart             # 主导航栏 Tab 路由表
│   ├── route_error_page.dart   # 路由参数错误回退页
│   ├── about/                  # 关于页与致谢名单
│   ├── collect/                # 追番收藏页、列表检索与同步弹窗
│   ├── download/               # 离线下载管理页与选集下载面板
│   ├── error/                  # 存储初始化失败页
│   ├── history/                # 历史记录页与检索列表
│   ├── info/                   # 番剧详情、角色详情、评分弹窗、评论视图与换源/验证码流程
│   ├── logs/                   # 运行日志查看页
│   ├── menu/                   # 自适应主导航栏（底部导航 / 侧边栏）与路由可见性
│   ├── my/                     # 个人空间与 Bangumi 账户概览页
│   ├── onboarding/             # 首次启动引导页与 steps/ 分步视图（免责声明/镜像/规则/更新源）
│   ├── player/                 # 播放器组件、弹幕/评论/截图/一起看面板与 controller/ 细分控制器
│   ├── plugin_editor/          # 规则管理、规则编辑器、规则商店与规则测试页
│   ├── popular/                # 热门番剧推荐页
│   ├── search/                 # 聚合搜索页、筛选面板与以图搜番页
│   ├── settings/               # 各项设置页 + danmaku/（弹幕与屏蔽）+ proxy/（代理）+ sync/（Bangumi/WebDAV 同步）
│   ├── timeline/               # 新番时间表页与周历选择器
│   └── video/                  # 视频播放宿主页、选集面板、侧边栏与全屏控制
│
├── plugins/                    # 视频源规则模型（Plugin）、API/反爬配置与 PluginsController
│
├── repositories/               # 本地数据仓储层（基于 Hive 的收藏、历史、下载、搜索历史与弹幕屏蔽仓储）
│
├── request/                    # 网络请求层
│   ├── apis/                   # 业务接口封装（Bangumi、弹幕、规则目录、以图搜番）
│   ├── clients/                # 按服务隔离的 HTTP 客户端
│   ├── config/                 # API 端点与常量配置
│   └── core/                   # Dio 工厂、网络配置、拦截器、ECH 传输适配与异常映射
│
├── services/                   # 业务服务与平台能力层
│   ├── deep_links/             # kazumi:// 深度链接解析与路由分发
│   ├── download/               # 离线下载管理、后台下载任务、目录授权与路径迁移
│   ├── logging/                # 日志服务（KazumiLogger）
│   ├── network/                # 代理管理、计费网络检测、镜像加速与代理感知图片缓存
│   ├── platform/               # 桌面窗口配置、刷新率、系统菜单、Windows 快捷方式与平台能力检测
│   ├── player/                 # 音频控制、外部播放器、DLNA 投屏、画中画、SyncPlay、截图导出与播放策略
│   ├── plugin/                 # XPath / API 规则引擎、站点 Cookie、人机验证、规则导入解析与有效性追踪
│   ├── shaders/                # Anime4K 着色器资源服务
│   ├── storage/                # Hive 存储管理（GStorage）、设置键（SettingsKeys）与缓存清理
│   ├── sync/                   # WebDAV、Bangumi 收藏、观看历史与弹幕屏蔽同步服务
│   ├── update/                 # 自动更新检查、下载源选择与安装包下载
│   └── video_source/           # 视频源地址解析服务（HTTP 解析、WebView 嗅探与解析池）
│
├── utils/                      # 无状态工具函数（并发控制、M3U8 解析与去广告、加解密、格式化、搜索解析等）
│
└── webview/                    # 跨平台 WebView 抽象与各平台实现（impl/）
    ├── captcha/                # 站点人机验证 WebView
    └── video/                  # 视频源嗅探 WebView
```
