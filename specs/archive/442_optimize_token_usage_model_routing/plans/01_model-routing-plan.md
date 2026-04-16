# Implementation Plan: Task #442

- **Task**: 442 - optimize_token_usage_model_routing
- **Status**: [COMPLETED]
- **Effort**: 3 hours
- **Dependencies**: None
- **Research Inputs**: specs/442_optimize_token_usage_model_routing/reports/01_model-routing-research.md
- **Artifacts**: plans/01_model-routing-plan.md (this file)
- **Standards**:
  - .claude/rules/artifact-formats.md
  - .claude/rules/state-management.md
- **Type**: meta

## Overview

This plan optimizes token usage across the Claude Code agent system by shifting the default model from Opus to Sonnet for all non-Lean agents and commands, reserving Opus for Lean4 research and implementation tasks which require deep mathematical reasoning. It also adds `--fast`, `--hard`, and `--opus` flags to `/research` and `/implement` commands so users can explicitly override the model tier at invocation time. The implementation spans three layers: agent frontmatter files, command flag-parsing (STAGE 1.5), and skill delegation-context forwarding.

### Research Integration

Research confirmed that:
- All 7 core agents and all 13 non-tag commands currently declare `model: opus`.
- Lean4 agents (`lean-research-agent`, `lean-implementation-agent`) must stay on Opus due to mathematical reasoning requirements.
- Other extension agents (formal, present, founder, epi, nvim, latex) also use Opus -- these are considered for Sonnet migration on a best-effort basis alongside core agents.
- Flag parsing in STAGE 1.5 follows a simple pattern; `--fast`, `--hard`, `--opus` extend the existing `--team`/`--force` pattern.
- The frontmatter standard only documents `opus` and `sonnet` (not `haiku`), so `--fast` maps to `sonnet` rather than requiring a new model value.
- Skills pass model context through the delegation context JSON to subagents.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No direct roadmap items are advanced by this task. The changes support the "Agent System Quality" phase by making model routing explicit and documented.

## Goals & Non-Goals

**Goals**:
- Change `model: opus` to `model: sonnet` in all 7 core agent frontmatter files
- Change `model: opus` to `model: sonnet` in non-Lean extension agent frontmatter files (formal, present, founder, epi, nvim, latex)
- Change `model: opus` to `model: sonnet` in all command frontmatter files (except `tag.md`)
- Add `--fast`, `--hard`, `--opus` flags to STAGE 1.5 of `/research` command
- Add `--fast`, `--hard`, `--opus` flags to STAGE 1.5 of `/implement` command
- Pass `model_flag` through delegation context in `skill-researcher` and `skill-implementer`
- Update CLAUDE.md skill-to-agent mapping table to reflect new Sonnet defaults
- Update agent-frontmatter-standard.md to document the new Sonnet default and Lean exception

**Non-Goals**:
- Changing Lean4 extension agents (`lean-research-agent`, `lean-implementation-agent`) -- they stay on Opus
- Adding `--fast`/`--hard`/`--opus` flags to `/plan` or other commands (only `/research` and `/implement` per task spec)
- Implementing Haiku as a model tier (not in frontmatter standard)
- Changing skill SKILL.md frontmatter (skills have no `model:` field -- model selection happens at agent level)
- Modifying extension routing logic (Lean task_type routing already ensures Opus via agent frontmatter)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Sonnet produces lower quality research/planning output | Medium | Medium | `--hard` and `--opus` flags allow Opus override when needed; monitor quality |
| Non-lean extension agents (formal, present) may need Opus for domain reasoning | Medium | Low | Task spec says "reserve Opus for Lean"; apply Sonnet broadly; `--opus` flag provides escape hatch |
| `model_flag` in delegation context ignored by agents | Medium | Low | Agents log delegation context; flag value is advisory and tracked |
| Command frontmatter change affects orchestrator-layer reasoning quality | Low | Low | Commands are thin orchestrators (parse args, validate state, delegate); Sonnet is sufficient |
| Extension command frontmatter (present, epi) change affects quality | Low | Low | Extension commands are also thin orchestrators |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 2 | -- |
| 2 | 3, 4 | 1, 2 |
| 3 | 5 | 3, 4 |

