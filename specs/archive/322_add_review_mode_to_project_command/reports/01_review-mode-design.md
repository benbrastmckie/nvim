# REVIEW Mode Design for /project Command

**Task**: #322 - Add REVIEW mode to /project command for timeline analysis
**Session**: sess_1774888923_d147e8
**Date**: 2026-03-30
**Status**: Research Complete

---

## Executive Summary

This report provides the design specification for adding a REVIEW mode to the `/project` command. The REVIEW mode enables critical analysis of project timelines to identify gaps, issues, weaknesses, and improvement opportunities.

**Key Findings**:

1. **Dual Input Pattern**: REVIEW mode must support both file paths (external timelines) and task numbers (internal artifacts), following the established input detection pattern from project.md.

2. **Analysis Framework**: A 7-category evaluation framework covers timeline gaps, feasibility issues, resource concerns, risk assessment, critical path vulnerabilities, dependency issues, and methodology compliance.

3. **Forcing Questions**: 5 review-specific forcing questions focus the analysis on user concerns, changed constraints, timeline validity, and risk tolerance.

4. **Output Structure**: Findings use a 4-tier severity system (Critical/High/Medium/Low) with actionable recommendations, following the pattern from code-reviewer-agent.md.

5. **Integration Model**: REVIEW mode operates as a standalone analysis that does not modify the timeline but produces a review artifact. It can be run after PLAN mode or on external files.

---

## 1. Input Handling Design

### 1.1 Input Type Detection

REVIEW mode accepts two primary input types, detected using the existing pattern from project.md:

```bash
# Task number input (internal artifact review)
if echo "$ARGUMENTS" | grep -qE '^[0-9]+$'; then
  input_type="task_number"
  task_number="$ARGUMENTS"

# File path input (external timeline review)
elif echo "$ARGUMENTS" | grep -qE '^\.|^/|^~|\.typ$|\.md$|\.json$'; then
  input_type="file_path"
  file_path="$ARGUMENTS"
fi
```

### 1.2 File Path Handling

**Supported Formats**:

| Format | Extension | Extraction Method |
|--------|-----------|-------------------|
| Typst Timeline | `.typ` | Parse `project-gantt()`, `pert-table()`, `resource-matrix()` calls |
| Markdown | `.md` | Parse tables, JSON code blocks, structured sections |
| JSON | `.json` | Direct parse of WBS, PERT, resource structures |
| Task Artifacts | (via task number) | Read from `specs/{NNN}_{SLUG}/reports/` |

**Typst Parsing Strategy**:

Extract data from Typst function calls in `project-timeline.typ`:
- `project-gantt(tasks: (...), milestones: (...))` - Task list and dependencies
- `pert-table(estimates: (...))` - Three-point estimates
- `resource-matrix(team: (...), allocations: (...))` - Resource assignments
- `risk-register(risks: (...))` - Risk items

**Markdown Parsing Strategy**:

Look for structured sections:
- "## Work Breakdown Structure" - Hierarchical task list
- "## PERT Estimates" - Table with O/M/P/E columns
- "## Resource Allocation" - Team member assignments
- "```json:wbs```", "```json:pert```", "```json:resources```" - Raw data blocks

### 1.3 Task Number Handling

When reviewing internal task artifacts:

```bash
# Validate task exists and is a founder task
task_data=$(jq -r --argjson num "$task_number" \
  '.active_projects[] | select(.project_number == $num)' \
  specs/state.json)

task_lang=$(echo "$task_data" | jq -r '.language')
if [ "$task_lang" == "founder" ]; then
  # Valid founder task
fi

# Locate artifacts to review
artifacts_path="specs/$(printf '%03d' $task_number)_*/reports/"
research_report=$(find $artifacts_path -name "01_*.md" 2>/dev/null | head -1)
plan_report=$(find $artifacts_path -name "*-plan.md" 2>/dev/null | head -1)
```

**Artifact Priority**:
1. Implementation plan (if exists) - Most complete timeline
2. Research report - Contains WBS/PERT/resource data
3. Both (if both exist) - Cross-reference for completeness

---

## 2. Analysis Framework

### 2.1 Seven-Category Evaluation

| Category | Focus Area | Weight |
|----------|------------|--------|
| Timeline Gaps | Missing phases, tasks, dependencies | 15% |
| Feasibility Issues | Unrealistic estimates, PERT outliers | 20% |
| Resource Concerns | Overallocations, bottlenecks, skill gaps | 15% |
| Risk Assessment | Unmitigated risks, single points of failure | 15% |
| Critical Path Vulnerabilities | Long chains, no slack, brittleness | 15% |
| Dependency Issues | Circular, missing, implicit dependencies | 10% |
| Methodology Compliance | WBS 100% rule, PERT validity, milestone types | 10% |

