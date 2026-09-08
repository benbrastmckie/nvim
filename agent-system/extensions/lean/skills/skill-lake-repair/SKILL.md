---
name: skill-lake-repair
description: Run Lean build with automatic error repair for missing cases, unused variables, and unused imports
allowed-tools: Read, Write, Edit, Bash
---

# Lake Repair Skill (Direct Execution)

Direct execution skill for automated Lean build repair. Runs `lake build`, parses errors, and automatically fixes common mechanical errors in an iterative loop.

This skill executes inline without spawning a subagent.

## Execution

### Step 1: Parse Arguments

Extract flags from command input:
- `--clean`: Run `lake clean` before building
- `--max-retries N`: Maximum fix iterations (default: 3)
- `--dry-run`: Preview fixes without applying
- `--module NAME`: Build specific module only

```bash
clean=false
max_retries=3
dry_run=false
module=""

for arg in "$@"; do
  case "$arg" in
    --clean) clean=true ;;
    --dry-run) dry_run=true ;;
    --max-retries=*) max_retries="${arg#*=}" ;;
    --module=*) module="${arg#*=}" ;;
  esac
done
```

---

### Step 2: Initial Clean (Optional)

If `--clean` flag is set:

```bash
if [ "$clean" = true ]; then
  echo "Running lake clean..."
  lake clean
fi
```

---

### Step 3: Build Loop

Initialize tracking variables:
- `retry_count=0`
- `previous_errors=""` (for cycle detection)
- `total_fixes=0`

---

### Step 4: Run Build

**Decision note**: this loop uses command substitution (`build_output=$(...)`) to capture build
output into a shell variable, which is incompatible with `Bash(run_in_background: true)` — a
detached call returns no stdout to the invoking shell. This carves the loop out of the
*detachment* obligation in `context/project/lean4/operations/long-builds.md` only; it still
routes through the build guard, gaining serialization against concurrent builds on the same
project and the guard's memory bounding. Residual exposure: a heavy first-time build in this loop
can still be killed at the foreground cap, but unlike a detached agent build the failure is not
silent — it surfaces as a failed command substitution, which the loop's existing error handling
(`build_exit_code`) already covers.

Attempt to build the project:

```bash
if [ -n "$module" ]; then
  build_output=$(bash .claude/scripts/lake-build-guard.sh build --timeout 1800 -- "$module" 2>&1)
else
  build_output=$(bash .claude/scripts/lake-build-guard.sh build --timeout 1800 -- build 2>&1)
fi
build_exit_code=$?
```

---

### Step 5: Parse Build Errors

Extract errors and warnings from build output using regex pattern:

```
Pattern: ^(.+\.lean):(\d+):(\d+): (error|warning): (.+)$
```

---

### Step 6: Classify Errors

| Error Pattern | Fix Type |
|---------------|----------|
| Missing cases | missing_cases |
| Unused variable | unused_variable |
| Unused import | unused_import |
| All other | UNFIXABLE |

---

### Step 7: Apply Fixes

#### Missing Cases Fix
Add match cases with sorry placeholders.

#### Unused Variable Fix
Rename by adding underscore prefix: `{name}` -> `_{name}`

#### Unused Import Fix
Remove the import line (only clean single-import lines).

---

### Step 8: Final Report

After loop exits:

```
Lake Build Complete
===================

Build succeeded after {retry_count} iterations.

Fixes applied:
- {file}:{line} - {description}

All modules built successfully.
```

---

## Error Handling

### MCP Tool Failure
Fall back to `lake build` via Bash, through the build guard per Step 4 above (see
`context/project/lean4/operations/long-builds.md`).

### File Read/Write Failure
Skip that particular fix, continue with others.

### Parse Failure
Treat as unfixable error.

---

## Safety Measures

### Conservative Fixes
- All missing case fixes use `sorry` placeholders
- Unused variable fixes only add underscore prefix
- Unused import removal is cautious (single-import lines only)

### Cycle Prevention
- Track error signatures between iterations
- Stop if same errors recur
- Hard limit via max_retries (default 3)