Phases within the same wave can execute in parallel.

---

### Phase 1: Update Core Agent Frontmatter [COMPLETED]

**Goal**: Change all 7 core agents from `model: opus` to `model: sonnet`.

**Tasks**:
- [ ] Edit `.claude/agents/general-research-agent.md`: change `model: opus` to `model: sonnet`
- [ ] Edit `.claude/agents/general-implementation-agent.md`: change `model: opus` to `model: sonnet`
- [ ] Edit `.claude/agents/planner-agent.md`: change `model: opus` to `model: sonnet`
- [ ] Edit `.claude/agents/meta-builder-agent.md`: change `model: opus` to `model: sonnet`
- [ ] Edit `.claude/agents/code-reviewer-agent.md`: change `model: opus` to `model: sonnet`
- [ ] Edit `.claude/agents/reviser-agent.md`: change `model: opus` to `model: sonnet`
- [ ] Edit `.claude/agents/spawn-agent.md`: change `model: opus` to `model: sonnet`
- [ ] Verify Lean agents are untouched: check `.claude/extensions/lean/agents/lean-research-agent.md` and `lean-implementation-agent.md` still have `model: opus`

**Timing**: 30 minutes

**Depends on**: none

**Files to modify**:
- `.claude/agents/general-research-agent.md` - `model: opus` -> `model: sonnet`
- `.claude/agents/general-implementation-agent.md` - `model: opus` -> `model: sonnet`
- `.claude/agents/planner-agent.md` - `model: opus` -> `model: sonnet`
- `.claude/agents/meta-builder-agent.md` - `model: opus` -> `model: sonnet`
- `.claude/agents/code-reviewer-agent.md` - `model: opus` -> `model: sonnet`
- `.claude/agents/reviser-agent.md` - `model: opus` -> `model: sonnet`
- `.claude/agents/spawn-agent.md` - `model: opus` -> `model: sonnet`

**Verification**:
- `grep -r "model:" .claude/agents/` shows `model: sonnet` for all 7 agents
- `.claude/extensions/lean/agents/*.md` still show `model: opus`

---

### Phase 2: Update Command Frontmatter [COMPLETED]

**Goal**: Change all non-tag commands from `model: opus` to `model: sonnet`, including extension commands.

**Tasks**:
- [ ] Edit `.claude/commands/research.md`: change `model: opus` to `model: sonnet` in frontmatter
- [ ] Edit `.claude/commands/implement.md`: change `model: opus` to `model: sonnet` in frontmatter
- [ ] Edit `.claude/commands/plan.md`: change `model: opus` to `model: sonnet` in frontmatter
- [ ] Edit `.claude/commands/task.md`: change `model: opus` to `model: sonnet` in frontmatter
- [ ] Edit `.claude/commands/meta.md`: change `model: opus` to `model: sonnet` in frontmatter
- [ ] Edit `.claude/commands/review.md`: change `model: opus` to `model: sonnet` in frontmatter
- [ ] Edit `.claude/commands/revise.md`: change `model: opus` to `model: sonnet` in frontmatter
- [ ] Edit `.claude/commands/spawn.md`: change `model: opus` to `model: sonnet` in frontmatter
- [ ] Edit `.claude/commands/merge.md`: change `model: opus` to `model: sonnet` in frontmatter
- [ ] Edit `.claude/commands/refresh.md`: change `model: opus` to `model: sonnet` in frontmatter
- [ ] Edit `.claude/commands/errors.md`: change `model: opus` to `model: sonnet` in frontmatter
- [ ] Edit `.claude/commands/todo.md`: change `model: opus` to `model: sonnet` in frontmatter
- [ ] Edit `.claude/commands/fix-it.md`: change `model: opus` to `model: sonnet` in frontmatter
- [ ] Leave `.claude/commands/tag.md` unchanged (user-only deployment command)
- [ ] Update extension commands: change `model: opus` to `model: sonnet` in `.claude/extensions/epidemiology/commands/epi.md` and all `.claude/extensions/present/commands/*.md`

