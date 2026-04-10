# Research Report: Create /talk Command for Present Extension

- **Task**: 390 - Create /talk command for present extension
- **Started**: 2026-04-09T19:42:30Z
- **Completed**: 2026-04-09T19:50:00Z
- **Effort**: ~1 hour
- **Dependencies**: None (sibling tasks 387-389 are independent)
- **Sources/Inputs**:
  - `.claude/extensions/founder/commands/deck.md` - Founder /deck command (primary adaptation source)
  - `.claude/extensions/founder/skills/skill-deck-research/SKILL.md` - Deck research skill
  - `.claude/extensions/founder/skills/skill-deck-implement/SKILL.md` - Deck implement skill
  - `.claude/extensions/founder/agents/deck-research-agent.md` - Deck research agent
  - `.claude/extensions/founder/context/project/founder/deck/index.json` - Slidev deck library
  - `.claude/extensions/founder/context/project/founder/deck/patterns/*.json` - Deck patterns
  - `.claude/extensions/founder/context/project/founder/patterns/pitch-deck-structure.md` - YC structure
  - `.claude/extensions/present/manifest.json` - Present extension manifest
  - `.claude/extensions/present/EXTENSION.md` - Present extension doc
  - `.claude/extensions/present/commands/grant.md` - Grant command (present extension pattern)
  - `.claude/extensions/present/context/project/present/` - Existing present context
- **Artifacts**: This report
- **Standards**: status-markers.md, artifact-management.md, tasks.md, report.md

## Project Context

- **Upstream Dependencies**: Founder extension's deck command architecture (commands/deck.md, skill-deck-research, skill-deck-implement, deck library), present extension's existing structure (manifest.json, grant command pattern)
- **Downstream Dependents**: Task 391 (manifest integration), future research presentation workflows
- **Alternative Paths**: Could build as standalone rather than adapting founder deck, but adaptation reuses proven architecture
- **Potential Extensions**: Poster session generator, workshop materials, teaching presentations

## Executive Summary

- The /talk command should adapt the founder /deck command's material-synthesis architecture for academic/medical research presentations, replacing investor-focused content with research presentation modes
- Five talk modes identified: CONFERENCE (15-20 min research talk), SEMINAR (45-60 min departmental), DEFENSE (grant/thesis defense), POSTER (poster session), JOURNAL_CLUB (paper review)
- The founder deck library provides a proven Slidev-based slide library architecture (themes, patterns, animations, styles, content templates, components) that can be directly replicated for research talks with different content templates
- Deliverables: 1 command file, 1 skill (skill-talk with research and implement stages), 1 agent (talk-agent), and context files covering domain knowledge, slide patterns, and content templates
- The /talk command follows the same pre-task forcing questions pattern as /deck, gathering talk type, source materials, and audience context before task creation

## Context & Scope

This task creates a /talk command within the present extension for generating Slidev-based research presentations. The present extension currently provides only the /grant command for structured proposal development. Adding /talk expands the extension to cover the presentation lifecycle for medical research.

The founder extension's /deck command provides a well-established pattern:
1. Pre-task forcing questions (Stage 0) gather purpose, source materials, and context
2. Task creation stores forcing_data in state.json metadata
3. Research skill (skill-deck-research) delegates to a research agent that synthesizes materials into a slide-mapped report
4. Planning uses the standard planner
5. Implementation skill (skill-deck-implement) delegates to a builder agent that generates Slidev output

This architecture can be adapted with research-specific:
- **Modes**: Replace INVESTOR/UPDATE/INTERNAL/PARTNERSHIP with academic presentation types
- **Slide structures**: Replace YC 10-slide format with research talk structures
- **Content templates**: Replace business metrics with research findings, methods, results
- **Themes**: Reuse existing themes (especially minimal-light, professional-blue) plus add academic-specific ones
- **Components**: Replace MetricCard/TeamMember with FigurePanel/CitationBlock/DataTable

