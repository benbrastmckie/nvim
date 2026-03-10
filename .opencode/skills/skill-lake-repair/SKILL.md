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

Attempt to build the project:

```bash
if [ -n "$module" ]; then
  build_output=$(lake build "$module" 2>&1)
else
  build_output=$(lake build 2>&1)
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
Fall back to `lake build` via Bash.

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
