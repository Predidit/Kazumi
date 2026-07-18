# Kazumi Windows 11 frontend inventory and release matrix

This document is the source-of-truth checklist for the iOS27-inspired Windows
frontend migration. A route or state is not considered reviewed merely because
it inherits the global theme.

## Visual system contract

- Geometry: 12 px controls/images, 16 px compact cards, 20 px standard
  surfaces, 24 px sheets, and 28 px dialogs/large panels.
- Spacing: a 4 px base grid with 8/12/16/20/24/32 px semantic steps.
- Depth: opaque tonal surfaces by default; glass is reserved for navigation,
  transient overlays, and bounded desktop chrome. Text never sits directly on
  an unbounded blur.
- Interaction: hover, focus-visible, pressed, selected, disabled, and loading
  roles are derived from the active ColorScheme. Keyboard focus must remain
  visible in light, dark, dynamic-color, OLED, and Windows high-contrast modes.
- Motion: 90/160/240/360 ms durations with interruptible standard/emphasized
  curves. Reduced-motion and accessible-navigation settings suppress decorative
  motion. MediaKit and WebView surfaces never receive backdrop blur.
- Layout: 720 px is the shell navigation breakpoint. Content is constrained at
  1,200 px where a full-width desktop canvas would harm readability, while
  player and media surfaces remain unconstrained.

## Reachable route inventory

| Area | Routes and visible states | Implementation ownership |
| --- | --- | --- |
| Bootstrap | `/`, `/onboarding`, `/error`, storage error | `init_page.dart`, onboarding steps, `storage_error_page.dart`, `route_error_page.dart` |
| Desktop shell | `/tab/popular`, `/tab/timeline`, `/tab/collect`, `/tab/my` | `menu.dart`, four tab pages, shared cards/app bars |
| Search | `/search`, `/search/:tag`, `/search/image` | search controller/pages, adaptive workbench sheet, result cards |
| Subject details | `/info`, character sheet/page, rating dialog, source sheet and captcha/alias/manual-search dialogs | info controller/pages/tabs, reusable comment/character/staff cards |
| Playback | `/video`, smallest/regular panels, HUDs, danmaku/chat sheets, episode/comments sheets, SyncPlay dialogs, debug/source menus | video/player controllers and all `pages/player` surfaces |
| Library | `/settings/history`, `/settings/download`, `/settings/download-settings` | history/download pages, download cards, episode sheet |
| Rules | `/settings/plugin`, `/shop`, `/test`, `/editor` | plugin pages, catalog/editor sections, `RuleCard` |
| Playback settings | `/settings/player`, `/decoder`, `/renderer`, `/super`, `/danmaku`, `/danmaku/shield`, `/keyboard` | settings pages and adaptive setting sheets |
| App/network settings | `/settings/theme`, `/theme/display`, `/interface`, `/proxy`, `/proxy/editor`, `/webdav`, `/webdav/editor`, `/bangumi` | settings pages, Kazumi settings rows, sync progress dialogs |
| Support | `/settings/about`, `/about/logs`, `/about/license`, image preview | about/log pages, Material license route, image viewer |
| Desktop lifecycle | title bar, resize, narrow width, tray hide/restore, close confirmation, fullscreen enter/exit, second-instance activation | app widget, native runner, menu shell, player |

## Mandatory state matrix

Each applicable surface is checked at 1280x800, a narrow 680 px desktop width,
and Windows scaling/text scale at 100% and 150% in both light and dark themes.

| Component/state | Required checks |
| --- | --- |
| Navigation | idle, hover, focus-visible, pressed, selected, keyboard traversal, route retention |
| Cards and rows | idle, hover, focus-visible, pressed, disabled, selected/edit mode, long title and subtitle |
| Async content | initial loading, pagination loading, refresh, empty, offline/error, retry, stale-content-with-error |
| Forms | empty, valid, malformed, focused, validation error, secret obscured/revealed, submit disabled/in-flight |
| Dialogs/sheets | compact/wide, focus trap, Escape, barrier policy, scrolling/overflow, destructive action, progress/success/error |
| Player | loading, playing, paused, seeking, controls hidden/visible, fullscreen, narrow panel, offline, source failure, hardware fallback |
| Window | first launch, restart, resize, minimize/restore, tray hide/restore, close choice, theme change, fullscreen/taskbar, second launch |

