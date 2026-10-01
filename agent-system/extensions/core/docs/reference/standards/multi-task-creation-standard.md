# Multi-Task Creation Standard

This document defines the standard patterns for commands, skills, and agents that create multiple tasks in a single operation. The `/meta` command and `meta-builder-agent` serve as the reference implementation.

## Overview

Multi-task creation involves discovering potential work items, presenting them to users for selection, organizing them into coherent tasks, establishing dependencies, and inserting them into state.json/TODO.md in the correct order.

## Task Minimization Principle

**Fewer, well-scoped tasks are better than many fragmented ones.**

Multi-task creators should proactively analyze user-provided items and suggest consolidation opportunities. This principle applies because:

1. **Reduced Context Switching**: Each task requires research, planning, and implementation phases. Consolidating related work reduces overhead.
2. **Better Coherence**: Related changes implemented together are more likely to be consistent and well-integrated.
3. **Clearer Progress**: Fewer tasks make TODO.md more navigable and progress more visible.
4. **Dependency Simplification**: Consolidated tasks have simpler dependency graphs.

**Implementation**: Commands should implement automatic topic clustering (like `/meta`'s Stage 3.5 and `/fix-it`'s topic grouping) to identify related items and offer consolidation options before task creation.

**User Control**: Consolidation should always be presented as a suggestion with three options:
- Accept suggested groups (recommended for related items)
- Keep as separate tasks (user preference)
- Customize groupings (fine-grained control)

This principle is now given a named, mechanical test — see Component 0 below. Component 0 is
the test; this section is the motivation for having one.

## Core Components

Multi-task creators implement these 8 components, plus Component 0 which runs upstream of all of
them. Components marked **Required** must be implemented; **Optional** components enhance the
user experience but may be omitted based on context.

### 0. Task-Count Reasoning (Required)

Before any discovered item (Component 1) is turned into a task entry, decide how MANY tasks the
set of items should become. This runs upstream of Component 3 (Topic Grouping) and Component 4a
(File Footprint Overlap): Component 3's fuzzy key-term/`affected_area` clustering and Component
4a's after-the-fact overlap-to-dependency-edge mechanism both operate on a split that has already
been decided, and neither asks whether the split should have happened at all. Component 0 asks
that question first; Components 3 and 4a are unchanged and still run afterward on whatever
separate tasks survive this test.

**The default: consolidate unless a named divide reason applies.** Findings, observations, or
discovered items default to ONE task. Only a closed, enumerated reason overrides that default.

**Legitimate reasons to divide** (closed list):
- **(a) Disjoint file scope**: the parts' anticipated `file_scope` entries genuinely do not
  overlap, under the rule in `.claude/context/patterns/file-footprint-overlap.md` (see that file
  for the overlap definition; it is not restated here).
- **(b) Different task_type or owning domain**: the parts belong to different `task_type` values
  or different extensions/owning domains, and so would route to different research/plan/
  implementation agents.
- **(c) Real dependency ordering**: one part genuinely cannot be verified until the other part
  has landed — a true sequencing constraint, not merely a shared topic.
- **(d) Size exceeding one agent dispatch**: the combined work will not fit one agent dispatch —
  see the phase-sizing bound (H8) in `.claude/merge-sources/claudemd.md`'s Hard Mode section
  (~100-500 lines of output per phase) rather than a line count restated here.

**Reasons NOT to divide** (chiefly): findings that share an edit target (the same file or files)
or share a single acceptance gate belong in ONE task. This is not merely a style preference — the
split is actively self-defeating. Two findings that edit the same file and are drafted as two
separate tasks will each declare overlapping `file_scope`; Component 4a's own in-batch overlap
check then adds a serializing dependency edge between them, so the two "tasks" were never
independently dispatchable in the first place. Consolidating them is the only way the resulting
tasks are actually run as the batch-dispatch system expects.

**Narrowness qualifier**: the shared-edit-target signal means a shared *narrow* `file_scope`
entry or one named acceptance gate/check — not a broad, widely-edited infrastructure file or a
directory-root scope. `.claude/scripts/validate-state.sh` Check 8 (WARN-only) already detects
coarse directory-root `file_scope` declarations; a file that trips Check 8 does not, by itself,
trigger consolidation under this component.

