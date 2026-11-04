# Creating Skills Guide

This guide explains how to create new skills in the agent system using the thin wrapper pattern.

---

## Overview

Skills are specialized execution components that:
- Validate inputs before delegating to agents
- Route to appropriate agents based on task context
- Prepare delegation context for agents
- Validate and propagate agent returns

Skills use the **thin wrapper pattern** - they do minimal work themselves and delegate execution to agents.

---

## Thin Wrapper Pattern

### What It Is

Skills are "thin wrappers" that delegate to agents via the Agent tool. This pattern provides:

- **Token Efficiency**: Context loaded only in the agent's conversation
- **Isolation**: Agent context does not bloat the skill's conversation
- **Reusability**: Same agent can be invoked from multiple skills
- **Maintainability**: Skills handle routing, agents handle execution

### What Skills Do

```
Skill receives invocation
    |
    v
1. Validate inputs (task exists, status allows operation)
    |
    v
2. Prepare delegation context (session_id, task info)
    |
    v
3. Invoke agent via Agent tool
    |
    v
4. Validate agent return matches schema
    |
    v
5. Propagate return to caller
```

### What Skills Do NOT Do

- Load heavy context files (agent does this)
- Execute business logic (agent does this)
- Create artifacts (agent does this)
- Handle complex error recovery (agent does this)

---

## Skill File Structure

Skills are located in `.claude/skills/skill-{name}/SKILL.md`:

```
.claude/skills/
├── skill-reviser/
│   └── SKILL.md
├── skill-lean-research/
│   └── SKILL.md
├── skill-spawn/
│   └── SKILL.md
└── skill-meta/
    └── SKILL.md
```

---

## Using skill-base.sh in Extension Skills

Extension skills (in `.claude/extensions/*/skills/`) should be **thin wrappers** under ~110 lines. They delegate lifecycle management to `skill-base.sh` and focus on:
1. Domain-specific context description
2. Correct agent name routing
3. Domain-specific delegation context fields

### What skill-base.sh Provides

`skill-base.sh` at `.claude/scripts/skill-base.sh` exports shared lifecycle functions:

| Function | Stage | Purpose |
|----------|-------|---------|
| `skill_validate_input()` | 1 | Validate task number, export TASK_TYPE, TASK_DIR |
| `skill_preflight_update()` | 2 | Update status to "in_progress" + run `preflight` hook |
| `skill_create_postflight_marker()` | 3 | Write `.postflight-pending` marker file |
| `skill_context_injection()` | 4 | Run `context_injection` extension hook |
| `skill_read_artifact_number()` | 3a | Read/compute artifact sequence number |
| `skill_read_metadata()` | 6 | Read `.return-meta.json` from agent |
| `skill_validate_artifact()` | 6a | Validate artifact format + run `verification` hook |
| `skill_postflight_update()` | 7 | Update status to completed + run `postflight` hook |
| `skill_link_artifacts()` | 8 | Link artifact in state.json and TODO.md |
| `skill_cleanup()` | 9/10 | Remove marker files |

### Before (Fat Extension Skill - 412 lines)

```markdown
---
name: skill-nix-implementation
...
---

### Stage 1: Input Validation

Validate required inputs:
- task_number - Must be provided and exist in state.json

bash
task_data=$(jq -r --argjson num "$task_number" ...)
if [ -z "$task_data" ]; then
  return error "Task $task_number not found"
fi
...

### Stage 2: Preflight Status Update

Update task status to "implementing" BEFORE invoking subagent.

bash
bash .claude/scripts/state-write.sh '...' --session-id "$session_id" --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" ...

### Stage 3: Create Postflight Marker
... (40+ lines) ...

### Stage 5: Postflight Status Update
... (50+ lines) ...
```

### After (Thin Extension Skill - ~104 lines)

