# Implementation Plan: Add --critic Flag to /slides Command

- **Task**: 426 - update_slides_command_manifest_critic_flag
- **Status**: [COMPLETED]
- **Effort**: 2 hours
- **Dependencies**: None (skill-slide-critic, slide-critic-agent, critique-rubric.md already exist)
- **Research Inputs**: specs/426_update_slides_command_manifest_critic_flag/reports/01_slides-critic-flag-research.md
- **Artifacts**: plans/01_slides-critic-flag-plan.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Wire the existing slide critique subsystem (skill-slide-critic, slide-critic-agent, critique-rubric.md) into the `/slides` command surface. The changes span five files: the slides.md command definition (flag parsing, new input type, new stage), manifest.json (critique routing), index-entries.json (agent context entries), EXTENSION.md (documentation), and a minor delegation path fix in slide-critic-agent.md.

### Research Integration

Research report (01_slides-critic-flag-research.md) identified all five files requiring changes, provided flag parsing pseudocode modeled on the `/grant` command's `--draft`/`--budget`/`--revise` pattern, and flagged a delegation path inconsistency between skill-slide-critic SKILL.md and slide-critic-agent.md.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md consulted.

## Goals & Non-Goals

**Goals**:
- Add `--critic` flag parsing to `/slides` command with three input forms: path, task number, and prompt
- Add `critique` routing section in manifest.json mapping `present:slides` to `skill-slide-critic`
- Add `slide-critic-agent` to relevant talk context entries in index-entries.json
- Document the new flag in EXTENSION.md
- Fix delegation path inconsistency in slide-critic-agent.md

**Non-Goals**:
- Modifying skill-slide-critic SKILL.md itself (already complete)
- Creating a separate `/critique` command
- Implementing the standalone `--critic /path/to/file` form without a task number (requires temporary task context design, out of scope)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Flag parsing order breaks existing input detection | H | L | Place `--critic` check first, before task_number/file_path detection, matching grant.md pattern |
| Delegation path mismatch causes confusing error traces | L | M | Normalize to consistent path in agent file |
| Missing `Task` tool in allowed-tools blocks critique delegation | H | L | Explicitly add `Task` to slides.md frontmatter |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3, 4 | 1 |

Phases within the same wave can execute in parallel.

### Phase 1: Update slides.md Command [COMPLETED]

**Goal**: Add `--critic` flag parsing, new input type, new delegation stage, and updated frontmatter to the `/slides` command definition.

**Tasks**:
- [ ] Add `Task` to the `allowed-tools` line in frontmatter (line 3)
- [ ] Update `argument-hint` to include `--critic` variants (line 4)
- [ ] Add `--critic` syntax entries to the Syntax section (after line 20)
- [ ] Add critic input rows to the Input Types table (after line 31)
- [ ] Insert `--critic` flag detection block before existing input detection in Step 2 (before line 142), following grant.md flag-first pattern
- [ ] Add new handling branch in Step 3 for `input_type="critic"`: validate task, build delegation context, invoke `Skill("skill-slide-critic", ...)`
- [ ] Add critique row to Core Command Integration table (after line 341)

**Timing**: 1 hour

**Depends on**: none

**Files to modify**:
- `.claude/extensions/present/commands/slides.md` - Frontmatter, syntax, input types, detection logic, new stage, integration table

**Verification**:
- The `--critic` flag detection appears before task_number/file_path detection
- `Task` is in allowed-tools
- All three critic input forms (path, task number, prompt) are documented
- Delegation to skill-slide-critic is correctly specified

---

### Phase 2: Update manifest.json Routing [COMPLETED]

**Goal**: Add a `critique` routing section so the system can look up `present:slides` -> `skill-slide-critic`.

**Tasks**:
- [ ] Add `"critique"` key to the `routing` object with entry `"present:slides": "skill-slide-critic"`

**Timing**: 10 minutes

