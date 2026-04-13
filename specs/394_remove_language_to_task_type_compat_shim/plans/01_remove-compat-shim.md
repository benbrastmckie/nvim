# Implementation Plan: Remove language-to-task_type Compatibility Shim

- **Task**: 394 - Remove language-to-task_type backward compatibility shim
- **Status**: [IMPLEMENTING]
- **Effort**: 2 hours
- **Dependencies**: Task 393 (completed)
- **Research Inputs**: specs/394_remove_language_to_task_type_compat_shim/reports/01_remove-compat-shim.md
- **Artifacts**: plans/01_remove-compat-shim.md (this file)
- **Standards**: plan-format.md; status-markers.md; artifact-management.md; tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Task 393 renamed the `language` routing field to `task_type` across the agent system, adding a backward compatibility shim (`.task_type // .language // "general"`) so existing tasks would not break. Research confirms zero active tasks use the old `language` field. This plan removes the shim from 19 core files, updates 18 extension skills and 11 extension commands that still read `.language` directly, and fixes 2 documentation references. Total: 50 files across 4 phases.

### Research Integration

Research identified four categories of changes: (1) 19 core files with the full `.task_type // .language // "general"` shim pattern, (2) 18 extension skills reading `.language` directly (missed during task 393), (3) 11 extension commands reading `.language` bare, and (4) 2 documentation files with stale references. Safety assessment confirmed all 6 active projects already use `task_type`.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

This plan advances the "Subagent-return reference cleanup" roadmap item under Agent System Quality -- it removes stale field references across the system. It also contributes to "Zero stale references to removed/renamed files in `.claude/`" success metric.

## Goals & Non-Goals

**Goals**:
- Remove all `.task_type // .language // "general"` fallback chains, leaving `.task_type // "general"`
- Update extension skills that read `.language` directly to read `.task_type`
- Update extension commands that read `.language` directly to read `.task_type`
- Update downstream `$language` variable references to `$task_type` where applicable
- Fix stale documentation references

**Non-Goals**:
- Modifying archived state.json entries (historical record, never read by active commands)
- Changing any runtime behavior (this is a pure cleanup -- `.task_type` is already populated everywhere)
- Updating the `language` field name in any user-facing documentation that describes the migration history

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Extension skill has downstream `$language` variable usage not caught by simple find-replace | M | M | Grep each file for `$language` after updating the extraction line; update all occurrences |
| A file uses a variant pattern not covered by research categories | L | L | Run a final sweep grep for any remaining `.language` references in `.claude/` after all phases |
| An active task in another worktree still uses `language` field | H | L | Research confirmed 0 active tasks use old field; archive is read-only |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 2, 3 | -- |
| 2 | 4 | 1, 2, 3 |

Phases within the same wave can execute in parallel.

### Phase 1: Remove Shim from Core Files [COMPLETED]

**Goal**: Replace the `.task_type // .language // "general"` fallback chain with `.task_type // "general"` in all 19 core files (commands and skills).

**Tasks**:
- [ ] Update 6 command files: `implement.md`, `plan.md`, `research.md`, `spawn.md`, `task.md`, `todo.md`
- [ ] Update 8 core skill files: `skill-implementer`, `skill-planner`, `skill-researcher`, `skill-reviser`, `skill-spawn`, `skill-team-implement`, `skill-team-plan`, `skill-team-research`
- [ ] Update 5 extension skill files that use the shim pattern: `formal/skill-logic-research`, `lean/skill-lean-implementation`, `lean/skill-lean-research`, `nix/skill-nix-implementation`, `web/skill-web-implementation`
- [ ] Handle the special `todo.md` pattern: replace `(.task_type // .language)` with `.task_type`

**Timing**: 45 minutes

**Depends on**: none