## Win11 functional parity matrix

| Capability | Automated evidence | Manual release-build gate |
| --- | --- | --- |
| Navigation/search/details | search focus and loading recovery tests | Traverse every route, back/forward, tag and image search |
| Collection/history/downloads | repository, merge, async-session tests | Edit/delete, resume online/offline, queue/pause/resume downloads |
| Player/danmaku | episode mapping, fullscreen coordinator, cancellation tests | Keyboard/mouse controls, seek, volume, subtitles/danmaku, screenshot, fullscreen |
| Rules/plugins/WebViews | rule-engine and input-policy tests | Shop/import/edit/test, captcha path, source switch and retry |
| WebDAV/Bangumi sync | history/collect merge, scheduler, auth-boundary tests | Configure a reachable account, sync, interrupt/retry, exit flush |
| Proxy/update | URL policy, metadata fallback, asset/hash/signature tests | Valid/invalid proxy UI, manual update check behind current network |
| Settings/logs | analyzer and widget coverage | Toggle every setting, restart persistence, log copy/clear |
| Windows lifecycle | native Release build and method-boundary tests | tray, close confirmation, second instance, resize, taskbar/fullscreen |

## Evidence policy

Screenshots must come from the final running Release build. Each major route
needs a normal-state capture; loading/empty/error states may use deterministic
local test conditions when the live service cannot safely provide them. Any
unavailable account, hardware, server, or remote rule is recorded as a manual
limitation rather than represented as a completed check.

## Implemented frontend migration (2026-07-18)

| Area | Implemented state | Main ownership |
| --- | --- | --- |
| Tokens and theme | Shared radius, glass, glow, shadow, spacing, motion, focus, hover, pressed, selected and disabled roles; Material component families use smooth superellipse geometry | `lib/design_system/kazumi_design_tokens.dart`, `kazumi_theme.dart` |
| Reusable surfaces | Bounded real blur, high-contrast opaque fallback, unclipped outer glow, interactive keyboard surface, icon badge, state panel and non-sampling player chrome | `lib/design_system/kazumi_surfaces.dart` |
| App shell | Ambient dual glow, glass app bar, responsive glass NavigationBar/NavigationRail, real Kazumi logo, scrollable short-height rail, selected popular-category menu | `lib/app_widget.dart`, `lib/bean/appbar/sys_app_bar.dart`, `lib/pages/menu/menu.dart`, `lib/pages/popular/popular_page.dart` |
| Settings | Local settings implementation replaces `card_settings_ui`; one keyboard stop and merged control semantics; bounded readable width; transparent leaf routes preserve the app backdrop | `lib/design_system/kazumi_settings.dart`, `lib/pages/settings/**`, `lib/pages/webdav_editor/**`, `lib/pages/bangumi/bangumi_setting.dart` |
| Dialogs and sheets | Smooth sheet/dialog geometry, in-glass 48 px keyboard-accessible drag handle, compact/wide rating layout, keyboard score adjustment and bounded adaptive sheets | `lib/bean/dialog/**`, `lib/pages/info/rating_review_dialog.dart` |
| Player | Regular/compact controls, HUDs and desktop side panel use simulated liquid glass without `BackdropFilter`; selected source, episode, speed, ratio, super-resolution and timer choices include icons and selected semantics | `lib/pages/player/**`, `lib/pages/video/video_page.dart` |
| Search, details and rules | Search/category/filter selection no longer relies only on color; source statuses have distinct icons/labels; rules expose keyboard-reachable multi-select and move-up/down commands | `lib/bean/widget/custom_dropdown_menu.dart`, `lib/pages/search/**`, `lib/pages/info/source_sheet.dart`, `lib/pages/plugin_editor/**` |
| Onboarding and responsive layout | Windows minimum size is 480x360; short/high-scale onboarding content scrolls; action bar reflows; rating dialog changes to the side panel only at the exact safe breakpoint | `lib/main.dart`, `lib/pages/onboarding/**`, `lib/pages/info/rating_review_dialog.dart` |
| Accessibility and motion | High contrast removes decorative blur/glow, reduced motion disables themed button/Hero/image/skeleton/player decoration motion, focus rings remain visible, selected states include non-color cues | `lib/app_widget.dart`, design-system files, affected cards/menus/player pages |

