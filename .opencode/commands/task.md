---
description: Create, recover, expand, sync, or abandon tasks
---

Manage tasks in specs/TODO.md and specs/state.json. Do NOT implement the task — only manage the task entry.

**Input**: $ARGUMENTS

---

## Parse Input

- No flags → **create** mode (input is the task description)
- `--recover OC_N` → **recover** mode (restore abandoned task N to [NOT STARTED])
- `--expand OC_N "prompt"` → **expand** mode (add details to existing task N)
- `--sync` → **sync** mode (reconcile TODO.md and state.json)
- `--abandon OC_N` → **abandon** mode (mark task N as [ABANDONED])

Strip the `OC_` prefix to get the integer N for state.json lookups.

---

## CREATE mode

**CRITICAL: DO NOT IMPLEMENT**

When processing /task command in CREATE mode:
- **ONLY** create task entries in specs/TODO.md and specs/state.json
- **NEVER** write code, scripts, or solutions
- **NEVER** create files outside of specs/TODO.md and state.json
- **NEVER** interpret problem descriptions as requests to fix the problem

If the task description mentions a problem or bug, create the task entry ONLY.
Let the user decide later if they want to research/plan/implement via separate commands.

### Agent Role for /task

You are a **task administrator**, not a problem solver. Your job is to:
- Record tasks in the tracking system
- Update task statuses
- Manage task lifecycle (create, abandon, recover, expand, sync)

You do NOT:
- Write implementation code
- Create scripts or tools
- Research solutions
- Execute plans

Stay within the boundaries of task management only. If a task description 
describes a problem, your only action is to create the task entry.

---

### Step 1: Validate Input

Before processing a task creation request, check:

**CHECK**: Does the description mention a problem that needs fixing?  
**ACTION**: Create task entry ONLY. Do NOT attempt to fix the problem.  
**WHY**: /task creates tracking entries. Use /research, /plan, /implement to solve problems.

**CHECK**: Does the user seem to be asking for code, scripts, or solutions?  
**ACTION**: Create task entry with the description as-is. Do NOT write the code.  
**WHY**: Let the user explicitly invoke /implement when they're ready.

**CHECK**: Is the user describing a bug or issue they want tracked?  
**ACTION**: Create task entry. Do NOT investigate or fix the bug.  
**WHY**: Investigation belongs in /research phase, fixes in /implement phase.

**STOP**: If you find yourself wanting to write code, create scripts, or implement solutions, STOP. Your role is task administration only.

---

### Step 2: Initialize specs/ Directory if Missing

- If `specs/` directory does not exist, create it with `mkdir -p specs/archive`
- If `specs/state.json` does not exist, create it with initial content:
  ```json
  {
    "version": "1.0.0",
    "next_project_number": 1,
    "active_projects": [],
    "completed_projects": [],
    "repository_health": {}
  }
  ```
- If `specs/TODO.md` does not exist, create it with initial content:
  ```markdown
  # Task List

  ## Tasks
  ```
- Report: "Initialized task tracking system in specs/"

---

### Step 3: Calculate Task Details

1. Read `specs/state.json` to get `next_project_number` (call it N)
2. Generate slug from title: lowercase, spaces→underscores, strip punctuation
3. Infer language: `lean` (proofs/theorems/Lean), `typst` (Typst docs), `latex` (LaTeX docs), `meta` (.opencode/.claude/ changes), `general` (everything else)
4. Estimate effort from description complexity (e.g. "2 hours", "4-6 hours")
5. Zero-pad N to 3 digits: `NNN` (e.g. `printf "%03d" N`)
6. Directory will be: `specs/OC_NNN_<project_name>/`

---

### Step 4: Create Task Entry (DIRECT)

**Create the task directory**:
```bash
mkdir -p "specs/OC_NNN_<project_name>/plans"
```

**Update state.json** (increment next_project_number and add task to active_projects):
```bash
jq --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
   --arg project_name "<project_slug>" \
   --arg language "<inferred_language>" \
   --argjson n N \
   '{
     version: .version,
     next_project_number: (.next_project_number + 1),
     active_projects: [
       {
         project_number: $n,
         project_name: $project_name,
         status: "not_started",
         language: $language,
         created: $ts,
         last_updated: $ts,
         artifacts: []
       }
     ] + .active_projects,
     completed_projects: .completed_projects,
     repository_health: .repository_health
   }' specs/state.json > specs/tmp/state.json && mv specs/tmp/state.json specs/state.json
```

