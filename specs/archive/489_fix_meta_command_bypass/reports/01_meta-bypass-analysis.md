# Research Report: Task #489

**Task**: 489 - Fix /meta prompt mode regression: model bypasses Skill delegation and implements changes directly instead of creating tasks via interactive picker
**Started**: 2026-04-20T00:00:00Z
**Completed**: 2026-04-20T00:15:00Z
**Effort**: Medium (1-3 hours for implementation)
**Dependencies**: None
**Sources/Inputs**:
- `.claude/commands/meta.md` - Current command definition
- `.claude/commands/plan.md` - Anti-bypass reference
- `.claude/commands/research.md` - Anti-bypass reference
- `.claude/commands/implement.md` - Anti-bypass reference
- `.claude/skills/skill-meta/SKILL.md` - Skill definition
- `.claude/agents/meta-builder-agent.md` - Agent definition
- `.claude/hooks/validate-plan-write.sh` - PostToolUse hook
- `.claude/hooks/subagent-postflight.sh` - SubagentStop hook
- `.claude/settings.json` - Hook configuration
- Memory: "Artifact Creation Must Use Skill Delegation" (task-414/416 incident)
**Artifacts**: specs/489_fix_meta_command_bypass/reports/01_meta-bypass-analysis.md
**Standards**: report-format.md, artifact-formats.md

## Executive Summary

- The /meta command lacks the explicit "Anti-Bypass Constraint" section present in /plan, /research, and /implement
- No PostToolUse hook monitors writes to `.claude/` paths (commands, skills, agents, rules, context) -- the validate-plan-write.sh hook only covers `specs/*/plans/*.md`, `specs/*/reports/*.md`, and `specs/*/summaries/*.md`
- The meta command's `allowed-tools: Skill` frontmatter is correct but insufficient because models can still use Write/Edit from within the Skill invocation context
- The bypass regression is structural: the model reads detailed agent instructions about HOW to build .claude/ components and conflates "understanding what to create" with "creating it directly"
- Four-layer fix recommended: (1) Anti-Bypass section in meta.md, (2) new PreToolUse hook for .claude/ writes during /meta, (3) Skill-level enforcement in skill-meta, (4) agent-level reinforcement

## Context & Scope

The /meta command is designed to ONLY create tasks (entries in TODO.md and state.json). It should never directly create or modify commands, skills, agents, rules, or context files in `.claude/`. When a user invokes `/meta "add a new command for exporting logs"`, the expected behavior is:

1. Command delegates to skill-meta
2. skill-meta spawns meta-builder-agent
3. meta-builder-agent interviews user, proposes task breakdown, gets confirmation
4. Tasks are created in TODO.md + state.json
5. User later runs /research, /plan, /implement on those tasks

The regression: the model bypasses steps 1-4 entirely and directly creates the command file, skill file, agent file, etc. in `.claude/`.

## Findings

### 1. Structural Comparison: Anti-Bypass Mechanisms

| Mechanism | /plan | /research | /implement | /meta |
|-----------|-------|-----------|------------|-------|
| Anti-Bypass Section | YES | YES | YES | NO |
| PROHIBITION keyword | YES | YES | YES | NO (uses FORBIDDEN) |
| PostToolUse hook coverage | YES (plans/) | YES (reports/) | YES (summaries/) | NO |
| `allowed-tools` restriction | Skill, Bash(jq/git), Read, Edit | Skill, Bash(jq/git), Read, Edit | Skill, Bash(jq/git), Read, Edit | Skill only |
| Corrective context injection | YES (via hook) | YES (via hook) | YES (via hook) | NO |

### 2. Root Cause Analysis

**Primary Cause**: The model encounters the detailed meta-builder-agent instructions which describe templates for commands, skills, and agents (lines 154-192 of meta.md, the entire agent file). When processing a direct prompt like `/meta "add export command"`, the model has enough information to construct the files and does so directly, skipping the Skill delegation entirely.

**Contributing Factor 1**: The `allowed-tools: Skill` frontmatter in meta.md SHOULD restrict the command to only use the Skill tool. However, this restriction is weaker than an explicit Anti-Bypass section because:
- It relies on Claude Code's tool permission system which may not override deeply embedded instructions
- It provides no explanatory context about WHY bypass is forbidden
- It offers no corrective mechanism if bypassed

