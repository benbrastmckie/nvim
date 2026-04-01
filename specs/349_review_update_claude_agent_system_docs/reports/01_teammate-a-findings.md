# Teammate A Findings: Primary Documentation Review

**Task**: 349 - Review and update .claude/ agent system documentation
**Scope**: README.md, extensions/README.md, extensions/founder/README.md, CLAUDE.md files
**Date**: 2026-04-01

---

## Key Findings

### Finding 1: README.md Extensions Table Uses Wrong Directory Names
**File**: `/home/benjamin/.config/nvim/.claude/README.md` (lines 114-121)

The Extensions table lists `neovim` and `lean4` as extension names, but the actual directory names are `nvim` and `lean`. This is directly verifiable:

- README.md says: `| neovim | Neovim/Lua | ... |`
- Actual directory: `.claude/extensions/nvim/`
- README.md says: `| lean4 | Theorem proving | ... |`
- Actual directory: `.claude/extensions/lean/`

The `extensions/README.md` correctly uses `nvim` and `lean` in its table.

**Confidence**: High

---

### Finding 2: README.md Extensions Table Is Incomplete (7 of 14 Extensions Listed)
**File**: `/home/benjamin/.config/nvim/.claude/README.md` (lines 113-121)

The Extensions section lists only 7 extensions, but there are 14 actual extension directories. Missing from the README.md table:

- `z3` (Z3 SMT solver)
- `epidemiology` (Epidemiology research with R)
- `formal` (Formal verification)
- `filetypes` (File format conversion)
- `founder` (Business strategy and startup operations)
- `present` (Presentations and grant proposals)
- `memory` (Learning and knowledge management)

The `extensions/README.md` correctly lists all 14 extensions.

**Confidence**: High

---

### Finding 3: README.md Skills Table Is Incomplete (5 of 15 Skills Listed)
**File**: `/home/benjamin/.config/nvim/.claude/README.md` (lines 85-91)

The Skills section lists only 5 skills but there are 15 actual skill directories. The following skills present in `.claude/skills/` are omitted from the README.md table:

- `skill-refresh`
- `skill-todo`
- `skill-tag`
- `skill-git-workflow`
- `skill-fix-it`
- `skill-orchestrator`
- `skill-spawn`
- `skill-team-research`
- `skill-team-plan`
- `skill-team-implement`

The CLAUDE.md skill-to-agent mapping table (which is comprehensive) serves as the authoritative reference. README.md appears to show only a partial/introductory subset.

**Confidence**: High

---

### Finding 4: README.md Quick Reference Missing /tag Command
**File**: `/home/benjamin/.config/nvim/.claude/README.md` (lines 13-28)

The Quick Reference table lists 12 commands but omits `/tag`. The CLAUDE.md Command Reference explicitly includes `/tag [--patch|--minor|--major]` as a user-only command. A `tag.md` command file exists at `.claude/commands/tag.md`.

Since `/tag` is user-only (cannot be invoked by agents), omitting it from the overview table is potentially intentional, but it creates an inconsistency with CLAUDE.md which does include it.

**Confidence**: High

---

### Finding 5: README.md Missing /merge Command
**File**: `/home/benjamin/.config/nvim/.claude/README.md` and `/home/benjamin/.config/nvim/.claude/CLAUDE.md`

A `/merge` command exists at `.claude/commands/merge.md` (creates GitHub PRs / GitLab MRs) but is not listed in either README.md or CLAUDE.md command tables. This appears to be a documentation gap for an existing, functional command.

**Confidence**: High

---

### Finding 6: README.md /fix-it Description Missing NOTE: and QUESTION: Tags
**File**: `/home/benjamin/.config/nvim/.claude/README.md` (line 25)

README.md describes `/fix-it` as "Scan for FIX:/TODO: tags" but the actual command scans for four tag types: `FIX:`, `NOTE:`, `TODO:`, `QUESTION:`.

- README.md: `Scan for FIX:/TODO: tags`
- CLAUDE.md: `Scan for FIX:/NOTE:/TODO: tags` (still missing QUESTION:)
- `commands/fix-it.md` description: `Scan files for FIX:, NOTE:, TODO:, QUESTION: tags`

Both README.md and CLAUDE.md are incomplete relative to the actual command definition.

**Confidence**: High

---

### Finding 7: README.md /research, /plan, /implement Missing --team Flag Documentation
**File**: `/home/benjamin/.config/nvim/.claude/README.md` (lines 17-19)

The Quick Reference table shows:
- `/research N [focus]`
- `/plan N`
- `/implement N`

But CLAUDE.md shows the correct usage:
- `/research N [focus] [--team]`
- `/plan N [--team]`
- `/implement N [--team]`

The `--team` flag is a documented feature in CLAUDE.md but is absent from README.md.

**Confidence**: High

---

