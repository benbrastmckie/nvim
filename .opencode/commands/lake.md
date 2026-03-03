---
description: Build Lean project with automatic error repair
---

# /lake Command

Build the Lean project with automatic error repair. Parses build errors and automatically fixes mechanical issues like missing match cases, unused variables, and unused imports.

## Usage

```bash
/lake                        # Build with auto-repair (default 3 retries)
/lake --clean               # Clean build artifacts first
/lake --max-retries 5       # Allow more repair iterations
/lake --dry-run             # Preview fixes without applying
/lake --module Logos.Layer1  # Build specific module
```

## Workflow

### STEP 1: Preflight

1. Generate session ID: `sess_{timestamp}_{random}`
2. Validate project structure:
   - Check `lakefile.lean` exists
   - Check `lean-toolchain` exists
3. Log session start

### STEP 2: Parse Arguments

Extract command flags:
- `--clean`: Run `lake clean` first
- `--max-retries N`: Set maximum iterations (default: 3)
- `--dry-run`: Preview mode
- `--module NAME`: Target specific module

### STEP 3: Execute Build Loop

Route to `skill-lake-repair`:

```
@.opencode/skills/skill-lake-repair/SKILL.md
```

Skill execution:
1. Run `lake build` (or `lake build {module}`)
2. Parse error output for fixable patterns
3. Apply fixes for:
   - Missing match cases (add `sorry` placeholders)
   - Unused variables (rename with `_` prefix)
   - Unused imports (remove import lines)
4. Retry build until success or max retries

### STEP 4: Report Results

**On success**:
```
Lake Build Complete
===================

Build succeeded after {N} iterations.

Fixes applied:
- {file}:{line} - {description}

All modules built successfully.
```

**On partial (unfixable errors remain)**:
```
Lake Build Partial
==================

Max retries ({N}) reached. Build not yet passing.

Fixes applied:
- {file}:{line} - {description}

Remaining errors (unfixable):
- {file}:{line}: {error message}

Recommendation: Fix the remaining errors manually, then run /lake again.
```

### STEP 5: Task Creation (Optional)

If unfixable errors remain, prompt user:

```
Task Creation Opportunity

{N} files have unfixable errors:
- {file}: {count} error(s)

Would you like to create tasks for these errors?
```

If user confirms:
1. Create one task per file with errors
2. Generate error report in `specs/{NNN}_{slug}/reports/error-report-{DATE}.md`
3. Update `specs/state.json` and `specs/TODO.md`

### STEP 6: Postflight

1. Log build results
2. Optionally commit if fixes were applied:
   ```
   lake: fix {N} mechanical errors

   Session: {session_id}

   Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>
   ```

## Error Patterns

### Auto-Fixable

| Pattern | Detection | Fix |
|---------|-----------|-----|
| Missing cases | `error: Missing cases:` | Add `\| Case => sorry` |
| Unused variable | `warning: unused variable '{name}'` | Rename to `_{name}` |
| Unused import | `warning: unused import '{module}'` | Remove import line |

### Not Auto-Fixable

All other errors require manual intervention:
- Type mismatches
- Unknown identifiers
- Proof failures
- Syntax errors

## Examples

### Basic Build
```
/lake

Running lake build...

Lake Build Complete
===================

Build succeeded on first attempt.
No fixes needed.
```

### Build with Repairs
```
/lake

Running lake build...

Iteration 1:
  Detected 2 fixable errors:
  - Theories/Layer1/Syntax.lean:45 - Missing cases
  - Theories/Layer0/Basic.lean:23 - unused variable
  Applying fixes...

Iteration 2:
  Build succeeded!

Lake Build Complete
===================

Build succeeded after 2 iterations.

Fixes applied:
- Theories/Layer1/Syntax.lean:45 - Added 2 missing match cases
- Theories/Layer0/Basic.lean:23 - Renamed 'h' to '_h'

All modules built successfully.
```

### Dry Run
```
/lake --dry-run

Lake Build Dry Run
==================

Would apply 2 fixes:

1. Theories/Layer1/Syntax.lean:45
   Error: Missing cases: Formula.implies, Formula.iff
   Fix: Add 2 match cases with sorry placeholders

2. Theories/Layer0/Basic.lean:23
   Warning: unused variable 'h'
   Fix: Rename to '_h'

No changes made (dry run mode).
```

## Safety

- All missing case fixes use `sorry` placeholders (require manual completion)
- Unused variable fixes only add underscore prefix (no semantic change)
- Unused import removal is conservative (single-import lines only)
- Cycle detection prevents infinite loops
- Max retries provides hard stop

## Related Commands

- `/lean` - Manage Lean toolchain and Mathlib versions
- `/implement` - Work on specific task implementations
- `/errors` - Analyze error patterns across codebase
