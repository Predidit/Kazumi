# Future Codex execution prompt

You are working in D:\devSpace\kazumi on KazumiIOS27. First read AGENTS.md, CODEX_PROJECT_INDEX.md, and CODEX_UPSTREAM_ISSUES.md in full. Treat the checked-out code, git state, and upstream issue bodies as the source of truth; do not assume that a bug label proves a report is reproducible.

The only required development and build target is Windows 11 desktop. Do not investigate, fix, test, configure, or build Android, iOS, macOS, or Linux reports or requirements. Touch shared Flutter code only when it is necessary for a verified Win11 behavior. The UI design goal is iOS27-inspired on Win11: smooth and unified rounded geometry, subtle highlights, responsive interactions, purposeful motion, blur, and liquid-glass depth. Preserve desktop usability, keyboard navigation, focus visibility, text scaling, performance, and Windows native behavior.

## Non-negotiable execution contract

Do not start implementing until you have read the index files and the relevant code. Do not claim completion based on a partial scan, a screenshot mockup, a successful analyzer run alone, or a narrow patch. The final result must be a functioning Win11 application with the existing product capabilities preserved.

- Read AGENTS.md, CODEX_PROJECT_INDEX.md, CODEX_UPSTREAM_ISSUES.md, pubspec.yaml, analysis_options.yaml, and all relevant source/tests before selecting a fix or a visual migration.
- Build an explicit map of the entire Win11-facing frontend: application bootstrap, theme/token layer, app shell, NavigationRail, every route, all dialogs/sheets/cards/settings rows, loading/empty/error states, player overlays, desktop window controls, tray flows, keyboard shortcuts, and fullscreen states.
- Read the implementation behind each visible surface. Understand its controller/state, persistence, service/repository calls, route arguments, async lifecycle, error path, and native Windows dependency before changing the UI.
- Treat no UI surface as implicitly complete. Audit every reachable element and state; an unreviewed surface is a release blocker, not a cosmetic omission.
- Work only on Win11 issues and Win11-relevant shared code. Do not consume task time repairing other platforms or change their platform-specific behavior unless a Win11 bug cannot be safely fixed otherwise.

 Work autonomously and thoroughly:

1. Intake and complete scan
   - Read all repository guidance, pubspec.yaml, analysis_options.yaml, .github workflows, and native Windows runner code.
   - Run git status --short --branch, git remote -v, git log --oneline -12, git fetch upstream --prune, and compare main with upstream/main.
   - Index the Win11-relevant Dart, test, windows, assets, build, and configuration areas. Trace startup, routing, state, persistence, networking, plugin rules, WebViews, player, downloads, sync, updates, platform channels, and Windows window/tray/fullscreen/shortcut integration before changing code.
   - Inspect only the Win11-specific upstream issue candidates and their related comments. Deduplicate reports and identify shared-code ownership when it affects Win11.

2. Establish an evidence-based baseline
   - Verify Flutter 3.44.6/Dart 3.12.2, enable Windows desktop, run flutter pub get, flutter analyze --no-fatal-infos --fatal-warnings, flutter test, and flutter build windows.
   - If Windows Developer Mode/plugin symlink support is not enabled, report that exact prerequisite; do not bypass security controls.
   - Preserve the baseline result and distinguish pre-existing defects from regressions introduced by your changes.

3. Security and correctness first
   - Audit all untrusted inputs: plugin rules, XPath/JSON parsing, URLs, headers, cookies, WebView messages, media URLs, proxy settings, WebDAV credentials/files, update data, local storage migration, and Windows method-channel arguments.
   - Fix confirmed vulnerabilities and correctness bugs with minimal, root-cause changes. Do not log secrets, credentials, cookies, or full private URLs.
   - Investigate every open upstream bug candidate that is relevant to Win11. Reproduce it first, check duplicates/closed fixes, implement only validated fixes, and add focused regression tests.
   - Prioritize Win11 playback progress, fullscreen/taskbar geometry, keyboard shortcut responsiveness, tray/window lifecycle, storage initialization, proxy/update behavior, WebDAV sync, resource resolution, and hardware-decoding failure handling.

4. Lightweight architecture and code-quality cleanup
   - Do not rewrite the app wholesale. Preserve public behavior and migrate in small reviewable units.
   - Remove confirmed duplication, sharpen repository/service/controller boundaries, add typed failure paths where loosely typed errors create bugs, centralize logging, and eliminate the current analyzer findings where safe.
   - Never hand-edit generated .g.dart files. Regenerate after changing MobX or Hive sources.
   - Expand tests around every repaired invariant, including async cancellation, syncing merges, parsing, persistence, and platform boundary behavior.