### Finding 8: Architecture Diagram Uses ASCII Box Drawing (Should Be Unicode)
**File**: `/home/benjamin/.config/nvim/.claude/README.md` (lines 40-60)

The architecture diagram uses ASCII box characters (`+-`, `|`) rather than Unicode box-drawing characters. Per the project standard documented at `.claude/extensions/nvim/context/project/neovim/standards/box-drawing-guide.md`, documentation should use Unicode characters (`┌─`, `│`, `└─`, etc.) for professional diagrams.

Current style:
```
    +---------------------------------------------------------+
    |                      COMMANDS                            |
    +---------------------------------------------------------+
```

Should be:
```
    ┌─────────────────────────────────────────────────────────┐
    │                      COMMANDS                            │
    └─────────────────────────────────────────────────────────┘
```

**Confidence**: Medium (box-drawing guide says "recommended", not mandatory)

---

### Finding 9: founder/README.md Documents Only 5 of 8 Commands
**File**: `/home/benjamin/.config/nvim/.claude/extensions/founder/README.md`

The README states "This extension provides five commands for strategic business analysis" and lists only: `/market`, `/analyze`, `/strategy`, `/legal`, `/project`. However, the actual `commands/` directory contains 8 commands:

Missing from documentation:
- `/deck` - Pitch deck creation with material synthesis
- `/finance` - Financial analysis and verification
- `/sheet` - Cost breakdown spreadsheet generation

These three commands are fully implemented (each has its own command file, agents, and skills). The EXTENSION.md correctly lists all 8 commands.

The architecture tree in the README (lines 155-160) also only shows 5 command files and 7 agents, while the actual directory has 12 agent files.

**Confidence**: High

---

### Finding 10: founder/README.md Per-Type Research Agents Table Incomplete
**File**: `/home/benjamin/.config/nvim/.claude/extensions/founder/README.md` (lines 244-249)

The "Per-Type Research Agents" table lists only 5 agent rows (market, analyze, strategy, legal, project). Missing:

- `/sheet` -> `spreadsheet-agent`
- `/finance` -> `finance-agent`
- `/deck` -> `deck-research-agent`, `deck-planner-agent`, `deck-builder-agent`

**Confidence**: High

---

### Finding 11: CLAUDE.md "Four Layers" Count Mismatch
**File**: `/home/benjamin/.config/nvim/.claude/CLAUDE.md`

The "Context Architecture" section states "Four layers provide context to agents" but the table directly below lists 5 rows:

1. Agent context
2. Extensions
3. Project context
4. Project memory
5. Auto-memory

The count should be "Five layers" or the table needs reconciliation.

**Confidence**: High

---

### Finding 12: README.md Context Organization Table Is Incomplete
**File**: `/home/benjamin/.config/nvim/.claude/README.md` (lines 155-161)

The context directory table lists only 5 subdirectories (`orchestration/`, `formats/`, `patterns/`, `processes/`, `reference/`), but the actual `.claude/context/` directory contains many more:

Present but undocumented: `architecture/`, `checkpoints/`, `guides/`, `meta/`, `repo/`, `schemas/`, `standards/`, `templates/`, `troubleshooting/`, `workflows/`

This is likely an intentional simplification (showing the most commonly accessed dirs), but the omission of key directories like `repo/` (containing `project-overview.md`) and `meta/` (containing `meta-guide.md`) is notable given these are cited as "always available" context in CLAUDE.md.

**Confidence**: Medium (may be intentional simplification)

---

### Finding 13: founder/README.md Architecture Tree Outdated
**File**: `/home/benjamin/.config/nvim/.claude/extensions/founder/README.md` (lines 148-204)

The architecture tree in the README is missing:
- Under `commands/`: `deck.md`, `finance.md`, `sheet.md`
- Under `skills/`: `skill-deck-implement/`, `skill-deck-plan/`, `skill-deck-research/`, `skill-finance/`, `skill-spreadsheet/`
- Under `agents/`: `deck-builder-agent.md`, `deck-planner-agent.md`, `deck-research-agent.md`, `finance-agent.md`, `spreadsheet-agent.md`
- Under `context/project/founder/`: `deck/` subdirectory

The README also lists a `legal-frameworks.md` domain file but the domain directory contains additional files: `financial-analysis.md`, `migration-guide.md`, `spreadsheet-frameworks.md`, `timeline-frameworks.md`, `workflow-reference.md`.

**Confidence**: High

---

### Finding 14: gstack GitHub Link May Be Incorrect
**File**: `/home/benjamin/.config/nvim/.claude/extensions/founder/README.md` (line 317)

The reference `[gstack (Garry Tan)](https://github.com/garrytan/gstack)` links to `garrytan/gstack`. Garry Tan's GitHub username is `garrytan` but the gstack repository is more commonly known as a collection of practices rather than a public GitHub repo. This link may be dead or incorrect, but cannot be verified without web access.

