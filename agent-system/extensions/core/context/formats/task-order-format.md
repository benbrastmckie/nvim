# Task Order Format Standard

**Purpose**: Define the Task Order section format for TODO.md, providing structured task prioritization, dependency visualization, and auto-generation from the state.json dependency graph.

---

## Placement

The `## Task Order` section is placed between the `# TODO` header (and optional YAML frontmatter) and the `## Tasks` section:

```markdown
---
next_project_number: 277
---

# TODO

## Task Order
{task order content}

## Tasks
{individual task entries}
```

---

## Structure Elements

### Section Header

Format: `## Task Order`
Regex: `^## Task Order$`

### Update Timestamp

Format: `*Updated YYYY-MM-DD. Generated from state.json dependency graph.*`
Regex: `^\*Updated (\d{4}-\d{2}-\d{2})\. (.+)\*$`

The changelog summary briefly describes the generation source and any notable context.

Examples:
```markdown
*Updated 2026-05-15. Generated from state.json dependency graph.*
*Updated 2026-05-15. Generated from state.json. Tasks {N}-{N} archived.*
```

### Goal Statement

Format: `**Goal**: {one-line project goal}`
Regex: `^\*\*Goal\*\*: (.+)$`

The goal is a single-line summary of the current project focus. The generation script resolves
this line from a four-tier precedence chain, applied identically whether it is invoked as
`--print` or `--update-todo`:

1. An explicit `--goal TEXT` override, if passed.
2. Otherwise, `state.json`'s `active_goal` field, if it is set to a non-empty string.
3. Otherwise, the existing `**Goal**:` line already present in TODO.md's `## Task Order` section
   (the **preserved-across-regenerations** behavior).
4. Otherwise, the line is omitted entirely.

**Conflict rule**: a non-empty `active_goal` takes precedence over a hand-edited TODO.md Goal
line; an unset, `null`, or empty-string `active_goal` all fall through to the preserve behavior
unchanged. The rationale: `state.json` is the authoritative store and TODO.md a generated render
target, so setting `active_goal` — not hand-editing the rendered line — is the deliberate way to
change the goal. The accepted trade-off is that a stale `active_goal` silently overwrites a
hand edit of the TODO.md line; this self-corrects through the goal-update flow that writes
`active_goal` (or a direct `state-write.sh` call), whereas the reverse precedence would make
that flow silently fail with no recovery path.

Example:
```markdown
**Goal**: Complete LSP integration and extend plugin coverage.
```

### Optional Status Summary

An optional `**Status**:` line may follow the Goal, providing a prose summary of current progress. This line is also preserved across regenerations.

Format: `**Status**: {prose summary}`

### Topic Headings

When tasks have `topic` fields in state.json, the dependency tree is replaced by topic-grouped sections. Each topic uses a level-3 heading inside `## Task Order`:

Format: `### {Topic Name}` (e.g., `### Lsp Integration`, `### Agent System`)
Regex: `^### (.+)$` (within `## Task Order` boundaries)

Topic headings do NOT trigger the section-end boundary detector (which only matches `^## `), so they are safely contained within the Task Order section.

### Topics Column

The wave table includes a 4th column for topic breakdown per wave:

```markdown
| Wave | Tasks | Blocked by | Topics |
|------|-------|------------|--------|
| 1 | 8,18,60 | -- | lsp-integration, plugin-config, agent-system |
| 2 | 20,21,125 | 18,116,122 | lsp-integration, plugin-config |
```

Topics are listed in canonical order from `active_topics` in state.json. When more than 3 topics appear in a wave, the display is truncated to `first, second, third, ...`.

### Cross-Topic Dependency Annotation

When a task's dependency belongs to a different topic section, the dependency entry shows the source topic inline:

```
### Plugin Config
```
125 [NOT STARTED] — Configure telescope with custom mappings
  └─ 116 [PLANNED] — (lsp-integration: Set up lsp-config defaults) (see above)
  └─ 122 [RESEARCHED] — (agent-system: Port task order script) (see above)
```
```

Format: `(topic-name: short description) (see above)` — indicates the task lives in a different topic section and was already rendered there.

Regex: `^(\s*)(└─ )?(\d+) \[([A-Z ]+)\] — \(([a-z-]+): (.+)\) \(see above\)$`

### Topic Taxonomy

Topics are project-specific. There is no global hardcoded taxonomy. Each project defines its own topics by:

1. Adding a `"topic"` string field to individual task entries in `state.json`
2. Optionally adding a top-level `"active_topics"` array to `state.json` to control render order

