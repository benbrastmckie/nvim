# Research Report: Task #382

**Task**: 382 - Simplify /revise command with command + skill + agent architecture
**Started**: 2026-04-08T00:00:00Z
**Completed**: 2026-04-08T00:30:00Z
**Effort**: 1 hour
**Dependencies**: None
**Sources/Inputs**: Codebase analysis of revise.md, skill-reviser/SKILL.md, plan.md, skill-planner/SKILL.md, planner-agent.md, plan-format.md, return-metadata-file.md, postflight-control.md, artifact-formats.md
**Artifacts**: reports/01_simplify-revise-command.md (this file)
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The current `/revise` command uses a two-layer architecture (command -> skill) with no subagent delegation, while `/plan` uses a three-layer architecture (command -> skill -> planner-agent). The task is to refactor `/revise` to match `/plan`'s pattern.
- The current implementation has status-based ABORT rules that prevent revision from many states. These should be removed so `/revise` always works regardless of task state.
- A new `reviser-agent.md` needs to be created, modeled on `planner-agent.md`, with a key differentiator: discovering and integrating research reports created after the last plan modification.
- Artifact numbering for revised plans should use the SAME round number (not incremented), consistent with how `/plan` already works.

## Context & Scope

This research examines the architectural gap between `/revise` (2-layer) and `/plan` (3-layer), and documents the specific changes needed to bring `/revise` into alignment. The scope covers command structure, skill delegation pattern, agent creation, status handling, research discovery, and artifact numbering.

## Findings

### 1. Current Architecture Analysis

**Current `/revise` (2-layer)**:
```
/revise command (revise.md)
  -> skill-reviser (SKILL.md) -- executes directly, no subagent
```

**Reference `/plan` (3-layer)**:
```
/plan command (plan.md)
  -> skill-planner (SKILL.md) -- thin wrapper with postflight
    -> planner-agent (planner-agent.md) -- does the actual work via Task tool
```

**Key differences in current skill-reviser vs skill-planner**:

| Aspect | skill-reviser (current) | skill-planner (reference) |
|--------|------------------------|--------------------------|
| Agent delegation | None (direct execution) | Task tool -> planner-agent |
| Postflight marker | None | Creates `.postflight-pending` |
| Metadata exchange | None | Writes/reads `.return-meta.json` |
| Preflight status | No intermediate status | Sets "planning" via script |
| Artifact validation | None | Runs `validate-artifact.sh` |
| Context loading | Inline | Agent loads via @-references |

### 2. Target Architecture

**Target `/revise` (3-layer)**:
```
/revise command (revise.md)
  -> skill-reviser (SKILL.md) -- thin wrapper with postflight
    -> reviser-agent (reviser-agent.md) -- does revision work via Task tool
```

The skill-reviser should become a thin wrapper that:
1. Validates task existence (no status gates)
2. Runs preflight status update (no intermediate "revising" status needed -- keep current behavior)
3. Creates postflight marker
4. Calculates artifact number (same round, `next_artifact_number - 1`)
5. Reads and injects plan-format.md for the agent
6. Invokes reviser-agent via Task tool
7. Reads `.return-meta.json` on return
8. Runs postflight: status update, artifact linking, git commit
9. Cleans up marker and metadata files

### 3. Key Differences: reviser-agent vs planner-agent

The reviser-agent is NOT just a planner-agent clone. It has distinct behavior:

| Aspect | planner-agent | reviser-agent |
|--------|--------------|---------------|
| Input: existing plan | None (creates from scratch) | Loads existing plan if one exists |
| Input: research reports | Single report path | Discovers ALL reports newer than plan |
| Plan creation | Always creates new plan | Synthesizes old plan + new research |
| No-plan fallback | Error (research required) | Description-only update if no plan |
| Description update | Never | Updates task description if appropriate |
| Status output | Always "planned" | "planned" (if plan revised) or unchanged (if description only) |
| Roadmap | Reads roadmap | Same behavior as planner |

### 4. Research Discovery Mechanism

The reviser-agent needs to find research reports created AFTER the existing plan was last modified. This is the core differentiator.