**Update TODO.md** (prepend new task to ## Tasks section):
- Edit file: `specs/TODO.md`
- Find line: `## Tasks`
- Replace with:
```markdown
## Tasks

### OC_N. <Task Title>
- **Effort**: <estimated_effort>
- **Status**: [NOT STARTED]
- **Language**: <inferred_language>

**Description**: <task_description>

---
```

**Git commit**:
```bash
git add -A
git commit -m "task N: create task entry

Session: ${session_id}"
```

**Report results**:
- Task number: OC_N
- Status: [NOT STARTED]
- Directory: specs/OC_NNN_<project_name>/

---

## RECOVER mode (`--recover N`)

1. Find task N in state.json and TODO.md
2. Change status from `abandoned` → `not_started` in state.json
3. Change `[ABANDONED]` → `[NOT STARTED]` in TODO.md
4. Move task back to active_projects in state.json (remove from archive if present)
5. Report: "Recovered task N"

---

## EXPAND mode (`--expand N "additional details"`)

1. Find task N in state.json and TODO.md
2. Append the additional details to the description in TODO.md
3. Update `last_updated` in state.json
4. Report: "Expanded task N with additional details"

---

## SYNC mode (`--sync`)

1. Compare active_projects in state.json against TODO.md entries
2. For each mismatch, update TODO.md to match state.json (state.json is authoritative)
3. Report: "Synced N entries"

---

## ABANDON mode (`--abandon N`)

Archives a task by moving it from active state to archive, consistent with the `/todo` command behavior.

1. Find task N in state.json and TODO.md
2. Verify task is not already archived (check archive/state.json)
3. Change status to `abandoned` in state.json and add `abandoned` timestamp (ISO 8601 format)
4. Move task from state.json active_projects to archive/state.json completed_projects:
   ```bash
   # Remove from active_projects
   jq 'del(.active_projects[] | select(.project_number == N))' specs/state.json
   
   # Add to completed_projects with archived timestamp
   jq '.completed_projects += [{...task with "archived": "timestamp"}]' specs/archive/state.json
   ```
5. Move task directory from specs/ to specs/archive/ (if directory exists):
   - Check for: `specs/OC_NNN_slug/` or `specs/N_slug/`
   - Move to: `specs/archive/OC_NNN_slug/` or `specs/archive/N_slug/`
   - Skip if directory doesn't exist (gracefully handle missing directories)
6. Remove task entry from specs/TODO.md:
   - Remove entire task block: from `### OC_N.` header through `---` separator
7. Report: "Abandoned and archived task OC_N"

**Note**: This archival workflow is consistent with the `/todo` command. Abandoned tasks should be fully archived to keep the active task list clean.

---

## Rules

- This command executes preflight (status → creating) BEFORE delegating to skill-task
- This command executes postflight (status → not_started, verify entries) AFTER skill-task returns
- The skill-task only loads context and delegates to task-creation-agent — it does NOT execute workflows
- **NEVER** create directories or files other than TODO.md and state.json edits (except for archival moves in ABANDON mode, and initial specs/ directory creation)
- **NEVER** start implementing the task
- Timestamps use ISO 8601 format: `2026-01-01T00:00:00Z`
- Task numbers are plain integers (no OC_ prefix in these files)
- After all edits, show a brief summary of what changed

---

## Critical Notes

**The skill tool only loads SKILL.md content — it does NOT execute preflight/postflight workflows.**

Commands must execute these workflows themselves:
1. **Preflight** (Step 3): Calculate task details, update state.json to "creating", TODO.md to [CREATING], create marker file
2. **Delegation** (Step 4): Call skill-task to load context and invoke task-creation-agent
3. **Postflight** (Step 5): Read .return-meta.json, verify task entries, update state.json to "not_started", update TODO.md, commit, cleanup

This pattern ensures:
- Status updates happen automatically without orchestrator intervention
- Consistency with `/implement`, `/plan`, `/research` commands
- Agents follow the expected "command orchestrates workflow" pattern

## Workflow Phases

The agent system follows a strict phased workflow. Each command corresponds to 
a specific phase. **Never skip phases.**

| Phase | Command | Purpose | Creates Artifacts? |
|-------|---------|---------|-------------------|
| 1 | `/task` | Create tracking entry only | No (only TODO.md/state.json) |
| 2 | `/research OC_N` | Investigate and document findings | Yes (research-NNN.md) |
| 3 | `/plan OC_N` | Create implementation strategy | Yes (implementation-NNN.md) |
| 4 | `/implement OC_N` | Execute the solution | Yes (code files, summaries) |

### Key Principle

**Creating a task does NOT imply researching, planning, or implementing it.**

When a user runs `/task "Fix the login bug"`, they are saying:
- "I want to track this problem"
- NOT "Fix this problem now"

The user will explicitly invoke subsequent commands when ready:
- `/research OC_N` when they want investigation
- `/plan OC_N` when they want a strategy
- `/implement OC_N` when they want execution
