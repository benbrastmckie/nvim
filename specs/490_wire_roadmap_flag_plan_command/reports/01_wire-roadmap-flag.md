# Research Report: Task #490

- **Task**: 490 - wire_roadmap_flag_plan_command
- **Started**: 2026-04-25T00:00:00Z
- **Completed**: 2026-04-25T00:00:00Z
- **Effort**: 0.5 hours
- **Dependencies**: None
- **Sources/Inputs**:
  - `.claude/commands/plan.md` - /plan command definition
  - `.claude/skills/skill-planner/SKILL.md` - Planner skill delegation wrapper
  - `.claude/agents/planner-agent.md` - Planner agent with Stage 2.6
  - `.claude/context/formats/roadmap-format.md` - ROADMAP.md format standard
  - `.claude/commands/research.md` - /research command (comparison)
  - `.claude/skills/skill-researcher/SKILL.md` - Researcher skill (comparison)
- **Artifacts**:
  - `specs/490_wire_roadmap_flag_plan_command/reports/01_wire-roadmap-flag.md` (this file)
- **Standards**: report-format.md, status-markers.md, artifact-management.md, tasks.md

## Executive Summary

- The planner-agent's Stage 2.6 (Evaluate Roadmap Flag) is fully implemented and ready to activate, but never receives `roadmap_flag=true` because the /plan command does not parse `--roadmap`
- The skill-planner SKILL.md already includes `roadmap_flag` in its delegation context JSON template (line 193), but the value is always `false` because nothing upstream sets it
- The /plan command (`plan.md`) needs a `--roadmap` flag added to its Options table and STAGE 1.5 flag parsing section
- The /plan command's STAGE 2 delegation args strings need `roadmap_flag={roadmap_flag}` appended
- Three files need changes: `plan.md` (primary), and the extension mirror `extensions/core/commands/plan.md` if it exists
- The skill-planner and planner-agent require zero changes -- they are already wired

## Context & Scope

The task is to wire the `--roadmap` flag from the /plan command through the delegation chain so that planner-agent Stage 2.6 activates. Stage 2.6 adds two wrapping phases to plans: a ROADMAP.md review phase at the start and a ROADMAP.md update phase at the end.

Currently, `roadmap_path` (always set to `specs/ROADMAP.md`) flows through the entire chain and powers Stage 2.5 (read-only roadmap consultation). The `roadmap_flag` is the opt-in trigger for the more impactful Stage 2.6 behavior.

## Findings

### Finding 1: The /plan command has no --roadmap flag

**File**: `.claude/commands/plan.md`

The Options table (lines 25-35) lists these flags: `--team`, `--team-size N`, `--fast`, `--hard`, `--haiku`, `--sonnet`, `--opus`, `--clean`. There is no `--roadmap` entry.

STAGE 1.5: PARSE FLAGS (lines 272-314) has five numbered steps:
1. Extract Team Options
2. Validate Team Size
3. Extract Effort Flags
4. Extract Model Flags
5. Extract Clean Flag

There is no step for extracting a `--roadmap` flag.

### Finding 2: The /plan command's STAGE 2 delegation args omit roadmap_flag

**File**: `.claude/commands/plan.md`, lines 383-396

The three `args:` strings (team mode, extension-routed, default single-agent) all follow this pattern:
```
args: "task_number={N} research_path={path} prior_plan_path={path} session_id={session_id} effort_flag={effort_flag} model_flag={model_flag} clean_flag={clean_flag}"
```

None include `roadmap_flag=...`.

### Finding 3: skill-planner already expects roadmap_flag

**File**: `.claude/skills/skill-planner/SKILL.md`, line 193

The delegation context JSON template already includes:
```json
"roadmap_flag": "{roadmap_flag from command, false if not set}",
```

The skill is prepared to pass it through. Since the command never sets the variable, the template placeholder resolves to `false` (or remains unset).

### Finding 4: planner-agent Stage 2.6 is fully implemented

**File**: `.claude/agents/planner-agent.md`, lines 78-89

Stage 2.6 checks `if roadmap_flag is true in the delegation context` and adds:
- First phase: "Review and Snapshot ROADMAP.md"
- Last phase: "Update ROADMAP.md" with completion annotations

