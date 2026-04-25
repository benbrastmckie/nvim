# Implementation Plan: Task #499

- **Task**: 499 - Research FORK_SUBAGENT patterns and context: fork strategies
- **Status**: [NOT STARTED]
- **Effort**: 2.5 hours
- **Dependencies**: None
- **Research Inputs**: specs/499_research_fork_subagent_patterns/reports/01_fork-subagent-patterns.md
- **Artifacts**: plans/01_fork-subagent-patterns.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

The research report for task 499 revealed a significant documentation inconsistency: `system-overview.md` asserts that skills "do NOT use `context: fork` or `agent:` frontmatter fields," yet the thin-wrapper template, creation guides, generation guidelines, and two extension skills all use `context: fork` and `agent:` as standard practice. The current core skills work via explicit Task tool delegation with `subagent_type`, making them immune to the `CLAUDE_CODE_FORK_SUBAGENT=1` env var. This plan addresses the documentation inconsistency, creates a reference guide for fork patterns, and documents the team-mode optimization opportunity for future work.

### Research Integration

Key findings from the research report integrated into this plan:
- `CLAUDE_CODE_FORK_SUBAGENT=1` only fires when `subagent_type` is omitted; current thin-wrapper skills always specify it
- `context: fork` (isolation) and `FORK_SUBAGENT` (inheritance) solve opposite problems
- The `system-overview.md` assertion contradicts the thin-wrapper template, creating-skills guide, generation-guidelines, component-checklist, and two present-extension skills
- `skill-meta` uses `agent:` but not `context: fork`, further contradicting the assertion
- Team mode is the highest-impact optimization opportunity for prompt cache sharing

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md found.

## Goals & Non-Goals

**Goals**:
- Reconcile the `system-overview.md` assertion with actual `context: fork` and `agent:` usage across the codebase
- Create a reference guide documenting fork patterns, cache mechanics, and decision criteria
- Update the thin-wrapper template to clarify when `context: fork` vs Task-tool delegation is appropriate
- Document team-mode cache optimization opportunity for future planning

**Non-Goals**:
- Modifying core skill delegation patterns (Task tool works correctly)
- Enabling `CLAUDE_CODE_FORK_SUBAGENT=1` globally
- Implementing team-mode cache optimization (future task)
- Adding `context: fork` to existing core skills

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Documentation changes introduce new inconsistencies | M | M | Grep all `context: fork` references after edits; verify consistency |
| Changing system-overview.md confuses /meta command generation | M | L | Preserve the explicit delegation principle; only soften the absolute prohibition |
| Extension skill authors misuse `context: fork` after doc update | L | L | Include clear decision criteria in the reference guide |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3 | 1 |
| 3 | 4 | 2, 3 |

Phases within the same wave can execute in parallel.

### Phase 1: Reconcile system-overview.md [NOT STARTED]

**Goal**: Fix the contradictory assertion in system-overview.md to reflect actual usage patterns.

**Tasks**:
- [ ] Read `.claude/context/architecture/system-overview.md` lines 100-120
- [ ] Update the Note at line 112 to distinguish core skills (Task-tool delegation) from extension skills (may use `context: fork` + `agent:`)
- [ ] Acknowledge that `skill-meta` uses `agent:` frontmatter
- [ ] Apply the same fix to `.claude/extensions/core/context/architecture/system-overview.md` (the extension core copy)
- [ ] Verify no other files in `.claude/context/architecture/` reference the old assertion

**Timing**: 30 minutes

**Depends on**: none

**Files to modify**:
- `.claude/context/architecture/system-overview.md` - Update Note about `context: fork` and `agent:` usage
- `.claude/extensions/core/context/architecture/system-overview.md` - Mirror the same update

**Verification**:
- Grep for "do NOT use.*context.*fork" returns zero matches
- The updated text accurately describes which skills use which pattern

---

### Phase 2: Create fork patterns reference guide [NOT STARTED]

**Goal**: Create a new context file documenting fork mechanisms, cache mechanics, and decision criteria for skill authors.

**Tasks**:
- [ ] Create `.claude/context/patterns/fork-patterns.md` with sections:
  - Mechanism overview (`context: fork` vs `CLAUDE_CODE_FORK_SUBAGENT=1`)
  - Prompt cache sharing mechanics and cost implications
  - Decision matrix: when to use `context: fork` vs Task-tool delegation
  - Constraints and incompatibilities (headless, no recursive forks, subagent_type)
  - Team-mode optimization opportunity (future work marker)
