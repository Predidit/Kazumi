# Cleanup Tools Reference

Language-specific tools for each cleanup dimension. Always fall back to grep patterns
(see [patterns.md](patterns.md)) when tools aren't installed.

---

## JavaScript / TypeScript

### Dead Code

```bash
# knip — finds unused files, exports, dependencies, and types
npx knip                          # Full report
npx knip --reporter compact       # Compact output
npx knip --include files          # Unused files only
npx knip --include exports        # Unused exports only
npx knip --include dependencies   # Unused dependencies only
```

### Circular Dependencies

```bash
# madge — dependency graph and circular detection
npx madge --circular src/         # Find circular deps
npx madge --circular --extensions ts src/  # TS only
npx madge --image graph.svg src/  # Visual dependency graph

# dependency-cruiser — configurable dependency analysis
npx depcruise --output-type err src/    # Error report
npx depcruise --output-type dot src/ | dot -T svg > deps.svg  # Visual
```

### Duplication

```bash
# jscpd — copy/paste detector
npx jscpd src/ --min-lines 10 --min-tokens 50
npx jscpd src/ --reporters console --format "typescript,javascript"
npx jscpd src/ --output report/   # HTML report
```

### Type Safety

```bash
# TypeScript strict checks
npx tsc --noEmit --strict         # Full strict mode
npx tsc --noEmit 2>&1 | grep "any"  # Find any-related issues
```

### Security

```bash
# npm audit for dependency vulnerabilities
npm audit --json | head -50
npm audit fix --dry-run

# eslint security plugins
npx eslint --rule '{"no-eval": "error", "no-implied-eval": "error"}' src/
```

### Performance

```bash
# Bundle analysis
npx webpack-bundle-analyzer stats.json    # Webpack
npx vite-bundle-visualizer                # Vite
npx source-map-explorer dist/bundle.js    # Generic

# Import cost estimation
npx import-cost src/index.ts
```

---

## Python

### Dead Code

```bash
# vulture — find unused code
vulture src/ --min-confidence 80
vulture src/ --make-whitelist > whitelist.py  # Generate whitelist

# autoflake — remove unused imports
autoflake --check --remove-all-unused-imports -r src/
autoflake --in-place --remove-all-unused-imports -r src/  # Apply
```

### Code Quality

```bash
# ruff — fast linter and formatter (replaces flake8, isort, pyupgrade)
ruff check src/                   # Lint
ruff check src/ --fix             # Auto-fix
ruff check src/ --select F841     # Unused variables only
ruff check src/ --select UP       # Pyupgrade rules (legacy patterns)

# pylint unused detection
pylint src/ --disable=all --enable=W0611,W0612,W0613  # Unused imports/vars/args
```

### Security

```bash
# bandit — security linter
bandit -r src/ -ll               # Medium+ severity
bandit -r src/ --format json     # JSON output
bandit -r src/ -t B101,B105,B106 # Specific checks (assert, hardcoded password)

# safety — dependency vulnerability check
safety check --json
```

### Duplication

```bash
# pylint duplicate detection
pylint src/ --disable=all --enable=R0801  # Duplicate code

# jscpd works for Python too
npx jscpd src/ --format python --min-lines 10
```

---

## Go

### Dead Code

```bash
# deadcode — find unreachable functions
go install golang.org/x/tools/cmd/deadcode@latest
deadcode ./...

# staticcheck — comprehensive analysis
staticcheck ./...
staticcheck -checks U1000 ./...   # Unused code specifically
```

### Code Quality

```bash
# golangci-lint — meta-linter
golangci-lint run
golangci-lint run --enable-all
golangci-lint run --enable unused,deadcode,ineffassign
```

---

## Rust

### Dead Code

```bash
# Compiler warnings
cargo build 2>&1 | grep "dead_code\|unused"
RUSTFLAGS="-W dead-code" cargo build

# cargo-udeps — unused dependencies
cargo install cargo-udeps
cargo udeps
```

### Code Quality

```bash
# clippy — comprehensive linting
cargo clippy -- -W clippy::all
cargo clippy --fix               # Auto-fix
```

---

## Universal Tools

### Duplication (Any Language)

```bash
npx jscpd . --min-lines 10 --min-tokens 50 \
  --format "typescript,javascript,python,go,rust,java"
```

### Secret Scanning

```bash
# gitleaks — scan for hardcoded secrets
gitleaks detect --source . --verbose
gitleaks detect --source . --report-format json --report-path leaks.json

# trufflehog — entropy-based secret detection
trufflehog filesystem . --only-verified
```

### Dependency Analysis

```bash
# depcheck (Node.js) — unused dependencies
npx depcheck
npx depcheck --ignores="@types/*"  # Ignore type packages
```
