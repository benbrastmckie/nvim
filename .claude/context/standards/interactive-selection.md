# Interactive Selection Standard

This standard defines patterns for interactive user prompts using AskUserQuestion.

## Overview

Commands that require user input for selection use AskUserQuestion for consistent UX. This standard covers question formatting, option construction, threshold handling, and selection patterns.

## AskUserQuestion Schema

```json
{
  "question": "string (required)",
  "header": "string (1-3 words, Title Case)",
  "multiSelect": "boolean (default: false)",
  "options": [
    {
      "label": "string (action phrase or descriptive noun)",
      "description": "string (consequence, details, or count)"
    }
  ]
}
```

## Question Format Guidelines

### Question Types

| Type | Format | Example |
|------|--------|---------|
| Confirmation | "Should {action}?" | "Should these 5 tasks be archived?" |
| Selection | "Which {items} should {action}?" | "Which task types should be created?" |
| Choice | "How should {items} be {action}?" | "How should TODO items be grouped?" |
| Filter | "Select {items} to {action}:" | "Select TODO items to create as tasks:" |

### Question Best Practices

- Start with action verb or question word
- Include count when relevant (e.g., "these 5 tasks")
- Keep under 80 characters
- Avoid jargon or technical terms

## Header Format Guidelines

Headers appear above the question in the UI.

### Format Rules

- **Length**: 1-3 words
- **Case**: Title Case
- **Content**: Noun phrase describing the selection type

### Header Examples

| Good | Bad | Reason |
|------|-----|--------|
| Task Types | Select the task types you want | Too long |
| TODO Selection | todos | Not Title Case |
| Confirm | Are you sure? | Question, not noun |
| Orphans | Orphaned Directories Found in Specs | Too long |
| CLAUDE.md Updates | claude suggestions | Not Title Case |

## Label Format Guidelines

Labels are the clickable/selectable options.

### Label Patterns

| Pattern | Use Case | Example |
|---------|----------|---------|
| Action phrase | Single actions | "Track all orphans" |
| Descriptive noun | Item types | "fix-it task (8 tags)" |
| [Group] prefix | Grouped items | "[Group] Bimodal fixes (3 issues)" |
| [Individual] prefix | Single items | "[Individual] Fix parser error" |

### Label Best Practices

- Keep under 60 characters
- Include count in parentheses when relevant
- Use consistent verb forms (imperative: "Track", "Skip", "Create")
- Add prefixes for mixed group/individual lists

### Standard Option Labels

| Label | Use Case |
|-------|----------|
| "Select all" | When >20 items, provides bulk selection |
| "Skip" / "Skip all" | Decline selection without action |
| "Keep as grouped tasks" | Preserve groupings |
| "Expand into individual tasks" | Break down groups |
| "Show issues and select manually" | Third-tier drill-down |

## Description Format Guidelines

Descriptions provide context for each option.

### Description Patterns

| Pattern | Use Case | Example |
|---------|----------|---------|
| Consequence | Actions with effects | "Move to archive/ and add state entries" |
| Item details | Grouped selections | "Critical: 1, High: 2 \| Files: Soundness.lean" |
| Count summary | Bulk operations | "Creates 5 tasks (one per selected group)" |
| Source reference | Filtered items | "From: Bimodal fixes group" |

### Description Best Practices

- Keep under 100 characters
- Use `|` as visual separator for multiple info types
- Start with most relevant info
- Avoid redundancy with label

## Threshold Guidelines

Number of items affects selection UI behavior.

| Item Count | Behavior | Rationale |
|------------|----------|-----------|
| 1-10 | Direct selection, no grouping | Small enough to review individually |
| 11-20 | Consider topic grouping | Moderate size, grouping helps |
| 21-50 | Add "Select all" option | Too many to select individually |
| 51-100 | Require narrowing first | Must filter before selection |
| >100 | Hard limit, require filter | Beyond practical selection |

### Threshold Implementation

```
if items.length <= 10:
    show_direct_selection(items)
elif items.length <= 20:
    offer_grouping_option(items)
elif items.length <= 50:
    add_select_all_option(items)
elif items.length <= 100:
    require_narrowing_filter(items)
else:
    error("Too many items. Please narrow scope first.")
```

## Selection Patterns

### Confirmation Pattern

Single yes/no decision with consequences.

```json
{
  "question": "Found 3 orphaned directories. Track them in state files?",
  "header": "Orphans",
  "multiSelect": false,
  "options": [
    {
      "label": "Yes, track all",
      "description": "Move to archive/ and add state entries"
    },
    {
      "label": "No, skip",
      "description": "Only archive tracked tasks"
    }
  ]
}
```

### Multi-Selection Pattern

User selects from multiple items.

```json
{
  "question": "Select TODO items to create as tasks:",
  "header": "TODO Selection",
  "multiSelect": true,
  "options": [
    {
      "label": "Add LSP configuration",
      "description": "src/config/server.ext:67"
    },
    {
      "label": "Implement helper function",
      "description": "utils/helpers.lua:23"
    }
  ]
}
```

### Tiered Selection Pattern

Progressive refinement of selection.

**Tier 1: Group selection**
```json
{
  "question": "Which task groups should be created?",
  "header": "Task Groups",
  "multiSelect": true,
  "options": [
    {
      "label": "[Group] Bimodal fixes (3 issues)",
      "description": "Critical: 1, High: 2 | Files: Soundness.lean"
    }
  ]
}
```

**Tier 2: Granularity selection**
```json
{
  "question": "How should selected groups be created?",
  "header": "Granularity",
  "multiSelect": false,
  "options": [
    {
      "label": "Keep as grouped tasks",
      "description": "Creates 2 tasks (one per selected group)"
    },
    {
      "label": "Expand into individual tasks",
      "description": "Creates 6 tasks (one per issue)"
    }
  ]
}
```

## Decision Tree: Confirmation vs Selection

```
Is there exactly one choice to make?
├── Yes → Confirmation Pattern
│   └── Use multiSelect: false with Yes/No options
└── No → Selection Pattern
    ├── Can user select multiple? → multiSelect: true
    └── Must choose one? → multiSelect: false with options
```

## Implementation Examples

### Reference Implementation: /meta

The `/meta` command demonstrates the full multi-task creation standard with interactive selection:
- Stage 5 (ReviewAndConfirm): Confirmation pattern
- Uses proper header/label/description formatting
- Implements dependency visualization

### Reference Implementation: /fix-it

The `/fix-it` command demonstrates:
- Tiered selection (task types -> individual items -> topic grouping)
- Threshold handling with "Select all" for >20 items
- Empty selection handling (no tasks created)

## Empty Selection Behavior

When user makes no selection or selects "Skip":

1. **Do not create any tasks/items**
2. **Do not prompt again**
3. **Report clearly**: "No tasks created (user selected none)"
4. **Continue to next step** if in multi-step flow

## Error Handling

| Error | Response |
|-------|----------|
| Empty options array | Log error, skip prompt, continue |
| All options filtered | Show "No items match criteria" message |
| Selection timeout | Preserve state, allow retry |
| Invalid selection index | Re-prompt with error message |

## Related Standards

- [command-output.md](../formats/command-output.md) - Output formatting for command results
- [multi-task-creation-standard.md](../../docs/reference/standards/multi-task-creation-standard.md) - Full multi-task workflow
