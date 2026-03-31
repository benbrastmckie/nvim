# Implementation Plan: Task #330

**Task**: Create /finance command, skill, and agent
**Date**: 2026-03-31
**Research**: specs/330_create_finance_command_skill_agent/reports/01_finance-command-research.md
**Estimated Effort**: 2-3 hours
**Phase Count**: 3

## Overview

Create the /finance command, skill-finance skill, and finance-agent for the founder extension. All three files follow the established founder extension patterns exactly, adapted for financial analysis with AUDIT/MODEL/FORECAST/VALIDATE modes.

## Phase 1: Create Core Files [COMPLETED]

**Estimated**: 60-90 minutes
**Files to create**: 3

### 1.1: Create finance.md command

**File**: `.claude/extensions/founder/commands/finance.md`
**Template source**: `legal.md` (most recent, cleanest pattern)

**Adaptations from legal.md**:
- Frontmatter: `description: Financial analysis and verification with task integration`
- Modes: AUDIT, MODEL, FORECAST, VALIDATE (instead of REVIEW, NEGOTIATE, TERMS, DILIGENCE)
- 5 forcing questions (instead of 4):
  1. Financial Document/Data - What financial data to analyze
  2. Primary Objective - What question needs answering
  3. Time Horizon - Period under analysis
  4. Key Assumptions - Critical assumptions (growth rate, churn, pricing)
  5. Decision Context - What decision this informs
- Input type detection: Add `.xlsx`, `.csv`, `.json` to file path patterns
- Task slug: `financial_analysis_` prefix
- task_type: `"finance"`
- Delegate to: `skill-finance`
- Artifact output: `strategy/financial-analysis-*.md` for implement phase

**Structure** (must match legal.md exactly):
- Frontmatter with allowed-tools
- Overview
- Syntax (4 examples)
- Input Types table
- Modes table
- STAGE 0: Pre-task forcing questions (Step 0.1 mode selection, Step 0.2 questions, Step 0.3 store)
- CHECKPOINT 1: GATE IN (Steps 1-7)
- STAGE 2: DELEGATE (2A legacy, 2B task workflow)
- CHECKPOINT 2: GATE OUT (verify, display)
- Error Handling
- Output Artifacts
- Workflow Summary
- Examples

### 1.2: Create SKILL.md for skill-finance

**File**: `.claude/extensions/founder/skills/skill-finance/SKILL.md`
**Template source**: `skill-legal/SKILL.md`

**Adaptations from skill-legal**:
- Frontmatter: `name: skill-finance`, `description: Financial analysis and verification for founders`
- Context pointers: Reference future finance context files (task 331)
- Trigger conditions: `/finance` command, `/research` on founder task with `task_type: "finance"`
- Trigger patterns: "Financial analysis", "Verify financials", "Revenue model", "Cash flow"
- When NOT to trigger: List other founder skills
- Input validation: mode values AUDIT/MODEL/FORECAST/VALIDATE
- Delegation context: task_type "finance", finance-specific forcing_data fields
- Invoke: finance-agent (via Task tool)
- Return summary: Financial analysis specifics

**Structure** (must match skill-legal exactly, 11 stages):
1. Input Validation
2. Preflight Status Update
3. Create Postflight Marker
4. Prepare Delegation Context
5. Invoke Agent (Task tool -> finance-agent)
6. Parse Subagent Return
7. Update Task Status (postflight)
8. Link Artifacts
9. Git Commit
10. Cleanup
11. Return Brief Summary

### 1.3: Create finance-agent.md

**File**: `.claude/extensions/founder/agents/finance-agent.md`
**Template sources**: `legal-council-agent.md` (structure) + `spreadsheet-agent.md` (XLSX generation)

**Agent design**:
- Name: finance-agent
- Purpose: Financial analysis research with document verification and XLSX output
- Invoked by: skill-finance (via Task tool)
- Return format: JSON metadata file + brief text summary

**Allowed tools**:
- AskUserQuestion (forcing questions)
- Read (financial documents, existing data)
- Write (research report, JSON metrics)
- Glob (find relevant files)
- WebSearch (market benchmarks, industry data)
- Bash (Python/openpyxl for XLSX, file verification)

**Context references** (to be created in task 331):
- `@.claude/extensions/founder/context/project/founder/domain/financial-frameworks.md`
- `@.claude/extensions/founder/context/project/founder/patterns/financial-verification.md`
- `@.claude/extensions/founder/context/project/founder/templates/financial-analysis.md`
- `@.claude/context/formats/return-metadata-file.md`

