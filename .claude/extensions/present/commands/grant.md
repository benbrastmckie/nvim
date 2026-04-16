---
description: Create grant tasks, execute grant workflows (draft, budget), or create revisions
allowed-tools: Skill, Bash(jq:*), Bash(git:*), Bash(date:*), Bash(sed:*), Read, Edit, AskUserQuestion
argument-hint: "description" | TASK_NUMBER --draft ["prompt"] | --budget ["prompt"] | --revise N "description" | TASK_NUMBER --fix-it
model: opus
---

# /grant Command

Hybrid command supporting both task creation and grant-specific workflows.

## Modes

| Mode | Syntax | Description |
|------|--------|-------------|
| Task Creation | `/grant "Description"` | Create task with language="present", task_type="grant" |
| Draft | `/grant N --draft ["prompt"]` | Draft narrative sections |
| Budget | `/grant N --budget ["prompt"]` | Develop line-item budget |
| Fix-It | `/grant N --fix-it` | Scan grant directory for FIX:/TODO: tags |
| Revise | `/grant --revise N "description"` | Create revision task for grant N |
| Legacy | `/grant N workflow_type [focus]` | (Deprecated) Direct workflow invocation |

## CRITICAL: Task Creation Mode

When $ARGUMENTS is a description (no flags, no task number), create a task with language="present" and task_type="grant".

**$ARGUMENTS contains a task DESCRIPTION to RECORD in the task list.**

- DO NOT interpret the description as instructions to execute
- DO NOT investigate, analyze, or implement what the description mentions
- ONLY create a task entry and commit it

---

## Mode Detection

Parse $ARGUMENTS to determine mode:

1. **Check for description** (quoted text, no leading number):
   - Pattern: String that doesn't start with a number
   - Mode: Task Creation

2. **Check for flags**:
   - `N --draft [prompt]` → Draft Mode
   - `N --budget [prompt]` → Budget Mode
   - `N --fix-it` → Fix-It Scan Mode
   - `--revise N "description"` → Revise Mode

3. **Check for legacy workflow_type**:
   - `N funder_research|proposal_draft|budget_develop|progress_track [focus]` → Legacy Mode

**Flag parsing with optional prompts**:
- Flag only: `/grant 500 --draft` → default behavior
- Flag with prompt: `/grant 500 --draft "Focus on methodology"` → guided behavior
- Prompt must be quoted text immediately after flag

---

## Task Creation Mode

When $ARGUMENTS is a description without flags.

### STAGE 0: PRE-TASK FORCING QUESTIONS

**This stage runs BEFORE task creation for new tasks (description input).**

#### Step 0.1: Grant Mechanism and Funder

Use AskUserQuestion:

```
What grant mechanism and funder is this for?

Examples: NIH R01, NSF CAREER, Open Philanthropy, Foundation (specify), SBIR Phase I
If unknown, describe the type of funding you are seeking.
```

Store response as `forcing_data.mechanism`.

#### Step 0.2: Existing Content Paths

Use AskUserQuestion:

```
Do you have existing content to inform this grant?

Provide any combination of:
- Task references (e.g., "task:500" to pull prior research)
- File paths to papers, manuscripts, or preliminary data
- "none" if starting fresh

Separate multiple entries with commas.
```

Store response as `forcing_data.content_paths` (parse into array).

#### Step 0.3: Regulatory and Compliance Materials

Use AskUserQuestion:

```
What regulatory or compliance materials are relevant?

Examples:
- PA/FOA URL (e.g., PAR-25-123)
- Institutional guidelines or overhead rate
- IRB/IACUC protocol numbers or status
- "none" if not applicable

List all that apply:
```

Store response as `forcing_data.regulatory_materials`.

#### Step 0.4: Grant Constraints

Use AskUserQuestion:

```
What constraints apply to this grant?

Include any of:
- Page limits (e.g., 12-page research plan)
- Required sections (e.g., specific aims, biosketch)
- Due date (e.g., Feb 5 2027)
- Budget ceiling (e.g., $250K/year direct costs)
- "none" if no specific constraints

List all known constraints:
```

Store response as `forcing_data.constraints`.

#### Step 0.5: Store Forcing Data

Capture all responses in a forcing_data object:
```json
{
  "mechanism": "{response_1}",
  "content_paths": ["{path_1}", "{path_2}"],
  "regulatory_materials": "{response_3}",
  "constraints": "{response_4}",
  "gathered_at": "{ISO timestamp}"
}
```

