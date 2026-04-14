# Implementation Plan: Task #424

- **Task**: 424 - create_slide_critic_agent
- **Status**: [IMPLEMENTING]
- **Effort**: 2 hours
- **Dependencies**: Task 423 (critique-rubric.md -- completed)
- **Research Inputs**: specs/424_create_slide_critic_agent/reports/01_slide-critic-agent-research.md
- **Artifacts**: plans/01_slide-critic-agent-plan.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Create the slide-critic-agent at `.claude/extensions/present/agents/slide-critic-agent.md` following the established 8-stage execution flow pattern used by sibling agents (slides-research-agent, slide-planner-agent). The agent loads the critique rubric, accepts source materials and slide artifacts, evaluates against 6 rubric categories weighted by talk type, and produces a structured issue list as a critique report. Supporting changes include adding a critique-rubric index entry and registering the agent in the manifest.

### Research Integration

Research identified the exact structural template from two sibling agents: YAML frontmatter with `model: opus`, 8-stage execution flow, file-based metadata return, and `load_when` index entries. The critique-rubric.md (task 423) defines 6 evaluation categories, severity levels, a talk-type priority matrix, and explicit output format. The agent needs `materials_to_review` and optional `focus_categories` fields in its delegation context. An index entry for critique-rubric.md does not yet exist and must be added.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md found.

## Goals & Non-Goals

**Goals**:
- Create a fully functional slide-critic-agent.md with proper frontmatter, tools, context references, and 8-stage execution flow
- Define structured delegation context accepting source files, research reports, plans, and assembled slides
- Produce critique output matching the rubric's specified format (per-slide findings, summary, recommendations)
- Integrate talk-type priority matrix for severity weighting
- Add critique-rubric.md index entry and register agent in manifest.json

**Non-Goals**:
- Creating the invoking skill (skill-slides critique mode) -- deferred to a separate task
- Adding routing entries in manifest.json for the /slides command critique workflow
- Modifying the critique rubric itself

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Agent output format diverges from rubric spec | Medium | Low | Copy output structure directly from critique-rubric.md into agent instructions |
| Index entry conflicts with existing entries | Low | Low | Check existing index-entries.json before adding |
| Agent file too long / unwieldy | Medium | Medium | Keep instructions focused; reference rubric via @-import rather than duplicating content |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3 | 1 |

Phases within the same wave can execute in parallel.

### Phase 1: Create slide-critic-agent.md [COMPLETED]

**Goal**: Write the complete agent definition file with frontmatter, overview, tools, context references, 8-stage execution flow, output format, error handling, and metadata return pattern.

**Tasks**:
- [ ] Create `.claude/extensions/present/agents/slide-critic-agent.md`
- [ ] Write YAML frontmatter: `name: slide-critic-agent`, `description: Review presentation materials against critique rubric`, `model: opus`
- [ ] Write Overview section explaining purpose and file-based metadata return
- [ ] Write Agent Metadata section (name, purpose, invoked by, return format)
- [ ] Write Allowed Tools section: Read, Write, Edit, Glob, Grep, Bash (no web tools)
- [ ] Write Context References section with always-load (@return-metadata-file.md, @critique-rubric.md) and conditional-load (presentation-types.md, talk-structure.md, talk pattern JSONs)
- [ ] Write Input section defining delegation context schema with `materials_to_review` array and optional `focus_categories`
- [ ] Write 8-stage Execution Flow:
  - Stage 0: Initialize early metadata (write in_progress to .return-meta.json)
  - Stage 1: Parse delegation context (extract task info, materials paths, talk_type, focus_categories)
  - Stage 2: Load critique rubric and talk-type priority matrix
  - Stage 3: Load all review materials (source files, research reports, plans, slides) using Read/Glob
  - Stage 4: Evaluate each material/slide against rubric criteria, applying priority weighting
  - Stage 5: Aggregate findings, compute severity counts, rank issues by weighted severity
  - Stage 6: Write critique report artifact to specs/{NNN}_{SLUG}/reports/
  - Stage 7: Write final metadata (.return-meta.json with status "researched", artifacts, findings_count)
  - Stage 8: Return brief text summary (3-6 bullets)
