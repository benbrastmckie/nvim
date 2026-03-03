# Research Report: Task #122 (Supplementary)

**Task**: 122 - Expand Document Converter to Filetypes Extension
**Date**: 2026-03-03
**Focus**: Plan review and gap analysis for implementation-001.md

## Summary

A review of `implementation-001.md` against the research findings in `research-001.md` and the
broader project architecture (established in tasks 111-121) reveals five areas requiring
correction or enhancement before implementation begins. The most critical gap is that the plan
only targets `.claude/extensions/filetypes/` and omits the `.opencode/extensions/` parity
requirement that the architecture mandates. Secondary gaps include missing plan metadata fields,
NixOS-specific dependency instructions, an undeclared soft dependency on task 121, a deferred
typst extension enhancement with no tracking, and a tool detection sequencing issue across phases.

## Findings

### 1. Critical: OpenCode Extension Parity Omitted

The plan exclusively targets `.claude/extensions/filetypes/` in every phase. However, the
project architecture established by tasks 111-116 requires mirrored extensions under
`.opencode/extensions/`. The task description itself specifies the source as
`.opencode/extensions/document-converter/`, making this the primary target.

**Evidence**:
- Task 116 completion summary: "Created 9 complete .opencode/ extensions ... with full parity to
  .claude/ counterparts"
- Task 111 completion summary: "Migrated nvim/.opencode/ to Theory/.opencode/ base"
- Task 113: Established shared picker architecture covering both `.claude/` and `.opencode/`
  directories
- The task description (TODO.md): "Expand the document-converter extension
  (`~/.config/nvim/.opencode/extensions/document-converter/`)"

**Impact**: If implemented as written, the `.opencode/` system will be missing the filetypes
extension and will continue referencing the old `document-converter` extension name. OpenCode
users will be unable to load the extension, and the orphan cleanup grep in Phase 5 will miss
stale references in `.opencode/`.

**Required additions**:

Phase 1 must include:
- Rename `.opencode/extensions/document-converter/` to `.opencode/extensions/filetypes/`
- Create full `.opencode/extensions/filetypes/` directory structure in parallel with
  `.claude/extensions/filetypes/`
- Translate all agent/skill/command/context files for the OpenCode format (`.opencode/`
  uses `agents/`, `skills/`, `commands/` subdirectories matching `.claude/`)

Phase 5 orphan cleanup must scan both systems:
```bash
grep -r "document-converter" .claude/
grep -r "document-converter" .opencode/
```

The "Expected Extension Directory Structure" should show both trees:
```
.claude/extensions/filetypes/      # Claude Code system
  manifest.json
  EXTENSION.md
  ...

.opencode/extensions/filetypes/    # OpenCode system (parity)
  manifest.json
  EXTENSION.md
  ...
```

---

### 2. Missing Required Plan Metadata Fields

The plan header is missing three required fields per the Plan Metadata Standard documented in
`.claude/docs/reference/standards/plan-metadata-standard.md`.

**Current header**:
```markdown
- **Task**: 122 - Expand Document Converter to Filetypes Extension
- **Status**: [NOT STARTED]
- **Effort**: 6-8 hours
- **Dependencies**: None
- **Research Inputs**: [research-001.md](../reports/research-001.md)
- **Artifacts**: plans/implementation-001.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false
```

**Missing required fields**:
- `Date`: Must be `2026-03-03` or `2026-03-03 (Revised)`
- `Feature`: One-line description (50-100 chars), e.g. "Expand document-converter extension to
  filetypes with specialized sub-agents for Excel and PowerPoint"
- `Standards File`: Absolute path to CLAUDE.md for standards traceability, i.e.
  `/home/benjamin/.config/nvim/CLAUDE.md`
- `Research Reports`: The existing `**Research Inputs**` field should be renamed to
  `**Research Reports**` to match the standard field name

**Impact**: Low (does not block implementation, but fails automated plan validation and
pre-commit hooks that enforce the Plan Metadata Standard).

---

### 3. NixOS Dependency Installation Instructions Missing

Phase 4 creates `context/project/filetypes/tools/dependency-guide.md` with installation commands
for `apt` (Ubuntu/Debian) and macOS (Homebrew), but does not include NixOS instructions. This
system runs NixOS (evidenced by the NixOS entries in research-001.md §7 and the nix extension
previously noted in project history).

**Current coverage** (research-001.md §7):
```bash
pip install markitdown        # Always required
pip install openpyxl pandas xlsx2csv   # Spreadsheet
apt install csv2latex         # LaTeX alternative
pip install python-pptx       # Presentation
apt install pandoc            # Universal converter
apt install texlive-base      # LaTeX compilation
```

**Missing NixOS equivalents**:
```bash
# Nix shell (ephemeral, for one-off use)
nix-shell -p python3Packages.markitdown
nix-shell -p python3Packages.openpyxl python3Packages.pandas
nix-shell -p python3Packages.python-pptx
nix-shell -p pandoc texlive.combined.scheme-basic

# Home-manager (persistent, declarative)
home.packages = with pkgs; [
  pandoc
  (python3.withPackages (ps: with ps; [
    markitdown openpyxl pandas python-pptx xlsx2csv
  ]))
];

# Nix profile (persistent, imperative)
nix profile install nixpkgs#pandoc
```

**Note**: `csv2latex` is not available in nixpkgs as of 2026; the fallback for NixOS is
`python3Packages.pandas` (already a dependency) combined with `DataFrame.to_latex()`, which
is the recommended approach regardless.