**Confidence**: Low (cannot verify URL without web access)

---

## Recommended Changes

### Change 1: Fix extension names in README.md Extensions table
**File**: `.claude/README.md`
**Lines**: ~114-121
Change `neovim` to `nvim` and `lean4` to `lean` in the Extension column.

### Change 2: Add missing extensions to README.md Extensions table
**File**: `.claude/README.md`
Add rows for: `z3`, `epidemiology`, `formal`, `filetypes`, `founder`, `present`, `memory`.

### Change 3: Expand README.md Skills table or add note
**File**: `.claude/README.md`
Either expand the Skills table to include all 15 skills (with reference to CLAUDE.md for full mapping), or add a note: "Core skills shown; see [CLAUDE.md](CLAUDE.md) for complete skill-to-agent mapping."

### Change 4: Add /tag to README.md Quick Reference
**File**: `.claude/README.md`
Add row: `| /tag | /tag [--patch|--minor|--major] | Create semantic version tag (user-only) |`

### Change 5: Add /merge to README.md Quick Reference and CLAUDE.md Command Reference
**Files**: `.claude/README.md`, `.claude/CLAUDE.md`
Add `/merge` command row to both tables.

### Change 6: Fix /fix-it description in README.md and CLAUDE.md
**Files**: `.claude/README.md`, `.claude/CLAUDE.md`
- README.md: change `Scan for FIX:/TODO: tags` to `Scan for FIX:/NOTE:/TODO:/QUESTION: tags`
- CLAUDE.md: change `Scan for FIX:/NOTE:/TODO: tags` to `Scan for FIX:/NOTE:/TODO:/QUESTION: tags`

### Change 7: Add --team flags to README.md Quick Reference
**File**: `.claude/README.md`
Update `/research`, `/plan`, `/implement` usage entries to include `[--team]` flag.

### Change 8: Convert ASCII diagram to Unicode box drawing in README.md
**File**: `.claude/README.md`
**Lines**: 40-60
Replace `+-...+` and `|...|` with Unicode box-drawing characters per project standard.

### Change 9: Update founder/README.md to document all 8 commands
**File**: `.claude/extensions/founder/README.md`
- Update "five commands" references to "eight commands"
- Add `/deck`, `/finance`, `/sheet` to the Overview table with their purposes and outputs
- Add command sections for each new command (syntax, modes)
- Update "What's New in v3.0" section or note these as post-v3.0 additions
- Update Per-Type Research Agents table with new agents

### Change 10: Update founder/README.md architecture tree
**File**: `.claude/extensions/founder/README.md`
Add missing files to the architecture tree (deck, finance, sheet commands; all agents; all skills; deck context).

### Change 11: Fix "Four layers" count in CLAUDE.md
**File**: `.claude/CLAUDE.md`
Change "Four layers provide context to agents" to "Five layers provide context to agents."

### Change 12: Expand README.md Context Organization table (optional)
**File**: `.claude/README.md`
Either add missing context directories to the table, or add a note: "Key directories shown; see [context/README.md](context/README.md) for full listing."

---

## Confidence Summary

| Finding | Confidence | Category |
|---------|------------|----------|
| 1. Extension names wrong (neovim/lean4 vs nvim/lean) | High | Factual error |
| 2. Extensions table incomplete (7/14) | High | Missing content |
| 3. Skills table incomplete (5/15) | High | Missing content |
| 4. /tag missing from Quick Reference | High | Missing content |
| 5. /merge missing from all tables | High | Missing content |
| 6. /fix-it description missing tags | High | Factual error |
| 7. --team flags missing from Quick Reference | High | Missing content |
| 8. ASCII box drawing vs Unicode standard | Medium | Style inconsistency |
| 9. founder README missing 3 commands | High | Factual error |
| 10. founder Per-Type Agents table incomplete | High | Factual error |
| 11. "Four layers" vs 5 rows in table | High | Factual error |
| 12. Context Organization table incomplete | Medium | Intentional simplification likely |
| 13. founder architecture tree outdated | High | Missing content |
| 14. gstack GitHub link accuracy | Low | Cannot verify |

---

## Summary

The most critical issues are:
1. **Extension name errors** in README.md (Finding 1) - direct factual errors
2. **Founder README significantly outdated** (Findings 9, 10, 13) - 3 commands completely undocumented
3. **"Four layers" count error** in CLAUDE.md (Finding 11)
4. **/fix-it tag list incomplete** in both files (Finding 6)
5. **Missing /merge command** in both files (Finding 5)

All file references checked in README.md resolve to existing files. The CLAUDE.md path references are all valid. The extensions/README.md is well-maintained and accurate. The core documentation structure is sound; issues are primarily omissions and one set of outdated content (founder extension).