**Depends on**: 1

**Files to modify**:
- `.claude/extensions/present/manifest.json` - Add critique routing section after implement section (after line 41)

**Verification**:
- `jq '.routing.critique["present:slides"]' manifest.json` returns `"skill-slide-critic"`
- JSON is valid after edit

---

### Phase 3: Update index-entries.json [COMPLETED]

**Goal**: Add `slide-critic-agent` to the agent arrays of talk context entries so the critic agent receives proper context.

**Tasks**:
- [ ] Add `"slide-critic-agent"` to the `load_when.agents` array of `project/present/domain/presentation-types.md` entry (line 349)
- [ ] Add `"slide-critic-agent"` to the `load_when.agents` array of `project/present/patterns/talk-structure.md` entry (line 363)
- [ ] Add `"slide-critic-agent"` to the `load_when.agents` array of `project/present/talk/index.json` entry (line 403)
- [ ] Verify the existing `critique-rubric.md` entry already has `slide-critic-agent` and `/slides` (no change needed)

**Timing**: 15 minutes

**Depends on**: 1

**Files to modify**:
- `.claude/extensions/present/index-entries.json` - Add agent to three existing entries

**Verification**:
- `jq '.entries[] | select(.path == "project/present/domain/presentation-types.md") | .load_when.agents' index-entries.json` includes `slide-critic-agent`
- Same check for talk-structure.md and talk/index.json entries
- JSON is valid after edit

---

### Phase 4: Update EXTENSION.md and Fix Agent Delegation Path [COMPLETED]

**Goal**: Document the new `--critic` flag in EXTENSION.md and fix the delegation path in slide-critic-agent.md.

**Tasks**:
- [ ] Add `skill-slide-critic | slide-critic-agent | opus | Interactive slide critique with rubric evaluation` row to Skill-Agent Mapping table
- [ ] Add `slide-planner-agent` row to Skill-Agent Mapping table if missing: `skill-slide-planning | slide-planner-agent | opus | Slide plan with design questions`
- [ ] Add `/slides N --critic [path|prompt]` row to Commands table with description "Critique slide materials with interactive feedback loop"
- [ ] Fix delegation path in slide-critic-agent.md to use consistent `["orchestrator", "slides", "skill-slide-critic", "slide-critic-agent"]`

**Timing**: 20 minutes

**Depends on**: 1

**Files to modify**:
- `.claude/extensions/present/EXTENSION.md` - Skill-Agent Mapping table, Commands table
- `.claude/extensions/present/agents/slide-critic-agent.md` - Delegation path example

**Verification**:
- EXTENSION.md Skill-Agent Mapping table includes skill-slide-critic row
- EXTENSION.md Commands table includes `/slides N --critic` variant
- slide-critic-agent.md delegation path is consistent with skill-slide-critic entry point

## Testing & Validation

- [ ] Verify `manifest.json` is valid JSON after edits
- [ ] Verify `index-entries.json` is valid JSON after edits
- [ ] Verify slides.md `--critic` detection block appears before existing task_number detection
- [ ] Verify `Task` tool is in slides.md allowed-tools
- [ ] Verify all three critic input forms are documented in slides.md syntax and input types sections
- [ ] Verify EXTENSION.md tables have no formatting issues (pipe alignment)

## Artifacts & Outputs

- `.claude/extensions/present/commands/slides.md` - Updated command with --critic support
- `.claude/extensions/present/manifest.json` - Critique routing added
- `.claude/extensions/present/index-entries.json` - slide-critic-agent added to talk context entries
- `.claude/extensions/present/EXTENSION.md` - Documentation updated
- `.claude/extensions/present/agents/slide-critic-agent.md` - Delegation path fixed

## Rollback/Contingency

All changes are to markdown and JSON configuration files within the present extension. Revert with `git checkout -- .claude/extensions/present/` if any changes cause issues. No runtime code is modified.
