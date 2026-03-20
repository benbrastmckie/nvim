# Implementation Plan: Task #252

- **Task**: 252 - add_legal_to_founder_extension
- **Status**: [IMPLEMENTING]
- **Effort**: 4 hours
- **Dependencies**: None
- **Research Inputs**: specs/252_add_legal_to_founder_extension/reports/02_team-research.md
- **Artifacts**: plans/02_implementation-plan.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Add contract review and legal counsel capability to the founder extension. This implementation creates a complete command-skill-agent stack following established founder extension patterns (market-agent, skill-market, /market) with legal domain-specific content. The work integrates findings from team research including structural patterns (Teammate A) and legal domain content (Teammate B).

### Research Integration

Integrated research report `02_team-research.md` covering:
- File inventory (7 new files, 3 modified files)
- Execution flow patterns (agent 9 stages, skill 11 stages, command STAGE 0 + CHECKPOINT pattern)
- Legal domain content (IP assignment, indemnification, data rights, etc.)
- Modes: REVIEW, NEGOTIATE, TERMS, DILIGENCE
- Pre-task forcing questions for contract type, concerns, position, financial exposure

## Goals & Non-Goals

**Goals**:
- Create legal-council-agent with 4 operational modes and forcing question framework
- Create skill-legal thin wrapper with postflight handling
- Create /legal command with pre-task forcing questions (STAGE 0 pattern)
- Create 3 context files (legal-frameworks.md, contract-review.md, contract-analysis.md)
- Create Typst template for PDF report generation
- Update manifest.json and index-entries.json with routing
- Document in EXTENSION.md

