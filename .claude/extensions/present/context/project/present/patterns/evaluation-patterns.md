# Evaluation Patterns

Frameworks for measuring project success, including logic models, outcome hierarchies, and measurement approaches.

## Overview

| Evaluation Type | Purpose | When Used |
|-----------------|---------|-----------|
| Process | Are activities happening as planned? | Ongoing |
| Outcome | Are short/medium-term changes occurring? | Milestones |
| Impact | Long-term systemic change | End of project |
| Formative | Improve program during implementation | Ongoing |
| Summative | Assess overall effectiveness | End of project |

## Logic Model Pattern

### Visual Format

```
+-------------+    +------------+    +-----------+    +-------------+
|   INPUTS    | -> | ACTIVITIES | -> |  OUTPUTS  | -> |  OUTCOMES   |
+-------------+    +------------+    +-----------+    +-------------+
| - Staff     |    | - Develop  |    | - 10      |    | Short-term: |
| - Funding   |    |   curriculum|   |   modules |    | - Knowledge |
| - Partners  |    | - Train    |    | - 200     |    |   gained    |
| - Facilities|    |   teachers |    |   trained |    |             |
| - Materials |    | - Implement|    | - 50      |    | Medium-term:|
|             |    |   program  |    |   schools |    | - Practice  |
|             |    |            |    |           |    |   change    |
|             |    |            |    |           |    |             |
|             |    |            |    |           |    | Long-term:  |
|             |    |            |    |           |    | - Student   |
|             |    |            |    |           |    |   outcomes  |
+-------------+    +------------+    +-----------+    +-------------+
                         ^                                    |
                         |          ASSUMPTIONS               |
                         +------------------------------------+
```

### Text Format

```markdown
## Logic Model

### Inputs (Resources)
- [Resource 1]: [How it will be used]
- [Resource 2]: [How it will be used]

### Activities (What we do)
- Activity 1: [Description]
- Activity 2: [Description]

### Outputs (Direct products)
- [Number] [things produced/delivered]
- [Number] [people reached/trained]

### Outcomes (Changes that result)

**Short-term (0-6 months)**
- Participants will [knowledge/attitude change]

**Medium-term (6-18 months)**
- Participants will [behavior/practice change]

**Long-term (18+ months)**
- [Population/system level change]

### Assumptions
- [Key assumption 1]
- [Key assumption 2]
```

## SMART Outcomes Pattern

### Template

```
By [DATE], [TARGET POPULATION] will [CHANGE] as measured by
[INDICATOR], increasing/decreasing from [BASELINE] to [TARGET].
```

### Examples

```
Short-term: By Month 6, 90% of workshop participants will
demonstrate understanding of safety protocols as measured by
post-workshop assessment scores above 80%.

Medium-term: By Month 12, participating organizations will
show 25% reduction in safety incidents as measured by incident
reports compared to the 12-month baseline period.

Long-term: By Month 24, the regional industry will adopt the
new safety standards as evidenced by certification of 50% of
eligible organizations.
```

## Outcome Hierarchy Pattern

```
                    IMPACT
                      |
          +-----------+-----------+
          |                       |
     Long-term              Long-term
     Outcome 1              Outcome 2
          |                       |
    +-----+-----+           +-----+-----+
    |           |           |           |
 Medium      Medium      Medium      Medium
 Outcome     Outcome     Outcome     Outcome
    |           |           |           |
 +--+--+     +--+--+     +--+--+     +--+--+
 |     |     |     |     |     |     |     |
S-T   S-T   S-T   S-T   S-T   S-T   S-T   S-T
```

### Writing Outcome Chains

```
IF we [activity]
THEN [short-term outcome] because [mechanism]
WHICH leads to [medium-term outcome] because [mechanism]
WHICH results in [long-term outcome]
```

## Indicator Development Pattern

### Indicator Table

```markdown
| Outcome | Indicator | Data Source | Frequency | Target |
|---------|-----------|-------------|-----------|--------|
| Increased knowledge | Test scores | Pre/post test | Start/end | 80% pass |
| Changed practice | Behavior checklist | Observation | Monthly | 75% compliance |
| Improved outcomes | Performance data | System records | Quarterly | 20% improvement |
```