### 2.2 Timeline Gaps Analysis

**Detection Criteria**:

| Gap Type | Detection Rule | Severity |
|----------|----------------|----------|
| Missing phase | Common phase absent (e.g., no Testing phase) | High |
| Orphan task | Task with no dependencies and no dependents (not start/end) | Medium |
| Implicit dependency | Task B starts after A ends but no explicit FS link | Medium |
| Missing milestone | No milestone for major deliverable | Low |
| Phase without deliverable | Phase exists but no deliverable defined | High |

**Reference**: timeline-frameworks.md Section "WBS Best Practices" - deliverable-oriented decomposition.

### 2.3 Feasibility Issues Analysis

**PERT Estimate Validation**:

| Issue | Formula | Threshold | Severity |
|-------|---------|-----------|----------|
| High uncertainty | (P - O) / M | > 2.0 | High |
| Optimism bias | O / M | < 0.5 | Medium |
| Pessimism outlier | P / M | > 4.0 | Medium |
| Impossible optimistic | O < 1 day for multi-day task | 0 | High |
| Invalid PERT relationship | O > M or M > P | Any | Critical |

**Duration Feasibility**:

| Issue | Detection | Severity |
|-------|-----------|----------|
| Heroic estimate | Single task > 20 days expected | High |
| Micro-management | Task < 0.5 days expected | Low |
| Total duration implausible | Project 95% CI > 2x target date | Critical |

### 2.4 Resource Concerns Analysis

**Overallocation Detection** (from project-agent.md Stage 7):

```
For each period:
  For each team member:
    Total allocation = sum of allocations for concurrent tasks
    If Total > 100%: Flag overallocation warning
    If Total > 150%: Flag critical overallocation
```

**Resource Issues**:

| Issue | Detection | Severity |
|-------|-----------|----------|
| Overallocation > 150% | Sum of concurrent allocations | Critical |
| Overallocation 100-150% | Sum of concurrent allocations | High |
| Unassigned task | Task has no resource owner | Medium |
| Single-person dependency | One person owns all critical path tasks | High |
| Skill gap | Task requires skill not present in team | High |
| Part-time bottleneck | < 50% allocated person on critical path | Medium |

### 2.5 Risk Assessment Analysis

**Risk Evaluation Criteria** (from timeline-frameworks.md Risk Matrix):

| Risk Score | Priority | Detection |
|------------|----------|-----------|
| 15-25 | Critical | Probability x Impact in matrix |
| 8-14 | High | Probability x Impact in matrix |
| 4-7 | Medium | Probability x Impact in matrix |
| 1-3 | Low | Probability x Impact in matrix |

**Risk Issues**:

| Issue | Detection | Severity |
|-------|-----------|----------|
| No mitigation for critical risk | Risk score >= 15, no mitigation listed | Critical |
| Missing risk owner | Risk has no assigned owner | High |
| Unquantified risk | Risk has no probability/impact assessment | Medium |
| Risk not linked to task | Risk affects project but no related task | Medium |
| Insufficient contingency | No buffer for high-uncertainty tasks | High |

### 2.6 Critical Path Vulnerabilities Analysis

**Critical Path Metrics** (from timeline-frameworks.md CPM):

```
Float = Late Start - Early Start
Critical Tasks = tasks where Float = 0
Critical Path = sequence of critical tasks
```

**Vulnerability Issues**:

| Issue | Detection | Severity |
|-------|-----------|----------|
| Long critical chain | > 10 sequential critical tasks | High |
| No parallel paths | All tasks on critical path | Critical |
| Zero slack throughout | Average float < 1 day across project | High |
| Critical path resource | Single person owns > 50% of critical path | High |
| External dependency on critical path | Critical task depends on external party | High |

### 2.7 Dependency Issues Analysis

| Issue | Detection | Severity |
|-------|-----------|----------|
| Circular dependency | Topological sort fails | Critical |
| Missing dependency | Task B uses output of A but no link | High |
| Over-constraining | FF or SF dependencies where FS suffices | Low |
| Long dependency chain | > 7 sequential dependencies | Medium |
| External dependency without buffer | External dep has no lag time | High |

### 2.8 Methodology Compliance Analysis

**WBS 100% Rule Validation**:

```
For each level:
  Sum of child durations / estimates
  If sum != parent estimate: Flag violation
```

**Compliance Issues**:

| Issue | Detection | Severity |
|-------|-----------|----------|
| 100% rule violation | Child sum != parent | High |
| Activity-named task | Task name is verb not noun | Low |
| Missing three-point estimate | Only single estimate provided | Medium |
| PERT formula not used | Expected != (O + 4M + P) / 6 | Medium |
| Milestone has duration | Milestone > 0 days | Low |

---

## 3. Forcing Questions for REVIEW Mode

Following the pattern from forcing-questions.md, ask one question at a time via AskUserQuestion.

### Question 1: Primary Concern

```
What aspect of this timeline concerns you most?

Push for: Specific area of doubt or uncertainty
Reject: "Everything" or "I don't know"
Examples:
- "The development estimates seem too optimistic"
- "I'm worried about resource availability in month 2"
- "The external dependencies are unclear"
```

Store as `review_context.primary_concern`.

### Question 2: Changed Constraints

```
Have any constraints changed since this timeline was created?

Push for: Specific changes in scope, resources, deadlines, or external factors
Accept: "No changes" if genuinely unchanged
Examples:
- "Budget was cut by 20%"
- "Key developer is leaving in April"
- "Deadline moved up by 2 weeks"
```

Store as `review_context.changed_constraints`.

### Question 3: Timeline Validity Window

```
When does this timeline need to be valid until?

Push for: Specific date or milestone
Context: Short-term reviews focus on immediate issues; long-term reviews examine sustainability
Examples:
- "Through end of Q2"
- "Until product launch on June 15"
- "For investor presentation next week"
```

Store as `review_context.validity_window`.

### Question 4: Risk Tolerance

```
What is your risk tolerance for this project?

Push for: Explicit risk posture
Options:
- Conservative (prefer buffer time over speed)
- Balanced (accept normal project risk)
- Aggressive (willing to take schedule risk for speed)
```

Store as `review_context.risk_tolerance`.

### Question 5: Review Depth

```
What depth of review do you need?

Push for: Explicit scope selection
Options:
- Quick (high-level issues only, 5-10 minutes)
- Standard (all categories, 15-30 minutes)
- Deep (methodology audit + recommendations, 30-60 minutes)
```

Store as `review_context.review_depth`.

---

## 4. Output Format

### 4.1 Review Artifact Structure

Location: `specs/{NNN}_{SLUG}/reports/02_timeline-review.md` (or `strategy/reviews/timeline-review-{datetime}.md` for file path input without task)

```markdown
# Timeline Review Report

**Reviewed**: {source - file path or task number}
**Date**: {ISO date}
**Reviewer**: Claude Code (project-agent)
**Risk Tolerance**: {conservative/balanced/aggressive}
**Review Depth**: {quick/standard/deep}

---

## Executive Assessment

**Overall Health**: {Healthy / At Risk / Critical}
**Confidence Level**: {High / Medium / Low}
**Recommended Action**: {Proceed / Address Issues / Major Revision Required}

### Key Findings (Top 3)

1. {Critical or highest-severity finding with location}
2. {Second finding}
3. {Third finding}

---

## Category Analysis

### Timeline Gaps

| Issue | Location | Severity | Recommendation |
|-------|----------|----------|----------------|
| {issue} | {phase/task} | {severity} | {action} |

### Feasibility Issues

| Issue | Location | Severity | Recommendation |
|-------|----------|----------|----------------|
| {issue} | {phase/task} | {severity} | {action} |

### Resource Concerns

| Issue | Location | Severity | Recommendation |
|-------|----------|----------|----------------|
| {issue} | {person/period} | {severity} | {action} |

### Risk Assessment

| Issue | Location | Severity | Recommendation |
|-------|----------|----------|----------------|
| {issue} | {risk item} | {severity} | {action} |

### Critical Path Vulnerabilities

| Issue | Location | Severity | Recommendation |
|-------|----------|----------|----------------|
| {issue} | {path segment} | {severity} | {action} |

### Dependency Issues

| Issue | Location | Severity | Recommendation |
|-------|----------|----------|----------------|
| {issue} | {dependency} | {severity} | {action} |

### Methodology Compliance

| Issue | Location | Severity | Recommendation |
|-------|----------|----------|----------------|
| {issue} | {element} | {severity} | {action} |

---

## Summary Statistics

| Category | Critical | High | Medium | Low | Total |
|----------|----------|------|--------|-----|-------|
| Timeline Gaps | {n} | {n} | {n} | {n} | {n} |
| Feasibility Issues | {n} | {n} | {n} | {n} | {n} |
| Resource Concerns | {n} | {n} | {n} | {n} | {n} |
| Risk Assessment | {n} | {n} | {n} | {n} | {n} |
| Critical Path | {n} | {n} | {n} | {n} | {n} |
| Dependency Issues | {n} | {n} | {n} | {n} | {n} |
| Methodology | {n} | {n} | {n} | {n} | {n} |
| **Total** | **{n}** | **{n}** | **{n}** | **{n}** | **{n}** |

---

## Recommendations

### Must Address (Critical/High)

1. {Actionable recommendation with specific steps}
2. {Actionable recommendation with specific steps}

### Should Consider (Medium)

1. {Recommendation}
2. {Recommendation}

### Nice to Have (Low)

1. {Suggestion}

---

## Raw Data

```json:review_findings
{
  "source": "{file path or task number}",
  "reviewed_at": "{ISO timestamp}",
  "review_depth": "{quick|standard|deep}",
  "risk_tolerance": "{conservative|balanced|aggressive}",
  "overall_health": "{healthy|at_risk|critical}",
  "confidence_level": "{high|medium|low}",
  "findings": [
    {
      "category": "{category}",
      "issue": "{description}",
      "location": "{phase/task/resource}",
      "severity": "{critical|high|medium|low}",
      "recommendation": "{action}"
    }
  ],
  "statistics": {
    "critical": {n},
    "high": {n},
    "medium": {n},
    "low": {n},
    "total": {n}
  }
}
```
```