**Algorithm**:
```bash
# 1. Find the existing plan file
plan_dir="specs/${padded_num}_${project_name}/plans"
latest_plan=$(ls -1t "$plan_dir"/*.md 2>/dev/null | head -1)

# 2. Get plan modification time
if [ -n "$latest_plan" ]; then
    plan_mtime=$(stat -c %Y "$latest_plan")
fi

# 3. Find research reports newer than the plan
reports_dir="specs/${padded_num}_${project_name}/reports"
new_reports=()
for report in "$reports_dir"/*.md; do
    if [ -f "$report" ]; then
        report_mtime=$(stat -c %Y "$report")
        if [ "$report_mtime" -gt "$plan_mtime" ]; then
            new_reports+=("$report")
        fi
    fi
done
```

**Edge cases**:
- No plan exists: Agent receives no plan path, falls through to description-update behavior
- No new reports: Agent uses existing plan as-is for structural revision (user provided reason)
- No plan and no reports: Description-only update
- Multiple new reports: All are loaded and synthesized

**Alternative approach**: Use `reports_integrated` from plan_metadata in state.json to determine which reports have already been integrated, rather than relying on file modification times. This is more reliable but requires the field to be populated.

**Recommended approach**: Use BOTH mechanisms. Check `reports_integrated` first (if populated), then fall back to file modification time comparison. The agent prompt should document both strategies.

### 5. Status Handling: No Gates

**Current behavior** (to be removed):

| Status | Current Action |
|--------|---------------|
| planned, implementing, partial, blocked | Plan Revision |
| not_started, researched | Description Update |
| completed | **ABORT** |
| abandoned | **ABORT** |

**Target behavior** (always works):

| Status | Target Action |
|--------|--------------|
| Any status with existing plan | Plan Revision (synthesize with new research) |
| Any status without plan | Description Update |
| No restrictions | No ABORTs based on status |

This means:
- **completed** tasks can be revised (user wants to re-plan for further work)
- **abandoned** tasks can be revised (user wants to revive with new approach)
- The command no longer needs to inspect status at all for routing purposes
- Routing is determined solely by whether a plan file exists in the task directory

**Status transition on revision**:
- Plan revision: Status returns to "planned" (via postflight script)
- Description update: Status unchanged (no postflight status update)

### 6. Artifact Numbering for Revisions

Per artifact-formats.md, the round concept:
- **Research**: Advances the sequence (reads `next_artifact_number`, uses it, increments)
- **Plan**: Uses current round (`next_artifact_number - 1`)
- **Summary**: Uses current round (`next_artifact_number - 1`)

For `/revise`:
- The revised plan uses the SAME artifact number as the current round
- This is identical to how `/plan` calculates it (Stage 3a in skill-planner)
- The revised plan file replaces the previous plan in the same round
- Previous plan files are preserved on disk for history

**Artifact number calculation** (same as skill-planner Stage 3a):
```bash
next_num=$(jq -r --argjson num "$task_number" \
  '.active_projects[] | select(.project_number == $num) | .next_artifact_number // 1' \
  specs/state.json)

if [ "$next_num" -le 1 ]; then
  artifact_number=1
else
  artifact_number=$((next_num - 1))
fi
```

### 7. Specific Changes Per File

#### 7a. `.claude/commands/revise.md`

