# Research Report: Task #416

**Task**: 416 - enforce_skill_delegation_for_plan_artifacts
**Started**: 2026-04-13T00:00:00Z
**Completed**: 2026-04-13T00:45:00Z
**Effort**: 1-2 hours
**Dependencies**: None
**Sources/Inputs**:
  - Codebase analysis: settings.json hooks, command specs, skill definitions, validate-artifact.sh
  - Claude Code hooks documentation (docs.anthropic.com/en/docs/claude-code/hooks)
  - .memory/ directory structure and README.md
  - ROADMAP.md current priorities
**Artifacts**: - specs/416_enforce_skill_delegation_for_plan_artifacts/reports/01_skill-delegation-enforcement.md
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The bypass occurs because the orchestrator (running the /plan command spec) can read the spec, understand what the planner-agent would do, and write plan files directly -- skipping the Skill('skill-planner') invocation entirely
- Three enforcement mechanisms are viable: (1) a PostToolUse hook on Write/Edit that validates plan artifacts and injects corrective context, (2) strengthened anti-bypass language in command specs, and (3) a local .memory/ feedback entry that agents load at session start
- The PostToolUse hook is the strongest mechanism because it operates outside the model's context -- it cannot be "forgotten" or ignored the way textual instructions can
- A PreToolUse hook could theoretically block writes to plan paths entirely, but this would also block legitimate plan writes from the planner-agent itself, making it impractical without a delegation-depth marker
- The recommended approach is a layered defense: PostToolUse validation hook (primary), command spec hardening (secondary), and .memory/ entry (tertiary)

## Context & Scope

On 2026-04-13, the /plan command for task 414 was executed by the orchestrator, which read the plan.md command spec but bypassed the `Skill('skill-planner')` invocation. Instead, it wrote a plan file directly, producing an artifact missing required metadata fields (Status, Dependencies, Research Inputs, Artifacts, Standards, Type), required sections (Goals & Non-Goals, Testing & Validation, Artifacts & Outputs, Rollback/Contingency), the Dependency Analysis wave table, and proper phase format (Goal/Tasks/Timing/Depends on).

The plan-format-enforcement.md rule (path-scoped to `specs/**/plans/**`) exists but only influences agents that load it. The orchestrator, operating at the command level, may not load this rule or may override it with its own interpretation of the command spec.

This research investigates enforcement mechanisms that work regardless of whether the model "remembers" or "chooses" to follow textual instructions.

## Findings

### 1. Current Enforcement Landscape

**What exists today:**

