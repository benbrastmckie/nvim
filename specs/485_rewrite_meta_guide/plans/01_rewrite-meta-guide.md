# Implementation Plan: Rewrite meta-guide.md

- **Task**: 485 - Rewrite meta-guide.md to match current system
- **Status**: [IMPLEMENTING]
- **Effort**: 2 hours
- **Dependencies**: None
- **Research Inputs**: specs/485_rewrite_meta_guide/reports/01_team-research.md
- **Artifacts**: plans/01_rewrite-meta-guide.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

The current `meta-guide.md` (462 lines) is entirely fictional, describing phantom systems (5-phase/12-question interview, fabricated performance statistics, non-existent output structures) that bear no resemblance to the actual `/meta` system. The actual system is a 3-mode command (interactive/prompt/analyze) with a 7-stage interview, AskUserQuestion enforcement, Kahn's topological sorting, and DAG visualization. A complete ground-up rewrite is required, along with removing the always-available import from CLAUDE.md (index.json already scopes it correctly) and syncing both copies (extension source and deployed).

### Research Integration

Team research report (4 teammates) identified 14 specific inaccuracies, documented the actual 3-mode/7-stage architecture, cataloged cross-reference patterns with other commands, and flagged 5 system shortcomings (v1 protocol mismatch, always-available import pollution, broken references, missing postflight, vestigial DetectDomainType). The recommended guide structure from the synthesis section serves as the primary blueprint for the rewrite.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No /meta-specific roadmap items exist. The rewrite supports "Agent System Quality" (Phase 1) by replacing phantom documentation with accurate system reference, enabling future frontmatter validation and lint scripts.

## Goals & Non-Goals

**Goals**:
- Replace the entire meta-guide.md with accurate documentation of the current /meta system
- Document all 3 modes (interactive, prompt, analyze) as primary organizational structure
- Document the actual 7-stage interview at conceptual level
- Document multi-task creation standard compliance (all 8 components)
- Include Known Limitations section (v1 protocol, missing postflight, missing memory)
- Include Future Extensions section (memory integration, roadmap awareness)
- Remove meta-guide.md from always-available imports in CLAUDE.md
- Update both copies: extension source and deployed
- Fix the broken reference to `.claude/context/standards/commands.md`

