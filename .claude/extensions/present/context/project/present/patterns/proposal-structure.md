# Proposal Structure Patterns

Organizational patterns for structuring grant proposals by funder type and proposal stage.

## Overview

Proposals follow different structural patterns based on funder requirements. This guide covers common patterns and how to adapt them.

## Standard Section Order

### Foundation Proposals

```
1. Cover Letter
2. Executive Summary (1/2-1 page)
3. Organization Background (1-2 pages)
4. Statement of Need (1-2 pages)
5. Project Description (3-5 pages)
6. Evaluation Plan (1 page)
7. Timeline (1/2-1 page)
8. Budget and Justification (1-2 pages)
9. Sustainability (1/2 page)
10. Appendices (as allowed)
```

### Federal Proposals (NSF Pattern)

```
1. Cover Sheet (SF-424)
2. Project Summary (1 page, structured)
3. Project Description (15 pages max)
   - Introduction
   - Goals and Objectives
   - Background and Rationale
   - Research Plan / Project Activities
   - Broader Impacts
   - Timeline
4. References Cited (no page limit)
5. Biographical Sketches (2 pages each)
6. Budget and Justification
7. Facilities and Equipment
8. Data Management Plan (2 pages)
9. Supplementary Documents
```

### Federal Proposals (NIH Pattern)

```
1. Face Page
2. Project Summary/Abstract (30 lines)
3. Specific Aims (1 page)
4. Research Strategy (12 pages)
   - Significance
   - Innovation
   - Approach
5. Bibliography/References
6. Budget and Justification
7. Biosketches (5 pages each)
8. Facilities and Resources
9. Equipment
10. Letters of Support
```

## Section Hierarchy Pattern

Use consistent heading levels throughout:

```markdown
# Project Title

## Section Name (Major Section)

### Subsection (Topic within section)

#### Point (Specific detail if needed)
```

### Heading Guidelines

- **Level 1 (#)**: Only for project title
- **Level 2 (##)**: Major proposal sections
- **Level 3 (###)**: Subsections within major sections
- **Level 4 (####)**: Only when necessary for complex sections

## Problem-Solution Pattern

Structure narrative sections using this pattern:

```
1. PROBLEM
   - Define the issue
   - Provide evidence of severity
   - Show consequences of inaction

2. SOLUTION
   - Describe your approach
   - Explain why this approach will work
   - Show evidence base or theory of change

3. CAPACITY
   - Demonstrate ability to execute
   - Highlight relevant experience
   - Show necessary resources

4. IMPACT
   - Describe expected outcomes
   - Connect to funder priorities
   - Show measurement approach
```

## Logic Model Pattern

Present theory of change visually:

```
INPUTS         ACTIVITIES       OUTPUTS        OUTCOMES
(Resources)    (What we do)     (Products)     (Changes)
    |              |                |              |
    v              v                v              v
+--------+    +---------+      +---------+    +---------+
| Staff  | -> | Train   | ->   | 100     | -> | 80%     |
| Money  |    | people  |      | trained |    | report  |
| Space  |    |         |      |         |    | skill   |
+--------+    +---------+      +---------+    +---------+
```

### Text Version

When visual is not possible:

```
IF we provide [inputs]
AND conduct [activities]
THEN we will produce [outputs]
WHICH will lead to [short-term outcomes]
WHICH will result in [long-term outcomes]
```

## Parallel Structure Pattern

Use consistent structure for similar elements:

### Objectives (Good)

```
Objective 1: Increase X by Y% by [date]
Objective 2: Reduce Z by W% by [date]
Objective 3: Establish N new [things] by [date]
```

### Objectives (Poor - Inconsistent)

```
Objective 1: We will increase X
Objective 2: Reducing Z is important
Objective 3: N new things
```

## STAR Method for Examples

Structure accomplishments and evidence:

```
SITUATION: Context or challenge faced
TASK: Specific goal or responsibility
ACTION: Steps taken to address
RESULT: Quantifiable outcome achieved
```

### Example

```
SITUATION: Our community lacked access to after-school tutoring.
TASK: Develop and launch a peer tutoring program within 6 months.
ACTION: Recruited and trained 25 high school tutors, partnered with
        3 elementary schools, secured donated space.
RESULT: 150 students received tutoring; 85% improved grades by one
        letter within one semester.
```

## Signposting Pattern

Guide readers through complex proposals:

### Section Transitions

```
"Having established the need for this program, we now describe our
approach to addressing it."

"The following section outlines our evaluation methodology..."

"Building on our track record described above, we now present..."
```

### Internal References

```
"As described in Section 3..."
"The budget (see page 12) reflects..."
"Consistent with our theory of change (Figure 1)..."
```

## Funder Alignment Pattern

Explicitly connect to funder priorities:

```
1. Quote or paraphrase funder priority
2. State how your project addresses it
3. Provide specific evidence
```

### Example

```
[Funder] prioritizes "innovative approaches to STEM education."
Our project directly addresses this priority by implementing [specific
innovation], which has been shown to [evidence of effectiveness].
```

## White Space Pattern

Improve readability:

- **Short paragraphs**: 3-5 sentences maximum
- **Bulleted lists**: For 3+ parallel items
- **Headers**: Break text every 1-2 paragraphs
- **Tables**: For comparative information
- **Visual breaks**: Between major sections

## Best Practices

1. **Start with funder template**: Never ignore required structure
2. **Use section headers liberally**: Reviewers skim
3. **Front-load key information**: Important points first
4. **Be explicit**: State connections, do not assume they are obvious
5. **Number objectives**: Makes reference easy
6. **Use consistent terminology**: Same word for same concept throughout

## Navigation

- [Budget Patterns](budget-patterns.md)
- [Evaluation Patterns](evaluation-patterns.md)
- [Narrative Patterns](narrative-patterns.md)
- [Parent Directory](../README.md)
