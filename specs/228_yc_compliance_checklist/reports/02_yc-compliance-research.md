# Research Report: Task #228

**Task**: Add YC Compliance Checklist context file
**Started**: 2026-03-18T12:00:00Z
**Completed**: 2026-03-18T12:15:00Z
**Effort**: 1-2 hours (implementation)
**Dependencies**: None
**Sources/Inputs**: Codebase exploration, prior research (01_meta-research.md), YC documentation
**Artifacts**: This report
**Standards**: report-format.md, artifact-formats.md

## Executive Summary

- Existing present extension has comprehensive pitch deck context files (`pitch-deck-structure.md`, `touying-pitch-deck-template.md`) documenting YC principles but lacking hard enforcement rules
- The `submission-checklist.md` template provides excellent structural pattern for compliance checklists
- Current example decks (`professional-blue-pitch.typ`, `minimal-light-pitch.typ`) demonstrate good practices but have some font size violations (20pt, 22pt text in places)
- Recommended structure: Three sections (Enforcement Rules, Anti-Patterns, Validation Checklist) following existing standards conventions

## Context & Scope

This research explores the present extension structure, existing context file patterns, and YC pitch deck guidelines to inform creation of `yc-compliance-checklist.md`. The goal is a context file that provides hard enforcement rules the `/deck` command can use to validate generated pitch decks.

## Findings

### Present Extension Structure

The present extension (`/.claude/extensions/present/`) organizes context files in a clear hierarchy:

```
context/project/present/
├── domain/         # Terminology and domain concepts
├── patterns/       # Reusable structural patterns
├── standards/      # Writing and formatting standards
├── templates/      # Document templates with fill-in sections
└── tools/          # Research and utility guides
```

**Key observations**:
- Context files use declarative language with specific thresholds
- Tables are preferred for measurable criteria
- Checklists use `[ ]` checkbox format for verification
- Files cross-reference each other via "Related Context" sections

### Existing Pitch Deck Context

**pitch-deck-structure.md** (254 lines) documents:
- 9+1 slide structure with per-slide requirements
- Three Design Principles (Legibility, Simplicity, Obviousness)
- Visual and content anti-patterns
- Key philosophy and design tests

**touying-pitch-deck-template.md** (397 lines) provides:
- Complete Typst template code
- Typography settings (30pt body, 48pt titles)
- Theme customization patterns
- Basic design checklist (lines 383-392)

**Gap identified**: Neither file provides hard PASS/FAIL validation criteria with specific thresholds. The design checklist in touying-pitch-deck-template.md is advisory, not enforcement-oriented.

### Example Deck Analysis

Analyzed `professional-blue-pitch.typ` and `minimal-light-pitch.typ` for compliance:

| Criterion | professional-blue-pitch.typ | minimal-light-pitch.typ |
|-----------|----------------------------|------------------------|
| Slide count | 10 (PASS) | 10 (PASS) |
| Body font | 30pt default, but 20-24pt in boxes (WARN) | 30pt default, but 18-22pt in places (WARN) |
| Title font | 48pt h1, 40pt h2 (PASS) | 48pt h1, 40pt h2 (PASS) |
| Bullets per slide | Max 4-5 (PASS) | Max 4-5 (PASS) |
| Grid columns | Uses 2-3 columns (MARGINAL) | Uses 2-4 columns (WARN) |

**Key violations found**:
- `text(size: 20pt, fill: secondary)[ARR]` - Below 24pt minimum
- `text(size: 18pt, fill: gray)[Customers]` - Below 24pt minimum
- `text(size: 14pt, fill: gray)[Enterprise AI Market]` - Far below minimum
- 4-column grid layouts on traction slides exceed 2-column max

### YC Guidelines Synthesis

From YC documentation and Kevin Hale's design principles:

**Legibility Requirements**:
- Minimum 24pt for body text (readable from back row)
- Minimum 40pt for slide titles
- High contrast colors (dark text on light, or vice versa)
- Sans-serif fonts preferred
- Text positioned at top of slides (F-pattern reading)

**Simplicity Requirements**:
- Maximum 10 slides (excluding appendix)
- One idea per slide
- Maximum 5 bullets per slide
- No animations or transitions
- Deliberate whitespace
- 5-7 key ideas across entire deck

**Obviousness Requirements**:
- 3-second comprehension test
- No jargon without explanation
- Familiar formats and conventions
- Clear labels on all visuals

### Anti-Pattern Catalog

From existing documentation and best practices:

**Visual Anti-Patterns** (FAIL):
- Screenshots or screen recordings
- Font sizes below 24pt (body) or 40pt (titles)
- Multi-column layouts exceeding 2 columns
- Nested panels/boxes (boxes within boxes)
- Complex grids (more than 2x2)
- Low contrast text/background combinations
- Detailed charts with small labels

**Content Anti-Patterns** (FAIL):
- More than 10 slides in main deck
- More than 5 bullets per slide
- Multiple distinct ideas per slide
- Jargon or unexplained acronyms
- Feature lists instead of benefits
- Competitive comparison tables

**Structural Anti-Patterns** (FAIL):
- Missing required slides (Problem, Solution, Traction, Ask)
- Burying the lede (key message after slide 3)
- No clear ask with specific amount
- Appendix exceeding main deck length

