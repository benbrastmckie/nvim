# Implementation Plan: Update README Documentation

- **Task**: 441 - Update README Documentation
- **Status**: [COMPLETED]
- **Effort**: 1.5 hours
- **Dependencies**: None
- **Research Inputs**: specs/441_update_readme_documentation/reports/01_readme-update-research.md
- **Artifacts**: plans/01_readme-update-plan.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: markdown
- **Lean Intent**: true

## Overview

The README.md (583 lines) contains extensive Avante AI documentation (~95 lines of dedicated section plus scattered references across 4 additional locations) despite Avante being fully removed from the codebase. This plan replaces all Avante references with current AI integration documentation (Claude Code, OpenCode, Lectic), adds a Zed editor alternative link at the top, and adds a reference to `.claude/README.md` for agent system details. Definition of done: README contains zero Avante references, documents current AI tools accurately, and includes both new links.

### Research Integration

Research report `01_readme-update-research.md` identified all Avante references with precise line numbers, documented the current AI plugin landscape (claudecode, lectic, mcp-hub, opencode), and confirmed that `.claude/README.md` exists as a comprehensive agent system documentation hub. The report mapped 6 distinct Avante reference locations across the README.

### Roadmap Alignment

No ROADMAP.md items are directly advanced by this task. The task addresses documentation accuracy rather than infrastructure improvements.

## Goals & Non-Goals

**Goals**:
- Remove all Avante references from README.md (6 locations identified in research)
- Replace the "Using Avante AI" section with a consolidated "AI Integration" section documenting Claude Code, OpenCode, and Lectic
- Add Zed editor alternative link near the top of the README
- Add `.claude/README.md` reference in the documentation section

**Non-Goals**:
- Updating `lua/neotex/plugins/ai/README.md` (separate task per research recommendation)
- Updating `MIGRATION.md` or other documentation files
- Restructuring the overall README layout
- Adding new sections beyond what is needed for the AI tool replacement

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Keybinding references from Avante section may be inaccurate for current tools | M | L | Cross-reference with AI README and plugin source files during implementation |
| Breaking internal markdown links or anchor references | L | L | Verify all section links after edits |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 2 |

Phases within the same wave can execute in parallel.

### Phase 1: Add Zed Link and Update Features Overview [COMPLETED]

**Goal**: Add the Zed alternative link at the top of the README and update the Features Overview AI bullet to reflect current plugins.

**Tasks**:
- [ ] Add a note near the top of the README (after the title/introduction) linking to `https://github.com/benbrastmckie/zed` as a user-friendly alternative to NeoVim
- [ ] Update line ~52: Replace Avante bullet in Features Overview AI Assistance section with current AI plugins (Claude Code, OpenCode, Lectic)
- [ ] Update line ~122: Change Module Documentation description from "Avante, Claude Code, and MCP Hub" to "Claude Code, OpenCode, Lectic, and MCP Hub"

**Timing**: 20 minutes

**Depends on**: none

**Files to modify**:
- `README.md` - Top section and Features Overview

**Verification**:
- Zed link appears near the top of README
- Features Overview lists current AI plugins without Avante
- Module Documentation link description is accurate

---

### Phase 2: Replace Avante Section with AI Integration Documentation [COMPLETED]

**Goal**: Remove the entire "Using Avante AI" section (lines ~179-274) and replace it with a consolidated "AI Integration" section documenting the current AI tools and their keybindings.

**Tasks**:
- [ ] Remove the "Using Avante AI" section and all its subsections (~95 lines)
- [ ] Write a new "AI Integration" section covering:
  - Claude Code as primary AI tool with keybindings (`<C-CR>` toggle, `<leader>ac` commands, `<leader>as` sessions, `<leader>ay` yolo mode)
  - OpenCode as alternative TUI (`<C-g>` toggle)
  - Lectic for AI-assisted writing in markdown
- [ ] Add a reference to `.claude/README.md` for agent system architecture details within or adjacent to the new AI section
- [ ] Update line ~307 Quick Access section: Replace Avante reference with Claude Code equivalent

**Timing**: 40 minutes

**Depends on**: 1

**Files to modify**:
- `README.md` - Lines ~179-274 (replace), line ~307 (update)

**Verification**:
- No "Avante" text appears in the replaced section
- All three current AI tools are documented with correct keybindings
- `.claude/README.md` link is present
- Quick Access section references Claude Code

---

### Phase 3: Final Verification and Cleanup [COMPLETED]

**Goal**: Verify zero Avante references remain, all links are valid, and the document reads consistently.

**Tasks**:
- [ ] Search entire README.md for any remaining "Avante" or "avante" references
- [ ] Remove or update any remaining references found
- [ ] Verify all internal markdown links and anchor references are intact
- [ ] Confirm the Lectic section (lines ~310-325) remains unchanged and accurate
- [ ] Read through modified sections to ensure consistent tone and formatting

**Timing**: 15 minutes

**Depends on**: 2

**Files to modify**:
- `README.md` - Any remaining stale references

**Verification**:
- `grep -i avante README.md` returns zero results
- All markdown links resolve correctly
- Document reads coherently with no orphaned references

## Testing & Validation

- [ ] `grep -ic avante README.md` returns 0
- [ ] Zed link (`https://github.com/benbrastmckie/zed`) appears in the first 20 lines
- [ ] `.claude/README.md` is referenced in the documentation or AI section
- [ ] Claude Code, OpenCode, and Lectic are all mentioned in the AI Integration section
- [ ] No broken markdown links or orphaned anchor references

## Artifacts & Outputs

- `plans/01_readme-update-plan.md` (this file)
- `summaries/01_readme-update-summary.md` (post-implementation)
- Updated `README.md` (primary deliverable)

## Rollback/Contingency

Git revert of the implementation commit restores the previous README.md. Since only one file is modified, rollback is straightforward with `git checkout HEAD~1 -- README.md`.
