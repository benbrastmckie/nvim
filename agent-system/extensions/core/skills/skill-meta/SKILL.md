---
name: skill-meta
description: Interactive system builder. Invoke for /meta command to create tasks for .claude/ system changes.
allowed-tools: Agent, AskUserQuestion, Bash, Edit, Read, Write
agent: meta-builder-agent
---

# Meta Skill

Thin wrapper that delegates system building to `meta-builder-agent` subagent. This skill handles all three modes of /meta: interactive interview, prompt analysis, and system analysis.

**IMPORTANT**: This skill implements the skill-internal postflight pattern. After the subagent returns,
this skill handles all postflight operations (git commit if tasks created) before returning.
This eliminates the "continue" prompt issue between skill return and orchestrator.

## Context References

Reference (do not load eagerly):
- Path: `.claude/context/formats/return-metadata-file.md` - Metadata file schema
- Path: `.claude/context/patterns/postflight-control.md` - Marker file protocol
- Path: `.claude/context/patterns/file-metadata-exchange.md` - File I/O helpers

Note: This skill is a thin wrapper with internal postflight. Context is loaded by the delegated agent.

## Trigger Conditions

This skill activates when:
- /meta command is invoked (with any arguments)
- User requests system building or task creation for .claude/ changes
- System analysis is requested (--analyze flag)

---

## Anti-Bypass Constraint

**PROHIBITION**: This skill and its delegated agent (meta-builder-agent) MUST NOT write to `.claude/` paths using Write or Edit tools. The /meta workflow creates TASKS only. All `.claude/` file modifications happen through the /implement lifecycle with proper skill delegation.

**Detected by**: PostToolUse hook `validate-meta-write.sh` provides corrective context if bypass is attempted.

**Legitimate writes**: Only `specs/` paths (TODO.md, state.json, task directories) are valid write targets for this skill chain.

---

## Execution

### 1. Input Validation

Validate and classify mode from arguments:

**Mode Detection Logic**:
```bash
# Parse arguments
args="$ARGUMENTS"

# Target resolution: global-by-default, --local is the only opt-out, no interactive prompt.
# Note: parse-command-args.sh is NOT sourced here — its Step 6 task-number validation gate
# hard-fails on /meta's free-form argument grammar (/meta takes a prompt, never N[,N-N]).
# This standalone check is a deliberate, same-shaped parallel to that script's --local handling
# (LOCAL_FLAG regex-match + sed-strip convention), not a redundant reimplementation of it.
GLOBAL_ROOT="${CLAUDE_AGENT_GLOBAL_ROOT:-$HOME/.config/nvim}"
local_mode="false"
if [[ "$args" =~ --local ]]; then
  local_mode="true"
fi
args=$(echo "$args" | sed 's/--local//g' | xargs)

# Determine mode (classified AFTER --local is stripped, so `/meta --local` does not
# mis-classify as mode=prompt with prompt="--local")
if [ -z "$args" ]; then
  mode="interactive"
elif [ "$args" = "--analyze" ]; then
  mode="analyze"
else
  mode="prompt"
  prompt="$args"
fi

# Resolve target_root from local_mode. This is a genuine no-op when invoked from within
# $GLOBAL_ROOT — the same code path runs and resolves to the same repo; there is no
# special-casing branch for "already at the global root".
if [ "$local_mode" = "true" ]; then
  target_root="$(git rev-parse --show-toplevel)"
  mode_target="local"
else
  target_root="$GLOBAL_ROOT"
  mode_target="global"
fi
```

No task_number validation needed - /meta creates new tasks rather than operating on existing ones.

### 2. Run the Interview (Pre-Delegation — `AskUserQuestion` Runs Here)

**Why this stage exists here and not in the dispatched agent**: `AskUserQuestion` is measured
categorically withheld from every `Agent`-tool dispatch of a named `subagent_type`, independent
of frontmatter — see `agent-frontmatter-standard.md`'s "Tool Withholding from Dispatched
Subagents" section. Every user-choice point this command needs must therefore be collected in
*this skill's own execution*, before Section 4 dispatches `meta-builder-agent`, exactly as
`skill-slide-planning`/`skill-slide-critic` already do for their own interactive stages.

Read `agent-system/extensions/core/context/workflows/meta-interview.md` and execute it inline, in
this skill's own execution context, selecting the branch for the resolved `mode`:

- **`mode=interactive`**: execute the workflow file's "Interactive Mode: Interview Stages 0-5"
  section in full, using `AskUserQuestion` for every question it specifies. Preserve every
  load-bearing constraint stated there verbatim — the topic-picker stage has no Skip option, the
  Stage 5 `ReviewAndConfirm` confirmation gate is mandatory, and a dependency-validation failure
  re-prompts rather than proceeding. If the user cancels at the confirmation gate, stop here and
  return the "User Cancelled" shape below — do not dispatch the agent.
- **`mode=prompt`**: execute the workflow file's "Prompt Mode: Clarification and Confirmation"
  section (Steps 1-5) in full, using `AskUserQuestion` for Step 4's clarification (when the
  prompt is ambiguous) and Step 5's confirmation. If the user cancels at Step 5, stop here and
  return the "User Cancelled" shape below.
- **`mode=analyze`**: no-op — this stage collects nothing and Section 3 carries no collected
  answers forward.

Hold every answer collected here (the resolved `task_list[]`, `dependency_map{}`,
`external_dependencies{}`, `file_scope` per task, the confirmed/clarified breakdown for prompt
mode, and the user's final confirmation) for Section 3's delegation context. The dispatched agent
performs no further asking — it receives these answers already resolved and proceeds directly to
task-writing (Interview Stage 6 `CreateTasks`) and summary delivery (Stage 7 `DeliverSummary`).

### 3. Context Preparation

Prepare delegation context:

```json
{
  "session_id": "sess_{timestamp}_{random}",
  "delegation_depth": 1,
  "delegation_path": ["orchestrator", "meta", "skill-meta"],
  "timeout": 7200,
  "mode": "interactive|prompt|analyze",
  "prompt": "{user prompt if mode=prompt, null otherwise}",
  "mode_target": "global|local",
  "target_root": "{resolved absolute path — $GLOBAL_ROOT in global mode, current repo root in local mode}",
  "collected_answers": {
    "task_list": "[] — populated for interactive/prompt modes by Section 2; empty/omitted for analyze",
    "dependency_map": "{} — internal task index -> [dependency indices], from Section 2",
    "external_dependencies": "{} — internal task index -> [existing task numbers], from Section 2",
    "file_scope_per_task": "{} — Component 4a footprint capture, from Section 2",
    "confirmed": "true — Section 2 only reaches delegation after the user confirmed at ReviewAndConfirm (interactive) or Step 5 (prompt); analyze mode omits this field entirely"
  }
}
```

### 4. Invoke Subagent

**CRITICAL**: You MUST use the **Agent** tool to spawn the subagent.

The `agent` field in this skill's frontmatter specifies the target: `meta-builder-agent`

**Required Tool Invocation**:
```
Tool: Agent (NOT Skill, NOT Plan)
Parameters:
  - subagent_type: "meta-builder-agent"
  - prompt: [Include mode, prompt if provided, delegation_context (with mode_target/target_root),
             AND the path-qualification imperative below]
  - description: "Execute meta building in {mode} mode"
```

**DO NOT** use `Skill(meta-builder-agent)` - this will FAIL.
Agents live in `.claude/agents/`, not `.claude/skills/`.
The Skill tool can only invoke skills from `.claude/skills/`.

**REQUIRED path-qualification imperative in the Agent-tool prompt**: because Write/Edit tool path
resolution is completely independent of shell cwd (no `cd` in any Bash call affects it), the prompt
sent to `meta-builder-agent` MUST include an explicit, unambiguous instruction that every
task-directory Write/Edit path be qualified by `target_root` (or be an absolute path) — NEVER a
bare `specs/...` relative path. For example: "All task-directory paths (TODO.md, state.json, task
dirs) MUST be written as `{target_root}/specs/...`, never as a bare `specs/...` relative path."
This instruction is carried by the prompt today; a dependent follow-up task makes it durable in the
agent definition itself (`meta-builder-agent.md`) rather than relying on prompt text alone.

