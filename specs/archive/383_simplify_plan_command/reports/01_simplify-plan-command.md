# Research Report: Task #383

**Task**: 383 - Simplify /plan command, remove status gates, reference prior plan
**Started**: 2026-04-09T05:22:42Z
**Completed**: 2026-04-09T05:30:00Z
**Effort**: 1 hour
**Dependencies**: None
**Sources/Inputs**: Codebase analysis of plan.md, SKILL.md, planner-agent.md, state-management.md, update-task-status.sh
**Artifacts**: specs/383_simplify_plan_command/reports/01_simplify-plan-command.md
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The /plan command currently restricts execution to tasks with status `not_started`, `researched`, or `partial`. These gates exist in the command (plan.md), skill (SKILL.md), and implicitly in the agent. All three need changes.
- The existing `/revise` command already handles re-planning but as a separate lightweight flow without subagent delegation. The new `/plan` behavior subsumes much of `/revise`'s plan-revision functionality.
- Prior plan discovery is straightforward: glob `specs/{NNN}_{SLUG}/plans/*.md` and take the latest by sort order.
- The delegation chain (command -> skill -> agent) passes context via args string. Adding `prior_plan_path` follows the existing `research_path` pattern exactly.
- The planner-agent needs a new Stage 2a to load prior plan as reference context, with clear instructions that research is primary and prior plan is secondary reference.

## Context & Scope

This research analyzes how to simplify `/plan` so it always creates a fresh plan from any task state, while optionally passing a prior plan to the planner-agent as reference context. The scope covers three files and the status transition script.

## Findings

### 1. Current Architecture Analysis (Command -> Skill -> Agent)

**Command (plan.md)**:
- CHECKPOINT 1: GATE IN (lines 236-267) validates status allows planning: `not_started`, `researched`, `partial`
- Blocks `planned` (offers --force for revision), `completed`, `implementing`
- Multi-task batch validation (lines 100-140) also validates status `researched`, `not_started`, or `partial`
- STAGE 2: DELEGATE passes `task_number`, `research_path`, `session_id` to skill

**Skill (SKILL.md)**:
- Stage 1: Input Validation (lines 41-68) validates task status -- only blocks `completed`
- Stage 2: Runs preflight via `update-task-status.sh preflight $task_number plan $session_id`
- Stage 3a: Calculates artifact number using `next_artifact_number` from state.json
- Stage 4: Prepares delegation context with `research_path` and `artifact_number`
- Stage 5: Invokes planner-agent via Task tool

**Agent (planner-agent.md)**:
- Stage 1: Parses delegation context including `research_path`
- Stage 2: Loads research report if `research_path` exists
- Stages 3-5: Analyzes scope, decomposes into phases, creates plan file
- Stage 6: Writes metadata file
- No awareness of prior plans at all

### 2. Status Gates to Remove

**In plan.md (CHECKPOINT 1: GATE IN, lines 255-259)**:
```
Current:
- Status allows planning: not_started, researched, partial
- If planned: Note existing plan, offer --force for revision
- If completed: ABORT "Task already completed"
- If implementing: ABORT "Task in progress, use /revise instead"

Change to:
- Task exists (ABORT if not)
- If completed or abandoned: ABORT (terminal states only)
- All other states: proceed
```

**In plan.md (MULTI-TASK DISPATCH, Step 1, lines 120-121)**:
```
Current: if [ "$status" = "researched" ] || [ "$status" = "not_started" ] || [ "$status" = "partial" ]
Change to: Allow any non-terminal status (not completed, not abandoned)
```

**In SKILL.md (Stage 1, lines 64-67)**:
```
Current: Only blocks "completed"
Change to: Block "completed" and "abandoned" (terminal states)
```

**In state-management.md (lines 37-38)**:
```
Current: "Cannot skip phases (e.g., NOT STARTED -> PLANNED)"
This rule needs relaxation for /plan specifically, or a note that /plan can run from any non-terminal state.
```

**In update-task-status.sh**:
The script itself has no status validation guards -- it simply maps operation+target to new status. No changes needed here. The script's idempotency check (lines 120-126) handles repeated runs gracefully.

### 3. Prior Plan Discovery Mechanism

The pattern already exists in `/revise` (SKILL.md Stage 2A.1):

```bash
# Find latest plan file in task directory
padded_num=$(printf "%03d" "$task_number")
latest_plan=$(ls -1 "specs/${padded_num}_${project_name}/plans/"*.md 2>/dev/null | sort -V | tail -1)
```

