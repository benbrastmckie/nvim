# System Architecture Overview

**Last Verified**: 2026-01-19

This document provides a high-level overview of the Neovim Configuration agent system architecture for users and developers.

---

## Three-Layer Architecture

The agent system uses a three-layer architecture that separates user interaction, routing, and execution:

```
                           USER
                             |
                             | /command args
                             v
    +-----------------------------------------------------+
    |                   LAYER 1: COMMANDS                  |
    |                                                      |
    |   .claude/commands/                                  |
    |   ├── research.md      Parse arguments              |
    |   ├── plan.md          Route by language            |
    |   ├── implement.md     Minimal logic                |
    |   └── ...                                            |
    +-----------------------------------------------------+
                             |
                             | Delegation context
                             v
    +-----------------------------------------------------+
    |                   LAYER 2: SKILLS                    |
    |                                                      |
    |   .claude/skills/skill-*/SKILL.md                   |
    |   ├── skill-neovim-research/   Validate inputs      |
    |   ├── skill-researcher/        Prepare context      |
    |   ├── skill-planner/           Invoke agents        |
    |   └── ...                                            |
    +-----------------------------------------------------+
                             |
                             | Task tool invocation
                             v
    +-----------------------------------------------------+
    |                   LAYER 3: AGENTS                    |
    |                                                      |
    |   .claude/agents/*.md                               |
    |   ├── neovim-research-agent.md Full execution       |
    |   ├── general-research-agent.md  Create artifacts   |
    |   ├── planner-agent.md         Return JSON          |
    |   └── ...                                            |
    +-----------------------------------------------------+
                             |
                             | Artifacts
                             v
    +-----------------------------------------------------+
    |                     ARTIFACTS                        |
    |                                                      |
    |   specs/{NNN}_{SLUG}/                                  |
    |   ├── reports/01_{short-slug}.md                    |
    |   ├── plans/02_{short-slug}.md                      |
    |   └── summaries/03_{short-slug}-summary.md          |
    +-----------------------------------------------------+
```

---

## Component Summary

### Commands (Layer 1)

**Location**: `.claude/commands/`

Commands are user-facing entry points invoked via `/command` syntax. They:
- Parse user arguments
- Route to appropriate skills based on task language
- Contain minimal logic (routing only)

**Available commands**:
| Command | Purpose |
|---------|---------|
| `/task` | Create, manage, sync tasks |
| `/research` | Conduct task research |
| `/plan` | Create implementation plans |
| `/implement` | Execute implementation |
| `/revise` | Revise plans |
| `/review` | Code review |
| `/errors` | Analyze errors |
| `/todo` | Archive completed tasks |
| `/meta` | System builder |

### Skills (Layer 2)

**Location**: `.claude/skills/skill-*/SKILL.md`

Skills are thin wrappers that validate inputs and delegate to agents. They:
- Validate task exists and arguments are correct
- Prepare delegation context (session_id, depth tracking)
- Invoke agents via the Task tool
- Pass through agent returns

**Key skills**:
| Skill | Agent | Purpose |
|-------|-------|---------|
| skill-neovim-research | neovim-research-agent | Neovim/plugin research |
| skill-researcher | general-research-agent | General web/codebase research |
| skill-planner | planner-agent | Create implementation plans |
| skill-implementer | general-implementation-agent | General file implementation |
| skill-neovim-implementation | neovim-implementation-agent | Neovim configuration implementation |

**Note**: Additional skills (latex, typst, filetypes) are available via extensions in `.claude/extensions/`.

### Agents (Layer 3)

**Location**: `.claude/agents/`

Agents are execution components that do the actual work. They:
- Load context on-demand
- Execute multi-step workflows
- Create artifacts (reports, plans, summaries)
- Return structured JSON results

---

## Execution Flow Example

When you run `/research 1`:

```
1. Command: research.md
   - Parse: task_number = 1
   - Lookup: language = "neovim" (from state.json)
   - Route: skill-neovim-research

2. Skill: skill-neovim-research
   - Generate session_id: sess_1736700000_abc123
   - Validate: task exists, status allows research
   - Prepare: delegation context
   - Invoke: neovim-research-agent via Task tool

3. Agent: neovim-research-agent
   - Load: Neovim context files
   - Execute: Search documentation, analyze plugins
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

## Language-Based Routing

Tasks route to specialized skills based on their `language` field:

| Language | Research | Implementation |
|----------|----------|----------------|
| `neovim` | skill-neovim-research | skill-neovim-implementation |
| `general` | skill-researcher | skill-implementer |
| `meta` | skill-researcher | skill-implementer |

The language is automatically detected from task description or can be set explicitly.

**Note**: Additional languages (latex, typst) are available via extensions in `.claude/extensions/`.

---

## State Management

The system maintains dual state files that stay synchronized:

| File | Purpose | Format |
|------|---------|--------|
| `specs/TODO.md` | User-facing task list | Markdown |
| `specs/state.json` | Machine-readable state | JSON |

Updates use two-phase commit:
1. Write state.json first
2. Write TODO.md second
3. Rollback both on any failure

---

## File Structure

```
.claude/
├── commands/           # Layer 1: User commands
│   ├── research.md
│   ├── plan.md
│   └── ...
├── skills/             # Layer 2: Skills
│   ├── skill-neovim-research/
│   │   └── SKILL.md
│   └── ...
├── agents/             # Layer 3: Agents
│   ├── neovim-research-agent.md
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

### Adding New Language Support

To add support for a new language (e.g., Python):

1. Create skill: `.claude/skills/skill-python-research/SKILL.md`
2. Create agent: `.claude/agents/python-research-agent.md`
3. Update routing in existing commands

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
- [README](../README.md) - Documentation hub

### Architecture Details

- [README.md](../../README.md) - Detailed system architecture
- [CLAUDE.md](../../CLAUDE.md) - Quick reference entry point

### Agent-Facing Documentation

- [Agent System Overview](../../context/core/architecture/system-overview.md) - Detailed architecture for agents (includes skill patterns, command mapping matrix)
