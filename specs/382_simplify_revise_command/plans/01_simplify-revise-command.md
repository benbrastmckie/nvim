# Implementation Plan: Simplify /revise Command

- **Task**: 382 - Simplify /revise command with command + skill + agent architecture
- **Status**: [NOT STARTED]
- **Effort**: 4 hours
- **Dependencies**: None
- **Research Inputs**: reports/01_simplify-revise-command.md
- **Artifacts**: plans/01_simplify-revise-command.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta

## Overview

Refactor the `/revise` command from a 2-layer architecture (command -> skill with direct execution) to a 3-layer architecture (command -> skill -> reviser-agent), matching `/plan`'s established pattern. The reviser-agent handles the substantive work of loading existing plans, discovering new research reports, and synthesizing revised plans. All status-based ABORT rules are removed so `/revise` works regardless of task state, with routing determined solely by whether a plan file exists.

### Research Integration

Key findings from the research report:
- The current skill-reviser executes plan revision directly (no subagent delegation), unlike skill-planner which delegates to planner-agent via Task tool
- Status-based ABORTs for "completed" and "abandoned" tasks should be removed entirely; routing is by plan file existence, not status
- Research discovery (finding reports newer than the plan) should live in the skill layer, which passes discovered paths to the agent
- Artifact numbering for revised plans uses the same round number (not incremented), matching /plan's behavior
- The reviser-agent is NOT a planner-agent clone: it loads existing plans, discovers new research, synthesizes both, and can update task descriptions

### Roadmap Alignment

No ROAD_MAP.md found.

## Goals & Non-Goals

**Goals**:
- Create reviser-agent.md modeled on planner-agent.md with revision-specific behavior
- Convert skill-reviser from direct execution to thin wrapper with Task tool delegation
- Remove all status-based ABORT rules from revise.md command
- Add GATE OUT verification to revise.md matching /plan's CHECKPOINT 2 pattern
- Update CLAUDE.md skill-to-agent mapping and agents tables

**Non-Goals**:
- Adding --team flag support (future work, not this task)
- Multi-task syntax for /revise (not needed)
- Changing the git commit message format for revise operations
- Adding a "revising" intermediate status

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Agent adds overhead for simple description-only updates | M | M | Agent short-circuits for description-only path with minimal processing |
| File modification time comparison unreliable across systems | L | L | Use reports_integrated from state.json as primary, mtime as fallback |
| Removing status gates on completed/abandoned tasks causes confusion | L | L | Revised completed tasks reset to "planned" which is expected behavior |
| Postflight marker mechanism adds failure surface | M | L | Well-tested pattern already proven in skill-planner |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3 | 1 |
| 3 | 4 | 2, 3 |

Phases within the same wave can execute in parallel.

### Phase 1: Create reviser-agent.md [NOT STARTED]

**Goal**: Create the new reviser-agent that handles plan revision and description update logic, modeled on planner-agent.md but with revision-specific behavior.

**Tasks**:
- [ ] Create `.claude/agents/reviser-agent.md` with frontmatter (name, description, model: opus)
- [ ] Write Overview section describing revision-specific purpose
- [ ] Write Context References section (same as planner-agent plus plan-format.md)
- [ ] Write Stage 0: Initialize early metadata (same pattern as planner-agent)
- [ ] Write Stage 1: Parse delegation context extracting `existing_plan_path`, `new_research_paths`, `revision_reason`
- [ ] Write Stage 2: Determine revision mode (plan exists -> Plan Revision; no plan -> Description Update)
- [ ] Write Stage 3: Load existing plan (read file, extract phase structure/statuses/dependencies)
- [ ] Write Stage 4: Load new research reports (read each report, extract findings)
- [ ] Write Stage 5a (Plan Revision): Synthesize revised plan preserving completed phases, revising not-started phases based on new research, following plan-format.md exactly
- [ ] Write Stage 5b (Description Update): Update task description from revision_reason or synthesized context
- [ ] Write Stage 6: Write metadata file with status "planned" (plan revision) or unchanged (description only)
- [ ] Write Stage 7: Return brief text summary
- [ ] Write Error Handling section
- [ ] Write Critical Requirements (MUST DO / MUST NOT lists)
- [ ] Add behavioral rules: never discard completed phase work, preserve phase numbering, update reports_integrated