This should be added to skill-planner SKILL.md at Stage 4 (Prepare Delegation Context), immediately after gathering `research_path`.

**Important**: The prior plan check should be informational only -- if no prior plan exists, `prior_plan_path` is simply empty/omitted. This is identical to how `research_path` works when no research exists.

### 4. Passing prior_plan_path Through the Delegation Chain

**In plan.md (STAGE 2: DELEGATE)**:

The skill invocation args string already passes `research_path`. Add `prior_plan_path`:

```
skill: "skill-planner"
args: "task_number={N} research_path={path} prior_plan_path={path} session_id={session_id}"
```

**In SKILL.md (Stage 4: Prepare Delegation Context)**:

Add `prior_plan_path` to the delegation context JSON:

```json
{
  "session_id": "...",
  "task_context": { ... },
  "artifact_number": "...",
  "research_path": "{path to research report if exists}",
  "prior_plan_path": "{path to prior plan if exists}",
  "roadmap_path": "specs/ROAD_MAP.md",
  "metadata_file_path": "specs/{NNN}_{SLUG}/.return-meta.json"
}
```

**In planner-agent.md (Stage 1: Parse Delegation Context)**:

Add `prior_plan_path` to extracted fields:

```
- `research_path` - Path to research report (if exists)
- `prior_plan_path` - Path to prior plan (if exists, reference only)
```

### 5. Agent Behavior Changes: Research as Primary, Prior Plan as Reference

**New Stage 2a in planner-agent.md** (between current Stage 2 and Stage 3):

```markdown
### Stage 2a: Load Prior Plan (if exists)

If `prior_plan_path` is provided:
1. Use `Read` to load the prior plan
2. Extract: phase structure, effort estimates, risks identified, what worked
3. Note any phase status markers (completed phases = validated approach)
4. Store as **reference context only** -- do NOT copy phases verbatim

If no prior plan exists:
- Skip this stage (no-op)

**Priority hierarchy for plan creation**:
1. **Research report** (primary) - Findings, recommendations, patterns discovered
2. **Task description** (primary) - Requirements and constraints
3. **Prior plan** (reference) - Lessons learned, effort calibration, risk awareness
4. **Roadmap context** (reference) - Alignment and sequencing

**MUST NOT**: Copy phases from prior plan into new plan. The prior plan is for learning, not templating.
```

**Update Stage 5 (Create Plan File)**:

Add a section to the plan metadata block:

```markdown
### Prior Plan Reference

{If prior plan existed: summary of what was learned from it. If not: "No prior plan."}
```

### 6. Artifact Numbering When Re-Planning

Current behavior (SKILL.md Stage 3a, lines 112-136):
- Plan uses `next_artifact_number - 1` to stay in the same "round" as research
- Plan does NOT increment `next_artifact_number`

**Question**: When re-planning from an already-planned state, should we:
- (A) Use the same artifact number as the prior plan (overwrite risk)
- (B) Increment to a new round (implies new research should have happened)
- (C) Always use the latest plan count + 1

**Recommendation: Option C** -- Count existing plans and use count + 1. This avoids both overwrite risk and the assumption that research must precede each plan. The prior plan files are preserved as historical record.

**Implementation**:
```bash
# Count existing plan artifacts
padded_num=$(printf "%03d" "$task_number")
plan_count=$(ls "specs/${padded_num}_${project_name}/plans/"*[0-9][0-9]*.md 2>/dev/null | wc -l)
artifact_number=$((plan_count + 1))
```

This is simpler and more robust than the current `next_artifact_number - 1` logic, and handles re-planning naturally.

**Note**: The `next_artifact_number` field in state.json should still only be incremented by research (existing behavior). Plan numbering becomes independent via file counting.

### 7. Specific Changes Needed Per File

#### File 1: `.claude/commands/plan.md`

| Section | Change | Lines |
|---------|--------|-------|
| CHECKPOINT 1 validation | Remove status restrictions, only block completed/abandoned | 255-259 |
| CHECKPOINT 1 planned handling | Remove --force offer, just proceed | 258 |
| CHECKPOINT 1 implementing handling | Remove ABORT, just proceed | 259 |
| CHECKPOINT 1 Load Context | Add: discover prior plan path from plans/ directory | 264 |
| MULTI-TASK validation | Accept any non-terminal status | 120-121 |
| STAGE 2 skill args | Add `prior_plan_path={path}` | 367-370 |

#### File 2: `.claude/skills/skill-planner/SKILL.md`