### 4.2 Severity Definitions

| Severity | Definition | Response Required |
|----------|------------|-------------------|
| **Critical** | Project likely to fail without immediate action | Stop, address before proceeding |
| **High** | Significant risk to project success | Address within current planning cycle |
| **Medium** | Moderate risk or inefficiency | Address when convenient |
| **Low** | Minor issue or style concern | Optional improvement |

---

## 5. Implementation Recommendations

### 5.1 Modifications to project.md

**Add REVIEW to mode table** (line ~35):

```markdown
## Modes

| Mode | Posture | Focus |
|------|---------|-------|
| **PLAN** | Create timeline | WBS structure, PERT estimates, resource allocation, critical path |
| **TRACK** | Update progress | Task completion %, milestone status, variance analysis |
| **REPORT** | Executive summary | Status dashboard, risk assessment, key decisions needed |
| **REVIEW** | Critical analysis | Gaps, feasibility, risks, vulnerabilities, recommendations |
```

**Add REVIEW to mode selection** (line ~52):

```markdown
### Step 0.1: Mode Selection

Use AskUserQuestion to present mode options:

```
What type of project management do you need?

- PLAN: Create new project timeline from scratch
- TRACK: Update existing timeline with progress
- REPORT: Generate executive status summary
- REVIEW: Critically analyze timeline for gaps and issues
```
```

**Add REVIEW input handling** (after line ~230):

```markdown
### Step 3.REVIEW: Handle REVIEW Mode Input

**If mode == REVIEW and file path**:
```bash
# Validate file exists
file_path=$(eval echo "$file_path")
if [ ! -f "$file_path" ]; then
  echo "Error: File not found: $file_path"
  exit 1
fi

# Detect format
file_ext="${file_path##*.}"
case "$file_ext" in
  typ) parse_mode="typst" ;;
  md)  parse_mode="markdown" ;;
  json) parse_mode="json" ;;
  *)   echo "Error: Unsupported format: .$file_ext"; exit 1 ;;
esac
```

**If mode == REVIEW and task number**:
```bash
# Load task and locate artifacts
task_data=$(jq -r --argjson num "$task_number" \
  '.active_projects[] | select(.project_number == $num)' \
  specs/state.json)

# Find research/plan artifacts
padded_num=$(printf '%03d' $task_number)
artifacts_base="specs/${padded_num}_*/reports/"
```
```

### 5.2 Modifications to project-agent.md

**Add REVIEW execution stages** (new section after Stage 8):