**Bidirectional**: the same closed divide-reason list above governs the division direction too.
An over-large or multi-domain task is still split when (b), (c), or (d) genuinely applies — this
component is not a one-way bias toward fewer tasks. Reasoned division under a named reason is
exactly as correct as reasoned consolidation under the default.

**Relationship to `batch-orchestration-guardrails.md`**: this component governs how many tasks
are CREATED from a set of findings. `.claude/context/patterns/batch-orchestration-guardrails.md`'s
"Batching Is the Default" section governs which *already-created* tasks are RUN together in one
`/orchestrate` invocation. Neither subsumes the other — one is a creation-time decision, the
other a dispatch-time decision — but they are complementary: tasks correctly consolidated here
are also the tasks the guardrails document expects to see batched at dispatch time.

**Motivating example**: a batch postflight once surfaced two findings that both edited the same
config file,
`agent-system/extensions/core/context/config/orchestrator-context-budget.json`, and both resolved
the same `verify-deploy.sh` gate. They were drafted as two separate tasks. As separate tasks they
would each have declared `orchestrator-context-budget.json` in `file_scope`, and Component 4a's
own in-batch `file_scope_collision` check would then have deferred one task behind the other — so
the split was not merely cosmetic, it was self-defeating: the two tasks could never have been
dispatched independently. Under this component's default, a single shared edit target and a
single shared acceptance gate are exactly the signal that calls for one task, not two.

### 1. Item Discovery (Required)

Identify items that could become tasks from various sources.

**Sources by Command**:
| Command | Discovery Source |
|---------|------------------|
| `/fix-it` | FIX:, NOTE:, TODO:, QUESTION: tags in source files |
| `/meta` | User interview responses |
| `/review` | Code analysis findings + roadmap items |
| `/errors` | Error patterns from errors.json |
| `/task --review` | Incomplete phases from plan files |

**Implementation**:
```bash
# Example: /fix-it tag discovery
grep -rn --include="*.lua" "-- FIX:" $paths 2>/dev/null || true
grep -rn --include="*.lua" "-- NOTE:" $paths 2>/dev/null || true
grep -rn --include="*.lua" "-- TODO:" $paths 2>/dev/null || true
```

### 2. Interactive Selection (Required)

Use AskUserQuestion with multiSelect for item selection.

**Standard Pattern**:
```json
{
  "question": "Which items should be created as tasks?",
  "header": "Task Selection",
  "multiSelect": true,
  "options": [
    {"label": "{item_title}", "description": "{item_context}"}
  ]
}
```

**Requirements**:
- Add "Select all" option when >20 items available
- Empty selection = graceful exit, no tasks created
- Present items in priority order (highest first)

**Example from /fix-it**:
```json
{
  "question": "Select TODO items to create as tasks:",
  "header": "TODO Selection",
  "multiSelect": true,
  "options": [
    {"label": "Add API configuration", "description": "src/config/api.py:67"},
    {"label": "Implement helper function", "description": "src/utils/helpers.py:23"}
  ]
}
```

### 3. Topic Grouping (Optional but Recommended)

Cluster related items into coherent task groups when 2+ items are selected. This implements the **Task Minimization Principle** - proactively suggesting consolidation opportunities rather than passively accepting user-provided breakdowns.

**Automatic Task Consolidation** (implemented by `/meta` Stage 3.5 (AnalyzeConsolidation) and `/fix-it`):
- Extract topic indicators: key terms, component type, affected area, action type
- Cluster by shared indicators (2+ key terms OR same component_type AND affected_area)
- Present consolidation options before task creation

**Clustering Algorithm**:
```
groups = []

for each issue in all_issues:
  matched = false

  # Primary match: same file_section AND same issue_type
  for each group in groups:
    if issue.file_section == group.file_section AND issue.issue_type == group.issue_type:
      add issue to group.items
      matched = true
      break

  # Secondary match: 2+ shared key_terms AND same priority
  if not matched:
    for each group in groups:
      shared_terms = intersection(issue.key_terms, group.key_terms)
      if len(shared_terms) >= 2 AND issue.priority == group.priority:
        add issue to group.items
        matched = true
        break

  # No match: create new group
  if not matched:
    create new group with issue
```

