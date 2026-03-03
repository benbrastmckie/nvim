# OpenCode System Architecture Overview

**Last Verified**: 2026-02-28

This document provides a high-level overview of the Logos/Theory agent system architecture for users and developers.

---

## Three-Layer Architecture

The Logos/Theory agent system uses a three-layer architecture that separates user interaction, routing, and execution:

```
                           USER
                             |
                             | /command args
                             v
    +-----------------------------------------------------+
    |                   LAYER 1: COMMANDS                  |
    |                                                      |
    |   .opencode/commands/                                |
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
    |   .opencode/skills/skill-*/SKILL.md                 |
    |   ├── skill-lean-research/     Validate inputs      |
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
    |   .opencode/agent/subagents/*.md                    |
    |   ├── lean-research-agent.md   Full execution       |
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
    |   specs/OC_NNN_{SLUG}/                               |
    |   ├── reports/research-001.md                       |
    |   ├── plans/implementation-001.md                 |
    |   └── summaries/implementation-summary-{DATE}.md    |
    +-----------------------------------------------------+
```

---

## Component Summary

### Commands (Layer 1)

**Location**: `.opencode/commands/`

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

**Location**: `.opencode/skills/skill-*/SKILL.md`

Skills are thin wrappers that validate inputs and delegate to agents. They:
- Validate task exists and arguments are correct
- Prepare delegation context (session_id, depth tracking)
- Invoke agents via the Task tool
- Pass through agent returns

**Key skills**:
| Skill | Agent | Purpose |
|-------|-------|---------|
| skill-lean-research | lean-research-agent | Lean 4/Mathlib research |
| skill-researcher | general-research-agent | General web/codebase research |
| skill-planner | planner-agent | Create implementation plans |
| skill-implementer | general-implementation-agent | General file implementation |
| skill-lean-implementation | lean-implementation-agent | Lean proof implementation |

### Agents (Layer 3)

**Location**: `.opencode/agent/subagents/`

Agents are execution components that do the actual work. They:
- Load context on-demand
- Execute multi-step workflows
- Create artifacts (reports, plans, summaries)
- Return structured JSON results

---

## Execution Flow Example

When you run `/research OC_259`:

```
1. Command: research.md
   - Parse: task_number = OC_259
   - Lookup: language = "lean" (from state.json)
   - Route: skill-lean-research

2. Skill: skill-lean-research
   - Generate session_id: sess_1736700000_abc123
   - Validate: task exists, status allows research
   - Prepare: delegation context
   - Invoke: lean-research-agent via Task tool

3. Agent: lean-research-agent
   - Load: Lean 4 context files
   - Execute: Use MCP tools (lean_leansearch, etc.)
   - Create: specs/OC_259_{slug}/reports/research-001.md
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
| `lean` | skill-lean-research | skill-lean-implementation |
| `general` | skill-researcher | skill-implementer |
| `meta` | skill-researcher | skill-implementer |
| `latex` | skill-researcher | skill-latex-implementation |
| `typst` | skill-typst-research | skill-typst-implementation |

The language is automatically detected from task description or can be set explicitly.

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
.opencode/
├── commands/           # Layer 1: User commands
│   ├── research.md
│   ├── plan.md
│   └── ...
├── skills/             # Layer 2: Skills
│   ├── skill-lean-research/
│   │   └── SKILL.md
│   └── ...
├── agent/              # Layer 3: Agents
│   ├── orchestrator.md          # Primary agent
│   └── subagents/                 # Execution agents
│       ├── lean-research-agent.md
│       └── ...
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

1. Create skill: `.opencode/skills/skill-python-research/SKILL.md`
2. Create agent: `.opencode/agent/subagents/python-research-agent.md`
3. Update routing in existing commands

### Adding New Commands

To add a new command (e.g., /analyze):

1. Create command: `.opencode/commands/analyze.md`
2. Create skill: `.opencode/skills/skill-analyzer/SKILL.md`
3. Create agent: `.opencode/agent/subagents/analyzer-agent.md`

See the guides in `.opencode/docs/guides/` for detailed instructions.

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

### Agent-Facing Documentation

- [Context Index](../../context/index.md) - Full context loading guide

---

**Document Version**: 1.0
**Created**: 2026-02-28
**Maintained By**: Logos/Theory Development Team