**Timing**: 1.5 hours

**Depends on**: none

**Files to modify**:
- `.claude/agents/reviser-agent.md` - NEW FILE: complete agent definition (~200 lines)

**Verification**:
- File exists with correct frontmatter (name: reviser-agent, model: opus)
- All 8 stages documented (0-7)
- Both Plan Revision and Description Update paths are covered
- Context References match planner-agent pattern
- Critical Requirements section present with MUST DO / MUST NOT lists

---

### Phase 2: Refactor skill-reviser/SKILL.md to thin wrapper [NOT STARTED]

**Goal**: Convert skill-reviser from direct execution to a thin wrapper that delegates to reviser-agent via Task tool, matching skill-planner's pattern.

**Tasks**:
- [ ] Update frontmatter: add `Task` to allowed-tools list
- [ ] Update header description to "Thin wrapper that delegates plan revision to reviser-agent subagent"
- [ ] Remove the note about not delegating to a subagent
- [ ] Rewrite Stage 1 (Input Validation): Remove status-based routing table and ABORT rules; validate only that task exists
- [ ] Remove Stage 2A (Plan Revision direct execution) entirely
- [ ] Remove Stage 2B (Description Update direct execution) entirely
- [ ] Add Stage 2 (Preflight): No intermediate "revising" status needed, skip this stage (document why)
- [ ] Add Stage 3 (Create Postflight Marker): Same pattern as skill-planner Stage 3
- [ ] Add Stage 3a (Artifact Number Calculation): Use `next_artifact_number - 1` pattern from skill-planner
- [ ] Add Stage 4 (Research Discovery): Find existing plan path, discover reports newer than plan using mtime comparison and reports_integrated fallback
- [ ] Add Stage 4b (Read and inject plan-format.md as artifact-format-specification)
- [ ] Add Stage 5 (Prepare Delegation Context): Build JSON with session_id, delegation_path, task_context, existing_plan_path, new_research_paths, revision_reason, artifact_number, roadmap_path, metadata_file_path
- [ ] Add Stage 6 (Invoke reviser-agent via Task tool)
- [ ] Add Stage 7 (Parse Return Metadata): Read .return-meta.json
- [ ] Add Stage 7a (Validate Artifact Content): Check plan file has required fields
- [ ] Rewrite Stage 3 -> Stage 8 (Postflight Status Update): Use update-task-status.sh for plan revision path only
- [ ] Rewrite Stage 4 -> Stage 9 (Artifact Linking): Preserve existing two-step jq pattern
- [ ] Rewrite Stage 5 -> Stage 10 (Git Commit): Preserve existing commit message format
- [ ] Add Stage 11 (Cleanup): Remove .postflight-pending and .return-meta.json
- [ ] Rewrite Stage 6 -> Stage 12 (Return Brief Summary)
- [ ] Add MUST NOT section matching skill-planner's postflight boundary rules

**Timing**: 1.5 hours

**Depends on**: 1

**Files to modify**:
- `.claude/skills/skill-reviser/SKILL.md` - REWRITE: convert from direct execution to thin wrapper (~250 lines)

**Verification**:
- `Task` appears in allowed-tools frontmatter
- No status-based ABORT rules remain
- No direct plan revision or description update logic remains (all moved to agent)
- Delegation context JSON structure matches research specification
- Postflight marker creation and cleanup present
- Artifact linking preserves two-step jq pattern for Issue #1132 safety
- Git commit messages preserved (`task {N}: revise plan (v{VERSION})` and `task {N}: revise description`)

---

### Phase 3: Simplify revise.md command [NOT STARTED]