**Files to modify**:
- `.claude/commands/implement.md` - Remove `// .language` from jq expression
- `.claude/commands/plan.md` - Remove `// .language` from jq expression
- `.claude/commands/research.md` - Remove `// .language` from 2 jq expressions
- `.claude/commands/spawn.md` - Remove `// .language` from jq expression
- `.claude/commands/task.md` - Remove `// .language` from jq expression
- `.claude/commands/todo.md` - Remove `// .language` from 4 jq expressions
- `.claude/skills/skill-implementer/SKILL.md` - Remove `// .language` from jq expression
- `.claude/skills/skill-planner/SKILL.md` - Remove `// .language` from jq expression
- `.claude/skills/skill-researcher/SKILL.md` - Remove `// .language` from jq expression
- `.claude/skills/skill-reviser/SKILL.md` - Remove `// .language` from jq expression
- `.claude/skills/skill-spawn/SKILL.md` - Remove `// .language` from jq expression
- `.claude/skills/skill-team-implement/SKILL.md` - Remove `// .language` from jq expression
- `.claude/skills/skill-team-plan/SKILL.md` - Remove `// .language` from jq expression
- `.claude/skills/skill-team-research/SKILL.md` - Remove `// .language` from jq expression
- `.claude/extensions/formal/skills/skill-logic-research/SKILL.md` - Remove `// .language` from jq expression
- `.claude/extensions/lean/skills/skill-lean-implementation/SKILL.md` - Remove `// .language` from jq expression
- `.claude/extensions/lean/skills/skill-lean-research/SKILL.md` - Remove `// .language` from jq expression
- `.claude/extensions/nix/skills/skill-nix-implementation/SKILL.md` - Remove `// .language` from jq expression
- `.claude/extensions/web/skills/skill-web-implementation/SKILL.md` - Remove `// .language` from jq expression

**Verification**:
- `grep -r '.task_type // .language' .claude/` returns zero results
- `grep -r '(.task_type // .language)' .claude/` returns zero results

---

### Phase 2: Update Extension Skills Reading `.language` Directly [IN PROGRESS]

**Goal**: Replace `.language` field reads with `.task_type` in 18 extension skill files that were not updated during task 393, including downstream `$language` variable references.

**Tasks**:
- [ ] Update 10 founder extension skills: replace `.language // "founder"` with `.task_type // "founder"` and `$language` with `$task_type`
- [ ] Update 4 present extension skills: replace `.language // "present"` with `.task_type // "present"` and `$language` with `$task_type`
- [ ] Update 2 nvim extension skills: replace `.language // "neovim"` with `.task_type // "neovim"` and `$language` with `$task_type`
- [ ] Update nix extension skill: replace `.language // "nix"` with `.task_type // "nix"` and `$language` with `$task_type`
- [ ] Update web extension skill: replace `.language // "web"` with `.task_type // "web"` and `$language` with `$task_type`
- [ ] For each file, grep for any remaining `$language` or `.language` references and update

**Timing**: 45 minutes

**Depends on**: none

**Files to modify**:
- `.claude/extensions/founder/skills/skill-analyze/SKILL.md` - `.language` -> `.task_type`, `$language` -> `$task_type`
- `.claude/extensions/founder/skills/skill-deck-research/SKILL.md` - same
- `.claude/extensions/founder/skills/skill-finance/SKILL.md` - same
- `.claude/extensions/founder/skills/skill-financial-analysis/SKILL.md` - same
- `.claude/extensions/founder/skills/skill-legal/SKILL.md` - same
- `.claude/extensions/founder/skills/skill-market/SKILL.md` - same
- `.claude/extensions/founder/skills/skill-meeting/SKILL.md` - same
- `.claude/extensions/founder/skills/skill-project/SKILL.md` - same
- `.claude/extensions/founder/skills/skill-spreadsheet/SKILL.md` - same
- `.claude/extensions/founder/skills/skill-strategy/SKILL.md` - same
- `.claude/extensions/present/skills/skill-budget/SKILL.md` - `.language` -> `.task_type`, `$language` -> `$task_type`
- `.claude/extensions/present/skills/skill-funds/SKILL.md` - same
- `.claude/extensions/present/skills/skill-grant/SKILL.md` - same
- `.claude/extensions/present/skills/skill-timeline/SKILL.md` - same
- `.claude/extensions/nvim/skills/skill-neovim-research/SKILL.md` - `.language` -> `.task_type`, `$language` -> `$task_type`
- `.claude/extensions/nvim/skills/skill-neovim-implementation/SKILL.md` - same
- `.claude/extensions/nix/skills/skill-nix-research/SKILL.md` - `.language` -> `.task_type`, `$language` -> `$task_type`
- `.claude/extensions/web/skills/skill-web-research/SKILL.md` - `.language` -> `.task_type`, `$language` -> `$task_type`

