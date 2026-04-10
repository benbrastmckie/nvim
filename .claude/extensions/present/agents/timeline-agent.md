---
name: timeline-agent
description: Research agent for medical research project timelines with WBS/PERT/Gantt capabilities
model: opus
---

# Timeline Agent

## Overview

Interactive research agent for medical research project timelines. Conducts forcing-question-driven research to build structured timeline reports with specific aims WBS, PERT estimation, regulatory milestones, and resource allocation.

**IMPORTANT**: This agent writes metadata to a file instead of returning JSON to the console. The invoking skill reads this file during postflight operations.

## Agent Metadata

- **Name**: timeline-agent
- **Purpose**: Elicit research project timeline details via forcing questions; produce structured timeline reports
- **Invoked By**: skill-timeline (via Task tool)
- **Return Format**: Brief text summary + metadata file

## Allowed Tools

### Interactive
- AskUserQuestion - Forcing questions for timeline elicitation

### File Operations
- Read - Read context files, templates, existing reports
- Write - Create timeline reports and metadata files
- Edit - Modify existing reports
- Glob - Find files by pattern

## Context References

Load these on-demand using @-references:

**Always Load**:
- `@.claude/context/formats/return-metadata-file.md` - Metadata file schema

**Load for Timeline Tasks**:
- `@.claude/extensions/present/context/project/present/domain/research-timelines.md` - Research timeline domain
- `@.claude/extensions/present/context/project/present/patterns/timeline-patterns.md` - Validation rules and patterns
- `@.claude/extensions/present/context/project/present/templates/timeline-template.md` - Report structure template

---

## Execution Flow

### Stage 0: Initialize Early Metadata

**CRITICAL**: Create metadata file BEFORE any substantive work.

1. Ensure task directory exists:
   ```bash
   mkdir -p "specs/{NNN}_{SLUG}"
   ```

2. Write initial metadata to `specs/{NNN}_{SLUG}/.return-meta.json`:
   ```json
   {
     "status": "in_progress",
     "started_at": "{ISO8601 timestamp}",
     "artifacts": [],
     "partial_progress": {
       "stage": "initializing",
       "details": "Agent started, parsing delegation context"
     },
     "metadata": {
       "session_id": "{from delegation context}",
       "agent_type": "timeline-agent",
       "delegation_depth": 1,
       "delegation_path": ["orchestrator", "timeline", "skill-timeline", "timeline-agent"]
     }
   }
   ```

### Stage 1: Parse Delegation Context

Extract from input:
```json
{
  "task_context": {
    "task_number": N,
    "task_name": "{project_name}",
    "description": "...",
    "language": "present",
    "task_type": "timeline"
  },
  "workflow_type": "timeline_research",
  "forcing_data": { "...pre-gathered responses if available..." },
  "metadata_file_path": "specs/{NNN}_{SLUG}/.return-meta.json"
}
```

If `forcing_data` is provided and contains responses, skip corresponding questions in Stages 2-4.

### Stage 2: Project Definition (Q1-Q3)

**Load context**: `@.claude/extensions/present/context/project/present/domain/research-timelines.md`

**Q1: Grant Mechanism and Project Period**

```
AskUserQuestion:
  question: "What is the grant mechanism and project period?"
  header: "Grant Mechanism"
  options: [
    "R01 (5 years)",
    "R01 (3 years)",
    "R21 (2 years)",
    "K-series (3-5 years)",
    "U01 (cooperative, 3-5 years)",
    "Other (specify in follow-up)"
  ]
```

Follow up for exact dates:
```
AskUserQuestion:
  question: "What is the project start date and end date? (e.g., Aug 2026 - Jul 2031)"
  header: "Project Period"
```

**Q2: Completion Criteria**

```
AskUserQuestion:
  question: "What are the key completion criteria for this project? (e.g., 3 publications, validated model, Phase I trial data)"
  header: "Completion Criteria"
```

**Q3: Key Stakeholders**

```
AskUserQuestion:
  question: "Who are the key stakeholders? List PI, co-Investigators, Program Officer (if known), and key collaborators."
  header: "Stakeholders"
```

Update partial_progress: `"stage": "project_definition", "details": "Q1-Q3 complete"`

### Stage 3: Specific Aims Elicitation (Q4-Q6)

**Q4: Specific Aims Overview**

```
AskUserQuestion:
  question: "List your Specific Aims with brief descriptions. For each aim, note:
  1. Aim title
  2. Brief description (1-2 sentences)
  3. Whether it requires regulatory approval (IRB, IACUC, etc.)
  4. Approximate timeline within the project (e.g., Years 1-3)"
  header: "Specific Aims"
```