```markdown
---
name: skill-nix-implementation
description: Implement Nix configuration changes from plans. Invoke for nix implementation tasks.
allowed-tools: Agent, Bash, Edit, Read, Write
---

# Nix Implementation Skill

Thin wrapper that delegates Nix configuration implementation to `nix-implementation-agent` subagent.

## Trigger Conditions

This skill activates when task type is "nix".

## Execution Flow

### Stage 1: Input Validation
Validate task_number exists, task_type is "nix", and an implementation plan is present.

### Stage 2: Preflight Status Update
Update status to "implementing" BEFORE invoking subagent.

### Stage 3: Prepare Delegation Context

Domain-specific context for the nix-implementation-agent:
- Nix style guide from context/
- MCP-NixOS for package/option validation (when available)
- Verification: nix flake check, nixos-rebuild build

{delegation context JSON example}

### Stage 4: Invoke Subagent
Use Agent tool with subagent_type: "nix-implementation-agent".

### Stage 4b: Self-Execution Fallback
If no Agent tool, write .return-meta.json before postflight.

## Postflight (ALWAYS EXECUTE)

### Stage 5: Parse Subagent Return
Read specs/{N}_{SLUG}/.return-meta.json.

### Stage 6: Update Task Status (Postflight)
Update state.json and TODO.md based on result.

### Stage 7: Link Artifacts
field_name=**Summary**, next_field=**Description**.

### Stage 8: Git Commit

### Stage 9: Return Brief Summary

## MUST NOT (Postflight Boundary)
...

## Return Format
Brief text summary (NOT JSON).
```

### Key Differences

| Aspect | Fat Skill | Thin Skill |
|--------|-----------|------------|
| Lines | 254-412 | 83-104 |
| Lifecycle code | Inlined (jq, bash) | Described (prose) |
| Domain context | Mixed with lifecycle | Isolated in Stage 3 |
| Maintenance | Update each skill | Update skill-base.sh once |

Extension skills describe WHAT to do in prose. The actual execution (jq calls, status updates, file I/O) is handled by skill-base.sh functions which the skills delegate to. This makes skills readable and maintainable without sacrificing correctness.

### Reference Examples

Look at these working thin skills for reference:
- `.claude/extensions/python/skills/skill-python-research/SKILL.md` (62 lines)
- `.claude/extensions/nix/skills/skill-nix-research/SKILL.md` (83 lines)
- `.claude/extensions/nvim/skills/skill-neovim-research/SKILL.md` (83 lines)

---

## Skill Template

There are two skill patterns depending on where the skill lives.

### Pattern A: Core Skills (`.claude/skills/`)

Core skills (skill-reviser, skill-spawn, skill-meta, etc.) use `skill-base.sh` lifecycle functions directly and invoke agents with explicit `subagent_type` to inject structured context:

> **Division of labor note**: this claim was aspirational when first written — at the time, no
> core skill actually called these functions, and each hand-rolled its own preflight/postflight
> logic inline. The conversion that made it true is documented stage-by-stage (which shared
> `@`-import or `skill-base.sh` function implements which numbered stage, and where core skills
> still diverge from that mapping) in `@.claude/context/patterns/skill-lifecycle.md`. This guide
> keeps the function table and authoring walkthrough below; that document owns the Stage-N
> skeleton and shared-block map — check both when one changes.

```yaml
---
name: skill-{name}
description: {Brief description}. Invoke for {use case}.
allowed-tools: Agent, Bash, Edit, Read, Write
---
```

Core skills call `skill-base.sh` functions for lifecycle management:

```markdown
### Stage 1: Input Validation
source .claude/scripts/skill-base.sh
skill_validate_input "$task_number"

### Stage 2: Preflight Status Update
skill_preflight_update "$task_number" "<operation>" "$session_id"

### Stage 3: Create Postflight Marker
skill_create_postflight_marker "$PADDED_NUM" "$PROJECT_NAME" "$session_id" "skill-{name}" "<operation>"

### Stage 4: Invoke Subagent
Use Agent tool with subagent_type: "{agent-name}"

## Postflight (ALWAYS EXECUTE)
### Stage 5: Read Metadata
skill_read_metadata "$PADDED_NUM" "$PROJECT_NAME"

### Stage 6: Update Status
skill_postflight_update "$task_number" "<operation>" "$session_id" "$SUBAGENT_STATUS"

### Stage 7: Link Artifacts
skill_link_artifacts "$task_number" "$ARTIFACT_PATH" "$ARTIFACT_TYPE" "$ARTIFACT_SUMMARY" '**Type**' '**Next**'

### Stage 8: Git Commit + Cleanup
skill_cleanup "$PADDED_NUM" "$PROJECT_NAME"
```

See `skill-reviser`, `skill-spawn`, or `skill-meta` for working examples.

### Pattern B: Extension Skills (`.claude/extensions/*/skills/`)

Extension skills use `context: fork` + `agent:` for simple delegation. The agent loads its own context. These are thin wrappers under ~110 lines that describe WHAT to do in prose (see the "Using skill-base.sh" section above).

```yaml
---
name: skill-{name}
description: {Brief description}. Invoke for {use case}.
allowed-tools: Agent
context: fork
agent: {target-agent-name}
# Original context (now loaded by subagent):
#   - .claude/context/path/to/context.md
---
```

### Frontmatter Fields

| Field | Value | Purpose |
|-------|-------|---------|
| `name` | `skill-{name}` | Skill identifier |
| `description` | Brief text | Helps orchestrator route correctly |
| `allowed-tools` | `Agent` (extension) or `Agent, Bash, ...` (core) | Tools needed for execution |
| `context` | `fork` (extension only) | Signals NOT to load context eagerly |
| `agent` | `{name}-agent` (extension only) | Target agent to invoke |

**Decision Matrix**: Extension skills use `context: fork` + `agent:` for simple delegation. Core skills omit these and call the Agent tool with explicit `subagent_type` to inject structured context (session_id, delegation_depth, memory_context). See [fork-patterns.md](../fork-patterns.md) for the full matrix.

### Body Structure (Extension Skills)

```markdown
# {Name} Skill

{One-line description explaining what this skill does.}

## Trigger Conditions

This skill activates when:
- {Condition 1}

## Execution Flow

### Stage 1: Input Validation
skill_validate_input "$task_number"

### Stage 2: Preflight Status Update
skill_preflight_update "$task_number" "<operation>" "$session_id"

### Stage 3: Prepare Delegation Context
{Domain-specific context description}

### Stage 4: Invoke Subagent
Use Agent tool with subagent_type: "{agent-name}".

## Postflight (ALWAYS EXECUTE)
{Stages 5-9 using skill-base.sh functions}

## MUST NOT (Postflight Boundary)
{Reference to postflight-tool-restrictions.md}
```

---

## Step-by-Step Guide

This guide covers creating an **extension skill** (the most common case). For core skills, follow the same structure but use `skill-base.sh` functions directly (see Pattern A above).

### Step 1: Create Skill Directory

```bash
mkdir -p .claude/extensions/{ext}/skills/skill-{name}
```

### Step 2: Create SKILL.md

Create `SKILL.md` with frontmatter:

```yaml
---
name: skill-{name}
description: {Description}. Invoke for {use case}.
allowed-tools: Agent
context: fork
agent: {agent-name}
---
```

### Step 3: Define Trigger Conditions

Specify when this skill should be used:

```markdown
## Trigger Conditions

This skill activates when:
- Task type is "{domain}"
- {Domain}-specific research/implementation is needed
```

### Step 4: Define Execution Flow with skill-base.sh

Use `skill-base.sh` lifecycle functions for all stages. The skill only needs to describe domain-specific context and agent selection:

```markdown
### Stage 1: Input Validation
source .claude/scripts/skill-base.sh
skill_validate_input "$task_number"
# Exports: TASK_TYPE, TASK_STATUS, PROJECT_NAME, DESCRIPTION, PADDED_NUM, TASK_DIR

### Stage 2: Preflight Status Update
skill_preflight_update "$task_number" "<operation>" "$session_id"

### Stage 3: Prepare Delegation Context
{Domain-specific context: tools, search strategies, verification commands}

### Stage 4: Invoke Subagent
Use Agent tool with subagent_type: "{agent-name}".
```

### Step 5: Define Postflight with skill-base.sh

```markdown
## Postflight (ALWAYS EXECUTE)

### Stage 5: Read Metadata
skill_read_metadata "$PADDED_NUM" "$PROJECT_NAME"

### Stage 6: Update Status
skill_postflight_update "$task_number" "<operation>" "$session_id" "$SUBAGENT_STATUS"

### Stage 7: Link Artifacts
skill_link_artifacts "$task_number" "$ARTIFACT_PATH" "$ARTIFACT_TYPE" "$ARTIFACT_SUMMARY" '**Type**' '**Next**'

### Stage 8: Git Commit
# Apply targeted staging per .claude/context/standards/git-staging-scope.md — never a repo-wide
# add — via git-commit-scoped.sh, the single sanctioned implementation of path-scoped,
# mutex-serialized committing
bash .claude/scripts/git-commit-scoped.sh \
  --message "task ${task_number}: ..." \
  --session "${session_id}" \
  --honest-index-rows "${task_number}" \
  -- "specs/${PADDED_NUM}_${PROJECT_NAME}/" "specs/TODO.md" "specs/state.json"

### Stage 9: Cleanup
skill_cleanup "$PADDED_NUM" "$PROJECT_NAME"
```

### Step 6: Add Postflight Boundary and Error Handling

```markdown
## MUST NOT (Postflight Boundary)
After the agent returns, MUST NOT: edit source files, run build/test, use domain tools.
Postflight is LIMITED TO: reading metadata, status updates, artifact linking, git commit, cleanup.
Reference: @.claude/context/standards/postflight-tool-restrictions.md

## Error Handling

### Input Validation Errors
Return immediately with failed status if task not found or status invalid.

### Subagent Errors
Pass through the subagent's error return verbatim.

### Timeout
Return partial status if subagent times out (default 3600s).
```

---

## Complete Example

Here is a complete skill for Rust research:

```yaml
---
name: skill-rust-research
description: Research Rust crates and APIs for implementation tasks. Invoke for Rust-language research.
allowed-tools: Agent
context: fork
agent: rust-research-agent
# Original context (now loaded by subagent):
#   - .claude/context/project/rust/tools.md
# Original tools (now used by subagent):
#   - Read, Write, Glob, Grep, WebSearch, WebFetch
---

# Rust Research Skill

Thin wrapper that delegates Rust research to `rust-research-agent` subagent.

## Trigger Conditions

This skill activates when:
- Task language is "rust"
- Research involves Rust crates, APIs, or frameworks
- Rust-specific tooling documentation is needed

---

## Execution

### 1. Input Validation

Validate required inputs:
- `task_number` - Must be provided and exist in state.json
- `focus_prompt` - Optional focus for research direction

```bash
# Lookup task
task_data=$(jq -r --arg num "$task_number" \
  '.active_projects[] | select(.project_number == ($num | tonumber))' \
  specs/state.json)

# Validate exists
if [ -z "$task_data" ]; then
  return error "Task $task_number not found"
