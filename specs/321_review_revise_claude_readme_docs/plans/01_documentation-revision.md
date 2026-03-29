# Implementation Plan: Task #321

- **Task**: 321 - review_revise_claude_readme_docs
- **Status**: [NOT STARTED]
- **Effort**: 4 hours
- **Dependencies**: None
- **Research Inputs**: specs/321_review_revise_claude_readme_docs/reports/01_documentation-audit.md
- **Artifacts**: plans/01_documentation-revision.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Revise .claude/README.md and related documentation to be accurate, complete, and navigable. The research audit identified outdated agent references, missing file references, incorrect ProofChecker terminology, and an overly long README.md (36KB) that attempts to serve both as introduction and reference. This plan restructures README.md as a concise navigation hub (~200-300 lines) linking to detailed documentation, removes broken references, and fixes terminology throughout. Per user constraint, no QUICK-START.md will be created.

### Research Integration

Key findings from 01_documentation-audit.md:
- 6 missing file references (QUICK-START.md, TESTING.md, context/system/, agents/specialists/, etc.)
- 5 outdated agent name references (researcher -> general-research-agent, etc.)
- 19 files reference "ProofChecker" incorrectly
- README.md is 1069 lines; should be ~200-300 lines as navigation hub
- CLAUDE.md and docs/README.md are well-maintained and accurate

## Goals & Non-Goals

**Goals**:
- Restructure README.md as concise navigation hub (~200-300 lines)
- Remove all references to non-existent files
- Fix outdated agent names throughout documentation
- Replace ProofChecker references with "Neovim Configuration"
- Ensure all links are valid and point to existing files
- Make extension system prominent in README.md

**Non-Goals**:
- Creating QUICK-START.md (user explicitly rejected)
- Creating TESTING.md (remove reference instead)
- Moving content that is already in appropriate locations
- Changing the underlying architecture or behavior
- Modifying code or configuration files

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Breaking existing valid links | M | M | Comprehensive link validation in Phase 5 |
| Losing important content | H | L | Move content to appropriate docs/ locations, never delete |
| User confusion | M | L | Clear navigation structure with descriptive links |
| Missing some ProofChecker references | L | M | Use grep to find all occurrences before fixing |

## Implementation Phases

### Phase 1: Audit and Remove Broken References [NOT STARTED]

**Goal**: Eliminate all references to non-existent files

**Tasks**:
- [ ] Search for references to QUICK-START.md and remove them
- [ ] Search for references to TESTING.md and remove them
- [ ] Search for references to context/system/ and update or remove
- [ ] Search for references to agents/specialists/ and remove
- [ ] Search for references to subagent-delegation-guide.md in workflows/ and update path
- [ ] Search for references to subagent-return-format.md in standards/ and update to formats/

**Timing**: 45 minutes

**Files to modify**:
- `.claude/README.md` - Primary location of broken references
- Any other files found via grep containing these references

**Verification**:
- grep for each missing file path returns zero results
- No 404-style broken links remain in documentation

---

### Phase 2: Fix ProofChecker References [NOT STARTED]

**Goal**: Replace incorrect "ProofChecker" terminology with "Neovim Configuration"

**Tasks**:
- [ ] Run grep to identify all 19+ files containing "ProofChecker"
- [ ] Categorize references by context (docs, context files, guides)
- [ ] Replace "ProofChecker" with appropriate terminology:
  - "ProofChecker README" -> "Neovim Configuration README"
  - "ProofChecker project" -> "Neovim configuration project"
  - "ProofChecker" (standalone) -> "this Neovim configuration"
- [ ] Verify each replacement maintains sentence coherence

**Timing**: 30 minutes

**Files to modify**:
- `.claude/docs/README.md`
- `.claude/docs/guides/user-installation.md`
- Other files identified by grep (approximately 17 additional)

**Verification**:
- grep for "ProofChecker" returns zero results
- Each replacement reads naturally in context

---

### Phase 3: Fix Outdated Agent References [NOT STARTED]

**Goal**: Update all agent name references to current naming scheme

**Tasks**:
- [ ] Search for "researcher" agent references and update to "general-research-agent"
- [ ] Search for "implementer" agent references and update to "general-implementation-agent"
- [ ] Search for "atomic-task-numberer" and remove/update references
- [ ] Search for "status-sync-manager" and remove/update references
- [ ] Search for "task-executor" and remove/update references
- [ ] Update agent tables in README.md to match actual agents/ directory contents

