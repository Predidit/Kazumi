# Upstream issue snapshot

## Scope, provenance, and confidence

Captured on 2026-07-17 from the parent repository Predidit/Kazumi.

- This checkout is the fork STERILITZIA02/KazumiIOS27. Its own GitHub Issues feature is disabled.
- The parent has three public branches: main, linux-external, and onboard. Issues are repository-level, so they cannot truthfully be attributed to a single branch.
- All 632 upstream issues carrying the bug label were read as metadata: 150 open and 482 closed.
- The bug label is automatically attached by the repository's issue form. The repository exposes no confirmed/triaged label, so there are no maintainer-evidence-confirmed technical tasks in the label metadata alone.
- The 150 open entries below are therefore reproduction candidates, not facts to blindly implement. For this project scope, only the Win11-specific section is actionable; the complete list is retained as a fetched archive, not a cross-platform task queue.
- Closed bug issues are historical reference, not future-task candidates. Query them when a related regression is being investigated.

Refresh commands:

    gh issue list --repo Predidit/Kazumi --state all --label bug --limit 1000 --json number,title,state,labels,createdAt,updatedAt,closedAt,url
    gh issue list --repo Predidit/Kazumi --state open --label bug --limit 1000 --json number,title,url

Approximate title-keyword counts among open candidates are: playback/decode/progress 53, sync/WebDAV/collection 30, search/rules/parse/network 22, UI/interaction 20, stability/storage/lifecycle 19. These categories overlap and do not prove root cause.

## Windows-specific priority candidates

These 19 open reports explicitly mention Windows, PC/desktop, MSIX, taskbar, or a Windows spelling variant. They are the only upstream issue candidates in scope for Win11 work. Reproduce and triage them before assuming an app-wide redesign is correct.

