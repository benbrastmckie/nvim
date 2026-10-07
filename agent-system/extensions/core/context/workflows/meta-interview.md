# /meta Interview Workflow

**Runs in the invoking skill's own execution — never in a dispatched subagent.**
`AskUserQuestion` is measured categorically withheld from every `Agent`-tool dispatch of a named
`subagent_type`, independent of frontmatter configuration — see
`agent-system/extensions/core/docs/reference/standards/agent-frontmatter-standard.md`'s "Tool
Withholding from Dispatched Subagents" section for the full measured probe matrix; this file does
not duplicate that measurement. `skill-meta/SKILL.md`'s pre-delegation stage reads this file and
executes it inline, in the skill's own (non-subagent) execution context, collecting every answer
*before* dispatching `meta-builder-agent` for the terminal, non-interactive task-writing work
(Interview Stage 6 `CreateTasks` and Stage 7 `DeliverSummary`, which remain `meta-builder-agent`'s
own responsibility and are not relocated here).

This text is relocated **verbatim**, cut-and-paste, from `meta-builder-agent.md`'s former
Interview Stages 0-5 (interactive mode) and Stage 3B Steps 1-5 (prompt mode) — it is not a
summary or a rewrite. Every load-bearing constraint in the original prose is preserved exactly,
including Interview Stage 4.5's topic-picker having no Skip option, the mandatory Stage 5
`ReviewAndConfirm` confirmation gate, and the Stage 3 dependency-validation re-prompt.

---

## Interactive Mode: Interview Stages 0-5

Execute these stages using `AskUserQuestion` for every user-choice point. This is Interview
Stages 0 (`DetectExistingSystem`) through 5 (`ReviewAndConfirm`) of the original 7-stage
interview; Stages 6 (`CreateTasks`) and 7 (`DeliverSummary`) are non-interactive and run inside
the dispatched `meta-builder-agent` against the answers this workflow collects.

### Interview Stage 0: DetectExistingSystem

**Action**: Analyze existing .claude/ structure

```bash
# Count existing components at the resolved target root
cmd_count=$(ls "${TARGET_ROOT}/.claude/commands"/*.md 2>/dev/null | wc -l)
skill_count=$(find "${TARGET_ROOT}/.claude/skills" -name "SKILL.md" 2>/dev/null | wc -l)
agent_count=$(ls "${TARGET_ROOT}/.claude/agents"/*.md 2>/dev/null | wc -l)
rule_count=$(ls "${TARGET_ROOT}/.claude/rules"/*.md 2>/dev/null | wc -l)
active_tasks=$(jq '.active_projects | length' "${TARGET_ROOT}/specs/state.json")
```

**Output**:
```
## Existing .claude/ System Detected

**Components**:
- Commands: {N}
- Skills: {N}
- Agents: {N}
- Rules: {N}
- Active Tasks: {N}
```

### Interview Stage 1: InitiateInterview

**Output**:
```
## Building Your Task Plan

I'll help you create structured tasks for your .claude/ system changes.

**Process** (5-10 minutes):
1. Understand what you want to accomplish
2. Break down into discrete tasks
3. Review and confirm task list
4. Create tasks in TODO.md

**What You'll Get**:
- Task entries in TODO.md and state.json
- Clear descriptions and priorities
- Dependencies mapped between tasks
- Ready for /research -> /plan -> /implement cycle

Let's begin!
```

**Checkpoint**: User understands process

### Interview Stage 2: GatherDomainInfo

**Question 1** (via AskUserQuestion):
```json
{
  "question": "What do you want to accomplish with this change?",
  "header": "Purpose",
  "options": [
    {"label": "Add a new command", "description": "Create a new /command for users"},
    {"label": "Add a new skill or agent", "description": "Create execution components"},
    {"label": "Fix or enhance existing component", "description": "Modify existing commands/skills/agents"},
    {"label": "Create documentation or rules", "description": "Add guides, rules, or context files"},
    {"label": "Something else", "description": "Let me explain..."}
  ]
}
```

**Capture**: purpose, change_type

**Question 2** (via AskUserQuestion):
```json
{
  "question": "What part of the .claude/ system is affected?",
  "header": "Scope"
}
```

**Capture**: affected_components, scope

**Checkpoint**: Domain and purpose clearly identified

**Context Loading Trigger**:
- If user selects "Add a new command" -> Load `creating-commands.md`
- If user selects "Add a new skill or agent" -> Load `creating-skills.md` AND `creating-agents.md`
- If user selects "Fix or enhance existing" -> Load relevant existing component file

