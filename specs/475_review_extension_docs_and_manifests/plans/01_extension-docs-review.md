# Implementation Plan: Review Extension Docs and Manifests

- **Task**: 475 - Review extension docs and manifests
- **Status**: [COMPLETED]
- **Effort**: 4 hours
- **Dependencies**: None
- **Research Inputs**: reports/01_team-research.md, reports/02_followup-research.md
- **Artifacts**: plans/01_extension-docs-review.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Systematic review and correction of extension documentation across `.claude/extensions/`. The primary concern is preventing README.md files from being loaded into runtime directories (`.claude/agents/`, `.claude/commands/`) where they could break the agent system. Secondary goals are fixing stale content in 4 extension READMEs, closing template compliance gaps in `present/README.md`, documenting the `routing_exempt` field in the extension development guide, and improving cross-linking between extension docs. The task is done when `check-extension-docs.sh` passes cleanly, no README.md files are listed in manifest `provides.agents` or `provides.commands`, and all identified stale content is corrected.

### Research Integration

Two research reports inform this plan:

- **01_team-research.md** (4-teammate synthesis): Identified that `routing_exempt` is a doc-lint-only flag (not a picker filter), found the founder `/consult` omission as the only lint failure, cataloged stale content in memory/nix/founder READMEs, and flagged the missing `routing_exempt` entry in `extension-development.md`.

- **02_followup-research.md**: Confirmed the actual loading risk -- `core/manifest.json` lists `"README.md"` in `provides.agents`, causing it to be copied to `.claude/agents/README.md` at runtime. Also confirmed `install-extension.sh` uses unfiltered globs that would copy any `README.md` in `commands/` or `agents/` directories. Provided exact line-level fixes for all stale content.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

- **"Zero stale references to removed/renamed files"** (Success Metrics) -- Phases 1 and 2 directly address stale manifest entries and broken @-references.
- **"Doc-lint script exits 0 on every commit"** (Success Metrics) -- Phase 2 fixes the founder `/consult` lint failure.
- **"CI enforcement of doc-lint"** (Phase 1: Documentation Infrastructure) -- This task ensures the baseline is clean before CI enforcement can be meaningful.

## Goals & Non-Goals

**Goals**:
- Eliminate README.md files from manifest `provides.agents` and `provides.commands` to prevent runtime loading
- Add README.md exclusion to `install-extension.sh` glob patterns
- Fix all stale content identified in research (memory `--remember`, nix broken refs, founder `/consult`)
- Document `routing_exempt` field in extension development guide
- Expand `present/README.md` to meet template compliance for complex extensions
- Add cross-linking (README links in hub, dependency sections)

**Non-Goals**:
- Implementing picker-level filtering (`picker_hidden` flag) -- out of scope, requires separate feature work
- Enforcing EXTENSION.md slim standard (60-line limit) -- minor violations, not blocking
- Adding CI enforcement of doc-lint -- roadmap Phase 1 item, separate task
- Restructuring memory or epidemiology README layout to match template exactly -- functional structure is acceptable

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Removing README.md from core manifest breaks something that depends on `.claude/agents/README.md` | M | L | Research confirmed no agent loads this file (no frontmatter); safe to remove |
| Stale content fixes introduce new inaccuracies | M | L | All fixes are exact text from follow-up research; verify against source files |
| `install-extension.sh` glob fix breaks legitimate file loading | H | L | Only skip files named exactly `README.md`; all real commands/agents have descriptive names |
| Founder README edits conflict with concurrent changes | L | L | Founder extension is stable; no active tasks modifying it |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3 | 1 |
| 3 | 4 | 2 |

Phases within the same wave can execute in parallel.

### Phase 1: Loading Safety [COMPLETED]

**Goal**: Prevent README.md files from being loaded into runtime agent/command directories.

**Tasks**:
- [ ] Remove `"README.md"` from `provides.agents` array in `.claude/extensions/core/manifest.json`
- [ ] Remove `"README.md"` from `provides.context` array in `.claude/extensions/core/manifest.json` (optional cleanup)
- [ ] Delete `.claude/agents/README.md` from the runtime directory (stale artifact from manifest listing)
- [ ] Add README.md exclusion to `install-extension.sh` `install_commands()` function glob loop
- [ ] Add README.md exclusion to `install-extension.sh` `install_agents()` function glob loop
- [ ] Delete `.claude/extensions/memory/commands/README.md` (redundant; poses install-extension.sh risk)
- [ ] Delete `.claude/extensions/memory/skills/README.md` (redundant navigation doc)
- [ ] Add `"routing_exempt": true` to `.claude/extensions/slidev/manifest.json` (documents infrastructure-only intent)

**Timing**: 45 minutes

**Depends on**: none

**Files to modify**:
- `.claude/extensions/core/manifest.json` - Remove README.md from provides.agents and provides.context
- `.claude/agents/README.md` - Delete
- `.claude/scripts/install-extension.sh` - Add README.md skip in glob loops
- `.claude/extensions/memory/commands/README.md` - Delete
- `.claude/extensions/memory/skills/README.md` - Delete
- `.claude/extensions/slidev/manifest.json` - Add routing_exempt flag

**Verification**:
- `ls .claude/agents/README.md` returns "No such file"
- `grep -c README .claude/extensions/core/manifest.json` shows reduced count
- `grep -q 'README.md' .claude/scripts/install-extension.sh` confirms skip logic present
- `.claude/extensions/memory/commands/README.md` no longer exists
- `jq '.routing_exempt' .claude/extensions/slidev/manifest.json` returns `true`

---

### Phase 2: Stale Content Fixes [COMPLETED]

