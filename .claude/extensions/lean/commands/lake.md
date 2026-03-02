---
description: Run Lean build with automatic error repair
allowed-tools: Read, Write, Edit, Bash, mcp__lean-lsp__lean_build
argument-hint: [--clean] [--max-retries N] [--dry-run] [--module NAME]
---

# /lake Command

Run `lake build` with automatic repair of common errors. Iteratively builds, parses errors, and applies mechanical fixes until the build succeeds or max retries are reached.

## Syntax

```
/lake [options]
```

## Options

| Flag | Description | Default |
|------|-------------|---------|
| `--clean` | Run `lake clean` before building | false |
| `--max-retries N` | Maximum auto-fix iterations | 3 |
| `--dry-run` | Show what would be fixed without applying changes | false |
| `--module NAME` | Build specific module only | (all) |

## Auto-Fixable Errors

The skill automatically fixes these common error types:

| Error Type | Detection Pattern | Fix Strategy |
|------------|-------------------|--------------|
| Missing pattern match cases | `error: Missing cases:\n{case1}\n{case2}` | Add `\| {case} => sorry` branches |
| Unused variable | `warning: unused variable '{name}'` | Rename to `_{name}` |
| Unused import | `warning: unused import '{module}'` | Remove import line |

Errors not in this list are reported but not auto-fixed.

## Execution

**MCP Safety**: Do not call `lean_diagnostic_messages` or `lean_file_outline` - they hang. Delegate to skills.

**EXECUTE NOW**: Follow these steps in sequence.

### STEP 1: Parse Arguments

**EXECUTE NOW**: Parse the command arguments to extract flags.

```
# Default values
clean=false
max_retries=3
dry_run=false
module=""

# Parse flags from $ARGUMENTS
```

Track:
- `--clean` -> set clean=true
- `--dry-run` -> set dry_run=true
- `--max-retries N` -> set max_retries=N
- `--module NAME` -> set module=NAME

**On success**: **IMMEDIATELY CONTINUE** to STEP 2.

---

### STEP 2: Run Initial Build

**EXECUTE NOW**: Run the initial build (with clean if requested).

If `clean=true`:
```bash
lake clean
```

Then run the build:
```bash
lake build $module 2>&1
```

Capture the output and exit code.

**If build succeeds (exit code 0, no error: lines)**:
```
Lake Build Complete
===================

Build succeeded on first attempt.
No fixes needed.
```
**STOP** - execution complete.

**If build has errors**: **IMMEDIATELY CONTINUE** to STEP 3.

---

### STEP 3: Parse and Fix Errors (Loop)

**EXECUTE NOW**: Initialize the repair loop.

```
retry_count=0
fix_log=[]
previous_error_hash=""
```

**EXECUTE NOW**: Begin the repair loop. For each iteration:

#### 3A: Parse Build Errors

Extract errors from build output using pattern:
```
^(.+\.lean):(\d+):(\d+): (error|warning): (.+)$
```

Create error records with: file, line, column, severity, message

#### 3B: Classify Errors

For each error, check if auto-fixable:

| Pattern | Fix Type |
|---------|----------|
| `Missing cases:` | missing_cases |
| `unused variable '{name}'` | unused_variable |
| `unused import '{module}'` | unused_import |
| Other | UNFIXABLE |

#### 3C: Check Stop Conditions

**STOP** the loop if ANY of these are true:
1. No fixable errors remain (only unfixable errors)
2. `retry_count >= max_retries`
3. Same errors repeated (cycle detection via hash comparison)

If stopping, **IMMEDIATELY CONTINUE** to STEP 4.

#### 3D: Apply Fixes

**If dry_run=true**: Add each proposed fix to preview list, do NOT apply changes.

**If dry_run=false**: **EXECUTE NOW** - For each fixable error, apply the fix:

- **Missing cases**: Read file, find last match case, insert `| {CaseName} => sorry` branches
- **Unused variable**: Read file, rename `{name}` to `_{name}` at the declaration
- **Unused import**: Read file, remove the import line (only clean single-import lines)

Log each fix to `fix_log`.

#### 3E: Rebuild and Continue Loop

```bash
retry_count=$((retry_count + 1))
lake build $module 2>&1
```

If build succeeds: **IMMEDIATELY CONTINUE** to STEP 4.
If build has errors: **Go back to 3A** (loop continues).

---

### STEP 4: Report Results

**EXECUTE NOW**: Generate the appropriate report based on outcome.

**On Success (build passed)**:
```
Lake Build Complete
===================

Build succeeded after {retry_count} iterations.

Fixes applied:
{for each fix in fix_log:}
- {file}:{line} - {description}

All modules built successfully.
```

**On Max Retries or Unfixable Errors**:
```
Lake Build Partial
==================

Max retries ({max_retries}) reached. Build not yet passing.

Fixes applied ({retry_count} iterations):
{for each fix in fix_log:}
- {file}:{line} - {description}

Remaining errors (unfixable):
{list unfixable_errors}

Recommendation: Fix the remaining errors manually, then run /lake again.
```

**On Dry Run**:
```
Lake Build Dry Run
==================

Would apply {count} fixes:

{for each proposed fix:}
{index}. {file}:{line}
   Error: {message}
   Fix: {description}

No changes made (dry run mode).
```

**Execution complete.**

---

## Examples

### Basic Build with Auto-Repair

```bash
# Build and automatically fix mechanical errors
/lake
```

### Clean Rebuild

```bash
# Clean build artifacts first, then build with repair
/lake --clean
```

### Preview Mode

```bash
# Show what would be fixed without modifying files
/lake --dry-run
```

### Module-Specific Build

```bash
# Build only the specified module
/lake --module MyProject.Core
```

### Extended Retries

```bash
# Allow more fix iterations for complex cascading errors
/lake --max-retries 5
```

## Output

### Success

```
Lake Build Complete
===================

Build succeeded after 2 iterations.

Fixes applied:
- src/Core.lean:45 - Added 2 missing match cases
- src/Basic.lean:23 - Renamed unused variable 'h' to '_h'

All modules built successfully.
```

### Partial Success (Max Retries)

```
Lake Build Partial
==================

Max retries (3) reached. Build not yet passing.

Fixes applied (2 iterations):
- src/Core.lean:45 - Added 2 missing match cases

Remaining errors (unfixable):
- src/Soundness.lean:89:15: error: Type mismatch
    expected: Model.Valid M phi
    found:    Frame.Valid F phi

Recommendation: Fix the type error manually, then run /lake again.
```

## Stop Conditions

The repair loop stops when:

1. **Build succeeds**: All modules compile without errors
2. **Max retries reached**: Default 3 iterations
3. **No fixable errors**: All remaining errors are unfixable types
4. **Same errors repeated**: Fixes didn't resolve the errors (infinite loop prevention)

## Safety

- All fixes use `sorry` placeholders that compile but indicate incomplete work
- Git provides full undo capability (`git checkout -- path/to/file`)
- Original code is never deleted, only modified
- Use `--dry-run` to preview changes before applying
- Unused import removal is conservative (only removes the specific line)

## Troubleshooting

### Build hangs or times out

The `lake build` command may take a long time for large projects. Consider:
- Using `--module` to build specific modules
- Running `lake build` directly to see real-time output

### Fixes create new errors

This can happen when auto-fixes interact unexpectedly. The skill tracks whether the same errors recur and stops to prevent infinite loops. Review the changes and adjust manually if needed.

### MCP tool unavailable

If the `lean_build` MCP tool fails, the skill falls back to `lake build` via Bash.
