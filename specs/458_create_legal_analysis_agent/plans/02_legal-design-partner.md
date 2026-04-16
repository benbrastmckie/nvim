# Implementation Plan: Legal Analysis Agent (Design Partner)

- **Task**: 458 - Create legal-analysis-agent
- **Status**: [NOT STARTED]
- **Effort**: 3 hours
- **Dependencies**: None
- **Research Inputs**: specs/458_create_legal_analysis_agent/reports/02_legal-design-partner.md, specs/458_create_legal_analysis_agent/reports/01_team-research.md
- **Artifacts**: plans/02_legal-design-partner.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Create a legal-analysis-agent that serves as a collaborative design partner embodying attorney thinking, along with its command (`/consult`), skill wrapper, context file, and manifest registration. The agent uses a translation model (understand intent, translate to attorney perspective, reframe, probe, validate) rather than adversarial critique, helping users describe legal AI products in language attorneys recognize. Done when all five artifacts exist, the agent is registered in manifest.json, and the `/consult --legal` command routes correctly to the agent.

### Research Integration

Two rounds of research inform this plan:

- **Round 1** (team, 4 teammates): Established five legal fundamentals (arguments constructed not found, discovery as term of art, duty of candor, case evaluation timing, merit as ongoing judgment), five error categories, and the critic-vs-design-partner framing tension.
- **Round 2** (single agent): Resolved the framing: the agent is a collaborative design partner, not an adversarial critic. Defined the translation model (understand intent -> attorney perspective -> reframe -> probe -> validate), five translation gap categories, and recommended `/consult --legal` over `/critic --attorney`.

Key findings integrated: five attorney reasoning patterns (IRAC, evidence evaluation, discretionary judgment, task-is-not-the-job, argument construction), legal design thinking principles (human-centered, iterative), and the specific translation gap table for legal-ai-example.typ.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

This task does not directly advance any current ROADMAP.md items. It extends the founder extension with a new agent capability (legal design consultation). The "Agent frontmatter validation" roadmap item is tangentially relevant -- the new agent should use correct frontmatter.

## Goals & Non-Goals

**Goals**:
- Create `legal-analysis-agent.md` with design-partner posture and translation workflow
- Create `/consult` command with `--legal` flag routing to the agent
- Create `skill-consult` skill wrapper for delegation
- Create `legal-reasoning-patterns.md` context file with attorney reasoning knowledge
- Register all new artifacts in `manifest.json`

**Non-Goals**:
- Building multi-flag framework (`--investor`, `--technical`, `--competitor`) beyond architecture support
- Running the agent against legal-ai-example.typ (that is a separate usage, not part of creation)
- Modifying legal-council-agent.md or any existing agents
- Creating task pipeline integration (the agent operates in standalone immediate-mode)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Agent becomes generic rewriting tool without legal depth | H | M | Ground in specific reasoning frameworks (IRAC, evidence evaluation, burden of proof); require attorney-perspective explanations, not just rewording |
| Command naming disagreement delays work | L | M | Implement as `/consult --legal` per research recommendation; name is trivially changeable post-creation |
| Overlap confusion with legal-council-agent | M | L | Explicit scope statement in agent and command: outgoing materials (design partner) vs. incoming contracts (council) |
| Context file becomes stale as legal AI landscape evolves | M | M | Structure as principles (how attorneys reason) not facts (current regulations); flag time-sensitive claims for verification |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3 | 1 |
| 3 | 4 | 2, 3 |

Phases within the same wave can execute in parallel.

### Phase 1: Create legal-reasoning-patterns.md context file [NOT STARTED]

**Goal**: Establish the domain knowledge foundation that the agent references.

**Tasks**:
- [ ] Create `.claude/extensions/founder/context/project/founder/domain/legal-reasoning-patterns.md`
- [ ] Document five attorney reasoning patterns from research (IRAC, evidence evaluation, discretionary judgment, task-is-not-the-job, argument construction)
- [ ] Document five translation gap categories (terminology, process/timeline, ethical accuracy, reasoning framework, role confusion) with detection heuristics
- [ ] Include common legal AI product misrepresentation patterns (claiming to replace judgment, task decomposition without professional context, verification language mismatch, overstating completeness, speed as primary value)
- [ ] Include vocabulary mapping table (technical term -> attorney interpretation -> suggested reframing)

**Timing**: 45 minutes

**Depends on**: none

**Files to modify**:
- `.claude/extensions/founder/context/project/founder/domain/legal-reasoning-patterns.md` - New file

**Verification**:
- File exists and contains all five reasoning patterns
- File contains all five translation gap categories with examples
- File contains vocabulary mapping table

---

### Phase 2: Create legal-analysis-agent.md [NOT STARTED]

**Goal**: Define the agent with design-partner posture and translation workflow.

