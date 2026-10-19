# iOS 画中画

在 iOS 15 及以上、支持系统画中画的设备上，播放视频后点击播放器右上角的「画中画」按钮进入小窗。支持系统播放 / 暂停、快进 / 快退、关闭及返回播放器。暂不自动进入画中画。

画中画复用当前 media-kit 播放器，不重新请求播放地址；进度、倍速、请求头、代理、缓存和离线视频继续沿用原有配置。Flutter 绘制的弹幕和字幕覆盖层不显示在小窗中。

进入小窗期间及小窗激活时，切到后台会继续播放。关闭小窗后，如果应用仍在后台且未启用「后台播放」，则暂停视频；通过系统按钮返回播放器时保留播放状态。离开播放器页面时释放画中画会话。

## 实现与限制

- 使用 `AVPictureInPictureController` 的 sample-buffer content source，通过 Flutter 的公开纹理注册接口取得 media-kit 渲染的视频帧。插件方法委托原样转发，不修改 pub 缓存或生成的插件注册文件。
- media-kit iOS 的 OpenGL ES 输出不能在后台持续渲染，因此仅在画中画期间切到软件输出，保留同一个 mpv 播放器。切换前保存视频轨道并设置 `vid=no`，新纹理注册后恢复轨道，避免释放活动 render context 导致视频被禁用。退出后在前台恢复原渲染器；后台关闭则延迟至前台恢复 GPU 输出。
- 输出切换调用 media-kit 插件通过 `publish` 提供的原生 `setSoftwareRendering` 接口，输出配置、尺寸及原生实例生命周期由 media-kit 持有。Kazumi 负责切换前暂停视频轨道、完成后恢复轨道，以及仅在前台恢复 GPU。`changed` / `unchanged` / `notReady` / `failed` 区分是否需要等待新纹理，以及是否可以在初始化结束后重试；失败也会尝试恢复轨道。画中画期间新建的输出也使用软件模式，并保留其原始 GPU 配置以便恢复。
- 上述接口在 [media-kit PR #41](https://github.com/Predidit/media-kit/pull/41) 中提出，由配套的 [media-kit 提交](https://github.com/sibogentleman/media-kit/commit/74384bd3941afbb769289e8ba086e3a776701c8e) 提供。`media_kit` 与 `media_kit_video` 在 `pubspec.yaml` 和 lockfile 中锁定同一远端提交，无需本地路径覆盖。该提交同时保留上游 OHOS native-assets 支持、Android 1.3.1 bundles 与 PiP 所需的渲染 API。依赖改动合入上游后，可将两项依赖一起切回上游对应提交。
- 支持画中画的 iOS 设备使用 `auto-copy` / `videotoolbox-copy` 硬件解码路径。正常播放保留 GPU 超分辨率，画中画期间不应用 GPU 超分辨率。
- mpv 的 `bgr0` 第四字节不是 alpha。复制到独立的 BGRA 缓冲区时将 alpha 设为 255；AVKit 使用最多三个缓冲区，来不及消费时丢弃新帧。软件输出和帧复制会增加 CPU、内存带宽及耗电，高分辨率 / 高帧率仍需评估性能。
- 等待有效视频帧及 AVKit 可显示后才启动小窗；进入失败 / 超时会清理显示层并恢复输出。页面销毁会等待进行中的输出切换完成，新页面会等待旧原生会话释放。
- 最低部署版本为 iOS 15，与当前 Flutter SDK 要求一致；`Info.plist` 已启用 `audio` 后台模式。模拟器能否测试取决于系统的 `isPictureInPictureSupported()`，以真机结果为准。

## 验证

```sh
flutter test --no-pub
flutter analyze --no-pub --no-fatal-infos --fatal-warnings
flutter build ios --release --no-codesign --no-pub
```

真机验证：2.3.8（20310）已在 iOS 27.0.1、iPhone 16 Pro 上覆盖安装并通过启动检查，包含本次同步原语、MobX 状态及 media-kit 公开接口改造。用户于 2026-10-12 确认已完成测试；未逐项提供下述性能与兼容性场景的结果。此前 20309 的进入小窗、返回 App、关闭小窗后的画面和声音也已由用户确认正常。

2026-10-12 针对当时的 media-kit 配套实现完成验证：261 项 Flutter 测试通过；静态分析无错误和警告（17 条已有 info）；iOS Release 无签名编译通过。media-kit 的 14 项原生逻辑和线程测试通过，使用真实 manager / worker 以及可控的纹理替身，覆盖初始化、失败回滚、销毁、后台渲染保护及临时未就绪状态，不代表真实 GPU 验收。

2026-10-12 的 16 项 Swift XCTest 已通过 `build-for-testing` 编译，覆盖插件原样转发、像素引用释放、输出切换及前后台恢复。当时执行受本机 CoreSimulator 的 `runtime path not found` 错误阻塞，未取得运行结果。

2026-10-17 依赖整合验证：Flutter 3.47.7 / Dart 3.13.5 下，256 项 Flutter 测试通过，静态分析无错误或警告（17 条已有 info），iOS Release 无签名构建通过，版本保持 2.3.9（20309）。16 项 XCTest 在 arm64 / x86_64 模拟器目标上编译通过；本机模拟器启动仍报 `runtime path not found`，未取得运行结果。整合后的 media-kit 在 Flutter 3.47.6 下通过 27 项 hook/core 和 7 项 lifecycle/video binding 测试，另有 14 项原生渲染模式测试通过。本次未重新验证真机 PiP 或 OHOS 构建与设备运行。

2026-10-19 依赖整合验证：使用现有 Flutter 3.47.7 / Dart 3.13.5，256 项 Flutter 测试通过，静态分析无错误或警告（17 条已有 info），iOS Release 无签名构建通过。16 项原生 XCTest 已在 iOS 27.0 模拟器上实际执行，全部通过（0 失败）。media-kit 的 27 项 hook/core、7 项 lifecycle/video binding 和 14 项原生渲染测试通过；四个 Android 1.3.1 bundle 均已下载并通过 SHA-256 校验。本次未验证 Android 设备播放、真机 PiP 或 OHOS 构建与设备运行。

后续真机回归项目：

1. 横屏、竖屏及全屏进入小窗，切到桌面后音视频持续播放。
2. 系统播放 / 暂停、快进 / 快退、倍速后的进度及音画同步。
3. 关闭 / 返回播放器后主画面恢复，再次进入小窗。
4. 后台播放设置关闭 / 开启时的关闭行为；切集、连播、退出页面及反复进入 / 退出。
5. 开启超分辨率、在线 MP4 / HLS、带请求头的源、离线源、缓冲状态及不同视频尺寸。
6. 高分辨率 / 高帧率的 CPU、内存、耗电与长时间播放稳定性。