- [ ] Write Output Format section matching rubric's specified structure (per-slide findings, summary, recommendations)
- [ ] Write Error Handling section (missing materials, invalid talk type, write failure, timeout)
- [ ] Write Critical Requirements (MUST DO / MUST NOT lists)

**Timing**: 1.5 hours

**Depends on**: none

**Files to modify**:
- `.claude/extensions/present/agents/slide-critic-agent.md` - Create new agent file

**Verification**:
- File exists at correct path
- Frontmatter has name, description, model fields
- All 8 stages are documented with clear instructions
- Output format matches critique-rubric.md structure
- Error handling covers all cases from research (missing materials, invalid talk type, write failure, timeout)

---

### Phase 2: Add critique-rubric index entry [COMPLETED]

**Goal**: Register critique-rubric.md in the present extension's index-entries.json so it loads automatically for the slide-critic-agent.

**Tasks**:
- [ ] Read current `.claude/extensions/present/index-entries.json`
- [ ] Add new entry for `project/present/talk/critique-rubric.md` with:
  - `domain: "project"`, `subdomain: "present"`
  - `topics: ["critique", "rubric", "evaluation", "slides", "review"]`
  - `load_when.agents: ["slide-critic-agent"]`
  - `load_when.commands: ["/slides"]`
  - `load_when.task_types: ["present"]`
  - Accurate `line_count` and `summary`
- [ ] Validate JSON syntax after edit

**Timing**: 15 minutes

**Depends on**: 1

**Files to modify**:
- `.claude/extensions/present/index-entries.json` - Add critique-rubric entry

**Verification**:
- JSON is valid (jq parse succeeds)
- Entry references correct relative path
- `load_when.agents` includes `slide-critic-agent`
- No duplicate entries

---

### Phase 3: Register agent in manifest.json [COMPLETED]

**Goal**: Add slide-critic-agent.md to the present extension's manifest so the system recognizes it.

**Tasks**:
- [ ] Read current `.claude/extensions/present/manifest.json`
- [ ] Add `"slide-critic-agent.md"` to the `provides.agents` array
- [ ] Validate JSON syntax after edit

**Timing**: 10 minutes

**Depends on**: 1

**Files to modify**:
- `.claude/extensions/present/manifest.json` - Add agent to provides.agents

**Verification**:
- JSON is valid (jq parse succeeds)
- `provides.agents` contains `"slide-critic-agent.md"`
- No duplicate entries

## Testing & Validation

- [ ] Agent file exists at `.claude/extensions/present/agents/slide-critic-agent.md`
- [ ] Frontmatter parses correctly (name, description, model fields present)
- [ ] All 8 execution stages documented with actionable instructions
- [ ] Output format matches critique-rubric.md specification
- [ ] Index entry for critique-rubric.md exists and references slide-critic-agent
- [ ] Manifest includes slide-critic-agent.md in provides.agents
- [ ] All JSON files (index-entries.json, manifest.json) parse without errors

## Artifacts & Outputs

- `.claude/extensions/present/agents/slide-critic-agent.md` - The new agent definition
- `.claude/extensions/present/index-entries.json` - Updated with critique-rubric entry
- `.claude/extensions/present/manifest.json` - Updated with agent registration

## Rollback/Contingency

All changes are additive (new file + appending to JSON arrays). Rollback is straightforward:
- Delete `.claude/extensions/present/agents/slide-critic-agent.md`
- Remove the critique-rubric entry from `index-entries.json`
- Remove `"slide-critic-agent.md"` from `manifest.json` provides.agents
- Git revert of the implementation commit restores all three files
