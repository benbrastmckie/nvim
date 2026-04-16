# Research Report: Task #442

**Task**: 442 - optimize_token_usage_model_routing
**Started**: 2026-04-15T00:00:00Z
**Completed**: 2026-04-15T00:30:00Z
**Effort**: 1 hour
**Dependencies**: None
**Sources/Inputs**:
- `.claude/agents/*.md` - Agent frontmatter declarations
- `.claude/commands/research.md` - Research command implementation
- `.claude/commands/implement.md` - Implement command implementation
- `.claude/skills/skill-researcher/SKILL.md` - Researcher skill
- `.claude/skills/skill-implementer/SKILL.md` - Implementer skill
- `.claude/skills/skill-team-research/SKILL.md` - Team research skill
- `.claude/skills/skill-team-plan/SKILL.md` - Team plan skill
- `.claude/extensions/lean/manifest.json` - Lean extension routing
- `.claude/extensions/lean/agents/lean-research-agent.md` - Lean research agent
- `.claude/extensions/lean/agents/lean-implementation-agent.md` - Lean implementation agent
- `.claude/extensions/lean/skills/skill-lean-research/SKILL.md` - Lean research skill
- `.claude/extensions/lean/skills/skill-lean-implementation/SKILL.md` - Lean implementation skill
- `.claude/docs/reference/standards/agent-frontmatter-standard.md` - Frontmatter standard
- `.claude/CLAUDE.md` - Skill-to-agent mapping table
**Artifacts**:
- `specs/442_optimize_token_usage_model_routing/reports/01_model-routing-research.md`
**Standards**: status-markers.md, artifact-management.md, tasks.md, report-format.md

---

## Executive Summary

- All commands (research.md, implement.md, plan.md, etc.) currently declare `model: opus` in their frontmatter, making every command execution use Opus.
- All core agents (general-research-agent, general-implementation-agent, planner-agent, meta-builder-agent, code-reviewer-agent, reviser-agent, spawn-agent) declare `model: opus` in frontmatter.
- Lean extension agents (lean-research-agent, lean-implementation-agent) also declare `model: opus`.
- Flag parsing in `/research` and `/implement` is handled in STAGE 1.5 via regex pattern matching on remaining args; adding `--fast`, `--hard`, and `--opus` flags follows the same pattern as existing `--team`/`--team-size`/`--force` flags.
- The `model:` frontmatter field in agent files is respected by Claude Code's Task tool; changing it to `sonnet` will route those agents to Sonnet unless overridden.
- Team mode skills (`skill-team-research`, `skill-team-plan`) already use `model: "sonnet"` explicitly in their TeammateTool invocations, establishing precedent for the sonnet-first pattern.

---

## Context & Scope

The task requires:
1. Changing default model from Opus to Sonnet for all non-Lean agents and commands
2. Preserving Opus for Lean research and implementation tasks
3. Adding `--fast` flag (low-effort/cheap: Haiku or Sonnet) to `/research` and `/implement`
4. Adding `--hard` flag (high-effort: Opus) to `/research` and `/implement`
5. Adding `--opus` flag as explicit Opus designator for `/research` and `/implement`

The agent system spans three layers: commands (`.claude/commands/`), skills (`.claude/skills/`), and agents (`.claude/agents/`). Model selection operates at all three layers.

---

## Findings

### Current Model Routing

#### Commands (`.claude/commands/*.md`)

Every command file has `model: opus` in frontmatter:

| Command | Current Model |
|---------|--------------|
| `research.md` | `opus` |
| `implement.md` | `opus` |
| `plan.md` | `opus` |
| `task.md` | `opus` |
| `meta.md` | `opus` |
| `review.md` | `opus` |
| `revise.md` | `opus` |
| `spawn.md` | `opus` |
| `merge.md` | `opus` |
| `refresh.md` | `opus` |
| `errors.md` | `opus` |
| `todo.md` | `opus` |
| `fix-it.md` | `opus` |
| `tag.md` | `opus` |

Commands execute as the "orchestrator" layer. They parse arguments, validate state, and delegate to skills/agents. For commands that are thin orchestrators (most of them), Sonnet is sufficient.

#### Core Agents (`.claude/agents/*.md`)

All core agents currently declare `model: opus`:

