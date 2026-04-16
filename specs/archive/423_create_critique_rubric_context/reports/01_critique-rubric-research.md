# Research Report: Task #423

**Task**: 423 - Create critique rubric context file
**Started**: 2026-04-13T00:00:00Z
**Completed**: 2026-04-13T00:15:00Z
**Effort**: Small-medium (context file creation, well-defined scope)
**Dependencies**: None
**Sources/Inputs**:
- Codebase: present extension talk patterns, themes, domain files, agents
- WebSearch: academic presentation rubrics, thesis defense evaluation, poster scoring, slide critique methodology
- Existing standards: presentation-types.md, talk-structure.md, narrative-patterns.md, evaluation-patterns.md, writing-standards.md
**Artifacts**: - specs/423_create_critique_rubric_context/reports/01_critique-rubric-research.md
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The present extension has rich talk patterns (4 mode JSONs), domain knowledge (presentation-types.md), and structural guidance (talk-structure.md) but no critique/review rubric for evaluating generated or existing presentations
- Academic presentation rubrics universally organize around 5-7 categories: content/organization, delivery/clarity, visual design, audience awareness, evidence quality, and timing/structure
- Severity classification should use a 3-tier model (critical/major/minor) aligned with code review conventions already familiar to the agent system
- Talk-type-specific criteria are well-supported by the existing pattern JSONs, which define expected slide counts, sections, timing, and content focus per mode -- the rubric should reference these directly
- The rubric file should be structured as a machine-readable reference (not prose) so a future slide-critic-agent can systematically evaluate presentations against it

## Context & Scope

This research informs creation of `.claude/extensions/present/context/project/present/talk/critique-rubric.md`, a context file that will be consumed by a slide-critic-agent to evaluate slide presentations. The file must define review criteria, scoring patterns, and talk-type-specific adjustments across all five presentation modes (CONFERENCE, SEMINAR, DEFENSE, POSTER, JOURNAL_CLUB).

### Constraints
- Must integrate with existing talk pattern JSONs (conference-standard.json, seminar-deep-dive.json, defense-grant.json, journal-club.json)
- Must follow the present extension's established conventions (markdown context files, structured references)
- No slide-critic-agent exists yet -- this rubric will inform its future creation
- The rubric should be agent-consumable (structured, scannable) not a human essay

## Findings

### Codebase Patterns

**Existing Talk Patterns (4 modes + poster)**:
Each pattern JSON defines slide positions, types, required/optional status, content focus, and template references. These provide the structural baseline for critique:

| Mode | Pattern File | Slides | Sections | Key Structural Features |
|------|-------------|--------|----------|------------------------|
| CONFERENCE | conference-standard.json | 12 | flat | ~1.5 min/slide, figures over tables, one message per slide |
| SEMINAR | seminar-deep-dive.json | 35 | 5 sections | Aim-based organization, transitions between aims, synthesis section |
| DEFENSE | defense-grant.json | 30 | 5 sections | Significance/innovation emphasis, preliminary data, pitfalls/alternatives |
| JOURNAL_CLUB | journal-club.json | 12 | flat | Objective presentation first, then critique, discussion questions |
| POSTER | (no pattern file) | 1 | layout-based | Readable from 4-6 feet, minimal text, visual hierarchy |

**Existing Domain Knowledge**:
- `presentation-types.md`: Defines audience, duration, format, key considerations per mode. This is the authoritative source for what differentiates a good conference talk from a good seminar.
- `talk-structure.md`: Cross-mode guidelines for slide density, visual elements, timing rules, content reuse patterns.
- `narrative-patterns.md`: Writing quality patterns (impact statements, problem framing, specificity ladder, active voice). Directly applicable to content quality criteria.
- `writing-standards.md`: Precision standards, evidence hierarchy, terminology consistency. Maps to evidence quality criteria.
- `evaluation-patterns.md`: Logic models and outcome frameworks (grant-focused, not presentation-focused).

**Existing Theme JSONs**:
Theme files (academic-clean.json, clinical-teal.json, ucsf-institutional.json) define palette, typography, spacing, borders, and footer positioning. These inform visual design criteria (contrast, font sizing, spacing consistency).

**Existing Components**:
Five Vue components (FigurePanel, DataTable, CitationBlock, StatResult, FlowDiagram) represent the expected visual vocabulary. Critique should check whether appropriate components are used.

**No Existing Critic Agent or Rubric**:
Grep for "critic", "rubric", "review" in the present extension found no existing critique framework. The slide-planner-agent and slides-research-agent exist but focus on creation, not evaluation.

### External Research: Academic Presentation Rubrics

**Universal Rubric Categories** (synthesized from multiple sources):

