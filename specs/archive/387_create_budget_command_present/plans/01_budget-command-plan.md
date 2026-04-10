# Implementation Plan: Create /budget Command for Present Extension

- **Task**: 387 - Create /budget command for present extension
- **Status**: [COMPLETED]
- **Effort**: 4 hours
- **Dependencies**: None (task 391 depends on this for manifest integration)
- **Research Inputs**: specs/387_create_budget_command_present/reports/01_budget-command-research.md
- **Artifacts**: plans/01_budget-command-plan.md (this file)
- **Standards**:
  - .claude/rules/artifact-formats.md
  - .claude/rules/state-management.md
- **Type**: markdown

## Overview

Create a standalone `/budget` command for the present extension that generates grant budget spreadsheets (XLSX) with native Excel formulas. The command adapts the founder extension's `/sheet` command pattern (forcing questions, XLSX generation, JSON metrics export) for medical research grant budgets, supporting NIH modular/detailed, NSF, Foundation, and SBIR formats. Deliverables include 1 command file, 1 skill file, 1 agent file, and 2 context files. Task 391 will handle manifest and index integration separately.

### Research Integration

- Report: `reports/01_budget-command-research.md` (integrated in plan version 1)
- Key findings: architecture mirrors founder /sheet with grant-specific categories (personnel effort/salary/fringe, equipment, travel, participant support, other direct, indirect), multi-year layout, F&A rate calculation, NIH salary cap enforcement, and sub-award splitting

## Goals & Non-Goals

- **Goals**:
  - Create `/budget` command with pre-task forcing questions for funder type, project period, and direct cost cap
  - Create `skill-budget` thin wrapper following the skill-internal postflight pattern
  - Create `budget-agent` with grant-specific forcing questions and XLSX generation via openpyxl
  - Create `domain/grant-budget-frameworks.md` context file for cost structures and formulas
  - Create `patterns/budget-forcing-questions.md` context file for grant-adapted forcing question framework
  - Support NIH Modular, NIH Detailed, NSF, Foundation, and SBIR budget modes
  - Generate multi-year XLSX with salary cap enforcement, fringe calculation, F&A/indirect cost calculation

- **Non-Goals**:
  - Manifest and index integration (task 391)
  - Modifying existing `/grant --budget` workflow (complementary, not replaced)
  - Implementing budget narrative generation (handled by `/grant --budget`)
  - Institution-specific rate databases or automatic rate lookup
  - SuperDoc MCP integration for XLSX editing

## Risks & Mitigations

- **Risk**: Agent file complexity (578 lines in spreadsheet-agent as reference) may exceed context budget. **Mitigation**: Focus on core NIH/NSF modes first; Foundation/SBIR can be simpler variants.
- **Risk**: XLSX formula generation for multi-year budgets is intricate. **Mitigation**: Agent references openpyxl patterns from spreadsheet-agent; formulas documented in research appendix.
- **Risk**: Forcing question scope -- too many questions may frustrate users. **Mitigation**: Limit pre-task (STAGE 0) to 3 essential questions; detailed questions happen during research phase in the agent.
- **Risk**: Language routing with new "budget" language requires manifest update. **Mitigation**: Task 391 handles manifest; this task uses "budget" language in files and defers integration.

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3 | 1 |
| 3 | 4 | 2, 3 |
| 4 | 5 | 4 |

Phases within the same wave can execute in parallel.

### Phase 1: Create Context Files [COMPLETED]