**Execution flow**:
- Stage 0: Initialize Early Metadata
- Stage 1: Parse Delegation Context
- Stage 2: Mode Selection (AUDIT/MODEL/FORECAST/VALIDATE)
- Stage 3: Forcing Questions - Document & Objective (Q1-Q2)
- Stage 4: Forcing Questions - Scope & Assumptions (Q3-Q4)
- Stage 5: Forcing Questions - Decision Context & Numbers (Q5 + follow-ups)
- Stage 6: Analyze Financial Data (read documents if provided, extract numbers)
- Stage 7: Generate Verification XLSX (openpyxl with formulas, cross-checks)
- Stage 8: Export JSON Metrics
- Stage 9: Generate Research Report
- Stage 10: Write Metadata File
- Stage 11: Return Brief Text Summary

**XLSX structure** (verification spreadsheet):
- Sheet 1 "Source Data": Input numbers from financial documents (blue cells)
- Sheet 2 "Verification": Cross-check formulas, variance analysis
- Sheet 3 "Model": Revenue/cost model with scenarios (if MODEL/FORECAST mode)
- Color conventions: Same as spreadsheet-agent (blue inputs, black formulas, dark header)

**Push-back patterns**: Financial-specific vagueness detection

**Verification outputs**:
- `specs/{NNN}_{SLUG}/financial-verification.xlsx` - XLSX with formulas
- `specs/{NNN}_{SLUG}/financial-metrics.json` - JSON metrics export
- `specs/{NNN}_{SLUG}/reports/01_{short-slug}.md` - Research report

## Phase 2: Update Integration Files [COMPLETED]

**Estimated**: 20-30 minutes
**Files to modify**: 3

### 2.1: Update manifest.json

Add to `provides.agents`: `"finance-agent.md"`
Add to `provides.skills`: `"skill-finance"`
Add to `provides.commands`: `"finance.md"`
Add routing entry: `"founder:finance": "skill-finance"` in routing.research
Add routing entries: `"founder:finance": "skill-founder-plan"` in routing.plan
Add routing entries: `"founder:finance": "skill-founder-implement"` in routing.implement

### 2.2: Update EXTENSION.md

Add to Skill-Agent Mapping table:
```
| skill-finance | finance-agent | Financial analysis research (uses forcing_data) |
```

Add to Commands table:
```
| `/finance` | `/finance "Q1 revenue verification"` | Financial analysis with forcing questions |
```

### 2.3: Update index-entries.json

Add entries for finance-agent to load:
- `business-frameworks.md` (existing, add finance-agent to agents list)
- `spreadsheet-frameworks.md` (existing, add finance-agent to agents list)
- `forcing-questions.md` (existing, add finance-agent to agents list)
- Future context files will be added in task 331

## Phase 3: Verify and Test [COMPLETED]

**Estimated**: 15-20 minutes

### 3.1: Structural Verification

- Verify all 3 new files exist at correct paths
- Verify manifest.json is valid JSON
- Verify index-entries.json is valid JSON
- Verify command frontmatter has correct allowed-tools
- Verify skill frontmatter has correct fields
- Verify agent frontmatter has correct fields

### 3.2: Pattern Consistency Check

- Compare finance.md structure against legal.md (section by section)
- Compare skill-finance/SKILL.md structure against skill-legal/SKILL.md
- Compare finance-agent.md structure against legal-council-agent.md and spreadsheet-agent.md
- Verify all cross-references are correct (skill -> agent name, command -> skill name)

## Risks and Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| Context files don't exist yet (task 331) | Agent references will be forward-looking | Use @-references that will resolve after task 331 |
| XLSX generation dependency on openpyxl | Agent may fail without openpyxl | Include error handling for missing dependency (same pattern as spreadsheet-agent) |
| Financial document parsing complexity | Agent scope may expand | Keep research phase focused on forcing questions; actual document parsing is implementation phase |

## Dependencies

- Task 331 (Create finance context and templates) - Creates the domain context files referenced by the agent. Not blocking for file creation, but agent will have limited context until task 331 completes.
- Task 332 (Integrate finance into founder extension) - Depends on this task completing first.

## Success Criteria

1. Three new files created at correct paths
2. All files follow founder extension patterns exactly
3. manifest.json updated with finance entries
4. EXTENSION.md updated with finance rows
5. index-entries.json updated with finance-agent context loading
6. All JSON files remain valid after edits