Topics are stored in `state.json` at two levels:
- **Top-level array**: `"active_topics": ["lsp-integration", "plugin-config", ...]` — canonical order for rendering
- **Per-task field**: `"topic": "lsp-integration"` — optional string on each task entry

If `active_topics` is absent or empty, topics are rendered in encounter order. Tasks without a `topic` field appear in the `### Uncategorized` fallback section at the end.

Topic values should be lowercase kebab-case strings (e.g., `lsp-integration`, `agent-system`, `plugin-config`). The script auto-capitalizes them for display (`### Lsp Integration`, `### Agent System`).

**Note**: Topic assignment is the responsibility of the project's task-creation commands (e.g., `/task`, `/meta`, `/fix-it`). No heuristic is provided in `generate-task-order.sh` itself; heuristics are project-specific and should be implemented in the project's tool integration layer.

---

## Dependency Waves Section

### Wave Table Header

Format: `**Dependency Waves**:`
Regex: `^\*\*Dependency Waves\*\*:$`

### Wave Table

Immediately follows the header. The wave table has four columns:

```markdown
| Wave | Tasks | Blocked by | Topics |
|------|-------|------------|--------|
| 1 | {task_id_list} | -- | {topic_list} |
| 2 | {task_id_list} | {blocking_ids} | {topic_list} |
```

- **Wave**: Wave number (1 = no active dependencies, 2 = depends only on wave 1, etc.)
- **Tasks**: Comma-separated task IDs in this wave
- **Blocked by**: Task IDs that must complete before this wave can start; `--` if none
- **Topics**: Comma-separated topic names in this wave (from `task_topic` map); `--` if no topics assigned; truncated to first 3 + `...` if more than 3

Wave table row regex (4-column): `^\| (\d+) \| ([\d,]+) \| ([\d,\-]+) \| (.+) \|$`

**Note**: The wave table serves as a quick index. The full task-to-topic mapping is in the grouped sections below.

---

## Grouped Topic Sections

When tasks have `topic` fields in state.json, the dependency tree is replaced by per-topic sections. Each section has a `### TopicName` heading and a single fenced code block:

### Grouped Section Header

Format: `**Grouped by Topic** (indented = depends on parent):`
Regex: `^\*\*Grouped by Topic\*\* \(indented = depends on parent\):$`

### Topic Section Structure

Root tasks (wave-1, no active deps) appear at depth 0. Tasks that depend on a root appear indented below it as children. This DFS traversal uses the successor relationship: each node's children are the tasks that depend on it.

````markdown
### Lsp Integration
```
8 [RESEARCHED] — configure_lsp_python
  └─ 18 [BLOCKED] — Wire up diagnostics and code actions for all LSP clients
    └─ 20 [NOT STARTED] — Review LSP handler configuration
```

### Plugin Config
```
112 [RESEARCHED] — survey_telescope_extensions
  └─ 125 [NOT STARTED] — Configure telescope with custom mappings
116 [PLANNED] — Set up lsp-config defaults
  └─ 125 [NOT STARTED] — Configure telescope with custom mappings (see above)
```
````

### Tree Entries

Each entry shows a task ID, status marker, and short description. Tasks appear in DFS order within their topic block. Root entries are tasks with no active dependencies (wave-1 / unblocked tasks). Children are tasks that depend on their parent (successors).

**Entry format**: `{indent}{task_id} [{STATUS}] — {short description}`

- Root entries (no active deps): no indent
- Level 1 successors: `  └─ ` (2 spaces + `└─ `)
- Level 2 successors: `    └─ ` (4 spaces + `└─ `)
- Each additional level: +2 spaces

**Tree entry regex**: `^(\s*)(└─ )?(\d+) \[([A-Z ]+)\] — (.+)$`

**Diamond dependencies**: When a task appears as a successor of multiple parents within the same topic, it uses `(see above)` on subsequent occurrences.

**Cross-topic successors**: When a successor belongs to a different topic section, it shows the source topic inline:
```
  └─ 125 [NOT STARTED] — (plugin-config: Configure telescope with custom mappings) (see above)
```

**Uncategorized fallback**: Tasks without a `topic` field appear in an `### Uncategorized` section at the end. This is the default state before topic assignment is configured.

### Backward Compatibility (Dependency Tree)

The old `**Dependency Tree** (indented = depends on parent):` format is no longer generated by the script, but remains parseable by `update-task-status.sh` Mode A since tree entry format is unchanged. The `generate_dependency_tree()` function is preserved in the script for debugging purposes.