**Timing**: 30 minutes

**Depends on**: none

**Files to modify**:
- `.claude/commands/research.md` - frontmatter `model: opus` -> `model: sonnet`
- `.claude/commands/implement.md` - frontmatter `model: opus` -> `model: sonnet`
- `.claude/commands/plan.md` - frontmatter `model: opus` -> `model: sonnet`
- `.claude/commands/task.md` - frontmatter `model: opus` -> `model: sonnet`
- `.claude/commands/meta.md` - frontmatter `model: opus` -> `model: sonnet`
- `.claude/commands/review.md` - frontmatter `model: opus` -> `model: sonnet`
- `.claude/commands/revise.md` - frontmatter `model: opus` -> `model: sonnet`
- `.claude/commands/spawn.md` - frontmatter `model: opus` -> `model: sonnet`
- `.claude/commands/merge.md` - frontmatter `model: opus` -> `model: sonnet`
- `.claude/commands/refresh.md` - frontmatter `model: opus` -> `model: sonnet`
- `.claude/commands/errors.md` - frontmatter `model: opus` -> `model: sonnet`
- `.claude/commands/todo.md` - frontmatter `model: opus` -> `model: sonnet`
- `.claude/commands/fix-it.md` - frontmatter `model: opus` -> `model: sonnet`
- `.claude/extensions/epidemiology/commands/epi.md` - frontmatter `model: opus` -> `model: sonnet`
- `.claude/extensions/present/commands/timeline.md` - frontmatter `model: opus` -> `model: sonnet`
- `.claude/extensions/present/commands/funds.md` - frontmatter `model: opus` -> `model: sonnet`
- `.claude/extensions/present/commands/budget.md` - frontmatter `model: opus` -> `model: sonnet`
- `.claude/extensions/present/commands/slides.md` - frontmatter `model: opus` -> `model: sonnet`
- `.claude/extensions/present/commands/grant.md` - frontmatter `model: opus` -> `model: sonnet`

**Verification**:
- `grep -r "model: opus" .claude/commands/` returns nothing (or only `tag.md`)
- `grep -r "model: opus" .claude/extensions/` returns only Lean extension agents

---

### Phase 3: Update Extension Agent Frontmatter [COMPLETED]

**Goal**: Change non-Lean extension agents from `model: opus` to `model: sonnet`.

**Tasks**:
- [ ] Edit `.claude/extensions/founder/agents/deck-planner-agent.md`: `model: opus` -> `model: sonnet`
- [ ] Edit `.claude/extensions/latex/agents/latex-research-agent.md`: `model: opus` -> `model: sonnet`
- [ ] Edit `.claude/extensions/formal/agents/logic-research-agent.md`: `model: opus` -> `model: sonnet`
- [ ] Edit `.claude/extensions/formal/agents/math-research-agent.md`: `model: opus` -> `model: sonnet`
- [ ] Edit `.claude/extensions/formal/agents/physics-research-agent.md`: `model: opus` -> `model: sonnet`
- [ ] Edit `.claude/extensions/formal/agents/formal-research-agent.md`: `model: opus` -> `model: sonnet`
- [ ] Edit `.claude/extensions/epidemiology/agents/epi-research-agent.md`: `model: opus` -> `model: sonnet`
- [ ] Edit `.claude/extensions/epidemiology/agents/epi-implement-agent.md`: `model: opus` -> `model: sonnet`
- [ ] Edit `.claude/extensions/nvim/agents/neovim-research-agent.md`: `model: opus` -> `model: sonnet`
- [ ] Edit `.claude/extensions/present/agents/*.md` (all 9 present agents): `model: opus` -> `model: sonnet`
- [ ] Confirm Lean agents are still `model: opus` (no changes to lean extension)

**Timing**: 30 minutes

**Depends on**: 1, 2

