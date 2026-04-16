# Implementation Plan: Task #455

- **Task**: 455 - Separate model/effort flags, add --haiku and --sonnet
- **Status**: [IMPLEMENTING]
- **Effort**: 3 hours
- **Dependencies**: None
- **Research Inputs**: specs/455_separate_model_effort_flags_add_haiku_sonnet/reports/01_model-effort-flags-research.md
- **Artifacts**: plans/01_model-effort-flags-plan.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Refactor the command flag system across `/research`, `/implement`, and `/plan` to separate two currently conflated concerns: model selection (which model family to use: --haiku, --sonnet, --opus) and effort level (how deeply the model reasons: --fast, --hard). Currently `--fast` maps to Sonnet and `--hard`/`--opus` both map to Opus, merging model choice and effort into a single dimension. This plan also fixes the documentation inconsistency where `agent-frontmatter-standard.md` claims agents default to Sonnet while all agents actually declare `model: opus`.

### Research Integration

Key findings from the research report:
- All 7 core agents and all 20+ extension agents declare `model: opus` in frontmatter, contradicting agent-frontmatter-standard.md which claims Sonnet defaults
- The `/plan` command is missing model flags entirely (no `--fast`, `--hard`, or `--opus`)
- Team skills hardcode `model: "sonnet"` instead of accepting a model_flag parameter
- Extension commands do not parse model flags and need no changes
- The effort_flag dimension is a "soft signal" since Claude Code's Task tool has no effort parameter -- it will be passed as prompt context

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

- Advances "Agent frontmatter validation" roadmap item (Phase 1 > Agent System Quality) by fixing the documentation inconsistency between agent-frontmatter-standard.md and actual agent frontmatter values
- Advances "Subagent-return reference cleanup" spirit by sweeping stale comments about model defaults across command and skill files

## Goals & Non-Goals

**Goals**:
- Separate model selection (--haiku, --sonnet, --opus) from effort level (--fast, --hard) into two independent flag dimensions
- Add missing --haiku and --sonnet model flags to all three commands
- Add model flags to /plan command (currently missing entirely)
- Update team skills to accept and pass through model_flag instead of hardcoding sonnet
- Fix agent-frontmatter-standard.md to match reality (all agents use opus, not sonnet)
- Update CLAUDE.md documentation tables to reflect new flag system

**Non-Goals**:
- Changing actual agent frontmatter model values (they stay as opus)
- Adding model flags to extension commands (they use their own frontmatter model)
- Implementing runtime effort-level enforcement in the Task tool (effort is prompt-level guidance only)
- Changing the --team flag behavior or team skill orchestration logic

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Backward compatibility: --fast no longer implies Sonnet | M | H | Document clearly; users can use --fast --sonnet for old behavior |
| Effort flag has no runtime enforcement | L | H | Pass as prompt context; document as soft signal |
| Haiku may not be valid Task tool model | M | M | Add --haiku to commands but note it depends on Claude Code support; validate before release |
| Stale comments/references missed during sweep | L | M | Grep-based validation in final phase catches stragglers |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3 | 1 |
| 3 | 4 | 2, 3 |

Phases within the same wave can execute in parallel.

### Phase 1: Update agent-frontmatter-standard.md and CLAUDE.md documentation [COMPLETED]

- **Goal:** Fix documentation inconsistencies and establish the two-dimensional flag system as the documented standard before changing any command/skill code
- **Tasks:**
  - [ ] Update `.claude/docs/reference/standards/agent-frontmatter-standard.md`:
    - Fix "Default Policy" section: change "Non-Lean agents default to Sonnet" to reflect reality that all agents declare `model: opus`
    - Update "Values" table to include `haiku` as a valid model value
    - Rewrite "Runtime Override Flags" section to show two dimensions: effort flags (--fast, --hard) and model flags (--haiku, --sonnet, --opus)
    - Update validation rules to allow `haiku` as a model value
    - Fix example frontmatter blocks that show `model: sonnet` for non-Lean agents to show `model: opus`
    - Remove "Migration" section note about task 442 migrating to sonnet (this is incorrect)
  - [ ] Update `.claude/CLAUDE.md`:
    - Update Command Reference usage hints to show model flags on /plan (add `[--fast|--hard] [--haiku|--sonnet|--opus]`)
    - Update Model Enforcement paragraph to describe two-dimensional system
    - Update Skill-to-Agent Mapping table: fix skill-implementer model column from `-` to `opus`