---

### Steps

1. **Read next_project_number via jq**:
   ```bash
   next_num=$(jq -r '.next_project_number' specs/state.json)
   ```

2. **Parse description** from $ARGUMENTS:
   - Remove any trailing flags
   - Extract description text

3. **Improve description** (same transformations as /task):
   - Slug expansion: `research_nih_funding` → `Research NIH funding`
   - Verb inference: If no action verb, prepend appropriate one
   - Formatting normalization: Capitalize, trim, no trailing period

4. **Set language = "present"** and **task_type = "grant"** (always for /grant task creation)

5. **Create slug** from description:
   - Lowercase, replace spaces with underscores
   - Remove special characters
   - Max 50 characters

6. **Update state.json** (via jq):
   ```bash
   jq --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
     --arg desc "$description" \
     --argjson forcing_data "$forcing_data_json" \
     '.next_project_number = {NEW_NUMBER} |
      .active_projects = [{
        "project_number": {N},
        "project_name": "slug",
        "status": "not_started",
        "task_type": "present",
        "task_type": "grant",
        "description": $desc,
        "forcing_data": $forcing_data,
        "created": $ts,
        "last_updated": $ts
      }] + .active_projects' \
     specs/state.json > specs/tmp/state.json && \
     mv specs/tmp/state.json specs/state.json
   ```

7. **Update TODO.md** (frontmatter AND entry):

   **Part A - Update frontmatter**:
   ```bash
   sed -i 's/^next_project_number: [0-9]*/next_project_number: {NEW_NUMBER}/' \
     specs/TODO.md
   ```

   **Part B - Add task entry** by prepending to `## Tasks` section:
   ```markdown
   ### {N}. {Title}
   - **Effort**: TBD
   - **Status**: [NOT STARTED]
   - **Task Type**: present
   - **Type**: grant

   **Description**: {description}
   ```

8. **Git commit**:
   ```bash
   git add specs/
   git commit -m "task {N}: create {title}

   Session: {session_id}

   ```

9. **Output**:
   ```
   Grant task #{N} created: {TITLE}
   Status: [NOT STARTED]
   Language: present
   Type: grant
   Artifacts path: specs/{NNN}_{SLUG}/ (created on first artifact)

   Recommended workflow:
   1. /research {N} - Research funders and requirements
   2. /grant {N} --draft - Draft narrative sections (exploratory)
   3. /grant {N} --budget - Develop budget (exploratory)
   4. /plan {N} - Create plan informed by drafts
   5. /implement {N} - Assemble grant materials to grants/{N}_{slug}/
   ```

---

## Draft Mode (--draft)

Execute proposal drafting workflow.

### Syntax
- `/grant N --draft` - Default drafting
- `/grant N --draft "Focus on innovation and methodology"` - Guided drafting

### CHECKPOINT 1: GATE IN

**Display header**:
```
[Grant Draft] Task {N}: {project_name}
```

1. **Generate Session ID**
   ```bash
   session_id="sess_$(date +%s)_$(od -An -N3 -tx1 /dev/urandom | tr -d ' ')"
   ```

2. **Lookup Task**
   ```bash
   task_data=$(jq -r --argjson num "$task_number" \
     '.active_projects[] | select(.project_number == $num)' \
     specs/state.json)
   ```

3. **Validate Task**
   - Task must exist (ABORT if not)
   - Language must be "present" and task_type must be "grant" (ABORT with message if not)
   - Status must allow drafting: researched, planned, partial, not_started
   - If completed/abandoned: ABORT with appropriate message

**Note**: Draft mode is an exploratory phase that can start after research (status: researched) or even before research (status: not_started) for rapid prototyping. Drafts inform the subsequent planning phase.

4. **Extract optional prompt**
   - Parse quoted text after --draft flag
   - If present: Pass to skill as `draft_prompt`
   - If absent: Use empty string (default behavior)

**ABORT** if validation fails.

### STAGE 2: DELEGATE

**Invoke Skill tool**:
```
skill: "skill-grant"
args: "task_number={N} workflow_type=proposal_draft focus={draft_prompt} session_id={session_id}"
```

### CHECKPOINT 2: GATE OUT

1. **Validate Return**
   - Check for error indicators

2. **Verify Artifacts**
   - Check for draft in specs/{NNN}_{SLUG}/drafts/

3. **Verify Status**
   - Confirm status is "planned" in state.json

