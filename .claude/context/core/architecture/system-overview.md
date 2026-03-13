# System Architecture Overview

**Created**: 2026-01-19
**Last Verified**: 2026-01-19
**Purpose**: Consolidated architecture reference for agents generating new components
**Audience**: /meta agent, system developers, architecture reviewers

---

## Three-Layer Architecture

The Neovim Configuration agent system implements a three-layer delegation pattern separating concerns into distinct execution layers.

```
                         USER INPUT
                              │
                              ▼
                    ┌─────────────────┐
     Layer 1:       │    Commands     │  User-facing entry points
     (Commands)     │  (/research,    │  Parse $ARGUMENTS
                    │   /plan, etc.)  │  Route to skills
                    └────────┬────────┘
                              │
                              ▼
                    ┌─────────────────┐
     Layer 2:       │     Skills      │  Thin wrappers with validation
     (Skills)       │ (skill-neovim-    │  Prepare delegation context
                    │  research, etc.)│  Invoke agents via Task tool
                    └────────┬────────┘
                              │
                              ▼
                    ┌─────────────────┐
     Layer 3:       │     Agents      │  Full execution components
     (Agents)       │ (neovim-research- │  Load context on-demand
                    │  agent, etc.)   │  Create artifacts
                    └────────┬────────┘
                              │
                              ▼
                        ARTIFACTS
               (reports, plans, summaries)
```

---

## Component Responsibilities Matrix

| Aspect | Command | Skill | Agent |
|--------|---------|-------|-------|
| **Location** | `.claude/commands/` | `.claude/skills/skill-*/SKILL.md` | `.claude/agents/*.md` |
| **User-facing** | Yes | No | No |
| **Invocation** | `/command` syntax | Via Command routing | Via Task tool from Skill |
| **Context loading** | None | Minimal | Full (lazy loading) |
| **Input validation** | Basic parsing | Delegation validation | Execution validation |
| **Execution** | Route only | Validate + delegate | Full workflow |
| **Artifact creation** | No | No | Yes |
| **Return format** | N/A | Pass-through | Standardized JSON |

---

## Layer Details

### Layer 1: Commands

**Purpose**: User-facing entry points that parse arguments and route to skills.

**Key characteristics**:
- Parse `$ARGUMENTS` from user input
- Determine target skill based on routing rules
- Pass arguments to skill via orchestrator
- Minimal logic (routing only)

**Structure requirements**:
- YAML frontmatter with routing table
- Command name, description, usage examples
- No execution logic embedded

**Example routing**:
```yaml
---
routing:
  neovim: skill-neovim-research
  general: skill-researcher
  default: skill-researcher
---
```

**Reference**: @.claude/docs/guides/creating-commands.md

---

### Layer 2: Skills

**Purpose**: Thin wrappers that validate inputs, delegate to agents, and handle lifecycle operations.

**Key characteristics**:
- Validate inputs before delegation
- Prepare delegation context (session_id, depth, path)
- Invoke agent via **Task tool** (not Skill tool)
- Handle preflight/postflight status updates internally
- Perform git commit after agent completion
- Return brief text summary (agent writes JSON to metadata file)

**Thin Wrapper Pattern**:
```yaml
---
name: skill-{name}
description: {description}
allowed-tools: Task, Bash, Edit, Read, Write
---
```

**Note**: Skills do NOT use `context: fork` or `agent:` frontmatter fields. Delegation is explicit via Task tool invocation in the skill body. Context loading happens in the agent (not via skill frontmatter).

**Critical**: Skills delegate via Task tool, not Skill tool. Agents live in `.claude/agents/`, not `.claude/skills/`.

**Reference**: @.claude/context/core/patterns/thin-wrapper-skill.md

---

### Layer 3: Agents

**Purpose**: Full execution components that do the actual work.

**Key characteristics**:
- Load context on-demand via @-references
- Execute multi-step workflows
- Create artifacts in proper locations
- Return standardized JSON format
- Handle errors with recovery information

