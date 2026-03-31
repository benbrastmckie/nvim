# Implementation Plan: Add REVIEW Mode to /project Command

**Task**: #322 - Add REVIEW mode to /project command
**Session**: sess_1774889715_c80f76
**Date**: 2026-03-30
**Status**: Plan Complete

---

## Executive Summary

This plan implements a fourth REVIEW mode for the `/project` command, enabling critical analysis of project timelines to identify gaps, feasibility issues, resource concerns, and improvement opportunities. The implementation modifies two existing files (`project.md` and `project-agent.md`) and optionally creates a new skill file.

**Key Deliverables**:
1. REVIEW mode in project.md command definition
2. Review execution stages (R1-R4) in project-agent.md
3. 7-category analysis framework with 4-tier severity system
4. Review artifact output format

**Estimated Effort**: 2-3 hours

---

## Phase 1: Update project.md Command Definition [COMPLETED]

### Objective
Add REVIEW mode to the command's mode table, input handling, and workflow.

### Changes to `.claude/extensions/founder/commands/project.md`

#### 1.1 Update Mode Table (line ~33-38)

Add REVIEW row to the modes table:

```markdown
## Modes

| Mode | Posture | Focus |
|------|---------|-------|
| **PLAN** | Create timeline | WBS structure, PERT estimates, resource allocation, critical path |
| **TRACK** | Update progress | Task completion %, milestone status, variance analysis |
| **REPORT** | Executive summary | Status dashboard, risk assessment, key decisions needed |
| **REVIEW** | Critical analysis | Gaps, feasibility, risks, vulnerabilities, recommendations |
```

#### 1.2 Update Mode Selection (line ~48-57)

Update the AskUserQuestion prompt in Step 0.1:

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

#### 1.3 Add REVIEW Forcing Questions Section (new section after Step 0.2)

Insert new section for REVIEW-specific forcing questions:

```markdown
### Step 0.3: REVIEW Mode Forcing Questions (if mode == REVIEW)

**Question R1: Primary Concern**
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

**Question R2: Changed Constraints**
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

**Question R3: Timeline Validity Window**
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

**Question R4: Risk Tolerance**
```
What is your risk tolerance for this project?

Options:
- Conservative (prefer buffer time over speed)
- Balanced (accept normal project risk)
- Aggressive (willing to take schedule risk for speed)
```
Store as `review_context.risk_tolerance`.

**Question R5: Review Depth**
```
What depth of review do you need?

Options:
- Quick (high-level issues only, 5-10 minutes)
- Standard (all categories, 15-30 minutes)
- Deep (methodology audit + recommendations, 30-60 minutes)
```
Store as `review_context.review_depth`.
```

#### 1.4 Add REVIEW Input Handling (new section after Step 3)

Insert section for REVIEW-specific input handling:

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

**Supported Formats**:

| Format | Extension | Extraction Method |
|--------|-----------|-------------------|
| Typst Timeline | `.typ` | Parse `project-gantt()`, `pert-table()`, `resource-matrix()` calls |
| Markdown | `.md` | Parse tables, JSON code blocks, structured sections |
| JSON | `.json` | Direct parse of WBS, PERT, resource structures |
| Task Artifacts | (via task number) | Read from `specs/{NNN}_{SLUG}/reports/` |
```

#### 1.5 Update Workflow Summary Section

Add REVIEW to the workflow summary:

```markdown
## Workflow Summary

...

Alternative: Review existing timeline:
```
/project REVIEW "description"  -> Asks review questions, creates task, stops at [NOT STARTED]
/project 234                   -> Runs review on task 234's artifacts
/project /path/to/timeline.typ -> Reviews external timeline file
```
```

#### 1.6 Update Examples Section

Add REVIEW examples:

```markdown
## Examples

...

# Review mode examples
/project REVIEW 234              # Review existing task's timeline artifacts
/project ~/projects/timeline.typ # Review external Typst timeline
/project ~/projects/plan.md      # Review external Markdown timeline
```

### Validation Criteria
- [ ] Mode table shows all 4 modes
- [ ] Mode selection prompt includes REVIEW option
- [ ] REVIEW forcing questions documented (5 questions)
- [ ] Input handling covers file path and task number
- [ ] Supported formats table complete
- [ ] Examples include REVIEW usage

---

## Phase 2: Add REVIEW Stages to project-agent.md [COMPLETED]

### Objective
Add review execution stages (R1-R4) to handle REVIEW mode delegation.

### Changes to `.claude/extensions/founder/agents/project-agent.md`

#### 2.1 Add REVIEW Mode Section Header (after Stage 10)

Insert new section:

```markdown
---

## REVIEW Mode Stages

When invoked with mode=REVIEW, execute these stages instead of research stages.
```

#### 2.2 Add Stage R1: Parse Timeline Input

```markdown
### Stage R1: Parse Timeline Input

Based on input type and format, extract timeline data:

**For Typst files** (`.typ`):
- Read file content
- Extract `project-gantt()` task definitions via regex
- Extract `pert-table()` estimate data
- Extract `resource-matrix()` allocations
- Extract `risk-register()` risk items

