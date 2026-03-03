---
name: skill-lake-repair
description: Run Lean build with automatic error repair for missing cases, unused variables, and unused imports
allowed-tools: Read, Write, Edit, Bash, mcp__lean-lsp__lean_build
---

# Lake Repair Skill (Direct Execution)

Direct execution skill for automated Lean build repair. Runs `lake build`, parses errors, and automatically fixes common mechanical errors in an iterative loop.

This skill executes inline without spawning a subagent.

**Temporary Workaround**: `lean_diagnostic_messages` removed due to MCP hanging bug (lean-lsp-mcp issues #118, #115). Use `lake build` via Bash for diagnostics.

## Context References

Load on-demand using @-references:

**Always Load**:
- `@.opencode/context/project/lean4/tools/mcp-tools-guide.md` - MCP tool reference for lean_build

**Load for Error Patterns**:
- `@.opencode/rules/lean4.md` - Lean development patterns

---

## Execution

### Step 1: Parse Arguments

Extract flags from command input:
- `--clean`: Run `lake clean` before building
- `--max-retries N`: Maximum fix iterations (default: 3)
- `--dry-run`: Preview fixes without applying
- `--module NAME`: Build specific module only

```bash
# Parse from command input
clean=false
max_retries=3
dry_run=false
module=""

# Parse flags
for arg in "$@"; do
  case "$arg" in
    --clean) clean=true ;;
    --dry-run) dry_run=true ;;
    --max-retries)
      shift
      max_retries="$1"
      ;;
    --max-retries=*)
      max_retries="${arg#*=}"
      ;;
    --module)
      shift
      module="$1"
      ;;
    --module=*)
      module="${arg#*=}"
      ;;
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
  echo "Clean complete."
fi
```

---

### Step 3: Build Loop

Initialize tracking variables:
- `retry_count=0`
- `previous_errors=""` (for cycle detection)
- `total_fixes=0`
- `fix_log=[]` (track all fixes applied)

---

### Step 4: Run Build

Attempt to build the project (or specific module):

```bash
# Build using MCP tool with fallback to Bash
if [ -n "$module" ]; then
  build_output=$(lake build "$module" 2>&1)
else
  build_output=$(lake build 2>&1)
fi
build_exit_code=$?
```

**MCP Tool Alternative** (preferred when available):
```
lean_build(clean=false, output_lines=100)
```

If MCP tool fails (AbortError), fall back to Bash `lake build`.

---

### Step 5: Check Build Success

If build succeeded (exit code 0 and no errors in output):

```
Lake Build Complete
===================

Build succeeded after {retry_count} iterations.

Fixes applied:
{fix_log entries}

All modules built successfully.
```

Exit successfully.

---

### Step 6: Parse Build Errors

Extract errors and warnings from build output using regex pattern:

```
Pattern: ^(.+\.lean):(\d+):(\d+): (error|warning): (.+)$
```

For each match, create error record:
```json
{
  "file": "{captured group 1}",
  "line": "{captured group 2}",
  "column": "{captured group 3}",
  "severity": "{captured group 4}",
  "message": "{captured group 5}"
}
```

**Multi-line error handling**: Some errors span multiple lines (e.g., "Missing cases:" followed by case names). Parse continuation lines until the next file:line:col pattern.

---

### Step 7: Classify Errors

For each error, determine if it's auto-fixable using these patterns:

| Error Pattern | Regex | Fix Type |
|---------------|-------|----------|
| Missing cases | `error: Missing cases:` | missing_cases |
| Unused variable | `warning: unused variable ['`]([^'`]+)['`]` | unused_variable |
| Unused import | `warning: unused import ['`]([^'`]+)['`]` | unused_import |
| All other | (no match) | UNFIXABLE |

**Classification logic**:

```python
def classify_error(message: str) -> tuple[str, dict]:
    # Missing cases - HIGH priority
    if "Missing cases:" in message:
        # Extract case names from subsequent lines
        return ("missing_cases", {"cases": extract_case_names(message)})

    # Unused variable - HIGH priority
    match = re.search(r"unused variable ['`]([^'`]+)['`]", message)
    if match:
        return ("unused_variable", {"name": match.group(1)})

    # Unused import - MEDIUM priority (more cautious)
    match = re.search(r"unused import ['`]([^'`]+)['`]", message)
    if match:
        return ("unused_import", {"module": match.group(1)})

    # Everything else is unfixable
    return ("unfixable", {})
```

Group errors by classification:
- `fixable_errors[]` - Errors we can auto-fix
- `unfixable_errors[]` - Errors requiring manual attention

**Priority order for fixes**:
1. Missing cases (often causes cascading errors)
2. Unused variables (quick fix, no side effects)
3. Unused imports (cautious, done last)

---

### Step 8: Check Stop Conditions

**Stop if**:

1. **No fixable errors**: All remaining errors are unfixable
   ```
   if [ ${#fixable_errors[@]} -eq 0 ]; then
     # Report unfixable errors and stop
   fi
   ```

2. **Max retries reached**:
   ```
   if [ $retry_count -ge $max_retries ]; then
     # Report progress and remaining errors
   fi
   ```

3. **Same errors repeated** (cycle detection):
   ```
   current_errors=$(echo "${fixable_errors[@]}" | sort | md5sum)
   if [ "$current_errors" = "$previous_errors" ]; then
     # Fixes didn't help, stop to prevent infinite loop
   fi
   previous_errors="$current_errors"
   ```

---

### Step 9: Apply Fixes (or Preview)

For each fixable error:

#### 9A: Missing Cases Fix

**Detection**: Error message contains "Missing cases:" followed by case names on subsequent lines.

**Example error**:
```
Logos/Layer1/Syntax.lean:45:2: error: Missing cases:
Formula.implies
Formula.iff
```

**Parsing**:
1. Match the error line: `{file}:{line}:{col}: error: Missing cases:`
2. Capture all subsequent non-empty lines until the next error pattern as case names
3. Each case name is a constructor reference (e.g., `Formula.implies`)

**Fix strategy**:
1. Read the source file using Read tool
2. Locate line {line} (the match expression or first case)
3. Find the last existing case branch by searching backwards from end of match for `| ... =>`
4. Determine indentation from existing cases
5. For each missing case, generate:
   ```lean
   | {CaseName} => sorry
   ```
6. Insert after the last existing case

**Implementation example**:

Given this source (line 45):
```lean
def eval : Formula -> Bool
  | Formula.atom n => atoms n
  | Formula.neg phi => !eval phi
  | Formula.conj phi psi => eval phi && eval psi
```

And error: `Missing cases: Formula.implies, Formula.iff`

Read source, find last case line:
```lean
  | Formula.conj phi psi => eval phi && eval psi
```

Generate and insert after:
```lean
  | Formula.implies => sorry
  | Formula.iff => sorry
```

**Edit tool call**:
```json
{
  "file_path": "/path/to/file.lean",
  "old_string": "  | Formula.conj phi psi => eval phi && eval psi",
  "new_string": "  | Formula.conj phi psi => eval phi && eval psi\n  | Formula.implies => sorry\n  | Formula.iff => sorry"
}
```

**Dry-run output**:
```
Would fix: Logos/Layer1/Syntax.lean:45
  Error: Missing cases: Formula.implies, Formula.iff
  Fix: Add 2 match cases with sorry placeholders
```

**Apply fix**: Use Edit tool to insert the case branches.

---

#### 9B: Unused Variable Fix

**Detection**: Warning message matches pattern `unused variable '{name}'` or `unused variable \`{name}\``.

**Example warnings**:
```
Logos/Layer0/Basic.lean:23:10: warning: unused variable 'h'
Logos/Layer0/Basic.lean:45:5: warning: unused variable `hyp`
```

**Parsing**:
1. Match: `{file}:{line}:{col}: warning: unused variable ['`]{name}['`]`
2. Extract variable name from quotes or backticks

**Fix strategy**:
1. Read the source file using Read tool
2. Navigate to line {line}, column {col}
3. Find the variable declaration (the identifier at that position)
4. Rename by adding underscore prefix: `{name}` -> `_{name}`
5. Only rename the declaration, not usages (there are none if it's unused)

**Common contexts**:
- Lambda parameters: `fun h => ...` -> `fun _h => ...`
- Let bindings: `let h := ...` -> `let _h := ...`
- Match patterns: `| (h, x) => ...` -> `| (_h, x) => ...`
- Function parameters: `def foo (h : P) ...` -> `def foo (_h : P) ...`

**Implementation example**:

Given source line 23:
```lean
theorem foo (h : P) (x : Q) : R := by
```

And warning: `unused variable 'h'` at column 13

Locate `h` at position:
```lean
theorem foo (h : P) (x : Q) : R := by
            ^-- column 13
```

**Edit tool call**:
```json
{
  "file_path": "/path/to/file.lean",
  "old_string": "theorem foo (h : P)",
  "new_string": "theorem foo (_h : P)"
}
```

**Dry-run output**:
```
Would fix: Logos/Layer0/Basic.lean:23
  Warning: unused variable 'h'
  Fix: Rename to '_h'
```

**Apply fix**: Use Edit tool to rename the variable.

---

#### 9C: Unused Import Fix

**Detection**: Warning message matches pattern `unused import ['`]{module}['`]`.

**Example warnings**:
```
Logos/Layer0/Basic.lean:5:1: warning: unused import 'Mathlib.Data.Nat.Basic'
Logos/Layer0/Basic.lean:7:1: warning: unused import `Init.Data.List`
```

**Parsing**:
1. Match: `{file}:{line}:{col}: warning: unused import ['`]{module}['`]`
2. Extract module name from quotes or backticks

**Fix strategy**:
1. Read the source file using Read tool
2. Navigate to line {line}
3. Check if the line is a simple import statement: `import {module}`
4. **Safety check**: Only remove if:
   - Line contains exactly one import (no multi-imports)
   - Module name matches the warning
5. Remove the entire line (including newline)

**Safety rules**:
- DO NOT modify lines like `import A, B, C` (multiple imports)
- DO NOT modify lines with comments after import
- ONLY remove clean single-import lines

**Implementation example**:

Given source line 5:
```lean
import Mathlib.Data.Nat.Basic
```

And warning: `unused import 'Mathlib.Data.Nat.Basic'`

Verify it's a clean single import, then remove.

**Edit tool call**:
```json
{
  "file_path": "/path/to/file.lean",
  "old_string": "import Mathlib.Data.Nat.Basic\n",
  "new_string": ""
}
```

**Edge cases - DO NOT FIX**:
```lean
import Mathlib.Data.Nat.Basic -- needed for X  -- has comment, skip
import A import B  -- multiple imports, skip (rare)
```

**Dry-run output**:
```
Would fix: Logos/Layer0/Basic.lean:5
  Warning: unused import 'Mathlib.Data.Nat.Basic'
  Fix: Remove import line
```

**Apply fix**: Use Edit tool to remove the line.

---

### Step 10: Log Fix

After each fix, record to fix_log:
```json
{
  "file": "path/to/file.lean",
  "line": 45,
  "error_type": "missing_cases",
  "description": "Added 2 missing match cases"
}
```

Increment `total_fixes`.

---

### Step 11: Increment Retry and Loop

```bash
retry_count=$((retry_count + 1))
```

Go back to Step 4 (Run Build).

---

### Step 12: Final Report

After loop exits (success or stop condition):

#### Success Report
```
Lake Build Complete
===================

Build succeeded after {retry_count} iterations.

Fixes applied:
{for each fix in fix_log:}
- {file}:{line} - {description}

All modules built successfully.
```

#### Partial Report (Max Retries or Unfixable)
```
Lake Build Partial
==================

Max retries ({max_retries}) reached. Build not yet passing.

Fixes applied ({retry_count} iterations):
{for each fix in fix_log:}
- {file}:{line} - {description}

Remaining errors (unfixable):
{for each error in unfixable_errors:}
- {file}:{line}:{column}: {severity}: {message}

Recommendation: Fix the remaining errors manually, then run /lake again.
```

#### Dry Run Report
```
Lake Build Dry Run
==================

Would apply {total_fixes} fixes:

{for each proposed fix:}
{index}. {file}:{line}
   Error: {message}
   Fix: {description}

No changes made (dry run mode).
```

---

### Step 13: Create Tasks for Unfixable Errors (Optional)

This step only executes when:
- Build has unfixable errors remaining
- `dry_run=false`
- User has been prompted and confirmed

#### 13A: Group Errors by File

Iterate through `unfixable_errors` and group by source file:

```python
# Conceptual logic
file_groups = {}
for error in unfixable_errors:
    file = error["file"]
    if file not in file_groups:
        file_groups[file] = []
    file_groups[file].append(error)
```

#### 13B: User Confirmation

Prompt user to confirm task creation:

**Prompt**:
```
Task Creation Opportunity

{len(file_groups)} files have unfixable errors:

- {file}: {len(errors)} error(s)
  (First error: {first_error_message_truncated}...)

Would you like to create tasks for these errors?
```

**Options**:
- "Yes, create tasks"
- "No, skip task creation"

If user declines, output message and stop execution.

#### 13B': Check for Existing Tasks

For each file in `file_groups`, check if an active task already exists before creating:

```bash
# Extract basename for project_name matching
base_name=$(basename "$file" .lean | tr '[:upper:]' '[:lower:]')

# Query state.json for existing task
existing_task=$(jq -r --arg source "$file" --arg basename "$base_name" '
  .active_projects[] |
  select(
    (.source == $source) or
    (.project_name | contains("fix_build_errors_" + $basename))
  ) |
  .project_number' specs/state.json | head -1)

if [ -n "$existing_task" ]; then
  echo "Skipping $file - existing task #$existing_task"
  skipped_files+=("$file:$existing_task")
  continue
fi
```

**Skip tracking**:
- `skipped_files[]` - Array of "file:task_number" pairs for files with existing tasks
- Files in this array are excluded from task creation
- Initialize `skipped_files=()` before the loop

#### 13C: Error Report Format

For each file group, create an error report artifact:

**Path**: `specs/{OC_NNN}_{SLUG}/reports/error-report-{DATE}.md`

**Template**:
```markdown
# Build Error Report: Task #{N}

**Generated**: {ISO_DATE}
**Source file**: {file_path}
**Error count**: {error_count} errors

## Errors

### Error 1: Line {line}
**Type**: {severity}
**Column**: {column}
**Message**:
```
{full_error_message}
```

### Error 2: Line {line}
...

## Suggested Approach

Review the error messages above and apply appropriate fixes.
Common patterns:
- Type mismatches: Check the expected vs actual types
- Unknown identifiers: Verify imports and namespaces
- Proof failures: May need additional hypotheses or different tactics

After fixing, run `/lake` again to verify the build passes.
```

#### 13D: Task Creation - state.json

For each file in `file_groups`:

```bash
# Get current task number
next_num=$(jq -r '.next_project_number' specs/state.json)

# Generate slug from filename
base_name=$(basename "$file" .lean)
slug="fix_build_errors_$(echo "$base_name" | tr '[:upper:]' '[:lower:]' | tr ' ' '_')"

# Date for report filename
date_stamp=$(date +%Y%m%d)
iso_date=$(date -u +%Y-%m-%dT%H:%M:%SZ)

# Create directory (uses padded number format)
mkdir -p "specs/$(printf '%03d' ${next_num})_${slug}/reports"

# Write error report (using Write tool with content above)
# Path: specs/$(printf '%03d' ${next_num})_${slug}/reports/error-report-${date_stamp}.md

# Update state.json
jq --arg ts "$iso_date" \
   --arg slug "$slug" \
   --arg source "$file" \
   --argjson error_count "$error_count" \
   --arg report_path "specs/$(printf '%03d' ${next_num})_${slug}/reports/error-report-${date_stamp}.md" \
   --argjson next_num "$next_num" \
   '.next_project_number = ($next_num + 1) |
    .active_projects = [{
      "project_number": $next_num,
      "project_name": $slug,
      "status": "not_started",
      "language": "lean",
      "source": $source,
      "created": $ts,
      "last_updated": $ts,
      "artifacts": [{
        "type": "error_report",
        "path": $report_path,
        "summary": ("Build error report with " + ($error_count | tostring) + " errors")
      }]
    }] + .active_projects' \
   specs/state.json > /tmp/state.json && mv /tmp/state.json specs/state.json
```

#### 13E: Task Creation - TODO.md

Use Edit tool to prepend task entry after the `## Tasks` header:

**Find pattern**: `## Tasks` section header

**Insert after header** (new tasks at top):
```markdown

### {next_num}. Fix build errors in {basename}
- **Effort**: 1-2 hours
- **Status**: [NOT STARTED]
- **Language**: lean
- **Source**: {file_path}
- **Error Report**: [specs/{NNN}_{slug}/reports/error-report-{date_stamp}.md]

**Description**: Fix {error_count} build errors in {file_path}. See linked error report for detailed error messages and suggested approaches.
```

**Edit pattern**:
```
old_string: "## Tasks\n"
new_string: "## Tasks\n\n### {next_num}. Fix build errors in {basename}\n..."
```

#### 13F: Final Report

After all tasks processed:

```
Tasks Created
=============

{If skipped_files not empty:}
Files skipped (existing tasks):
- {file}: Task #{task_num}

{If created_tasks not empty:}
Created {len(created_tasks)} tasks for unfixable build errors:
- Task #{task_num}: Fix build errors in {basename} ({error_count} errors)
  Report: specs/{NNN}_{slug}/reports/error-report-{date}.md

{If no tasks created and no files skipped:}
No tasks created.

Run /implement {task_num} to work on each task.
Or fix manually and run /lake again.
```

---

## Error Handling

### MCP Tool Failure

**Note**: `lean_diagnostic_messages` is BLOCKED (lean-lsp-mcp #118). Always use `lake build` via Bash.

If `lean_build` MCP tool fails:
1. Log the error
2. Fall back to `lake build` via Bash
3. Parse stdout/stderr directly

### File Read/Write Failure

If unable to read or write a source file:
1. Log the error
2. Skip that particular fix
3. Continue with other fixes
4. Report skipped fixes in final output

### Parse Failure

If error output doesn't match expected patterns:
1. Treat as unfixable error
2. Include raw error text in report

---

## Safety Measures

### Git Safety

- Never commit automatically
- User reviews all changes
- `git checkout -- path/to/file` undoes any change

### Conservative Fixes

- All missing case fixes use `sorry` placeholders
- Unused variable fixes only add underscore prefix
- Unused import removal is cautious (single-import lines only)

### Cycle Prevention

- Track error signatures between iterations
- Stop if same errors recur (fix didn't work)
- Hard limit via max_retries (default 3)

---

## Example Execution Flows

### Successful Auto-Repair

```
$ /lake

Running lake build...

Iteration 1:
  Detected 2 fixable errors:
  - Logos/Layer1/Completeness.lean:45 - Missing cases: Formula.implies, Formula.iff
  - Logos/Layer0/Basic.lean:23 - unused variable 'h'
  Applying fixes...

Iteration 2:
  Build succeeded!

Lake Build Complete
===================

Build succeeded after 2 iterations.

Fixes applied:
- Logos/Layer1/Completeness.lean:45 - Added 2 missing match cases
- Logos/Layer0/Basic.lean:23 - Renamed unused variable 'h' to '_h'

All modules built successfully.
```

### Dry Run

```
$ /lake --dry-run

Running lake build...

Lake Build Dry Run
==================

Would apply 2 fixes:

1. Logos/Layer1/Completeness.lean:45
   Error: Missing cases: Formula.implies, Formula.iff
   Fix: Add 2 match cases with sorry placeholders

2. Logos/Layer0/Basic.lean:23
   Warning: unused variable 'h'
   Fix: Rename to '_h'

No changes made (dry run mode).
```

### Build Already Passing

```
$ /lake

Running lake build...

Lake Build Complete
===================

Build succeeded on first attempt.
No fixes needed.
```