### Interview Stage 2.5: DetectDomainType

**Classification Logic**:
- Keywords: "command", "skill", "agent", "meta", ".claude/" -> task_type = "meta"
- Otherwise -> task_type = "general"

**Note**: the literal `.claude/` string stays in this *keyword* list intentionally — a user typing
`.claude/` still signals a meta task. This is independent of `file_scope`/`affected_area`, which
Component 4a and Stage 3.5 always populate with `agent-system/extensions/core/**` source-store
paths, never `.claude/**`. Do not "fix" this keyword into `agent-system/extensions/core/` — the
keyword and the produced file_scope are deliberately different strings serving different purposes.

### Interview Stage 3: IdentifyUseCases

**Question 3** (via AskUserQuestion):
```json
{
  "question": "Can this be broken into smaller, independent tasks?",
  "header": "Task Breakdown",
  "options": [
    {"label": "Yes, there are multiple steps", "description": "3+ distinct tasks needed"},
    {"label": "No, it's a single focused change", "description": "1-2 tasks at most"},
    {"label": "Help me break it down", "description": "I'm not sure how to divide it"}
  ]
}
```

**Question 4** (if breakdown needed):
- Ask user to list discrete tasks
- Capture: task_list[]

**Question 5** (if multiple tasks, via AskUserQuestion):
```json
{
  "question": "Do any of these tasks depend on others? (A task can't start until its dependencies complete)",
  "header": "Task Dependencies",
  "options": [
    {"label": "No dependencies", "description": "All tasks can start independently"},
    {"label": "Linear chain", "description": "Each task depends on the previous one (1 -> 2 -> 3)"},
    {"label": "Custom", "description": "I'll specify which tasks depend on which"}
  ],
  "context": "Example: 'Task {M} depends on Task {N}' means Task {N} must complete before Task {M} can start."
}
```

**Question 5 follow-up** (if "Custom" selected):
```json
{
  "question": "For each dependent task, list what it depends on:",
  "header": "Specify Dependencies",
  "format": "Task {N}: depends on Task {M}, Task {P}",
  "examples": [
    "Task {M}: depends on Task {N}",
    "Task {P}: depends on Task {N}, Task {M}"
  ]
}
```

**Capture**: dependency_map{task_idx: [dep_idx, ...]}
- "No dependencies": dependency_map = {}
- "Linear chain": dependency_map = {2: [1], 3: [2], 4: [3], ...}
- "Custom": dependency_map from user input (1-based indices matching task_list order)

**Dependency Validation** (immediate, before proceeding):

1. **Self-Reference Check**: Task cannot depend on itself
   ```
   for task_idx, deps in dependency_map:
     if task_idx in deps:
       ERROR: "Task {task_idx} cannot depend on itself"
   ```

2. **Valid Index Check**: All referenced tasks must exist
   ```
   for task_idx, deps in dependency_map:
     for dep in deps:
       if dep < 1 or dep > len(task_list):
         ERROR: "Task {dep} does not exist in task list"
   ```

3. **Circular Dependency Check**: No cycles allowed
   ```
   # Build dependency graph and detect cycles via DFS
   visited = set()
   in_progress = set()

   function has_cycle(node):
     if node in in_progress: return True  # Cycle detected
     if node in visited: return False
     in_progress.add(node)
     for dep in dependency_map.get(node, []):
       if has_cycle(dep): return True
     in_progress.remove(node)
     visited.add(node)
     return False

   for task_idx in range(1, len(task_list) + 1):
     if has_cycle(task_idx):
       ERROR: "Circular dependency detected involving Task {task_idx}"
   ```

**On Validation Failure**: Present error message via AskUserQuestion and return to dependency input.

**Question 5b** (optional, via AskUserQuestion):
```json
{
  "question": "Should any tasks depend on existing tasks in your TODO?",
  "header": "External Dependencies",
  "options": [
    {"label": "No", "description": "Only dependencies between new tasks"},
    {"label": "Yes", "description": "I'll specify existing task numbers"}
  ]
}
```

**Question 5b follow-up** (if "Yes" selected):
```json
{
  "question": "For each task needing external dependencies, list existing task numbers:",
  "header": "Specify External Dependencies",
  "format": "Task {N}: depends on #35, #36",
  "examples": [
    "Task {N}: depends on #{X}",
    "Task {P}: depends on #{X}, #{Y}"
  ]
}
```

**Capture**: external_dependencies{task_idx: [existing_task_num, ...]}