### Enforcement Rule Format Pattern

Based on `character-limits.md` and `submission-checklist.md`, enforcement rules should use:

```markdown
## Hard Limits (FAIL if violated)

| Rule | Threshold | Severity |
|------|-----------|----------|
| Max slides | 10 | FAIL |
| Min body font | 24pt | FAIL |
| Min title font | 40pt | FAIL |
| Max bullets | 5 per slide | FAIL |
| Max columns | 2 | FAIL |

## Soft Limits (WARN if exceeded)

| Rule | Threshold | Severity |
|------|-----------|----------|
| Caption text | 18pt minimum | WARN |
| Grid cells | 3x2 maximum | WARN |
```

### Validation Checklist Pattern

From `submission-checklist.md`, use section-based checkbox format:

```markdown
## Pre-Generation Checklist

```
[ ] Content for all 9 required slides prepared
[ ] Key metrics identified with specific numbers
[ ] Team bios condensed to 2-3 bullets each
[ ] Ask amount finalized with allocation percentages
```

## Design Validation

```
[ ] All body text >= 24pt
[ ] All titles >= 40pt
[ ] No multi-column layouts > 2 columns
[ ] No nested panels or boxes
[ ] No screenshots or screen recordings
```
```

### Index Entry Requirements

The new context file needs an entry in `index-entries.json`:

```json
{
  "path": "project/present/patterns/yc-compliance-checklist.md",
  "domain": "project",
  "subdomain": "present",
  "topics": ["deck", "compliance", "validation", "yc", "pitch"],
  "keywords": ["compliance", "validation", "yc", "pitch-deck", "enforcement", "checklist"],
  "summary": "Hard enforcement rules and validation checklist for YC-style pitch decks",
  "line_count": 200,
  "load_when": {
    "languages": ["deck"],
    "agents": ["deck-agent"],
    "commands": ["/deck"]
  }
}
```

## Recommendations

### File Structure

The `yc-compliance-checklist.md` should contain:

1. **Overview** (brief purpose statement)
2. **Hard Limits Table** (FAIL criteria with thresholds)
3. **Soft Limits Table** (WARN criteria with thresholds)
4. **Anti-Pattern Catalog** (prohibited patterns with examples)
5. **Typst Patterns to Avoid** (specific code patterns that violate rules)
6. **Pre-Flight Validation Checklist** (checkbox format)
7. **Post-Generation Audit Checklist** (checkbox format)
8. **Related Context** (links to pitch-deck-structure.md and touying-pitch-deck-template.md)

### Enforcement Rule Categories

Organize rules by the three YC principles:

**Legibility Rules**:
- Font size minimums
- Contrast requirements
- Text positioning

**Simplicity Rules**:
- Slide count limits
- Bullet count limits
- Column/grid limits
- Animation prohibition

**Obviousness Rules**:
- Required slide presence
- Jargon prohibition
- Label requirements

### Typst Code Patterns

Document specific Typst patterns that violate rules:

```typst
// FAIL: Font size below 24pt
#text(size: 20pt)[Caption text]

// PASS: Minimum compliant size
#text(size: 24pt)[Caption text]

// FAIL: More than 2 columns
#grid(columns: (1fr, 1fr, 1fr, 1fr), ...)

// PASS: Maximum 2 columns
#grid(columns: (1fr, 1fr), ...)
```

### Integration with /deck Command

The `/deck` command should:
1. Load `yc-compliance-checklist.md` for all deck generation
2. Validate output against hard limits before finalizing
3. Emit warnings for soft limit violations
4. Block generation if hard limits are violated

## Decisions

1. **File location**: Place in `patterns/` directory (consistent with `pitch-deck-structure.md`)
2. **Rule severity**: Use FAIL/WARN two-tier system (not FAIL/WARN/INFO)
3. **Threshold values**: Use 24pt body minimum (not 30pt from template) as per YC guidelines
4. **Grid limit**: Set at 2 columns maximum (strict interpretation of Kevin Hale's guidance)
5. **Bullet limit**: Set at 5 per slide (from YC documentation)

## Risks & Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| Overly strict rules prevent useful designs | Medium | Use WARN for edge cases, FAIL only for clear violations |
| Existing templates become non-compliant | Low | Update templates in separate task after checklist created |
| Rules conflict with specific funder requirements | Low | Add override mechanism for non-YC contexts |

## Context Extension Recommendations

None. This research is for a meta task creating context documentation; no additional context gaps identified that are not addressed by this task itself.

## References

- [How to Design a Better Pitch Deck | Y Combinator](https://www.ycombinator.com/blog/how-to-design-a-better-pitch-deck/)
- [How to design a better pitch deck : YC Startup Library](https://www.ycombinator.com/library/4T-how-to-design-a-better-pitch-deck)
- [Practical Design: Pitching | Y Combinator](https://blog.ycombinator.com/practical-design-pitching/)
- Existing research: `specs/228_yc_compliance_checklist/reports/01_meta-research.md`
- pitch-deck-structure.md (present extension)
- touying-pitch-deck-template.md (present extension)
- submission-checklist.md (present extension)

## Next Steps

Run `/plan 228` to create implementation plan for the context file.
