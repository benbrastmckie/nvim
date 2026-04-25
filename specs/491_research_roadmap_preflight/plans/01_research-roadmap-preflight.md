# Implementation Plan: Task #491

- **Task**: 491 - research_roadmap_preflight
- **Status**: [COMPLETED]
- **Effort**: 1 hour
- **Dependencies**: None
- **Research Inputs**: specs/491_research_roadmap_preflight/reports/01_research-roadmap-preflight.md
- **Artifacts**: plans/01_research-roadmap-preflight.md (this file)
- **Standards**: plan-format.md; status-markers.md; artifact-management.md; tasks.md
- **Type**: meta
- **Lean Intent**: true

## Overview

Add ROADMAP.md preflight consultation to the `/research` command so research agents receive strategic roadmap context automatically, suppressible with `--clean`. The implementation follows the existing Stage 4a memory retrieval pattern: check `clean_flag`, read `specs/ROADMAP.md`, inject content as a `<roadmap-context>` tagged block into the agent prompt. Three files need modification across the skill layer (reading and injection), command layer (flag documentation), and agent layer (prefer injected content over self-reading).

### Research Integration

Key findings from the research report:
- The `roadmap_path` field is already passed in delegation context, and the agent already has Stage 1.5 to self-read the roadmap -- but this wastes tokens on every invocation
- Stage 4a memory retrieval is the exact template: check `clean_flag`, read content, inject as tagged block
- ROADMAP.md is 29 lines, well within injection budget -- full content injection, no summarization needed
- `<roadmap-context>` tag name follows the `<memory-context>` pattern for consistency

### Roadmap Alignment

This task advances **Agent System Quality** in Phase 1. It improves agent efficiency by eliminating redundant file I/O and provides strategic context to research agents by default.

## Goals & Non-Goals

**Goals**:
- Add Stage 4c to skill-researcher that reads ROADMAP.md and injects it into the agent prompt
- Suppress roadmap injection when `--clean` flag is set (consistent with memory suppression)
- Update general-research-agent to prefer injected `<roadmap-context>` over self-reading
- Document the updated `--clean` flag behavior in research.md

**Non-Goals**:
- Applying this pattern to `/plan` or `/implement` commands (follow-up work)
- Updating team research skill (follow-up work)
- Summarizing or filtering roadmap content (not needed at current size)
- Removing `roadmap_path` from delegation context (kept as fallback)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Roadmap grows very large, wasting tokens | M | L | Add a comment noting future size-check threshold (~100 lines) |
| ROADMAP.md does not exist | None | L | Graceful skip via empty-string check, same as memory pattern |
| Stage numbering conflicts with existing stages | M | L | Research confirmed 4c slots cleanly between 4a (memory) and 4b (format) |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |

Phases within the same wave can execute in parallel.

### Phase 1: Add Stage 4c and update Stage 5 injection in skill-researcher [COMPLETED]

**Goal**: Add roadmap consultation to the skill preflight and inject content into the agent prompt.

**Tasks**:
- [ ] Add Stage 4c (Roadmap Consultation) to `.claude/skills/skill-researcher/SKILL.md` between Stage 4a (memory) and Stage 4b (format injection)
  - Check `clean_flag` -- skip if true
  - Read `specs/ROADMAP.md` -- if file exists, capture content
  - If content is non-empty, store for injection
- [ ] Update Stage 5 (Delegate to Agent) prompt injection instructions to include `<roadmap-context>` block after `<memory-context>` and before task-specific instructions
  - Use format: `<roadmap-context>\n## Project Roadmap (auto-injected, read-only)\n\n{content}\n</roadmap-context>`
- [ ] Verify Stage 4c follows the same guard pattern as Stage 4a (clean_flag check, graceful skip on missing file)

**Timing**: 30 minutes

**Depends on**: none

**Files to modify**:
- `.claude/skills/skill-researcher/SKILL.md` - Add Stage 4c (~25 lines), update Stage 5 injection instructions (~5 lines)

**Verification**:
- Stage 4c exists between 4a and 4b with clean_flag guard
- Stage 5 prompt template includes `<roadmap-context>` block placement
- Pattern matches Stage 4a structure (check flag, read file, inject or skip)

---

### Phase 2: Update command docs and agent to prefer injected content [COMPLETED]

**Goal**: Document the updated `--clean` behavior and update the agent to consume injected roadmap context.

**Tasks**:
- [ ] Update `.claude/commands/research.md` Options table: change `--clean` description from "Skip automatic memory retrieval" to "Skip automatic memory and roadmap retrieval"
- [ ] Update `.claude/agents/general-research-agent.md` Stage 1.5 to prefer injected `<roadmap-context>`:
  - If `<roadmap-context>` is present in the prompt, parse it directly (no file I/O)
  - If not present (clean mode or missing file), fall back to reading `roadmap_path` from delegation context
  - Keep existing `roadmap_path` handling as fallback
- [ ] Verify the agent Stage 1.5 update preserves backward compatibility (still works if no injection occurs)

**Timing**: 30 minutes

**Depends on**: 1

**Files to modify**:
- `.claude/commands/research.md` - Update `--clean` flag description (1 line)
- `.claude/agents/general-research-agent.md` - Update Stage 1.5 (~10 lines modified)

**Verification**:
- `--clean` description mentions both memory and roadmap suppression
- Agent Stage 1.5 checks for `<roadmap-context>` before attempting file read
- Fallback to `roadmap_path` self-reading still documented

## Testing & Validation

- [ ] Read modified SKILL.md and confirm Stage 4c exists with correct placement and clean_flag guard
- [ ] Read modified SKILL.md Stage 5 and confirm `<roadmap-context>` injection is documented
- [ ] Read modified research.md and confirm `--clean` description updated
- [ ] Read modified general-research-agent.md and confirm Stage 1.5 prefers injected content with fallback
- [ ] Verify no references to removed or renamed stages were introduced

## Artifacts & Outputs

- `.claude/skills/skill-researcher/SKILL.md` - Updated with Stage 4c and Stage 5 injection
- `.claude/commands/research.md` - Updated `--clean` flag description
- `.claude/agents/general-research-agent.md` - Updated Stage 1.5 roadmap handling
- `specs/491_research_roadmap_preflight/plans/01_research-roadmap-preflight.md` - This plan
- `specs/491_research_roadmap_preflight/summaries/01_research-roadmap-preflight-summary.md` - Execution summary (after implementation)

## Rollback/Contingency

All changes are to markdown specification files with no runtime dependencies. Revert via `git checkout` of the three modified files. The existing `roadmap_path` delegation context field and agent self-reading behavior provide full backward compatibility if the injection mechanism needs to be removed.