- **Timing:** 45 minutes
- **Depends on:** none
- **Files to modify:**
  - `.claude/docs/reference/standards/agent-frontmatter-standard.md` - Rewrite default policy, flags section, examples, validation
  - `.claude/CLAUDE.md` - Update command reference table, model enforcement paragraph, skill-to-agent table
- **Verification:**
  - No references to "Non-Lean agents default to Sonnet" remain in agent-frontmatter-standard.md
  - `/plan` shows model flags in CLAUDE.md command reference
  - Validation rules list haiku, sonnet, opus as valid model values

---

### Phase 2: Update command files (research.md, implement.md, plan.md) [COMPLETED]

- **Goal:** Rewrite flag parsing in all three commands to separate effort flags from model flags, and add --haiku/--sonnet as new model flags
- **Tasks:**
  - [ ] Update `.claude/commands/research.md`:
    - Update frontmatter `argument-hint` to show both dimensions: `[--fast|--hard] [--haiku|--sonnet|--opus]`
    - Update Options table to list effort flags and model flags as separate groups
    - Rewrite STAGE 1.5 step 3 "Extract Model Override Flags" to become two steps: "Extract Effort Flags" (--fast -> effort_flag="fast", --hard -> effort_flag="hard") and "Extract Model Flags" (--haiku -> model_flag="haiku", --sonnet -> model_flag="sonnet", --opus -> model_flag="opus")
    - Update step 4 to also remove --haiku and --sonnet from remaining args
    - Update STAGE 2 model passthrough: model_flag="haiku" -> model: haiku, model_flag="sonnet" -> model: sonnet, model_flag="opus" -> model: opus, model_flag=null -> omit (use agent default)
    - Add effort_flag to skill invocation args
    - Fix stale comment "use agent default, which is Sonnet" to "use agent default (currently opus for all agents)"
  - [ ] Update `.claude/commands/implement.md`:
    - Same changes as research.md (frontmatter, Options table, STAGE 1.5, STAGE 2 passthrough)
    - Keep --force flag handling unchanged
  - [ ] Update `.claude/commands/plan.md`:
    - Add model/effort flags to frontmatter `argument-hint`: `[--team [--team-size N]] [--fast|--hard] [--haiku|--sonnet|--opus]`
    - Add Options table entries for effort and model flags
    - Add "Extract Effort Flags" and "Extract Model Flags" steps to STAGE 1.5
    - Add model_flag and effort_flag to STAGE 2 skill invocation args
    - Update Options table to include new flags
- **Timing:** 1 hour
- **Depends on:** 1
- **Files to modify:**
  - `.claude/commands/research.md` - Frontmatter, Options table, STAGE 1.5, STAGE 2
  - `.claude/commands/implement.md` - Frontmatter, Options table, STAGE 1.5, STAGE 2
  - `.claude/commands/plan.md` - Frontmatter, Options table, add STAGE 1.5 flag steps, STAGE 2
- **Verification:**
  - All three commands parse --fast, --hard as effort flags and --haiku, --sonnet, --opus as model flags
  - /plan now passes model_flag and effort_flag to skills
  - No references to "--fast uses Sonnet" or "--hard uses Opus" remain in command files
  - grep for "which is Sonnet" returns zero matches in command files

---

### Phase 3: Update skill files (3 single-agent + 3 team skills) [COMPLETED]

- **Goal:** Update skills to accept, interpret, and pass through both effort_flag and model_flag independently
- **Tasks:**
  - [ ] Update `.claude/skills/skill-researcher/SKILL.md`:
    - Add effort_flag and model_flag to input parameters / delegation context documentation
    - Ensure both flags are passed through to the agent spawn (Task tool invocation)
  - [ ] Update `.claude/skills/skill-implementer/SKILL.md`:
    - Same changes as skill-researcher
  - [ ] Update `.claude/skills/skill-planner/SKILL.md`:
    - Add effort_flag and model_flag to input parameters (currently has neither)
    - Add passthrough to agent spawn
  - [ ] Update `.claude/skills/skill-team-research/SKILL.md`:
    - Add model_flag to input parameters
    - Replace hardcoded `default_model="sonnet"` in Stage 5b with logic that uses model_flag if provided, otherwise uses agent frontmatter default
    - Update `model_preference_line` generation to use model_flag value
  - [ ] Update `.claude/skills/skill-team-implement/SKILL.md`:
    - Add model_flag to input parameters
    - Update teammate prompt model_preference_line to use model_flag
  - [ ] Update `.claude/skills/skill-team-plan/SKILL.md`:
    - Add model_flag to input parameters
    - Update teammate prompt model_preference_line to use model_flag