```markdown
---

## REVIEW Mode Stages

When invoked with mode=REVIEW, execute these stages instead of research stages.

### Stage R1: Parse Timeline Input

Based on input type and format:

**For Typst files**:
- Read file content
- Extract `project-gantt()` task definitions
- Extract `pert-table()` estimate data
- Extract `resource-matrix()` allocations
- Extract `risk-register()` risk items

**For Markdown files**:
- Parse structured sections (WBS, PERT, Resources)
- Extract JSON code blocks (json:wbs, json:pert, json:resources)
- Build internal data structures

**For Task artifacts**:
- Read research report from specs/{NNN}_{SLUG}/reports/
- Read plan report if exists
- Extract Raw Data JSON blocks

### Stage R2: Execute Analysis Framework

Run all 7 category analyses:

1. Timeline Gaps Analysis
2. Feasibility Issues Analysis
3. Resource Concerns Analysis
4. Risk Assessment Analysis
5. Critical Path Vulnerabilities Analysis
6. Dependency Issues Analysis
7. Methodology Compliance Analysis

Collect findings with severity classifications.

### Stage R3: Generate Review Report

Write review artifact following output format specification.

### Stage R4: Write Metadata File

```json
{
  "status": "reviewed",
  "summary": "Timeline review complete: {critical} critical, {high} high, {medium} medium, {low} low issues found.",
  "artifacts": [
    {
      "type": "review",
      "path": "specs/{NNN}_{SLUG}/reports/02_timeline-review.md",
      "summary": "Timeline review with {total} findings"
    }
  ],
  "metadata": {
    "session_id": "{session_id}",
    "review_depth": "{quick|standard|deep}",
    "overall_health": "{healthy|at_risk|critical}",
    "findings_count": {total}
  }
}
```
```

### 5.3 New Skill: skill-project-review

Create `/home/benjamin/.config/nvim/.claude/extensions/founder/skills/skill-project-review/SKILL.md`:

```markdown
---
name: skill-project-review
description: Review project timelines for gaps, issues, and improvement opportunities
invoked-by: /project REVIEW mode
agent: project-agent (review mode)
---

# skill-project-review

Skill for project timeline review and critical analysis.

## Invocation

Called by /project command when mode=REVIEW.

## Inputs

- `task_number` OR `file_path` - Source of timeline to review
- `review_context` - User-provided context from forcing questions
- `session_id` - Session identifier

## Workflow

1. Preflight: Validate input, update status if task-based
2. Delegate: Invoke project-agent with mode=REVIEW
3. Postflight: Link review artifact, update status
4. Return: Brief summary of review findings

## Return Format

```
Timeline review complete for {source}:
- Overall Health: {healthy|at_risk|critical}
- Issues Found: {critical} critical, {high} high, {medium} medium, {low} low
- Top Concern: {highest severity finding}
- Review Report: {artifact path}
```
```

---

## 6. Raw Data