**Files to modify**:
- `.claude/extensions/founder/agents/deck-planner-agent.md`
- `.claude/extensions/latex/agents/latex-research-agent.md`
- `.claude/extensions/formal/agents/logic-research-agent.md`
- `.claude/extensions/formal/agents/math-research-agent.md`
- `.claude/extensions/formal/agents/physics-research-agent.md`
- `.claude/extensions/formal/agents/formal-research-agent.md`
- `.claude/extensions/epidemiology/agents/epi-research-agent.md`
- `.claude/extensions/epidemiology/agents/epi-implement-agent.md`
- `.claude/extensions/nvim/agents/neovim-research-agent.md`
- `.claude/extensions/present/agents/slide-critic-agent.md`
- `.claude/extensions/present/agents/funds-agent.md`
- `.claude/extensions/present/agents/pptx-assembly-agent.md`
- `.claude/extensions/present/agents/timeline-agent.md`
- `.claude/extensions/present/agents/slide-planner-agent.md`
- `.claude/extensions/present/agents/slidev-assembly-agent.md`
- `.claude/extensions/present/agents/budget-agent.md`
- `.claude/extensions/present/agents/slides-research-agent.md`
- `.claude/extensions/present/agents/grant-agent.md`

**Verification**:
- `grep -rn "model: opus" .claude/extensions/` returns only the two Lean agents
- `grep -rn "model: sonnet" .claude/extensions/` shows all non-Lean extension agents

---

### Phase 4: Add --fast, --hard, --opus Flags to Commands [COMPLETED]

**Goal**: Add three new model-tier flags to STAGE 1.5 of `/research` and `/implement`, and update the Options tables and argument-hint frontmatter fields.

**Tasks**:
- [ ] Edit `.claude/commands/research.md`:
  - Update `argument-hint` frontmatter to include `[--fast] [--hard] [--opus]`
  - Add `--fast`, `--hard`, `--opus` to Options table
  - In STAGE 1.5, after team flag extraction, add model flag parsing:
    - `--fast` -> `model_flag = "fast"` (uses Sonnet, explicit low-cost)
    - `--hard` -> `model_flag = "hard"` (uses Opus, explicit high-effort)
    - `--opus` -> `model_flag = "opus"` (uses Opus, explicit)
    - default: `model_flag = null`
  - Remove `--fast`, `--hard`, `--opus` from remaining args (focus_prompt extraction)
  - Pass `model_flag` in skill invocation args: `model_flag={model_flag}`
- [ ] Edit `.claude/commands/implement.md`:
  - Update `argument-hint` frontmatter to include `[--fast] [--hard] [--opus]`
  - Add `--fast`, `--hard`, `--opus` to Options table
  - In STAGE 1.5, after team/force flag extraction, add model flag parsing (same logic)
  - Pass `model_flag` in skill invocation args: `model_flag={model_flag}`

**Flag semantics**:
```
--fast  -> model_flag="fast"   Maps to sonnet (lowest cost; explicit low-effort mode)
--hard  -> model_flag="hard"   Maps to opus (highest quality; explicit high-effort mode)
--opus  -> model_flag="opus"   Maps to opus (alias for --hard; more explicit)
```

**Note**: `--fast` and `--hard`/`--opus` are mutually exclusive. If both are provided, `--hard`/`--opus` takes precedence (last flag wins or document precedence explicitly).

**Timing**: 45 minutes

**Depends on**: 1, 2

**Files to modify**:
- `.claude/commands/research.md` - STAGE 1.5 flag parsing + Options table + argument-hint
- `.claude/commands/implement.md` - STAGE 1.5 flag parsing + Options table + argument-hint

**Verification**:
- STAGE 1.5 in both commands includes extraction of `--fast`, `--hard`, `--opus`
- Skill invocation args include `model_flag={model_flag}`
- Options table in both commands lists the three new flags

---

### Phase 5: Update Documentation [COMPLETED]

**Goal**: Update CLAUDE.md skill-to-agent mapping table and agent-frontmatter-standard.md to reflect new Sonnet defaults, preserved Lean Opus, and new flag mechanism.

