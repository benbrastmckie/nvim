# Meta Guide: /meta Command Reference

Reference guide for the `/meta` command -- the interactive system builder that creates **tasks** for `.claude/` system changes. This guide documents the actual deployed system behavior.

## Overview

The `/meta` command creates structured tasks in TODO.md and state.json for modifying the `.claude/` agent architecture. It never implements changes directly -- it only plans what needs to change and creates task entries for the standard `/research` -> `/plan` -> `/implement` lifecycle.

**Delegation chain**: `/meta` command -> `skill-meta` -> `meta-builder-agent` -> TODO.md + state.json

**Critical distinction**: `/meta` does NOT create commands, skills, agents, rules, or context files. It creates *tasks* that describe those changes. Actual file creation happens later during `/implement`.

**Multi-task creation standard**: `/meta` is the reference implementation for the multi-task creation standard (all 8 components). See `.claude/docs/reference/standards/multi-task-creation-standard.md`.

## Modes

### Interactive Mode (no arguments)

```bash
/meta
```

Launches the full 7-stage interview using AskUserQuestion for multi-turn conversation. Best for exploratory or complex system changes where the scope needs to be discovered through dialogue.

### Prompt Mode (with text argument)

```bash
/meta "add a new command for exporting logs"
```

Abbreviated flow that parses the prompt for intent, checks for related existing tasks, proposes a task breakdown, and confirms with the user before creating tasks. Best for focused changes where the user already knows what they want.

### Analyze Mode (--analyze)

```bash
/meta --analyze
```

Read-only system analysis. Inventories all commands, skills, agents, and rules; counts active tasks; provides recommendations. No tasks are created.

## Interactive Interview Stages

The interactive mode executes these stages in order. Each user-facing choice uses AskUserQuestion with the `options` parameter (never plain text selection).

### Stage 0: DetectExistingSystem

Scans the `.claude/` directory to count existing components (commands, skills, agents, rules) and active tasks. Displays the inventory so both user and agent have context about the current system state.

### Stage 1: InitiateInterview

Explains the process (5-10 minutes), what the user will get (task entries, dependencies, execution order), and sets expectations. No user input required.

### Stage 2: GatherDomainInfo

Two questions via AskUserQuestion:
1. **Purpose**: What do you want to accomplish? Options include adding commands, skills/agents, fixing existing components, creating documentation, or something else.
2. **Scope**: What part of the `.claude/` system is affected?

Context files are loaded on-demand based on the user's selections (e.g., `creating-commands.md` if adding a command).

### Stage 2.5: DetectDomainType

Classifies the task type based on keywords. Since `/meta` is inherently about `.claude/` system changes, this almost always produces `task_type = "meta"`. This stage is vestigial -- the classification is largely redundant given the command's scope.

### Stage 3: IdentifyUseCases

Three question areas:
1. **Task breakdown**: Can this be broken into smaller tasks? (Yes / No / Help me break it down)
2. **Task listing**: If multiple tasks, user provides discrete task titles and descriptions.
3. **Dependencies**: Do tasks depend on each other? Options: No dependencies, Linear chain, Custom specification. Custom allows specifying which tasks depend on which using `Task N: depends on Task M` format.

Dependencies are validated immediately:
- No self-references
- All referenced task indices must exist
- No circular dependencies (detected via DFS)

Optional follow-up asks about external dependencies on existing tasks in TODO.md.

### Stage 3.5: AnalyzeTopics (Topic Clustering)

Executes only when the user provided 2+ tasks with shared topic indicators. Implements the **Task Minimization Principle**: fewer, well-scoped tasks are better than many fragmented ones.

Extracts key terms, component types, affected areas, and action types from each task. Clusters related tasks by shared indicators. Presents a consolidation picker with three options:
- Accept suggested groups (consolidated tasks)
- Keep as separate tasks (original breakdown)
- Customize groupings (fine-grained control via multiSelect)

Consolidated tasks use effort scaling: `base_effort + (30 min * (item_count - 1))`.

### Stage 4: AssessComplexity

Asks the user to estimate effort for each task: Small (< 1h), Medium (1-3h), Large (3-6h), Very Large (> 6h, consider splitting).

### Stage 5: ReviewAndConfirm

Presents a summary table of all tasks with titles, task types, effort estimates, and dependencies. The user must explicitly select "Yes, create tasks" to proceed. Other options: "Revise" (return to Stage 3) or "Cancel" (exit without creating tasks).

This confirmation gate is mandatory -- no tasks are created without it.

### Stage 6: CreateTasks

Applies Kahn's topological sorting algorithm to ensure foundational tasks (those with no dependencies) receive lower task numbers. Tasks are inserted into TODO.md as a batch (not individually prepended) to preserve topological order.

For each task:
1. Assigns a task number from `next_project_number` in state.json
2. Creates a slug from the title
3. Updates state.json with the new project entry (including dependencies array)
4. Creates the task directory under `specs/`

TODO.md entries include all required fields: Effort, Status ([NOT STARTED]), Task Type, Dependencies, and Description.

Git commit happens inside the agent: `meta: create {N} tasks for {domain}`.

### Stage 7: DeliverSummary

Generates a summary with:
- Task table (number, title, dependencies, path)
- Dependency graph visualization (linear chain or layered DAG based on complexity)
- Execution order with parallel execution annotations
- Next steps pointing to `/research {first_task}` for the foundational task

## Task Dependency System

### Dependency Types