**Goal**: Correct all identified stale, broken, or missing content across 4 extension READMEs and the extension development guide.

**Tasks**:
- [ ] Fix `memory/README.md`: Replace all `--remember` references with auto-retrieval model description (lines 17-27 table, line 22 Important block, lines 67-89 "During Research" section)
- [ ] Fix `nix/README.md`: Correct two broken @-references -- `patterns/modules.md` to `patterns/module-patterns.md`, `tools/nixos-rebuild.md` to `tools/nixos-rebuild-guide.md` (lines 177-178)
- [ ] Fix `founder/README.md`: Add `/consult` to command table (lines 16-27), update command count from "eight" to "nine" (line 9), add `consult.md` to architecture tree (lines 229-231), fix lifecycle statement (line 302), add `/consult` to Per-Type Research Agents table (lines 332-340)
- [ ] Fix `founder/README.md`: Update stale names in architecture tree -- `skill-spreadsheet/` to `skill-founder-spreadsheet/`, `spreadsheet-agent.md` to `founder-spreadsheet-agent.md`
- [ ] Add `routing_exempt` field to `extension-development.md` Manifest Fields table (after `merge_targets` row, line 103)
- [ ] Fix `extension-development.md`: Change stale `See extensions/template/` reference to `See core/templates/extension-readme-template.md`

**Timing**: 1.5 hours

**Depends on**: 1

**Files to modify**:
- `.claude/extensions/memory/README.md` - Replace --remember with auto-retrieval
- `.claude/extensions/nix/README.md` - Fix 2 broken @-references
- `.claude/extensions/founder/README.md` - Add /consult, fix counts, fix stale tree names
- `.claude/context/guides/extension-development.md` - Add routing_exempt field, fix template reference

**Verification**:
- `grep -c "remember" .claude/extensions/memory/README.md` returns 0 (no --remember references)
- `grep "module-patterns" .claude/extensions/nix/README.md` shows corrected reference
- `grep "nixos-rebuild-guide" .claude/extensions/nix/README.md` shows corrected reference
- `grep "consult" .claude/extensions/founder/README.md` returns matches for command table and tree
- `grep "routing_exempt" .claude/context/guides/extension-development.md` returns the new field row
- `.claude/scripts/check-extension-docs.sh` passes with 0 failures

---

### Phase 3: Template Gaps and Present README [COMPLETED]

**Goal**: Expand `present/README.md` to include required sections for a complex extension, matching template compliance standards.

**Tasks**:
- [ ] Add Installation section (standard boilerplate, after Overview)
- [ ] Add Architecture section with directory tree derived from EXTENSION.md
- [ ] Add Skill-Agent Mapping table (9 skills from EXTENSION.md)
- [ ] Add Language Routing table (5 task types from EXTENSION.md)
- [ ] Add Talk Modes table (CONFERENCE, SEMINAR, DEFENSE, POSTER, JOURNAL_CLUB)
- [ ] Add Workflow section describing the talk creation pipeline
- [ ] Add Output Artifacts section listing generated file types
- [ ] Clean up "Related Files" section -- integrate into Architecture or remove redundancy

**Timing**: 1 hour

**Depends on**: 1

**Files to modify**:
- `.claude/extensions/present/README.md` - Expand from ~90 lines to ~180 lines with missing sections

**Verification**:
- README contains all 7 required template sections for complex extensions
- Line count is in the 150-200 range (comparable to nix at 186, lean at 192)
- Content is consistent with `present/EXTENSION.md` and `present/manifest.json`

---

### Phase 4: Cross-Linking [COMPLETED]

**Goal**: Improve discoverability across extension documentation with systematic cross-links.

**Tasks**:
- [ ] Add "Docs" column with README links to `extensions/README.md` Available Extensions table
- [ ] Add Dependencies section to `founder/README.md` noting slidev dependency with link to `../slidev/README.md`
- [ ] Add Dependencies section to `present/README.md` noting slidev dependency with link to `../slidev/README.md`

**Timing**: 30 minutes

**Depends on**: 2

**Files to modify**:
- `.claude/extensions/README.md` - Add Docs column to extension table
- `.claude/extensions/founder/README.md` - Add Dependencies section
- `.claude/extensions/present/README.md` - Add Dependencies section

**Verification**:
- `grep "README.md" .claude/extensions/README.md` shows links to individual extension READMEs
- `grep -i "dependencies\|slidev" .claude/extensions/founder/README.md` shows dependency section
- `grep -i "dependencies\|slidev" .claude/extensions/present/README.md` shows dependency section

## Testing & Validation

- [ ] Run `.claude/scripts/check-extension-docs.sh` and verify 0 failures (especially founder /consult fix)
- [ ] Verify `.claude/agents/README.md` does not exist
- [ ] Verify `memory/commands/README.md` does not exist
- [ ] Grep all modified README files for `--remember` to confirm no stale references remain
- [ ] Verify `nix/README.md` @-references point to files that actually exist on disk
- [ ] Verify `install-extension.sh` contains README.md skip logic in both glob functions
- [ ] Spot-check `present/README.md` against `present/EXTENSION.md` for consistency

## Artifacts & Outputs

- `plans/01_extension-docs-review.md` (this file)
- `summaries/01_extension-docs-review-summary.md` (created after implementation)

## Rollback/Contingency

All changes are to documentation files (markdown) and one shell script. Git revert of the implementation commit(s) fully restores the previous state. No runtime code changes, no database migrations, no build artifacts.

If the `core/manifest.json` change causes unexpected behavior on extension reload, restore the `"README.md"` entry to `provides.agents` and investigate what (if anything) depends on `.claude/agents/README.md` at runtime.
