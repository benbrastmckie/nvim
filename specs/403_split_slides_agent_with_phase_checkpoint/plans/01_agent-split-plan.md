# Implementation Plan: Split slides-agent into 3 specialized agents with Phase Checkpoint Protocol

- **Task**: 403 - Split slides-agent into 3 specialized agents with Phase Checkpoint Protocol
- **Status**: [NOT STARTED]
- **Effort**: 1.5 hours
- **Dependencies**: None
- **Research Inputs**: specs/403_split_slides_agent_with_phase_checkpoint/reports/01_agent-split-research.md
- **Artifacts**: plans/01_agent-split-plan.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Replace the monolithic `slides-agent.md` (300 lines) with 3 specialized agents ported from the zed repository: `slides-research-agent.md` (verbatim copy), `pptx-assembly-agent.md` (copy + Phase Checkpoint Protocol), and `slidev-assembly-agent.md` (copy + Phase Checkpoint Protocol). The Phase Checkpoint Protocol enables plan heading status tracking, per-phase git commits, and resume discovery for assembly workflows. After all 3 agents are verified, delete the old `slides-agent.md`.

### Research Integration

The research report (01_agent-split-research.md) provides:
- Exact source and target paths for all 3 agents
- Gap analysis confirming research agent needs no phase tracking (single-stage workflow)
- Complete Phase Checkpoint Protocol specification with phase-to-stage mapping tables for both assembly agents
- List of 5 modifications needed per assembly agent (preamble step, commit approach, 3 MUST DO items)
- Confirmation that context reference paths need no adjustment (extension loader merges paths)

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

This task does not directly advance any current ROADMAP.md items. It is foundational infrastructure for the present extension's multi-agent slide generation pipeline (tasks 405, 406, 407 depend on it).

## Goals & Non-Goals

**Goals**:
- Create 3 well-formed agent files in `.claude/extensions/present/agents/`
- Add Phase Checkpoint Protocol to both assembly agents (pptx and slidev)
- Delete the old monolithic slides-agent.md
- Ensure all agents follow existing agent conventions (frontmatter, metadata return pattern, etc.)

**Non-Goals**:
- Updating skill-slides SKILL.md routing (task 405)
- Updating manifest.json agent listings (task 407)
- Modifying any context files or templates (task 404)
- Testing end-to-end slide generation workflow

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Phase Checkpoint Protocol injection breaks agent execution flow | H | L | Follow exact specification from research report; use grant-agent as reference |
| Context path references incorrect after copy | M | L | Research confirms no path changes needed; verify by grep after copy |
| Old slides-agent deleted before new agents verified | H | L | Delete in final phase after verification |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3 | 1 |
| 3 | 4 | 2, 3 |

Phases within the same wave can execute in parallel.

### Phase 1: Copy slides-research-agent.md [COMPLETED]

**Goal**: Create the research agent by copying verbatim from zed source.

**Tasks**:
- [ ] Copy `/home/benjamin/.config/zed/.claude_NEW/agents/slides-research-agent.md` to `/home/benjamin/.config/nvim/.claude/extensions/present/agents/slides-research-agent.md`
- [ ] Read the copied file and verify: frontmatter contains `name: slides-research-agent` and `model: opus`
- [ ] Verify delegation path references `slides-research-agent` (not old `slides-agent`)
- [ ] Verify MUST NOT items include prohibitions on loading PPTX/Slidev context

**Timing**: 15 minutes

**Depends on**: none

**Files to modify**:
- `.claude/extensions/present/agents/slides-research-agent.md` - CREATE (copy from zed)

**Verification**:
- File exists and is valid markdown
- Frontmatter fields present (name, description, model)
- No references to old slides-agent
- Agent type in metadata section is `slides-research-agent`

---

### Phase 2: Copy and augment pptx-assembly-agent.md [COMPLETED]

**Goal**: Create the PPTX assembly agent with Phase Checkpoint Protocol.

**Tasks**:
- [ ] Copy `/home/benjamin/.config/zed/.claude_NEW/agents/pptx-assembly-agent.md` to `/home/benjamin/.config/nvim/.claude/extensions/present/agents/pptx-assembly-agent.md`
- [ ] Read grant-agent.md Phase Checkpoint Protocol section (lines ~397-427) for reference
- [ ] Insert Phase Checkpoint Protocol section between Stage 1 and Stage A1 per research spec
- [ ] Include phase-to-stage mapping table (A1-A6 mapping from research report)
- [ ] Include resume behavior documentation
- [ ] Add preamble step to Stage A1: read plan file and update current phase to [IN PROGRESS]
- [ ] Modify Stage A7 (Write Final Metadata): note that per-phase commits replace the single final commit
- [ ] Add 3 MUST DO items to Critical Requirements:
  - "Follow Phase Checkpoint Protocol for all assembly operations"
  - "Update plan phase headings before and after each phase"
  - "Create per-phase git commits with session ID"

