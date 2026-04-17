# Implementation Plan: Task #469

- **Task**: 469 - Review agent system post-refactor
- **Status**: [IMPLEMENTING]
- **Effort**: 3 hours
- **Dependencies**: None
- **Research Inputs**: specs/469_review_agent_system_post_refactor/reports/01_team-research.md
- **Artifacts**: plans/01_system-review-fixes.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Fix bookkeeping gaps left by the task 464/465/467 refactoring: 4 broken context index entries, 3 stale path references in team skills, duplicate CLAUDE.md section, broken validation scripts, and 6 unindexed context files. All fixes are edits to existing files with no architectural changes. Done when all HIGH and MEDIUM research findings are resolved and validation scripts pass.

### Research Integration

Team research (4 teammates) identified 16 issues across HIGH/MEDIUM/LOW severity. This plan addresses all 4 HIGH (P1-P4) and 3 MEDIUM (P5-P7) findings. LOW items (P8-P10) are deferred as they are cosmetic or functionally harmless.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

- **Subagent-return reference cleanup** (Phase 1, Agent System Quality): P7 directly addresses the ROADMAP item to sweep remaining `subagent-return-format.md` references.
- **Agent frontmatter validation** (Phase 1, Agent System Quality): P8 (deferred) relates to nix agent frontmatter consistency.

## Goals & Non-Goals

**Goals**:
- Fix all 4 broken context index entries (P1)
- Correct 3 stale team skill path references (P2)
- Remove duplicate Memory Extension section from CLAUDE.md (P3)
- Repair both broken validation scripts (P4)
- Add 6 missing context files to the index (P5)
- Fix 13 stale subagent-return-format.md references (P7)

**Non-Goals**:
- Fix loader.lua to handle root-level context files (architectural change, separate task)
- Add model: opus to nix agents (LOW, harmless default)
- Fix script permissions for lean MCP scripts (LOW)
- Clean up stale permissions in settings.local.json (operational, not agent system)
- Create core extension README.md (P6 deferred -- doc generation is a ROADMAP item)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Removing wrong Memory Extension section from CLAUDE.md | H | L | Verify which section comes from core merge-sources vs memory EXTENSION.md before editing |
| Validator fixes introduce regressions | M | L | Run both validators after fixes to confirm they pass |
| Index entry additions break context loading | M | L | Verify paths exist before adding entries; test with jq query after |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 2 | -- |
| 2 | 3 | 1 |
| 3 | 4 | -- |

Phases within the same wave can execute in parallel.

### Phase 1: Fix broken context index entries and deploy missing files [COMPLETED]

**Goal**: Resolve P1 (4 broken index entries) and P5 (6 unindexed files)

**Tasks**:
- [ ] Remove `orchestration/routing.md` entry from `.claude/extensions/core/context/core-index-entries.json` (file never existed)
- [ ] Copy 3 root-level files (README.md, routing.md, validation.md) from `.claude/extensions/core/context/` to `.claude/context/` so index entries resolve
- [ ] Add 6 missing index entries to `core-index-entries.json` for: `patterns/artifact-linking-todo.md`, `patterns/multi-task-operations.md`, `reference/team-wave-helpers.md`, `schemas/frontmatter-schema.json`, `schemas/subagent-frontmatter.yaml`, `templates/state-template.json`
- [ ] Regenerate `.claude/context/index.json` by running the extension loader or manually merging
- [ ] Verify all index paths resolve to existing files: `jq -r '.entries[].path' .claude/context/index.json | while read p; do test -f ".claude/context/$p" || echo "MISSING: $p"; done`

**Timing**: 1 hour

**Depends on**: none

**Files to modify**:
- `.claude/extensions/core/context/core-index-entries.json` - Remove stale entry, add 6 new entries
- `.claude/context/README.md` - Copy from extension source
- `.claude/context/routing.md` - Copy from extension source
- `.claude/context/validation.md` - Copy from extension source
- `.claude/context/index.json` - Regenerated with merged entries

**Verification**:
- All `index.json` paths resolve to existing files
- No "MISSING" output from path verification loop

---

### Phase 2: Fix team skill paths and duplicate CLAUDE.md section [COMPLETED]

**Goal**: Resolve P2 (3 stale team skill paths) and P3 (duplicate Memory Extension section)