## Findings

### 1. Talk Modes (Replacing Deck Modes)

| Mode | Duration | Slide Count | Focus | Audience |
|------|----------|-------------|-------|----------|
| **CONFERENCE** | 15-20 min | 12-18 slides | Research findings, methods, impact | Peer researchers |
| **SEMINAR** | 45-60 min | 30-45 slides | Deep methodology, background, discussion | Department |
| **DEFENSE** | 30-60 min | 25-40 slides | Research justification, rigor, future work | Committee |
| **POSTER** | N/A | 1 large poster | Visual summary, methods, results | Conference attendees |
| **JOURNAL_CLUB** | 15-30 min | 10-15 slides | Paper critique, key findings, discussion | Lab/journal club |

### 2. Research Talk Slide Structure (CONFERENCE Mode - Primary)

The standard 15-20 minute conference talk maps to this structure:

| Position | Slide Type | Required | Content Focus |
|----------|-----------|----------|---------------|
| 1 | title | Yes | Talk title, authors, affiliations, conference/date |
| 2 | motivation | Yes | Clinical/scientific question, gap in knowledge |
| 3 | background | Yes | Literature context, prior work |
| 4 | objectives | Yes | Specific aims or research questions |
| 5 | methods | Yes | Study design, population, analysis |
| 6 | results-1 | Yes | Primary outcome, key figure/table |
| 7 | results-2 | No | Secondary outcomes, subgroup analyses |
| 8 | results-3 | No | Additional results if needed |
| 9 | discussion | Yes | Interpretation, comparison to literature |
| 10 | limitations | No | Study limitations, methodological caveats |
| 11 | conclusions | Yes | Key takeaways (3-4 bullet points) |
| 12 | acknowledgments | No | Funding, collaborators, disclosures |

This replaces the YC 10-slide structure. Other modes have different sequences (see Decisions section).

### 3. Slide Content Templates Needed

New content templates for research presentations (analogous to founder deck contents):

**Title slides**:
- `title-standard.md` - Title, authors, affiliations, date
- `title-institutional.md` - With institutional logo placeholder and department

**Motivation/Background**:
- `motivation-gap.md` - Knowledge gap framing with literature reference
- `motivation-clinical.md` - Clinical vignette or case to motivate research
- `background-timeline.md` - Chronological literature progression

**Methods**:
- `methods-study-design.md` - Study design diagram (RCT, cohort, etc.)
- `methods-flowchart.md` - CONSORT/STROBE participant flow
- `methods-analysis.md` - Statistical analysis approach

**Results**:
- `results-table.md` - Key results table with highlights
- `results-figure.md` - Figure with caption and interpretation
- `results-forest-plot.md` - Meta-analysis or subgroup forest plot layout
- `results-kaplan-meier.md` - Survival analysis presentation

**Discussion/Conclusions**:
- `discussion-comparison.md` - Findings vs. literature comparison
- `conclusions-takeaway.md` - 3-4 key messages with implications
- `limitations-standard.md` - Standard limitations slide

**Other**:
- `acknowledgments-funding.md` - Funding sources and COI disclosures
- `questions-contact.md` - Q&A slide with contact info

### 4. Research-Specific Components (Vue)

New Vue components for research presentations:

| Component | Props | Purpose |
|-----------|-------|---------|
| `FigurePanel` | src, caption, source, scale | Display research figure with caption |
| `DataTable` | headers, rows, highlight_row, caption | Formatted data table |
| `CitationBlock` | author, year, journal, finding | Inline literature reference |
| `StatResult` | test, value, p_value, ci, significance | Statistical result display |
| `FlowDiagram` | stages, counts, excluded | CONSORT/STROBE flow |

### 5. Deck Patterns for Research Talk Modes

Pattern JSON files needed (analogous to yc-10-slide.json):