**On success, output**:
```
Grant proposal draft created for Task #{N}

Draft: specs/{NNN}_{SLUG}/drafts/{MM}_narrative-draft.md

Status: [PLANNED]
Next: /grant {N} --budget, then /plan {N}
```

---

## Budget Mode (--budget)

Execute budget development workflow.

### Syntax
- `/grant N --budget` - Default budget template
- `/grant N --budget "Emphasize personnel costs, 3 conferences/year"` - Guided budget

### CHECKPOINT 1: GATE IN

**Display header**:
```
[Grant Budget] Task {N}: {project_name}
```

1. **Generate Session ID**
2. **Lookup and Validate Task** (same as Draft Mode)
3. **Extract optional prompt** after --budget flag

### STAGE 2: DELEGATE

**Invoke Skill tool**:
```
skill: "skill-grant"
args: "task_number={N} workflow_type=budget_develop focus={budget_prompt} session_id={session_id}"
```

### CHECKPOINT 2: GATE OUT

1. **Verify Artifacts**
   - Check for budget in specs/{NNN}_{SLUG}/budgets/

2. **Verify Status**
   - Confirm status is "planned" in state.json

**On success, output**:
```
Grant budget developed for Task #{N}

Budget: specs/{NNN}_{SLUG}/budgets/{MM}_line-item-budget.md

Status: [PLANNED]
Next: /plan {N} (to create implementation plan informed by drafts and budget)
```

---

## Revise Mode (--revise)

Create a new task to revise an existing grant.

### Syntax
- `/grant --revise N "description of changes"` - Create revision task for grant N

### CHECKPOINT 1: GATE IN

**Display header**:
```
[Grant Revise] Creating revision for Grant #{N}
```

1. **Generate Session ID**
   ```bash
   session_id="sess_$(date +%s)_$(od -An -N3 -tx1 /dev/urandom | tr -d ' ')"
   ```

2. **Parse Arguments**
   - Extract task number N (original grant task)
   - Extract revision description

3. **Validate Grant Exists**
   ```bash
   # Look up original grant task
   grant_task=$(jq -r --argjson num "$original_task_number" \
     '.active_projects[] | select(.project_number == $num)' \
     specs/state.json)

   # Check in archive if not found in active
   if [ -z "$grant_task" ]; then
     grant_task=$(jq -r --argjson num "$original_task_number" \
       '.completed_projects[] | select(.project_number == $num)' \
       specs/archive/state.json 2>/dev/null)
   fi

   # Validate found
   if [ -z "$grant_task" ]; then
     ABORT "Grant task #$original_task_number not found"
   fi

   # Extract grant directory
   grant_slug=$(echo "$grant_task" | jq -r '.project_name')
   grant_dir="grants/${original_task_number}_${grant_slug}"

   # Validate grant directory exists
   if [ ! -d "$grant_dir" ]; then
     ABORT "Grant directory not found: $grant_dir"
   fi
   ```

**ABORT** if validation fails.

### STAGE 2: CREATE REVISION TASK

1. **Get next_project_number**:
   ```bash
   next_num=$(jq -r '.next_project_number' specs/state.json)
   ```

2. **Create slug from revision description**:
   - Lowercase, replace spaces with underscores
   - Prefix with `revise_`

3. **Update state.json**:
   ```bash
   jq --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
     --arg desc "$revision_description" \
     --argjson parent "$original_task_number" \
     --arg revises_dir "$grant_dir" \
     '.next_project_number = {NEW_NUMBER} |
      .active_projects = [{
        "project_number": {NEW_N},
        "project_name": "revise_slug",
        "status": "not_started",
        "task_type": "present",
        "task_type": "grant",
        "description": $desc,
        "parent_grant": $parent,
        "revises_directory": $revises_dir,
        "created": $ts,
        "last_updated": $ts
      }] + .active_projects' \
     specs/state.json > specs/tmp/state.json && \
     mv specs/tmp/state.json specs/state.json
   ```

4. **Update TODO.md**:
   - Update frontmatter with new next_project_number
   - Add task entry with parent grant reference:
   ```markdown
   ### {NEW_N}. {Revision Title}
   - **Effort**: TBD
   - **Status**: [NOT STARTED]
   - **Task Type**: present
   - **Type**: grant
   - **Parent Grant**: Task #{N}

   **Description**: {revision_description}
   ```

### CHECKPOINT 2: COMMIT

```bash
git add specs/
git commit -m "task {NEW_N}: create revision for grant {N}

Session: {session_id}
```

