# KazumiIOS27 project index

## Snapshot and repository topology

- Local checkout: D:\devSpace\kazumi
- Current revision: 1793d22 (tag 2.2.1, message: version 2.2.1)
- Working branch: main, tracking origin/main
- Fork origin: STERILITZIA02/KazumiIOS27
- Parent upstream: Predidit/Kazumi
- Local upstream remote is configured and fetched. Its public branches are upstream/main, upstream/linux-external, and upstream/onboard.
- At this snapshot, main and upstream/main have no divergence (ahead 0, behind 0).
- GitHub issues are repository-level, not branch-level. The fork disables issues; upstream is the authoritative issue tracker.

Read CODEX_UPSTREAM_ISSUES.md for the captured upstream backlog and the current Windows-specific candidates.
Read CODEX_WINDOWS_UI_AUDIT.md for the complete Win11 route, state, visual, and
functional-parity release matrix.

## Scope and supported local workflow

The requested build and development target is Windows 11 desktop only. The UI may adopt an iOS27-inspired design language, but this does not make iOS compilation a local requirement. Ignore bugs and development requirements that are specific to Android, iOS, macOS, or Linux; only touch shared Flutter code when it is necessary for a verified Win11 behavior.

- Flutter SDK: 3.44.6 at D:\environment\runtimes\flutter-3.44.6
- Bundled Dart: 3.12.2
- Flutter bin has been added to the current user's PATH. Restart a terminal or editor once if it does not discover Flutter.
- Windows toolchain: Visual Studio Build Tools 2022 17.14.35 with C++ tools and Windows SDK 10.0.26100.0
- Editor: VS Code is available, and .vscode/launch.json includes Skia/Impeller debug launch entries.
- The project pins Flutter 3.44.6 in pubspec.yaml. Do not casually upgrade Flutter or broad dependency ranges during unrelated repair work.

Windows prerequisite currently pending:

- Flutter plugins require Windows Developer Mode (or an explicitly elevated build environment) to create plugin symlinks.
- A direct flutter pub get downloaded the dependency graph but exited after reporting missing symlink support.
- windows/flutter/ephemeral/.plugin_symlinks exists but has zero entries; therefore flutter build windows has not been claimed as verified.
- Enable Developer Mode manually in Settings > Privacy & security > For developers, then reopen the terminal and run the validation sequence below.

Validation sequence:

    flutter doctor -v
    flutter pub get
    flutter analyze --no-fatal-infos --fatal-warnings
    flutter test
    flutter build windows
    flutter run -d windows

If Hive/MobX annotated models or controllers change, regenerate rather than editing generated files:

    dart run build_runner build --delete-conflicting-outputs

## Current repair verification on 2026-07-18

Windows Developer Mode is enabled and plugin symlink creation now works. On the
`codex/win11-issue-fixes` branch, the locked Flutter 3.44.6 / Dart 3.12.2 toolchain
has completed dependency resolution, static analysis with zero findings, the
complete Flutter test suite, and a Windows x64 Release build. The generated
binary is `build/windows/x64/runner/Release/kazumi.exe`.

The build emits a non-fatal NuGet availability message and a CMake developer
warning from the third-party `webview_windows` plugin. Neither prevents the
runner from compiling or linking. Actual launch, route-by-route visual QA, tray,
keyboard, fullscreen, and screenshots remain release gates until the frontend
migration is complete.

## Baseline verification on 2026-07-17

| Check | Result |
| --- | --- |
| Flutter SDK version | Passed: Flutter 3.44.6 / Dart 3.12.2 |
| Windows doctor checks | Passed: Windows 11, Visual Studio C++ Build Tools, Chrome, Edge |
| flutter analyze --no-fatal-infos --fatal-warnings | Completed with 27 info-level findings and no error/warning |
| flutter test | Passed: 120 tests across 14 test files |
| flutter build windows | Pending Developer Mode/plugin symlink prerequisite |

Known quality baseline, not yet fixed:

- Public controller APIs expose private generated MobX store types in eleven controller files.
- displaymode_settings.dart has one strict-top-level-inference finding.
- Production code still calls print in logging, SyncPlay, and WebView code.
- Two deprecated Material theme fields remain in lib/utils/constants.dart.
- syncplay_client.dart has an uppercase constant naming finding.
- Some HistorySync tests pass while emitting a non-fatal logger warning about an uninitialized Flutter binding; this is worth fixing so tests stay quiet and deterministic.

## Architecture map

### Bootstrap and application shell

- lib/main.dart initializes Flutter, MediaKit, Hive CE/GStorage, desktop window behavior, Windows system proxy support, and the root ModularApp.
- lib/app_widget.dart owns Material 3 themes, dynamic color, tray integration, lifecycle hooks, desktop close/minimize behavior, and Windows title-bar brightness.
- lib/bean/settings/theme_provider.dart is the app-wide ChangeNotifier for theme mode, dynamic color, and font selection.
- lib/navigation.dart holds the root navigator and ScaffoldMessenger keys.

### Routing and feature composition

