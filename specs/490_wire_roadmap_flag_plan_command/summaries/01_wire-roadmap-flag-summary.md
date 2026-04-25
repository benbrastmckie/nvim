# Implementation Summary: Wire --roadmap Flag to /plan Command
- **Task**: 490 - wire_roadmap_flag_plan_command
- **Status**: [COMPLETED]
- **Started**: 2026-04-25T16:37:00Z
- **Completed**: 2026-04-25T16:50:00Z
- **Artifacts**: plans/01_wire-roadmap-flag.md

## Overview
Wired the `--roadmap` flag from the `/plan` command through the skill-planner delegation chain to the planner-agent. The skill-planner and planner-agent already had full `roadmap_flag` support; only `.claude/commands/plan.md` needed edits.

## What Changed
- Added `--roadmap` row to Options table in `plan.md` (after `--clean`)
- Added Step 6 "Extract Roadmap Flag" to STAGE 1.5 flag parsing
- Appended `roadmap_flag={roadmap_flag}` to all 3 STAGE 2 args strings (team, extension, default)

## Decisions
- Followed existing flag patterns (clean, effort, model) for consistency
- Boolean flag with `false` default, no value argument
- Team mode `--roadmap` wiring deferred (team-plan skill would need separate update)

## Impacts
- `/plan N --roadmap` now passes `roadmap_flag=true` to planner-agent
- Planner-agent Stage 2.6 will activate, adding ROADMAP.md review/update phases to plans
- No backward compatibility issues (flag defaults to false)

## Follow-ups
- Task 493: Strengthen per-phase ROADMAP.md updates in planner-agent Stage 2.6
- Wire `--roadmap` through skill-team-plan if team mode + roadmap is needed

## References
- `.claude/commands/plan.md` (modified)
- `.claude/skills/skill-planner/SKILL.md` (already wired, no changes)
- `.claude/agents/planner-agent.md` (Stage 2.6 already implemented, no changes)