### Indicator Quality Checklist

```
[ ] Specific: Measures one thing clearly
[ ] Measurable: Quantifiable or categorizable
[ ] Available: Data can actually be collected
[ ] Relevant: Connected to outcome
[ ] Timely: Available when needed
[ ] Independent: Not influenced by evaluator
```

## Data Collection Matrix

```markdown
## Data Collection Plan

| Question | Data Source | Method | Timing | Responsible |
|----------|-------------|--------|--------|-------------|
| Are activities on track? | Project records | Review | Monthly | PM |
| Did knowledge increase? | Participants | Pre/post survey | Start/end | Evaluator |
| Did behavior change? | Supervisors | Interview | Q2, Q4 | Evaluator |
| Were outcomes achieved? | System data | Data pull | Quarterly | Analyst |
```

## Evaluation Timeline Pattern

```markdown
## Evaluation Timeline

| Activity | M1 | M2 | M3 | M4 | M5 | M6 | M7 | M8 | M9 | M10 | M11 | M12 |
|----------|----|----|----|----|----|----|----|----|----|----|-----|-----|
| Baseline |  X |    |    |    |    |    |    |    |    |    |     |     |
| Process  |    |  X |    |  X |    |  X |    |  X |    |  X |     |     |
| Midpoint |    |    |    |    |    |  X |    |    |    |    |     |     |
| Outcome  |    |    |    |    |    |    |    |    |    |    |     |  X  |
| Report   |    |    |  X |    |    |  X |    |    |  X |    |     |  X  |
```

## Theory of Change Pattern

### Narrative Format

```markdown
## Theory of Change

**Problem Statement**
[Description of the problem and its root causes]

**Solution Hypothesis**
We believe that by [intervention], we will achieve [outcome] because
[mechanism/evidence].

**Key Assumptions**
1. [Assumption about context]
2. [Assumption about participants]
3. [Assumption about implementation]

**Evidence Base**
- [Prior research or program evidence]
- [Theoretical framework]

**Critical Uncertainties**
- [What we do not know that could affect success]
- [Risks to the theory]
```

## Measurement Methods

### Quantitative Methods

| Method | Use Case | Pros | Cons |
|--------|----------|------|------|
| Surveys | Large groups, standardized | Scalable, comparable | Response bias |
| Tests | Knowledge assessment | Objective | Limited scope |
| Administrative data | System-level outcomes | Already collected | May not fit needs |
| Observations | Behavior documentation | Direct | Observer effect |

### Qualitative Methods

| Method | Use Case | Pros | Cons |
|--------|----------|------|------|
| Interviews | In-depth understanding | Rich data | Time-intensive |
| Focus groups | Group perspectives | Efficient | Groupthink |
| Case studies | Complex situations | Contextual | Not generalizable |
| Document review | Historical analysis | Non-intrusive | Incomplete |

## Reporting Pattern

### Quarterly Report Structure

```markdown
# Quarterly Progress Report

## Executive Summary
[2-3 sentences on overall progress]

## Activities Completed
- [Activity 1]: [Status/completion]
- [Activity 2]: [Status/completion]

## Outputs Achieved
| Output | Target | Actual | % Complete |
|--------|--------|--------|------------|
| [Output] | [N] | [N] | [X]% |

## Outcome Progress
[Early indicators of outcome achievement]

## Challenges and Adaptations
[What problems arose, how addressed]

## Next Quarter Plans
[Key activities planned]

## Financial Summary
[Budget vs. actual spending]
```

## Best Practices

1. **Plan evaluation early**: Build into proposal, not afterthought
2. **Be realistic**: Do not promise more measurement than resources allow
3. **Use existing data**: Administrative records are often underutilized
4. **Budget appropriately**: 5-15% of project budget for evaluation
5. **Involve stakeholders**: Include participants in evaluation design
6. **Plan for learning**: Build in feedback loops, not just final reports

## Navigation

- [Proposal Structure](proposal-structure.md)
- [Budget Patterns](budget-patterns.md)
- [Narrative Patterns](narrative-patterns.md)
- [Parent Directory](../README.md)