| Agent | Current Model | Recommended Model |
|-------|--------------|-------------------|
| `general-research-agent` | `opus` | `sonnet` |
| `general-implementation-agent` | `opus` | `sonnet` |
| `planner-agent` | `opus` | `sonnet` |
| `meta-builder-agent` | `opus` | `sonnet` |
| `code-reviewer-agent` | `opus` | `sonnet` |
| `reviser-agent` | `opus` | `sonnet` |
| `spawn-agent` | `opus` | `sonnet` |

Per the agent-frontmatter-standard.md, the `model:` field in frontmatter is used by the Task tool when spawning agents. Changing to `sonnet` will route those agents to Sonnet.

#### Lean Extension Agents (`.claude/extensions/lean/agents/`)

Both Lean agents declare `model: opus`:

| Agent | Current Model | Recommended Model |
|-------|--------------|-------------------|
| `lean-research-agent` | `opus` | `opus` (preserve) |
| `lean-implementation-agent` | `opus` | `opus` (preserve) |

These should remain on Opus per the task requirements (Lean tasks require deep mathematical reasoning).

#### Skills

Core skills (`.claude/skills/`) do NOT have `model:` frontmatter - they are skill wrappers that invoke agents via the Task tool. Model selection happens at the agent level (via `subagent_type` frontmatter) not at the skill level.

Exception: Team mode skills (`skill-team-research`, `skill-team-plan`) pass `model: "sonnet"` explicitly as a parameter to the TeammateTool invocation. This is a separate pattern from frontmatter-based routing.

Lean skills (`.claude/extensions/lean/skills/`) also do NOT have model frontmatter - they delegate model selection to the lean agents.

### Current Flag Parsing

Flag parsing in commands occurs in **STAGE 1.5: PARSE FLAGS** in both `/research` and `/implement`.

#### `/research` STAGE 1.5 Pattern

```bash
# Recognized flags:
--team          -> team_mode = true
--team-size N   -> team_size = N (clamp 2-4)

# Remaining text after flags removed = focus_prompt
```

#### `/implement` STAGE 1.5 Pattern

```bash
# Recognized flags:
--team          -> team_mode = true
--team-size N   -> team_size = N (clamp 2-4)
--force         -> force_mode = true

# Flag removal: each recognized flag stripped from remaining_args
```

Both commands use the same structural pattern:
1. Parse task numbers from the beginning of the argument string (regex: `^([0-9][0-9,\ \-]*)`)
2. Remaining args after task numbers are flags/focus
3. STAGE 1.5 strips recognized flags from remaining, leaving `focus_prompt`

Adding `--fast`, `--hard`, and `--opus` follows the identical pattern with new variables.

### Lean4 Extension Routing

The lean extension (`manifest.json`) defines routing:

```json
"routing": {
  "research": {
    "lean4": "skill-lean-research",
    "lean4:lake": "skill-lake-repair",
    "lean4:version": "skill-lean-version"
  },
  "implement": {
    "lean4": "skill-lean-implementation",
    "lean4:lake": "skill-lake-repair",
    "lean4:version": "skill-lean-version"
  }
}
```

When a task has `task_type: "lean4"`, the `/research` and `/implement` commands route to lean-specific skills (`skill-lean-research`, `skill-lean-implementation`) instead of the default `skill-researcher`/`skill-implementer`. These skills invoke `lean-research-agent` and `lean-implementation-agent` respectively, both of which declare `model: opus`.

This means Lean tasks automatically get Opus through the existing agent frontmatter - no special handling is needed for Lean when changing other agents to Sonnet.

### Agent Frontmatter Standard

From `.claude/docs/reference/standards/agent-frontmatter-standard.md`:

- `model:` is an optional field in agent frontmatter
- Valid values: `opus`, `sonnet`
- The Task tool respects this field when spawning agents
- Recommended usage:
  - `opus`: Complex reasoning, research, planning, mathematical/logical tasks
  - `sonnet`: Implementation, code generation, routine tasks
  - Omit: Default behavior / model flexibility

The standard explicitly recommends Sonnet for "routine code generation tasks" and "tasks where speed is prioritized over depth."

### CLAUDE.md Skill-to-Agent Mapping

The current mapping in `.claude/CLAUDE.md` shows:

| Skill | Agent | Model |
|-------|-------|-------|
| skill-researcher | general-research-agent | opus |
| skill-planner | planner-agent | opus |
| skill-implementer | general-implementation-agent | - (no model listed) |
| skill-team-research | (team orchestration) | sonnet |
| skill-team-plan | (team orchestration) | sonnet |
| skill-team-implement | (team orchestration) | sonnet |

Notably, `skill-implementer` already shows no model in the CLAUDE.md mapping table, suggesting implementation was already considered a candidate for non-Opus execution. Team skills already use Sonnet.

### Model Parameter Passing

The Task tool accepts a `subagent_type` parameter that maps to agent frontmatter. The `model:` field in agent frontmatter is used by Claude Code to select the model when spawning that agent. There is no separate "model override" parameter documented in the skills - the model is set at the agent definition level.

For `--opus`, `--fast`, `--hard` flag implementation, the approach must be:
1. The command parses the flag from arguments
2. Passes a `model_override` (or similar) field in the delegation context JSON
3. The skill reads this field and either selects a different agent or modifies how it invokes the Task tool

**Key constraint**: Since model selection happens at the agent level (frontmatter), runtime model overrides require either:
- A separate agent variant (e.g., `general-research-agent-sonnet`) - not ideal
- The skill selecting different agents based on context - adds complexity
- Direct use of `model` parameter in Task tool invocation if Claude Code supports runtime override - this is the cleanest approach

The skill-team-research SKILL.md documents passing `model: "sonnet"` as a parameter to TeammateTool, establishing that runtime model selection IS possible through tool parameters. The same approach should work for the Task tool.

---

## Decisions

1. **Primary change location**: Agent frontmatter files should change from `model: opus` to `model: sonnet` for non-Lean agents. This is the most impactful single change.
2. **Command model**: Commands can change from `model: opus` to `model: sonnet` for lightweight orchestrators. This changes only the command executor's model, not the subagent.
3. **Flag implementation**: `--fast`, `--hard`, `--opus` flags should be parsed in STAGE 1.5 of both `/research` and `/implement` commands, then passed in delegation context to skills which can use them for model selection.
4. **Lean preservation**: No changes needed to lean agents or lean skills - they retain `model: opus`.
5. **CLAUDE.md update**: The skill-to-agent mapping table should be updated to reflect new model assignments.

---

## Recommendations

### Priority 1: Change Agent Frontmatter (Highest Impact)

Change `model: opus` to `model: sonnet` in:
- `/home/benjamin/.config/nvim/.claude/agents/general-research-agent.md`
- `/home/benjamin/.config/nvim/.claude/agents/general-implementation-agent.md`
- `/home/benjamin/.config/nvim/.claude/agents/planner-agent.md`
- `/home/benjamin/.config/nvim/.claude/agents/meta-builder-agent.md`
- `/home/benjamin/.config/nvim/.claude/agents/code-reviewer-agent.md`
- `/home/benjamin/.config/nvim/.claude/agents/reviser-agent.md`
- `/home/benjamin/.config/nvim/.claude/agents/spawn-agent.md`

**Do NOT change**:
- `.claude/extensions/lean/agents/lean-research-agent.md` (keep `model: opus`)
- `.claude/extensions/lean/agents/lean-implementation-agent.md` (keep `model: opus`)

### Priority 2: Change Command Frontmatter

Change `model: opus` to `model: sonnet` in most commands. Commands are lightweight orchestrators that parse arguments and delegate to skills. Notable exception: `/meta` command invokes `meta-builder-agent` which does complex interactive work - could stay on Sonnet since the agent itself will be Sonnet.

Files to change: `research.md`, `implement.md`, `plan.md`, `task.md`, `meta.md`, `review.md`, `revise.md`, `spawn.md`, `merge.md`, `refresh.md`, `errors.md`, `todo.md`, `fix-it.md`.

