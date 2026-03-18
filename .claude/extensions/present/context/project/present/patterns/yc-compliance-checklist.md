# YC Compliance Checklist

Enforcement-oriented validation checklist for YC-style pitch decks. This document provides PASS/FAIL criteria based on Kevin Hale's three design principles: Legibility, Simplicity, and Obviousness.

## Purpose

This checklist provides:
- **Hard limits** that MUST be respected (FAIL = rejection)
- **Soft limits** that SHOULD be respected (WARN = review needed)
- **Anti-pattern catalog** for common violations
- **Typst code examples** showing violations and corrections
- **Pre-flight and post-audit checklists** for validation

Use this alongside `pitch-deck-structure.md` for content guidance and `touying-pitch-deck-template.md` for Typst implementation patterns.

---

## Hard Limits (FAIL Criteria)

Violations of these rules indicate the deck does not meet YC standards and requires revision.

| Rule | Limit | Principle | Rationale |
|------|-------|-----------|-----------|
| Maximum slides | 10 (excluding appendix) | Simplicity | More than 10 loses attention |
| Minimum body font | 24pt | Legibility | Back-row readability |
| Minimum title font | 40pt | Legibility | Instant slide identification |
| Maximum bullets per slide | 5 | Simplicity | One idea per slide |
| Maximum columns | 2 | Simplicity | Prevents information overload |
| Text contrast ratio | 4.5:1 minimum | Legibility | WCAG AA standard |
| Animations | None allowed | Simplicity | Distracts from message |
| Screenshots | None allowed | All three | Illegible, complex, non-obvious |

### Slide Count Verification

```
FAIL: Total slide count > 10 (excluding appendix slides)
PASS: Total slide count <= 10
```

### Font Size Verification

```
FAIL: Any body text < 24pt
FAIL: Any title text < 40pt
PASS: Body >= 24pt AND Title >= 40pt
```

---

## Soft Limits (WARN Criteria)

These rules should be followed but may have exceptions with justification.

| Rule | Limit | Principle | Notes |
|------|-------|-----------|-------|
| Caption font | >= 20pt | Legibility | Axis labels, chart legends |
| Grid cells per slide | <= 4 | Simplicity | 2x2 grid maximum preferred |
| Words per slide | <= 30 | Simplicity | Forces concision |
| Appendix slides | <= 5 | Simplicity | Excessive appendix signals lack of focus |
| Chart data points | <= 7 | Obviousness | More requires explanation |
| Team members shown | <= 4 | Simplicity | Focus on key founders |

### Caption Size Verification

```
WARN: Caption/label text 18-19pt (borderline legibility)
PASS: Caption/label text >= 20pt
```

---

## Anti-Pattern Catalog

### Visual Anti-Patterns

| Pattern | Severity | Violation | Fix |
|---------|----------|-----------|-----|
| Screenshots in slides | FAIL | Illegible, complex, non-obvious | Use simplified mockups or describe verbally |
| Font size < 24pt | FAIL | Legibility | Increase to minimum 24pt |
| 3+ column grid | FAIL | Simplicity | Reduce to 2 columns maximum |
| Nested panels/cards | FAIL | Complexity | Flatten to single-level layout |
| Low contrast text | FAIL | Legibility | Ensure 4.5:1 contrast ratio |
| Gradient backgrounds | WARN | Distraction | Use solid backgrounds |
| Multiple font families | WARN | Visual noise | Stick to one sans-serif font |
| Decorative elements | WARN | Distraction | Remove non-essential graphics |

### Content Anti-Patterns

| Pattern | Severity | Violation | Fix |
|---------|----------|-----------|-----|
| More than 10 slides | FAIL | Simplicity | Consolidate or remove |
| More than 5 bullets | FAIL | Simplicity | Break into multiple slides or consolidate |
| Multiple ideas per slide | FAIL | Simplicity | One idea, one slide |
| Industry jargon | FAIL | Obviousness | Plain language only |
| Unexplained acronyms | WARN | Obviousness | Define on first use |
| Feature lists (not benefits) | WARN | Obviousness | Convert to outcomes |
| Vague claims | WARN | Obviousness | Add specific data |

### Structural Anti-Patterns

| Pattern | Severity | Violation | Fix |
|---------|----------|-----------|-----|
| Missing title slide | FAIL | Structure | Add company name + one-liner |
| Missing ask slide | FAIL | Structure | Add fundraising amount + milestones |
| Key message after slide 3 | WARN | Obviousness | Lead with core message |
| No traction data | WARN | Validation | Add metrics or explain absence |
| Appendix > 5 slides | WARN | Focus | Reduce to essential backup |

