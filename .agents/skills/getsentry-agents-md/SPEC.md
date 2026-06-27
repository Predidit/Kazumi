# AGENTS.md Specification

## Intent

`agents-md` creates and maintains compact repository instruction files for coding agents.

It should turn scattered repo norms into a short `AGENTS.md` index: commands, non-obvious conventions, and exact links to existing docs/specs/policies.

## Scope

In scope:

- Root `AGENTS.md` files.
- Nested `AGENTS.md` files for subtree-specific overrides.
- `CLAUDE.md` compatibility symlinks when needed.
- Concise command tables, external reference tables, and commit attribution rules.
- Removing duplicated prose from existing agent docs.

Out of scope:

- Rewriting the referenced docs themselves.
- Replacing `README.md`, `CONTRIBUTING.md`, policy docs, or architecture docs.
- Listing installed skills/plugins.
- Encoding linter or formatter rules already enforced by config.
- Maintaining divergent tool-specific copies of the same instructions.

## Users And Trigger Context

- Primary users: engineers and agents maintaining repository-level agent instructions.
- Should trigger for: create AGENTS.md, update AGENTS.md, maintain agent docs, set up CLAUDE.md, document repo agent conventions, reduce agent instruction prose.
- Should not trigger for: general docs writing, PR descriptions, code review, or creating reusable agent skills.

## Runtime Contract

- Inspect repo commands, configs, docs, specs, and policies before writing.
- Prefer exact repo-relative paths and command tables.
- Enumerate external files for setup, architecture, API specs, security, release, and policy docs when present.
- Keep root guidance broad and nested guidance narrow.
- Keep `AGENTS.md` under 60 lines when practical and under 100 lines always.
- Preserve the commit attribution section when the repo requires AI co-authorship.
- Use a `CLAUDE.md` symlink only for compatibility; avoid divergent copies.

## Source And Evidence Model

Authoritative sources:

- Repository instructions, especially root `AGENTS.md`.
- `README.md`, `CONTRIBUTING.md`, package manifests, CI workflows, and settings files.
- Existing project docs, specs, security docs, and policy files.
- Official AGENTS.md format guidance and OpenAI Codex discovery behavior.

Useful improvement sources:

- Repositories with concise, path-backed agent docs.
- Review feedback about stale commands, duplicated docs, or overlong instructions.
- Agent failures caused by missing exact file paths, command ambiguity, or nested instruction conflicts.

Do not store secrets, private customer data, or long copied policy text in examples.

## Reference Architecture

- `SKILL.md` contains the runtime checklist, template, and anti-patterns.
- `SPEC.md` contains this maintenance contract.
- `SOURCES.md` stores provenance, decisions, coverage, and gaps.
- `references/`, `scripts/`, and `assets/` are unused until repeated failures require focused lookup material.

## Evaluation

- Lightweight validation: check the generated file for line count, exact commands, exact external paths, no duplicated policy prose, and no vague "see docs" references.
- Trigger QA: verify create/update/CLAUDE.md requests trigger this skill, while generic docs and skill-authoring tasks do not.
- Holdout examples: one simple single-package repo, one monorepo with nested overrides, one repo with existing docs/specs/policies to enumerate.
- Acceptance gates: the resulting `AGENTS.md` is short, command-backed, path-backed, and free of redundant style rules.

## Known Limitations

- The skill relies on local file inspection; it cannot know private policy docs that are not present or supplied.
- Some agent tools have provider-specific discovery behavior; keep compatibility notes concise and avoid making one provider the default.
- Very large monorepos may need several nested files instead of a longer root file.

## Maintenance Notes

- Update `SKILL.md` when runtime sections, templates, or anti-patterns change.
- Update `SPEC.md` when scope, evaluation, or evidence policy changes.
- Update `SOURCES.md` when AGENTS.md discovery behavior or source-backed decisions change.
- Add focused references only when repeated failures cannot be fixed with the compact runtime checklist.