- **Goal:** Establish domain knowledge and forcing question patterns that the agent will reference
- **Tasks:**
  - [ ] Create `domain/grant-budget-frameworks.md` at `.claude/extensions/present/context/project/present/domain/grant-budget-frameworks.md` (~200 lines)
    - Grant-specific cost structures: personnel (effort/salary/fringe), equipment, travel, participant support, other direct costs, indirect costs
    - F&A calculation rules: MTDC base, standard exclusions (equipment >$5K, participant support, sub-award amounts >$25K, patient care, tuition remission)
    - NIH salary cap rules (current FY2026: $221,900 Executive Level II)
    - Multi-year inflation conventions (typically 3% annual escalation for federal grants)
    - Sub-award indirect cost rules (first $25K subject to indirect)
    - Cost-sharing patterns
    - Key formulas: Personnel Cost, Fringe Benefits, MTDC, Indirect Costs, Total Project Cost
  - [ ] Create `patterns/budget-forcing-questions.md` at `.claude/extensions/present/context/project/present/patterns/budget-forcing-questions.md` (~250 lines)
    - Adapt founder `cost-forcing-questions.md` pattern for grant budgets
    - Pre-task questions: funder type, project period, direct cost cap
    - Research-phase questions: personnel details (PI/Co-PI effort, salary, fringe rate), equipment items, travel plans, participant support, other direct costs, F&A rate, sub-awards
    - Push-back patterns for unrealistic budget assumptions
    - Mode-specific question variations (NIH Modular vs Detailed vs NSF)
- **Timing:** 1 hour
- **Depends on:** none

### Phase 2: Create Budget Agent [COMPLETED]

- **Goal:** Create the budget-agent that handles forcing questions and XLSX generation
- **Tasks:**
  - [ ] Create `budget-agent.md` at `.claude/extensions/present/agents/budget-agent.md`
  - [ ] Define agent metadata: name, description, mcp-servers (empty), allowed tools (AskUserQuestion, Read, Write, Glob, Bash)
  - [ ] Define context references: grant-budget-frameworks.md, budget-forcing-questions.md, budget-patterns.md (existing), budget-justification.md (existing)
  - [ ] Implement Stage 0: Early metadata initialization
  - [ ] Implement Stage 1: Parse delegation context (task_context, mode, forcing_data, metadata_file_path)
  - [ ] Implement Stage 2: Forcing questions (one at a time via AskUserQuestion)
    - Mode confirmation (MODULAR/DETAILED/NSF/FOUNDATION/SBIR)
    - Personnel: PI name, effort%, base salary, fringe rate; repeat for Co-PIs
    - Equipment: items >$5K threshold
    - Travel: domestic/international conferences, site visits
    - Participant support: stipends, travel, subsistence
    - Other direct costs: supplies, publication, sub-awards (first $25K vs remainder)
    - Indirect: F&A rate, on/off campus distinction
  - [ ] Implement Stage 3: XLSX generation via Python/openpyxl
    - Multi-year layout (Year 1 through Year N columns)
    - Personnel section with salary cap enforcement formulas
    - Automatic fringe benefit calculation
    - Equipment section (excluded from MTDC)
    - Travel, participant support, other direct sections
    - F&A/indirect cost calculation with MTDC base
    - Modular budget rounding ($25K modules for NIH Modular)
    - Cumulative budget summary sheet
    - Blue input cells (rates, salaries) vs calculated cells
  - [ ] Implement Stage 4: JSON metrics export (`budget-metrics.json`)
  - [ ] Implement Stage 5: Write research report to `reports/` directory
  - [ ] Implement Stage 6: Write final metadata file
- **Timing:** 1.5 hours
- **Depends on:** 1

### Phase 3: Create Budget Skill [COMPLETED]

- **Goal:** Create the thin wrapper skill that delegates to budget-agent with postflight handling
- **Tasks:**
  - [ ] Create `SKILL.md` at `.claude/extensions/present/skills/skill-budget/SKILL.md`
  - [ ] Define skill frontmatter: name, description, allowed-tools (Task, Bash, Edit, Read, Write)
  - [ ] Implement Stage 1: Input validation (task exists, language is "budget")
  - [ ] Implement Stage 2: Preflight status update via `update-task-status.sh`
  - [ ] Implement Stage 3: Postflight marker creation
  - [ ] Implement Stage 3a: Artifact number calculation
  - [ ] Implement Stage 4: Delegation context preparation with forcing_data passthrough
  - [ ] Implement Stage 5: Invoke budget-agent via Task tool
  - [ ] Implement Stages 6-11: Standard postflight (parse metadata, validate artifact, update status, link artifacts, git commit, cleanup, return summary)
  - [ ] Reference existing skill-spreadsheet and skill-grant as structural templates