**Non-Goals**:
- Implementing any system changes (v2 protocol migration, memory integration, postflight)
- Updating sister files (architecture-principles.md, standards-checklist.md, interview-patterns.md)
- Redesigning the /meta command itself
- Reproducing agent pseudocode (Kahn's algorithm implementation details)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Scope creep into system redesign vs documentation | M | M | Strict "document current state" principle; improvements go to Known Limitations/Future Extensions |
| Documenting aspirational v2 protocol as current | H | L | Research explicitly resolved: document actual v1 behavior, note mismatch |
| Extension source and deployed copy diverge | M | L | Phase 3 explicitly syncs both copies and verifies content match |
| CLAUDE.md import removal breaks context loading | L | L | index.json already has correct conditional loading; removing always-available just stops context pollution |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 2 |

Phases within the same wave can execute in parallel.

### Phase 1: Write new meta-guide.md content [COMPLETED]

**Goal**: Create the complete replacement meta-guide.md from scratch based on research findings and source-of-truth files.

**Tasks**:
- [ ] Read the actual source files for reference: `.claude/commands/meta.md`, `.claude/skills/skill-meta/SKILL.md`, `.claude/agents/meta-builder-agent.md`
- [ ] Read `.claude/docs/reference/standards/multi-task-creation-standard.md` for multi-task standard details
- [ ] Write new meta-guide.md at `.claude/context/meta/meta-guide.md` (deployed copy) following the recommended structure from research synthesis:
  - Overview section: purpose, critical distinction (creates tasks not implementations), delegation chain
  - Modes section: Interactive (no args), Prompt (with text), Analyze (--analyze)
  - Interview stages section: conceptual description of 7 stages with actual questions/patterns
  - Task dependency system: dependency types, validation, Kahn's algorithm (conceptual), visualization
  - Multi-task creation standard compliance: all 8 components
  - What You Get section: task entries, directories, dependency visualization, next steps
  - After /meta: The Lifecycle section: research -> plan -> implement, standard skill routing
  - Known Limitations: v1 return protocol, minimal postflight, no memory integration
  - Future Extensions: memory retrieval, roadmap-aware priority hints, sister file updates
  - Resources: actual file paths to command, skill, agent
- [ ] Remove broken reference to `.claude/context/standards/commands.md`
- [ ] Target ~200-300 lines (concise but comprehensive)

**Timing**: 1 hour

**Depends on**: none

**Files to modify**:
- `.claude/context/meta/meta-guide.md` - Complete replacement

**Verification**:
- New guide documents all 3 modes
- New guide documents 7-stage interview at conceptual level
- No references to phantom systems (orchestrators, subagents, 3-level context, performance statistics)
- No broken file references
- Known Limitations and Future Extensions sections present

---

### Phase 2: Update CLAUDE.md and extension source files [COMPLETED]

**Goal**: Remove the always-available import of meta-guide.md from CLAUDE.md and sync the extension source copy.

**Tasks**:
- [ ] Remove `- @.claude/context/meta/meta-guide.md` from the Context Imports section in `.claude/extensions/core/merge-sources/claudemd.md` (the extension source for CLAUDE.md generation)
- [ ] Copy the new meta-guide.md to the extension source location: `.claude/extensions/core/context/meta/meta-guide.md`
- [ ] Verify both copies have identical content (diff check)

**Timing**: 20 minutes

**Depends on**: 1

**Files to modify**:
- `.claude/extensions/core/merge-sources/claudemd.md` - Remove always-available meta-guide.md import
- `.claude/extensions/core/context/meta/meta-guide.md` - Replace with new content

**Verification**:
- `diff` between deployed and extension source copies shows no differences
- CLAUDE.md Context Imports section no longer lists meta-guide.md
- index.json still has correct conditional loading (no changes needed there)

---

### Phase 3: Validation and regeneration [NOT STARTED]

**Goal**: Regenerate CLAUDE.md from merge sources and verify the complete change set is consistent.

**Tasks**:
- [ ] Regenerate `.claude/CLAUDE.md` by running the extension loader or manually removing the meta-guide.md line from the deployed CLAUDE.md
- [ ] Verify the generated CLAUDE.md no longer has meta-guide.md in always-available imports
- [ ] Verify meta-guide.md is still discoverable via index.json conditional loading (grep for the entry)
- [ ] Verify no other files reference the broken `.claude/context/standards/commands.md` path
- [ ] Spot-check that no phantom terminology remains in the new guide (search for "orchestrator", "subagent", "3-level context", "Level 1", "Level 2", "+20%")

**Timing**: 20 minutes

**Depends on**: 2

**Files to modify**:
- `.claude/CLAUDE.md` - Regenerated (meta-guide.md import removed)

**Verification**:
- CLAUDE.md regenerated successfully
- No phantom terminology in new meta-guide.md
- index.json entry for meta-guide.md unchanged (still conditional on meta task type)
- Both copies of meta-guide.md are identical

## Testing & Validation

- [ ] New meta-guide.md accurately describes the 3 modes of /meta
- [ ] New meta-guide.md documents 7 interview stages at conceptual level
- [ ] No references to phantom systems remain (orchestrators, subagents, 3-level context allocation)
- [ ] No fabricated performance statistics remain (+20%, +25%, 80%)
- [ ] Broken `.claude/context/standards/commands.md` reference removed
- [ ] Known Limitations section documents: v1 protocol, missing postflight, no memory integration
- [ ] Future Extensions section documents: memory retrieval, roadmap awareness
- [ ] Both copies (deployed + extension source) are identical
- [ ] CLAUDE.md no longer lists meta-guide.md as always-available import
- [ ] index.json conditional loading unchanged

## Artifacts & Outputs

- `specs/485_rewrite_meta_guide/plans/01_rewrite-meta-guide.md` (this plan)
- `.claude/context/meta/meta-guide.md` (rewritten deployed copy)
- `.claude/extensions/core/context/meta/meta-guide.md` (rewritten extension source copy)
- `.claude/extensions/core/merge-sources/claudemd.md` (import removed)
- `.claude/CLAUDE.md` (regenerated)

## Rollback/Contingency

All modified files are tracked in git. If the rewrite introduces problems:
1. `git checkout HEAD -- .claude/context/meta/meta-guide.md` to restore the old guide
2. `git checkout HEAD -- .claude/extensions/core/context/meta/meta-guide.md` for extension source
3. `git checkout HEAD -- .claude/extensions/core/merge-sources/claudemd.md` for CLAUDE.md source
4. Regenerate CLAUDE.md from restored merge sources
