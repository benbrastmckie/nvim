# System Architecture Overview

**Last Verified**: 2026-05-22

This document provides a high-level overview of the agent system architecture for users and developers.

The unified workflow refactor is complete. This document describes the **current** architecture including skill-base.sh lifecycle functions, command gate scripts, the /orchestrate autonomous state machine, computed CLAUDE.md generation, and extension lifecycle hooks.

**Note**: `/orchestrate` is the sole lifecycle entry point for the `general`/`meta`/`markdown`
task types, dispatching agents directly for the research/plan/implement phases (no per-function
skill layer). Extension domain task types still route through their own research/implementation
skills as shown below.

---

## Three-Layer Architecture

The agent system uses a three-layer architecture that separates user interaction, routing, and execution:

```
                           USER
                             |
                             | /command args
                             v
    ┌─────────────────────────────────────────────────────┐
    │                   LAYER 1: COMMANDS                  │
    │                                                      │
    │   .claude/commands/                                  │
    │   ├── orchestrate.md   Parse arguments               │
    │   ├── meta.md          Route by task_type             │
    │   ├── revise.md        Minimal logic                 │
    │   └── ...                                            │
    └─────────────────────────────────────────────────────┘
                             |
                             | Delegation context
                             v
    ┌─────────────────────────────────────────────────────┐
    │                   LAYER 2: SKILLS                    │
    │                                                      │
    │   .claude/skills/skill-*/SKILL.md                   │
    │   ├── skill-orchestrate/  Validate inputs             │
    │   │                       Prepare context, dispatch   │
    │   │                       agents directly (no per-    │
    │   │                       function skill layer)       │
    │   └── ...                                            │
    └─────────────────────────────────────────────────────┘
                             |
                             | Agent tool invocation
                             v
    ┌─────────────────────────────────────────────────────┐
    │                   LAYER 3: AGENTS                    │
    │                                                      │
    │   .claude/agents/*.md                               │
    │   ├── general-research-agent.md  Full execution     │
    │   ├── general-implementation-agent.md Create artifacts│
    │   ├── planner-agent.md         Return JSON          │
    │   └── ...                                            │
    └─────────────────────────────────────────────────────┘
                             |
                             | Artifacts
                             v
    ┌─────────────────────────────────────────────────────┐
    │                     ARTIFACTS                        │
    │                                                      │
    │   specs/{NNN}_{SLUG}/                                  │
    │   ├── reports/01_{short-slug}.md                    │
    │   ├── plans/02_{short-slug}.md                      │
    │   └── summaries/03_{short-slug}-summary.md          │
    └─────────────────────────────────────────────────────┘
```

---

## Component Summary

### Commands (Layer 1)

**Location**: `.claude/commands/`

Commands are user-facing entry points invoked via `/command` syntax. They:
- Parse user arguments
- Route to appropriate skills based on task language
- Contain minimal logic (routing only)

**Available commands** (core; loaded extensions contribute further task-type-specific commands via the extension picker — see [extensions/README.md](../../../README.md)):
| Command | Purpose |
|---------|---------|
| `/task` | Create, recover, divide, sync, or abandon tasks |
| `/orchestrate` | Drive a task autonomously through its full lifecycle (research -> plan -> implement -> complete) |
| `/revise` | Create new version of implementation plan, or update task description if no plan exists |
| `/review` | Review code and create analysis reports |
| `/project-overview` | Analyze repository and create task to generate project-overview.md |
| `/todo` | Archive completed, abandoned, and expanded tasks |
| `/errors` | Analyze errors and create fix plans |
| `/meta` | Interactive system builder that creates tasks for agent architecture changes |
| `/fix-it` | Scan for FIX:/NOTE:/TODO:/QUESTION: tags and create structured tasks |
| `/zulip` | Fetch a Zulip thread via API and write formatted JSON to a file |
| `/refresh` | Clean orphaned processes and old files |
| `/tag` | Create and push semantic version tags for CI/CD deployment (user-only) |
| `/spawn` | Spawn new tasks to unblock a blocked task |
| `/merge` | Create a pull/merge request for the current branch (user-only) |
| `/please` | Authorize one otherwise-blocked git action for this single invocation (user-only) |

### Skills (Layer 2)