- **Timing:** 45 minutes
- **Depends on:** 1
- **Files to modify:**
  - `.claude/skills/skill-researcher/SKILL.md` - Add effort_flag/model_flag parameters
  - `.claude/skills/skill-implementer/SKILL.md` - Add effort_flag/model_flag parameters
  - `.claude/skills/skill-planner/SKILL.md` - Add effort_flag/model_flag parameters
  - `.claude/skills/skill-team-research/SKILL.md` - Add model_flag, replace hardcoded sonnet
  - `.claude/skills/skill-team-implement/SKILL.md` - Add model_flag, update model_preference_line
  - `.claude/skills/skill-team-plan/SKILL.md` - Add model_flag, update model_preference_line
- **Verification:**
  - No hardcoded "sonnet" model selection remains in team skills (except as fallback default)
  - All single-agent skills accept and pass through both effort_flag and model_flag
  - skill-planner now accepts model flags (previously had none)

---

### Phase 4: Validation and cross-reference sweep [COMPLETED]

- **Goal:** Verify no stale references to the old single-dimension flag mapping remain anywhere in the codebase, and confirm the new system is internally consistent
- **Tasks:**
  - [ ] Grep for stale patterns across all .claude/ files:
    - `"which is Sonnet"` -- old default comment
    - `"alias for --hard"` -- old --opus description
    - `"uses Sonnet, explicit low-cost"` -- old --fast description
    - `"uses Opus, explicit high-effort"` -- old --hard description
    - `"Non-Lean agents default to Sonnet"` -- old frontmatter standard
  - [ ] Verify consistency between command files and CLAUDE.md:
    - All three commands list the same flag set
    - CLAUDE.md command reference matches actual command argument-hints
  - [ ] Verify team skills use model_flag correctly:
    - No hardcoded model selection that ignores the flag
  - [ ] Fix any stale references found during the sweep
- **Timing:** 30 minutes
- **Depends on:** 2, 3
- **Files to modify:**
  - Any files with stale references discovered during grep sweep
- **Verification:**
  - All stale-pattern greps return zero matches
  - /research, /implement, /plan all have identical flag documentation structure
  - CLAUDE.md command table shows flags for all three commands

## Testing & Validation

- [ ] Grep `.claude/` for "which is Sonnet" -- expect 0 matches
- [ ] Grep `.claude/` for "alias for --hard" -- expect 0 matches
- [ ] Grep `.claude/` for "Non-Lean agents default to Sonnet" -- expect 0 matches
- [ ] Verify all three command files have both effort and model flag parsing in STAGE 1.5
- [ ] Verify all three command files pass effort_flag and model_flag in STAGE 2 delegation
- [ ] Verify agent-frontmatter-standard.md lists haiku, sonnet, opus as valid model values
- [ ] Verify CLAUDE.md command reference shows model flags for /plan
- [ ] Verify team skill files accept model_flag parameter

## Artifacts & Outputs

- Updated `.claude/docs/reference/standards/agent-frontmatter-standard.md` (corrected documentation)
- Updated `.claude/CLAUDE.md` (updated command reference and model enforcement)
- Updated `.claude/commands/research.md` (two-dimensional flag parsing)
- Updated `.claude/commands/implement.md` (two-dimensional flag parsing)
- Updated `.claude/commands/plan.md` (added model/effort flags)
- Updated 3 single-agent skill files (effort_flag/model_flag passthrough)
- Updated 3 team skill files (model_flag acceptance, removed hardcoded sonnet)

## Rollback/Contingency

All changes are to documentation and command/skill definition files within `.claude/`. If the new flag system causes issues:
1. Revert the commit(s) with `git revert`
2. The old single-dimension flag system will be restored immediately
3. No runtime code, Lua files, or Neovim configuration is affected -- this is purely agent infrastructure