**Verification**:
- `grep -r "\.language" .claude/extensions/*/skills/` returns zero results for jq field access patterns
- `grep -r '\$language' .claude/extensions/*/skills/` returns zero results

---

### Phase 3: Update Extension Commands Reading `.language` Bare [NOT STARTED]

**Goal**: Replace `.language` field reads with `.task_type` in 11 extension command files.

**Tasks**:
- [ ] Update 9 founder extension commands: replace `.language` with `.task_type` in jq expressions
- [ ] Update 2 present extension commands: replace `.language` with `.task_type` in jq expressions
- [ ] Check for any downstream `$task_lang` or similar variable references that may need updating

**Timing**: 15 minutes

**Depends on**: none

**Files to modify**:
- `.claude/extensions/founder/commands/analyze.md` - `.language` -> `.task_type` in jq
- `.claude/extensions/founder/commands/deck.md` - same
- `.claude/extensions/founder/commands/finance.md` - same
- `.claude/extensions/founder/commands/legal.md` - same
- `.claude/extensions/founder/commands/market.md` - same
- `.claude/extensions/founder/commands/meeting.md` - same
- `.claude/extensions/founder/commands/project.md` - same
- `.claude/extensions/founder/commands/sheet.md` - same
- `.claude/extensions/founder/commands/strategy.md` - same
- `.claude/extensions/present/commands/budget.md` - same
- `.claude/extensions/present/commands/funds.md` - same

**Verification**:
- `grep -r "\.language" .claude/extensions/*/commands/` returns zero results for jq field access patterns

---

### Phase 4: Update Documentation and Final Sweep [NOT STARTED]

**Goal**: Fix stale documentation references and run a comprehensive sweep to confirm no `.language` field references remain anywhere in `.claude/`.

**Tasks**:
- [ ] Update `.claude/context/README.md` line 189: change `load_when.languages` example to `load_when.task_types`
- [ ] Review `.claude/context/patterns/context-discovery.md` line 272 and update if the "languages" reference is about field names
- [ ] Run comprehensive grep: `grep -rn '\.language' .claude/` and verify all remaining hits are English prose (not field access)
- [ ] Run comprehensive grep: `grep -rn '"language"' .claude/` and verify no active code references remain

**Timing**: 15 minutes

**Depends on**: 1, 2, 3

**Files to modify**:
- `.claude/context/README.md` - Update stale `load_when.languages` example
- `.claude/context/patterns/context-discovery.md` - Update if needed

**Verification**:
- Final grep confirms zero jq/code references to `.language` field in `.claude/`
- All remaining "language" strings are English prose, not field names

## Testing & Validation

- [ ] `grep -rn '.task_type // .language' .claude/` returns zero results (shim fully removed)
- [ ] `grep -rn "jq.*\.language" .claude/` returns zero results (no jq expressions read `.language`)
- [ ] `grep -rn '\$language' .claude/extensions/` returns zero results (no shell variables use old name)
- [ ] Spot-check: read one file from each category to confirm correct replacement
- [ ] Verify `specs/state.json` active projects all have `task_type` field (no regression)

## Artifacts & Outputs

- `specs/394_remove_language_to_task_type_compat_shim/plans/01_remove-compat-shim.md` (this plan)
- 50 modified files across `.claude/` (commands, skills, extensions, context docs)
- Execution summary after implementation

## Rollback/Contingency

All changes are simple string replacements with no behavioral impact (since `.task_type` is already populated on all active tasks). To revert: restore the `// .language` fallback in jq expressions using `git revert` on the implementation commit. The archive state.json with old `language` entries is untouched and would resume working if the shim were restored.