**Location**: `.claude/skills/skill-*/SKILL.md`

Skills are thin wrappers that validate inputs and delegate to agents. All skills share lifecycle logic via `.claude/scripts/skill-base.sh`, which provides:
- `skill_validate_input()` — validate task number and state
- `skill_preflight_update()` — update status to "in progress" + run extension `preflight` hook
- `skill_context_injection()` — run extension `context_injection` hook before agent delegation
- `skill_read_metadata()` / `skill_validate_artifact()` — read and validate agent return + run extension `verification` hook
- `skill_postflight_update()` — update status to completed + run extension `postflight` hook
- `skill_link_artifacts()` / `skill_cleanup()` — artifact linking and cleanup

**Key skills**:
| Skill | Agent | Purpose |
|-------|-------|---------|
| skill-meta | meta-builder-agent | System building and task creation |
| skill-status-sync | (direct execution) | Atomic status updates |
| skill-orchestrate | (direct execution) | Autonomous lifecycle state machine (/orchestrate command) — dispatches `general-research-agent`/`planner-agent`/`general-implementation-agent` directly for `general`/`meta`/`markdown` task types |
| skill-git-workflow | (direct execution) | Create scoped git commits |
| skill-spawn | spawn-agent | Analyze blockers and spawn new tasks |

**Note**: Additional skills are available via extensions in `agent-system/extensions/`. Extension skills are thin wrappers (under ~110 lines) that source skill-base.sh and delegate to their domain agent. See [CLAUDE.md](../../CLAUDE.md) for the complete skill-to-agent mapping.

### Agents (Layer 3)

**Location**: `.claude/agents/`

Agents are execution components that do the actual work. They:
- Load context on-demand
- Execute multi-step workflows
- Create artifacts (reports, plans, summaries)
- Write structured `.return-meta.json` metadata (read by skills in postflight)

---

## Computed CLAUDE.md

CLAUDE.md at `.claude/CLAUDE.md` is a **computed artifact** generated by `merge.lua:generate_claudemd()`. It is assembled from:
- Core merge-source: `agent-system/extensions/core/merge-sources/claudemd.md`
- Loaded extension EXTENSION.md files (each extension contributes a section)

Do not edit `.claude/CLAUDE.md` directly — it will be overwritten on the next generation. To modify core content, edit the merge-sources. To modify extension content, edit the extension's `EXTENSION.md`.

---

## Extension Lifecycle Hooks

Extensions can declare lifecycle hooks in their `manifest.json` under a top-level `"hooks"` object:

```json
{
  "hooks": {
    "preflight": "scripts/my-preflight.sh",
    "context_injection": "scripts/my-context.sh",
    "verification": "scripts/my-verify.sh",
    "postflight": "scripts/my-postflight.sh"
  }
}
```

**Distinction from `provides.hooks`**: The `provides.hooks` array lists scripts for file-copy deployment to `.claude/hooks/`. The top-level `hooks` object lists scripts called during skill lifecycle stages.

Hook scripts receive 5 positional arguments: `task_number task_type task_dir session_id operation`.

All hooks are:
- Optional (missing key = skip silently)
- Non-blocking (non-zero exit = warning, not failure)
- Invoked by skill-base.sh at the corresponding lifecycle stage

---

## Execution Flow Example

When you run `/orchestrate 1 --research`:

```
1. Command: orchestrate.md
   - Parse: task_number = 1
   - Lookup: task_type = "general" (from state.json)
   - Route: general-research-agent (via command-route-agent.sh)

2. Skill: skill-orchestrate
   - Generate session_id: sess_1736700000_abc123
   - Validate: task exists, status is not terminal
   - Prepare: delegation context
   - Invoke: general-research-agent via Agent tool

3. Agent: general-research-agent
   - Load: relevant context files
   - Execute: Search documentation, analyze codebase
   - Create: specs/001_{slug}/reports/01_{short-slug}.md
   - Return: {"status": "researched", "artifacts": [...]}

4. Postflight:
   - Update: specs/state.json (status -> researched)
   - Update: specs/TODO.md (add research link)
   - Commit: git commit with session_id
```

---

## Checkpoint Model

All workflow commands follow a three-checkpoint pattern:

```
CHECKPOINT 1     -->     STAGE 2      -->     CHECKPOINT 2     -->   CHECKPOINT 3
  GATE IN                DELEGATE              GATE OUT              COMMIT
 (Preflight)           (Skill/Agent)         (Postflight)         (Git Commit)
```

| Checkpoint | Purpose |
|------------|---------|
| GATE IN | Validate task, update status to "in_progress" |
| DELEGATE | Route to skill, skill invokes agent |
| GATE OUT | Validate result, update status to "success" |
| COMMIT | Git commit with session tracking |

This ensures:
- Consistent state management
- Traceability via session IDs
- Recovery from interruptions
- Automatic git commits

---

## Task-Type-Based Routing

Tasks route to specialized agents based on their `task_type` field. `general`/`meta`/`markdown`
route directly to agents (no per-function skill layer); extension task types may route through
their own domain skill instead:

| Task Type | Research | Implementation |
|----------|----------|----------------|
| `general` | general-research-agent | general-implementation-agent |
| `meta` | general-research-agent | general-implementation-agent |
| `markdown` | general-research-agent | general-implementation-agent |

The task type is automatically detected from task description or can be set explicitly.

**Note**: Additional task types (nix, latex, typst, python, etc.) are available via extensions in `agent-system/extensions/`.

---

## State Management

The system maintains dual state files that stay synchronized:

| File | Purpose | Format |
|------|---------|--------|
| `specs/TODO.md` | User-facing task list | Markdown |
| `specs/state.json` | Machine-readable state | JSON |

Updates use the state-first pipeline:
1. Write state.json (sole source of truth)
2. Regenerate TODO.md via `generate-todo.sh`

---

## File Structure

```
.claude/
├── commands/           # Layer 1: User commands
│   ├── orchestrate.md
│   ├── meta.md
│   └── ...
├── skills/             # Layer 2: Skills
│   ├── skill-orchestrate/
│   │   └── SKILL.md
│   └── ...
├── agents/             # Layer 3: Agents
│   ├── general-research-agent.md
│   └── ...
├── rules/              # Automatic behavior rules
├── context/            # Domain knowledge
│   └── core/
│       ├── architecture/    # Architecture docs (for agents)
│       ├── patterns/        # Reusable patterns
│       ├── formats/         # Artifact formats
│       └── ...
└── docs/               # User documentation
    ├── guides/         # How-to guides
    ├── architecture/   # This directory
    └── ...
```

---

## Extending the System

### Adding New Language Support via Extensions

The recommended way to add new language support is via an extension. Create a directory under `agent-system/extensions/{name}/` with:

1. `manifest.json` — extension metadata, routing, hook scripts
2. `EXTENSION.md` — content merged into CLAUDE.md
3. `skills/skill-{name}-research/SKILL.md` — thin research skill
4. `skills/skill-{name}-implementation/SKILL.md` — thin implementation skill
5. `agents/{name}-research-agent.md` — research agent
6. `agents/{name}-implementation-agent.md` — implementation agent

Extension skills should source skill-base.sh for lifecycle management. See `.claude/docs/guides/creating-extensions.md` for detailed instructions.

### Adding New Commands

To add a new command (e.g., /analyze):

1. Create command: `.claude/commands/analyze.md`
2. Create skill: `.claude/skills/skill-analyzer/SKILL.md`
3. Create agent: `.claude/agents/analyzer-agent.md`

See the guides in `.claude/docs/guides/` for detailed instructions.

---

## Related Documentation

### For Developers

- [Component Selection Guide](../guides/component-selection.md) - When to create what
- [Creating Commands](../guides/creating-commands.md) - Command creation guide
- [Creating Skills](../guides/creating-skills.md) - Skill creation guide
- [Creating Agents](../guides/creating-agents.md) - Agent creation guide

### For Users

- [User Installation Guide](../guides/user-installation.md) - Getting started
- [README](../docs-README.md) - Documentation hub

### Architecture Details

- [README.md](../../README.md) - Detailed system architecture
- [CLAUDE.md](../../CLAUDE.md) - Quick reference entry point

### Agent-Facing Documentation

- [Agent System Overview](../../context/architecture/system-overview.md) - Detailed architecture for agents (includes skill patterns, command mapping matrix)