**Contributing Factor 2**: No hook exists to detect and block writes to `.claude/` paths during /meta execution. The validate-plan-write.sh hook is scoped exclusively to `specs/*/plans/*.md`, `specs/*/reports/*.md`, and `specs/*/summaries/*.md`.

**Contributing Factor 3**: The meta.md command file has a "Constraints" section with FORBIDDEN/REQUIRED blocks, but these focus on the OUTCOMES (don't create commands, don't modify CLAUDE.md) rather than the MECHANISM (don't bypass Skill delegation). The /plan and /research commands specifically say "MUST NOT write ... directly using Write or Edit tools" and "All ... files MUST be created by invoking the appropriate skill via the Skill tool."

### 3. Enforcement Gap Analysis

**Hook Coverage Gap**:
```
Current hooks monitor:
  specs/*/plans/*.md       -> validate-plan-write.sh (PostToolUse)
  specs/*/reports/*.md     -> validate-plan-write.sh (PostToolUse)
  specs/*/summaries/*.md   -> validate-plan-write.sh (PostToolUse)
  specs/state.json         -> validate-state-sync.sh (PostToolUse)

NOT monitored (where /meta bypass writes):
  .claude/commands/*.md    -> NO HOOK
  .claude/skills/**        -> NO HOOK
  .claude/agents/*.md      -> NO HOOK
  .claude/rules/*.md       -> NO HOOK
  .claude/context/**       -> NO HOOK
  CLAUDE.md                -> NO HOOK
```

**Instruction Clarity Gap**: The existing "Constraints" section says what NOT to do but not HOW to avoid it. Compare:

- /plan says: "You MUST NOT write plan artifacts directly using Write or Edit tools. All plan files MUST be created by invoking the appropriate skill (skill-planner or skill-team-plan) via the Skill tool."
- /meta says: "This command MUST NOT: Directly create commands, skills, rules, or context files"

The /plan version explicitly names the tool mechanism. The /meta version is outcome-focused, which is weaker for model compliance.

### 4. Memory Context

The memory entry from task 414/416 documents a nearly identical bypass for /plan. The fix involved:
1. PostToolUse hook (validate-plan-write.sh) -- primary enforcement
2. Anti-Bypass sections in command specs -- secondary enforcement
3. Memory entry -- tertiary enforcement

For /meta, only the tertiary mechanism (memory) currently exists, and it references /plan, /research, /implement -- not /meta specifically.

## Decisions

- The fix should mirror the proven pattern from /plan, /research, /implement
- A new hook is needed specifically for `.claude/` directory writes during /meta execution
- The meta.md command needs an explicit Anti-Bypass Constraint section using identical language patterns
- The skill-meta SKILL.md should reinforce the delegation requirement

## Recommendations

### Priority 1: Add Anti-Bypass Constraint to meta.md (HIGH)

Add a new section between "Constraints" and "Execution" in `.claude/commands/meta.md`:

```markdown
## Anti-Bypass Constraint

**PROHIBITION**: You MUST NOT create or modify files in `.claude/` directly using Write or Edit tools. The /meta command creates TASKS only - actual implementation is done later via /implement. You MUST invoke skill-meta via the Skill tool for all operations.

**Why**: Direct file creation bypasses the task lifecycle (research -> plan -> implement), produces changes without user confirmation or quality review, and circumvents the delegation chain. A PostToolUse hook monitors Write/Edit operations to `.claude/` paths and will inject corrective context on violation.

**Required**: Always delegate to the Skill tool. Never write to `.claude/commands/`, `.claude/skills/`, `.claude/agents/`, `.claude/rules/`, `.claude/context/`, or CLAUDE.md directly from this command.
```

### Priority 2: Create validate-meta-write.sh hook (HIGH)

New PostToolUse hook that detects writes to `.claude/` paths during /meta-like operations:

```bash
#!/bin/bash
# PostToolUse hook: block .claude/ writes during /meta command
# Returns corrective context if model attempts direct .claude/ writes

FILE=$(echo "$CLAUDE_TOOL_INPUT" | jq -r '.file_path // empty' 2>/dev/null)
if [ -z "$FILE" ]; then
  INPUT=$(cat)
  FILE=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null)
fi

# Check if file is in .claude/ directory (not inside specs/)
case "$FILE" in
  .claude/commands/*|.claude/skills/*|.claude/agents/*|.claude/rules/*|.claude/context/*|*/CLAUDE.md)
    echo "{\"additionalContext\": \"BYPASS DETECTED: You are writing directly to .claude/ files. The /meta command ONLY creates tasks - it never implements changes directly. Use the Skill tool to invoke skill-meta, which will create tasks in TODO.md for later implementation via /implement. Undo this write and delegate to the Skill tool instead.\"}"
    ;;
  *)
    echo '{}'
    ;;
esac
```

Register in settings.json under PostToolUse for Write|Edit matcher.

**Important caveat**: This hook should only fire during /meta context, not during /implement which legitimately writes to .claude/. One approach: check for a marker file or use the tool_use_id context. Alternatively, make the hook advisory (additionalContext) rather than blocking, which is less disruptive to other workflows.

### Priority 3: Reinforce in skill-meta SKILL.md (MEDIUM)

Add explicit anti-bypass language to the skill:

```markdown
## Anti-Bypass Constraint

**CRITICAL**: This skill MUST invoke meta-builder-agent via the Task tool. It MUST NOT:
- Write to `.claude/` paths directly
- Create command/skill/agent files
- Skip the subagent delegation

The skill is a thin delegation wrapper. All work is done by the subagent.
```

### Priority 4: Strengthen meta-builder-agent.md (MEDIUM)

The agent already has good FORBIDDEN/REQUIRED sections. Add an explicit statement at the top of the Constraints section:

```markdown
**SCOPE BOUNDARY**: This agent creates TASK ENTRIES (TODO.md + state.json + task directories in specs/) ONLY. It has NO authority to create or modify files in `.claude/`. Any such writes are a VIOLATION regardless of how helpful they appear.
```

### Priority 5: Update memory entry (LOW)

Extend the existing memory entry "Artifact Creation Must Use Skill Delegation" to explicitly include /meta:

> When executing /meta, NEVER create commands, skills, agents, or other .claude/ files directly. Always delegate to skill-meta via the Skill tool, which creates TASKS for later implementation.

## Risks & Mitigations

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Hook fires during legitimate /implement writes to .claude/ | Medium | High | Make hook advisory (additionalContext) not blocking; or scope to command context |
| Anti-bypass text makes command file too long | Low | Low | Section is ~8 lines, minimal overhead |
| Model still bypasses despite all fixes | Low | Medium | Memory entry provides session-persistent reinforcement |
| Hook slows down all Write/Edit operations | Low | Low | Early exit for non-.claude/ paths (~1ms overhead) |

## Context Extension Recommendations

- **Topic**: Anti-bypass enforcement patterns
- **Gap**: No centralized documentation of the anti-bypass pattern across all commands
- **Recommendation**: Create `.claude/context/patterns/anti-bypass-enforcement.md` documenting the pattern (Anti-Bypass section + PostToolUse hook + corrective context injection) for use when creating new commands

## Appendix

### Search Queries Used
- Grep for "Anti-Bypass" across all commands (found in plan.md, research.md, implement.md; absent from meta.md)
- Grep for `.claude/` path patterns in hooks directory (no matches -- gap confirmed)
- Read of settings.json hook configuration (only validate-plan-write.sh and validate-state-sync.sh as PostToolUse)

### Key File Comparison

**Allowed-tools frontmatter**:
- `/meta`: `Skill` (most restrictive -- but not enforced by hook)
- `/plan`: `Skill, Bash(jq:*), Bash(git:*), Read, Edit` (less restrictive but has hook enforcement)
- `/research`: `Skill, Bash(jq:*), Bash(git:*), Read, Edit` (same pattern)

**Delegation pattern**:
- `/plan`: Command -> Skill tool -> skill-planner -> planner-agent
- `/research`: Command -> Skill tool -> skill-researcher -> general-research-agent
- `/meta`: Command -> Skill tool -> skill-meta -> Task tool -> meta-builder-agent

The /meta command has an ADDITIONAL delegation layer (skill-meta uses Task tool to spawn meta-builder-agent) which increases the opportunity for the model to short-circuit the chain.

### Reference: task-414 incident resolution
The task-414 memory documents the identical pattern for /plan. The fix was:
1. validate-plan-write.sh hook (PRIMARY)
2. Anti-Bypass sections in command specs (SECONDARY)
3. Memory entry (TERTIARY)

This task should follow the same three-layer approach adapted for /meta's unique characteristics.