**For Markdown files** (`.md`):
- Parse structured sections (## Work Breakdown Structure, ## PERT Estimates, ## Resource Allocation)
- Extract JSON code blocks tagged `json:wbs`, `json:pert`, `json:resources`
- Build internal data structures

**For Task artifacts** (task number input):
- Read research report from `specs/{NNN}_{SLUG}/reports/01_*.md`
- Read plan report from `specs/{NNN}_{SLUG}/plans/` if exists
- Extract Raw Data JSON blocks

**Data Structures** (internal representation):
```json
{
  "source": "{file path or task number}",
  "parse_mode": "{typst|markdown|json|artifact}",
  "wbs": { ... },
  "pert": { ... },
  "resources": { ... },
  "risks": { ... }
}
```
```

#### 2.3 Add Stage R2: Execute Analysis Framework

```markdown
### Stage R2: Execute Analysis Framework

Run all 7 category analyses, weighted by importance:

| Category | Weight | Focus |
|----------|--------|-------|
| Timeline Gaps | 15% | Missing phases, orphan tasks, implicit dependencies |
| Feasibility Issues | 20% | Unrealistic estimates, PERT outliers, duration problems |
| Resource Concerns | 15% | Overallocations, bottlenecks, skill gaps |
| Risk Assessment | 15% | Unmitigated risks, missing owners, unquantified risks |
| Critical Path Vulnerabilities | 15% | Long chains, no slack, brittleness |
| Dependency Issues | 10% | Circular, missing, implicit dependencies |
| Methodology Compliance | 10% | WBS 100% rule, PERT validity, milestone types |

**Severity Classification**:

| Severity | Definition | Response Required |
|----------|------------|-------------------|
| **Critical** | Project likely to fail without immediate action | Stop, address before proceeding |
| **High** | Significant risk to project success | Address within current planning cycle |
| **Medium** | Moderate risk or inefficiency | Address when convenient |
| **Low** | Minor issue or style concern | Optional improvement |

**Detection Rules** (per category):

**Timeline Gaps**:
- Missing phase: Common phase absent (e.g., no Testing phase) -> High
- Orphan task: Task with no deps and no dependents (not start/end) -> Medium
- Implicit dependency: Task B starts after A ends but no explicit FS link -> Medium
- Missing milestone: No milestone for major deliverable -> Low
- Phase without deliverable: Phase exists but no deliverable defined -> High

**Feasibility Issues**:
- High uncertainty: (P - O) / M > 2.0 -> High
- Optimism bias: O / M < 0.5 -> Medium
- Pessimism outlier: P / M > 4.0 -> Medium
- Invalid PERT order: O > M or M > P -> Critical
- Heroic estimate: Single task > 20 days expected -> High
- Duration implausible: Project 95% CI > 2x target date -> Critical

**Resource Concerns**:
- Critical overallocation: Sum of concurrent allocations > 150% -> Critical
- Overallocation: Sum of concurrent allocations 100-150% -> High
- Unassigned task: Task has no resource owner -> Medium
- Single-person dependency: One person owns all critical path tasks -> High
- Skill gap: Task requires skill not present in team -> High

**Risk Assessment**:
- No mitigation for critical risk: Risk score >= 15, no mitigation listed -> Critical
- Missing risk owner: Risk has no assigned owner -> High
- Unquantified risk: Risk has no probability/impact assessment -> Medium
- Insufficient contingency: No buffer for high-uncertainty tasks -> High

**Critical Path Vulnerabilities**:
- Long critical chain: > 10 sequential critical tasks -> High
- No parallel paths: All tasks on critical path -> Critical
- Zero slack throughout: Average float < 1 day across project -> High
- Critical path resource: Single person owns > 50% of critical path -> High

**Dependency Issues**:
- Circular dependency: Topological sort fails -> Critical
- Missing dependency: Task B uses output of A but no link -> High
- Long dependency chain: > 7 sequential dependencies -> Medium
- External dependency without buffer: External dep has no lag time -> High

**Methodology Compliance**:
- 100% rule violation: Child sum != parent -> High
- Missing three-point estimate: Only single estimate provided -> Medium
- PERT formula not used: Expected != (O + 4M + P) / 6 -> Medium
- Milestone has duration: Milestone > 0 days -> Low

Collect all findings with severity classifications.
```

#### 2.4 Add Stage R3: Generate Review Report

```markdown
### Stage R3: Generate Review Report

Write review artifact to appropriate location:
- Task-based input: `specs/{NNN}_{SLUG}/reports/02_timeline-review.md`
- File-based input: `strategy/reviews/timeline-review-{YYYYMMDD-HHMMSS}.md`

**Report Structure**:

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

Use Write tool to create the report file.
```

#### 2.5 Add Stage R4: Write Metadata File

```markdown
### Stage R4: Write Metadata File

Write final metadata to specified path:

```json
{
  "status": "reviewed",
  "summary": "Timeline review complete: {critical} critical, {high} high, {medium} medium, {low} low issues found.",
  "artifacts": [
    {
      "type": "review",
      "path": "{artifact_path}",
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

#### 2.6 Add Stage R5: Return Brief Summary

```markdown
### Stage R5: Return Brief Text Summary

Return a brief summary (NOT JSON):

```
Timeline review complete for {source}:
- Overall Health: {healthy|at_risk|critical}
- Confidence: {high|medium|low}
- Issues Found: {critical} critical, {high} high, {medium} medium, {low} low
- Top Concern: {highest severity finding}
- Review Report: {artifact path}
- Metadata written for skill postflight
```
```

### Validation Criteria
- [ ] REVIEW Mode Stages section exists
- [ ] Stage R1 covers all input formats (Typst, Markdown, JSON, artifacts)
- [ ] Stage R2 includes all 7 analysis categories with detection rules
- [ ] Stage R3 defines complete report structure
- [ ] Stage R4 specifies metadata format
- [ ] Stage R5 defines brief return format

---

## Phase 3: Integration and Testing [COMPLETED]

### Objective
Ensure REVIEW mode integrates properly with the existing command workflow.

### 3.1 Verify Skill Routing

The existing `skill-project` should handle REVIEW mode delegation. Verify:
- Mode parameter passes through to project-agent
- review_context data from forcing questions passes through
- Metadata file path follows convention

### 3.2 Test Scenarios

| Test Case | Input | Expected Output |
|-----------|-------|-----------------|
| Review existing task | `/project REVIEW 234` | Review report in task's reports directory |
| Review Typst file | `/project ~/timeline.typ` | Review report in strategy/reviews/ |
| Review Markdown file | `/project ~/plan.md` | Review report in strategy/reviews/ |
| Invalid file type | `/project ~/data.csv` | Error: Unsupported format |
| Missing file | `/project ~/missing.typ` | Error: File not found |
| Task not found | `/project REVIEW 999` | Error: Task not found |

### 3.3 Integration Points

- **Error handling**: REVIEW mode failures follow existing error patterns
- **Git commits**: Review artifacts commit with standard message format
- **Status sync**: If reviewing task artifacts, task status unchanged (review is read-only)

### Validation Criteria
- [ ] skill-project routes REVIEW mode correctly
- [ ] All test scenarios pass
- [ ] Error messages follow existing patterns
- [ ] Review artifacts created in correct locations

---

## Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Typst parsing complexity | Medium | Medium | Start with simple regex extraction; iterate |
| Large timeline files | Low | Medium | Add size limit check; truncate with warning |
| Missing source data | Medium | Low | Graceful degradation; skip analysis categories without data |

---

## Success Criteria

1. **REVIEW mode selectable**: Mode selection shows 4 options (PLAN, TRACK, REPORT, REVIEW)
2. **Forcing questions work**: 5 REVIEW-specific questions gather context
3. **Input handling complete**: File paths and task numbers both work
4. **Analysis framework functional**: 7 categories analyzed with severity levels
5. **Report generated**: Review artifact created with complete structure
6. **Metadata returned**: skill postflight receives valid metadata

---

## Estimated Effort

| Phase | Time | Complexity |
|-------|------|------------|
| Phase 1: project.md updates | 45 min | Low |
| Phase 2: project-agent.md stages | 60 min | Medium |
| Phase 3: Integration testing | 30 min | Low |
| **Total** | **~2.25 hours** | |

---

## Files Modified

| File | Action | Lines Changed |
|------|--------|---------------|
| `.claude/extensions/founder/commands/project.md` | Edit | ~150 lines added |
| `.claude/extensions/founder/agents/project-agent.md` | Edit | ~200 lines added |

## Files Created

None required. The skill-project-review mentioned in research is optional since skill-project can handle mode routing.

---

## Raw Data

```json:implementation_plan
{
  "task_number": 322,
  "session_id": "sess_1774889715_c80f76",
  "phases": [
    {
      "number": 1,
      "name": "Update project.md Command Definition",
      "status": "not_started",
      "deliverables": [
        "REVIEW mode in mode table",
        "REVIEW forcing questions section",
        "REVIEW input handling section",
        "Updated workflow summary and examples"
      ],
      "files": [
        ".claude/extensions/founder/commands/project.md"
      ],
      "estimated_minutes": 45
    },
    {
      "number": 2,
      "name": "Add REVIEW Stages to project-agent.md",
      "status": "not_started",
      "deliverables": [
        "Stage R1: Parse Timeline Input",
        "Stage R2: Execute Analysis Framework",
        "Stage R3: Generate Review Report",
        "Stage R4: Write Metadata File",
        "Stage R5: Return Brief Summary"
      ],
      "files": [
        ".claude/extensions/founder/agents/project-agent.md"
      ],
      "estimated_minutes": 60
    },
    {
      "number": 3,
      "name": "Integration and Testing",
      "status": "not_started",
      "deliverables": [
        "Skill routing verification",
        "Test scenario validation",
        "Integration point confirmation"
      ],
      "files": [],
      "estimated_minutes": 30
    }
  ],
  "total_estimated_minutes": 135,
  "risk_level": "low",
  "complexity": "medium"
}
```