**Timing**: 30 minutes

**Depends on**: 1

**Files to modify**:
- `.claude/extensions/present/agents/pptx-assembly-agent.md` - CREATE (copy from zed + augment)

**Verification**:
- File contains `## Phase Checkpoint Protocol` section
- Phase-to-stage mapping table present with A1-A6 entries
- Resume behavior paragraph present
- Critical Requirements MUST DO list includes 3 checkpoint items
- Per-phase commit message format matches git conventions (`task {N} phase {P}: {phase_name}`)
- No `Co-Authored-By` trailer in commit template (per user preference)

---

### Phase 3: Copy and augment slidev-assembly-agent.md [COMPLETED]

**Goal**: Create the Slidev assembly agent with Phase Checkpoint Protocol.

**Tasks**:
- [ ] Copy `/home/benjamin/.config/zed/.claude_NEW/agents/slidev-assembly-agent.md` to `/home/benjamin/.config/nvim/.claude/extensions/present/agents/slidev-assembly-agent.md`
- [ ] Insert Phase Checkpoint Protocol section between Stage 1 and Stage S1 per research spec
- [ ] Include phase-to-stage mapping table (S1-S7 mapping from research report)
- [ ] Include resume behavior documentation
- [ ] Add preamble step to Stage S1: read plan file and update current phase to [IN PROGRESS]
- [ ] Modify Stage S8 (Write Final Metadata): note that per-phase commits replace the single final commit
- [ ] Add 3 MUST DO items to Critical Requirements (same as Phase 2)

**Timing**: 30 minutes

**Depends on**: 1

**Files to modify**:
- `.claude/extensions/present/agents/slidev-assembly-agent.md` - CREATE (copy from zed + augment)

**Verification**:
- File contains `## Phase Checkpoint Protocol` section
- Phase-to-stage mapping table present with S1-S7 entries
- Resume behavior paragraph present
- Critical Requirements MUST DO list includes 3 checkpoint items
- Per-phase commit message format matches git conventions
- No `Co-Authored-By` trailer in commit template

---

### Phase 4: Delete old slides-agent.md and verify all agents [NOT STARTED]

**Goal**: Remove the old monolithic agent and verify the complete set of new agents.

**Tasks**:
- [ ] Delete `/home/benjamin/.config/nvim/.claude/extensions/present/agents/slides-agent.md`
- [ ] Verify all 3 new agent files exist in `.claude/extensions/present/agents/`
- [ ] Verify no remaining references to `slides-agent` (as agent name, not as a substring of other names) in the 3 new files
- [ ] Verify grant-agent.md still exists and is unchanged (reference file, should not be modified)
- [ ] List all agent files in `extensions/present/agents/` to confirm expected set

**Timing**: 15 minutes

**Depends on**: 2, 3

**Files to modify**:
- `.claude/extensions/present/agents/slides-agent.md` - DELETE

**Verification**:
- `slides-agent.md` no longer exists
- `slides-research-agent.md` exists with correct frontmatter
- `pptx-assembly-agent.md` exists with Phase Checkpoint Protocol
- `slidev-assembly-agent.md` exists with Phase Checkpoint Protocol
- `grant-agent.md` unchanged
- No orphan references to deleted slides-agent

## Testing & Validation

- [ ] All 3 new agent files are valid markdown with correct frontmatter
- [ ] Both assembly agents contain Phase Checkpoint Protocol section
- [ ] Phase-to-stage mapping tables are present and correctly formatted
- [ ] Old slides-agent.md is deleted
- [ ] No broken cross-references between agents
- [ ] Commit message templates in Phase Checkpoint Protocol omit Co-Authored-By trailer

## Artifacts & Outputs

- `plans/01_agent-split-plan.md` (this file)
- `.claude/extensions/present/agents/slides-research-agent.md` (new)
- `.claude/extensions/present/agents/pptx-assembly-agent.md` (new)
- `.claude/extensions/present/agents/slidev-assembly-agent.md` (new)
- `.claude/extensions/present/agents/slides-agent.md` (deleted)

## Rollback/Contingency

If implementation fails, the old `slides-agent.md` can be restored from git history (`git checkout HEAD -- .claude/extensions/present/agents/slides-agent.md`). The 3 new agent files are purely additive until the delete step, so partial progress is safe. Downstream tasks (405, 407) will not proceed until this task is marked complete.