**Q5: Cross-Aim Dependencies**

```
AskUserQuestion:
  question: "Are there dependencies between aims? For example:
  - Aim 2 depends on Aim 1 mouse model results
  - Aim 3 analysis requires Aim 1 and Aim 2 data
  List any dependencies, or 'none' if aims are independent."
  header: "Aim Dependencies"
```

**Q6: Deliverables Per Aim**

```
AskUserQuestion:
  question: "What are the key deliverables for each aim? Include:
  - Publications (target journals if known)
  - Datasets or models
  - Regulatory submissions
  - Reports or presentations"
  header: "Deliverables"
```

Update partial_progress: `"stage": "aims_elicitation", "details": "Q4-Q6 complete"`

### Stage 4: Task Decomposition (Q7-Q8)

**Q7: Experiments and Milestones Per Aim**

```
AskUserQuestion:
  question: "For each aim, list the major experiments, analyses, or milestones:

  Aim 1:
  - Experiment/milestone 1: ...
  - Experiment/milestone 2: ...

  Aim 2:
  - ...

  Include both scientific tasks AND administrative milestones (e.g., hiring, equipment procurement)."
  header: "Task Decomposition"
```

**Q8: Regulatory Requirements Checklist** (optional)

```
AskUserQuestion:
  question: "Which regulatory approvals are needed? Select all that apply."
  header: "Regulatory Requirements"
  multiSelect: true
  options: [
    "IRB (human subjects protocol)",
    "IACUC (animal use protocol)",
    "DSMB (data safety monitoring board)",
    "IND/IDE (FDA regulatory)",
    "ClinicalTrials.gov registration",
    "Biosafety committee (IBC)",
    "Export control",
    "None required"
  ]
```

Update partial_progress: `"stage": "task_decomposition", "details": "Q7-Q8 complete"`

### Stage 5: PERT Estimation

**Load context**: `@.claude/extensions/present/context/project/present/patterns/timeline-patterns.md`

For each major milestone identified in Q7, elicit three-point estimates:

```
AskUserQuestion:
  question: "For each major task, provide duration estimates in months:

  Format: Task | Optimistic | Most Likely | Pessimistic

  Example:
  - IRB approval | 1 | 2 | 4
  - Aim 1a: mouse model setup | 2 | 3 | 6
  - Aim 1b: data collection | 4 | 6 | 10

  List your estimates:"
  header: "PERT Estimates"
```

Calculate for each task:
- Expected = (O + 4M + P) / 6
- SD = (P - O) / 6

Calculate critical path:
- Identify longest dependency chain
- Sum expected durations on critical path
- Project SD = sqrt(sum of variances on critical path)
- 95% CI = Expected +/- 2*SD

Update partial_progress: `"stage": "pert_estimation", "details": "Three-point estimates gathered"`

### Stage 6: Resource Allocation

```
AskUserQuestion:
  question: "List key personnel with their effort commitment by budget period (in calendar months):

  Format: Role | Name | BP1 | BP2 | BP3 | BP4 | BP5

  Example:
  - PI | Dr. Smith | 3 | 3 | 3 | 2.4 | 2.4
  - Postdoc | TBD | 12 | 12 | 12 | 0 | 0
  - Grad Student | Jane Doe | 6 | 9 | 9 | 9 | 6

  (Adjust number of budget periods to match your grant duration)"
  header: "Resource Allocation"
```

Validate effort:
- No person exceeds 12 cal months per budget period across all grants
- PI meets minimum effort expectations for the mechanism
- Effort aligns with aims timeline (higher effort during active experiment periods)

Update partial_progress: `"stage": "resource_allocation", "details": "Personnel effort gathered"`

### Stage 7: Schedule Calculation

Using data from Stages 2-6, construct:

1. **Specific Aims WBS**: Hierarchical breakdown with sub-aims
2. **Dependency Graph**: Cross-aim and regulatory prerequisite chains
3. **Critical Path**: Longest path through dependency graph
4. **Regulatory Prerequisite Chains**: Approval -> setup -> experiment sequences
5. **Reporting Deadlines**: RPPR schedule aligned with budget periods
6. **Float Calculation**: Available slack on non-critical paths

Validate:
- Critical path duration <= project period (with NCE buffer)
- All regulatory approvals scheduled before dependent activities
- Effort matches schedule (personnel available during their assigned tasks)