**Execution pattern**:
1. Parse delegation context
2. Load required context files
3. Execute workflow steps
4. Create artifacts
5. Return JSON result

**Return format**:
```json
{
  "status": "researched|planned|implemented|partial|failed|blocked",
  "summary": "Brief 2-5 sentence summary (<100 tokens)",
  "artifacts": [{...}],
  "metadata": {
    "session_id": "sess_{timestamp}_{random}",
    "agent_type": "{name}",
    "delegation_depth": N,
    "delegation_path": [...]
  },
  "errors": [...],
  "next_steps": "..."
}
```

**Critical**: Never use "completed" as status value - triggers Claude stop behavior.

**Reference**: @.claude/context/core/formats/subagent-return.md

---

## Skill Architecture Patterns

Skills implement three distinct architecture patterns based on their execution needs.

### Pattern A: Delegating Skills with Internal Postflight

**Used by**: skill-researcher, skill-neovim-research, skill-planner, skill-implementer, skill-neovim-implementation, skill-meta (6 core skills; extensions add more)

**Characteristics**:
- Frontmatter: `allowed-tools: Task, Bash, Edit, Read, Write`
- 11-stage execution flow with preflight/postflight inline
- Invoke subagent via Task tool with explicit subagent_type
- Handle all lifecycle operations (status updates, git commit)
- Create postflight marker file to prevent premature termination
- Return brief text summary (agent writes JSON to metadata file)

**Execution Flow**:
```
Stage 1:  Input Validation
Stage 2:  Preflight Status Update      [RESEARCHING]
Stage 3:  Create Postflight Marker
Stage 4:  Prepare Delegation Context
Stage 5:  Invoke Subagent (Task tool)
Stage 6:  Parse Subagent Return (read metadata file)
Stage 7:  Update Task Status           [RESEARCHED]
Stage 8:  Link Artifacts
Stage 9:  Git Commit
Stage 10: Cleanup (remove marker)
Stage 11: Return Brief Summary
```

**Motivation**: Eliminates "continue prompt" between skill return and orchestrator. The skill handles all lifecycle operations, ensuring atomic completion without user interaction.

---

### Pattern B: Direct Execution Skills

**Used by**: skill-status-sync, skill-refresh, skill-git-workflow (3 skills)

**Characteristics**:
- Frontmatter: `allowed-tools: Bash, Edit, Read` (no Task tool)
- Execute work inline without spawning subagent
- No postflight marker needed (work is atomic)
- Return JSON or text directly

**Example Frontmatter**:
```yaml
---
name: skill-status-sync
description: Atomically update task status across TODO.md and state.json
allowed-tools: Bash, Edit, Read
---
```

**Motivation**: Some operations are simple enough that spawning a subagent adds unnecessary overhead. Status updates, git commits, and process cleanup are atomic operations that don't need the full delegation machinery.

---

### Pattern C: Orchestrator/Routing Skills

**Used by**: skill-orchestrator (1 skill)

**Characteristics**:
- Frontmatter: `allowed-tools: Read, Glob, Grep, Task`
- Central routing intelligence
- Dispatches to other skills/agents based on task language
- Provides context preparation and routing logic

**Motivation**: Centralizes routing decisions and reduces duplication across commands. Rather than each command implementing routing logic, the orchestrator provides a single source of routing truth.

---

### Pattern Selection Decision Tree

When creating a new skill:

```
Does the skill need to spawn a subagent?
├── NO → Pattern B (Direct Execution)
│   └── Use for: atomic operations, status updates, cleanup
│
└── YES → Does it need to route to multiple skills/agents?
    ├── YES → Pattern C (Orchestrator/Routing)
    │   └── Use for: command routing, language-based dispatch
    │
    └── NO → Pattern A (Delegating with Internal Postflight)
        └── Use for: research, planning, implementation workflows
```

**Default Choice**: Pattern A is the standard for new skills unless there's a specific reason to use B or C.

---

## Delegation Flow

### Standard Execution Flow