| Pattern | Slides | Modes | Description |
|---------|--------|-------|-------------|
| `conference-standard.json` | 12 | CONFERENCE | Standard 15-20 min research talk |
| `seminar-deep-dive.json` | 35 | SEMINAR | 45-60 min departmental seminar |
| `defense-grant.json` | 30 | DEFENSE | Grant defense (NIH study section style) |
| `defense-thesis.json` | 35 | DEFENSE | Thesis/dissertation defense |
| `poster-portrait.json` | 1 | POSTER | Single-slide poster layout |
| `journal-club.json` | 12 | JOURNAL_CLUB | Paper review presentation |

### 6. Forcing Questions (Stage 0) Adaptation

The /deck command asks purpose, source materials, and context. For /talk:

**Step 0.1: Talk Type** (replaces Deck Purpose):
```
What type of talk is this?

- CONFERENCE: Research talk (15-20 min) for conference presentation
- SEMINAR: Departmental seminar (45-60 min)
- DEFENSE: Grant defense or thesis defense
- POSTER: Poster session presentation
- JOURNAL_CLUB: Paper review for journal club
```

**Step 0.2: Source Materials** (same pattern as /deck):
```
What materials should inform the talk?

Provide any combination of:
- Task references (e.g., "task:500" to pull grant research)
- File paths to papers, manuscripts, data (e.g., "/path/to/manuscript.md")
- "none" if you will describe the content

Separate multiple entries with commas.
```

**Step 0.3: Audience Context** (replaces Company Context):
```
Describe the presentation context:
- What is the research topic?
- Who is the audience? (clinicians, basic scientists, mixed)
- What is the time limit?
- Any specific emphasis? (methods, clinical implications, translational)
```

### 7. Theme Reuse and New Themes

Most founder deck themes can be reused directly for research presentations:

| Theme | Reuse | Notes |
|-------|-------|-------|
| Minimal Light | Yes, as-is | Excellent for data-heavy research talks |
| Professional Blue | Yes, as-is | Corporate/clinical settings |
| Dark Blue (AI Startup) | Rename for reuse | Good for technical/computational talks |
| Growth Green | Yes, as-is | Biotech/sustainability topics |
| Premium Dark | Less suitable | Too "luxury" for academic setting |

New themes to add:

| Theme | Description | Use Case |
|-------|-------------|----------|
| `academic-clean` | White background, muted blue accents, serif headings | Standard academic talks |
| `clinical-teal` | White background, teal/medical accents | Clinical research presentations |

### 8. Architecture: Command -> Skill -> Agent

Following the /deck pattern exactly:

**Command**: `commands/talk.md`
- Pre-task forcing questions (Stage 0)
- Task creation with `language: "present"`, `task_type: "talk"`
- Routes to skill-talk for research, planning, implementation

**Skill**: `skills/skill-talk/SKILL.md`
- Thin wrapper with internal postflight
- Routes to talk-agent via Task tool
- Handles status updates, artifact linking, git commits

**Agent**: `agents/talk-agent.md`
- Material synthesis agent (like deck-research-agent)
- Reads source materials, maps content to talk structure
- Creates slide-mapped research report
- Minimal follow-up questions (1-2 max)

