# Implementation Plan: Task #436

- **Task**: 436 - Resolve /convert command: documented but not implemented
- **Status**: [COMPLETED]
- **Effort**: 0.25 hours
- **Dependencies**: None
- **Research Inputs**: reports/01_convert-command.md
- **Artifacts**: plans/01_convert-command.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: true

## Overview

The `/convert` command exists in the filetypes extension at `.claude/extensions/filetypes/commands/convert.md` with full infrastructure (agents, skills, context). The user-guide.md presents it alongside core commands without noting it requires the filetypes extension. This plan adds extension annotations at 2 locations in user-guide.md to clarify the dependency.

### Research Integration

Research report `reports/01_convert-command.md` confirmed the command exists in the filetypes extension with complete infrastructure. The issue is purely a documentation clarity problem: user-guide.md lists `/convert` in the "Utility Commands" section and summary table without indicating it requires extension loading. The fix is a 2-line annotation edit.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md consulted.

## Goals & Non-Goals

**Goals**:
- Add "(requires filetypes extension)" annotation to the /convert section in user-guide.md
- Add extension annotation to the /convert entry in the command summary table

**Non-Goals**:
- Creating a core commands/convert.md (extension architecture is correct)
- Redesigning the extension documentation pattern
- Modifying any other documentation files (extension-slim-standard.md references are already correctly scoped)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Line numbers shifted since research | L | L | Grep for section headings instead of hardcoded line numbers |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |

Phases within the same wave can execute in parallel.

### Phase 1: Annotate user-guide.md [NOT STARTED]

**Goal**: Add extension requirement annotations to both /convert references in user-guide.md

**Tasks**:
- [ ] Locate the /convert section header in user-guide.md (around line 462) and add "(requires filetypes extension)" annotation
- [ ] Locate the /convert entry in the command summary table (around line 511) and add extension annotation
- [ ] Verify both edits render correctly in markdown

**Timing**: 0.25 hours

**Depends on**: none

**Files to modify**:
- `.claude/docs/guides/user-guide.md` - Add extension requirement annotation at 2 locations

**Verification**:
- Grep for "filetypes" in user-guide.md confirms both annotations present
- No other /convert references need updating (research confirmed all others are correctly scoped)

## Testing & Validation

- [ ] Both annotation locations in user-guide.md contain "(requires filetypes extension)" or equivalent
- [ ] Markdown renders correctly (no broken tables or headings)
- [ ] No unintended changes to other sections of user-guide.md

## Artifacts & Outputs

- plans/01_convert-command.md (this file)
- summaries/01_convert-command-summary.md (after implementation)

## Rollback/Contingency

Revert the 2-line edit in user-guide.md via git. No other files are modified.