- **Timing:** 45 minutes
- **Depends on:** 1

### Phase 4: Create Budget Command [COMPLETED]

- **Goal:** Create the /budget slash command with pre-task forcing questions and task creation
- **Tasks:**
  - [ ] Create `budget.md` at `.claude/extensions/present/commands/budget.md`
  - [ ] Define command frontmatter: description, allowed-tools (Skill, Bash, Edit, Read, AskUserQuestion), argument-hint
  - [ ] Implement input type detection: description string, task number, file path, --quick flag
  - [ ] Implement STAGE 0: Pre-task forcing questions
    - Question 1: Funder type selection (NIH Modular, NIH Detailed, NSF, Foundation, SBIR)
    - Question 2: Project period (number of years, start date)
    - Question 3: Direct cost cap (determines NIH modular vs detailed threshold at $250K)
  - [ ] Implement task creation mode: create task with language="budget", store forcing_data in state.json
  - [ ] Implement task resume mode: load existing task, delegate to skill-budget
  - [ ] Implement --quick mode: legacy standalone mode (skip task creation)
  - [ ] Follow /sheet command structure for mode detection, task creation, and skill delegation
- **Timing:** 45 minutes
- **Depends on:** 2, 3

### Phase 5: Verification and Cross-Reference [COMPLETED]

- **Goal:** Verify all files are internally consistent and cross-reference correctly
- **Tasks:**
  - [ ] Verify command references skill-budget correctly
  - [ ] Verify skill references budget-agent correctly
  - [ ] Verify agent references all context files with correct paths
  - [ ] Verify context file paths match expected extension directory structure
  - [ ] Verify forcing question flow is consistent across command (STAGE 0) and agent (research phase)
  - [ ] Verify XLSX formula references match research report appendix formulas
  - [ ] Verify mode names are consistent: MODULAR, DETAILED, NSF, FOUNDATION, SBIR
  - [ ] Verify language is set to "budget" consistently in command, skill, and agent
  - [ ] Confirm no manifest or index changes are included (deferred to task 391)
- **Timing:** 15 minutes
- **Depends on:** 4

## Testing & Validation

- [ ] All 5 new files exist at correct paths under `.claude/extensions/present/`
- [ ] Command file has valid frontmatter with correct allowed-tools
- [ ] Skill file follows thin-wrapper postflight pattern (matches skill-grant/skill-spreadsheet structure)
- [ ] Agent file has complete forcing question flow and XLSX generation stages
- [ ] Context files contain grant-specific domain knowledge not duplicated from existing files
- [ ] No references to files that do not exist (all @-references point to real paths)
- [ ] No manifest.json or index-entries.json modifications (reserved for task 391)

## Artifacts & Outputs

- `plans/01_budget-command-plan.md` (this file)
- `.claude/extensions/present/commands/budget.md` (~180 lines)
- `.claude/extensions/present/skills/skill-budget/SKILL.md` (~300 lines)
- `.claude/extensions/present/agents/budget-agent.md` (~550 lines)
- `.claude/extensions/present/context/project/present/domain/grant-budget-frameworks.md` (~200 lines)
- `.claude/extensions/present/context/project/present/patterns/budget-forcing-questions.md` (~250 lines)
- `summaries/01_budget-command-summary.md` (generated after implementation)

## Rollback/Contingency

- All files are new additions; rollback is simply deleting the 5 new files
- No existing files are modified in this task
- If openpyxl XLSX generation proves too complex for a single agent pass, simplify to NIH Modular + NSF only and add other modes in a follow-up task
- If forcing question count is excessive, reduce to 3 pre-task + 5 research-phase questions minimum