1. **Content & Organization** -- Logical flow, completeness, accuracy of information, appropriate depth
2. **Visual Design** -- Slide readability, text density, figure quality, layout consistency
3. **Audience Alignment** -- Jargon calibration, assumed knowledge level, engagement strategies
4. **Evidence Quality** -- Data presentation, citations, statistical reporting, claims support
5. **Timing & Pacing** -- Slide count vs. duration, section balance, information density per minute
6. **Narrative Structure** -- Story arc, motivation framing, transitions, conclusions that land

**Scoring Approaches**:
- Analytic rubrics (per-criterion scoring) are more useful for automated agents than holistic rubrics
- Common scales: 4-point (Excellent/Good/Adequate/Poor), 5-point (1-5), 10-point
- For agent use, a severity-based approach (critical/major/minor) maps better to actionable feedback

**Severity Classification (from code review and academic peer review conventions)**:

| Severity | Definition | Action Required |
|----------|-----------|----------------|
| Critical | Presentation will fail its purpose; audience will be confused or misled | Must fix before presenting |
| Major | Significantly weakens the presentation; noticeable quality gap | Should fix; presentation is suboptimal |
| Minor | Polish issue; would improve quality but not essential | Nice to fix; low priority |

### External Research: Talk-Type-Specific Criteria

**Conference Talks**:
- Time discipline is paramount (strict enforcement by session chairs)
- One message per slide principle
- Figures preferred over tables (audience cannot read dense tables from a distance)
- 3-4 concluding takeaways maximum
- Must be self-contained (audience may not have read the paper)

**Seminar Presentations**:
- Research program narrative arc (how aims connect)
- Transitions between sections are critical for 45-60 min talks
- Deeper methodology is expected and welcome
- Balance between comprehensive and overwhelming
- Future directions section signals active research program

**Defense/Grant Presentations**:
- Committee has read the proposal -- do not just read slides aloud
- Preliminary data must be strong and clearly presented
- Pitfalls and alternatives show intellectual rigor
- Innovation must be explicitly stated, not left for inference
- Q&A preparation matters more than slide quality

**Poster Sessions**:
- Readability from 4-6 feet is the single most important criterion
- Maximum 50-75 words per figure label
- Visual hierarchy must guide the eye through the poster
- Must stand alone without presenter narration
- QR code/contact information for follow-up

**Journal Club**:
- Objective presentation before personal critique
- Strengths-before-limitations ordering
- Discussion questions quality (not just "what do you think?")
- Connection to group's own research
- Methodological critique depth (biases, confounders, design issues)

### Visual Design Criteria (synthesized)

| Criterion | Good | Problematic |
|-----------|------|-------------|
| Text per slide | 6-8 lines, 30-40 words | >10 lines or >80 words |
| Font size (body) | 24-28pt minimum | <20pt |
| Font size (title) | 36-44pt | <28pt |
| Figures per slide | 1-2 with clear labels | >3 or unlabeled |
| Color contrast | WCAG AA ratio (4.5:1) | Low contrast text on background |
| Bullet depth | 1 level preferred, 2 max | 3+ nested levels |
| Animations | Purposeful (reveal sequence) | Decorative or distracting |
| Consistency | Same layout patterns throughout | Mixed styles across slides |

### Narrative Flow Criteria

The "Glance Test" from presentation design: each slide should communicate its main point within 3 seconds of viewing. Related criteria:
- Every slide should answer "why does this matter?" or "what should I remember?"
- Transitions between slides should feel natural, not abrupt
- The overall arc should follow: Hook -> Context -> Evidence -> Synthesis -> Takeaway
- Section transitions should be explicit (transition slides or verbal bridges)

## Decisions

1. **Severity model**: Use 3-tier (critical/major/minor) rather than numeric scoring. This is more actionable for an agent producing feedback.
2. **Category structure**: Use 6 categories matching the task description (narrative flow, audience alignment, timing balance, content depth, evidence quality, visual design) rather than the 3-category academic rubric model (content/delivery/visual).
3. **Talk-type specificity**: Implement as modifier tables that adjust baseline criteria per mode, rather than separate complete rubrics per mode.
4. **Machine-readable format**: Use structured markdown with clear headings, tables, and checklists rather than prose paragraphs.
5. **Integration with patterns**: Reference existing pattern JSONs by path so the critic agent can cross-reference expected structure against actual slides.

## Recommendations

### File Structure for critique-rubric.md

```
1. Overview & Purpose
2. Severity Definitions (critical/major/minor)
3. Rubric Categories (6 sections, each with):
   - Category description
   - Criteria table (criterion | good | problematic | severity-if-violated)
   - Common anti-patterns
4. Talk-Type-Specific Adjustments (modifier table per mode)
5. Cross-References to pattern JSONs and templates
6. Output Format Guidance (how the critic should structure its feedback)
```