---

## Typst Patterns to Avoid

### Font Size Violations

```typst
// FAIL: Body text below 24pt
#text(size: 20pt)[This caption is too small]
#text(size: 18pt)[Even worse for readability]

// PASS: Body text at or above 24pt
#text(size: 24pt)[Minimum acceptable body text]
#text(size: 28pt)[Better for emphasis]
```

```typst
// FAIL: Title text below 40pt
#text(size: 32pt, weight: "bold")[Slide Title]

// PASS: Title text at or above 40pt
#text(size: 40pt, weight: "bold")[Slide Title]
#text(size: 48pt, weight: "bold")[Even better visibility]
```

### Column Layout Violations

```typst
// FAIL: More than 2 columns
#grid(
  columns: (1fr, 1fr, 1fr, 1fr),
  gutter: 10pt,
  [Col 1], [Col 2], [Col 3], [Col 4]
)

// PASS: Maximum 2 columns
#grid(
  columns: (1fr, 1fr),
  gutter: 20pt,
  [Left content], [Right content]
)
```

### Bullet Count Violations

```typst
// FAIL: More than 5 bullets
#list(
  [Point 1],
  [Point 2],
  [Point 3],
  [Point 4],
  [Point 5],
  [Point 6],  // Exceeds limit
  [Point 7],  // Exceeds limit
)

// PASS: Maximum 5 bullets
#list(
  [Point 1],
  [Point 2],
  [Point 3],
  [Point 4],
  [Point 5],
)
```

### Nested Layout Violations

```typst
// FAIL: Nested panels create visual complexity
#block(fill: gray, inset: 10pt)[
  #block(fill: white, inset: 8pt)[
    #block(fill: luma(240), inset: 6pt)[
      Deeply nested content
    ]
  ]
]

// PASS: Single-level layout
#block(fill: luma(240), inset: 16pt)[
  Simple, flat content
]
```

### Low Contrast Violations

```typst
// FAIL: Low contrast (light gray on white)
#text(fill: luma(180))[Hard to read text]

// FAIL: Low contrast (dark gray on black)
#block(fill: black)[
  #text(fill: luma(80))[Also hard to read]
]

// PASS: High contrast
#text(fill: black)[Clear on light background]
#block(fill: black)[
  #text(fill: white)[Clear on dark background]
]
```

---

## Pre-Flight Validation Checklist

Run before generating or reviewing a deck:

### Structure Check
- [ ] Total slides <= 10 (excluding appendix)
- [ ] Title slide present with company name + one-liner
- [ ] Ask slide present with amount + milestones
- [ ] Appendix slides <= 5 (if any)

### Font Size Check
- [ ] All body text >= 24pt
- [ ] All title text >= 40pt
- [ ] All captions/labels >= 20pt (WARN if 18-19pt)

### Layout Check
- [ ] No slides with > 2 columns
- [ ] No slides with > 5 bullets
- [ ] No nested panels/cards
- [ ] Grid layouts have <= 4 cells

### Content Check
- [ ] One idea per slide
- [ ] No unexplained jargon or acronyms
- [ ] Benefits, not feature lists
- [ ] Specific claims with data

### Visual Check
- [ ] No screenshots
- [ ] No animations
- [ ] High contrast text (4.5:1 minimum)
- [ ] Solid backgrounds (no gradients)

---

## Post-Generation Audit Checklist

Run after generating or receiving a deck:

### Slide-by-Slide Audit

For each slide, verify:
- [ ] Title font >= 40pt
- [ ] Body font >= 24pt
- [ ] Bullet count <= 5
- [ ] Column count <= 2
- [ ] Single main idea
- [ ] No screenshots or complex graphics

### 3-Second Test

For each slide:
- [ ] Can a stranger understand the main point in 3 seconds?
- [ ] Is the key message at the top of the slide?
- [ ] Is every word readable from the back row?

### Overall Deck Audit

- [ ] Total slide count <= 10
- [ ] Key message appears by slide 3
- [ ] Clear progression: Problem -> Solution -> Traction -> Ask
- [ ] No redundant slides
- [ ] Appendix is essential backup only

### Final Verification

- [ ] Read entire deck aloud (takes ~10 minutes = correct length)
- [ ] Review with someone unfamiliar with your business
- [ ] Test on projector or large screen if possible

---

## Related Context

- [pitch-deck-structure.md](pitch-deck-structure.md) - YC 9+1 slide structure and content guidelines
- [touying-pitch-deck-template.md](touying-pitch-deck-template.md) - Typst implementation patterns and theme configuration