```
User: "/research 259"
         │
         ▼
┌───────────────────┐
│ 1. Command parses │  Extract task_number=259
│    $ARGUMENTS     │  Determine language=neovim
└─────────┬─────────┘
          │
          ▼
┌───────────────────┐
│ 2. Route to skill │  language=neovim → skill-neovim-research
│    by language    │
└─────────┬─────────┘
          │
          ▼
┌───────────────────┐
│ 3. Skill prepares │  session_id: sess_1736700000_abc123
│    delegation     │  delegation_depth: 1
│    context        │  delegation_path: [orchestrator, research, ...]
└─────────┬─────────┘
          │
          ▼
┌───────────────────┐
│ 4. Skill invokes  │  Task tool with subagent_type: neovim-research-agent
│    agent via Task │  Pass: task_context, delegation_context
└─────────┬─────────┘
          │
          ▼
┌───────────────────┐
│ 5. Agent loads    │  @.claude/context/project/lean4/...
│    context        │  @specs/state.json
│    on-demand      │  Task details from TODO.md
└─────────┬─────────┘
          │
          ▼
┌───────────────────┐
│ 6. Agent executes │  Use MCP tools (lean_leansearch, etc.)
│    workflow       │  Gather findings
└─────────┬─────────┘
          │
          ▼
┌───────────────────┐
│ 7. Agent creates  │  specs/259_{slug}/reports/01_research-findings.md
│    artifacts      │
└─────────┬─────────┘
          │
          ▼
┌───────────────────┐
│ 8. Agent returns  │  {"status": "researched", "artifacts": [...]}
│    JSON           │
└─────────┬─────────┘
          │
          ▼
┌───────────────────┐
│ 9. Skill validates│  Check return schema
│    return         │  Verify session_id matches
└─────────┬─────────┘
          │
          ▼
┌───────────────────┐
│ 10. Postflight    │  Update TODO.md: [RESEARCHED]
│     (checkpoint)  │  Update state.json
│                   │  Git commit
└───────────────────┘
```

---

## Checkpoint-Based Execution

All workflow commands follow a three-checkpoint pattern:

```
┌──────────────────────────────────────────────────────────────┐
│  CHECKPOINT 1    ─→    STAGE 2    ─→    CHECKPOINT 2    ─→   │
│   GATE IN              DELEGATE          GATE OUT            │
│  (Preflight)         (Skill/Agent)     (Postflight)          │
│                                                   │          │
│                                                   ▼          │
│                                            CHECKPOINT 3      │
│                                              COMMIT          │
└──────────────────────────────────────────────────────────────┘
```

### Checkpoint Details

| Checkpoint | Purpose | Key Operations |
|------------|---------|----------------|
| GATE IN | Preflight validation | Generate session_id, validate task exists, update status to "in_progress" variant |
| DELEGATE | Execute work | Route to skill, skill invokes agent, agent creates artifacts |
| GATE OUT | Postflight validation | Validate return, link artifacts, update status to success variant |
| COMMIT | Finalize | Git commit with session_id, return result to user |

**Reference**: @.claude/context/core/checkpoints/

---

## Session Tracking

Every delegation has a unique session ID for traceability:

**Format**: `sess_{unix_timestamp}_{6_char_random}`
**Example**: `sess_1736700000_abc123`

**Generation**:
```bash
session_id="sess_$(date +%s)_$(od -An -N3 -tx1 /dev/urandom | tr -d ' ')"
```

**Usage**:
- Generated at GATE IN checkpoint
- Passed through delegation context to agent
- Returned in agent metadata
- Included in git commit message
- Logged in errors.json for traceability

---

## Language-Based Routing

Tasks route to specialized skills/agents based on their `language` field:

| Language | Research | Planning | Implementation |
|----------|----------|----------|----------------|
| `neovim` | skill-neovim-research → neovim-research-agent | skill-planner → planner-agent | skill-neovim-implementation → neovim-implementation-agent |
| `general` | skill-researcher → general-research-agent | skill-planner → planner-agent | skill-implementer → general-implementation-agent |
| `meta` | skill-researcher → general-research-agent | skill-planner → planner-agent | skill-implementer → general-implementation-agent |