| Mechanism | File | Scope | Strength |
|-----------|------|-------|----------|
| plan-format-enforcement.md | .claude/rules/plan-format-enforcement.md | Path-scoped rule (specs/**/plans/**) | Weak -- only loaded when agent writes to matching path |
| plan-format.md | .claude/context/formats/plan-format.md | Context file, loaded by agents | Weak -- must be explicitly loaded |
| validate-artifact.sh | .claude/scripts/validate-artifact.sh | Bash script, called by skill-planner Stage 6a | Medium -- validates after write but only if skill-planner runs |
| Format injection in skill-planner | skill-planner SKILL.md Stage 4b | Reads plan-format.md and injects into subagent prompt | Medium -- only works if skill-planner is invoked |

**Key gap:** All enforcement depends on the skill-planner being invoked. If the orchestrator bypasses skill-planner, none of these mechanisms activate.

### 2. PostToolUse Hook (Primary Enforcement)

**Capability confirmed:** PostToolUse hooks can:
- Match on `Write` and `Edit` tool names
- Access `tool_input` (including `file_path` and `content`) via stdin JSON
- Return `additionalContext` to inject corrective messages back to Claude
- Exit with code 2 to surface stderr as a blocking error to Claude

**Proposed hook: validate-plan-artifact.sh**

A PostToolUse hook matching `Write|Edit` that:
1. Checks if the written file path matches `specs/*/plans/*.md`
2. Runs `validate-artifact.sh` against the file
3. If validation fails, returns `additionalContext` warning Claude that the plan artifact violates the format standard and must be rewritten via proper skill delegation

**Design:**

```bash
#!/bin/bash
# .claude/hooks/validate-plan-write.sh
# PostToolUse hook: validates plan artifacts written to specs/*/plans/*.md

INPUT=$(cat)
FILE=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null)

# Only check plan files
if [[ "$FILE" == */specs/*/plans/*.md ]]; then
  RESULT=$(bash .claude/scripts/validate-artifact.sh "$FILE" plan 2>&1)
  EXIT_CODE=$?

  if [ $EXIT_CODE -eq 1 ]; then
    # Validation failed -- inject corrective context
    jq -n --arg ctx "PLAN FORMAT VIOLATION: The plan file at $FILE does not conform to the plan-format.md standard. Validation output: $RESULT. You MUST invoke Skill('skill-planner') to create plan artifacts -- do not write plan files directly. Delete the non-conforming file and re-run the planning workflow through proper skill delegation." \
      '{"hookSpecificOutput": {"hookEventName": "PostToolUse", "additionalContext": $ctx}}'
    exit 0
  fi
fi

echo '{}'
exit 0
```

**settings.json addition:**

```json
{
  "matcher": "Write|Edit",
  "hooks": [
    {
      "type": "command",
      "command": "bash .claude/hooks/validate-plan-write.sh",
      "timeout": 10000
    }
  ]
}
```

**Strengths:**
- Works regardless of which agent or orchestrator writes the file
- Cannot be "forgotten" -- it is infrastructure, not instructions
- Provides corrective feedback that directs Claude to use proper delegation
- Non-destructive -- the file is already written but Claude is told to fix it
- Existing validate-artifact.sh already checks all required metadata and sections

**Weaknesses:**
- Cannot prevent the write (PostToolUse fires after the tool completes)
- Relies on Claude following the corrective context (but this is very reliable in practice)
- Adds ~100ms latency to every Write/Edit of any file (path check is fast, but the hook fires for all Write/Edit calls)

**Note on PreToolUse alternative:** A PreToolUse hook with `permissionDecision: "deny"` could block writes to plan paths entirely. However, this would also block the planner-agent from writing plans. There is no built-in way for a hook to distinguish "orchestrator writing directly" from "planner-agent writing legitimately" -- both use the same Write tool. A workaround (e.g., checking for a `.delegation-active` marker file) would add fragile complexity.

### 3. Command Spec Hardening (Secondary Enforcement)

**Current wording in plan.md (STAGE 2: DELEGATE):**
```
**EXECUTE NOW**: After STAGE 1.5 completes, immediately invoke the Skill tool.
```

This is directive but not explicitly prohibitive. The orchestrator can read the full spec, understand what the skill would do, and decide to "optimize" by doing it directly.

**Proposed strengthening -- add explicit prohibition block at the top of plan.md:**

```markdown
## Anti-Bypass Constraint

**CRITICAL**: This command MUST delegate to the appropriate skill. The orchestrator
MUST NOT write plan files directly. Plan artifacts require format compliance that
is enforced by the skill's internal validation pipeline. Direct writes will:
1. Be detected by PostToolUse hooks and flagged as violations
2. Miss required metadata fields (Status, Dependencies, Research Inputs, etc.)
3. Miss required sections (Goals & Non-Goals, Testing & Validation, etc.)
4. Miss the Dependency Analysis wave table
5. Miss proper phase format (Goal/Tasks/Timing/Depends on)

If you are reading this command spec, your ONLY action is to invoke
Skill('skill-planner') or the appropriate extension skill. Do NOT attempt
to create the plan yourself.
```

**Similar additions needed for research.md and implement.md** to prevent the same class of bypass.

**Strengths:**
- Directly addresses the bypass pattern observed
- Makes the prohibition explicit and explains consequences
- Low implementation cost (text changes only)

**Weaknesses:**
- Purely instructional -- the model can still ignore it
- May be overridden by competing instructions in the conversation
- Less effective than infrastructure-level enforcement

### 4. Local .memory/ Feedback Entry (Tertiary Enforcement)

**Current state of .memory/:**
- Directory exists with proper structure (.memory/00-Inbox/, 10-Memories/, 20-Indices/, 30-Templates/)
- 10-Memories/ is empty -- no memories have been created yet
- Template format uses YAML frontmatter with title, created, tags, topic, source, modified fields
- .memory/ files are loaded by the context discovery system (per CLAUDE.md: "Project memory | .memory/ files | Loaded directly, no index needed")

**Proposed memory entry: MEM-plan-delegation-required.md**

```markdown
---
title: "Plan artifacts require skill delegation"
created: 2026-04-13
tags: enforcement, plan-format, delegation, bypass-prevention
topic: "agent-system/enforcement"
source: "incident 2026-04-13 task 414"
modified: 2026-04-13
---

# Plan artifacts require skill delegation

On 2026-04-13, the /plan command for task 414 was executed by the orchestrator
without invoking Skill('skill-planner'). The orchestrator read the command spec
and wrote a plan file directly, producing an artifact that violated the plan
format standard (missing 6 metadata fields, 4 required sections, dependency
analysis table, and proper phase format).

## Rule

When executing /plan, /research, or /implement commands:
- ALWAYS invoke the appropriate Skill tool (skill-planner, skill-researcher, skill-implementer)
- NEVER write artifact files (plans, reports, summaries) directly
- The skill pipeline includes format validation, status updates, and artifact linking
  that cannot be replicated by direct writes

## Detection

A PostToolUse hook validates plan artifacts written to specs/*/plans/*.md.
Non-conforming files trigger corrective context injection.
```

**How .memory/ loading works:**
Per the context architecture, `.memory/` files are "loaded directly, no index needed." This means they are available to all agents in all sessions. The memory entry would serve as a persistent reminder across conversations.

**Strengths:**
- Persists across sessions -- new conversations will see this memory
- Provides incident context (what happened, why it matters)
- Low overhead -- single markdown file
- Works within the existing .memory/ system (no new infrastructure)

**Weaknesses:**
- Still instructional -- the model can ignore it
- Only effective if the .memory/ loading system actually surfaces it (depends on how "loaded directly" works in practice)
- Less authoritative than hooks or rules

### 5. Analogous Bypass Risks in /research and /implement

**All three commands share the same bypass vulnerability:**

| Command | Delegation Target | Bypass Risk |
|---------|------------------|-------------|
| /plan | skill-planner | Orchestrator writes plan directly (observed) |
| /research | skill-researcher | Orchestrator writes research report directly (theoretical) |
| /implement | skill-implementer | Orchestrator modifies source files directly (theoretical) |

The command specs for all three use similar "EXECUTE NOW: invoke the Skill tool" language. The same class of bypass could occur with any of them.

**Recommendation:** Apply enforcement to all three commands, not just /plan. The PostToolUse hook should validate reports (specs/*/reports/*.md) and summaries (specs/*/summaries/*.md) in addition to plans.

### 6. Hook Input Mechanism

**Important finding:** The existing PreToolUse hook in settings.json uses `$CLAUDE_TOOL_INPUT` as an environment variable:
```bash
FILE=$(echo "$CLAUDE_TOOL_INPUT" | jq -r ".file_path // empty" 2>/dev/null)
```

However, the official Claude Code documentation (as of 2026) specifies that hooks receive JSON on **stdin**, not via environment variables. The docs show:
```bash
TOOL=$(jq -r '.tool_name' < /dev/stdin)
FILE_PATH=$(jq -r '.tool_input.file_path' < /dev/stdin)
```

The existing hook works (it has been in production), suggesting `$CLAUDE_TOOL_INPUT` is also supported. However, the new hook should use the stdin approach as documented, for forward compatibility. The implementation should handle both patterns as a safety measure.

## Decisions

1. **Layer all three mechanisms** -- no single mechanism is sufficient alone. The PostToolUse hook is primary, command spec hardening is secondary, .memory/ is tertiary.
2. **Use PostToolUse (not PreToolUse)** -- PreToolUse cannot distinguish legitimate writes from bypass writes without a delegation-depth marker, which adds fragile complexity.
3. **Extend to all artifact types** -- the hook should validate plans, reports, and summaries, not just plans.
4. **Use stdin for hook input** -- follow the documented approach rather than the legacy env var approach.
5. **Use local .memory/ only** -- per user requirement, do not use global ~/.claude/projects/ memories.

## Recommendations

### Priority 1: PostToolUse validation hook (implement first)
- Create `.claude/hooks/validate-plan-write.sh` that calls `validate-artifact.sh` for plan files
- Add PostToolUse entry to settings.json matching `Write|Edit`
- Extend to also validate report and summary artifacts
- Test with a deliberately non-conforming plan write

### Priority 2: Command spec anti-bypass language (implement second)
- Add "Anti-Bypass Constraint" section to plan.md, research.md, implement.md
- Place at the top of the file (before execution stages) for maximum visibility
- Include explicit prohibition and consequence explanation

### Priority 3: .memory/ feedback entry (implement third)
- Create `.memory/10-Memories/MEM-plan-delegation-required.md`
- Include incident context and enforcement rule
- Verify it loads in new sessions

### Priority 4 (optional): Extend validate-artifact.sh
- Currently validates metadata and sections
- Could add phase format validation (Goal/Tasks/Timing/Depends on)
- Could add Dependency Analysis table validation

## Risks & Mitigations

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| PostToolUse hook adds latency to all Write/Edit calls | Medium | Low | Early path check exits immediately for non-plan files (~1ms) |
| Hook stdin format changes in future Claude Code versions | Low | Medium | Test hook in CI; handle both stdin and env var inputs |
| Model ignores corrective context from hook | Low | Medium | The corrective message is injected as system-level context, which models treat with high authority |
| .memory/ files not loaded in all sessions | Medium | Low | .memory/ is tertiary defense; hook and spec language are primary |
| Hook validation too strict, blocks legitimate edge cases | Low | Medium | validate-artifact.sh has --fix mode for auto-repair; hook uses non-blocking additionalContext |

## Appendix

### Search Queries and Sources
- Codebase: settings.json, plan.md, research.md, implement.md, skill-planner/SKILL.md, plan-format.md, plan-format-enforcement.md, validate-artifact.sh, validate-state-sync.sh, subagent-postflight.sh, skill-orchestrator/SKILL.md, .memory/ directory
- Web: Claude Code hooks documentation (https://code.claude.com/docs/en/hooks)
- Web: PostToolUse additionalContext issues (https://github.com/anthropics/claude-code/issues/18427)
- Web: PreToolUse deny capability (https://code.claude.com/docs/en/hooks-guide)

### Environment Variable vs Stdin Discrepancy

The existing PreToolUse hook uses `$CLAUDE_TOOL_INPUT`:
```bash
FILE=$(echo "$CLAUDE_TOOL_INPUT" | jq -r ".file_path // empty" 2>/dev/null)
```

The official docs show stdin:
```bash
INPUT=$(cat)
FILE=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')
```

Both approaches should be supported in the implementation for robustness.

### Existing validate-artifact.sh Coverage

The script validates:
- **Plans**: Task, Status, Effort, Dependencies, Research Inputs, Artifacts, Standards, Type (metadata); Overview, Goals & Non-Goals, Risks & Mitigations, Implementation Phases, Testing & Validation, Artifacts & Outputs, Rollback/Contingency (sections); Phase headings; Dependency Analysis table
- **Reports**: Task, Started, Completed, Effort, Dependencies, Sources/Inputs, Artifacts, Standards (metadata); Executive Summary, Context & Scope, Findings, Decisions, Recommendations (sections)
- **Summaries**: Task, Status, Started, Completed, Artifacts, Standards (metadata); Overview, What Changed, Decisions, Impacts, Follow-ups, References (sections)

This coverage is sufficient for the PostToolUse hook validation.