**Tasks**:
- [ ] Create `.claude/extensions/founder/agents/legal-analysis-agent.md` following agent pattern from analyze-agent.md
- [ ] Add frontmatter: `name: legal-analysis-agent`, `description: Legal design partner for product descriptions and marketing materials`, `model: opus` (per research recommendation for reasoning depth)
- [ ] Define Overview section: collaborative design partner, NOT adversarial critic; reviews outgoing materials (explicit boundary with legal-council-agent)
- [ ] Define Agent Metadata: purpose, invoked by skill-consult, return format
- [ ] Define Allowed Tools: AskUserQuestion (for Socratic dialogue), Read, Write, Glob, WebSearch, Bash
- [ ] Define Context References: always-load `legal-reasoning-patterns.md` and `legal-frameworks.md`; load-for-output `return-metadata-file.md`
- [ ] Define Execution Flow with stages:
  - Stage 0: Initialize early metadata
  - Stage 1: Parse delegation context (extract file path, inline text, or design question)
  - Stage 2: Understand intent (ask what user is trying to convey to attorneys)
  - Stage 3: Read and translate (read document, translate each section to attorney perspective, identify divergence points)
  - Stage 4: Reframe and probe (offer alternative language, ask Socratic follow-up questions about product capabilities)
  - Stage 5: Validate consistency (check reframed language is internally consistent)
  - Stage 6: Generate consultation report
  - Stage 7: Write metadata and return summary
- [ ] Include advisory disclaimer: models how attorneys think but does not replace attorney review
- [ ] Include confidence levels and verification suggestions in output format
- [ ] Define push-back patterns for vague product claims
- [ ] Define error handling (user abandons dialogue, no document provided, etc.)

**Timing**: 1 hour

**Depends on**: 1

**Files to modify**:
- `.claude/extensions/founder/agents/legal-analysis-agent.md` - New file

**Verification**:
- Agent file follows pattern established by analyze-agent.md and legal-council-agent.md
- Frontmatter is valid (name, description, model fields only per agent-frontmatter-standard)
- All execution stages are defined
- Translation workflow (understand -> translate -> reframe -> probe -> validate) is clearly encoded
- Boundary with legal-council-agent is explicitly stated
- Advisory disclaimer is present

---

### Phase 3: Create /consult command and skill-consult wrapper [NOT STARTED]

**Goal**: Create the command file and skill wrapper that route to the agent.

**Tasks**:
- [ ] Create `.claude/extensions/founder/commands/consult.md` following command pattern from legal.md
  - Define syntax: `/consult --legal [file_path|"text"|task_number]`
  - Define input types: file path (read as document), quoted text (inline product description), task number (load from existing task), bare text (design question)
  - Define `--legal` flag as domain selector routing to legal-analysis-agent
  - Document future extensibility: `--investor`, `--technical` flags route to future agents
  - Define standalone immediate-mode operation (no task pipeline requirement)
  - Define frontmatter: description, allowed-tools, argument-hint
- [ ] Create `.claude/extensions/founder/skills/skill-consult/SKILL.md` as thin delegation wrapper
  - Route `--legal` flag to legal-analysis-agent via Task tool
  - Pass delegation context (file path, mode, session_id)
  - Handle return metadata from agent

**Timing**: 45 minutes

**Depends on**: 1

**Files to modify**:
- `.claude/extensions/founder/commands/consult.md` - New file
- `.claude/extensions/founder/skills/skill-consult/SKILL.md` - New file

**Verification**:
- Command file defines syntax, input types, and flag routing
- Skill wrapper delegates to legal-analysis-agent
- Command frontmatter includes allowed-tools and argument-hint
- Future flag extensibility is documented but not implemented

---

### Phase 4: Register in manifest.json and verify integration [NOT STARTED]

**Goal**: Register all new artifacts in the founder extension manifest and verify end-to-end wiring.

**Tasks**:
- [ ] Update `.claude/extensions/founder/manifest.json`:
  - Add `legal-analysis-agent.md` to `provides.agents` array
  - Add `skill-consult` to `provides.skills` array
  - Add `consult.md` to `provides.commands` array
  - Add routing entries for `founder:consult` in research, plan, and implement routing tables (pointing to skill-consult for research, skill-founder-plan for plan, skill-founder-implement for implement)
- [ ] Verify all new files exist at expected paths
- [ ] Verify manifest.json is valid JSON after edits
- [ ] Verify no duplicate entries in manifest arrays

**Timing**: 30 minutes

**Depends on**: 2, 3

**Files to modify**:
- `.claude/extensions/founder/manifest.json` - Update agents, skills, commands, routing

**Verification**:
- `jq . manifest.json` succeeds (valid JSON)
- All new artifacts listed in provides arrays
- Routing entries present for `founder:consult`
- No duplicate entries in any array

## Testing & Validation

- [ ] All four new files exist at expected paths
- [ ] manifest.json is valid JSON with new entries
- [ ] Agent frontmatter uses correct minimal format (name, description, model only)
- [ ] Agent execution flow has all stages (0 through 7)
- [ ] Agent references legal-reasoning-patterns.md and legal-frameworks.md
- [ ] Command defines `--legal` flag routing
- [ ] Skill wrapper delegates to legal-analysis-agent
- [ ] No modifications to existing legal-council-agent.md
- [ ] Boundary statement (outgoing vs incoming) present in agent Overview

## Artifacts & Outputs

- `.claude/extensions/founder/context/project/founder/domain/legal-reasoning-patterns.md` - Attorney reasoning patterns and translation gap categories
- `.claude/extensions/founder/agents/legal-analysis-agent.md` - Design partner agent definition
- `.claude/extensions/founder/commands/consult.md` - Command definition with flag routing
- `.claude/extensions/founder/skills/skill-consult/SKILL.md` - Thin skill delegation wrapper
- `.claude/extensions/founder/manifest.json` - Updated with new registrations

## Rollback/Contingency

All changes are additive (new files plus manifest additions). Rollback: delete the four new files and revert manifest.json to pre-task state. No existing files are modified except manifest.json, which only receives new array entries and routing keys.