**Note**: Additional languages (latex, typst) available via extensions in `.claude/extensions/`.

---

## Command-Skill-Agent Mapping

Complete mapping of all commands to their skill and agent paths:

| Command | Routing Type | Skill(s) | Agent(s) | Pattern |
|---------|--------------|----------|----------|---------|
| `/research` | Language-based | neovim: skill-neovim-research, other: skill-researcher | neovim-research-agent, general-research-agent | A |
| `/plan` | Single | skill-planner | planner-agent | A |
| `/implement` | Language-based | neovim: skill-neovim-implementation, other: skill-implementer | neovim-implementation-agent, general-implementation-agent | A |
| `/revise` | Single | skill-planner (new version) | planner-agent | A |
| `/meta` | Single | skill-meta | meta-builder-agent | A |
| `/review` | Direct | skill-orchestrator | (inline execution) | C |
| `/errors` | Direct | skill-orchestrator | (inline execution) | C |
| `/todo` | Direct | skill-orchestrator | (inline execution) | C |
| `/task` | Direct | skill-orchestrator | (inline execution) | C |
| `/refresh` | Direct | skill-refresh | (no agent) | B |

**Note**: Additional commands (/convert) available via extensions in `.claude/extensions/`.

**Pattern Legend**:
- **A**: Delegating skill with internal postflight (spawns subagent)
- **B**: Direct execution skill (no subagent)
- **C**: Orchestrator/routing skill (central dispatch)

**Routing Types**:
- **Language-based**: Routes to different skills based on task language field
- **Single**: Always routes to the same skill regardless of language
- **Direct**: Executes inline without spawning a subagent

---

## Error Handling

Errors propagate upward through the layers with structured information:

```
Agent Error
    │
    ▼
Agent returns: {"status": "failed", "errors": [{...}]}
    │
    ▼
Skill validates return, passes through error
    │
    ▼
Orchestrator receives error, handles based on severity:
  ├─ Critical: Log to errors.json, return to user
  ├─ Recoverable: Suggest retry/resume
  └─ Partial: Save progress, enable resume
```

**Error object schema**:
```json
{
  "type": "timeout|validation|execution|tool_unavailable",
  "message": "Human-readable description",
  "code": "ERROR_CODE",
  "recoverable": true,
  "recommendation": "What to do next"
}
```

---

## Delegation Depth Limits

Prevent infinite delegation loops with depth tracking:

| Depth | Layer | Example |
|-------|-------|---------|
| 0 | Orchestrator | User -> Orchestrator |
| 1 | Command/Skill | Orchestrator -> Command -> Skill |
| 2 | Agent | Skill -> Agent |
| 3 | Sub-agent (rare) | Agent -> Utility Agent |

**Maximum depth**: 3 levels (hard limit)

**Enforcement**: Check `delegation_depth < 3` before delegating.

---

## Related Documentation

### User-Facing Documentation
- @.claude/docs/architecture/system-overview.md - Simplified architecture overview for users

### Detailed Patterns
- @.claude/context/core/orchestration/orchestration-core.md - Delegation, routing, session tracking
- @.claude/context/core/orchestration/orchestration-validation.md - Return validation patterns
- @.claude/context/core/orchestration/architecture.md - Three-layer detailed explanation

### Templates
- @.claude/context/core/patterns/thin-wrapper-skill.md - Skill delegation pattern
- @.claude/context/core/templates/subagent-template.md - Agent template
- @.claude/context/core/templates/command-template.md - Command template

### Return Formats
- @.claude/context/core/formats/subagent-return.md - Agent return schema
- @.claude/context/core/formats/return-metadata-file.md - File-based return pattern

### Anti-Patterns
- @.claude/context/core/patterns/anti-stop-patterns.md - Patterns that cause workflow early stop