**External Dependency Validation**:
```
# Validate against state.json
for task_idx, ext_deps in external_dependencies:
  for task_num in ext_deps:
    exists = jq --arg num "$task_num" '.active_projects[] | select(.project_number == ($num | tonumber))' "${TARGET_ROOT}/specs/state.json"
    if not exists:
      WARNING: "Task #{task_num} not found in active projects (may be archived)"
```

**Note**: External dependency warnings are non-blocking. Validation occurs at Stage 6 (CreateTasks) with full state.json access.

**Context Loading Trigger**:
- If "Help me break it down" selected -> Load `component-selection.md` decision tree
- If discussing template-based components -> Load relevant template file

**Stage 3 Capture Summary**:
- `task_list[]`: Array of task titles/descriptions
- `dependency_map{}`: Map of task index -> [dependency indices] (internal)
- `external_dependencies{}`: Map of task index -> [existing task numbers] (external)

**File Footprint Capture and Overlap Detection (Component 4a)**: Before finalizing
`dependency_map`, capture and apply footprint overlap:

1. **Populate `file_scope` per task** in `task_list[]`:
   - If the user's Stage 3 breakdown names specific files or directories for a task, use those
     paths directly.
   - Otherwise, infer `file_scope` via a keyword-to-directory heuristic over the task's
     title/description: match domain keywords (e.g. "skill", "agent", "command", "rule",
     "context pattern") against their corresponding source-store subdirectories under
     `agent-system/extensions/core/` (`skills/`, `agents/`, `commands/`, `rules/`,
     `context/patterns/`, etc.) — **never** `.claude/`, which is a disposable deploy tree — and any
     explicit file paths already mentioned in the interview transcript. Bias toward the broader
     directory prefix when uncertain — over-declaring only costs parallelism, never correctness.
     **Known limitation**: `agent-system/extensions/core/` is the documented default; the heuristic
     has no reliable signal to distinguish core scope from an extension's own source directory
     (e.g. `agent-system/extensions/email/...`) without parsing extension manifests, so
     extension-scoped tasks require human correction rather than a guess.
2. **Run the shared overlap algorithm** (`.claude/context/patterns/file-footprint-overlap.md`,
   referenced by path — do not restate the rule) pairwise across `task_list[]`'s `file_scope`
   entries.
3. **Auto-add a serializing dependency** into `dependency_map` for every overlapping pair with no
   existing edge (from the Question 5/5b interview above or a prior 4a pass): the
   later/lower-priority task index depends on the other.
4. **Never silent**: every edge added by this step must be visibly annotated
   "(auto: file overlap)" in the Stage 5 (ReviewAndConfirm) task summary table so the user can
   override it by selecting "Revise".

This runs automatically (no AskUserQuestion gate) and re-validates the augmented
`dependency_map` against the same self-reference/cycle checks used above.

### Interview Stage 3.5: AnalyzeConsolidation (Task Consolidation)

**Skip Condition**: Execute ONLY when:
- User provided task_list with 2+ items (single task needs no consolidation)
- At least 2 items share topic indicators (otherwise no groupings to suggest)

**Purpose**: Proactively analyze user-provided task breakdown for opportunities to consolidate related items into fewer, more coherent tasks. This follows the "minimize tasks" principle - fewer, well-scoped tasks are better than many fragmented ones.

**3.5.1: Extract Topic Indicators**

For each task in task_list, extract:
- **Shared-Target Indicator**: the anticipated narrow `file_scope` path(s) the task would declare,
  and any named acceptance gate or check it resolves (e.g. a specific validator script, a named
  CI gate). See Component 0 (Task-Count Reasoning) in
  `.claude/docs/reference/standards/multi-task-creation-standard.md` for the full rule and its
  narrowness exclusion (a directory root or broad, widely-edited infrastructure file does not
  count).
- **Key Terms**: Significant words (nouns, verbs) from title/description, ignoring stop words (a, the, in, on, for, to, and, or)
- **Component Type**: Identify component (command, skill, agent, rule, context, documentation)
- **Affected Area**: Parse for directory mentions and map to source-store paths (agent-system/extensions/core/commands/, agent-system/extensions/core/skills/, agent-system/extensions/core/agents/, etc.) — never the `.claude/` deploy tree; see the Known limitation note under Component 4a above (defaults to `core`, extension-scoped tasks need human correction)
- **Action Type**: Categorize by action (create, modify, fix, document, refactor, test)

