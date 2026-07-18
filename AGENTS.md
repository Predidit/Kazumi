# Kazumi Codex handoff

Before modifying this repository, read CODEX_PROJECT_INDEX.md and, when issue work is involved, CODEX_UPSTREAM_ISSUES.md.

- The local delivery target is Windows 11 desktop only. Do not investigate, fix, test, configure, or build Android, iOS, macOS, or Linux work unless a Win11 fix demonstrably requires shared code and the user explicitly expands scope.
- Preserve uncommitted user work. Inspect git status before edits and use a focused branch for substantial changes.
- Do not manually edit generated Dart files ending in .g.dart. Regenerate them with build_runner after changing their source declarations.
- Treat upstream bug reports as reproduction candidates, not confirmed defects, unless the issue itself or code evidence verifies the fault.
- Never put API keys, WebDAV credentials, cookies, or local dart-define files into source control.
