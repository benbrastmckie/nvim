# Research Report: Task #349

**Task**: Review and update .claude/ agent system documentation for correctness and consistency
**Date**: 2026-04-01
**Mode**: Team Research (3 teammates)

---

## Summary

All three teammates completed their research. Teammate A reviewed the three key README files and CLAUDE.md for correctness and formatting. Teammate B cross-referenced extension documentation against actual manifest.json files, skills, and agents. Teammate C audited skills/agents/commands tables and Unicode box-drawing character usage. Findings are synthesized below.

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

### 9. README.md Extensions Table Uses Wrong Directory Names (Teammate A)

The README.md Extensions table lists `neovim` and `lean4` as extension names, but actual directories are `nvim/` and `lean/`. The `extensions/README.md` correctly uses the actual directory names.

### 10. README.md Extensions Table Is Incomplete (7 of 14) (Teammate A)

Only 7 extensions listed; missing: `z3`, `epidemiology`, `formal`, `filetypes`, `founder`, `present`, `memory`. The `extensions/README.md` correctly lists all 14.

### 11. README.md /fix-it Description Missing Tag Types (Teammate A)

- README.md says: "Scan for FIX:/TODO: tags"
- CLAUDE.md says: "Scan for FIX:/NOTE:/TODO: tags"
- Actual command scans: FIX:, NOTE:, TODO:, QUESTION:

Both README.md and CLAUDE.md are incomplete.

### 12. README.md /research, /plan, /implement Missing --team Flag (Teammate A)

Quick Reference shows `/research N [focus]` but CLAUDE.md shows `/research N [focus] [--team]`. Same gap for `/plan` and `/implement`.

### 13. CLAUDE.md "Four Layers" Count Mismatch (Teammate A)

Context Architecture section says "Four layers" but the table lists 5 rows (Agent context, Extensions, Project context, Project memory, Auto-memory).

### 14. README.md Context Organization Table Incomplete (Teammate A)

Lists 5 subdirectories but actual `context/` has many more: `architecture/`, `checkpoints/`, `guides/`, `meta/`, `repo/`, `schemas/`, `standards/`, `templates/`, `troubleshooting/`, `workflows/`.

### 15. Extension README Incorrectly Attributes `deck` to `present` Extension (Teammate B)

The `extensions/README.md` Available Extensions table (line 35) reads:
```
| present | deck, grant | Presentations and grant proposals |
```
This is wrong: the `present` extension has `language: "present"` and only provides grant writing. Deck is in the `founder` extension. The `present/README.md` explicitly notes: "Pitch deck generation has moved to the `founder` extension."

### 16. `founder/README.md` Is Outdated — Documents 5 Commands, Extension Has 8 (Teammate B)

The founder README consistently says "five commands" (market, analyze, strategy, legal, project) and omits `/sheet`, `/finance`, and `/deck` from the commands table, architecture tree, and narrative. The actual extension (manifest v3.0, EXTENSION.md) has 8 commands, 12 agents, and 12 skills. The EXTENSION.md injected into CLAUDE.md at load time is accurate; the README fell behind.

### 17. `CLAUDE.md` Extension Language List Omits `founder` and `present` (Teammate B)

The Language-Based Routing section lists extension languages as:
> "neovim, lean4, latex, typst, python, nix, web, z3, epidemiology, formal, etc."

Both `founder` (language: "founder", 8 commands, sub-type routing) and `present` (language: "present", grant workflow) are missing.

### 18. `extensions/README.md` Loading Steps Omit Path for `core-index-entries.json` (Teammate B)

Step 2 of the loading procedure says "Core index entries are loaded from `core-index-entries.json`" without specifying the path. The file is at `.claude/context/core-index-entries.json`.

### 19. All Extension Files and Context References Verified Correct (Teammate B)

All 14 extensions verified: every agent `.md`, every skill directory, every rule file, and every context path in every `index-entries.json` exists on disk. No broken references found across all 14 extensions (265 total context entries checked).

---

## Synthesis

### Recommended Changes (Priority Order)

**Priority 1 — Factual errors**:

1. Fix README.md extension names: `neovim` -> `nvim`, `lean4` -> `lean` (Finding 9)
2. Fix README.md /fix-it description to include all 4 tag types; fix CLAUDE.md too (Finding 11)
3. Fix CLAUDE.md "Four layers" -> "Five layers" (Finding 13)
4. Fix `extensions/README.md` `present` row: remove `deck`, keep `grant`/`present` only (Finding 15)

**Priority 2 — Missing content (documentation gaps)**:

5. Add `/merge` and `/tag` to README.md Quick Reference table (Findings 1, 5)
6. Add `/merge` to CLAUDE.md Command Reference table (Finding 1)
7. Add `skill-orchestrator` and `skill-git-workflow` to CLAUDE.md Skill-to-Agent Mapping (Finding 2)
8. Add `spawn-agent` to `agents/README.md` table (Finding 3)
9. Add `tts-stt-integration.md` to `docs/README.md` guides section (Finding 4)
10. Add missing 7 extensions to README.md Extensions table (Finding 10)
11. Add `--team` flags to README.md Quick Reference for /research, /plan, /implement (Finding 12)
12. Update `docs/architecture/system-overview.md` commands and skills tables (Finding 5)
13. Add `founder` and `present` to CLAUDE.md extension language example list (Finding 17)
14. Add full path to `core-index-entries.json` in `extensions/README.md` (Finding 18)
15. Update `founder/README.md`: document all 8 commands, update architecture tree, agents table (Findings 16, A-9, A-10, A-13)

**Priority 3 — Consistency (box-drawing)**:

16. Convert `.claude/README.md` architecture diagram to Unicode box-drawing (Finding 6)
17. Convert `docs/architecture/system-overview.md` diagram to Unicode (Finding 6)
18. Convert `docs/architecture/extension-system.md` diagram to Unicode (Finding 6)

**Priority 4 — Minor improvements**:

19. Expand README.md skills table or add note pointing to CLAUDE.md (Finding 2, A-3)
20. Expand README.md context organization table or add note (Finding 14)
21. Consider adding `skill-template.md` to `docs/templates/` (Finding 8)

---

## Teammate Contributions

| Teammate | Angle | Status | Confidence |
|----------|-------|--------|------------|
| A | Primary documentation review (3 READMEs + CLAUDE.md) | completed | high |
| B | Extension system documentation cross-reference | completed | high |
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
- All 14 `extensions/*/manifest.json` files cross-referenced against filesystem
- All 14 `extensions/*/index-entries.json` context paths verified on disk
- Teammate A detailed findings: `reports/01_teammate-a-findings.md`
- Teammate B detailed findings: `reports/01_teammate-b-findings.md`
- Teammate C detailed findings: `reports/01_teammate-c-findings.md`
