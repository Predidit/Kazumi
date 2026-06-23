# Grep Patterns by Dimension

Fallback detection patterns when dedicated tools aren't installed. Use with `Grep` tool or `rg`.

---

## Dead Code

```bash
# Unused imports (JS/TS) — imported but never referenced
rg "^import .+ from " --type ts -l  # Get all files with imports, then cross-reference

# Unreachable code after return/throw
rg "^\s*(return|throw)\b" -A 2 --type ts  # Look for code after return/throw

# Commented-out code blocks (>3 lines)
rg "^\s*//" --type ts -c | sort -t: -k2 -rn | head -20  # Files with most comments

# TODO/FIXME/HACK markers (potential dead code indicators)
rg "(TODO|FIXME|HACK|XXX|DEPRECATED)" --type-add 'src:*.{ts,js,py,go,rs}' --type src

# Empty catch blocks
rg "catch\s*\([^)]*\)\s*\{\s*\}" --type ts

# Unused function parameters (starts with _)
rg "function\s+\w+\([^)]*_\w+" --type ts
```

## AI Slop

```bash
# Restating comments: "// Set X" or "// Get X" or "// Return X"
rg "//\s*(Set|Get|Return|Create|Initialize|Define|Check|Update|Delete|Remove)\s+(the\s+)?\w+" --type ts

# Obvious JSDoc
rg "@param\s+\w+\s*-?\s*(The|A|An)\s+\w+$" --type ts
rg "@returns?\s*(The|A|An)\s+\w+$" --type ts

# Filler section markers
rg "//\s*-{3,}.*-{3,}" --type ts
rg "//\s*(Helper|Utility|Private|Public)\s+(Functions|Methods|Variables)" --type ts

# "This function/method/class" comments
rg "//.*\b(This (function|method|class|variable|constant|module))" --type ts
```

## Weak Types

```bash
# Explicit any (TypeScript)
rg ": any\b" --type ts
rg "as any\b" --type ts
rg "<any>" --type ts

# Implicit any — missing return types on exported functions
rg "export (async )?function \w+\([^)]*\)\s*\{" --type ts  # No return type annotation

# Python Any import
rg "from typing import.*\bAny\b" --type py
rg ":\s*Any\b" --type py

# Object type (too broad)
rg ": object\b" --type ts
rg ": Object\b" --type ts
rg ": \{\}" --type ts  # Empty object type
```

## Security

```bash
# Hardcoded secrets
rg "(api[_-]?key|secret|password|token|auth)\s*[:=]\s*['\"][^'\"]{8,}" -i
rg "(AKIA[A-Z0-9]{16})" # AWS access keys
rg "-----BEGIN (RSA |EC |DSA )?PRIVATE.KEY-----"
rg "(ghp_|gho_|ghu_|ghs_|ghr_)[A-Za-z0-9_]{36,}"  # GitHub tokens

# Weak crypto
rg "(md5|sha1)\s*\(" -i --type-add 'src:*.{ts,js,py,go,rs}' --type src
rg "Math\.random\(\)" --type ts  # Insecure random for tokens
rg "crypto\.createHash\(['\"]md5" --type ts

# SQL injection vectors
rg "(query|exec|execute)\s*\(\s*[`'\"].*\$\{" --type ts  # Template literal in SQL
rg "f['\"].*SELECT.*\{" --type py  # Python f-string SQL

# Command injection
rg "(exec|execSync|spawn|spawnSync)\s*\(" --type ts
rg "(subprocess\.call|os\.system|os\.popen)\s*\(" --type py

# eval usage
rg "\beval\s*\(" --type-add 'src:*.{ts,js,py}' --type src

# Insecure defaults
rg "rejectUnauthorized:\s*false" --type ts
rg "verify\s*=\s*False" --type py  # Disabled SSL verify
rg "http://" --type-add 'src:*.{ts,js,py,go}' --type src  # Plain HTTP
```

## Legacy Code

```bash
# Old Node.js APIs
rg "\bnew Buffer\b" --type ts
rg "\bfs\.exists\b" --type ts  # Use fs.access instead
rg "\burl\.parse\b" --type ts  # Use new URL() instead
rg "\bpath\.resolve\(__dirname" --type ts  # Use import.meta in ESM

# Old JS patterns
rg "\bvar\s+" --type ts  # Use let/const
rg "\.prototype\." --type ts  # Use class syntax
rg "\barguments\b" --type ts  # Use rest params
rg "require\(" --type ts  # CJS in TS files

# Unnecessary polyfills
rg "core-js|regenerator-runtime|@babel/polyfill" --type json
rg "Object\.assign" --type ts  # Spread is available everywhere now
```

## Type Consolidation

```bash
# Duplicate interface names across files
rg "^(export )?(interface|type) (\w+)" --type ts -o | sort | uniq -d

# Pick/Omit opportunities — interfaces with many shared fields
rg "^\s+(id|name|email|createdAt|updatedAt|status):" --type ts -c | sort -t: -k2 -rn
```

## Defensive Code

```bash
# Unnecessary null checks (look for patterns after non-null assertions)
rg "\?\.\w+\?\." --type ts  # Excessive optional chaining
rg "!= null|!== null|!= undefined|!== undefined" --type ts
rg "typeof \w+ !== ['\"]undefined['\"]" --type ts

# Empty catch blocks (swallowed errors)
rg "catch\s*\(\w*\)\s*\{\s*\}" --type ts

# Redundant boolean comparisons
rg "=== true|=== false|!== true|!== false" --type ts
```

## Performance

```bash
# N+1 query indicators (loop + await)
rg "for.*\{" -A 5 --type ts | rg "await.*(find|query|fetch|get)"

# Sync I/O in potentially async contexts
rg "readFileSync|writeFileSync|execSync" --type ts
rg "JSON\.parse\(fs\.readFileSync" --type ts

# Bundle bloat — full library imports
rg "import \w+ from ['\"]lodash['\"]" --type ts  # Should use lodash/map
rg "import \* as" --type ts  # Namespace imports prevent tree shaking
rg "require\(['\"]moment['\"]" --type ts  # moment.js is heavy, use date-fns/dayjs

# React re-render triggers
rg "\{\{" --type tsx  # Inline objects in JSX (new ref every render)
rg "useEffect\(\s*\(\)\s*=>" -A 3 --type tsx  # Missing deps array
```

## Async Patterns

```bash
# forEach with async (floating promises)
rg "\.forEach\(async" --type ts

# Missing await
rg "async.*=>" -A 3 --type ts | rg "return [^a]"  # Async arrow without await

# Async function with no await
rg "async function" --type ts  # Then check function body for await

# Mixed .then() and await
rg "await.*\.then\(" --type ts
rg "\.then\(" --type ts -c | sort -t: -k2 -rn  # Files with most .then()

# Unhandled promise rejection
rg "\.catch\(\s*\)" --type ts  # Empty catch on promise
rg "Promise\.(all|race|allSettled)\(" --type ts  # Check for error handling
```

## Circular Dependencies

```bash
# Barrel file re-exports (common source of circles)
rg "export \* from" --type ts
rg "export \{.*\} from ['\"]\.\./" --type ts  # Re-exporting from parent

# Mutual imports — quick heuristic
# Find files that import each other (requires cross-referencing)
rg "from ['\"]\.\.?/" --type ts -l  # Files with relative imports
```