**Impact**: Medium. Developers on NixOS (the primary development environment for this project)
will encounter friction when setting up tools referenced in the dependency guide.

---

### 4. Undeclared Soft Dependency on Task 121

Task 121 (currently in `[IMPLEMENTING]` status) is removing `skill-document-converter` and other
extension-specific skills from `.opencode/skills/` and `~/.config/.claude/skills/`. This
cleanup is a prerequisite for task 122 Phase 1 to start from a clean state.

**Specifically**:
- Task 121 removes `skill-document-converter` from `.opencode/skills/` (extension-owned skill
  that should not be in the core skills directory)
- Task 122 Phase 1 renames the entire `extensions/document-converter/` directory

If task 122 Phase 1 runs while task 121 is incomplete, there will be stale
`skill-document-converter` references in `.opencode/skills/` pointing to a skill whose parent
extension no longer exists at `extensions/document-converter/`.

**Required addition to plan**:
- Add to Phase 1 prerequisites: "Task 121 should be completed or at minimum Phase 1 of task 121
  (removal of extension-specific skills from core directories) should be complete before this
  phase runs"
- Add to Phase 5 verification: confirm `.opencode/skills/` contains no `skill-document-converter`
  entries

---

### 5. Typst Extension Enhancement Has No Tracking

Research report research-001.md §10 and the Context Extension Recommendations section explicitly
identify a follow-on enhancement for the typst extension:

> **Topic**: Typst presentation packages (Polylux/Touying)
> **Gap**: Typst extension context does not cover slide deck creation
> **Recommendation**: Add `context/project/typst/patterns/slide-decks.md` to the typst extension
> when presentation support is added

The implementation plan correctly defers modification of the typst extension (listed in
Non-Goals: "Modifying the LaTeX or Typst extensions themselves"). However, the plan contains no
reference to this enhancement as a future roadmap item. Without explicit tracking, it will be
lost.

**Required addition**:

Add to plan Artifacts section or a new "Future Work" section:
```markdown
## Future Work (Out of Scope for This Task)

- **Typst slide deck context** (typst extension): Add
  `context/project/typst/patterns/slide-decks.md` to the typst extension covering Polylux and
  Touying syntax, theme selection, and overlay/animation patterns. This complements the
  presentation-slides.md context file created in Phase 3 of this task.
- **Round-trip conversions** (Phase 3 of research §5.2): LaTeX table -> XLSX, Beamer -> PPTX
  via beamer2pptx, CSV/data file management utilities.
- **LaTeX extension slide deck context**: Add `context/project/latex/patterns/beamer-slides.md`
  covering Beamer theme selection, overlay syntax, and academic presentation patterns.
```

---

### 6. Tool Detection Sequencing Issue

Phase 4 creates tool detection patterns and then retroactively updates the agents created in
Phases 2 and 3 with those patterns. This means Phases 2 and 3 produce agents with placeholder
or incomplete tool detection that must be patched in Phase 4.

**Current sequence**:
- Phase 2: Creates `spreadsheet-agent.md` (tool detection TBD)
- Phase 3: Creates `presentation-agent.md` (tool detection TBD)
- Phase 4: Creates shared tool detection patterns, updates both agents

**Recommended alternatives** (either of two approaches):

**Option A - Move tool detection to Phase 1**:
Add a shared `context/project/filetypes/tools/tool-detection.md` to Phase 1 that defines
standard detection patterns. Phases 2 and 3 agents reference this context file instead of
embedding detection logic. Phase 4 then focuses on documentation only.

**Option B - Reorder phases** (minimal change):
Move Phase 4 between Phase 1 and Phase 2, so the dependency documentation and tool detection
framework exists before any agents are written. This makes Phases 2 and 3 write complete agents
on the first pass, eliminating the retroactive update step.

Option A is preferable as it avoids embedding tool detection logic in agent definitions
(cleaner separation of concerns) and produces a reusable context artifact.

## Recommendations

### Priority Ordering

| Priority | Finding | Effort |
|----------|---------|--------|
| Critical | Add `.opencode/` extension parity to all phases | High (doubles implementation scope for each phase) |
| High | Reorder or refactor tool detection (Finding 6) | Low (restructure existing phase tasks) |
| High | Add NixOS dependency instructions to Phase 4 | Low (additive documentation) |
| Medium | Add task 121 soft dependency to Phase 1 | Minimal (note in prerequisites) |
| Medium | Add future work section for typst/latex slide context | Minimal (add section to plan) |
| Low | Fix plan metadata fields | Minimal (add 3 lines to header) |

### Summary of Plan Modifications Needed

1. **Phase 1**: Add `.opencode/extensions/filetypes/` creation alongside `.claude/` work; note
   task 121 soft dependency; create shared tool detection context file (if choosing Option A)
2. **Phase 2**: Write complete tool detection into spreadsheet-agent (no retroactive update
   needed if using Option A)
3. **Phase 3**: Write complete tool detection into presentation-agent (no retroactive update
   needed if using Option A)
4. **Phase 4**: Add NixOS dependency installation section; remove retroactive agent updates
   (superseded by Option A tool detection)
5. **Phase 5**: Extend orphan cleanup grep to cover `.opencode/` as well as `.claude/`
6. **Plan header**: Add Date, Feature, Standards File, rename Research Inputs to Research Reports
7. **New section**: Add Future Work section documenting typst/latex slide deck context enhancements

## Next Steps

Run `/revise 122` to create `implementation-002.md` incorporating these corrections before
beginning implementation.