| Type | Description | Example |
|------|-------------|---------|
| None | All tasks independent | `dependency_map = {}` |
| Linear chain | Sequential A -> B -> C | `{2: [1], 3: [2]}` |
| Custom DAG | Arbitrary dependencies | `{3: [1, 2], 4: [2]}` |
| External | Depends on existing tasks | `Task 1: depends on #35` |

### Dependency Validation

Three checks run before proceeding past Stage 3:
1. **Self-reference**: Task cannot depend on itself
2. **Valid index**: All referenced tasks must exist in the task list
3. **Circular dependency**: No cycles allowed (DFS-based detection)

External dependencies are validated against state.json but failures are non-blocking (the task may be archived).

### Topological Sorting

Kahn's algorithm sorts tasks so foundational tasks receive lower numbers:
1. Build reverse dependency graph
2. Calculate in-degree for each task
3. Initialize queue with zero-dependency tasks
4. Process queue in BFS order, decrementing dependents' in-degree

This ensures the first task in TODO.md is the one to start with.

### Visualization

**Linear chain** (each task depends on at most one other, and is depended on by at most one):
```
  [37] Add topological sorting
    |
    v
  [38] Update TODO insertion
    |
    v
  [39] Enhance visualization
```

**Layered DAG** (diamond patterns, parallel branches, or multiple roots):
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

External dependencies are shown above the graph when present.

## Multi-Task Creation Standard Compliance

`/meta` implements all 8 components of the multi-task creation standard:

| Component | Implementation | Stage |
|-----------|---------------|-------|
| Discovery | User interview responses | 2-3 |
| Selection | ReviewAndConfirm with task list | 5 |
| Grouping | Automatic topic clustering | 3.5 |
| Dependencies | Internal + external dependency interview | 3 |
| Ordering | Kahn's topological sorting | 6 |
| Visualization | Linear chain / layered DAG | 7 |
| Confirmation | Mandatory "Yes, create tasks" gate | 5 |
| State Updates | Batch insertion into TODO.md + state.json | 6 |

## What You Get

After `/meta` completes (interactive or prompt mode):

- **Task entries** in TODO.md with status `[NOT STARTED]`
- **State entries** in state.json with `task_type: "meta"` and dependencies array
- **Task directories** under `specs/{NNN}_{slug}/`
- **Dependency visualization** showing execution order
- **Next steps**: Run `/research {N}` on the first foundational task

After `/meta --analyze`:

- **Component inventory** listing all commands, skills, agents, rules
- **Active task count** from state.json
- **Recommendations** for system improvements
- No tasks created, no files modified

## After /meta: The Lifecycle

Tasks created by `/meta` follow the standard lifecycle:

```
/meta (creates tasks) -> /research N -> /plan N -> /implement N
```

Meta tasks route through the standard skill pipeline:
- `/research N` uses `skill-researcher` (not a meta-specific research agent)
- `/plan N` uses `skill-planner`
- `/implement N` uses `skill-implementer`

The `meta-builder-agent` is only invoked by `/meta` itself -- it is not used during research, planning, or implementation of the tasks it creates.

## Known Limitations

1. **v1 return protocol**: The meta-builder-agent returns console JSON rather than writing a `.return-meta.json` file. This is the legacy v1 protocol; all other agents use the v2 file-based return protocol. The agent header declares v2 but the body implements v1.

2. **Minimal postflight**: Git commits happen inside the agent (Stage 6), not in skill-meta's postflight. The skill's declared "skill-internal postflight" is limited to reading the agent's return. This differs from other skills where postflight handles status updates, artifact linking, and git commits.

3. **No memory integration**: Unlike `/research`, `/plan`, and `/implement` (which call `memory-retrieve.sh` to inject relevant memories), `/meta` does not retrieve memories. Past decisions, patterns, and anti-patterns from the memory vault are not available during the interview.

4. **No effort/model flags**: `/meta` does not support `--fast`, `--hard`, `--team`, `--haiku`, `--sonnet`, or `--opus` flags. It always runs in its default mode.

5. **DetectDomainType is vestigial**: Stage 2.5 classifies tasks as "meta" vs "general" based on keywords, but since `/meta` is inherently about `.claude/` changes, the result is almost always "meta."

## Future Extensions

1. **Memory retrieval during task creation**: Add memory retrieval to skill-meta (similar to skill-researcher's Stage 4a). When creating tasks for familiar domains, retrieved memories about past patterns and decisions would inform the interview. Implementation would use the existing `memory-retrieve.sh` infrastructure.

2. **Roadmap-aware priority hints**: Pass `roadmap_path` in delegation context. During ReviewAndConfirm (Stage 5), the agent could check if proposed tasks align with roadmap priorities and surface alignment information.

3. **Sister file updates**: The companion files in `.claude/context/meta/` (architecture-principles.md, standards-checklist.md, interview-patterns.md) contain stale references and should be updated or consolidated in follow-on tasks.

4. **v2 return protocol migration**: Migrate meta-builder-agent from console JSON return to file-based `.return-meta.json` protocol, aligning with all other agents and enabling proper postflight in skill-meta.

## Resources

| File | Purpose |
|------|---------|
| `.claude/commands/meta.md` | Command entry point with mode detection |
| `.claude/skills/skill-meta/SKILL.md` | Skill wrapper with delegation context |
| `.claude/agents/meta-builder-agent.md` | Full agent specification (source of truth) |
| `.claude/docs/reference/standards/multi-task-creation-standard.md` | Multi-task creation standard |
| `.claude/docs/guides/component-selection.md` | Component selection guide (loaded during interview) |
