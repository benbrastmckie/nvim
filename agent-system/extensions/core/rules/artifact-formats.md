---
paths: specs/**/*
---

# Artifact Format Rules

## Placeholder Conventions

Placeholders in path templates and content follow these conventions:

| Placeholder | Format | Usage | Examples |
|-------------|--------|-------|----------|
| `{N}` | Unpadded integer | Task numbers in text, commits | `389`, `task 389:` <!-- task-ref-ok illustrative rendering of the {N} placeholder convention --> |
| `{NNN}` | 3-digit padded | Directory numbers | `014`, `{NNN}_{SLUG}` |
| `{P}` | Unpadded integer | Phase numbers | `1`, `phase 1:` |
| `{DATE}` | YYYYMMDD | Date stamps in filenames | `20260111` |
| `{ISO_DATE}` | YYYY-MM-DD | ISO dates in content | `2026-01-11` |
| `{SLUG}` | snake_case | Task slug from title | `fix_bug_name` |

**Key distinction**: Task numbers in text and JSON (`{N}`) remain unpadded for readability. Directory names and artifact versions (`{NNN}`) use 3-digit zero-padding for proper lexicographic sorting.

**System-specific directory prefixes**:
- Claude Code tasks: `specs/{NNN}_{SLUG}/` (no prefix)
- OpenCode tasks: `specs/OC_{NNN}_{SLUG}/` (OC_ prefix)

## Artifact Naming Convention

All task artifacts use the `MM_{short-slug}.md` format:
- `MM` = Zero-padded sequence number within task (01, 02, 03...)
- `{short-slug}` = 3-5 word kebab-case description

### Slug Generation Rules
1. Extract 3-5 most significant words from task title
2. Convert to kebab-case (lowercase, spaces to hyphens)
3. Remove: articles (a, an, the), prepositions (in, on, at, of), conjunctions (and, or, for, to)
4. Keep: main nouns, verbs, adjectives that capture task essence

### Unified Sequential Numbering

All artifact types share one sequence number per task per "round": a research report advances
`next_artifact_number`; the matching plan and summary reuse that round's number
(`next_artifact_number - 1`). Format: `{NN}_{slug}.md` (e.g. `01_initial-research.md`,
`01_implementation-plan.md`). See `context/reference/artifact-numbering-and-versioning.md` for
the round-concept walkthrough and a worked two-round example.

## Phase Status Markers (phase-heading scope)

Use in plan files, on the `### Phase N: {name} [STATUS]` heading only:
- `[NOT STARTED]` - Phase not begun
- `[IN PROGRESS]` - Currently executing
- `[COMPLETED]` - Phase finished
- `[COMPLETED WITH EXCLUSIONS]` - Phase closed with enumerated, reasoned, evidenced exclusions;
  see `context/standards/status-markers.md`'s `[COMPLETED WITH EXCLUSIONS]` subsection
- `[PARTIAL]` - Partially complete (interrupted)
- `[BLOCKED]` - Cannot proceed

These are phase-heading markers, distinct from the plan-level `- **Status**:` field vocabulary
(`{NOT STARTED, IMPLEMENTING, PARTIAL, BLOCKED, ABANDONED, COMPLETED}`, no `[IN PROGRESS]`)
documented in plan-format.md. See that file's "Plan-level vs. phase-level markers" subsection for
the rationale behind the asymmetry.

## Versioning

Research reports may accumulate per task (each supplementing, not replacing, earlier ones); a
new plan version revises the prior approach, and previous plan versions are preserved for
history; one summary per completion covers all phases. See
`context/reference/artifact-numbering-and-versioning.md` for the per-type filename examples.

## Artifact Linking in TODO.md

Use count-aware format from `.claude/context/reference/state-management-schema.md`:
- Single artifact (1): Use inline format `- **Type**: [path]`
- Multiple artifacts (2+): Use multi-line list format with 2-space indentation

**PROHIBITION**: Never use markdown link format `[name](path)` in TODO.md artifact links. Always use bracket-only format `[path]`. Call `bash .claude/scripts/generate-todo.sh` after updating `state.json` to regenerate TODO.md with correct artifact link format (replaces the deprecated `link-artifact-todo.sh`).

## Template Reference

For error report templates, see [Artifact Templates](.claude/context/reference/artifact-templates.md). For research reports, plans, and summaries, use the format files directly:
- `.claude/context/formats/report-format.md`
- `.claude/context/formats/plan-format.md`
- `.claude/context/formats/summary-format.md`
