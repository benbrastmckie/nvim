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

## Core Components

Multi-task creators implement these 8 components. Components marked **Required** must be implemented; **Optional** components enhance the user experience but may be omitted based on context.

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
    {"label": "Add LSP configuration", "description": "nvim/lua/plugins/lsp.lua:67"},
    {"label": "Implement helper function", "description": "utils/helpers.lua:23"}
  ]
}
```

### 3. Topic Grouping (Optional but Recommended)

Cluster related items into coherent task groups when 2+ items are selected. This implements the **Task Minimization Principle** - proactively suggesting consolidation opportunities rather than passively accepting user-provided breakdowns.

**Automatic Topic Clustering** (implemented by `/meta` Stage 3.5 and `/fix-it`):
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
  "examples": ["Task 2: depends on Task 1", "Task 3: depends on Task 1, Task 2"]
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

| # | Title | Language | Effort | Dependencies |
|---|-------|----------|--------|--------------|
| 37 | Add sorting | meta | 2h | None |
| 38 | Update insertion | meta | 1h | Task #37 |

**Total Estimated Effort**: 3 hours
```

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

### 8. State Updates (Required)

Update state.json and TODO.md atomically with correct dependency information.

**state.json Entry Schema**:
```json
{
  "project_number": 36,
  "project_name": "task_slug",
  "status": "not_started",
  "language": "meta",
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
- **Language**: meta
- **Dependencies**: Task #35, Task #34

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
- [ ] **Discovery**: Clear criteria for identifying potential tasks
- [ ] **Selection UI**: AskUserQuestion with multiSelect
- [ ] **Confirmation**: Summary table + explicit "Yes, create tasks" selection
- [ ] **State Updates**: Update both state.json and TODO.md atomically

### Optional Components (Recommended for 3+ Tasks)
- [ ] **Grouping**: Semantic clustering when 2+ items selected
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
| **Topic Clustering** | **Interview Stage 3.5 (AnalyzeTopics - automatic clustering)** |
| Grouping | Interview Stage 3.5 (automatic) + Stage 3 (user refinement) |
| Dependencies | Interview Stage 3 Question 5 (dependency interview) |
| Ordering | Interview Stage 6 (Kahn's algorithm) |
| Visualization | Interview Stage 7 (DeliverSummary with graph) |
| Confirmation | Interview Stage 5 (mandatory confirmation) |
| **Research Generation** | **Interview Stage 5.5 (GenerateResearchArtifacts)** |
| State Updates | Interview Stage 6 (batch insertion with RESEARCHED status) |

**Enhanced Stages** (added for Task Minimization Principle):
- **Stage 3.5 (AnalyzeTopics)**: Extracts topic indicators, clusters by shared terms/components, presents consolidation picker
- **Stage 5.5 (GenerateResearchArtifacts)**: Creates `01_meta-research.md` from interview context for each task

See `.claude/agents/meta-builder-agent.md` for complete implementation details.

## Current Compliance Status

| Command | Required | Grouping | Dependencies | Ordering | Visualization | Research Gen |
|---------|----------|----------|--------------|----------|---------------|--------------|
| `/meta` | Yes | **Automatic** | Full DAG | Kahn's | Linear/Layered | **Yes** |
| `/fix-it` | Yes | Yes | Internal only | No | No | No |
| `/review` | Yes | Yes | No | No | No | No |
| `/errors` | Partial* | No | No | No | No | No |
| `/task --review` | Yes | No | parent_task | No | No | No |

*`/errors` creates tasks automatically without interactive selection (intentional for error triage workflow).

**Enhanced `/meta` Features**:
- **Automatic Topic Clustering** (Stage 3.5): Proactively analyzes user-provided task breakdown and suggests consolidation opportunities
- **Research Artifact Generation** (Stage 5.5): Creates lightweight research reports from interview context
- **RESEARCHED Status**: Tasks start in `researched` status, enabling immediate `/plan N` without separate `/research N`

## Gaps and Future Enhancements

### /review
- **Gap**: No dependency support between created tasks
- **Enhancement**: Add dependency interview for issue groups that have natural ordering

### /errors
- **Gap**: No interactive selection, no dependency support
- **Rationale**: Automatic mode is intentional for quick error triage
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