**Post-Processing**:
- Combine small groups (<2 items) into "Other" group
- Cap total groups at 10 (merge lowest-priority if exceeded)
- Generate labels from common terms

**Grouping Confirmation Pattern**:
```json
{
  "question": "How should items be grouped into tasks?",
  "header": "Task Grouping",
  "multiSelect": false,
  "options": [
    {"label": "Accept suggested groups", "description": "Creates {N} grouped tasks"},
    {"label": "Keep as separate tasks", "description": "Creates {M} individual tasks"},
    {"label": "Create single combined task", "description": "Creates 1 task containing all items"}
  ]
}
```

**Effort Scaling Formula**:
```
base_effort = 1 hour
scaled_effort = base_effort + (30 min * (item_count - 1))

Examples:
  1 item  -> 1 hour
  2 items -> 1.5 hours
  3 items -> 2 hours
```

### 4. Dependency Declaration (Optional but Recommended)

Ask users about dependencies between tasks when creating multiple tasks.

**Interview Pattern** (from /meta):
```json
{
  "question": "Do any tasks depend on others?",
  "header": "Task Dependencies",
  "options": [
    {"label": "No dependencies", "description": "All tasks can start independently"},
    {"label": "Linear chain", "description": "Each task depends on the previous one"},
    {"label": "Custom", "description": "I'll specify which tasks depend on which"}
  ]
}
```

**Custom Dependency Input**:
```json
{
  "question": "For each dependent task, list dependencies:",
  "header": "Specify Dependencies",
  "format": "Task {N}: depends on Task {M}, Task {P}",
  "examples": ["Task {N}: depends on Task {M}", "Task {P}: depends on Task {N}, Task {M}"]
}
```

**External Dependencies** (to existing tasks):
```json
{
  "question": "Should any tasks depend on existing tasks?",
  "header": "External Dependencies",
  "format": "Task {N}: depends on #35, #36"
}
```

**Validation Requirements**:
1. **Self-reference check**: Task cannot depend on itself
2. **Valid index check**: All referenced tasks must exist
3. **Circular dependency check**: No cycles allowed (detect via DFS)
4. **External validation**: Verify external task numbers exist in state.json

### 4a. File Footprint Capture and Overlap Detection (Automatic)

Runs automatically after Component 3 (Topic Grouping) and before the user is asked about
dependencies in Component 4 — mirroring `/meta` Stage 3.5's proactive-before-asking placement.
This sub-step never depends on user input; it derives an initial set of serializing dependency
edges from file footprint alone, which Component 4's interview can then extend or the user can
override.

**Steps**:
1. **Populate `file_scope` per proposed task**: Using whatever structured signal the calling
   command already has (tag `file:line` locations for `/fix-it`, keyword-to-directory inference
   for `meta-builder-agent`, blocker/codebase research paths for `skill-spawn`), assign each
   proposed task an anticipated `file_scope` array of repo-relative paths. Declare the narrowest
   currently-known files — the actual paths the task is expected to read or write, not a
   directory prefix chosen as a hedge. A directory root or extension-wide prefix is warranted
   only when the task's real footprint is genuinely expected to span most of that directory, never
   as a stand-in for a footprint that simply isn't known yet before research. The
   no-false-negatives constraint from the overlap check below still governs: under-declaring
   remains strictly worse than over-declaring, because a missed collision serializes silently
   while a false one only costs an orchestration wave — a narrowing must never drop a path the
   task actually writes. See "Unknown-Footprint Convention" below for what to do when the real
   footprint genuinely cannot be named yet.
2. **Run the shared overlap algorithm pairwise across the batch**: apply the directory-prefix
   overlap check defined once in `.claude/context/patterns/file-footprint-overlap.md` (reference
   by path — do not restate the rule) to every unordered pair of proposed tasks in the current
   batch.