---

## Status Markers

Task Order entries use the same status markers as TODO.md task entries:

| Marker | Meaning |
|--------|---------|
| `[NOT STARTED]` | Task not yet begun |
| `[RESEARCHING]` | Research in progress |
| `[RESEARCHED]` | Research completed |
| `[PLANNING]` | Plan creation in progress |
| `[PLANNED]` | Plan created, ready for implementation |
| `[IMPLEMENTING]` | Implementation in progress |
| `[COMPLETED]` | Task finished |
| `[BLOCKED]` | Cannot proceed (with reason) |
| `[ABANDONED]` | Task dropped |
| `[PARTIAL]` | Partially complete |
| `[EXPANDED]` | Divided into subtasks |

Status marker regex: `\[([A-Z ]+)\]`

---

## Complete Example

````markdown
## Task Order

*Updated 2026-05-15. Generated from state.json dependency graph.*

**Goal**: Complete LSP integration and extend plugin coverage.

**Dependency Waves**:
| Wave | Tasks | Blocked by | Topics |
|------|-------|------------|--------|
| 1 | 8,18,60,64,579,580 | -- | lsp-integration, plugin-config, agent-system |
| 2 | 20,21,125,128 | 18,116,122 | lsp-integration, plugin-config |

**Grouped by Topic** (indented = depends on parent):

### Lsp Integration
```
8 [RESEARCHED] — configure_lsp_python
  └─ 18 [BLOCKED] — Wire up diagnostics and code actions for all LSP clients
    └─ 20 [NOT STARTED] — Review LSP handler configuration
64 [RESEARCHED] — audit_lsp_keymaps
```

### Plugin Config
```
112 [RESEARCHED] — survey_telescope_extensions
  └─ 125 [NOT STARTED] — Configure telescope with custom mappings
116 [PLANNED] — configure_lsp_defaults
  └─ 125 [NOT STARTED] — Configure telescope with custom mappings (see above)
```

### Agent System
```
579 [IMPLEMENTING] — port_task_order_script
  └─ 580 [NOT STARTED] — integrate_task_order_into_commands
```

## Tasks
````

---

## Parsing Patterns Summary

| Element | Pattern |
|---------|---------|
| Section header | `^## Task Order$` |
| Timestamp | `^\*Updated (\d{4}-\d{2}-\d{2})\. (.+)\*$` |
| Goal | `^\*\*Goal\*\*: (.+)$` |
| Wave table header | `^\*\*Dependency Waves\*\*:$` |
| Wave table row (4-col) | `^\| (\d+) \| ([\d,]+) \| ([\d,\-]+) \| (.+) \|$` |
| Grouped section header | `^\*\*Grouped by Topic\*\* \(indented = depends on parent\):$` |
| Topic heading | `^### (.+)$` (within `## Task Order`) |
| Tree fenced block start | `^\`\`\`` |
| Tree entry | `^(\s*)(└─ )?(\d+) \[([A-Z ]+)\] — (.+)$` |
| Cross-topic dep entry | `^(\s*)(└─ )?(\d+) \[([A-Z ]+)\] — \(([a-z-]+): (.+)\) \(see above\)$` |
| Tree indent level | Count of 2-space units before `└─` or task ID |
| Status marker | `\[([A-Z ]+)\]` |

---

## Generation

The `## Task Order` section is auto-generated by `.claude/scripts/generate-task-order.sh`.

### Script Usage

```bash
# Print to stdout (inspection)
.claude/scripts/generate-task-order.sh --print

# Replace Task Order section in TODO.md
.claude/scripts/generate-task-order.sh --update-todo specs/TODO.md specs/state.json

# Replace section with custom goal line
.claude/scripts/generate-task-order.sh --update-todo specs/TODO.md specs/state.json --goal "Custom goal text"
```

`--print` and `--update-todo` resolve the Goal line identically: both run the same
`resolve_goal_text()` chain (see Goal Statement above) and both read the same target TODO.md for
the fallback (preserve-from-existing-line) tier — `--print` resolves it from `specs/TODO.md` via
`PROJECT_ROOT`, `--update-todo` from the `TODO_FILE` argument. The parity between the two modes
is the behavior, not an implementation detail: any caller that regenerates TODO.md through either
mode observes the same precedence.

### Generation Algorithm