The migration deliberately leaves network targets, authentication, request
construction, persistence and player controller behavior unchanged. Player and
WebView-adjacent surfaces explicitly disable backdrop sampling to avoid adding
Windows GPU risk.

## Automated delivery evidence (2026-07-18)

| Gate | Result |
| --- | --- |
| Changed Dart formatting | Passed: all changed Dart files formatted with Dart 3.12.2 |
| `flutter pub get` | Passed; obsolete `card_settings_ui` dependency removed from the lockfile |
| `flutter analyze --no-fatal-infos --fatal-warnings` | Passed: no issues found |
| `flutter test test/design_system_test.dart` | Passed: 22/22 design, keyboard, semantics, motion, high-contrast and responsive tests |
| `flutter test` | Passed: 192/192 tests |
| `flutter build windows --release` | Passed: Windows x64 runner produced |
| Release artifact | `build/windows/x64/runner/Release/kazumi.exe`, 210,432 bytes, SHA-256 `441C78F7DF752370ACFE00998B8A03E669C089C61AA510221FFF5B24C7860B60` |

The build still prints the existing non-fatal `Nuget is not installed` message
and a CMake developer-policy warning from `webview_windows`; compilation and
linking succeed. No generated `*.g.dart` file was edited.

## Change-to-evidence matrix

| Changed behavior | Automated evidence | Remaining manual evidence |
| --- | --- | --- |
| Smooth component geometry and bounded glass | Shape/clip/blur/high-contrast widget tests | Light/dark screenshots of shell, cards, dialogs and settings |
| Keyboard, focus, enabled/disabled and selected states | Interactive surface, settings tile, dropdown and rating keyboard/semantics tests | Tab/Shift+Tab pass through every route and popup |
| Narrow/high-scale responsiveness | 480x360 at 150%, 200% and 225%; rating 720px and exact 887/888px tests | Live resize through 719/720/721px and Windows display scaling |
| Reduced motion and high contrast | Zero-duration theme, Hero/image/skeleton/player fallbacks and no-blur tests | Toggle Windows settings while the Release build is running |
| Player-safe glass | Player chrome and adaptive player sheet prove no `BackdropFilter` | Real MediaKit playback, HUD/menu interaction and GPU smoothness |
| Functional parity | Full 192-test suite plus successful Release build | Remote sources, accounts, downloads, tray/window and fullscreen lifecycle |

## Manual Release acceptance still required

Automated checks cannot truthfully replace a live Win11 visual and remote-flow
pass. Run the final Release binary and record screenshots only after verifying:

1. First launch/onboarding at 480x360, 1280x800 and a maximized window; resize
   across 719/720/721 px and confirm navigation changes without clipping.
2. Popular, timeline, collection, My, search, image search, subject details,
   history and downloads in light/dark themes; inspect loading, empty, error,
   selected and long-text states.
3. All settings routes, rule shop/editor/test, WebDAV/Bangumi/proxy editors and
   modal sheets; use Tab, Shift+Tab, Enter, Space, arrows and Escape.
4. Real playback: play/pause, seek, speed, aspect ratio, source, episode,
   super-resolution, danmaku, HUDs, screenshot, fullscreen and compact window.
5. Windows high contrast, reduced motion and 150%/225% text scaling; confirm
   focus remains visible and blur/animation fallbacks are readable.
6. Tray hide/restore, minimize/restore, close confirmation, second-instance
   activation, theme change, fullscreen/taskbar restoration and app restart.
7. A reachable WebDAV/Bangumi account, proxy/update check, rule source and
   download; interrupt/retry failures and verify saved settings after restart.

No final screenshots are claimed in this document yet. They must come from the
user's manual pass of this exact Release artifact; mocked or pre-build images do
not satisfy the evidence policy.