3. **Auto-add a serializing dependency for every overlapping pair with no existing edge**: when
   two proposed tasks' `file_scope` arrays overlap and neither already depends on the other
   (from Component 4's interview or a prior 4a pass), add a dependency edge from the
   later/lower-priority task onto the other, so they can never land in the same `/orchestrate`
   wave.
4. **Never silent**: every auto-added edge from this sub-step must be visibly annotated in the
   Component 7 confirmation summary (see below) so the user can override it via the existing
   Custom/Revise path.

**Unknown-Footprint Convention**: when a proposed task's real file footprint genuinely cannot be
named at creation time — the work depends on what research discovers — declaring a directory root
as a placeholder is not the answer; it manufactures false collisions against every other task that
touches anything beneath that root (see `validate-state.sh` Check 8, WARN-only, which detects
exactly this pattern). Instead:
(a) At creation time, declare only the narrowest currently-known files in `file_scope`, and never
    a directory root as a stand-in for "not known yet".
(b) At research postflight, the research phase may propose additional concrete paths it
    discovered via `proposed_file_scope` in `.return-meta.json`; these are union-merged into the
    task's `file_scope` before the plan phase begins (see
    `context/formats/return-metadata-file.md` for the field contract and
    `scripts/update-task-status.sh`'s `--file-scope-add` flag for the consumer mechanism).
(c) The merge is additive only, never subtractive — it can only add paths research discovered, and
    can never remove a path declared at creation time. Pruning an over-broad declaration is a
    human or plan-phase decision, not something this mechanism does automatically.

Check 8 in `validate-state.sh` is the WARN-only detector for violations of this guidance — a
coarse, directory-root `file_scope` entry that collides with other tasks' declared scopes. It
remains advisory, not a blocking gate.

Components 5 (Kahn ordering) and 6 (Visualization) require no change — they consume whatever
`dependency_map` they are given, now augmented with 4a's auto-added edges, automatically.

### 5. Task Ordering (Required when dependencies exist)

Apply topological sort (Kahn's algorithm) to ensure foundational tasks receive lower numbers.

**Kahn's Algorithm Implementation**:
```python
n = len(task_list)

# Build reverse dependency graph
dependents = {i: [] for i in range(1, n + 1)}
for task_idx, deps in dependency_map.items():
    for dep_idx in deps:
        dependents[dep_idx].append(task_idx)

# Calculate in-degree for each task
in_degree = {idx: len(dependency_map.get(idx, [])) for idx in range(1, n + 1)}

# Initialize queue with no-dependency tasks
queue = [idx for idx in range(1, n + 1) if in_degree[idx] == 0]

# Process in BFS order
sorted_indices = []
while queue:
    current = queue.pop(0)
    sorted_indices.append(current)
    for dependent in dependents[current]:
        in_degree[dependent] -= 1
        if in_degree[dependent] == 0:
            queue.append(dependent)
```

**Why This Matters**: Foundational tasks get lower numbers and appear first in TODO.md, making the execution order intuitive.

### 6. Visualization (Optional)

Display dependency relationships for complex task sets.

**Linear Chain Format** (simple dependencies):
```
  [37] Add topological sorting
    |
    v
  [38] Update TODO insertion
    |
    v
  [39] Enhance visualization
```

**Layered DAG Format** (complex dependencies):
```
       [37] Core API
         |
    +----+----+
    |         |
    v         v
[38] Parser  [39] Validator
    |         |
    +----+----+
         |
         v
   [40] Integration
```

**Complexity Detection**:
- Linear chain: Each task has at most 1 dependency, each task is depended on by at most 1 other
- Complex DAG: Any diamond pattern, parallel branches, or multiple roots/leaves

### 7. User Confirmation (Required)

Always show task summary and require explicit confirmation before creating tasks.

**Summary Table Format**:
```markdown
**Tasks to Create** ({N} total):

| # | Title | Task Type | Effort | Dependencies |
|---|-------|----------|--------|--------------|
| 37 | Add sorting | meta | 2h | None |
| 38 | Update insertion | meta | 1h | Task #{N} |
| 39 | Refactor helper | meta | 1h | Task #{N} (auto: file overlap) |

**Total Estimated Effort**: 4 hours
```

**Auto-Derived Dependency Annotation**: Any dependency edge added automatically by Component 4a
(file footprint overlap) MUST be annotated inline in the Dependencies cell with
`(auto: file overlap)`, distinguishing it from user-declared dependencies (Component 4). This
annotation is never omitted — an auto-added edge is always visible in the confirmation summary
so the user can override it via the Custom/Revise path before tasks are created.

**Confirmation Pattern**:
```json
{
  "question": "Proceed with creating these tasks?",
  "header": "Confirm",
  "options": [
    {"label": "Yes, create tasks", "description": "Create {N} tasks"},
    {"label": "Revise", "description": "Go back and adjust"},
    {"label": "Cancel", "description": "Exit without creating"}
  ]
}
```

**Mandatory**: User MUST explicitly select "Yes, create tasks" before any tasks are created.

**Foreground Requirement**: Confirmation MUST execute in the foreground skill layer (not inside a delegated background agent). `AskUserQuestion` called from background agents (spawned via Task tool) does not reliably surface to users. Skills that delegate to agents for task creation must complete all confirmation steps before spawning the agent. The correct pattern:
1. Skill performs item discovery, proposal, and confirmation via `AskUserQuestion` (foreground)
2. On user confirmation, skill passes `mode=confirmed` + `confirmed_tasks=[...]` to the agent
3. Agent creates tasks without any interactive prompts

Reference implementation: `skill-meta` Stage 2.5 (Pre-Confirmation) + `meta-builder-agent` Stage 3D (Confirmed Task Creation).

### 8. State Updates (Required)

Update state.json and TODO.md atomically with correct dependency information.

**state.json Entry Schema**:
```json
{
  "project_number": 36,
  "project_name": "task_slug",
  "status": "not_started",
  "task_type": "meta",
  "dependencies": [35, 34],
  "created": "2026-02-03T12:00:00Z",
  "last_updated": "2026-02-03T12:00:00Z"
}
```

**TODO.md Entry Format**:
```markdown
### 36. Task Title
- **Effort**: 2 hours
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Dependencies**: Task #{N}, Task #{M}

**Description**: Task description here.

---
```

**Batch Insertion Pattern**:
```python
# Build all entries in sorted order (foundational first)
batch_entries = []
for position, task_idx in enumerate(sorted_indices):
    batch_entries.append(format_entry(task_idx))

# Join and insert entire batch after ## Tasks heading
batch_markdown = "\n\n".join(batch_entries)
insert_after_heading("## Tasks", batch_markdown)
```

**Why Batch Insertion**: Individual prepends reverse the order (last task at top). Batch insertion preserves topological order.

## Implementation Checklist

For any command/skill/agent that creates multiple tasks:

### Required Components
- [ ] **Task-Count Reasoning (0)**: Default to consolidate unless a named divide reason (disjoint
      file_scope, different task_type/domain, real dependency ordering, or size exceeding one
      agent dispatch) applies
- [ ] **Discovery**: Clear criteria for identifying potential tasks
- [ ] **Selection UI**: AskUserQuestion with multiSelect
- [ ] **Confirmation**: Summary table + explicit "Yes, create tasks" selection
- [ ] **State Updates**: Update both state.json and TODO.md atomically

### Optional Components (Recommended for 3+ Tasks)
- [ ] **Grouping**: Semantic clustering when 2+ items selected
- [ ] **File Footprint Overlap (4a)**: Populate `file_scope` and auto-add serializing dependencies on overlap (automatic, not user-interview-gated)
- [ ] **Dependency Interview**: Ask about internal and external dependencies
- [ ] **Validation**: Self-reference, cycle detection, valid indices
- [ ] **Topological Sort**: Kahn's algorithm for task ordering
- [ ] **Batch Insertion**: Build all entries, insert as batch
- [ ] **Visualization**: Linear chain or layered DAG display

### Git Commit
- [ ] Include task count in commit message
- [ ] Example: `learn: create 5 tasks from tags`

## Reference Implementation

The `/meta` command and `meta-builder-agent` implement all 8 components plus enhanced features:

| Component | Implementation Location |
|-----------|-------------------------|
| Discovery | Interview Stage 2-3 (GatherDomainInfo, IdentifyUseCases) |
| Selection | Interview Stage 5 (ReviewAndConfirm with task list) |
| **Task Consolidation** | **Interview Stage 3.5 (AnalyzeConsolidation - automatic clustering)** |
| Grouping | Interview Stage 3.5 (automatic) + Stage 3 (user refinement) |
| Dependencies | Interview Stage 3 Question 5 (dependency interview) |
| Ordering | Interview Stage 6 (Kahn's algorithm) |
| Visualization | Interview Stage 7 (DeliverSummary with graph) |
| Confirmation | Interview Stage 5 (mandatory confirmation) |
| State Updates | Interview Stage 6 (batch insertion with NOT STARTED status) |

**Enhanced Stages** (added for Task Minimization Principle):
- **Stage 3.5 (AnalyzeConsolidation)**: Extracts topic indicators, clusters by shared terms/components, presents consolidation picker

See `.claude/agents/meta-builder-agent.md` for complete implementation details.

## Current Compliance Status

| Command | Task-Count Reasoning (0) | Required | Grouping | Footprint Overlap (4a) | Dependencies | Ordering | Visualization |
|---------|---------------------------|----------|----------|-------------------------|--------------|----------|---------------|
| `/meta` | Yes (primary-match criterion) | Yes | **Automatic** | Yes (meta-builder-agent) | Full DAG | Kahn's | Linear/Layered |
| `/fix-it` | Yes (primary-match criterion) | Yes | Yes | Yes (skill-fix-it) | Internal only | No | No |
| `/review` | No (not yet wired) | Yes | Yes | No | No | No | No |
| `/errors` | Yes (non-interactive) | Partial* | No | No | No | No | No |
| `/task --review` | No (not yet wired) | Yes | No | No | parent_task | No | No |

*`/errors` creates tasks automatically without interactive selection (intentional for error triage workflow).

`/spawn` (single-task-follow-up creator, `spawn-agent` + `skill-spawn`) also implements
Footprint Overlap (4a) even though it is not a multi-task *creation* command in the strict
Component-1-8 sense; see `.claude/agents/spawn-agent.md` and `.claude/skills/skill-spawn/SKILL.md`.

`/task` Create Task Mode and Expand Mode (single/few-task creators, not strict Component-1-8
multi-task creators) also implement Task-Count Reasoning (0): **Yes** for both, applied at the
point task count is decided (Create Task Mode Step 2.5; Expand Mode Steps 2-3). See
`.claude/commands/task.md`.

**Enhanced `/meta` Features**:
- **Automatic Task Consolidation** (Stage 3.5): Proactively analyzes user-provided task breakdown and suggests consolidation opportunities

## Gaps and Future Enhancements

### /review
- **Gap**: No dependency support between created tasks
- **Enhancement**: Add dependency interview for issue groups that have natural ordering

### /errors
- **Gap**: No interactive selection, no dependency support
- **Rationale**: Automatic mode is intentional for quick error triage; `/errors` now applies the
  Task-Count Reasoning (0) default-to-consolidate rule non-interactively before drafting task
  entries (see Component 0 above), so the remaining gap is selection/dependency UI, not
  consolidation
- **Enhancement**: Add `--interactive` flag for manual selection mode

### /fix-it
- **Gap**: No external dependency support (only internal learn-it -> fix-it)
- **Enhancement**: Allow TODO tasks to depend on existing tasks

### /task --review
- **Gap**: No topological sorting for follow-up tasks
- **Enhancement**: Order follow-up tasks by phase number (already implicit)

## Related Documentation

- `.claude/rules/state-management.md` - Dependencies field schema
- `.claude/agents/meta-builder-agent.md` - Reference implementation
- `.claude/commands/fix-it.md` - Topic grouping example
- `.claude/commands/review.md` - Issue grouping example
- `.claude/context/patterns/batch-orchestration-guardrails.md` - "Batching Is the Default":
  governs which already-created tasks are run together, complementary to Component 0's
  how-many-to-create decision
