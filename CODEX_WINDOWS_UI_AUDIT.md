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
| App/network settings | `/settings/theme`, `/theme/display`, `/interface`, `/proxy`, `/proxy/editor`, `/webdav`, `/webdav/editor`, `/bangumi` | settings pages, Card Settings rows, sync progress dialogs |
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