- [#417 Win版打开提示“存储初始化错误：检测到一个Kazumi实例已在运行”](https://github.com/Predidit/Kazumi/issues/417)
- [#630 PC偶现播放时快捷键失效问题](https://github.com/Predidit/Kazumi/issues/630)
- [#655 电脑端(Windows x64)播放器进度条不动](https://github.com/Predidit/Kazumi/issues/655)
- [#813 全屏下无法隐藏任务栏](https://github.com/Predidit/Kazumi/issues/813)
- [#865 windous最小至托盘会消失](https://github.com/Predidit/Kazumi/issues/865)
- [#1041 windows端无法自动同步观看记录](https://github.com/Predidit/Kazumi/issues/1041)
- [#1084 win版本无法使用webdav进行同步](https://github.com/Predidit/Kazumi/issues/1084)
- [#1132 Windows 10 22H2 提示 Wi-Fi 异常，报告称此前 issue 未解决](https://github.com/Predidit/Kazumi/issues/1132)
- [#1175 PC 的 WebDAV 无法同步](https://github.com/Predidit/Kazumi/issues/1175)
- [#1205 电脑端开启 TUN 模式无法检查更新](https://github.com/Predidit/Kazumi/issues/1205)
- [#1277 MSIX 安装包暂停后无法继续播放](https://github.com/Predidit/Kazumi/issues/1277)
- [#1327 电脑端获取动漫资源失败](https://github.com/Predidit/Kazumi/issues/1327)
- [#1539 桌面端按空格暂停会卡住](https://github.com/Predidit/Kazumi/issues/1539)
- [#1614 Windows 版本部分资源以三秒短段播放](https://github.com/Predidit/Kazumi/issues/1614)
- [#1711 Windows AMD Radeon R6 硬解有声无画面，关闭硬解崩溃](https://github.com/Predidit/Kazumi/issues/1711)
- [#1832 电脑端观看时出现错误提示](https://github.com/Predidit/Kazumi/issues/1832)
- [#1958 任务栏在屏幕上方时播放器全屏异常](https://github.com/Predidit/Kazumi/issues/1958)
- [#2247 PC 端同步设置问题](https://github.com/Predidit/Kazumi/issues/2247)
- [#2299 Windows 全屏后无法恢复原窗口大小](https://github.com/Predidit/Kazumi/issues/2299)

## Win11 repair evidence (2026-07-18)

The table below records what this checkout can currently prove. "Manual" is
not treated as fixed until the built Windows application has completed the
listed interaction. Reports whose issue body identifies Windows 10 or another
platform remain intentionally out of scope for this Win11-only delivery.

| Issue | Win11 disposition | Evidence and next gate |
| --- | --- | --- |
| #417 | Manual verification required | Current native host has single-instance activation; launch the release executable twice and verify the existing window activates without a storage-init error. |
| #630 | Manual verification required | Upstream 2.2.1 includes desktop-shortcut work. Exercise Space, arrows, fullscreen, volume, and repeated key presses during playback before claiming closure. |
| #655 | Out of scope | The report targets Windows 10, not the required Win11 environment. |
| #813 | Out of scope | The report targets Windows 10-era fullscreen/taskbar behavior; do not infer a Win11 defect from it. |
| #865 | Manual verification required | Minimize-to-tray, restore, fullscreen enter/exit, and repeated Escape must be exercised against the release build. |
| #1041 | Fixed with automated evidence; remote-service manual gate remains | History writes now feed a debounced/max-wait WebDAV scheduler, failures remain dirty for retry, and all exit paths perform a bounded flush. Covered by `history_auto_sync_scheduler_test.dart` and `history_repository_test.dart`. |
| #1084 | Out of scope | Issue environment is not the required Win11 target; retained as historical WebDAV context only. |
| #1132 | Out of scope | Explicit Windows 10 22H2 report. |
| #1175 | Out of scope | The issue evidence does not establish a current Win11 failure and predates the current sync implementation. |
| #1205 | Fixed with automated and live endpoint evidence | Update metadata tries the verified `api.kazumi.fyi` mirror, then the official GitHub API after transport/schema failure. Windows downloads retain mirror and source candidates, enforce HTTPS, size and SHA-256, then verify the SignPath publisher. Covered by update metadata, asset-policy, and artifact-verifier tests. |
| #1277 | Out of scope | Report targets a Windows 10 MSIX environment; no Win11 reproduction evidence. |
| #1327 | Confirmed loading-state defect fixed; source-specific reproduction unavailable | Search, source resolution, and video initialization now leave loading state and expose retry after failure without discarding existing results. Covered by `loading_state_recovery_test.dart`; the report does not include a durable rule needed to reproduce its remote source. |
| #1539 | Out of scope | Report environment is Windows 10. Win11 keyboard behavior is still included in the manual player gate. |
| #1614 | Not reproducible from supplied evidence | Report depends on a specific ACE rule/segmented media response that is not available in the issue. No playback algorithm change was made speculatively. |
| #1711 | Hardware-blocked, not claimed fixed | Requires an AMD Radeon R6 device and its driver/decoder path. Preserve the software-decoding fallback and do not guess at a hardware-specific fix. |
| #1832 | Out of scope | Issue environment is not confirmed as Win11 and its remote source is unavailable. |
| #1958 | Out of scope | Report concerns taskbar placement on Windows 10; no Win11 reproduction evidence. |
| #2247 | Partially hardened; manual WebDAV server gate required | WebDAV now rejects malformed/non-HTTP(S) endpoints before handing over credentials, resets stale initialization state on reconfiguration, bounds/quarantines remote history files, and keeps valid local HTTP servers compatible. The issue supplies no server response/logs, so service-specific closure would be false. |
| #2299 | Fixed with automated evidence; native-window manual gate remains | Fullscreen transitions now serialize rapid enter/exit requests instead of dropping the reverse request or committing optimistic state. Covered by five coordinator regression tests and a successful MSVC Windows release build. |

Related Win11-relevant defects found during the audit, rather than assumed from
an issue label, are also covered: bearer tokens are restricted to explicit
trusted Bangumi HTTPS requests; certificate verification is no longer globally
disabled; plugin request URLs/headers and episode URLs are validated; log output
redacts credentials/cookies/private URLs; Windows method-channel arguments are
type-checked; and external-player playlists reject injection and use bounded,
unique temporary files.

## Complete open bug-candidate archive (out of scope unless it also affects Win11)

- [#121 能识别到番剧的集数但还是无法播放](https://github.com/Predidit/Kazumi/issues/121)
- [#188 [Bug]: 内存初始化错误](https://github.com/Predidit/Kazumi/issues/188)
- [#309 [Bug]: 个别番解析超时但是网站可以播放（江苏）](https://github.com/Predidit/Kazumi/issues/309)
- [#339 [Bug]: [建议]WebDav可以上传无法下载](https://github.com/Predidit/Kazumi/issues/339)
- [#370 [Bug]: 历史记录似乎只能记录播放列表1？](https://github.com/Predidit/Kazumi/issues/370)
- [#386 [Bug]: 手势快进概率失效](https://github.com/Predidit/Kazumi/issues/386)
- [#417 [Bug]: Win版打开提示“存储初始化错误：检测到一个Kazumi实例已在运行”](https://github.com/Predidit/Kazumi/issues/417)
- [#435 播放器內部出錯怎麼辦](https://github.com/Predidit/Kazumi/issues/435)
- [#437 关于Kazumi鸿蒙版的一些小问题](https://github.com/Predidit/Kazumi/issues/437)
- [#443 [Bug]: ios更新1.4.5报错](https://github.com/Predidit/Kazumi/issues/443)
- [#463 [Android] 高倍速播放音画不同步](https://github.com/Predidit/Kazumi/issues/463)
- [#471 [Bug]: 一个不影响使用的小bug](https://github.com/Predidit/Kazumi/issues/471)
- [#499 [Bug]: 硬件解码有些番剧会卡住](https://github.com/Predidit/Kazumi/issues/499)
- [#530 [Bug]:暂停后再播放会出现无法播放](https://github.com/Predidit/Kazumi/issues/530)
- [#558 [Bug]: zsh: segmentation fault (core dumped) （段错误）](https://github.com/Predidit/Kazumi/issues/558)
- [#583 [Bug]: 编辑历史记录必须返回才能保存](https://github.com/Predidit/Kazumi/issues/583)
- [#589 [Bug]: 坚果云的webdav同步有并发限制](https://github.com/Predidit/Kazumi/issues/589)
- [#630 [Bug]: PC偶现播放时快捷键失效问题](https://github.com/Predidit/Kazumi/issues/630)
- [#655 [Bug]: 电脑端(Windows x64)播放器进度条不动](https://github.com/Predidit/Kazumi/issues/655)
- [#673 [Bug]: Linux点击番剧详情时闪退](https://github.com/Predidit/Kazumi/issues/673)
- [#676 [Bug]: Linux Mint Cinnamon 文字乱码](https://github.com/Predidit/Kazumi/issues/676)
- [#697 [Bug]: webdav功能无法使用](https://github.com/Predidit/Kazumi/issues/697)
- [#712 按键全屏和设备方向全屏的冲突问题](https://github.com/Predidit/Kazumi/issues/712)
- [#754 [Bug]播放器在NVIDIA设备上可能存在内存泄露](https://github.com/Predidit/Kazumi/issues/754)
- [#801 [iOS] iPhone 6s播放动画会在视频加载界面卡住并且闪退](https://github.com/Predidit/Kazumi/issues/801)
- [#813 [Bug]: 全屏下无法隐藏任务栏](https://github.com/Predidit/Kazumi/issues/813)
- [#831 [Bug]: 视频解析器在 macOS 10.15 x86 上发生 wkwebview 组件崩溃](https://github.com/Predidit/Kazumi/issues/831)
- [#856 [Bug]: 原站有资源，但由于要翻页所以未撷取到](https://github.com/Predidit/Kazumi/issues/856)
- [#865 [Bug]: windous最小至托盘会消失](https://github.com/Predidit/Kazumi/issues/865)
- [#869 [Bug]: 启动kazumi会连带n卡录制一起启动](https://github.com/Predidit/Kazumi/issues/869)
- [#910 [Bug]: 底栏图标样式显示错误](https://github.com/Predidit/Kazumi/issues/910)
- [#938 [Bug]: 弹幕检索错误: type 'Null' is not a subtype of type 'List<dynamic>' in type cast](https://github.com/Predidit/Kazumi/issues/938)
- [#942 [Bug]: 番剧名字过长时会点不到追番按钮](https://github.com/Predidit/Kazumi/issues/942)
- [#957 [Bug]: 從觀看記錄進入其他季彈幕與標題不是該季](https://github.com/Predidit/Kazumi/issues/957)
- [#971 DLNA搜索迟滞](https://github.com/Predidit/Kazumi/issues/971)
- [#992 [Bug]: 视频加载中选集时，向下滑动，滚动条自动返回当前集定位处](https://github.com/Predidit/Kazumi/issues/992)
- [#1002 [Bug]: webdav同步失败](https://github.com/Predidit/Kazumi/issues/1002)
- [#1011 [Bug]: 打开软件之后提示“正在使用wifi 网络异常”](https://github.com/Predidit/Kazumi/issues/1011)
- [#1041 [Bug]: windows端无法自动同步观看记录](https://github.com/Predidit/Kazumi/issues/1041)
- [#1084 [Bug]: win版本无法使用webdav进行同步](https://github.com/Predidit/Kazumi/issues/1084)
- [#1102 [Bug]: 软件逻辑方面](https://github.com/Predidit/Kazumi/issues/1102)
- [#1132 [Bug](之前在#1060有提交，因为问题一直没解决所以又投了一次): windows10 22H2系统在使用1.7.4版本时提示wifi异常](https://github.com/Predidit/Kazumi/issues/1132)
- [#1139 [Bug]: iPhone13mini 播放器缓存创建失败](https://github.com/Predidit/Kazumi/issues/1139)
- [#1140 [Bug]: 莫名其妙会跳几秒钟](https://github.com/Predidit/Kazumi/issues/1140)
- [#1175 [Bug]:PC的 Web Dav无法同步](https://github.com/Predidit/Kazumi/issues/1175)
- [#1198 [Bug]: 这种视频带播放器的会无法解析出来](https://github.com/Predidit/Kazumi/issues/1198)
- [#1199 [Bug]: 代理切换视频无法续播](https://github.com/Predidit/Kazumi/issues/1199)
- [#1203 [Bug]: 移动端播放器页面的切换下一集控件容易误触](https://github.com/Predidit/Kazumi/issues/1203)
- [#1205 [Bug]: 移动端开启代理或电脑端开启 TUN 模式无法检查更新](https://github.com/Predidit/Kazumi/issues/1205)
- [#1231 [Bug]: 安卓端  在竖屏滑动剧集列表会回弹，横屏正常](https://github.com/Predidit/Kazumi/issues/1231)
- [#1239 同步下载失败问题](https://github.com/Predidit/Kazumi/issues/1239)
- [#1246 [Bug]: 获取视频连接时剧集列表多次回滚](https://github.com/Predidit/Kazumi/issues/1246)
- [#1277 [Bug]: msix安装包 播放时暂停播放然后无法继续播放](https://github.com/Predidit/Kazumi/issues/1277)
- [#1280 无法同步追番列表](https://github.com/Predidit/Kazumi/issues/1280)
- [#1326 关于播放页面自动旋转](https://github.com/Predidit/Kazumi/issues/1326)
- [#1327 [Bug]: 电脑端获取动漫资源失败的问题](https://github.com/Predidit/Kazumi/issues/1327)
- [#1341 [Bug]: 首页推荐同时刷出两个相同卡片，并且响应点击的始终为其中之一](https://github.com/Predidit/Kazumi/issues/1341)
- [#1348 [Bug]: Linux平台下无法使用nvdec解码](https://github.com/Predidit/Kazumi/issues/1348)
- [#1358 [Bug]: 新版无法安装](https://github.com/Predidit/Kazumi/issues/1358)
- [#1393 [Bug]: 软件内更新异常](https://github.com/Predidit/Kazumi/issues/1393)
- [#1422 [Bug]: 多次开关弹幕同时启用超分辨率质量档时有大概率导致软件卡死](https://github.com/Predidit/Kazumi/issues/1422)
- [#1453 [Bug]: 其中一集无画面有声音](https://github.com/Predidit/Kazumi/issues/1453)
- [#1478 [Bug]: 播放器播放时进度随机自动跳转](https://github.com/Predidit/Kazumi/issues/1478)
- [#1511 弹幕行数减少的同时减少出现的弹幕数量](https://github.com/Predidit/Kazumi/issues/1511)
- [#1539 [Bug]: 桌面端按空格暂停会卡住，只能用鼠标暂停](https://github.com/Predidit/Kazumi/issues/1539)
- [#1544 [Bug]: 经常会莫名自动切换下一集](https://github.com/Predidit/Kazumi/issues/1544)
- [#1547 [Linux] 超分辨率质量档导致 nvidia 设备视频内容偏色](https://github.com/Predidit/Kazumi/issues/1547)
- [#1549 [Bug]: 点进番剧的时候，点开始观看按钮会误点到tag](https://github.com/Predidit/Kazumi/issues/1549)
- [#1560 [Bug]: Linux版本搜索栏无法输入中文](https://github.com/Predidit/Kazumi/issues/1560)
- [#1572 [Bug]: 历史记录重现](https://github.com/Predidit/Kazumi/issues/1572)
- [#1580 [Bug]: 部分番源搜索结果不完整](https://github.com/Predidit/Kazumi/issues/1580)
- [#1588 [Bug]: 一起看同步偏移](https://github.com/Predidit/Kazumi/issues/1588)
- [#1590 [Bug]: linux平台下从1.8.8版本开始无法播放](https://github.com/Predidit/Kazumi/issues/1590)
- [#1592 [Bug]: iPadOS26窗口模式下UI问题](https://github.com/Predidit/Kazumi/issues/1592)
- [#1614 [Bug]: 在新版的windows版本中部分网站解析的资源只会以三秒每个视频的情况播放](https://github.com/Predidit/Kazumi/issues/1614)
- [#1621 [Bug]: ios播放不连续问题](https://github.com/Predidit/Kazumi/issues/1621)
- [#1657 [Bug]: Webdav同步失败](https://github.com/Predidit/Kazumi/issues/1657)
- [#1664 [Bug]: 就是有一些动漫源可以正常使用，但是不久后需要开代理才能使用，甚至有些开代理也不能使用了](https://github.com/Predidit/Kazumi/issues/1664)
- [#1673 [Bug]: 完全缺失vulkan驱动的安卓设备打开应用时崩溃](https://github.com/Predidit/Kazumi/issues/1673)
- [#1693 [Bug]: 安卓九中的webdav似乎无法使用](https://github.com/Predidit/Kazumi/issues/1693)
- [#1711 [Bug][windows]: AMD Radeon R6 硬解有声无画面，关闭硬解则播放崩溃退出](https://github.com/Predidit/Kazumi/issues/1711)
- [#1713 [Bug]: 设置中打开 MenuAnchor 时，MenuAnchor 无法在列表滚动时自动关闭](https://github.com/Predidit/Kazumi/issues/1713)
- [#1735 [Bug]: Linux上intel和nvidia双显卡无法正常播放](https://github.com/Predidit/Kazumi/issues/1735)
- [#1755 [Bug]: 视频播放鬼跳](https://github.com/Predidit/Kazumi/issues/1755)
- [#1786 [Bug]: 看番全是36分钟宝宝巴士](https://github.com/Predidit/Kazumi/issues/1786)
- [#1802 [Bug]: 超分辨率可能导致视频播放偏慢](https://github.com/Predidit/Kazumi/issues/1802)
- [#1826 能否更新下载之后的视频弹幕到最新？有时下的时候弹幕不多。另外，在缓存视频里切弹幕挺诡异的，需要两次打开弹幕（我是安卓端）](https://github.com/Predidit/Kazumi/issues/1826)
- [#1828 [Bug]: webdav不明错误](https://github.com/Predidit/Kazumi/issues/1828)
- [#1832 [Bug]: 电脑端观看时候会有报错提示](https://github.com/Predidit/Kazumi/issues/1832)
- [#1836 [Bug]: 安卓折叠屏竖屏状态下全屏播放问题](https://github.com/Predidit/Kazumi/issues/1836)
- [#1839 [Bug]: iOS端无法使用远程投屏](https://github.com/Predidit/Kazumi/issues/1839)
- [#1862 [Bug]: 有时候只是左滑了一点但是会从头开始播放](https://github.com/Predidit/Kazumi/issues/1862)
- [#1870 [Bug]: 超分辨率使用画面卡顿降帧](https://github.com/Predidit/Kazumi/issues/1870)
- [#1872 [Bug]: 对于新番加入追番列表后，在评分人数大幅度更新后，但具体评分和评分人数似乎卡住不动](https://github.com/Predidit/Kazumi/issues/1872)
- [#1874 [Bug]:下载后的番剧无法投屏](https://github.com/Predidit/Kazumi/issues/1874)
- [#1878 [Bug]: 弹幕没加载出来](https://github.com/Predidit/Kazumi/issues/1878)
- [#1893 [Bug]: 配对Apple Watch后 DLNA功能无法使用](https://github.com/Predidit/Kazumi/issues/1893)
- [#1900 [Bug]: 收藏的番剧出现了丢失的情况](https://github.com/Predidit/Kazumi/issues/1900)
- [#1920 [Bug]: 播控中心图标异常](https://github.com/Predidit/Kazumi/issues/1920)
- [#1936 [Bug]: 开启动态配色后设置卡片的问题](https://github.com/Predidit/Kazumi/issues/1936)
- [#1941 [Bug]: WebDAV 上传失败: DioException [bad response] 当服务端返回 201 + HTML 响应体时](https://github.com/Predidit/Kazumi/issues/1941)
- [#1946 [Bug]: 存储初始化错误](https://github.com/Predidit/Kazumi/issues/1946)
- [#1951 [Bug]: kazumi闪退](https://github.com/Predidit/Kazumi/issues/1951)
- [#1953 [Bug]:](https://github.com/Predidit/Kazumi/issues/1953)
- [#1958 [Bug]: 任务栏位于屏幕上方时播放器全屏问题](https://github.com/Predidit/Kazumi/issues/1958)
- [#1965 [Bug]: 全屏后退出到详情页时 画面会自动全屏一次](https://github.com/Predidit/Kazumi/issues/1965)
- [#1976 [Bug]: 进度条对应问题](https://github.com/Predidit/Kazumi/issues/1976)
- [#1986 [Bug]: 播放器内部出现问题，无法观看任何番剧](https://github.com/Predidit/Kazumi/issues/1986)
- [#2015 [Bug]: Flatpak version background instance is inaccessible](https://github.com/Predidit/Kazumi/issues/2015)
- [#2016 [Bug]: 熄屏会让暂停的视频继续播放](https://github.com/Predidit/Kazumi/issues/2016)
- [#2021 [Bug]: webDav同步的证书错误](https://github.com/Predidit/Kazumi/issues/2021)
- [#2027 [Bug]: 历史记录和已下载内容意外消失（列表清空）](https://github.com/Predidit/Kazumi/issues/2027)
- [#2039 [Bug]: 视频解析完成后，会直接导致软件退出](https://github.com/Predidit/Kazumi/issues/2039)
- [#2044 [Bug]: 频繁卡顿](https://github.com/Predidit/Kazumi/issues/2044)
- [#2053 [Bug]: 方向键失灵](https://github.com/Predidit/Kazumi/issues/2053)
- [#2067 [Bug]: 番剧详情页背景问题](https://github.com/Predidit/Kazumi/issues/2067)
- [#2071 mac添加取消自动熄屏的功能建议](https://github.com/Predidit/Kazumi/issues/2071)
- [#2075 [Bug]: 番剧角色图片无法正常显示](https://github.com/Predidit/Kazumi/issues/2075)
- [#2077 [Bug]: 同步后，收藏里的所有番剧消失](https://github.com/Predidit/Kazumi/issues/2077)
- [#2081 [Bug]: mac上的Kazumi](https://github.com/Predidit/Kazumi/issues/2081)
- [#2084 [Bug]: 选集和内容匹配错误](https://github.com/Predidit/Kazumi/issues/2084)
- [#2101 F-Droid reproducible build failed](https://github.com/Predidit/Kazumi/issues/2101)
- [#2103 [Bug]: 右半边屏幕上下滑动的音量控制不平衡](https://github.com/Predidit/Kazumi/issues/2103)
- [#2109 [Bug]: 历史记录可优化逻辑](https://github.com/Predidit/Kazumi/issues/2109)
- [#2118 [Bug]: 7sefun源下载程序崩溃](https://github.com/Predidit/Kazumi/issues/2118)
- [#2124 [Bug]: 历史记录同步失败](https://github.com/Predidit/Kazumi/issues/2124)
- [#2140 [Bug]: When the button for checking for updates is clicked, an error message indicating "Update failed" is displayed.](https://github.com/Predidit/Kazumi/issues/2140)
- [#2155 [Bug]: webdav无法同步.](https://github.com/Predidit/Kazumi/issues/2155)
- [#2161 在线观看时没有广告，下载缓存的视频有广告。](https://github.com/Predidit/Kazumi/issues/2161)
- [#2166 [Bug]: 仅依赖 video/* MIME 导致部分 MP4 视频源解析超时](https://github.com/Predidit/Kazumi/issues/2166)
- [#2191 储存错误](https://github.com/Predidit/Kazumi/issues/2191)
- [#2243 [Bug][Darwin]: 更新后本地缓存消失](https://github.com/Predidit/Kazumi/issues/2243)
- [#2247 [Bug]: pc端同步设置bug](https://github.com/Predidit/Kazumi/issues/2247)
- [#2265 [Bug]: 部分视频播放异常](https://github.com/Predidit/Kazumi/issues/2265)
- [#2276 [Bug]: kazumi规则示例里的规则无法使用](https://github.com/Predidit/Kazumi/issues/2276)
- [#2288 [Bug]: 储存初始化错误](https://github.com/Predidit/Kazumi/issues/2288)
- [#2289 [Bug]: 在开始播放的时候发生闪退](https://github.com/Predidit/Kazumi/issues/2289)
- [#2290 [Bug]: macOS 10.15 Catalina下发生闪退](https://github.com/Predidit/Kazumi/issues/2290)
- [#2299 [Bug]: Windows全屏后无法恢复原窗口大小](https://github.com/Predidit/Kazumi/issues/2299)
- [#2301 [Bug]: 播放时分为短段播放](https://github.com/Predidit/Kazumi/issues/2301)
- [#2302 [Bug]: 发送弹幕后，播放界面UI不能收起](https://github.com/Predidit/Kazumi/issues/2302)
- [#2304 [Bug]: 搜索番剧功能开启 隐藏已看，功能异常](https://github.com/Predidit/Kazumi/issues/2304)
- [#2314 [Bug]: 开超分辨率时耗电太快了](https://github.com/Predidit/Kazumi/issues/2314)
- [#2329 [Bug]: linux下搜索任意都为空无法找到任何番剧](https://github.com/Predidit/Kazumi/issues/2329)
- [#2333 [Bug]: 无法进入系统，初始化错误](https://github.com/Predidit/Kazumi/issues/2333)
- [#2334 [Bug]: 无法连接WebDAV](https://github.com/Predidit/Kazumi/issues/2334)
- [#2335 [Bug]: 番剧搜索异常](https://github.com/Predidit/Kazumi/issues/2335)
- [#2341 [Bug]: 2.2.0版本多客户端无法同步](https://github.com/Predidit/Kazumi/issues/2341)
- [#2347 [Bug]: 在低内存下观看视频时软件大概率崩溃的问题](https://github.com/Predidit/Kazumi/issues/2347)
- [#2362 弹幕和番剧问题[Bug]:](https://github.com/Predidit/Kazumi/issues/2362)