| Section | Change | Lines |
|---------|--------|-------|
| Stage 1 status validation | Only block completed/abandoned | 64-67 |
| Stage 3a artifact numbering | Use plan file count + 1 instead of next_artifact_number - 1 | 112-136 |
| Stage 4 delegation context | Add `prior_plan_path` field | 146-162 |
| Stage 4 prior plan discovery | New: glob for latest plan in plans/ directory | (new) |

#### File 3: `.claude/agents/planner-agent.md`

| Section | Change | Lines |
|---------|--------|-------|
| Stage 1 delegation fields | Add `prior_plan_path` extraction | 31 |
| New Stage 2a | Load prior plan as reference context | (new, between Stage 2 and Stage 3) |
| Stage 5 plan template | Add "Prior Plan Reference" section | 129-217 |
| Context References | Note about prior plan handling | 16-20 |
| Priority hierarchy | Document research > task desc > prior plan > roadmap | (in Stage 2a) |

### 8. Status Transition Impact

When `/plan` runs from various states, the `update-task-status.sh preflight plan` call sets status to `planning`, and postflight sets it to `planned`. This works correctly regardless of the starting state because:

- The script has no starting-state validation -- it just maps `preflight:plan` -> `planning` and `postflight:plan` -> `planned`
- The idempotency check handles repeated runs
- state.json and TODO.md are updated atomically

**However**: The `state-management.md` rules document says "Cannot skip phases (e.g., NOT STARTED -> PLANNED)". This rule should be softened to acknowledge that `/plan` is explicitly allowed to run from any non-terminal state, creating a documented exception.

### 9. Relationship with /revise

Currently `/revise` handles re-planning as a lightweight operation (no subagent, direct execution). With the simplified `/plan`, there is functional overlap:

| Feature | /plan (new) | /revise |
|---------|-------------|---------|
| Creates fresh plan | Yes | No (revises existing) |
| Uses prior plan as reference | Yes (if exists) | Yes (base for revision) |
| Delegates to planner-agent | Yes | No (direct execution) |
| Research as primary input | Yes | No |
| Can run from any state | Yes (non-terminal) | Yes (planned/implementing/partial/blocked) |

**Recommendation**: Keep `/revise` as-is. It serves a different purpose (quick lightweight iteration on an existing plan without full agent delegation). `/plan` is for "start fresh with full analysis". Users choose based on need.

## Decisions

- Prior plan is **reference only**, never copied as template -- this matches the task description's "clean start" requirement
- Terminal states (completed, abandoned) remain blocked -- re-planning a completed task makes no sense
- Artifact numbering uses file counting instead of `next_artifact_number` -- simpler and handles re-planning naturally
- `/revise` is preserved as a separate command -- different use case (lightweight iteration vs. full fresh plan)
- The priority hierarchy (research > task description > prior plan > roadmap) is explicit and enforced in agent instructions

## Risks & Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| Stale status transitions in state-management.md | Low | Update rule documentation to note /plan exception |
| Prior plan biasing fresh plans too heavily | Medium | Clear agent instructions: "reference only, not template" |
| Artifact numbering collisions on re-plan | Low | File counting ensures unique numbers |
| /revise confusion with new /plan behavior | Low | Different purposes clearly documented |
| Multi-task batch validation too permissive | Low | Only terminal states blocked, which is correct |

## Appendix

### Files Examined
- `.claude/commands/plan.md` (492 lines) - Full command specification
- `.claude/skills/skill-planner/SKILL.md` (448 lines) - Planner skill with postflight
- `.claude/agents/planner-agent.md` (281 lines) - Planner agent execution flow
- `.claude/context/formats/plan-format.md` (170 lines) - Plan artifact format
- `.claude/context/formats/return-metadata-file.md` (503 lines) - Metadata exchange schema
- `.claude/rules/state-management.md` (80 lines) - Status transition rules
- `.claude/scripts/update-task-status.sh` (200 lines) - Status update script
- `.claude/skills/skill-reviser/SKILL.md` (180 lines) - Reviser for comparison

### Key Patterns Discovered
- The delegation chain uses string args at the command->skill boundary and JSON context at the skill->agent boundary
- `research_path` is the existing pattern for optional context passing -- `prior_plan_path` follows it exactly
- The `update-task-status.sh` script has no status validation, only operation+target mapping, making the transition changes safe
- Artifact numbering via file counting is already used as a fallback for legacy tasks (SKILL.md line 131)