```json
{
  "analysis_framework": {
    "categories": [
      {
        "name": "timeline_gaps",
        "weight": 0.15,
        "issues": [
          {"type": "missing_phase", "severity": "high"},
          {"type": "orphan_task", "severity": "medium"},
          {"type": "implicit_dependency", "severity": "medium"},
          {"type": "missing_milestone", "severity": "low"},
          {"type": "phase_without_deliverable", "severity": "high"}
        ]
      },
      {
        "name": "feasibility_issues",
        "weight": 0.20,
        "issues": [
          {"type": "high_uncertainty", "formula": "(P-O)/M > 2.0", "severity": "high"},
          {"type": "optimism_bias", "formula": "O/M < 0.5", "severity": "medium"},
          {"type": "pessimism_outlier", "formula": "P/M > 4.0", "severity": "medium"},
          {"type": "impossible_optimistic", "condition": "O < 1 day for multi-day", "severity": "high"},
          {"type": "invalid_pert_order", "condition": "O > M or M > P", "severity": "critical"},
          {"type": "heroic_estimate", "condition": "single task > 20 days", "severity": "high"},
          {"type": "micro_management", "condition": "task < 0.5 days", "severity": "low"},
          {"type": "duration_implausible", "condition": "95% CI > 2x target", "severity": "critical"}
        ]
      },
      {
        "name": "resource_concerns",
        "weight": 0.15,
        "issues": [
          {"type": "critical_overallocation", "threshold": "> 150%", "severity": "critical"},
          {"type": "overallocation", "threshold": "100-150%", "severity": "high"},
          {"type": "unassigned_task", "severity": "medium"},
          {"type": "single_person_dependency", "severity": "high"},
          {"type": "skill_gap", "severity": "high"},
          {"type": "part_time_bottleneck", "threshold": "< 50% on critical path", "severity": "medium"}
        ]
      },
      {
        "name": "risk_assessment",
        "weight": 0.15,
        "issues": [
          {"type": "no_mitigation_critical", "condition": "score >= 15, no mitigation", "severity": "critical"},
          {"type": "missing_risk_owner", "severity": "high"},
          {"type": "unquantified_risk", "severity": "medium"},
          {"type": "risk_not_linked", "severity": "medium"},
          {"type": "insufficient_contingency", "severity": "high"}
        ]
      },
      {
        "name": "critical_path_vulnerabilities",
        "weight": 0.15,
        "issues": [
          {"type": "long_critical_chain", "threshold": "> 10 sequential", "severity": "high"},
          {"type": "no_parallel_paths", "severity": "critical"},
          {"type": "zero_slack", "threshold": "avg float < 1 day", "severity": "high"},
          {"type": "critical_path_resource", "threshold": "> 50% single person", "severity": "high"},
          {"type": "external_on_critical_path", "severity": "high"}
        ]
      },
      {
        "name": "dependency_issues",
        "weight": 0.10,
        "issues": [
          {"type": "circular_dependency", "severity": "critical"},
          {"type": "missing_dependency", "severity": "high"},
          {"type": "over_constraining", "severity": "low"},
          {"type": "long_dependency_chain", "threshold": "> 7 sequential", "severity": "medium"},
          {"type": "external_without_buffer", "severity": "high"}
        ]
      },
      {
        "name": "methodology_compliance",
        "weight": 0.10,
        "issues": [
          {"type": "100_percent_rule_violation", "severity": "high"},
          {"type": "activity_named_task", "severity": "low"},
          {"type": "missing_three_point", "severity": "medium"},
          {"type": "pert_formula_not_used", "severity": "medium"},
          {"type": "milestone_has_duration", "severity": "low"}
        ]
      }
    ]
  },
  "forcing_questions": [
    {
      "id": "primary_concern",
      "question": "What aspect of this timeline concerns you most?",
      "push_back": ["Everything", "I don't know"]
    },
    {
      "id": "changed_constraints",
      "question": "Have any constraints changed since this timeline was created?",
      "accepts": ["No changes"]
    },
    {
      "id": "validity_window",
      "question": "When does this timeline need to be valid until?"
    },
    {
      "id": "risk_tolerance",
      "question": "What is your risk tolerance for this project?",
      "options": ["Conservative", "Balanced", "Aggressive"]
    },
    {
      "id": "review_depth",
      "question": "What depth of review do you need?",
      "options": ["Quick", "Standard", "Deep"]
    }
  ],
  "severity_levels": {
    "critical": {
      "definition": "Project likely to fail without immediate action",
      "response": "Stop, address before proceeding"
    },
    "high": {
      "definition": "Significant risk to project success",
      "response": "Address within current planning cycle"
    },
    "medium": {
      "definition": "Moderate risk or inefficiency",
      "response": "Address when convenient"
    },
    "low": {
      "definition": "Minor issue or style concern",
      "response": "Optional improvement"
    }
  },
  "supported_formats": [
    {
      "extension": ".typ",
      "name": "Typst Timeline",
      "parse_targets": ["project-gantt", "pert-table", "resource-matrix", "risk-register"]
    },
    {
      "extension": ".md",
      "name": "Markdown",
      "parse_targets": ["structured sections", "json code blocks"]
    },
    {
      "extension": ".json",
      "name": "JSON",
      "parse_targets": ["wbs", "pert", "resources"]
    }
  ],
  "output_artifact": {
    "task_mode": "specs/{NNN}_{SLUG}/reports/02_timeline-review.md",
    "file_mode": "strategy/reviews/timeline-review-{datetime}.md"
  }
}
```

---

## References

- `/home/benjamin/.config/nvim/.claude/extensions/founder/commands/project.md` - Current command structure
- `/home/benjamin/.config/nvim/.claude/extensions/founder/agents/project-agent.md` - Agent execution stages
- `/home/benjamin/.config/nvim/.claude/extensions/founder/context/project/founder/domain/timeline-frameworks.md` - WBS/PERT/CPM methodology
- `/home/benjamin/.config/nvim/.claude/extensions/founder/context/project/founder/patterns/forcing-questions.md` - Question framework
- `/home/benjamin/.config/nvim/.claude/extensions/founder/context/project/founder/templates/typst/project-timeline.typ` - Typst template
- `/home/benjamin/.config/nvim/.claude/agents/code-reviewer-agent.md` - Review output pattern
- `/home/benjamin/.config/nvim/.claude/extensions/founder/context/project/founder/patterns/contract-review.md` - Review methodology pattern