1. **Filter**: Extract non-terminal tasks from state.json (exclude `completed`, `abandoned`, `expanded`)
2. **Clean dependencies**: Remove dependencies that point to terminal tasks (treat as satisfied)
3. **Load topics**: Read `task_topic[task_num]` from state.json `topic` field; read `active_topics_order[]` from top-level `active_topics` array
4. **Kahn's algorithm**: Compute wave assignments by iteratively removing zero-in-degree nodes
5. **Union-Find**: Compute connected components for implicit subtree grouping
6. **Resolve Goal text**: Resolve the Goal line via the precedence chain — `--goal` override, then
   non-empty `state.json` `active_goal`, then the existing TODO.md Goal line, then omit
7. **Build wave table**: Group tasks by wave; `Blocked by` = union of active deps; `Topics` = distinct topic names in wave (canonical order, truncated to 3 + `...`)
8. **Build grouped sections**: For each topic in `active_topics_order`, filter tasks, render DFS tree with cross-topic dep annotations; `Uncategorized` fallback for tasks without topic.
   **Append-extras behavior**: a topic present on one or more tasks but absent from
   `active_topics_order` (a curated-list/task desync) is not dropped or folded into
   `Uncategorized` -- it is still rendered as its own section, appended after all curated
   topics in first-encountered-task order. This keeps every task visible even when
   `active_topics` in `state.json` has drifted out of sync with the topics tasks actually
   carry. Each distinct undeclared topic also emits a one-time stderr warning (symmetric to
   the `Uncategorized` warning below) naming the topic and the task that surfaced it, so the
   desync is visible without being treated as fatal.
9. **Replace section**: Replace content between `## Task Order` and next `## ` heading in TODO.md

### Wave Computation

```
in_degree[task] = count of task's active dependencies
wave = 1
queue = tasks where in_degree == 0

while queue not empty:
  assign all queue tasks to current wave
  for each task in queue:
    for each successor (task that depends on current):
      in_degree[successor] -= 1
      if in_degree[successor] == 0: add to next queue
  wave += 1
```

---

## update-task-status.sh Integration

Phase 3 of `update-task-status.sh` updates task status markers in the Task Order tree. It uses a two-mode strategy:

### Mode A: In-Place Status Update (non-terminal transitions)

For status transitions to `RESEARCHING`, `RESEARCHED`, `PLANNING`, `PLANNED`, `IMPLEMENTING`:
- Pattern: `^\s*(└─ )?{task_number} \[` matches tree lines at any indent level
- Action: Replace `[OLD_STATUS]` with `[NEW_STATUS]` on the matched line

### Mode B: Full Regeneration (terminal transitions)

For transitions to `COMPLETED`, `ABANDONED`, `EXPANDED`:
- Call `generate-task-order.sh --update-todo` to rebuild the entire section
- This auto-prunes the completed task from both wave table and tree
- Also fires when `--clean` flag is passed to `update-task-status.sh`

---

## Related

- @.claude/scripts/generate-task-order.sh — Auto-generation script
- @.claude/scripts/update-task-status.sh — Phase 3 status update (uses patterns above)
- @.claude/context/formats/roadmap-format.md — ROADMAP.md structure
- @.claude/rules/state-management.md — Task status management
- @.claude/rules/artifact-formats.md — Status marker definitions

---

## Appendix: Previous Format (Historical Reference)

The previous format (before 2026-05-15) used numbered category subsections with arrow-chain dependency notation and manual curation:

```markdown
### 1. Critical Path -- Primary Goal

```
63 → 58 → 59 → 60
```

1. **63** [RESEARCHED] -- Prove initial condition
2. **58** [NOT STARTED] -- Wire results to framework

### 2. Code Cleanup (parallel to critical path)

1. **57** [NOT STARTED] -- Clean up legacy modules

### 3. Experimental

- **61** [NOT STARTED] -- Explore alternative approach (independent)

### 4. Deferred

- **18** [BLOCKED] -- Deferred work (depends on base being clean)

### 5. Backlog

- **8** [RESEARCHED] -- Long-term improvement (publication quality, 12-20h)
```

This format required manual curation of categories and dependency chains, and did not auto-prune completed tasks. It was replaced by the wave+tree format for automated generation from state.json.

Key differences from the current format:
- **Categories**: Static numbered headings (`### 1. Critical Path`) replaced by dynamic topic headings (`### Plugin Config`)
- **Dependency notation**: Arrow-chain (`63 → 58 → 59`) replaced by indented DFS tree (`  └─ 58`)
- **Task entries**: Bold task numbers (`**63** [STATUS] -- desc`) replaced by plain IDs (`63 [STATUS] — desc`)
- **Automation**: Manual curation replaced by auto-generation from state.json via `generate-task-order.sh`