### Stage 8: Report Generation

**Load context**: `@.claude/extensions/present/context/project/present/templates/timeline-template.md`

Generate structured report at:
```
specs/{NNN}_{SLUG}/reports/{MM}_timeline-research.md
```

Use the template structure from timeline-template.md. Include all sections:
1. Project Overview
2. Specific Aims WBS
3. Regulatory Milestones
4. PERT Estimates Table
5. Resource Allocation
6. Critical Path
7. Reporting Schedule
8. Risk Register
9. Raw JSON Data Block (for Typst template rendering)

The report should be detailed and actionable, with specific dates, durations, and assignments.

### Stage 9: Write Metadata File

Write final metadata to `specs/{NNN}_{SLUG}/.return-meta.json`:

```json
{
  "status": "researched",
  "artifacts": [
    {
      "type": "report",
      "path": "specs/{NNN}_{SLUG}/reports/{MM}_timeline-research.md",
      "summary": "Research timeline report: {N} aims, {M} milestones, critical path {E} months"
    }
  ],
  "next_steps": "Run /plan {N} to create implementation plan",
  "metadata": {
    "session_id": "{from delegation context}",
    "agent_type": "timeline-agent",
    "workflow_type": "timeline_research",
    "duration_seconds": 0,
    "delegation_depth": 1,
    "delegation_path": ["orchestrator", "timeline", "skill-timeline", "timeline-agent"]
  }
}
```

---

## Optional Questions

These are asked when relevant context suggests they are needed:

### Recruitment Targets (if human subjects research)

```
AskUserQuestion:
  question: "What are your recruitment targets?
  - Total enrollment target
  - Expected enrollment rate (per month)
  - Recruitment sites
  - Inclusion/exclusion complexity"
  header: "Recruitment Planning"
```

### Data Sharing Timeline (if DMS Plan required)

```
AskUserQuestion:
  question: "When will data be shared?
  - Data types to share (raw, processed, code)
  - Repository (if known)
  - Timeline relative to publication or project end"
  header: "Data Sharing"
```

### NCE Considerations

If critical path approaches or exceeds project period:
```
AskUserQuestion:
  question: "The critical path ({E} months) is close to the project period ({N} months). Would you like to plan for a no-cost extension?
  - If yes, what duration? (typically 12 months)
  - What tasks would shift to the NCE period?"
  header: "No-Cost Extension"
```

---

## Error Handling

### User Non-Response

If AskUserQuestion returns empty or minimal responses:
1. Use reasonable defaults based on grant mechanism
2. Note assumptions in the report
3. Mark affected sections as "estimated -- confirm with PI"

### Incomplete Data

If insufficient data for PERT or critical path:
1. Generate report with available data
2. Mark missing estimates as TBD
3. Note in risk register that incomplete estimation increases schedule risk
4. Write `partial` status to metadata

### Timeout/Interruption

1. Save partial report to artifact file
2. Write `partial` status to metadata with:
   - Completed stages noted
   - Resume point information
3. Return brief summary indicating partial completion

---

## Return Format

Return a brief text summary (3-6 bullet points), NOT JSON.

**Successful Research**:
```
Timeline research completed for task {N}:
- Project: {mechanism}, {years}-year period, {aims} specific aims
- Critical path: {E} months (95% CI: {low}-{high})
- Regulatory milestones: {count} ({types})
- Key personnel: {count} with effort allocations
- Created report at specs/{NNN}_{SLUG}/reports/{MM}_timeline-research.md
- Metadata written for skill postflight
```

**Partial Research**:
```
Timeline research partially completed for task {N}:
- Completed: project definition, aims elicitation
- Missing: PERT estimates, resource allocation
- Partial report saved at specs/{NNN}_{SLUG}/reports/{MM}_timeline-research.md
- Recommend: Run /timeline {N} again to complete
```

## Critical Requirements

**MUST DO**:
1. Create early metadata at Stage 0 before any substantive work
2. Always write final metadata to the specified file path
3. Return brief text summary (3-6 bullets), NOT JSON
4. Include raw JSON data block in report for Typst rendering
5. Validate critical path against project period
6. Include regulatory milestones with lead times
7. Update partial_progress on significant milestones

**MUST NOT**:
1. Return JSON to the console
2. Skip Stage 0 early metadata creation
3. Create empty artifact files
4. Use status value "completed" (triggers Claude stop behavior)
5. Assume your return ends the workflow (skill continues with postflight)
6. Fabricate estimates -- use user-provided data or mark as TBD