Keep `tag.md` as-is (it's a user-only command for deployment).

### Priority 3: Add --fast, --hard, --opus Flags

**In `/research` STAGE 1.5**:
```bash
# New flags to parse:
--fast   -> model_flag = "fast"   # Use Sonnet (explicit low-cost)
--hard   -> model_flag = "hard"   # Use Opus (explicit high-effort)
--opus   -> model_flag = "opus"   # Use Opus (explicit)
```

**In `/implement` STAGE 1.5** (same pattern):
```bash
--fast   -> model_flag = "fast"
--hard   -> model_flag = "hard"
--opus   -> model_flag = "opus"
```

Pass the `model_flag` in the delegation context:
```json
{
  "model_flag": "fast|hard|opus|null"
}
```

**In skills** (`skill-researcher`, `skill-implementer`): Read `model_flag` from delegation context and include it in the delegation context passed to the subagent. The subagent (agent) uses this to inform its behavior or log the preference.

**Agent-level enforcement**: Since runtime model override via Task tool parameters is possible (as evidenced by team skills using `model: "sonnet"` in TeammateTool), the skills can pass model overrides to the Task tool invocation when `model_flag` is set.

### Priority 4: Update CLAUDE.md Mapping Table

Update the skill-to-agent mapping in `.claude/CLAUDE.md` to reflect new Sonnet defaults and document the flag-based override mechanism.

### Priority 5: Update Agent Frontmatter Standard

Update `.claude/docs/reference/standards/agent-frontmatter-standard.md` to note that:
- Default for non-Lean agents is now Sonnet
- Lean agents retain Opus
- `--opus` flag can override to Opus at runtime

---

## Risks & Mitigations

| Risk | Severity | Mitigation |
|------|----------|------------|
| Sonnet produces lower quality research/planning output | Medium | Monitor quality; --hard/--opus flags allow Opus when needed |
| Lean tasks accidentally get Sonnet via flag parsing | Low | Lean routing bypasses default skill entirely; flags only affect default skill behavior |
| CLAUDE.md documentation becomes stale | Low | Update CLAUDE.md in same PR as agent changes |
| Other extensions (python, formal, z3) may have custom agents | Low | Check extension agent frontmatter before finalizing |
| `--fast` flag: no "haiku" value documented in frontmatter standard | Medium | Frontmatter standard only lists "opus" and "sonnet"; haiku may not be available as a frontmatter value. `--fast` should map to sonnet (already default), not haiku |

---

## Appendix

### Files Requiring Changes (Summary)

**Agent files to change `model: opus` -> `model: sonnet`**:
- `.claude/agents/general-research-agent.md`
- `.claude/agents/general-implementation-agent.md`
- `.claude/agents/planner-agent.md`
- `.claude/agents/meta-builder-agent.md`
- `.claude/agents/code-reviewer-agent.md`
- `.claude/agents/reviser-agent.md`
- `.claude/agents/spawn-agent.md`

**Agent files to leave unchanged**:
- `.claude/extensions/lean/agents/lean-research-agent.md` (opus, preserve)
- `.claude/extensions/lean/agents/lean-implementation-agent.md` (opus, preserve)

**Command files to change `model: opus` -> `model: sonnet`**:
All `.claude/commands/*.md` except `tag.md`

**Commands to add flag parsing**:
- `.claude/commands/research.md` (STAGE 1.5)
- `.claude/commands/implement.md` (STAGE 1.5)

**Skills to add model_flag forwarding**:
- `.claude/skills/skill-researcher/SKILL.md`
- `.claude/skills/skill-implementer/SKILL.md`

**Documentation to update**:
- `.claude/CLAUDE.md` (skill-to-agent mapping table)
- `.claude/docs/reference/standards/agent-frontmatter-standard.md`

### Haiku Availability Note

The agent frontmatter standard documents only `opus` and `sonnet` as valid values. The `--fast` flag should map to `sonnet` (which becomes the default anyway) rather than requiring a new `haiku` value. If Haiku support is desired, the frontmatter standard would need to be extended.

### Current Flag Parsing Pseudocode (For Reference)

From `/research` STAGE 1.5:
```bash
# Extract team options
if remaining_args contains "--team": team_mode = true
if remaining_args contains "--team-size N": team_size = N

# Remove recognized flags
focus_prompt = remaining_args minus "--team" minus "--team-size N"
```

New flags would extend this:
```bash
# NEW: Extract model flags
if remaining_args contains "--fast": model_flag = "fast"
if remaining_args contains "--hard": model_flag = "hard"
if remaining_args contains "--opus": model_flag = "opus"
else: model_flag = null  # Use agent default

# Remove from focus_prompt
focus_prompt = remaining_args minus all recognized flags
```