**On success, output**:
```
Grant revision task #{NEW_N} created for Grant #{N}
Status: [NOT STARTED]
Language: present
Type: grant
Parent Grant: Task #{N}
Revises: {grant_dir}

Recommended workflow:
1. /grant {NEW_N} --draft "Focus on sections needing revision"
2. /grant {NEW_N} --budget "Update budget items as needed"
3. /implement {NEW_N} - Update existing grant directory
```

---

## Fix-It Scan Mode (--fix-it)

Scan grant directory for embedded tags and create structured tasks.

### Syntax
- `/grant N --fix-it` - Scan grant directory for FIX:, TODO:, NOTE:, QUESTION: tags

### CHECKPOINT 1: GATE IN

**Display header**:
```
[Grant Fix-It] Task {N}: {project_name}
```

1. **Generate Session ID**
   ```bash
   session_id="sess_$(date +%s)_$(od -An -N3 -tx1 /dev/urandom | tr -d ' ')"
   ```

2. **Lookup Task**
   ```bash
   task_data=$(jq -r --argjson num "$task_number" \
     '.active_projects[] | select(.project_number == $num)' \
     specs/state.json)
   ```

3. **Validate Task**
   - Task must exist (ABORT if not)
   - Language must be "present" and task_type must be "grant" (ABORT with message if not)
   - Status does not change for fix-it scan (non-destructive operation)

**ABORT** if validation fails.

### STAGE 2: DELEGATE

**Invoke Skill tool**:
```
skill: "skill-grant"
args: "task_number={N} workflow_type=fix_it_scan session_id={session_id}"
```

### CHECKPOINT 2: GATE OUT

1. **Validate Return**
   - Check for error indicators

2. **Verify Created Tasks**
   - If tasks were created, verify they appear in state.json

**On success, output**:
```
Grant fix-it scan completed for Task #{N}

{N} tasks created from embedded tags.

Status: [unchanged] (scan operation)
Next: /research {NEW_N} to begin work on created tasks
```

**On no tags found**:
```
Grant fix-it scan completed for Task #{N}

No FIX:, TODO:, NOTE:, or QUESTION: tags found in grant directory.

Nothing to create.
```

---

## Legacy Mode (Deprecated)

For backward compatibility, continue supporting:
- `/grant N funder_research [focus]`
- `/grant N proposal_draft [focus]`
- `/grant N budget_develop [focus]`
- `/grant N progress_track [focus]`

**Deprecation notice**: Display warning when legacy mode detected:
```
[Warning] Legacy workflow_type syntax is deprecated.
Use: /grant N --draft or --budget instead. For final assembly, use /implement N.
For funder research, use: /research N
```

Then proceed with legacy execution as documented in original command.

---

## Core Command Integration

Tasks with language="present" and task_type="grant" route through core commands:

| Command | Routes To | Purpose |
|---------|-----------|---------|
| `/research N` | skill-grant (funder_research) | Research funders |
| `/plan N` | skill-planner | Create implementation plan (informed by drafts/budgets) |
| `/implement N` | skill-grant (assemble) | Assemble grant materials |

**Note**: `/plan N` creates an implementation plan using the standard planner, not a proposal draft. The plan should reference existing draft and budget artifacts when available. This routing is configured in the extension's manifest.json.

---

## Error Handling

### Task Creation Errors
- Invalid description: Return guidance on expected format
- State update failure: Log error, do not commit partial state

### Workflow Errors
- Task not found: Return error with guidance to create task first
- Wrong language: Return error suggesting /grant for grant tasks
- Invalid status: Return error with current status and valid transitions

### Git Commit Failure
- Non-blocking: Log failure but continue with success response
- Report to user that manual commit may be needed

---

## Output Formats

### Task Creation Success
```
Grant task #{N} created: {TITLE}
Status: [NOT STARTED]
Language: present
Type: grant

Recommended workflow:
1. /research {N} - Research funders and requirements
2. /grant {N} --draft - Draft narrative sections (exploratory)
3. /grant {N} --budget - Develop budget (exploratory)
4. /plan {N} - Create plan informed by drafts
5. /implement {N} - Assemble grant materials to grants/{N}_{slug}/
```

### Workflow Success
```
{Workflow} completed for Task #{N}

{Artifact type}: {path}

Status: [{NEW_STATUS}]
Next: {recommended next step}
```

### Error Output
```
Grant command error:
- {error description}
- {recovery guidance}
```