**Note**: Unlike the founder deck which has separate research/plan/implement agents, the /talk command should use a single talk-agent for research (following the grant skill's simpler pattern). Planning and implementation route through shared present agents (analogous to founder-plan-agent and founder-implement-agent), but these can be created in a future task if needed. For now, the talk-agent handles research, and standard planner/implementer handle planning/implementation.

### 9. Output Directory Structure

Research talk output follows a parallel structure to founder decks:

```
talks/{N}_{slug}/
  slides.md       # Slidev source
  style.css       # Composed styles
  components/     # Vue components used
  assets/         # Figures, images
  README.md       # Talk overview
```

This parallels the founder's `strategy/{slug}-deck/` output pattern.

### 10. Integration Points with Present Extension

The /talk command integrates with existing present extension through:

- **Manifest routing**: `routing.implement.talk: "skill-talk:assemble"` (or shared implementer)
- **Index entries**: New context files added to `index-entries.json`
- **EXTENSION.md**: Updated skill-agent mapping table
- **Cross-referencing**: /talk can consume /grant research reports as source materials via `task:{N}` references

## Decisions

1. **Adopt /deck architecture**: Use the same pre-task forcing questions + task creation + skill delegation pattern. This is proven and consistent with the founder extension.

2. **Use `language: "present"` with `task_type: "talk"`**: Follows the founder pattern of `language: "founder"` with `task_type: "deck"`. Enables routing discrimination within the present extension.

3. **Single talk-agent for research**: Unlike founder's separate deck-research-agent and deck-builder-agent, start with a single talk-agent that handles research. The standard planner and implementer handle later phases. This keeps the initial implementation simpler.

4. **Five modes**: CONFERENCE, SEMINAR, DEFENSE, POSTER, JOURNAL_CLUB cover the major academic presentation types.

5. **Reuse existing Slidev themes**: The founder deck themes are technology-agnostic. Reuse minimal-light, professional-blue, dark-blue, growth-green directly. Add 2 academic-specific themes.

6. **Separate slide library**: Create `context/project/present/talk/` as the research talk equivalent of `context/project/founder/deck/`. Contains patterns, contents, components, styles, and animations specific to research presentations.

7. **Content slot pattern**: Reuse the founder deck's content_slots mechanism for templated slide content with placeholder filling.

## Recommendations

1. **Start with CONFERENCE mode**: Implement the 12-slide conference talk pattern first as the primary use case. Other modes can be added incrementally.

2. **Reuse animation library**: The founder deck's animations (fade-in, staggered-list, etc.) are presentation-generic and can be referenced directly without duplication.

3. **Create talk-specific content templates**: Research presentations have fundamentally different content from pitch decks. New templates are needed for methods, results, discussion slides.

4. **Design new Vue components**: FigurePanel, DataTable, CitationBlock, and StatResult are essential for research presentations. These do not exist in the founder deck library.

5. **Create an index.json for the talk library**: Follow the exact same structure as the founder deck's `index.json` with categories for themes, patterns, animations, styles, content, and components.

6. **Keep poster mode minimal**: Poster presentations (single-slide) have a fundamentally different layout from slides. The POSTER pattern should generate a single full-page layout rather than a multi-slide deck.

7. **Implementation priority for context files**:
   - High: patterns (conference-standard.json, journal-club.json), content templates (title, methods, results, conclusions)
   - Medium: components (FigurePanel, DataTable), additional patterns (seminar, defense)
   - Low: additional themes (academic-clean, clinical-teal), poster mode

## Risks & Mitigations

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Scope creep from 5 modes | Medium | High | Start with CONFERENCE only, add modes incrementally |
| Component complexity (FigurePanel, DataTable) | Medium | Medium | Start with simple markdown-based alternatives, upgrade to Vue components later |
| Theme duplication with founder | Low | Low | Reference founder themes directly rather than copying; add only academic-specific themes |
| Poster mode fundamentally different | High | Medium | Treat poster as optional/future; document as "planned" but don't block on it |
| Integration with task 391 (manifest) | Low | Low | Design routing and index entries to match expected manifest format |

## Deliverables Checklist

| Deliverable | Path | Priority |
|-------------|------|----------|
| Command file | `commands/talk.md` | P0 |
| Skill definition | `skills/skill-talk/SKILL.md` | P0 |
| Agent definition | `agents/talk-agent.md` | P0 |
| Conference pattern | `context/project/present/talk/patterns/conference-standard.json` | P0 |
| Journal club pattern | `context/project/present/talk/patterns/journal-club.json` | P1 |
| Title content templates | `context/project/present/talk/contents/title/` | P0 |
| Methods content templates | `context/project/present/talk/contents/methods/` | P0 |
| Results content templates | `context/project/present/talk/contents/results/` | P0 |
| Discussion content templates | `context/project/present/talk/contents/discussion/` | P0 |
| Conclusions content templates | `context/project/present/talk/contents/conclusions/` | P0 |
| Talk library index | `context/project/present/talk/index.json` | P0 |
| Talk structure pattern | `context/project/present/patterns/talk-structure.md` | P0 |
| Domain: presentation types | `context/project/present/domain/presentation-types.md` | P1 |
| Vue: FigurePanel | `context/project/present/talk/components/FigurePanel.vue` | P1 |
| Vue: DataTable | `context/project/present/talk/components/DataTable.vue` | P1 |
| Academic clean theme | `context/project/present/talk/themes/academic-clean.json` | P2 |

## Appendix

### A. Comparison: /deck vs /talk Command Structure

| Aspect | /deck (Founder) | /talk (Present) |
|--------|----------------|-----------------|
| Language | founder | present |
| task_type | deck | talk |
| Modes | INVESTOR, UPDATE, INTERNAL, PARTNERSHIP | CONFERENCE, SEMINAR, DEFENSE, POSTER, JOURNAL_CLUB |
| Slide framework | Slidev | Slidev |
| Slide structure | YC 10-slide | Research talk (12-slide conference, etc.) |
| Pre-task questions | Purpose, sources, company context | Talk type, sources, audience context |
| Research agent | deck-research-agent | talk-agent |
| Content focus | Business metrics, traction, ask | Research findings, methods, results |
| Output dir | strategy/{slug}-deck/ | talks/{N}_{slug}/ |
| Themes | Dark blue, minimal, premium, growth, professional | Reuse founder + academic-clean, clinical-teal |

### B. CONFERENCE Mode Slide Content Mapping

| Slide | Content to Extract from Source Materials |
|-------|----------------------------------------|
| Title | Paper/project title, author list, affiliations |
| Motivation | Research question, knowledge gap, clinical relevance |
| Background | Key literature, prior findings, theoretical framework |
| Objectives | Specific aims, hypotheses, research questions |
| Methods | Study design, sample/population, interventions, analysis |
| Results 1 | Primary outcome, main finding, key figure |
| Results 2 | Secondary outcomes, subgroup analyses |
| Discussion | Interpretation, comparison to prior work, implications |
| Limitations | Study limitations, generalizability caveats |
| Conclusions | 3-4 key takeaway messages |
| Acknowledgments | Funding sources, COI disclosures, collaborators |
| Questions | Contact information, Q&A prompt |

### C. File Structure Overview

```
.claude/extensions/present/
  commands/
    talk.md                          # /talk command
  skills/
    skill-talk/
      SKILL.md                       # Talk research/implement skill
  agents/
    talk-agent.md                    # Talk research agent
  context/project/present/
    talk/
      index.json                     # Talk library index
      patterns/
        conference-standard.json     # 12-slide conference talk
        journal-club.json            # Paper review talk
        seminar-deep-dive.json       # Departmental seminar
        defense-grant.json           # Grant defense
      contents/
        title/
          title-standard.md
          title-institutional.md
        motivation/
          motivation-gap.md
          motivation-clinical.md
        methods/
          methods-study-design.md
          methods-flowchart.md
        results/
          results-table.md
          results-figure.md
        discussion/
          discussion-comparison.md
        conclusions/
          conclusions-takeaway.md
        acknowledgments/
          acknowledgments-funding.md
          questions-contact.md
      components/
        FigurePanel.vue
        DataTable.vue
        CitationBlock.vue
        StatResult.vue
      themes/
        academic-clean.json
        clinical-teal.json
    patterns/
      talk-structure.md              # Research talk structure guide
    domain/
      presentation-types.md          # Academic presentation types reference
```
