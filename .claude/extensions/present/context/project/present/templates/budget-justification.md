# Budget Justification Templates

Templates for writing budget justifications that connect expenses to project activities.

## Overview

Budget justifications explain why each expense is necessary and how costs were calculated. Strong justifications prevent reviewer questions and demonstrate careful planning.

## Personnel Template

### Standard Format

```markdown
## Personnel

### [NAME], [TITLE] ([X]% effort, [Y] calendar months)
**Salary**: $[AMOUNT] | **Fringe**: $[AMOUNT] | **Total**: $[AMOUNT]

[Name] will serve as [ROLE], responsible for [LIST 2-3 KEY RESPONSIBILITIES].
This level of effort ([X]%) is required because [RATIONALE FOR EFFORT LEVEL].

[Name]'s qualifications include [RELEVANT CREDENTIALS OR EXPERIENCE].
[Optional: [Name] will spend approximately [X] hours per week on [SPECIFIC
ACTIVITIES].]

Salary is based on [institutional salary scale / market rate / current salary].
Fringe benefits are calculated at [X]% per institutional policy, covering
[health insurance, retirement, etc.].
```

### Example

```markdown
### Dr. Jane Smith, Principal Investigator (10% effort, 1.2 calendar months)
**Salary**: $12,000 | **Fringe**: $4,200 | **Total**: $16,200

Dr. Smith will serve as PI, providing overall project direction, supervising
research staff, leading data analysis, and ensuring timely completion of
deliverables. This 10% effort is sufficient because day-to-day activities
will be managed by the Project Coordinator.

Dr. Smith has 15 years of experience in community health research, including
3 prior NIH-funded studies with similar methodology. Salary is based on the
institutional base salary of $120,000. Fringe benefits are calculated at 35%
per university policy.
```

### To Be Named (TBN) Template

```markdown
### To Be Named, Research Assistant (100% effort, 12 calendar months)
**Salary**: $45,000 | **Fringe**: $15,750 | **Total**: $60,750

A full-time Research Assistant will be recruited to [PRIMARY RESPONSIBILITIES].
Qualifications will include [REQUIRED CREDENTIALS].

This position requires full-time effort because [JUSTIFICATION].

Salary is based on institutional pay scale for [position level/grade] with
[X] years of experience. The position will be advertised within [timeframe]
of award.
```

## Equipment Template

```markdown
## Equipment

### [EQUIPMENT NAME]
**Cost**: $[AMOUNT] | **Quantity**: [N] | **Total**: $[AMOUNT]

**Purpose**: [What the equipment will be used for in the project]

**Justification**: This equipment is necessary because [why existing equipment
is insufficient]. Specifically, [technical requirement that necessitates this
equipment].

**Procurement**: Cost based on [vendor quote / catalog price / market research].
[Quote/documentation attached as appendix if required.]

**Location**: Equipment will be housed at [location] and maintained by [person/unit].
```

### Example

```markdown
### High-Performance Computing Server
**Cost**: $25,000 | **Quantity**: 1 | **Total**: $25,000

**Purpose**: This server will support machine learning model training and
large-scale data analysis required for Objectives 2 and 3.

**Justification**: Current institutional computing resources are insufficient
for the intensive GPU computation required. Our experiments require [specific
technical specifications] which are not available through shared resources.
Training time on existing systems would exceed 6 months vs. 2 weeks with
dedicated hardware.

**Procurement**: Cost based on Dell quote #12345 dated 1/15/2025. Server
specifications: [specifications].

**Location**: Equipment will be housed in the PI's laboratory and maintained
by the Computer Science department IT staff.
```

## Travel Template

```markdown
## Travel

### [TRIP PURPOSE]
**Per Trip**: $[AMOUNT] | **# Trips**: [N] | **# Travelers**: [N] | **Total**: $[AMOUNT]

**Purpose**: [Why this travel is necessary for the project]

**Breakdown**:
- Airfare: $[X] (based on [current fares / GSA rate / estimate])
- Lodging: $[X]/night x [N] nights = $[X]
- Per diem: $[X]/day x [N] days = $[X] (per [GSA rates / institutional policy])
- Ground transportation: $[X]
- Registration (if applicable): $[X]
```

### Example

```markdown
### Annual Conference Presentation (ACM CHI)
**Per Trip**: $2,200 | **# Trips**: 1 | **# Travelers**: 2 | **Total**: $4,400

**Purpose**: PI and graduate student will present research findings at ACM CHI,
the premier venue for this research area. Presentation of results is essential
for dissemination and feedback from the research community.

**Breakdown** (per person):
- Airfare: $600 (based on current fares to likely conference locations)
- Lodging: $200/night x 4 nights = $800
- Per diem: $75/day x 5 days = $375 (per GSA rates)
- Ground transportation: $75
- Conference registration: $350 (early bird academic rate)
```

