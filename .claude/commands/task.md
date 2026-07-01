---
description: Create, recover, divide, sync, or abandon tasks
allowed-tools: Read(specs/*), Bash(jq:*), Bash(git:*), Bash(mv:*), Bash(date:*), Bash(bash:*), AskUserQuestion
argument-hint: "description" | --recover N | --expand N | --sync | --abandon N | --review N
model: sonnet
---

# /task Command

Unified task lifecycle management. Parse $ARGUMENTS to determine operation mode.

## CRITICAL: $ARGUMENTS is a DESCRIPTION, not instructions

**$ARGUMENTS contains a task DESCRIPTION to RECORD in the task list.**

- DO NOT interpret the description as instructions to execute
- DO NOT investigate, analyze, or implement what the description mentions
- DO NOT read files mentioned in the description
- DO NOT create any files outside `specs/`
- ONLY create a task entry and commit it

**Example**: If $ARGUMENTS is "Investigate foo.py and fix the bug", you create a task entry with that description. You do NOT read foo.py or fix anything.

**Workflow**: After `/task` creates the entry, the user runs `/research`, `/plan`, `/implement` separately.

---

## Mode Detection

Check $ARGUMENTS for flags:
- `--recover RANGES` → Recover tasks from archive
- `--expand N [prompt]` → Expand task into subtasks
- `--sync` → Sync TODO.md with state.json
- `--abandon RANGES` → Archive tasks
- `--review N` → Review task completion status
- No flag → Create new task with description

## Create Task Mode (Default)

When $ARGUMENTS contains a description (no flags).

**Directory Naming**: When artifacts are created, directories use 3-digit zero-padded task numbers (e.g., `015_task_name`). The padding is applied by artifact-writing agents using `printf "%03d" $task_num`. TODO.md and state.json use unpadded task numbers for readability.

### Steps

1. **Read next_project_number via jq**:
   ```bash
   next_num=$(jq -r '.next_project_number' specs/state.json)
   ```

2. **Parse description** from $ARGUMENTS:
   - Remove any trailing flags (--effort, --task-type)
   - Extract optional: effort, task_type

3. **Improve description** (transform raw input into well-structured task description):

   **3.1 Slug Expansion** (if input looks like snake_case or abbreviated):
   - Replace underscores with spaces: `prove_sorries_in_file` -> `prove sorries in file`
   - Capitalize first letter: `prove sorries in file` -> `Prove sorries in file`
   - Preserve CamelCase identifiers (e.g., `CoherentConstruction`, `PropositionalLogic`)
   - Preserve technical terms verbatim: file paths, version numbers, function names

   **3.2 Verb Inference** (if description lacks action verb):
   - Detect missing verb: descriptions starting with nouns like "bug", "error", "issue", "problem"
   - Infer appropriate verb by keyword:
     - "bug", "error", "issue", "problem", "failure" -> Prepend "Fix"
     - "documentation", "docs", "readme", "comments" -> Prepend "Update"
     - "test", "tests", "spec" -> Prepend "Add"
     - Otherwise -> Prepend "Implement" (safe default)
   - Example: `bug in modal evaluator` -> `Fix bug in modal evaluator`

   **3.3 Formatting Normalization**:
   - Capitalize first letter of description
   - Collapse multiple spaces to single space
   - Trim leading/trailing whitespace
   - Ensure no trailing period (task titles don't end with periods)

   **Preserve Exactly** (DO NOT transform):
   - File paths: `src/components/Button.tsx`
   - CamelCase identifiers: `CoherentConstruction`, `PropositionalLogic`
   - Quoted strings: `"exact phrase here"`
   - Technical identifiers: `lean4`, `v4.3.0`, `#123`
   - Already well-formed descriptions (start with verb, proper capitalization)

   **Transformation Examples**:

   | Input | Output | Transformation Applied |
   |-------|--------|------------------------|
   | `prove_sorries_in_coherentconstruction` | `Prove sorries in CoherentConstruction` | Slug expansion + CamelCase preserved |
   | `bug in modal evaluator` | `Fix bug in modal evaluator` | Verb inference (Fix) + capitalize |
   | `documentation for new API` | `Update documentation for new API` | Verb inference (Update) |
   | `tests for validation module` | `Add tests for validation module` | Verb inference (Add) |
   | `new caching layer` | `Implement new caching layer` | Verb inference (Implement default) |
   | `Update TODO.md header metrics` | `Update TODO.md header metrics` | No change (already well-formed) |
   | `Fix the race condition in handlers` | `Fix the race condition in handlers` | No change (starts with verb) |
   | `implement_option_b_canonical_models` | `Implement option b canonical models` | Slug expansion |

   **Edge Cases**:
   - Input with quotes: `Add "hello world" test` -> No change to quoted content
   - Input with file path: `Fix bug in src/config/lsp.lua` -> Preserve path exactly
   - Input with version: `Update to python v3.12` -> Preserve version identifier
   - Input with issue ref: `Fix #123 memory leak` -> Preserve issue reference
   - CamelCase preserved: `prove_CoherentConstruction_complete` -> `Prove CoherentConstruction complete`

   **Action Verb Categories**:
   - **Fix**: bug, error, issue, problem, failure, crash, regression
   - **Update**: documentation, docs, readme, comments, config, settings
   - **Add**: test, tests, spec, feature, support, capability
   - **Implement**: (default for unrecognized patterns)

4. **Detect task_type** from keywords:

   First, check for a project-level default:
   ```bash
   default_type=$(jq -r '.default_task_type // empty' specs/state.json)
   ```

   Then apply precedence rules (first match wins, stop checking):

   **4a. Meta keywords (always win, unconditional)**:
   - "meta", "agent", "command", "skill" in description → task_type = `meta`, done

   **4b. Extension keyword_overrides (scan manifests)**:
   Scan `.claude/extensions/*/manifest.json` for `keyword_overrides` fields.
   For each manifest that has `keyword_overrides`:
   - For each task_type key in `keyword_overrides`:
     - If any string in `keywords` array appears as a whole word in the
       description (case-insensitive) → task_type = that key, done

   Reference jq pattern for keyword scanning:
   ```bash
   for manifest in .claude/extensions/*/manifest.json; do
     [ -f "$manifest" ] || continue
     matched=$(jq -r --arg desc "$description_lower" '
       .keyword_overrides // {} | to_entries[] |
       select(.value.keywords[]? as $kw |
         ($desc | test("\\b" + $kw + "\\b"))) |
       .key' "$manifest" 2>/dev/null | head -1)
     [ -n "$matched" ] && break
   done
   ```
   If `matched` is non-empty → task_type = `matched`, skip to step 4e.

   **4c. Project default** (if `default_type` is non-empty): task_type = `default_type`, skip to step 4e.

   **4d. Hardcoded keyword table** (fallback):
   - "lean", "lean4", "mathlib", "theorem", "proof" → lean4
   - "latex", "tex", "document", "typeset" → latex
   - "typst" → typst
   - "python", "pytest", "pip" → python
   - "z3", "smt", "solver", "constraint" → z3
   - "nix", "nixos", "home-manager", "flake" → nix
   - "web", "astro", "tailwind", "cloudflare" → web
   - "epidemiology", "epi", "cohort", "case-control", "strobe" → epi:study
   - "formal", "logic", "math", "physics", "modal", "kripke" → formal
   - "deck", "slide", "presentation", "pitch deck" → founder:deck
   - "spreadsheet", "sheet", "excel" → founder:sheet
   - "finance", "financial", "revenue", "burn rate" → founder:finance
   - "market size", "tam", "sam", "som" → founder:market
   - "competitive", "competitor" → founder:analyze
   - "strategy", "strategic", "roadmap" → founder:strategy
   - "legal", "contract", "agreement" → founder:legal
   - "project plan", "timeline", "milestone" → founder:project
   - "founder", "go-to-market", "gtm" → founder
   - Otherwise → general

   **4e. Extension alias remapping** (post-resolution):
   After 4c or 4d resolves a task_type, scan manifests for alias matches:
   - For each manifest with `keyword_overrides`:
     - For each task_type key: if `aliases` array contains the current
       task_type → remap to the extension's task_type, done

   Reference jq pattern for alias remapping:
   ```bash
   for manifest in .claude/extensions/*/manifest.json; do
     [ -f "$manifest" ] || continue
     aliased=$(jq -r --arg tt "$task_type" '
       .keyword_overrides // {} | to_entries[] |
       select(.value.aliases[]? == $tt) |
       .key' "$manifest" 2>/dev/null | head -1)
     [ -n "$aliased" ] && { task_type="$aliased"; break; }
   done
   ```

   Note: Alias remapping applies only to results from 4c/4d (project default
   and hardcoded table). Extension keyword matches from 4b are final and
   not subject to alias remapping by other extensions.

4.5. **Assign topic** to this task:

   Follow @.claude/context/patterns/topic-assignment-pattern.md (Mode A: Interactive).
   Capture the selected topic in `$topic`.

   After topic selection:
   ```bash
   bash .claude/scripts/manage-topics.sh set "$next_num" "$topic"
   ```

5. **Create slug** from description:
   - Lowercase, replace spaces with underscores
   - Remove special characters
   - Max 50 characters

6. **Update state.json** (via jq):
   ```bash
   # Include topic field only if not null/skipped
   # Build topic from step 4.5 result
   # $improved_desc is the final description from step 3 text transformation
   jq --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
     --arg topic "$topic" \
     --arg desc "$improved_desc" \
     '.next_project_number = {NEW_NUMBER} |
      .active_projects = [{
        "project_number": {N},
        "project_name": "slug",
        "status": "not_started",
        "task_type": "detected",
        "description": $desc,
        "topic": (if ($topic == "" | not) then $topic else null end),
        "created": $ts,
        "last_updated": $ts
      } | if .topic == null then del(.topic) else . end] + .active_projects' \
     specs/state.json > specs/tmp/state.json && \
     mv specs/tmp/state.json specs/state.json
    ```

7. **Regenerate TODO.md** from state.json (handles frontmatter, task entries, and Task Order):
   ```bash
   bash .claude/scripts/generate-todo.sh \
     2>/dev/null || echo "Note: Failed to regenerate TODO.md (non-fatal)" >&2
   ```

8. **Git commit**:
   ```
   git add specs/
   git commit -m "task {N}: create {title}"
   ```

9. **Output**:
   ```
   Task #{N} created: {TITLE}
   Status: [NOT STARTED]
   Task Type: {task_type}
   Artifacts path: specs/{NNN}_{SLUG}/  (created on first artifact)
   ```
   Note: `{NNN}` is the 3-digit padded task number (e.g., `015` for task 15). Directories are created lazily when the first artifact is written.

## Recover Mode (--recover)

Parse task ranges after --recover (e.g., "343-345", "337, 343"):

<!-- NOTE: command-gate-in.sh does NOT apply here. gate-in reads active_projects only;
     recover mode looks up tasks from specs/archive/state.json (completed_projects).
     The inline archive lookup below is intentional. -->

1. For each task number in range:
   **Lookup task in archive via jq**:
   ```bash
   task_data=$(jq -r --arg num "$task_number" \
     '.completed_projects[] | select(.project_number == ($num | tonumber))' \
     specs/archive/state.json)

   if [ -z "$task_data" ]; then
     echo "Error: Task $task_number not found in archive"
     exit 1
   fi

   # Get project name for directory move
   slug=$(echo "$task_data" | jq -r '.project_name')
   ```

   **Move to active_projects via jq** (two-step to avoid jq escaping bug - see `jq-escaping-workarounds.md`):
   ```bash
   # Step 1: Remove from archive using del() instead of map(select(!=))
   jq --arg num "$task_number" \
     'del(.completed_projects[] | select(.project_number == ($num | tonumber)))' \
    specs/archive/state.json > specs/tmp/archive.json && \
    mv specs/tmp/archive.json specs/archive/state.json

   # Step 2: Add to active with status reset
    jq --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" --argjson task "$task_data" \
      '.active_projects = [$task | .status = "not_started" | .last_updated = $ts] + .active_projects' \
      specs/state.json > specs/tmp/state.json && \
      mv specs/tmp/state.json specs/state.json
   ```

   **Move project directory from archive** (handle both legacy unpadded and new padded formats):
   ```bash
   PADDED_NUM=$(printf "%03d" "$task_number")
   # Check legacy unpadded format first (e.g., 15_slug), then padded (e.g., 015_slug)
   if [ -d "specs/archive/${task_number}_${slug}" ]; then
     mv "specs/archive/${task_number}_${slug}" "specs/${PADDED_NUM}_${slug}"
   elif [ -d "specs/archive/${PADDED_NUM}_${slug}" ]; then
     mv "specs/archive/${PADDED_NUM}_${slug}" "specs/${PADDED_NUM}_${slug}"
   fi
   ```
   Note: Recovered directories always use 3-digit padding regardless of source format.

   **Regenerate TODO.md** from state.json:
   ```bash
   bash .claude/scripts/generate-todo.sh \
     2>/dev/null || echo "Note: Failed to regenerate TODO.md (non-fatal)" >&2
   ```

2. Git commit: "task: recover tasks {ranges}"

## Expand Mode (--expand)

Parse task number and optional prompt:

1. **Lookup task via gate-in**:
   ```bash
   # Note: command-gate-in.sh reads active_projects only (not archive).
   # This is correct for expand mode which operates on active tasks.
   source .claude/scripts/command-gate-in.sh "$task_number" "expand"
   # Exports: SESSION_ID, TASK_TYPE, TASK_STATUS, PROJECT_NAME, DESCRIPTION, PADDED_NUM
   # gate_in exits with error if task not found or in terminal status
   ```

2. Analyze description for natural breakpoints (use DESCRIPTION exported by gate-in)

2.5. **Read parent topic** for inheritance:
   ```bash
   parent_topic=$(jq -r --arg num "$task_number" \
     '.active_projects[] | select(.project_number == ($num | tonumber)) | .topic // ""' \
     specs/state.json)
   ```

   **Mode B Fallback Picker**: If `parent_topic` is empty, show a full Mode A interactive picker:
   ```bash
   if [[ -z "$parent_topic" ]]; then
     mapfile -t existing_topics < <(bash .claude/scripts/manage-topics.sh list)
     # Show AskUserQuestion picker (existing topics + "New topic..." + "Skip (no topic)")
   fi
   ```
   AskUserQuestion:
   ```json
   {
     "question": "Assign a topic to subtasks (parent has none)?",
     "header": "Topic",
     "multiSelect": false,
     "options": ["<existing-topic-1>", "<existing-topic-2>", "New topic...", "Skip (no topic)"]
   }
   ```
   - If user selects an existing topic → `parent_topic="$selected"`
   - If user selects "New topic..." → free-text follow-up, capture as `parent_topic`
   - If user selects "Skip (no topic)" → `parent_topic=""` (no topic assigned)

3. **Create 2-5 subtasks** using the Create Task jq pattern for each, inheriting parent topic:
   ```bash
   # Each subtask jq entry MUST include a "description" field:
   # where $subtask_desc is the subtask's description derived from the parent task analysis.
   # Include "topic": parent_topic in each subtask jq entry (if parent has a topic)
   # After each subtask entry is written to state.json, call manage-topics.sh set:
   if [[ -n "$parent_topic" ]]; then
     bash .claude/scripts/manage-topics.sh set "$subtask_num" "$parent_topic" \
       2>/dev/null || echo "Warning: manage-topics.sh set failed (non-fatal)" >&2
   fi
   ```

4. **Update original task** to reference subtasks and set status to expanded:
   ```bash
   jq --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
     '(.active_projects[] | select(.project_number == '$task_number')) |= . + {
       status: "expanded",
       subtasks: [list_of_subtask_numbers],
       last_updated: $ts
      }' specs/state.json > specs/tmp/state.json && \
      mv specs/tmp/state.json specs/state.json

5. **Regenerate TODO.md** from state.json after all subtask state.json writes complete:
   ```bash
   bash .claude/scripts/generate-todo.sh \
     2>/dev/null || echo "Note: Failed to regenerate TODO.md (non-fatal)" >&2
   ```

6. Git commit: "task {N}: expand into subtasks"

## Sync Mode (--sync)

state.json is the authoritative source of truth. Sync validates integrity and regenerates TODO.md.

1. **Validate state.json integrity**:
   ```bash
   state_tasks=$(jq -r '.active_projects[].project_number' specs/state.json | sort -n)
   state_next=$(jq -r '.next_project_number' specs/state.json)
   # Verify state.json is valid JSON
   jq empty specs/state.json || { echo "Error: state.json is invalid JSON"; exit 1; }
   ```

2. **Identify orphan TODO.md tasks** not in state.json (warn user only, do not auto-add):
   ```bash
   todo_tasks=$(grep -o "^### [0-9]\+\." specs/TODO.md | sed 's/[^0-9]//g' | sort -n)
   # Warn about tasks in TODO.md but not in state.json (orphans)
   for task_num in $todo_tasks; do
     if ! jq -e --argjson n "$task_num" '.active_projects[] | select(.project_number == $n)' specs/state.json > /dev/null 2>&1; then
       echo "Warning: Task $task_num in TODO.md not found in state.json (orphan)"
     fi
   done
   ```

2.5. **Artifact reconciliation** — backfill missing artifact registrations:
   ```bash
   bash .claude/scripts/reconcile-artifacts.sh
   ```

3. **Regenerate TODO.md from state.json** (single authoritative operation):
   ```bash
   bash .claude/scripts/generate-todo.sh \
     2>/dev/null || echo "Warning: generate-todo.sh failed (non-fatal)" >&2
   ```

6.5. **Topic backfill** for tasks missing the `topic` field:

   Detect active tasks without a topic:
   ```bash
   missing_topics=$(jq -r '.active_projects[] |
     select(.status == "completed" | not) |
     select(.status == "abandoned" | not) |
     select(.status == "expanded" | not) |
     select(.topic == null or .topic == "") |
     "\(.project_number)|\(.project_name)"
   ' specs/state.json)
   ```

   If any tasks need backfill, follow @.claude/context/patterns/topic-assignment-pattern.md
   (Mode A: Interactive, per-task backfill variant). Loop over detected tasks with header
   "Topic Backfill ({i} of {total})".

   After each topic selection:
   ```bash
   bash .claude/scripts/manage-topics.sh set "$task_num" "$topic"
   ```

7. Git commit: "sync: reconcile TODO.md and state.json"

## Review Mode (--review)

Parse task number after --review (e.g., `--review 597`):

### Step 1: Validate Task Exists

**Lookup task via jq**:
```bash
task_number="{N from arguments}"
task_data=$(jq -r --arg num "$task_number" \
  '.active_projects[] | select(.project_number == ($num | tonumber))' \
  specs/state.json)

if [ -z "$task_data" ]; then
  echo "Error: Task $task_number not found in active projects"
  exit 1
fi

# Extract task metadata
slug=$(echo "$task_data" | jq -r '.project_name')
status=$(echo "$task_data" | jq -r '.status')
task_type=$(echo "$task_data" | jq -r '.task_type // "general"')
```

### Step 2: Load Task Artifacts

**Find task directory** (handle both legacy unpadded and new padded formats):
```bash
PADDED_NUM=$(printf "%03d" "$task_number")
# Check padded format first (new), then unpadded (legacy)
if [ -d "specs/${PADDED_NUM}_${slug}" ]; then
  task_dir="specs/${PADDED_NUM}_${slug}"
elif [ -d "specs/${task_number}_${slug}" ]; then
  task_dir="specs/${task_number}_${slug}"
else
  task_dir=""  # No directory exists yet
fi
```

**Find and load plan file**:
```bash
plan_file=""
if [ -n "$task_dir" ]; then
  plan_dir="${task_dir}/plans"
  plan_file=$(ls -t "$plan_dir"/*.md 2>/dev/null | head -1)
fi

if [ -z "$plan_file" ]; then
  echo "No implementation plan found for task $task_number"
  echo "Recommendation: Run /plan $task_number to create a plan"
  # Continue - can still report on task status
fi
```

**Find and load summary file** (if exists):
```bash
summary_file=""
if [ -n "$task_dir" ]; then
  summary_dir="${task_dir}/summaries"
  summary_file=$(ls -t "$summary_dir"/*-summary.md 2>/dev/null | head -1)
fi
```

**Find research reports** (for context):
```bash
research_files=""
if [ -n "$task_dir" ]; then
  reports_dir="${task_dir}/reports"
  research_files=$(ls "$reports_dir"/*.md 2>/dev/null | grep -v README)
fi
```

### Step 3: Parse Plan Phases

**Extract phase statuses from plan file**:
```bash
# Parse phase headings with status markers
# Format: ### Phase N: Name [STATUS]
phases=$(grep -E "^### Phase [0-9]+:" "$plan_file" 2>/dev/null)

# Build phase analysis:
# - phase_number
# - phase_name
# - status: [NOT STARTED], [IN PROGRESS], [COMPLETED], [PARTIAL], [BLOCKED]
```

**Categorize phases**:
- **Completed**: Phases with `[COMPLETED]` status
- **In Progress**: Phases with `[IN PROGRESS]` status
- **Not Started**: Phases with `[NOT STARTED]` status
- **Partial**: Phases with `[PARTIAL]` status
- **Blocked**: Phases with `[BLOCKED]` status

### Step 4: Generate Review Summary

**Display task overview**:
```
## Task Review: #{N} - {slug}

**Status**: {status from state.json}
**Task Type**: {task_type}

### Artifacts Found
- Plan: {path or "Not found"}
- Summary: {path or "Not found"}
- Research: {count} report(s)

### Phase Analysis
| Phase | Name | Status |
|-------|------|--------|
| 1 | {name} | [COMPLETED] |
| 2 | {name} | [IN PROGRESS] |
| 3 | {name} | [NOT STARTED] |

### Completion Assessment
- Total phases: {N}
- Completed: {N}
- Remaining: {N}
```

### Step 5: Identify Incomplete Work

For each incomplete phase, extract:
- Phase number and name
- Phase goal (from **Goal**: line in plan)
- Estimated effort (if available)
- Dependencies (if any)

### Step 6: Generate Follow-up Task Suggestions

**For each incomplete phase, generate suggestion**:
```markdown
### Suggested Follow-up Tasks

1. **Complete phase {P} of task {N}: {phase_name}**
   - Goal: {extracted phase goal}
   - Effort: {inherited or "TBD"}
   - Task Type: {inherited from parent}
   - Ref: Parent task #{N}
```

**No suggestions if**:
- All phases are `[COMPLETED]`
- No plan file exists

### Step 7: Interactive User Selection

**Use AskUserQuestion with multiSelect**:
```json
{
  "question": "Select follow-up tasks to create:",
  "header": "Follow-up Tasks",
  "multiSelect": true,
  "options": [
    {
      "label": "Phase 2: implement_validation_rules",
      "description": "Goal: {phase_goal} | Effort: {effort}"
    },
    {
      "label": "Phase 3: add_error_reporting",
      "description": "Goal: {phase_goal} | Effort: {effort}"
    }
  ]
}
```

**For >20 incomplete phases**, add "Select all" option:
```json
{
  "label": "Select all",
  "description": "Create tasks for all {N} incomplete phases"
}
```

**Selection handling**:
- Selected options → Create those specific tasks
- Empty selection → Exit without creating tasks (no separate "none" option needed)
- "Select all" selected → Create all suggested tasks

### Step 7.5: Read Parent Topic for Inheritance

Before creating follow-up tasks, read the parent task's topic:
```bash
parent_topic=$(jq -r --arg num "$task_number" \
  '.active_projects[] | select(.project_number == ($num | tonumber)) | .topic // ""' \
  specs/state.json)
```

### Step 7.6: Fallback Topic Picker

If `parent_topic` is empty, the parent task has no topic. Show a full Mode A interactive picker:
```bash
if [[ -z "$parent_topic" ]]; then
  mapfile -t existing_topics < <(bash .claude/scripts/manage-topics.sh list)
  # Show AskUserQuestion picker (existing topics + "New topic..." + "Skip (no topic)")
fi
```

AskUserQuestion:
```json
{
  "question": "Assign a topic to follow-up tasks (parent has none)?",
  "header": "Topic",
  "multiSelect": false,
  "options": ["<existing-topic-1>", "<existing-topic-2>", "New topic...", "Skip (no topic)"]
}
```

- If user selects an existing topic → `parent_topic="$selected"`
- If user selects "New topic..." → free-text follow-up, capture as `parent_topic`
- If user selects "Skip (no topic)" → `parent_topic=""` (no topic assigned)

### Step 8: Create Selected Follow-up Tasks

For each selected task, use the Create Task jq pattern:

```bash
# Get next task number
next_num=$(jq -r '.next_project_number' specs/state.json)

# Create follow-up task
description="Complete phase {P} of task {parent_N}: {phase_name}. Goal: {phase_goal}. (Follow-up from task #{parent_N})"

# Update state.json (inherit parent topic if available)
jq --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  --arg desc "$description" \
  --arg topic "$parent_topic" \
  '.next_project_number = ($next_num + 1) |
   .active_projects = [{
     "project_number": '$next_num',
     "project_name": "followup_{parent_N}_phase_{P}",
     "status": "not_started",
     "task_type": "'{task_type}'",
     "topic": (if ($topic == "" | not) then $topic else null end),
     "description": $desc,
     "parent_task": '{parent_N}',
     "created": $ts,
     "last_updated": $ts
   } | if .topic == null then del(.topic) else . end] + .active_projects' \
     specs/state.json > specs/tmp/state.json && \
     mv specs/tmp/state.json specs/state.json

# After state.json write, assign topic via manage-topics.sh (non-blocking)
if [[ -n "$parent_topic" ]]; then
  bash .claude/scripts/manage-topics.sh set "$next_num" "$parent_topic" \
    2>/dev/null || echo "Warning: manage-topics.sh set failed for task $next_num (non-fatal)" >&2
fi
```

After all follow-up task state.json writes complete, **regenerate TODO.md**:
```bash
bash .claude/scripts/generate-todo.sh \
  2>/dev/null || echo "Note: Failed to regenerate TODO.md (non-fatal)" >&2
```

### Step 9: Output Results

**If tasks were created**:
```
Created {N} follow-up task(s):
  - Task #{X}: Complete phase 2 of task 597: implement_validation_rules
  - Task #{Y}: Complete phase 3 of task 597: add_error_reporting
```

**Git commit** (only if tasks were created):
```
git add specs/
git commit -m "task {parent_N}: review - created {N} follow-up tasks"
```

**If no tasks created**:
```
Review complete. No follow-up tasks created.
```

### Review Mode Constraints

- **READ-ONLY** analysis until user explicitly selects tasks to create
- Does NOT modify the reviewed task's status
- Does NOT fix inconsistencies (use --sync for that)
- Does NOT auto-create tasks without user confirmation
- Gracefully handles missing artifacts (plan, summary, research)

### Standards Reference (--review mode)

This mode implements the multi-task creation pattern. See `.claude/docs/reference/standards/multi-task-creation-standard.md` for the complete standard.

**Compliance Level**: Partial (simplified for follow-up tasks)

| Component | Status | Notes |
|-----------|--------|-------|
| Discovery | Yes | Incomplete phases from plan file |
| Selection | Yes | Numbered list selection |
| Grouping | No | One task per phase |
| Dependencies | Partial | parent_task linking only |
| Ordering | No | Phase number is implicit order |
| Visualization | No | Not implemented |
| Confirmation | Yes | Explicit selection required |
| State Updates | Yes | Standard task creation |

**Note**: Topological sorting is not needed because follow-up tasks inherit natural ordering from plan phase numbers. The parent_task field provides traceability to the original task.

## Abandon Mode (--abandon)

Parse task ranges:

1. For each task:
   **Lookup and validate task via gate-in**:
   ```bash
   # Note: command-gate-in.sh reads active_projects only (not archive).
   # This is correct for abandon mode which operates on active tasks.
   # gate_in also guards against abandoning already-terminal tasks.
   source .claude/scripts/command-gate-in.sh "$task_number" "abandon"
   # Exports: SESSION_ID, TASK_TYPE, TASK_STATUS, PROJECT_NAME, DESCRIPTION, PADDED_NUM
   # gate_in exits with error if task not found or already in terminal status
   slug="$PROJECT_NAME"
   ```

   **Read full task JSON for archive operation** (gate-in validated existence; read blob for jq insert):
   ```bash
   task_data=$(jq -c --argjson num "$task_number" \
     '.active_projects[] | select(.project_number == $num)' \
     specs/state.json)
   ```

   **Move to archive via jq** (two-step to avoid jq escaping bug - see `jq-escaping-workarounds.md`):
   ```bash
    # Step 1: Add to archive with abandoned status
    jq --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" --argjson task "$task_data" \
      '.completed_projects = [$task | .status = "abandoned" | .abandoned = $ts] + .completed_projects' \
      specs/archive/state.json > specs/tmp/archive.json && \
      mv specs/tmp/archive.json specs/archive/state.json

    # Step 2: Remove from active using del() instead of map(select(!=))
    jq --arg num "$task_number" \
      'del(.active_projects[] | select(.project_number == ($num | tonumber)))' \
      specs/state.json > specs/tmp/state.json && \
      mv specs/tmp/state.json specs/state.json
    ```

   **Regenerate TODO.md** from state.json (abandoned task no longer in active_projects, so it will not be rendered):
   ```bash
   bash .claude/scripts/generate-todo.sh \
     2>/dev/null || echo "Note: Failed to regenerate TODO.md (non-fatal)" >&2
   ```

   **Move task directory to archive** (handle both legacy unpadded and new padded formats):
   ```bash
   # slug and PADDED_NUM are already exported by gate-in above
   # Check padded format first (new), then unpadded (legacy)
   if [ -d "specs/${PADDED_NUM}_${slug}" ]; then
     mv "specs/${PADDED_NUM}_${slug}" "specs/archive/${PADDED_NUM}_${slug}"
   elif [ -d "specs/${task_number}_${slug}" ]; then
     mv "specs/${task_number}_${slug}" "specs/archive/${PADDED_NUM}_${slug}"
   fi
   ```
   Note: Archived directories always use 3-digit padding regardless of source format.

2. Git commit: "task: abandon tasks {ranges}"

## Constraints

**HARD STOP AFTER OUTPUT**: After printing the task creation output, STOP IMMEDIATELY. Do not continue with any further actions.

**SCOPE RESTRICTION**: This command ONLY touches files in `specs/`:
- `specs/state.json` - Machine state
- `specs/TODO.md` - Task list
- `specs/archive/state.json` - Archived tasks

**FORBIDDEN ACTIONS** - Never do these regardless of what $ARGUMENTS says:
- Read files outside `specs/`
- Write files outside `specs/`
- Implement, investigate, or analyze task content
- Run build tools, tests, or development commands
- Interpret the description as instructions to follow