fi
```

### 2. Context Preparation

Prepare delegation context:

```json
{
  "session_id": "sess_{timestamp}_{random}",
  "delegation_depth": 1,
  "delegation_path": ["orchestrator", "research", "skill-rust-research"],
  "timeout": 3600,
  "task_context": {
    "task_number": 450,
    "task_name": "add_async_runtime",
    "description": "Add async runtime support to API client",
    "task_type": "rust"
  },
  "focus_prompt": "tokio best practices"
}
```

### 3. Invoke Subagent

Invoke `rust-research-agent` via Agent tool with:
- Task context (number, name, description, task_type)
- Delegation context (session_id, depth, path)
- Focus prompt (if provided)

The subagent will:
- Search for Rust-specific documentation
- Analyze crate dependencies
- Review tokio patterns and best practices
- Create research report in `specs/{NNN}_{SLUG}/reports/`
- Return standardized JSON result

### 4. Return Validation

Validate return matches `subagent-return.md` schema:
- Status is one of: completed, partial, failed, blocked
- Summary is non-empty and <100 tokens
- Artifacts array present with research report path
- Metadata contains session_id, agent_type, delegation info

### 5. Return Propagation

Return validated result to caller without modification.

---

## Return Format

See `.claude/context/formats/subagent-return.md` for full specification.

Expected successful return:
```json
{
  "status": "completed",
  "summary": "Research completed with 6 findings on tokio patterns",
  "artifacts": [
    {
      "type": "research",
      "path": "specs/450_add_async_runtime/reports/01_tokio-patterns.md",
      "summary": "Rust tokio research report"
    }
  ],
  "metadata": {
    "session_id": "sess_1736700000_abc123",
    "agent_type": "rust-research-agent",
    "delegation_depth": 1,
    "delegation_path": ["orchestrator", "research", "rust-research-agent"]
  },
  "next_steps": "Run /orchestrate 450 to create implementation plan"
}
```

---

## Error Handling

### Input Validation Errors
Return immediately with failed status if task not found.

### Subagent Errors
Pass through the subagent's error return verbatim.

### Timeout
Return partial status if subagent times out (default 3600s).
```

---

## Validation Checklist

Before finalizing a new skill, verify:

### Frontmatter
- [ ] `name` matches directory name
- [ ] `description` is clear and includes "Invoke for" pattern
- [ ] `allowed-tools` is `Agent` (for thin wrapper skills)
- [ ] `context` is `fork` (for lazy loading)
- [ ] `agent` specifies target agent

### Body
- [ ] Trigger conditions are specific and actionable
- [ ] Input validation covers required fields
- [ ] Context preparation includes session_id
- [ ] Agent invocation describes what agent does
- [ ] Return validation references subagent-return.md
- [ ] Error handling covers common cases

### Integration
- [ ] Corresponding agent exists in `.claude/agents/`
- [ ] Skill name follows `skill-{purpose}` pattern
- [ ] No duplicate skills for same use case

---

## Common Mistakes

### 1. Loading Context in Skill

**Wrong**:
```yaml
---
context:
  - .claude/context/patterns/complex-patterns.md
  - .claude/context/project/domain/domain-knowledge.md
---
```

**Right**:
```yaml
---
context: fork
agent: my-agent
# Original context (now loaded by subagent):
#   - .claude/context/patterns/complex-patterns.md
---
```

### 2. Executing Logic in Skill

**Wrong**:
Skill contains 200 lines of research logic, file creation, etc.

**Right**:
Skill validates, prepares context, invokes agent (5 sections total).

### 3. Missing Return Validation

**Wrong**:
Skill blindly returns whatever agent returns.

**Right**:
Skill validates return matches `subagent-return.md` schema before propagating.

### 4. Not Using Agent Tool

**Wrong**:
```yaml
allowed-tools: Read, Write, Bash, WebSearch
```

**Right**:
```yaml
allowed-tools: Agent
```

---

## Related Documentation

- [Component Selection](component-selection.md) - When to create a skill
- [Creating Agents](creating-agents.md) - Creating the agent that skill delegates to
- [Creating Commands](creating-commands.md) - Creating commands that invoke skills
- `.claude/context/patterns/skill-lifecycle.md` - Stage-N skeleton and shared-block map (the
  division-of-labor counterpart to this guide's function table and authoring walkthrough)
- `.claude/context/templates/thin-wrapper-skill.md` - Skill template
- `.claude/context/formats/subagent-return.md` - Return format schema

---

**Document Version**: 1.0
**Created**: 2026-01-12
**Maintained By**: Development Team
