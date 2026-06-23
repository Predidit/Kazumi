# Safety Protocol

Rules for safe code cleanup. Every cleanup session follows this protocol.

---

## Pre-Cleanup Checklist

1. **Clean git state** — `git status --porcelain` must be empty
2. **Record baseline** — save `git rev-parse HEAD` for rollback
3. **Green tests** — run existing test suite, confirm passing
4. **Backup branch** — `git branch cleanup-backup` before starting

If any check fails, stop and ask the user before proceeding.

## Confidence Scoring

Every finding gets a confidence score:

| Level | Criteria | Action |
|-------|----------|--------|
| **HIGH** | Tool confirms unused, type system proves safe, tests pass after removal | Auto-apply (if dimension allows) |
| **MEDIUM** | Pattern match is strong, but dynamic usage possible | Flag with suggested fix |
| **LOW** | Heuristic match only, could be intentional | Flag with explanation only |

**Scoring rules:**

- Tool verification (knip, madge, tsc) → +1 confidence level
- Multiple signals pointing to same issue → +1 confidence level
- Dynamic usage possible (reflection, eval, metaprogramming) → -1 confidence level
- Code is in test/fixture directory → -1 confidence level
- Code has comments explaining why it exists → -1 confidence level

## Revert Procedures

### Revert Single Dimension

```bash
# Undo all unstaged changes
git checkout -- .

# Or selectively revert specific files
git checkout -- src/path/to/file.ts
```

### Revert Everything

```bash
# Reset to pre-cleanup state
git reset --hard <baseline-commit-hash>
```

### Partial Revert (Keep Some Changes)

```bash
# Interactive: review each hunk
git add -p        # Stage only the changes you want to keep
git checkout -- .  # Discard the rest
```

## Dimension Risk Matrix

| Risk Level | Dimensions | Auto-Apply Policy |
|------------|-----------|-------------------|
| **LOW** | dead, slop | Apply after build verification |
| **MEDIUM** | types, security, legacy, typecons, defensive, perf | Varies — see dimension table in SKILL.md |
| **HIGH** | dry, async, circular | Flag only — never auto-apply |

## Never Auto-Apply Rules

These findings are ALWAYS flagged, never auto-applied:

1. **Security findings** — hardcoded secrets, injection vectors
2. **Async pattern changes** — risk of introducing race conditions
3. **Circular dependency restructuring** — architectural change
4. **DRY extractions** — premature abstraction risk
5. **Defensive code removal** — might guard against runtime edge cases
6. **Performance optimizations** — need benchmarking evidence

## Build Verification Gate

After every auto-applied dimension:

1. Run type checker (`tsc --noEmit`, `mypy`, etc.)
2. Run test suite (`npm test`, `pytest`, `go test`, etc.)
3. Run linter (`eslint`, `ruff`, `golangci-lint`, etc.)

**If any step fails:**

1. Immediately revert: `git checkout -- .`
2. Log which changes caused the failure
3. Re-apply only the safe subset
4. Move failed items to "Flagged for Review"

## Common False Positive Patterns

Be cautious when encountering:

| Pattern | Why It's Tricky |
|---------|----------------|
| Dynamic `require()`/`import()` | Static analysis can't see usage |
| Reflection / `Object.keys()` | Properties accessed dynamically |
| Dependency injection | Usage is in config, not in code |
| Event emitters | Listeners registered elsewhere |
| Plugin systems | Entry points called by framework |
| Test utilities | Used in test files, not source |
| CLI entry points | Called by shell, not by code |
| Webpack/Vite magic | Loaders transform at build time |

When in doubt, **flag** rather than **apply**.