**Non-Goals**:
- Creating legal-specific plan/implement agents (reuse founder-plan-agent and founder-implement-agent)
- Integrating external MCP servers (legal analysis is internal, unlike market-agent's sec-edgar)
- Providing actual legal advice (agent outputs are research/analysis for founder review)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Pattern drift from other founder agents | M | M | Copy from market-agent exactly, only change domain content |
| Incomplete index-entries.json integration | M | L | Follow existing entries structure precisely |
| Manifest routing conflicts | H | L | Use "founder:legal" key pattern matching existing routing |
| Context file too large | M | M | Keep each file under 300 lines per research recommendation |

## Implementation Phases

### Phase 1: Context Files [COMPLETED]

**Goal**: Create the three legal domain context files that the agent will reference.

**Tasks**:
- [ ] Create `context/project/founder/domain/legal-frameworks.md` (~250 lines)
  - IP assignment and work-for-hire for AI startups
  - Indemnification and liability caps patterns
  - Data rights and AI training provisions
  - Non-compete landscape (state-by-state)
  - R&W patterns for AI services
  - Termination provisions checklist
  - Contract types reference (SaaS, employment, SAFE, etc.)
- [ ] Create `context/project/founder/patterns/contract-review.md` (~230 lines)
  - Review methodology (5-step flow)
  - Red flags checklist by category (Data/IP, Liability, Business, Investment, Employment)
  - Push-back patterns for vague answers
  - Attorney escalation guide
- [ ] Create `context/project/founder/templates/contract-analysis.md` (~260 lines)
  - Research report template sections
  - Clause-by-clause analysis table
  - Risk assessment matrix
  - Negotiation position summary with BATNA/ZOPA
  - Walk-away conditions
  - Escalation recommendation

**Timing**: 1 hour

**Files to modify**:
- `.claude/extensions/founder/context/project/founder/domain/legal-frameworks.md` - create
- `.claude/extensions/founder/context/project/founder/patterns/contract-review.md` - create
- `.claude/extensions/founder/context/project/founder/templates/contract-analysis.md` - create

**Verification**:
- Files exist and contain domain-appropriate content
- Each file under 300 lines
- Structure matches existing founder context files

---

### Phase 2: Typst Template [COMPLETED]

**Goal**: Create Typst template for PDF contract analysis report generation.

**Tasks**:
- [ ] Create `context/project/founder/templates/typst/contract-analysis.typ` (~250 lines)
  - Import base strategy-template.typ styles
  - Executive summary section
  - Clause analysis table with risk level column
  - Risk matrix visualization
  - Negotiation position summary
  - Recommended modifications table
  - Action items with priority markers
  - Escalation recommendation section

**Timing**: 30 minutes

**Files to modify**:
- `.claude/extensions/founder/context/project/founder/templates/typst/contract-analysis.typ` - create

**Verification**:
- Template compiles with typst
- Uses base template patterns consistently
- Tables render correctly

---

### Phase 3: Agent Definition [COMPLETED]

**Goal**: Create legal-council-agent following market-agent pattern exactly.

**Tasks**:
- [ ] Create `agents/legal-council-agent.md` following market-agent structure:
  - Frontmatter: name, description (no MCP servers)
  - Overview section (advisory nature, research output focus)
  - Agent Metadata block
  - Allowed Tools section (AskUserQuestion, Read, Write, Glob, WebSearch, Bash)
  - Context References pointing to Phase 1 files
  - 9-stage execution flow:
    - Stage 0: Initialize early metadata
    - Stage 1: Parse delegation context
    - Stage 2: Mode selection (REVIEW, NEGOTIATE, TERMS, DILIGENCE)
    - Stages 3-5: Forcing questions (one at a time)
    - Stage 6: Generate research report
    - Stage 7: Write report to specs/{NNN}_{SLUG}/reports/
    - Stage 8: Write metadata file
    - Stage 9: Return brief text summary
  - Push-back patterns for legal domain
  - Error handling section
  - Critical requirements

**Timing**: 1 hour

**Files to modify**:
- `.claude/extensions/founder/agents/legal-council-agent.md` - create

**Verification**:
- Structure matches market-agent.md exactly
- All 9 stages documented
- Mode selection includes REVIEW/NEGOTIATE/TERMS/DILIGENCE
- Push-back patterns are legal domain specific

---

### Phase 4: Skill Definition [COMPLETED]

**Goal**: Create skill-legal thin wrapper following skill-market pattern.

**Tasks**:
- [ ] Create `skills/skill-legal/SKILL.md` following skill-market structure:
  - Frontmatter: name, description, allowed-tools
  - Context Pointers section
  - Trigger Conditions section
  - 11-stage execution flow:
    - Stage 1: Input validation
    - Stage 2: Preflight status update
    - Stage 3: Create postflight marker
    - Stage 4: Prepare delegation context (with forcing_data passthrough)
    - Stage 5: Invoke agent via Task tool
    - Stage 6: Parse .return-meta.json
    - Stage 7: Postflight status update
    - Stage 8: Link artifacts (two-step jq, "| not" pattern)
    - Stage 9: Git commit
    - Stage 10: Cleanup
    - Stage 11: Return brief summary
  - Return format section
  - Error handling section

**Timing**: 30 minutes

**Files to modify**:
- `.claude/extensions/founder/skills/skill-legal/SKILL.md` - create

**Verification**:
- Structure matches skill-market/SKILL.md
- Uses Task tool (not Skill) for agent invocation
- jq patterns use "| not" for filtering

---

### Phase 5: Command Definition [COMPLETED]

**Goal**: Create /legal command following /market pattern with pre-task forcing questions.

**Tasks**:
- [ ] Create `commands/legal.md` following market.md structure:
  - Frontmatter: description, allowed-tools, argument-hint
  - Overview section
  - Syntax examples (description, task number, file path, --quick)
  - Input Types table
  - Modes table (REVIEW, NEGOTIATE, TERMS, DILIGENCE)
  - STAGE 0: Pre-task forcing questions
    - Mode selection
    - Contract type question
    - Primary concern question
    - Position question
    - Financial exposure question
  - CHECKPOINT 1: GATE IN
    - Session ID generation
    - Input detection
    - Task creation with forcing_data and task_type: "legal"
    - Git commit
    - Display summary and STOP
  - STAGE 2: DELEGATE
    - Legacy mode (--quick)
    - Task workflow mode (invoke skill-legal)
  - CHECKPOINT 2: GATE OUT
    - Verify research completed
    - Display result
  - Error handling section
  - Output artifacts section
  - Workflow summary
  - Examples section

**Timing**: 30 minutes

**Files to modify**:
- `.claude/extensions/founder/commands/legal.md` - create

**Verification**:
- Structure matches market.md exactly
- STAGE 0 has legal-specific forcing questions
- Uses skill-legal for delegation
- Includes --quick legacy mode support

---

### Phase 6: Registration and Documentation [COMPLETED]

**Goal**: Register components in manifest.json and index-entries.json, update EXTENSION.md.

**Tasks**:
- [ ] Update `manifest.json`:
  - Add "legal-council-agent.md" to provides.agents
  - Add "skill-legal" to provides.skills
  - Add "legal.md" to provides.commands
  - Add routing.research["founder:legal"] = "skill-legal"
  - Bump version to "2.1.0"
- [ ] Update `index-entries.json`:
  - Add entry for legal-frameworks.md (agents: legal-council-agent + plan + implement, commands: /legal)
  - Add entry for contract-review.md (agents: legal-council-agent, commands: /legal)
  - Add entry for contract-analysis.md (agents: legal-council-agent + implement, commands: /legal, /implement)
  - Add entry for contract-analysis.typ (agents: founder-implement-agent, commands: /implement)
- [ ] Update `EXTENSION.md`:
  - Bump version to v2.2
  - Add /legal to Commands table
  - Add legal to Input Types table
  - Add skill-legal -> legal-council-agent to Skill-to-Agent Mapping
  - Add founder:legal routing entry to Language-Based Routing table
  - Add legal context files to Context Files table
  - Add Pre-Task Forcing Questions example for /legal

**Timing**: 30 minutes

**Files to modify**:
- `.claude/extensions/founder/manifest.json` - modify
- `.claude/extensions/founder/index-entries.json` - modify
- `.claude/extensions/founder/EXTENSION.md` - modify

**Verification**:
- jq validates manifest.json and index-entries.json
- EXTENSION.md documents /legal command
- Version bumped to 2.1.0 (manifest) and v2.2 (EXTENSION.md)
- `founder:legal` routing key registered

## Testing & Validation

- [ ] `jq empty .claude/extensions/founder/manifest.json` succeeds
- [ ] `jq empty .claude/extensions/founder/index-entries.json` succeeds
- [ ] All 7 new files exist and have content
- [ ] All 3 modified files contain expected updates
- [ ] Agent structure matches market-agent.md pattern
- [ ] Skill structure matches skill-market/SKILL.md pattern
- [ ] Command structure matches market.md pattern
- [ ] Typst template compiles: `typst compile contract-analysis.typ`

## Artifacts & Outputs

- `.claude/extensions/founder/agents/legal-council-agent.md`
- `.claude/extensions/founder/skills/skill-legal/SKILL.md`
- `.claude/extensions/founder/commands/legal.md`
- `.claude/extensions/founder/context/project/founder/domain/legal-frameworks.md`
- `.claude/extensions/founder/context/project/founder/patterns/contract-review.md`
- `.claude/extensions/founder/context/project/founder/templates/contract-analysis.md`
- `.claude/extensions/founder/context/project/founder/templates/typst/contract-analysis.typ`
- `.claude/extensions/founder/manifest.json` (modified)
- `.claude/extensions/founder/index-entries.json` (modified)
- `.claude/extensions/founder/EXTENSION.md` (modified)
- `specs/252_add_legal_to_founder_extension/summaries/03_execution-summary.md`

## Rollback/Contingency

If implementation fails:
1. Delete the 7 new files created in Phases 1-5
2. Revert manifest.json, index-entries.json, and EXTENSION.md using git checkout
3. All changes are contained within .claude/extensions/founder/ directory
4. No external dependencies or side effects