This is complete and functional -- it just never triggers because `roadmap_flag` is never `true`.

### Finding 5: roadmap_path already flows through the entire chain

Both skill-planner (line 196) and skill-researcher (line 167) hardcode `"roadmap_path": "specs/ROADMAP.md"` in their delegation contexts. The planner-agent's Stage 2.5 already loads ROADMAP.md via `roadmap_path`. The `roadmap_flag` is a separate, additive behavior on top of this.

### Finding 6: Extension mirrors need matching changes

The extension core mirrors exist at:
- `.claude/extensions/core/skills/skill-planner/SKILL.md` (already has `roadmap_flag` at line 193)
- `.claude/extensions/core/agents/planner-agent.md` (already has Stage 2.6)

The command file `.claude/commands/plan.md` may or may not have an extension mirror. A check shows no `extensions/core/commands/plan.md` exists (commands are not mirrored in extensions). Only `plan.md` in `.claude/commands/` needs editing.

### Finding 7: The team-plan skill also needs consideration

When `--team --roadmap` is used together, the `skill-team-plan` receives the args. The team plan args string (line 387) would also need `roadmap_flag={roadmap_flag}`. The team-plan skill would need to pass it through to each teammate agent.

## Decisions

- The implementation should mirror the existing flag patterns (effort, model, clean) for consistency
- `roadmap_flag` should default to `false` (matching the existing template comment)
- The flag is boolean (no value argument), following the same pattern as `--team` and `--clean`

## Recommendations

### Change 1: Add --roadmap to Options table in plan.md

Insert a row in the Options table after `--clean`:

```markdown
| `--roadmap` | Include ROADMAP.md review/update phases in plan | false |
```

### Change 2: Add Step 6 to STAGE 1.5 in plan.md

After step 5 (Extract Clean Flag), add:

```markdown
6. **Extract Roadmap Flag**
   Check remaining args for roadmap phase injection:
   - `--roadmap` -> `roadmap_flag = true` (add ROADMAP.md review/update phases to plan)

   If not present: `roadmap_flag = false`
```

### Change 3: Append roadmap_flag to all three args strings in STAGE 2

For each of the three skill invocation patterns (team, extension, default), append `roadmap_flag={roadmap_flag}` to the args string.

Before:
```
args: "... clean_flag={clean_flag}"
```

After:
```
args: "... clean_flag={clean_flag} roadmap_flag={roadmap_flag}"
```

This applies to lines 387, 391, and 395.

### Change 4 (Optional): Wire through skill-team-plan

If `--team --roadmap` should work together, `skill-team-plan` would need to:
1. Parse `roadmap_flag` from its args
2. Pass it in delegation context to each teammate agent

This is a secondary concern and could be deferred to a follow-up task.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Team mode + roadmap flag not wired | L | M | Document as known gap; defer to follow-up if needed |
| Multi-task dispatch doesn't pass flag | L | M | Multi-task dispatch reuses single-task flag parsing; flags flow through naturally |
| ROADMAP.md doesn't exist when flag used | L | L | Stage 2.6 already handles this: "log a warning and proceed without roadmap phases" |

## Appendix

### Files requiring changes

| File | Change | Lines affected |
|------|--------|---------------|
| `.claude/commands/plan.md` | Add `--roadmap` to Options table | ~line 35 |
| `.claude/commands/plan.md` | Add Step 6 to STAGE 1.5 | ~line 312 |
| `.claude/commands/plan.md` | Append `roadmap_flag` to 3 args strings | lines 387, 391, 395 |

### Files requiring NO changes (already wired)

| File | Reason |
|------|--------|
| `.claude/skills/skill-planner/SKILL.md` | Already has `roadmap_flag` in delegation context (line 193) |
| `.claude/agents/planner-agent.md` | Stage 2.6 fully implemented (lines 78-89) |
| `.claude/extensions/core/skills/skill-planner/SKILL.md` | Mirror already has `roadmap_flag` (line 193) |
| `.claude/extensions/core/agents/planner-agent.md` | Mirror already has Stage 2.6 (lines 78-89) |
| `.claude/context/formats/roadmap-format.md` | Format reference, no changes needed |