### Priority of Categories by Talk Type

| Category | CONFERENCE | SEMINAR | DEFENSE | POSTER | JOURNAL_CLUB |
|----------|-----------|---------|---------|--------|-------------|
| Narrative Flow | High | Critical | High | Medium | High |
| Audience Alignment | Critical | High | High | High | Medium |
| Timing Balance | Critical | High | Medium | N/A | Medium |
| Content Depth | Medium | High | Critical | Medium | Critical |
| Evidence Quality | High | High | Critical | High | Critical |
| Visual Design | High | Medium | Medium | Critical | Low |

### Integration Points

- The critic agent should load the appropriate pattern JSON for the talk mode to validate structural compliance
- Theme JSONs should be used to check visual consistency
- The component list (FigurePanel, DataTable, etc.) should inform whether appropriate visual elements are used
- narrative-patterns.md criteria (specificity ladder, data sandwich, active voice) should feed into content quality checks

## Risks & Mitigations

| Risk | Mitigation |
|------|-----------|
| Rubric too prescriptive, stifling creative presentations | Include "guidelines not rules" framing; severity levels allow flexibility |
| Rubric categories overlap (e.g., evidence quality vs content depth) | Define clear boundaries in category descriptions; each criterion belongs to exactly one category |
| Talk-type modifiers become unwieldy with 5 modes x 6 categories | Use a single modifier table rather than 5 separate rubric copies |
| Critic agent may not exist yet, so rubric format may need revision | Design for human readability too; structured markdown works for both |
| Poster mode is fundamentally different (single page vs slides) | Include poster-specific section noting which criteria apply differently |

## Appendix

### Search Queries Used
1. "academic presentation evaluation rubric criteria categories conference talk scoring"
2. "scientific conference presentation review criteria severity levels critical minor issues slide evaluation"
3. "thesis defense presentation evaluation form criteria rubric committee assessment"
4. "poster presentation evaluation criteria scientific conference visual design text density scoring"
5. "slide critique OR presentation review narrative flow audience alignment timing pacing automated evaluation"

### Codebase Files Examined
- `.claude/extensions/present/context/project/present/talk/patterns/conference-standard.json`
- `.claude/extensions/present/context/project/present/talk/patterns/seminar-deep-dive.json`
- `.claude/extensions/present/context/project/present/talk/patterns/defense-grant.json`
- `.claude/extensions/present/context/project/present/talk/patterns/journal-club.json`
- `.claude/extensions/present/context/project/present/talk/index.json`
- `.claude/extensions/present/context/project/present/talk/themes/academic-clean.json`
- `.claude/extensions/present/context/project/present/domain/presentation-types.md`
- `.claude/extensions/present/context/project/present/patterns/talk-structure.md`
- `.claude/extensions/present/context/project/present/patterns/narrative-patterns.md`
- `.claude/extensions/present/context/project/present/patterns/evaluation-patterns.md`
- `.claude/extensions/present/context/project/present/standards/writing-standards.md`
- `.claude/extensions/present/agents/slide-planner-agent.md`

### External References
- [Illinois State Oral Presentation Rubric](https://assessment.illinoisstate.edu/downloads/about/2018_Rubric_Presentation.doc)
- [ReadWriteThink Oral Presentation Rubric](https://www.readwritethink.org/classroom-resources/printouts/oral-presentation-rubric)
- [PMC - Preparing Slides for Conference Research Presentations](https://pmc.ncbi.nlm.nih.gov/articles/PMC9896115/)
- [UCGHI Poster Guidelines & Judging Criteria](https://www.ucghi.universityofcalifornia.edu/poster-guidelines-judging-criteria)
- [Cornell College Poster Presentation Rubric](https://www.cornellcollege.edu/library/faculty/focusing-on-assignments/tools-for-assessment/poster-presentation-rubric.shtml)
- [DIU Thesis Defense Rubric](https://diu.edu/forms/2256-Thesis-Defense-Rubric.pdf)
- [Purdue PhD Dissertation Defense Rubric](https://old.polytechnic.purdue.edu/sites/default/files/files/GEC%2004%20Dissertation%20and%20Defense%20Form%20Polytechnic%20v3.pdf)
- [Duarte - Critique Language for Presentations](https://www.duarte.com/blog/techniques-for-using-critique-language-for-more-powerful-and-effective-presentations/)
- [University of Minnesota Research Presentation Guidelines](https://cbs.umn.edu/sites/cbs.umn.edu/files/migrated-files/downloads/Research_Presentation_Guidelines_EEB3407.pdf)