- [ ] Add an entry in `.claude/context/index.json` for the new file with appropriate `load_when` targeting meta task type and relevant agents
- [ ] Apply the same addition to `.claude/extensions/core/context/index.json` if extension core mirrors the index

**Timing**: 45 minutes

**Depends on**: 1

**Files to modify**:
- `.claude/context/patterns/fork-patterns.md` - New file
- `.claude/context/index.json` - Add entry for fork-patterns.md

**Verification**:
- The new file exists and contains all listed sections
- `jq` query for "fork-patterns" in index.json returns a valid entry
- Content is consistent with research report findings

---

### Phase 3: Update thin-wrapper template and creation guides [NOT STARTED]

**Goal**: Clarify the thin-wrapper template to explain both delegation patterns and when each applies.

**Tasks**:
- [ ] Update `.claude/context/patterns/thin-wrapper-skill.md` to add a section distinguishing:
  - Core skills: Use Task tool with explicit `subagent_type` for structured delegation (session_id, delegation_depth, memory_context)
  - Extension skills: May use `context: fork` + `agent:` for simpler delegation when structured context injection is not needed
- [ ] Update `.claude/context/templates/thin-wrapper-skill.md` to add a comment or note explaining that `context: fork` is optional and when to use it vs explicit Task tool delegation
- [ ] Update `.claude/docs/guides/creating-skills.md` to reference the new fork-patterns guide and clarify the two patterns
- [ ] Apply matching updates to the extension core copies of these files
- [ ] Verify `generation-guidelines.md` and `component-checklist.md` are consistent with the updated guidance

**Timing**: 45 minutes

**Depends on**: 1

**Files to modify**:
- `.claude/context/patterns/thin-wrapper-skill.md` - Add delegation pattern comparison
- `.claude/context/templates/thin-wrapper-skill.md` - Add explanatory note
- `.claude/docs/guides/creating-skills.md` - Reference fork-patterns guide
- `.claude/extensions/core/context/patterns/thin-wrapper-skill.md` - Mirror update
- `.claude/extensions/core/context/templates/thin-wrapper-skill.md` - Mirror update
- `.claude/extensions/core/docs/guides/creating-skills.md` - Mirror update

**Verification**:
- Templates clearly distinguish the two delegation patterns
- No file suggests `context: fork` is universally required or prohibited
- Creation guide references the fork-patterns guide

---

### Phase 4: Cross-reference verification and consistency sweep [NOT STARTED]

**Goal**: Verify all documentation is internally consistent after the changes.

**Tasks**:
- [ ] Grep all `.claude/` files for "context: fork" and verify each reference is consistent with updated guidance
- [ ] Grep for "do NOT use" or "do not use" near "fork" or "agent:" to catch stale prohibitions
- [ ] Verify `component-checklist.md` and `generation-guidelines.md` in both `.claude/context/` and `.claude/extensions/core/` are consistent
- [ ] Run `.claude/scripts/check-extension-docs.sh` to validate extension documentation integrity
- [ ] Verify skill-meta's use of `agent:` without `context: fork` is documented as a valid pattern

**Timing**: 30 minutes

**Depends on**: 2, 3

**Files to modify**:
- Any files found with stale assertions (TBD based on sweep results)

**Verification**:
- Zero stale prohibitions found
- `check-extension-docs.sh` passes
- All `context: fork` references are consistent with the new guidance

## Testing & Validation

- [ ] Grep for "do NOT use.*context.*fork" returns zero matches across `.claude/`
- [ ] Grep for "context: fork" in all files confirms consistent messaging
- [ ] The fork-patterns reference guide exists and is indexed
- [ ] `check-extension-docs.sh` exits 0
- [ ] Thin-wrapper template clearly explains both delegation approaches

## Artifacts & Outputs

- `specs/499_research_fork_subagent_patterns/plans/01_fork-subagent-patterns.md` (this plan)
- `.claude/context/patterns/fork-patterns.md` (new reference guide)
- Updated: `.claude/context/architecture/system-overview.md`
- Updated: `.claude/context/patterns/thin-wrapper-skill.md`
- Updated: `.claude/context/templates/thin-wrapper-skill.md`
- Updated: `.claude/docs/guides/creating-skills.md`
- Mirror updates in `.claude/extensions/core/` for affected files

## Rollback/Contingency

All changes are documentation-only edits to `.claude/` files. Rollback via `git checkout` of affected files. No runtime behavior changes. If the fork-patterns guide proves misleading, it can be removed from the index without affecting any skill execution.