**Timing**: 30 minutes

**Files to modify**:
- `.claude/README.md` - Main agent documentation
- Any other files found via grep with old agent names

**Verification**:
- Agent names in documentation match files in .claude/agents/
- No references to non-existent agents remain

---

### Phase 4: Restructure README.md as Navigation Hub [NOT STARTED]

**Goal**: Transform README.md from 1069 lines to ~200-300 line navigation hub

**Tasks**:
- [ ] Read current README.md fully to understand all sections
- [ ] Create new structure outline:
  - Brief Overview (2 paragraphs)
  - Quick Reference (key commands table, link to CLAUDE.md)
  - Architecture (three-layer diagram, link to docs/architecture/)
  - Core Components (commands/skills/agents tables with links)
  - Extensions (prominent section, list extensions, link to extensions/README.md)
  - Documentation Map (links to docs/ subdirectories)
  - Related Files (CLAUDE.md, docs/README.md)
- [ ] Move detailed content to appropriate locations:
  - Delegation Flow details -> verify in context/orchestration/delegation.md
  - State Management details -> verify in context/orchestration/state-management.md
  - Error Handling details -> verify covered in rules/error-handling.md
  - Git Workflow details -> verify covered in rules/git-workflow.md
  - Forked Subagent Pattern -> context/patterns/ (create if needed)
- [ ] Write new concise README.md with navigation links
- [ ] Preserve version history section at bottom

**Timing**: 1.5 hours

**Files to modify**:
- `.claude/README.md` - Complete rewrite as navigation hub
- `.claude/context/patterns/forked-subagent-pattern.md` - Create if moving content

**Verification**:
- README.md is 200-350 lines (allows some flexibility)
- All major topics are covered via links
- No detailed technical content duplicated
- Extension system is prominently featured

---

### Phase 5: Validate All Links [NOT STARTED]

**Goal**: Ensure every link in documentation points to existing file

**Tasks**:
- [ ] Extract all markdown links from README.md
- [ ] Verify each linked file exists
- [ ] Extract links from docs/README.md and verify
- [ ] Check cross-references between context files
- [ ] Fix any broken links discovered
- [ ] Document any intentionally removed sections

**Timing**: 45 minutes

**Files to modify**:
- Any files with broken links discovered during validation

**Verification**:
- Manual or scripted check that all linked paths exist
- No dead links in primary documentation files

---

### Phase 6: Final Review and Cleanup [NOT STARTED]

**Goal**: Ensure documentation is coherent, consistent, and complete

**Tasks**:
- [ ] Read through new README.md for coherence
- [ ] Verify terminology consistency across files
- [ ] Check that navigation from README.md -> docs/ -> detailed files works
- [ ] Update README.md version to 3.0 and date
- [ ] Verify CLAUDE.md still accurate (should be, minimal changes)
- [ ] Create brief summary of changes for commit message

**Timing**: 30 minutes

**Files to modify**:
- `.claude/README.md` - Final polish, version update

**Verification**:
- Documentation reads as cohesive system
- New user can navigate from README.md to find any information
- Version and date updated

## Testing & Validation

- [ ] grep for "ProofChecker" returns zero matches
- [ ] grep for removed file paths (QUICK-START.md, TESTING.md, etc.) returns zero matches
- [ ] grep for old agent names returns zero matches (researcher, implementer as standalone refs)
- [ ] All markdown links in README.md point to existing files
- [ ] README.md line count is 200-350 lines
- [ ] Extension system has dedicated section with 5+ lines

## Artifacts & Outputs

- `.claude/README.md` - Restructured navigation hub (~250 lines)
- `.claude/context/patterns/forked-subagent-pattern.md` - New file if content moved
- Any other files modified to fix broken references

## Rollback/Contingency

If restructuring causes confusion:
1. Git history preserves original README.md
2. Can revert to previous version with `git checkout HEAD~1 -- .claude/README.md`
3. All moved content remains in destination files

If links break after changes:
1. Run link validation again to identify issues
2. Fix individual broken links
3. Detailed content remains in docs/ and context/ directories