**Example Extraction**:
```
Task: "Create a new /export command for documentation"
  -> key_terms: ["export", "command", "documentation"]
  -> component_type: "command"
  -> affected_area: "agent-system/extensions/core/commands/"
  -> action_type: "create"

Task: "Add export skill to handle PDF generation"
  -> key_terms: ["export", "skill", "PDF", "generation"]
  -> component_type: "skill"
  -> affected_area: "agent-system/extensions/core/skills/"
  -> action_type: "create"
```

**3.5.2: Cluster Tasks by Shared Indicators**

Apply clustering algorithm (matches /fix-it pattern). The shared-target/shared-gate branch below
is the **primary** match criterion — it runs first because it is the sharper, structural signal
Component 0 names (shared narrow `file_scope` entry or a single named acceptance gate), ahead of
the fuzzy `component_type`/`affected_area` and key-term branches, which cannot see it:

```python
groups = []

for task in task_list:
  matched = False

  # Primary match: shares a narrow file_scope entry or the same named acceptance gate
  # (Component 0, multi-task-creation-standard.md). Excludes directory-root or broad
  # widely-edited infrastructure files -- see the narrowness qualifier there.
  for group in groups:
    if shares_narrow_file_target(task, group) or shares_acceptance_gate(task, group):
      group.items.append(task)
      group.key_terms = union(group.key_terms, task.key_terms)
      matched = True
      break

  # Secondary match: same component_type AND same affected_area
  if not matched:
    for group in groups:
      if task.component_type == group.component_type and task.affected_area == group.affected_area:
        group.items.append(task)
        group.key_terms = union(group.key_terms, task.key_terms)
        matched = True
        break

  # Tertiary match: 2+ shared key_terms
  if not matched:
    for group in groups:
      shared = intersection(task.key_terms, group.key_terms)
      if len(shared) >= 2:
        group.items.append(task)
        group.key_terms = union(group.key_terms, task.key_terms)
        matched = True
        break

  # No match: create new group
  if not matched:
    groups.append(Group(items=[task], key_terms=task.key_terms,
                        component_type=task.component_type,
                        affected_area=task.affected_area))
```

**3.5.3: Generate Topic Labels**

For each group with 2+ items, generate label from:
- Most common key terms (up to 3)
- Component type (e.g., "Command Changes", "Skill Updates")
- Example: "Export Functionality (command + skill)" for two export-related tasks

**3.5.4: Check Skip Condition**

If no groups have 2+ items (all tasks are independent):
- Skip to Stage 4 (no consolidation benefit)
- Set: `topic_consolidation_skipped = true`

**3.5.5: Present Topic Consolidation Picker**

**Question** (via AskUserQuestion):
```json
{
  "question": "I found related tasks that could be consolidated. How should they be grouped?",
  "header": "Task Consolidation",
  "multiSelect": false,
  "options": [
    {
      "label": "Accept suggested groups",
      "description": "Creates {N} consolidated tasks: {group_summaries}"
    },
    {
      "label": "Keep as separate tasks",
      "description": "Creates {M} individual tasks (as you provided)"
    },
    {
      "label": "Customize groupings",
      "description": "I'll specify which items to combine"
    }
  ]
}
```

**Where**:
- `{N}` = Number of groups after consolidation
- `{M}` = Original number of individual tasks
- `{group_summaries}` = Brief list like "Export (2 items), Testing (2 items)"

**3.5.6: Handle User Response**

**If "Accept suggested groups"**:
- Replace task_list with consolidated groups
- Each group becomes one task with combined description
- Apply effort scaling: `base_effort + (30 min * (item_count - 1))`

**If "Keep as separate tasks"**:
- Proceed with original task_list unchanged

**If "Customize groupings"**:
- Present Tier 2 multiSelect picker:
```json
{
  "question": "Select items to combine into a single task:",
  "header": "Custom Grouping",
  "multiSelect": true,
  "options": [
    {"label": "{task_1_title}", "description": "Item 1"},
    {"label": "{task_2_title}", "description": "Item 2"},
    ...
  ]
}
```
- Selected items become one consolidated task
- Remaining items stay as individual tasks
- Repeat until user confirms groupings are complete

**Effort Scaling Formula** (for consolidated tasks):
```
base_effort = original task effort (or 1 hour default)
scaled_effort = base_effort + (30 min * (item_count - 1))

Examples:
  1 item  -> 1 hour
  2 items -> 1.5 hours
  3 items -> 2 hours
  4 items -> 2.5 hours
```

**Capture**: Updated task_list (may be consolidated), consolidation_mode

---

### Interview Stage 4: AssessComplexity

