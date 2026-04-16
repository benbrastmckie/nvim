# Implementation Plan: Update Docs for Task 428 Changes

- **Task**: 429 - Update docs for task 428 changes
- **Status**: [COMPLETED]
- **Effort**: 1.5 hours
- **Dependencies**: Task 428 (completed)
- **Research Inputs**: specs/429_update_docs_for_task_428_changes/reports/02_docs-update-research.md
- **Artifacts**: plans/02_docs-update-plan.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: true

## Overview

Fix 10 stale documentation references across 7 files in `.claude/docs/` that were left behind by task 428. All changes are text replacements: renaming `"language"` to `"task_type"` in manifest examples and delegation contexts, adding missing `routing` objects to manifest examples, replacing the deprecated backup system section, updating renamed spreadsheet agent references, and correcting agent frontmatter examples for model enforcement. No structural changes are needed.

### Research Integration

The research report (02_docs-update-research.md) verified all 6 original audit issues and discovered 4 additional stale references, bringing the total to 10 issues. Each issue has exact current text and replacement text identified with line numbers. Reference manifests (latex, filetypes) and agents (general-implementation-agent, meta-builder-agent) were consulted to validate replacements.

### Roadmap Alignment

Directly advances ROADMAP Phase 1 success metric: "Zero stale references to removed/renamed files in `.claude/`".

## Goals & Non-Goals

**Goals**:
- Fix all 10 verified stale references in `.claude/docs/`
- Ensure manifest examples match actual working manifests (latex, filetypes)
- Ensure agent frontmatter examples match actual agent definitions

**Non-Goals**:
- Fixing stale references outside `.claude/docs/` (e.g., filetypes EXTENSION.md)
- Addressing `--language` CLI flag references (separate follow-up)
- Structural documentation improvements or rewrites

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Incorrect replacement text breaks extension creation guidance | M | L | All replacements verified against actual manifests |
| Missing a stale reference | L | L | Research did comprehensive grep across all docs files |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 2, 3, 4 | -- |

Phases within the same wave can execute in parallel.

### Phase 1: Fix extension-system.md (Issues 1, 2, 3, 10) [COMPLETED]

**Goal**: Update the primary extension architecture doc with backup removal, task_type rename, routing addition, and prose fix.

**Tasks**:
- [ ] Replace backup system section (lines 380-383) with git-based recovery section (Issue 1)
- [ ] Change `"language": "latex"` to `"task_type": "latex"` in manifest example at line 111 (Issue 2)
- [ ] Add `routing` object to manifest example after `"provides"` block, using `"latex"` keys (Issue 3)
- [ ] Change `language: latex` to `task_type: latex` in prose at line 299 (Issue 10)

**Timing**: 25 minutes

**Depends on**: none

**Files to modify**:
- `.claude/docs/architecture/extension-system.md` - 4 text replacements

**Verification**:
- No remaining `"language":` in manifest JSON examples
- Manifest example contains `routing` object
- No `### Backup System` heading remains
- Grep for `language:` finds no stale manifest/prose references

---

### Phase 2: Fix guide files (Issues 2, 3, 5, 7, 8, 9) [COMPLETED]

**Goal**: Update creating-extensions.md, adding-domains.md, creating-skills.md, and creating-agents.md with task_type rename, routing additions, and delegation context fixes.

**Tasks**:
- [ ] In creating-extensions.md: change `"language": "your-domain"` to `"task_type": "your-domain"` at line 55 (Issue 2)
- [ ] In creating-extensions.md: add `routing` object after `"provides"` block, using `"your-domain"` keys (Issue 3)
- [ ] In adding-domains.md: change `"language": "your-domain"` to `"task_type": "your-domain"` at line 77 (Issue 2/5)
- [ ] In adding-domains.md: add `routing` object after `"provides"` block, using `"your-domain"` keys (Issue 3)
- [ ] In adding-domains.md: fix architecture diagram lines 192-194, changing `language:` to `task_type:` (Issue 9)
- [ ] In adding-domains.md: fix prose at line 197 ("Each language type" to "Each task type") (Issue 9)
- [ ] In adding-domains.md: fix line 302 ("language matches" to "task_type matches") (Issue 9)
- [ ] In adding-domains.md: fix line 431 test command to remove `--language` flag (Issue 9)
- [ ] In creating-skills.md: change `"language": "rust"` to `"task_type": "rust"` at line 370 (Issue 7)
- [ ] In creating-skills.md: change "language)" to "task_type)" at line 379 (Issue 7)
- [ ] In creating-agents.md: change `"language": "rust"` to `"task_type": "rust"` at line 276 (Issue 8)

**Timing**: 30 minutes

**Depends on**: none

**Files to modify**:
- `.claude/docs/guides/creating-extensions.md` - task_type rename + routing addition
- `.claude/docs/guides/adding-domains.md` - task_type rename + routing addition + diagram/prose fixes
- `.claude/docs/guides/creating-skills.md` - delegation context task_type rename
- `.claude/docs/guides/creating-agents.md` - delegation context task_type rename

**Verification**:
- Grep for `"language":` in guide files returns no manifest/delegation examples
- All manifest examples include `routing` object
- Architecture diagram uses `task_type:` labels

---

### Phase 3: Fix extension-slim-standard.md (Issue 4) [COMPLETED]

**Goal**: Update the spreadsheet agent reference to use the renamed filetypes-specific agent.

**Tasks**:
- [ ] Replace `skill-spreadsheet | spreadsheet-agent` with `skill-filetypes-spreadsheet | filetypes-spreadsheet-agent` at line 106

**Timing**: 5 minutes

**Depends on**: none

**Files to modify**:
- `.claude/docs/reference/standards/extension-slim-standard.md` - 1 table row replacement

**Verification**:
- No remaining `spreadsheet-agent` or `skill-spreadsheet` references (without prefix)

---

### Phase 4: Fix agent-frontmatter-standard.md (Issue 6) [COMPLETED]

**Goal**: Update the implementation agent example and sonnet usage guidelines to reflect model enforcement changes.

**Tasks**:
- [ ] Replace implementation agent example (lines 105-110): change name to `general-implementation-agent`, description to general/meta/markdown, model to `opus`
- [ ] Replace sonnet usage guideline (lines 57-60): change "Implementation agents with clear plans" to "Team orchestration skills (lightweight coordination)"

**Timing**: 10 minutes

**Depends on**: none

**Files to modify**:
- `.claude/docs/reference/standards/agent-frontmatter-standard.md` - 2 text replacements

**Verification**:
- Implementation agent example shows `model: opus`
- Sonnet guidelines no longer reference implementation agents

## Testing & Validation

- [ ] Grep `.claude/docs/` for `"language":` -- should find zero hits in manifest JSON blocks
- [ ] Grep `.claude/docs/` for `spreadsheet-agent` without a prefix -- should find zero hits
- [ ] Grep `.claude/docs/` for `Backup System` heading -- should find zero hits
- [ ] Grep `.claude/docs/` for `model: sonnet` in implementation agent context -- should find zero hits
- [ ] Verify each modified file renders valid markdown (no broken JSON blocks or tables)

## Artifacts & Outputs

- `specs/429_update_docs_for_task_428_changes/plans/02_docs-update-plan.md` (this plan)
- `specs/429_update_docs_for_task_428_changes/summaries/02_docs-update-summary.md` (after implementation)
- 7 modified documentation files in `.claude/docs/`

## Rollback/Contingency

All changes are to `.claude/docs/` markdown files tracked by git. Use `git checkout HEAD -- .claude/docs/{file}` to revert any individual file, or `git revert` to undo the entire commit.