**Tasks**:
- [ ] In `.claude/skills/skill-team-plan/SKILL.md`: replace `.claude/extensions/core/context/reference/team-wave-helpers.md` with `.claude/context/reference/team-wave-helpers.md`
- [ ] In `.claude/skills/skill-team-research/SKILL.md`: same path replacement
- [ ] In `.claude/skills/skill-team-implement/SKILL.md`: same path replacement
- [ ] In `.claude/extensions/core/skills/skill-team-plan/SKILL.md`: same path replacement (source copy)
- [ ] In `.claude/extensions/core/skills/skill-team-research/SKILL.md`: same path replacement (source copy)
- [ ] In `.claude/extensions/core/skills/skill-team-implement/SKILL.md`: same path replacement (source copy)
- [ ] Remove duplicate `## Memory Extension` section from `.claude/extensions/core/merge-sources/claudemd.md` (keep the memory extension's own section)
- [ ] Regenerate `.claude/CLAUDE.md` by running the loader or trigger reload

**Timing**: 45 minutes

**Depends on**: none

**Files to modify**:
- `.claude/skills/skill-team-{plan,research,implement}/SKILL.md` - Fix 3 deployed skill files
- `.claude/extensions/core/skills/skill-team-{plan,research,implement}/SKILL.md` - Fix 3 source skill files
- `.claude/extensions/core/merge-sources/claudemd.md` - Remove duplicate Memory Extension section
- `.claude/CLAUDE.md` - Regenerated (no longer has duplicate section)

**Verification**:
- `grep -r "extensions/core/context/reference" .claude/skills/` returns no results
- `grep -c "## Memory Extension" .claude/CLAUDE.md` returns exactly 1

---

### Phase 3: Fix validation scripts [COMPLETED]

**Goal**: Resolve P4 (broken validate-wiring.sh and validate-context-index.sh) and P7 (13 stale subagent-return-format.md references)

**Tasks**:
- [ ] In `.claude/scripts/validate-wiring.sh`: define or remove calls to `validate_language_entries` at lines 244/250/255/260 for nvim/lean/latex/typst extensions
- [ ] In `.claude/scripts/validate-context-index.sh`: remove or make optional the check for `version` and `generated` top-level fields (current index uses `entries` only)
- [ ] Run `validate-wiring.sh` and confirm it completes without error
- [ ] Run `validate-context-index.sh` and confirm it completes without error
- [ ] Find all 13 files referencing `subagent-return-format.md` and replace with `formats/subagent-return.md` (or the correct current path)
- [ ] Verify no remaining references: `grep -r "subagent-return-format" .claude/`

**Timing**: 1 hour

**Depends on**: 1

**Files to modify**:
- `.claude/scripts/validate-wiring.sh` - Fix undefined function calls
- `.claude/scripts/validate-context-index.sh` - Fix field expectations
- 13 context files with stale `subagent-return-format.md` references

**Verification**:
- `bash .claude/scripts/validate-wiring.sh` exits 0
- `bash .claude/scripts/validate-context-index.sh` exits 0
- `grep -r "subagent-return-format" .claude/` returns no results

---

### Phase 4: Final validation and cleanup [NOT STARTED]

**Goal**: End-to-end verification that all fixes are consistent

**Tasks**:
- [ ] Run `bash .claude/scripts/check-extension-docs.sh` and note results (P6 core README missing is expected/deferred)
- [ ] Verify CLAUDE.md has no duplicate sections: count all `##` headings and check for duplicates
- [ ] Verify context index integrity: all paths resolve, no orphan entries
- [ ] Run extension loader to confirm clean load with all 4 extensions (core, nvim, memory, nix)

**Timing**: 15 minutes

**Depends on**: none

**Files to modify**:
- None (verification only)

**Verification**:
- All validation scripts pass (except known P6 deferral)
- No duplicate headings in CLAUDE.md
- All index entries resolve to files

## Testing & Validation

- [ ] `jq -r '.entries[].path' .claude/context/index.json | while read p; do test -f ".claude/context/$p" || echo "MISSING: $p"; done` produces no output
- [ ] `grep -r "extensions/core/context/reference" .claude/skills/` returns no matches
- [ ] `grep -c "## Memory Extension" .claude/CLAUDE.md` returns 1
- [ ] `bash .claude/scripts/validate-wiring.sh` exits 0
- [ ] `bash .claude/scripts/validate-context-index.sh` exits 0
- [ ] `grep -r "subagent-return-format" .claude/` returns no matches
- [ ] Extension loader runs cleanly with core + nvim + memory + nix

## Artifacts & Outputs

- `specs/469_review_agent_system_post_refactor/plans/01_system-review-fixes.md` (this plan)
- `specs/469_review_agent_system_post_refactor/summaries/01_system-review-fixes-summary.md` (after implementation)

## Rollback/Contingency

All changes are to configuration files tracked in git. If any fix causes regressions, revert the specific commit with `git revert`. The extension loader regenerates `CLAUDE.md` and `index.json` on reload, so reverting source files in `extensions/core/` and re-running the loader restores the prior state.
