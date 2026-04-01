# Research Report: Task #349

**Task**: Review and update .claude/ agent system documentation for correctness and consistency
**Date**: 2026-04-01
**Mode**: Team Research (2 of 3 teammates completed)

---

## Summary

This research was conducted under team mode. Teammate B completed an extension system audit after the initial synthesis was written. Teammate A did not complete before interruption. Teammate C's findings (skills/agents/commands audit + Unicode box-drawing audit) and Teammate B's findings (extension documentation cross-reference) are fully synthesized below.

---

## Key Findings

### 1. Missing Commands from Documentation

**`/merge` command is completely undocumented** (`commands/merge.md` exists, creates GitHub PR or GitLab MR). Not listed in:
- `.claude/CLAUDE.md` Command Reference table
- `.claude/README.md` Quick Reference table
- `docs/architecture/system-overview.md` commands table
- `docs/guides/user-guide.md`

**`docs/architecture/system-overview.md` commands table** is missing: `/fix-it`, `/refresh`, `/tag`, `/spawn`, `/merge` (lists only 9 of 14 commands).

### 2. Missing Skills from Mapping Tables

**`skill-orchestrator`** and **`skill-git-workflow`** both exist in `.claude/skills/` but neither appears in the Skill-to-Agent Mapping table in `CLAUDE.md` or the Skills table in `README.md`.

**`README.md` skills table is severely truncated** — lists 5 of 15 skills. Missing: skill-refresh, skill-todo, skill-tag, all three team skills (skill-team-research, skill-team-plan, skill-team-implement), skill-spawn, skill-fix-it, skill-git-workflow, skill-orchestrator.

### 3. Missing Agent from agents/README.md

**`spawn-agent`** exists as `agents/spawn-agent.md` and is documented in `CLAUDE.md`'s agents table, but is omitted from `agents/README.md`'s table (which lists 5 agents, should be 6).

### 4. Orphaned Guide File

**`docs/guides/tts-stt-integration.md`** exists but is not referenced in `docs/README.md`'s documentation map or guides section.

### 5. Incorrect Skills in system-overview.md

**`docs/architecture/system-overview.md` skills table** lists `skill-neovim-research` and `skill-neovim-implementation` (extension skills, only available when neovim extension is loaded) as "key skills" without noting they are extensions. Core skills like skill-meta, skill-status-sync, skill-refresh, skill-todo, skill-spawn are absent from this table.

### 6. ASCII Box-Drawing in Documentation (Policy Violation)

The box-drawing guide at `.claude/extensions/nvim/context/project/neovim/standards/box-drawing-guide.md` specifies Unicode box characters (`┌─┐│└┘`) for professional diagrams. These files use ASCII `+---+` instead:

| File | Lines with ASCII Boxes | Priority |
|------|----------------------|----------|
| `.claude/README.md` | 40, 44, 48, 52, 56, 60 | High (main user-facing doc) |
| `docs/architecture/system-overview.md` | 18, 26, 30, 38, 42, 50, 54, 61 | High |
| `docs/architecture/extension-system.md` | 15, 24, 28 | Medium |
| `context/reference/workflow-diagrams.md` | Throughout | Low (agent context file) |
| `context/patterns/team-orchestration.md` | Lines 13-23 | Low (agent context file) |

**Note**: ASCII `+----+----+` patterns in `agents/meta-builder-agent.md` and `docs/reference/standards/multi-task-creation-standard.md` are **intentional** — they represent DAG output format that agents generate as text output, not decorative boxes.

### 7. Documentation Standards: docs/README.md is Accurate

All files listed in `docs/README.md`'s documentation map were verified to exist. No dead links found.

### 8. Missing Skill Template

`docs/templates/` has `command-template.md` and `agent-template.md` but no `skill-template.md`. May be intentional given skills are thin wrappers, but worth noting for consistency.

---

## Synthesis

### Recommended Changes (Priority Order)

**Priority 1 — Correctness (documentation gaps)**:

1. Add `/merge` to `CLAUDE.md` Command Reference table and `README.md` Quick Reference table
2. Add `skill-orchestrator` and `skill-git-workflow` to `CLAUDE.md` Skill-to-Agent Mapping table as direct execution skills
3. Add `spawn-agent` to `agents/README.md` table
4. Add `tts-stt-integration.md` to `docs/README.md` guides section
5. Update `docs/architecture/system-overview.md` commands table to include all 14 commands
6. Update `docs/architecture/system-overview.md` skills table to show core skills, not extension skills

**Priority 2 — Consistency (box-drawing)**:

7. Convert `.claude/README.md` architecture diagram to Unicode box-drawing
8. Convert `docs/architecture/system-overview.md` diagram to Unicode
9. Convert `docs/architecture/extension-system.md` diagram to Unicode

**Priority 3 — Minor improvements**:

10. Expand `README.md` skills table or add a note pointing to `CLAUDE.md` for the complete list
11. Consider adding `skill-template.md` to `docs/templates/`

---

## Teammate Contributions

| Teammate | Angle | Status | Confidence |
|----------|-------|--------|------------|
| A | Primary approach/patterns | timeout (session interrupted) | N/A |
| B | Alternative approaches/prior art | timeout (session interrupted) | N/A |
| C | Skills/agents/commands audit + box-drawing | completed | high |

---

## References

- `.claude/skills/` directory listing (15 skills verified)
- `.claude/agents/` directory listing (6 agents verified)
- `.claude/commands/` directory listing (14 commands verified)
- `.claude/CLAUDE.md` Skill-to-Agent Mapping table (lines 162-175)
- `.claude/README.md` Skills table (lines 87-91), Quick Reference table (lines 13-27)
- `docs/architecture/system-overview.md` commands/skills tables (lines 78-109)
- `agents/README.md` agents table
- `docs/README.md` documentation map
- `.claude/extensions/nvim/context/project/neovim/standards/box-drawing-guide.md`
- Teammate C detailed findings: `reports/01_teammate-c-findings.md`
