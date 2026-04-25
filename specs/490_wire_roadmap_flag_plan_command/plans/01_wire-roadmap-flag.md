# Implementation Plan: Wire --roadmap Flag to /plan Command

- **Task**: 490 - wire_roadmap_flag_plan_command
- **Status**: [COMPLETED]
- **Effort**: 0.25 hours
- **Dependencies**: None
- **Research Inputs**: specs/490_wire_roadmap_flag_plan_command/reports/01_wire-roadmap-flag.md
- **Artifacts**: plans/01_wire-roadmap-flag.md (this file)
- **Standards**: plan-format.md; status-markers.md; artifact-management.md; tasks.md
- **Type**: meta
- **Lean Intent**: true

## Overview

Wire the `--roadmap` flag from the `/plan` command through skill-planner delegation to the planner-agent so that Stage 2.6 (Evaluate Roadmap Flag) activates. The skill-planner and planner-agent already have full support for `roadmap_flag` -- only `.claude/commands/plan.md` needs three edits: add the flag to the Options table, add flag parsing in STAGE 1.5, and append `roadmap_flag` to the three STAGE 2 args strings.

### Research Integration

Research report (01_wire-roadmap-flag.md) confirmed:
- Only `.claude/commands/plan.md` requires changes (3 locations)
- `skill-planner/SKILL.md` already has `roadmap_flag` in its delegation context template (line 193)
- `planner-agent.md` Stage 2.6 is fully implemented (lines 78-89) but never triggers
- No extension mirror exists for `plan.md` -- commands are not mirrored in extensions

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md consultation requested (roadmap_flag=false).

## Goals & Non-Goals

**Goals**:
- Enable `/plan N --roadmap` to pass `roadmap_flag=true` through the delegation chain
- Follow existing flag patterns (effort, model, clean) for consistency

**Non-Goals**:
- Wiring `--roadmap` through `skill-team-plan` (deferred to follow-up if needed)
- Changes to skill-planner or planner-agent (already wired)
- Adding `--roadmap` to `/research` or `/implement` commands

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Team mode + roadmap flag not wired | L | M | Document as known gap; defer to follow-up task |
| Args string formatting error | M | L | Verify by inspecting the three args patterns match existing flag style |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |

Phases within the same wave can execute in parallel.

### Phase 1: Add --roadmap flag to plan.md [IN PROGRESS]

**Goal**: Wire the `--roadmap` flag through all three touchpoints in `.claude/commands/plan.md`.

**Tasks**:
- [ ] Add `--roadmap` row to the Options table (~line 35): `| \`--roadmap\` | Include ROADMAP.md review/update phases in plan | false |`
- [ ] Add Step 6 "Extract Roadmap Flag" to STAGE 1.5 (~line 312), following the pattern of Step 5 (Extract Clean Flag): check for `--roadmap` in remaining args, set `roadmap_flag = true` if present, default to `false`
- [ ] Append `roadmap_flag={roadmap_flag}` to the team mode args string (~line 387)
- [ ] Append `roadmap_flag={roadmap_flag}` to the extension-routed args string (~line 391)
- [ ] Append `roadmap_flag={roadmap_flag}` to the default single-agent args string (~line 395)
- [ ] Verify the three args strings are consistent and follow existing flag patterns

**Timing**: 15 minutes

**Depends on**: none

**Files to modify**:
- `.claude/commands/plan.md` - Add flag to Options table, STAGE 1.5 parsing, and STAGE 2 args strings

**Verification**:
- `grep -c "roadmap" .claude/commands/plan.md` returns >= 5 (option row + step 6 + 3 args strings)
- The Options table has a `--roadmap` row
- STAGE 1.5 has a Step 6 for roadmap flag extraction
- All three STAGE 2 args strings end with `roadmap_flag={roadmap_flag}`

---

## Testing & Validation

- [ ] Verify `--roadmap` appears in the Options table
- [ ] Verify STAGE 1.5 has Step 6 extracting the roadmap flag
- [ ] Verify all three STAGE 2 args strings include `roadmap_flag={roadmap_flag}`
- [ ] Confirm no other files need changes (skill-planner and planner-agent already wired)

## Artifacts & Outputs

- `.claude/commands/plan.md` (modified) - /plan command with --roadmap flag support

## Rollback/Contingency

Revert the single file with `git checkout -- .claude/commands/plan.md`. No other files are modified.