**Goal**: Remove status-based ABORT rules from the command, add GATE OUT verification matching /plan's CHECKPOINT 2 pattern, and route solely by plan file existence.

**Tasks**:
- [ ] Update frontmatter: add `Skill` to allowed-tools (for skill invocation)
- [ ] Rewrite CHECKPOINT 1 (GATE IN): Remove status routing table, remove completed/abandoned ABORT rules, keep only "task not found" ABORT
- [ ] Add plan existence check: use Glob to detect `specs/{NNN}_{SLUG}/plans/*.md` files
- [ ] Update CHECKPOINT 2 (DELEGATE): Pass `plan_exists` flag instead of `branch` to skill-reviser, remove status-based branch routing
- [ ] Add CHECKPOINT 2 (GATE OUT): Read .return-meta.json, verify artifact exists if plan was revised, defensive status verification
- [ ] Update Error Handling section: Remove "Invalid status" error case, add GATE OUT failure handling
- [ ] Update Output section to reflect both paths are handled by skill/agent

**Timing**: 0.5 hours

**Depends on**: 1

**Files to modify**:
- `.claude/commands/revise.md` - MODIFY: simplify gate logic, add GATE OUT (~120 lines)

**Verification**:
- No ABORT rules based on task status (only "task not found" ABORT remains)
- No status routing table in GATE IN
- GATE OUT checkpoint present with .return-meta.json reading
- `plan_exists` flag passed to skill instead of `branch`

---

### Phase 4: Update CLAUDE.md tables [NOT STARTED]

**Goal**: Update the Skill-to-Agent Mapping and Agents tables in CLAUDE.md to reflect the new reviser-agent.

**Tasks**:
- [ ] Edit `.claude/CLAUDE.md`: Change skill-reviser row from `(direct execution)` to `reviser-agent` in Skill-to-Agent Mapping table
- [ ] Edit `.claude/CLAUDE.md`: Add `reviser-agent` row to Agents table with purpose "Plan revision with research synthesis"
- [ ] Verify the root `CLAUDE.md` at `/home/benjamin/.config/nvim/CLAUDE.md` does not need updates (it references .claude/CLAUDE.md)

**Timing**: 0.5 hours

**Depends on**: 2, 3

**Files to modify**:
- `.claude/CLAUDE.md` - EDIT: Update two table entries (2 line changes)

**Verification**:
- Skill-to-Agent Mapping shows `skill-reviser | reviser-agent | opus | Plan revision and description update`
- Agents table includes `reviser-agent | Plan revision with research synthesis`
- No other references to "(direct execution)" for skill-reviser remain

## Testing & Validation

- [ ] Verify reviser-agent.md has correct frontmatter and all required stages
- [ ] Verify skill-reviser SKILL.md has Task in allowed-tools and delegates via Task tool
- [ ] Verify revise.md command has no status-based ABORT rules
- [ ] Verify CLAUDE.md tables are updated with reviser-agent entries
- [ ] Grep for remaining "(direct execution)" references to skill-reviser across the codebase
- [ ] Verify plan-format.md injection pattern matches skill-planner's approach
- [ ] Verify delegation context JSON includes all required fields (existing_plan_path, new_research_paths, revision_reason)

## Artifacts & Outputs

- `.claude/agents/reviser-agent.md` - New agent file (~200 lines)
- `.claude/skills/skill-reviser/SKILL.md` - Rewritten skill file (~250 lines)
- `.claude/commands/revise.md` - Simplified command file (~120 lines)
- `.claude/CLAUDE.md` - Updated mapping tables (2 line edits)

## Rollback/Contingency

All three modified files are tracked in git. If the refactoring introduces issues:
1. `git checkout HEAD -- .claude/commands/revise.md .claude/skills/skill-reviser/SKILL.md .claude/CLAUDE.md` to restore originals
2. `git rm .claude/agents/reviser-agent.md` to remove the new agent file
3. The original 2-layer architecture remains functional as fallback
