# Sources

This file tracks material synthesized into `agents-md`.

## Selected profile

- `skills/skill-writer/references/examples/workflow-process-skill.md`

Why: this skill is a repeatable authoring workflow with pre-inspection, scoped output, validation, and failure controls.

## Current source inventory

| Source | Type | Trust tier | Retrieved | Confidence | Contribution | Usage constraints | Notes |
|---|---|---|---|---|---|---|---|
| `AGENTS.md` | repo policy | canonical | 2026-05-04 | high | Requires `skill-writer`, concise prose, exact registration expectations | local repository authority | Highest-priority local instruction source |
| `README.md` | repo policy | canonical | 2026-05-04 | high | Skill layout, `SPEC.md` convention, public inventory style | local repository authority | Confirms canonical `skills/` tree |
| `CONTRIBUTING.md` | repo policy | canonical | 2026-05-04 | high | Local testing and contribution workflow | local repository authority | Used for validation expectations |
| `skills/skill-writer/SKILL.md` and references | local canonical | canonical | 2026-05-04 | high | Skill update workflow, source capture, authoring, validation | local repository authority | Primary authoring workflow |
| `https://agents.md/` | official format guide | canonical | 2026-05-04 | high | AGENTS.md purpose, common sections, nested files, closest-file precedence | public format guidance | Supports path-backed and scoped instructions |
| `https://developers.openai.com/codex/guides/agents-md` | official product docs | canonical | 2026-05-04 | high | Codex discovery order, global/project scopes, nested precedence, size cap, verification commands | OpenAI-specific behavior | Used only for compatibility guidance |
| `https://agentskills.io/specification` | official spec | canonical | 2026-05-04 | high | Skill frontmatter, progressive disclosure, focused references | skill format guidance | Supports concise runtime file shape |

## Decisions

1. Make external file enumeration a default AGENTS.md section when docs/specs/policies exist.
   Status: adopted
   Why: AGENTS.md should point agents to exact source files instead of copying policy or asking them to scan vague directories.

2. Prefer concise root files plus nested overrides.
   Status: adopted
   Why: official AGENTS.md and Codex docs both describe hierarchical instructions where narrower files override broader guidance.

3. Keep `CLAUDE.md` as a compatibility symlink when needed.
   Status: adopted
   Why: one canonical instruction file avoids divergent provider-specific copies.

4. Treat OpenAI `AGENTS.override.md` behavior as compatibility guidance, not a shared-repo default.
   Status: adopted
   Why: it is useful for Codex-specific overrides but can surprise other tools and humans if used as the main repo contract.

5. Cut prose and examples to a compact template.
   Status: adopted
   Why: instruction-following and truncation risks grow with long agent docs; the user explicitly requested minimal prose.

## Coverage matrix

| Dimension | Coverage status | Evidence |
|---|---|---|
| Repo inspection before writing | complete | local repo policy, `skill-writer` workflow |
| External docs/specs/policies enumeration | complete | user concern, AGENTS.md format guidance |
| Nested scope and precedence | complete | official AGENTS.md guide, OpenAI Codex docs |
| Prose minimization | complete | user concern, Agent Skills progressive disclosure |
| Command precision | complete | AGENTS.md examples, repo contribution conventions |
| CLAUDE.md compatibility | complete | existing skill behavior, local repo convention |
| Provider-specific variance | partial | OpenAI Codex docs covered; other tools deferred until a concrete repo need |

## Open gaps

1. Add provider-specific discovery notes only when a concrete repository or tool requires them.
2. Add durable before/after examples only if future changes regress into long prose or vague references.

## Stopping rationale

Further retrieval is currently low-yield. The source pack covers local repo policy, the official AGENTS.md format guide, OpenAI Codex discovery behavior, and the Agent Skills specification.

## Changelog

- 2026-05-04: Added source-backed external reference guidance, nested-scope rules, `SPEC.md`, and provenance.