**Changes needed**:
1. Remove status-based ABORT rules (completed, abandoned) from GATE IN
2. Remove status-based routing table (plan revision vs description update)
3. Route solely by plan file existence instead of status
4. Add extension routing lookup (matching `/plan` command's STAGE 2)
5. Add `--team` flag support structure (future-proofing, not required now)
6. Update GATE OUT to read `.return-meta.json` and verify artifacts
7. Add defensive status verification (matching `/plan` CHECKPOINT 2)
8. Move git commit responsibility to CHECKPOINT 3 (from skill)

**Structure should become**:
```
CHECKPOINT 1: GATE IN
  - Generate session_id
  - Lookup task (ABORT only if task not found)
  - Load context (determine if plan exists)
  - No status-based ABORTs

STAGE 2: DELEGATE
  - Extension routing lookup
  - Invoke skill-reviser with task context
  - Pass plan_exists flag, revision_reason

CHECKPOINT 2: GATE OUT
  - Read .return-meta.json
  - Verify artifacts
  - Defensive status verification

CHECKPOINT 3: COMMIT
  - git commit
```

#### 7b. `.claude/skills/skill-reviser/SKILL.md`

**Changes needed**:
1. Convert from "direct execution" to "thin wrapper with subagent delegation"
2. Add `Task` to allowed-tools (required for subagent invocation)
3. Remove ALL plan revision logic (Stage 2A) -- this moves to reviser-agent
4. Remove ALL description update logic (Stage 2B) -- this moves to reviser-agent
5. Add Stage 2 (preflight status update): No intermediate "revising" status needed
6. Add Stage 3 (postflight marker creation)
7. Add Stage 3a (artifact number calculation, same as skill-planner)
8. Add Stage 4 (prepare delegation context)
9. Add Stage 4b (read and inject plan-format.md)
10. Add Stage 5 (invoke reviser-agent via Task tool)
11. Add Stage 6 (parse return metadata)
12. Add Stage 6a (validate artifact content)
13. Add Stage 7 (postflight status update)
14. Add Stage 8 (artifact linking)
15. Add Stage 9 (git commit) -- or leave to command CHECKPOINT 3
16. Add Stage 10 (cleanup)
17. Add Stage 11 (return brief summary)
18. Add MUST NOT section (postflight boundary)

**Delegation context should include**:
```json
{
  "session_id": "...",
  "delegation_path": ["orchestrator", "revise", "skill-reviser"],
  "task_context": { "task_number": N, "task_name": "...", "description": "...", "language": "..." },
  "artifact_number": "NN",
  "existing_plan_path": "path/to/plan.md or null",
  "new_research_paths": ["path/to/report1.md", ...],
  "revision_reason": "optional user reason",
  "roadmap_path": "specs/ROAD_MAP.md",
  "metadata_file_path": "specs/{NNN}_{SLUG}/.return-meta.json"
}
```

**Research discovery**: The skill (not the agent) should discover new reports, since it has access to file system and plan metadata. Pass the discovered paths to the agent.

#### 7c. `.claude/agents/reviser-agent.md` (NEW FILE)

**Model**: `planner-agent.md` as template, with these key modifications:

**Frontmatter**:
```yaml
---
name: reviser-agent
description: Revise implementation plans by synthesizing existing plans with new research findings
model: opus
---
```

**Context References**: Same as planner-agent, plus:
- `@.claude/context/formats/plan-format.md` (always load)
- `@.claude/context/workflows/task-breakdown.md` (when creating/revising plan)

**Execution Flow**:

Stage 0: Initialize early metadata (same as planner-agent)

Stage 1: Parse delegation context
  - Extract `existing_plan_path`, `new_research_paths`, `revision_reason`

Stage 2: Determine revision mode
  - If `existing_plan_path` is provided and file exists: Plan Revision mode
  - If no plan exists: Description Update mode

Stage 3 (Plan Revision): Load existing plan
  - Read the plan file
  - Extract phase structure, statuses, dependencies
  - Note which phases were completed/in-progress/blocked

Stage 4 (Plan Revision): Load new research
  - Read each report in `new_research_paths`
  - Extract findings, recommendations, new patterns
  - Note conflicts with existing plan assumptions

Stage 5 (Plan Revision): Synthesize revised plan
  - Preserve completed phases (mark as [COMPLETED])
  - Revise in-progress/not-started phases based on new research
  - Add new phases if research reveals additional work
  - Remove phases that are no longer needed
  - Update effort estimates, dependencies, wave analysis
  - Write revised plan following plan-format.md exactly
  - Include "Research Integration" section listing newly integrated reports

Stage 5 (Description Update): Update task description
  - If `revision_reason` provides new description text, use it
  - Otherwise, synthesize improved description from available context

Stage 6: Write metadata file
  - Status: "planned" (plan revision) or "researched"/"not_started" (description only)
  - Include artifact path, summary
  - Set `next_steps`

Stage 7: Return brief text summary

**Key behavioral rules for reviser-agent**:
1. Never discard completed phase work
2. Preserve phase numbering continuity where possible
3. Update `reports_integrated` in plan metadata
4. If revision_reason is provided, weigh it heavily in decisions
5. The revised plan completely replaces the old plan (new file, same round number)

### 8. CLAUDE.md Updates Required

The Skill-to-Agent Mapping table needs updating:

**Current entry**:
```
| skill-reviser | (direct execution) | opus | Plan revision and description update |
```

**Target entry**:
```
| skill-reviser | reviser-agent | opus | Plan revision and description update |
```

The Agents table needs a new entry:
```
| reviser-agent | Plan revision with research synthesis |
```

### 9. Git Commit Convention

Current revise commits:
- `task {N}: revise plan (v{VERSION})`
- `task {N}: revise description`

These should be preserved. The command's CHECKPOINT 3 handles the commit (not the skill or agent).

## Decisions

1. **Research discovery lives in skill, not agent**: The skill has access to file system metadata and state.json `reports_integrated` field. It discovers new reports and passes paths to the agent. The agent focuses on content synthesis.

2. **No intermediate "revising" status**: Unlike "planning" for /plan, /revise does not need a "revising" intermediate status. The task transitions directly to "planned" on success.

3. **Routing by plan existence, not status**: The fundamental routing question is "does a plan file exist?" not "what is the current status?"

4. **Git commit in command CHECKPOINT 3**: Following /plan's pattern, the git commit happens in the command's GATE OUT phase, not inside the skill. However, looking at the current implementation, skill-planner does its own git commit in Stage 9. Either approach works; recommend keeping it in the skill for consistency with skill-planner.

5. **Description-update still handled by reviser-agent**: Even though description updates are simple, routing them through the agent maintains architectural consistency. The agent can determine whether a description update is warranted based on the revision reason and available context.

## Risks & Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| Agent adds complexity for simple description updates | M | Agent can short-circuit for description-only path |
| File modification time comparison unreliable across systems | L | Use `reports_integrated` as primary, mtime as fallback |
| Removing status gates could cause confusion for completed tasks | L | /revise on completed task resets to "planned" -- user expects this |
| Postflight marker mechanism adds failure surface | M | Well-tested pattern from skill-planner, loop guard protection |

## Context Extension Recommendations

None. This is a meta task modifying the agent system itself.

## Appendix

### Files Analyzed

| File | Lines | Purpose |
|------|-------|---------|
| `.claude/commands/revise.md` | 105 | Current revise command |
| `.claude/skills/skill-reviser/SKILL.md` | 255 | Current revise skill (no agent) |
| `.claude/commands/plan.md` | 492 | Reference: plan command with full architecture |
| `.claude/skills/skill-planner/SKILL.md` | 447 | Reference: plan skill with agent delegation |
| `.claude/agents/planner-agent.md` | 281 | Reference: agent template to mirror |
| `.claude/context/formats/plan-format.md` | 170 | Plan artifact format specification |
| `.claude/context/formats/return-metadata-file.md` | 503 | Metadata exchange schema |
| `.claude/context/patterns/postflight-control.md` | 266 | Marker file protocol |
| `.claude/rules/artifact-formats.md` | 119 | Artifact naming conventions |
| `.claude/context/workflows/task-breakdown.md` | 271 | Task decomposition guidelines |

### Architecture Comparison Summary

```
CURRENT /revise:
  command (105 lines) -> skill (255 lines, direct execution)
  Total: 360 lines, 2 layers

TARGET /revise:
  command (~120 lines) -> skill (~250 lines, thin wrapper) -> agent (~200 lines)
  Total: ~570 lines, 3 layers

REFERENCE /plan:
  command (492 lines) -> skill (447 lines) -> agent (281 lines)
  Total: 1220 lines, 3 layers
  (Note: /plan is much larger due to multi-task support and team mode)
```