5. iOS27-inspired Windows frontend redesign
   - Start with a visual inventory of every reusable shell, navigation, card, dialog, sheet, settings row, player control, loading/error/empty state, and desktop window state.
   - Define a compact design-token layer for radii, spacing, elevations, opacity, blur, highlights, motion curves/durations, color roles, and focus/hover/pressed/disabled states.
   - Build reusable primitives before screen migration. Keep Material 3 semantics where practical and use platform-safe glass effects; do not add indiscriminate blur or animation.
   - Upgrade the app shell, NavigationRail, search, cards, dialogs, player overlays, settings, download/sync screens, and error/loading states in a coherent sequence. Preserve keyboard, mouse, touch, screen-reader, high-contrast, and reduced-motion support.
   - Make animations interruptible, avoid jank around MediaKit and WebView, and verify performance at normal Windows desktop sizes.

6. Mandatory UI-completeness audit
   - Review every Win11 route and modal at normal desktop dimensions, narrow desktop width, high-DPI scaling, light and dark themes, and Windows system font/text scaling where available.
   - For every interactive component, validate idle, hover, focus-visible, pressed, disabled, selected, loading, empty, error, and long-content/overflow states where applicable.
   - Verify that no screen retains inconsistent legacy geometry, radius, spacing, elevation, color roles, typography, icon alignment, blur, highlight, animation, or transition behavior after the redesign.
   - Eliminate clipping, overlap, missing assets, blank areas, accidental scroll traps, unreadable translucent content, contrast failures, inaccessible focus, broken keyboard traversal, stale state, duplicate controls, and layout jumps.
   - Check the full desktop lifecycle: first launch, onboarding, app restart, restore from tray, minimize/restore, close confirmation, system theme change, window resize, fullscreen enter/exit, taskbar placement, and multi-window/display behavior where supported.

7. Functional-parity and issue closure gate
   - Build a feature matrix before edits and retest every existing Win11 capability after them: navigation, search, details, collection, history, downloads, player controls, playback state, danmaku, rules/plugins, WebDAV and Bangumi sync, proxy/update behavior, logs, settings, keyboard shortcuts, window/tray lifecycle, and error recovery.
   - Reproduce every in-scope Win11 issue from CODEX_UPSTREAM_ISSUES.md. For each one, record reproduce/not-reproducible/duplicate/fixed, the evidence, affected files, and a focused regression test or manual verification step.
   - Fix all validated Win11 defects found during the scan, including root causes exposed by testing. Do not leave a known reproducible Win11 regression without explicitly documenting why it cannot be safely fixed in this task.
   - Ensure no original Win11 feature is removed, silently degraded, hidden, or replaced by a visual-only approximation.

8. Performance and reliability gate
   - Profile the release-mode Win11 app before and after significant changes when tools permit. Record startup, route transition, scrolling, resize, player-overlay, dialog, and animation observations.
   - Keep all I/O, parsing, image work, synchronization, plugin resolution, and expensive layout/blur work off the UI-critical path. Avoid repeated rebuilds, unbounded caches, redundant network work, synchronous disk access on the UI thread, runaway timers/listeners, and resource leaks.
   - Make blur, shaders, image decoding, animation, and WebView/MediaKit integration resilient under normal Win11 hardware. Use caching, throttling, debouncing, cancellation, pagination, and lazy rendering where evidence shows they help.
   - Prefer measured, maintainable optimizations over speculative micro-optimizations. Do not trade away correctness, accessibility, visual fidelity, or debuggability.
   - Validate error recovery, cancellation, timeout, offline/proxy conditions, storage failures, malformed remote data, and app lifecycle interruptions around every touched async path.

9. Visual evidence and completion bar
   - Run formatter on changed Dart files, code generation if needed, flutter analyze, flutter test, flutter build windows, and launch the built Win11 application. Resolve all introduced diagnostics, runtime exceptions, and build errors. Do not mark completion with a failed command.
   - Perform a manual Win11 regression pass for every row in the feature matrix and every redesigned route/state.
   - Capture screenshots from the running Win11 app, not mocked images. Cover the app shell, every major route, settings, dialogs/sheets, player controls, loading/empty/error states, light/dark variants where relevant, and every screen changed by the task.
   - In the final report, include a change-to-evidence matrix: each modified area, files changed, behavior preserved or fixed, test/build command result, and one or more screenshot paths. Include before/after evidence when a meaningful visual change was made.
   - Report all modifications, all fixed Win11 issues, all tests, performance observations, screenshots, known limitations, and any intentionally untouched out-of-scope platform issues. Update CODEX_PROJECT_INDEX.md and CODEX_UPSTREAM_ISSUES.md only when facts changed.

Do not stop at a narrow patch. Finish the full Win11 code and frontend review, root-cause repairs, regression coverage, safe lightweight cleanup, complete UI migration, performance work, visual QA, Windows run/build verification, and evidence-based screenshot report while keeping every original Win11 capability functional.
