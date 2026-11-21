## 1.2.5
- fix: subtitleView not being updated
- fix: mobile double tap areas hidden but still mounted
- fix: mobile center click is delayed

- feat: desktop video controls mouse hides with controls
- feat: desktop on tap pause and play
- feat: desktop on double tap fullscreen
- fix: windows crash by @Airyzz [#900](https://github.com/media-kit/media-kit/pull/900)
- feat: auto pass changes to fullscreen without having to call .update

## 1.2.4

- fix: web compile error

## 1.2.3

- feat: `VideoState.update` & `VideoViewParameters`

## 1.2.2

- fix: override `setState` & check `mounted` in `MaterialVideoControls` & `MaterialDesktopVideoControls`

## 1.2.1

- fix(android): clear `android.view.Surface` before playback
- feat: `MaterialVideoControlsThemeData.seekBarAlignment`

## 1.2.0

- fix: `MaterialVideoControls` layout

## 1.1.9

- fix: unmount `CircularProgressIndicator` buffering indicator if invisible
- fix: pass all video attributes to fullscreen route
- fix: prevent controls from hiding during seek
- fix: hide last video's frame upon `Player.open`
- fix: `ThemeData.copyWith` override
- fix(android): `hwdec=auto-safe` w/ `enableHardwareAcceleration=true`
- fix(windows): fullscreen for non-primary monitors
- fix(darwin): `mpv_render_context_free` call
- fix(darwin): memory leaks
- fix(ios): fix `disposeMPV`
- feat: `VideoControllerConfiguration.androidAttachSurfaceAfterVideoParameters`
- feat: center the seek-bar within its parent `Container` for improved tap area
- feat: `backdropColor` argument in `MaterialVideoControlsThemeData`

## 1.1.8

- fix: pass all `*VideoControlsTheme`(s) to fullscreen `context`

## 1.1.7

- fix: add `await` to `maybePop` when exiting fullscreen
- fix: `MaterialVideoControls`/`MaterialDesktopVideoControls` seekbar glitch
- fix(android): S/W rendering fallback
- fix(android): create fresh `android.view.Surface` for every video output

## 1.1.6

- fix: programmatic fullscreen API
- fix(android): pause upon entering fullscreen
- fix(android): `waitUntilFirstFrameRenderedNotify` in `FlutterFragmentActivity`

## 1.1.5

- fix(android): `waitUntilFirstFrameRenderedNotify` fallback & release-mode

## 1.1.4

- feat: `Video` `resumeUponEnteringForegroundMode`
- feat(android): `waitUntilFirstFrameRenderedNotify` implementation

## 1.1.3

- feat(android): `VideoControllerConfiguration.scale`
- fix(android): use `hwdec=auto`
- fix(android): `SurfaceTexture.setDefaultBufferSize` & render race

## 1.1.2

- fix(windows): memory leak in `GetVideoWidth`/`GetVideoHeight`
- fix(linux): `GThread*` leak in S/W render & `video_output_get_(width|height)`
- fix(linux): H/W support for multiple videos
- build(darwin): bump `mpv` headers to `0.36.0`
- build(darwin): use symlinks for `FRAMEWORK_SEARCH_PATHS`, `media_kit_libs_*** >= 1.1.0`
- fix(darwin): remove black screen when switching videos ([#332](https://github.com/media-kit/media-kit/issues/332))
- feat: `Video`: expose `onEnterFullscreen` & `onExitFullscreen`
- feat: feat: `visibleOnMount` `MaterialVideoControls`/`MaterialDesktopVideoControls`
- fix: display `bufferingIndicatorBuilder` even if controls are hidden

## 1.1.1

- chore: `try`/`catch` native calls to hide stray logs
- fix: `MaterialDesktopVideoControls`: do not add `onTapUp` callback if `toggleFullscreenOnDoublePress` is disabled

## 1.1.0

- feat: `SubtitleView`, `SubtitleViewConfiguration`
- feat: `shiftSubtitlesOnControlsVisibilityChange` in `MaterialVideoControls` & `MaterialDesktopVideoControls`
- feat: apply rotation from metadata to video output
- feat: improve wakelock behavior
- feat: `pauseUponEnteringBackgroundMode`
- fix: `bufferingIndicatorBuilder` padding in `MaterialVideoControls` & `MaterialDesktopVideoControls`
- fix(windows): maintain aspect ratio in s/w rendering pixel-buffer size clamping
- fix(linux): maintain aspect ratio in s/w rendering pixel-buffer size clamping
- perf(android): use `hwdec=mediacodec` w/ `enableHardwareAcceleration`
- deps: migrate [`package:wakelock_plus`](https://pub.dev/packages/wakelock_plus)

## 1.0.2

- fix(video/macos): fix fullscreen support

## 1.0.1

- fix: synchronize `VideoController` constructor
- fix: `fullscreen` video controls theme data not being applied

## 1.0.0

- feat: web support
- feat: fullscreen API
- feat: acquire wakelock
- feat: support for AGP 8.0
- feat: pre-built video controls
- feat: `controls` argument in `Video` widget
- feat: `AdaptiveVideoControls`, `MaterialVideoControls`, `MaterialDesktopVideoControls` & `NoVideoControls`

## 0.0.12

- fix(android): improve `Texture` resize handling

## 0.0.11

- fix(android): improve `Texture` resize handling

## 0.0.10

- feat: `VideoControllerConfiguration`
- feat: `VideoController.waitUntilFirstFrameRendered`
- refactor: clean-up package structure
- refactor: remove `VideoController.dispose`
- refactor: `VideoController.create` -> `VideoController` constructor
- fix(android): add `av1` to `hwdec-codecs`
- fix(android): use `--vo=gpu` + `--hwdec=mediacodec-copy` /w `enableHardwareAcceleration`

## 0.0.9

- fix(android): revert to `--vo=mediacodec_embed` in `enableHardwareAcceleration`

## 0.0.8

- fix(android): subtitle rendering
- fix(android): video rendering inside emulators (#149)
- fix(android): video rendering with `enableHardwareAcceleration: false`

## 0.0.7

- fix(linux): VAAPI hardware acceleration
- perf(windows): `VideoOutput::Resize`: delete texture objects in background

## 0.0.6

- fix(windows): synchronize texture object deletion in on unregister _v.i.z_ `VideoOutput::Resize` or `VideoOutput::~VideoOutput`

## 0.0.5

- Android support
- feat: `VideoController.setSize`
- fix: set `vo` to `libmpv` before creating render context
- refactor: `VideoController.create` takes `Player` reference instead of `handle`

## 0.0.4

- fix: use `mkdir` instead of `.gitkeep`

## 0.0.3

- fix: add `.framework` & `.xcframework` for all libs

## 0.0.2

- macOS support:
  - Hardware: MPV_RENDER_API_TYPE_OPENGL + pixel buffer + METAL
  - Software: MPV_RENDER_API_TYPE_SW + pixel buffer
- iOS support:
  - Hardware: MPV_RENDER_API_TYPE_OPENGL + pixel buffer
  - Software: MPV_RENDER_API_TYPE_SW + pixel buffer
- fix(windows): use `TextureRegistrar::UnregisterTexture` release callback to free texture resources
- fix(windows): synchronize texture unregister & release on frame dimensions change
- feat: `aspectRatio` parameter for `Video` widget

## 0.0.1

- Initial release
- Windows support:
  - Hardware: MPV_RENDER_API_TYPE_OPENGL + ANGLE + DirectX 11
  - Software: MPV_RENDER_API_TYPE_SW + pixel buffer
- GNU/Linux support:
  - Hardware: MPV_RENDER_API_TYPE_OPENGL + GDK/GL
  - Software: MPV_RENDER_API_TYPE_SW + pixel buffer