## Supplies and Materials Template

```markdown
## Supplies and Materials

### [CATEGORY]
**Total**: $[AMOUNT]

**Items included**:
- [Item 1]: $[X] ([calculation or quantity])
- [Item 2]: $[X] ([calculation or quantity])
- [Item 3]: $[X] ([calculation or quantity])

**Justification**: These supplies are necessary for [specific project activities].
[Additional context on how costs were estimated.]
```

### Example

```markdown
## Supplies and Materials

### Laboratory Consumables
**Total**: $3,600

**Items included**:
- Reagents and chemicals: $2,000 (based on prior project costs)
- Pipette tips and tubes: $800 ($200/month x 4 months of experiments)
- Safety supplies: $400 (gloves, goggles, lab coats)
- Miscellaneous: $400 (unforeseen consumables)

**Justification**: These consumables are required to conduct the experiments
described in Phase 2. Estimates are based on similar experiments conducted
in the PI's laboratory over the past 2 years.
```

## Contractual/Consultant Template

```markdown
## Contractual Services

### [CONSULTANT NAME OR TBN], [EXPERTISE]
**Rate**: $[X]/[hour/day] | **Units**: [N] [hours/days] | **Total**: $[AMOUNT]

**Role**: [Specific responsibilities in the project]

**Justification**: External expertise is required because [why internal staff
cannot provide this]. [Consultant name] is uniquely qualified because [relevant
credentials].

**Deliverables**: [What the consultant will produce]
```

### Example

```markdown
## Contractual Services

### Dr. Maria Garcia, External Evaluator
**Rate**: $150/hour | **Units**: 80 hours | **Total**: $12,000

**Role**: Dr. Garcia will design the evaluation framework, develop data
collection instruments, conduct analysis, and prepare evaluation reports.

**Justification**: External evaluation provides objectivity and methodological
expertise that complements the implementation team. Dr. Garcia has 20 years of
experience evaluating similar programs and holds a Ph.D. in Program Evaluation.

**Deliverables**: Evaluation plan (Month 2), mid-point report (Month 12),
final evaluation report (Month 24).
```

## Other Direct Costs Template

```markdown
## Other Direct Costs

### Publication Costs
**Total**: $[AMOUNT]
Publication fees for [N] anticipated peer-reviewed articles at approximately
$[X] per article. [Journal names if known] charge [X] for open access publication.

### Participant Support
**Total**: $[AMOUNT]
[N] participants will receive $[X] each as [compensation/stipend] for [purpose].
This amount is [consistent with IRB protocols / standard for similar studies].

### Software/Licenses
**Total**: $[AMOUNT]
Annual license for [Software Name] ($[X]/year x [N] years). This software is
necessary for [specific project activity].

### Communication/Printing
**Total**: $[AMOUNT]
[Description of what will be printed or communicated and why].
```

## Indirect Costs Template

```markdown
## Indirect Costs (Facilities and Administration)

Indirect costs are calculated at the federally negotiated rate of [X]% on
modified total direct costs (MTDC).

**MTDC Base**: $[AMOUNT]
**Indirect Costs** ([X]%): $[AMOUNT]

MTDC excludes: equipment over $5,000, participant support costs, and the
portion of subawards exceeding $25,000.

[Institution name]'s negotiated rate agreement is dated [date] and is valid
through [date]. A copy is included in the appendix.
```

## Multi-Year Budget Template

```markdown
## Budget Summary by Year

| Category | Year 1 | Year 2 | Year 3 | Total |
|----------|--------|--------|--------|-------|
| Personnel | $X | $X | $X | $X |
| Fringe | $X | $X | $X | $X |
| Equipment | $X | $0 | $0 | $X |
| Travel | $X | $X | $X | $X |
| Supplies | $X | $X | $X | $X |
| Other | $X | $X | $X | $X |
| **Direct** | **$X** | **$X** | **$X** | **$X** |
| Indirect | $X | $X | $X | $X |
| **Total** | **$X** | **$X** | **$X** | **$X** |

**Year-over-Year Changes**:
- Personnel: [X]% annual increase per institutional policy
- Year 1 equipment costs are one-time purchases
- [Other explanations for year-to-year variations]
```

## Best Practices

1. **Connect to activities**: Every cost should link to specific project tasks
2. **Show calculations**: Demonstrate how figures were derived
3. **Be specific**: Avoid vague categories; itemize where possible
4. **Verify accuracy**: Triple-check all math
5. **Match narrative**: Budget should reflect what's described elsewhere
6. **Follow format**: Use funder's required categories exactly
7. **Document sources**: Reference quotes, rates, and policies

## Navigation

- [Executive Summary](executive-summary.md)
- [Evaluation Plan](evaluation-plan.md)
- [Submission Checklist](submission-checklist.md)
- [Parent Directory](../README.md)
