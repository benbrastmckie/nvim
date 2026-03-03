# Roadmap Update Pattern

**Purpose**: Document roadmap update process during /review

---

## Update Trigger

Roadmap updates occur during `/review` at Step 2.5 (Roadmap Integration). No flag required.

---

## Completion Detection

### Data Sources

| Source | Query |
|--------|-------|
| specs/TODO.md | Grep `[COMPLETED]` |
| specs/state.json | Filter `status == "completed"` |
| File system | Glob for mentioned paths |
| Lean files | Grep `sorry` in Logos/ |

### Matching Strategy

- **Exact**: Item contains `(Task {N})` reference
- **Title**: Item text matches completed task title (fuzzy)
- **File**: Item references file path that exists

### Confidence Levels

| Level | Action |
|-------|--------|
| High (exact match) | Auto-annotate |
| Medium (fuzzy match) | Suggest annotation |
| Low (partial match) | Report only |

---

## Annotation Process

Convert `- [ ] {item}` to `- [x] {item} *(Completed: Task {N}, {DATE})*`

**Safety Rules**: Never remove content. Skip already-annotated items. One edit per item.

---

## Goal Identification

Find first incomplete item (`- [ ]`) in each active phase. Format:

```json
{
  "phase": 1,
  "priority": "High",
  "current_goal": "Audit proof dependencies",
  "items_remaining": 12
}
```

---

## Task Recommendations

### Selection

1. First incomplete from highest-priority phase
2. First incomplete from other phases (max 2 per phase)
3. Items in "Near Term" execution order

### Scoring

| Factor | Weight |
|--------|--------|
| High/Medium/Low priority | 3x / 2x / 1x |
| First in phase | +2 |
| In "Near Term" list | +3 |

### Limit

Present max 5-7 recommendations.

### Language Inference

- `.lean` path: `lean`
- `.md` path: `meta`
- `.tex` path: `latex`
- Otherwise: `general`

---

## User Interaction

Prompt user with numbered list. Accept: numbers (e.g., "1,3"), "all", or "none".

---

## Related

- @.opencode/context/core/formats/roadmap-format.md - ROAD_MAP.md structure