- lib/app_module.dart combines coreModule and indexModule.
- lib/core_module.dart registers long-lived repositories, services, and cross-feature MobX controllers.
- lib/pages/index_module.dart declares startup, onboarding, tab shell, video, info, settings, search, and image-preview routes.
- lib/pages/menu/menu.dart is the responsive tab shell: NavigationBar in portrait and NavigationRail in desktop/landscape.
- Primary tab routes: popular, timeline, collect, my.

### Source layout

| Area | Responsibility |
| --- | --- |
| lib/pages | Screens, feature modules, route-scoped controllers, player UI |
| lib/bean | Reusable UI primitives: cards, dialogs, settings widgets, app bars |
| lib/modules | Hive models, domain entities, sync plans, generated adapters |
| lib/repositories | History, collection, downloads, and search-history persistence boundaries |
| lib/services/storage | Hive/GStorage and history coordination |
| lib/services/network | Proxy handling, system proxy integration, image cache behavior |
| lib/services/plugin | User-supplied rule engine, XPath/API strategies, captcha/cookies/plugin search |
| lib/services/video_source | Video resolution and WebView-backed source resolution |
| lib/services/player | MediaKit, screenshots, external player, PiP, remote controls, SyncPlay |
| lib/services/sync | WebDAV, Bangumi, history synchronization and remote commits |
| lib/services/update | In-app update checking |
| lib/webview | Cross-platform video WebView abstractions and implementations |
| windows/runner | Native Win32 host, fullscreen/taskbar utilities, storage/intent/shortcut channels |

Key technologies: Flutter Modular for DI/routing, MobX for observable controllers, Hive CE for local persistence, Dio for networking, MediaKit for playback, WebView plugins for source resolution, and Flutter Material 3 for UI.

## Critical engineering boundaries

- Generated files: *.g.dart and lib/bbcode/generated are generated artifacts. Modify their inputs, then run build_runner or the relevant grammar generator.
- Security-sensitive surface: user-defined plugin rules, XPath/JSON parsing, HTTP requests, WebView content, proxy configuration, cookies, WebDAV credentials, media URLs, and Windows platform channels all require validation and least-privilege handling.
- Secrets: CI consumes DANDANAPI_APPID, DANDANAPI_KEY, KAZUMI_APPID, and KAZUMI_KEY via dart-define. A local .kazumi_build_defines.env is absent in this checkout and must remain untracked.
- Desktop-specific behavior: preserve window controls, tray behavior, keyboard shortcuts, fullscreen/taskbar behavior, proxy integration, native method channels, and media playback while redesigning UI.
- Fastlane contains release automation and nested submodules. It is not needed for the normal Windows development loop.

## Useful entry points for repair work

| Workstream | Start here |
| --- | --- |
| App shell, theme, desktop chrome | lib/main.dart, lib/app_widget.dart, lib/pages/menu/menu.dart, lib/utils/theme.dart |
| Player regressions | lib/pages/player, lib/services/player, lib/services/video_source, windows/runner |
| Windows keyboard/fullscreen/tray | lib/pages/player/player_keyboard_shortcuts.dart, lib/services/platform/windows_shortcut.dart, windows/runner |
| Sync and WebDAV | lib/modules/history, lib/modules/collect, lib/services/sync, lib/repositories |
| Rule/search/parse issues | lib/services/plugin, lib/plugins, lib/request, test/rule_engine_test.dart |
| Download behavior | lib/pages/download, lib/services/download, lib/repositories/download_repository.dart |
| Native Windows host | windows/runner/flutter_window.cpp, fullscreen_utils.cpp, shortcut_utils.cpp, external_player_utils.cpp |

## Design migration guardrails

The requested iOS27-inspired visual language means calm, coherent rounded surfaces, restrained highlights, responsive feedback, intentional motion, blur, and liquid-glass depth. It does not mean indiscriminately placing translucent blur behind every widget.

- Establish shared tokens and reusable primitives before restyling individual screens.
- Keep contrast, keyboard focus, reduced-motion behavior, text scaling, and Windows high-contrast/system settings usable.
- Preserve feature semantics and desktop density: the NavigationRail shell, player controls, dialogs, sheets, cards, settings, and focus states must remain functional before visual polish.
- Prefer Material 3-compatible composition and platform-safe effects; gate costly blur/animation and avoid destabilizing MediaKit/WebView surfaces.
- Validate the target changes on the Windows app, not only in static screenshots.

## Recommended work order for a future repair task

1. Re-read this file, CODEX_UPSTREAM_ISSUES.md, git status, the issue bodies, and recent related commits.
2. Scan all Dart, native Windows, configuration, workflow, and test sources before choosing changes.
3. Establish a reproducible baseline with pub get, analyze, test, and build windows.
4. Triage each issue by reproduction, platform, affected version, duplicate status, and code ownership; do not implement unverified reports as facts.
5. Repair security and correctness defects first, then regression-proof them with focused tests.
6. Apply a small, coherent architecture/lint cleanup only where it reduces risk or duplication.
7. Migrate UI through a token/primitives layer and screen-by-screen visual regression checks.
8. Re-run analysis, tests, Windows build, and relevant manual desktop checks before handoff.

The ready-to-copy execution brief is in CODEX_REPAIR_PROMPT.md.
