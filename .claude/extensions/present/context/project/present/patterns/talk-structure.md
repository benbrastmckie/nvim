# Research Talk Structure Guide

Reference guide for structuring academic research presentations across five modes.

## Talk Modes Overview

| Mode | Duration | Slides | Primary Audience | Key Focus |
|------|----------|--------|------------------|-----------|
| CONFERENCE | 15-20 min | 12-18 | Peer researchers | Concise findings, methods, impact |
| SEMINAR | 45-60 min | 30-45 | Department/faculty | Deep methodology, research program |
| DEFENSE | 30-60 min | 25-40 | Review committee | Rigor, feasibility, preliminary data |
| POSTER | N/A | 1 | Conference attendees | Visual summary, quick comprehension |
| JOURNAL_CLUB | 15-30 min | 10-15 | Lab/journal club | Paper critique, group discussion |

## CONFERENCE Mode (12-Slide Standard)

The most common format for 15-20 minute platform presentations.

**Structure**: Title -> Motivation -> Background -> Objectives -> Methods -> Results (1-3) -> Discussion -> Limitations -> Conclusions -> Acknowledgments

**Key principles**:
- One message per slide
- ~1.5 minutes per slide
- Figures preferred over tables
- 3-4 concluding takeaway messages
- Pattern file: `talk/patterns/conference-standard.json`

## SEMINAR Mode (35-Slide Deep Dive)

Departmental seminar presenting a research program with multiple aims.

**Structure**: Introduction (6) -> Research Program by Aim (17) -> Synthesis (5) -> Future Directions (3) -> Closing (4)

**Key principles**:
- Organize by specific aims
- Include transitions between aims
- Show integration across aims in synthesis
- Discuss ongoing and future work
- Pattern file: `talk/patterns/seminar-deep-dive.json`

## DEFENSE Mode (30-Slide Grant Defense)

Grant defense for NIH study section or institutional review board.

**Structure**: Introduction (5) -> Preliminary Data (5) -> Specific Aims (10) -> Rigor and Feasibility (5) -> Impact and Closing (5)

**Key principles**:
- Emphasize significance and innovation
- Strong preliminary data section
- Detailed experimental approach per aim
- Address potential pitfalls proactively
- Show team expertise and environment
- Pattern file: `talk/patterns/defense-grant.json`

## POSTER Mode

Single-page poster for conference poster sessions.

**Layout sections**: Title Banner, Introduction, Methods, Results, Conclusions, References, Acknowledgments

**Key principles**:
- Readable from 4-6 feet away
- Minimal text, maximum visuals
- Clear visual hierarchy
- Contact information and QR code
- No pattern file (single-slide layout)

## JOURNAL_CLUB Mode (12-Slide Paper Review)

Paper review and critique for journal club meetings.

**Structure**: Title -> Overview -> Background -> Objectives -> Methods -> Results (1-2) -> Strengths -> Limitations/Critique -> Clinical Relevance -> Discussion Questions -> References

**Key principles**:
- Present the paper objectively first
- Separate strengths from limitations
- Prepare discussion questions for the group
- Include your own critical appraisal
- Pattern file: `talk/patterns/journal-club.json`

## Cross-Mode Guidelines

### Slide Density
- **Conference**: Low density (1 concept per slide)
- **Seminar**: Medium density (can include more detail)
- **Defense**: Medium-high density (reviewers expect detail)
- **Poster**: High density (space-constrained)
- **Journal Club**: Low-medium density (discussion-oriented)

### Visual Elements
- Use FigurePanel for research figures with captions
- Use DataTable for formatted results tables
- Use CitationBlock for inline literature references
- Use StatResult for statistical results display
- Use FlowDiagram for CONSORT/STROBE participant flow

### Timing Rules of Thumb
- Conference: ~1.5 min/slide
- Seminar: ~1.5-2 min/slide
- Defense: ~1.5-2 min/slide
- Journal Club: ~2 min/slide

### Content Reuse
- Research from `/grant` tasks can inform talk content via `task:{N}` references
- Manuscripts and papers can be provided as file path source materials
- Multiple talks can reference the same source materials with different modes

### Format-Specific Implementation Notes
- **Slidev**: See `talk/patterns/slidev-pitfalls.md` for setup, footer positioning, and mermaid gotchas
- **PowerPoint**: See `talk/patterns/pptx-generation.md` for python-pptx API patterns and component helpers
- Theme JSON files include a `footer` section with correct positioning guidance for custom footers