The subagent will:
- Load component guides on-demand based on mode
- Execute mode-specific workflow, consuming the `collected_answers` Section 2 already gathered —
  the agent asks nothing itself:
  - **Interactive/Prompt**: Decide on the already-confirmed breakdown (topological sort, task
    number assignment) and write task entries
  - **Analyze**: Inventory existing components and provide recommendations (no interview to
    consume; this mode never reaches Section 2's interview branches)
- Create task entries (TODO.md, state.json, task directories) for non-analyze modes
- Return standardized JSON result

### 5. Return Validation

Validate return matches `return-metadata-file.md` schema:
- Status is one of: completed, partial, failed, blocked
- Summary is non-empty and <100 tokens
- Artifacts array present (task directories for interactive/prompt modes)
- Metadata contains session_id, agent_type, delegation info

### 6. Return Propagation

Return validated result to caller without modification.

---

## Return Format

See `.claude/context/formats/return-metadata-file.md` for full specification.

### Expected Return: Interactive Mode (tasks created)

```json
{
  "status": "tasks_created",
  "summary": "Created 2 tasks for command creation workflow. Tasks start in NOT STARTED status.",
  "artifacts": [
    {
      "type": "task",
      "path": "specs/430_create_export_command/",
      "summary": "Task directory for new command"
    },
    {
      "type": "task",
      "path": "specs/431_export_command_tests/",
      "summary": "Task directory for tests"
    }
  ],
  "metadata": {
    "session_id": "sess_1736700000_abc123",
    "agent_type": "meta-builder-agent",
    "delegation_depth": 1,
    "delegation_path": ["orchestrator", "meta", "meta-builder-agent"],
    "mode": "interactive",
    "tasks_created": 2,
    "tasks_status": "not_started"
  },
  "next_steps": "Run /research 430 to begin research on first task"
}
```

**Note**: Tasks created via `/meta` start in NOT STARTED status. Run `/research N` to begin the standard research -> plan -> implement lifecycle.

### Expected Return: Analyze Mode (read-only)

```json
{
  "status": "analyzed",
  "summary": "System analysis complete. Found 9 commands, 9 skills, 6 agents, and 15 active tasks.",
  "artifacts": [],
  "metadata": {
    "session_id": "sess_1736700000_xyz789",
    "agent_type": "meta-builder-agent",
    "delegation_depth": 1,
    "delegation_path": ["orchestrator", "meta", "meta-builder-agent"],
    "mode": "analyze",
    "component_counts": {
      "commands": 9,
      "skills": 9,
      "agents": 6,
      "active_tasks": 15
    }
  },
  "next_steps": "Review analysis and run /meta to create tasks if needed"
}
```

### Expected Return: User Cancelled

```json
{
  "status": "cancelled",
  "summary": "User cancelled task creation at confirmation stage. No tasks created.",
  "artifacts": [],
  "metadata": {
    "session_id": "sess_1736700000_def456",
    "agent_type": "meta-builder-agent",
    "delegation_depth": 1,
    "delegation_path": ["orchestrator", "meta", "meta-builder-agent"],
    "mode": "interactive",
    "cancelled": true
  },
  "next_steps": "Run /meta again when ready to create tasks"
}
```

---

## Error Handling

### Input Validation Errors
Return immediately with failed status if arguments are malformed.

### Subagent Errors
Pass through the subagent's error return verbatim.

### User Cancellation
Return completed status (not failed) when user explicitly cancels at confirmation stage.

### Timeout
Return partial status if subagent times out (default 7200s for interactive sessions).

---

## MUST NOT (Postflight Boundary)

After the agent returns, this skill MUST NOT:

1. **Edit .claude/ files** - All system building is done by agent
2. **Create task directories** - Task creation is done by agent
3. **Run analysis commands** - Analysis is agent work
4. **Write documentation** - Artifact creation is agent work
5. **Use AskUserQuestion** - this boundary is scoped to **after the agent returns**, not to the
   whole skill. Section 2 (pre-delegation) legitimately calls `AskUserQuestion` — that is the
   entire point of this skill's restructuring, since the dispatched agent cannot call it at all.
   Once the agent has been dispatched and returned, no further user interaction is valid; the
   postflight phase below is read-and-commit only.

The postflight phase is LIMITED TO:
- Reading agent return
- Git commit (if tasks were created)

### Postflight Git Commit

If the agent return indicates tasks were created, commit at `target_root` (resolved in Section 1)
via `.claude/scripts/git-commit-scoped.sh`, the single sanctioned implementation of path-scoped,
mutex-serialized committing. Invoke the script at `target_root`'s own path so it derives
`PROJECT_ROOT` (and therefore `cd`s) from `GLOBAL_ROOT`/`target_root` rather than the current
repo — no separate `cd` is needed:

```bash
GLOBAL_ROOT="${CLAUDE_AGENT_GLOBAL_ROOT:-$HOME/.config/nvim}"
bash "${GLOBAL_ROOT}/.claude/scripts/git-commit-scoped.sh" \
  --message "task {N}: create {title}" \
  --session "${session_id}" \
  --honest-index-rows {N} \
  -- specs/TODO.md specs/state.json
```

In local mode, the identical block runs with `target_root` (the current repo root) substituted
for `$GLOBAL_ROOT` — this is the same code path, not a separate branch; when the current repo
already IS `$GLOBAL_ROOT`, both modes resolve to an identical commit target (the no-op case).

Reference: @.claude/context/standards/postflight-tool-restrictions.md