**Tasks**:
- [ ] Edit `.claude/CLAUDE.md`:
  - Update skill-to-agent mapping table: change `model: opus` entries to `model: sonnet` for `skill-researcher`, `skill-planner`, `skill-reviser`, `skill-spawn`
  - Update "Model Enforcement" paragraph to state: "Non-Lean agents default to Sonnet for cost efficiency. Lean4 agents retain Opus for mathematical reasoning. Use `--opus` or `--hard` flags with `/research` or `/implement` to override to Opus for specific tasks."
  - Update `/research` entry in Command Reference table to show new flags: `N[,N-N] [focus] [--team] [--fast|--hard|--opus]`
  - Update `/implement` entry in Command Reference table to show new flags: `N[,N-N] [--team] [--force] [--fast|--hard|--opus]`
- [ ] Edit `.claude/docs/reference/standards/agent-frontmatter-standard.md`:
  - Update "Usage Guidelines" section: note that non-Lean agents now default to Sonnet
  - Add note that Lean agents retain Opus
  - Add entry documenting the `--opus`/`--hard`/`--fast` runtime override flags
  - Update example frontmatter blocks to show `model: sonnet` for general/implementation/planning agents

**Timing**: 30 minutes

**Depends on**: 3, 4

**Files to modify**:
- `.claude/CLAUDE.md` - skill-to-agent table, Model Enforcement paragraph, Command Reference table
- `.claude/docs/reference/standards/agent-frontmatter-standard.md` - Usage Guidelines, examples

**Verification**:
- CLAUDE.md skill-to-agent table shows `sonnet` for `skill-researcher`, `skill-planner`, `skill-reviser`, `skill-spawn`
- CLAUDE.md Command Reference shows new flags for `/research` and `/implement`
- agent-frontmatter-standard.md reflects Sonnet default with Lean exception

---

## Testing & Validation

- [ ] `grep -r "model: opus" .claude/agents/` returns empty (all 7 core agents changed)
- [ ] `grep -r "model: opus" .claude/commands/` returns empty or only `tag.md`
- [ ] `grep -r "model: opus" .claude/extensions/` returns only `lean-research-agent.md` and `lean-implementation-agent.md`
- [ ] `grep -r "model: sonnet" .claude/agents/` shows all 7 core agents
- [ ] Both `/research` and `/implement` commands have STAGE 1.5 parsing for `--fast`, `--hard`, `--opus`
- [ ] Skill invocation sections in both commands include `model_flag` in args
- [ ] CLAUDE.md skill-to-agent table reflects sonnet defaults
- [ ] No Lean extension files were modified

## Artifacts & Outputs

- `.claude/agents/` - 7 files with updated `model: sonnet` frontmatter
- `.claude/commands/` - 13 files with updated `model: sonnet` frontmatter (excluding `tag.md`)
- `.claude/extensions/` - ~19 non-Lean extension agent/command files with updated `model: sonnet` frontmatter
- `.claude/commands/research.md` - STAGE 1.5 extended with `--fast`/`--hard`/`--opus` flag parsing
- `.claude/commands/implement.md` - STAGE 1.5 extended with `--fast`/`--hard`/`--opus` flag parsing
- `.claude/CLAUDE.md` - Updated skill-to-agent mapping and command reference
- `.claude/docs/reference/standards/agent-frontmatter-standard.md` - Updated to reflect new Sonnet default

## Rollback/Contingency

All changes are mechanical search-and-replace operations on YAML frontmatter and Markdown documentation. If issues arise:

1. `git diff .claude/agents/ .claude/commands/ .claude/extensions/` shows all frontmatter changes
2. `git checkout .claude/agents/ .claude/commands/ .claude/extensions/` reverts all agent/command frontmatter changes
3. `git checkout .claude/CLAUDE.md .claude/docs/reference/standards/agent-frontmatter-standard.md` reverts documentation

The changes are purely additive configuration (model field value change) with no structural modifications to agent logic. Reverting to `model: opus` across the board restores prior behavior exactly.