**Question 6** (via AskUserQuestion):
```json
{
  "question": "For each task, estimate the effort:",
  "header": "Effort Estimates"
}
```

Options per task:
- Small: < 1 hour
- Medium: 1-3 hours
- Large: 3-6 hours
- Very Large: > 6 hours (consider splitting)

### Interview Stage 4.5: AssignTopic (Topic Assignment)

**Purpose**: Assign a topic to all tasks in this batch for Task Order grouping in TODO.md.

Follow @.claude/context/patterns/topic-assignment-pattern.md (Mode A: Interactive, batch variant).
Note: question wording is plural — "Assign a topic to these tasks?". Topic assignment is
mandatory: there is no Skip option, so this stage always produces a non-empty topic.

**Capture**: `batch_topic` (non-empty string by construction — Mode A has no Skip option) —
used in Stage 5 confirmation table and Stage 6 state.json entry.

---

### Interview Stage 5: ReviewAndConfirm (CRITICAL)

**MANDATORY**: User MUST confirm before any task creation.

**Present summary**:
```
## Task Summary

**Domain**: {domain}
**Purpose**: {purpose}
**Scope**: {affected_components}

**Tasks to Create** ({N} total):

| # | Title | Language | Topic | Effort | Dependencies |
|---|-------|----------|-------|--------|--------------|
| {N} | {title} | {lang} | {topic} | {hrs} | None |
| {N} | {title} | {lang} | {topic} | {hrs} | Task {M}, #{ext_task} |

**Dependencies Legend**:
- "Task {M}" = internal dependency on another new task in this batch
- "#{ext_task}" = external dependency on existing task in TODO
- "Task {M} (auto: file overlap)" = dependency auto-added by Component 4a (Stage 3 File Footprint
  Capture and Overlap Detection) because the two tasks' `file_scope` entries overlap; never
  silent, can be overridden via "Revise"
- Topic assigned via Stage 4.5 picker; applies to all tasks in this batch. User can revise by selecting "Revise".

**Total Estimated Effort**: {sum} hours
```

**Use AskUserQuestion**:
```json
{
  "question": "Proceed with creating these tasks?",
  "header": "Confirm",
  "options": [
    {"label": "Yes, create tasks", "description": "Create {N} tasks in TODO.md and state.json"},
    {"label": "Revise", "description": "Go back and adjust the task breakdown"},
    {"label": "Cancel", "description": "Exit without creating any tasks"}
  ]
}
```

**If user selects "Cancel"**: Return completed status with cancelled flag.
**If user selects "Revise"**: Go back to Stage 3.
**If user selects "Yes"**: Proceed to Stage 6 (CreateTasks).


---

## Prompt Mode: Clarification and Confirmation

When mode is "prompt", run this analysis-and-clarification workflow (Stage 3B Steps 1-5 of the
original agent) in the skill's own execution, the same way the interactive-mode stages above run
here rather than in a dispatched subagent. Only the final task-creation work (Interview Stage 6,
"same as Interview Stage 6") is delegated to `meta-builder-agent`, carrying the resolved
breakdown as the already-collected answer.

### Step 1: Parse Prompt for Keywords

Identify:
- Language indicators: "command", "skill", "latex", etc.
- Change type: "fix", "add", "refactor", "document", "create"
- Scope: component names, file paths, feature areas

### Step 2: Check for Related Tasks

Search state.json for related active tasks:
```bash
jq '.active_projects[] | select(.project_name | contains("{keyword}"))' "${TARGET_ROOT}/specs/state.json"
```

### Step 3: Propose Task Breakdown

Based on analysis, propose:
- Single task if scope is narrow
- Multiple tasks if scope is broad

### Step 4: Clarify if Needed

Use AskUserQuestion **with `options` array** when:
- Prompt is ambiguous (multiple interpretations) - present interpretations as selectable options
- Scope is unclear - present scope choices as selectable options
- Dependencies are uncertain - present dependency patterns as selectable options

**NEVER** present choices as plain text (A/B/C or numbered lists). Always use AskUserQuestion with `options` for interactive selection.

Example for ambiguous prompt:
```json
{
  "question": "How should I interpret this request?",
  "header": "Clarify Intent",
  "options": [
    {"label": "Interpretation A", "description": "..."},
    {"label": "Interpretation B", "description": "..."}
  ]
}
```

### Step 5: Confirm

Present summary and get confirmation (same as Interview Stage 5, using AskUserQuestion with
`options`). Task creation itself ("same as Interview Stage 6") is the dispatched agent's work,
carried out against this confirmed breakdown.
