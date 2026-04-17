# Roadmap Format Standard

**Purpose**: Document ROADMAP.md structure for parsing during /review

---

## Structure Elements

### Phase Headers

Format: `## Phase {N}: {Title} ({Priority})`
Regex: `^## Phase (\d+): (.+?) \((\w+) Priority\)`

### Checkboxes

| State | Format |
|-------|--------|
| Incomplete | `- [ ]` |
| Complete | `- [x]` |

### Status Tables

Format: `| **{Component}** | {STATUS} | {Location} |`
Status values: `PROVEN`, `COMPLETE`, `PARTIAL`, `NOT STARTED`

### Priority Markers

- `(High Priority)`, `(Medium Priority)`, `(Low Priority)`
- `(Low Priority Now, High Later)` - Deferred priority

### Completion Annotation

Format: `- [x] {item} *(Completed: Task {N}, {DATE})*`

Example:
```markdown
- [x] Create proof architecture guide *(Completed: Task 628, 2026-01-15)*
```

---

## Section Types

| Section | Header Pattern |
|---------|----------------|
| Current State | `## Current State:` |
| Phase | `## Phase {N}:` |
| Success Metrics | `## Success Metrics` |
| Execution Order | `## Recommended Execution Order` |

---

## Parsing Strategy

1. Extract phases: Match `## Phase {N}:` headers
2. Extract checkboxes: Match `- \[ \]` and `- \[x\]` patterns
3. Extract tables: Match pipe-delimited rows
4. Identify priorities: Match `({Priority} Priority)` patterns
5. Track annotations: Match `*(Completed: Task {N}, {DATE})*` suffix

---

## Related

- @.claude/context/patterns/roadmap-update.md - Update process
